package daemon

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"sync"
	"syscall"
	"time"

	"ambxst/backend/pkg/ipc"
	"ambxst/backend/pkg/paths"
	"ambxst/backend/pkg/svc"
	"ambxst/backend/pkg/svc/brightness"
	"ambxst/backend/pkg/svc/caffeine"
	"ambxst/backend/pkg/svc/clipboard"
	"ambxst/backend/pkg/svc/compositor"
	configsvc "ambxst/backend/pkg/svc/config"
	"ambxst/backend/pkg/svc/gamemode"
	"ambxst/backend/pkg/svc/keystore"
	"ambxst/backend/pkg/svc/linkpreview"
	"ambxst/backend/pkg/svc/network"
	"ambxst/backend/pkg/svc/nightlight"
	"ambxst/backend/pkg/svc/powerprofile"
	"ambxst/backend/pkg/svc/sleep"
	"ambxst/backend/pkg/svc/systemmonitor"
	"ambxst/backend/pkg/svc/weather"
)

// Daemon is the unified ambxst process. It owns the IPC server, all
// background services (clipboard, sleep, compositor, …) and the Quickshell
// child. A single binary acts as both launcher and daemon: this struct's
// Run() method replaces the previous "launch + detached daemon" dance and
// guarantees a clean shutdown of every child the process spawned.
type Daemon struct {
	paths *paths.Paths
	srv   *ipc.Server

	ui          *svc.UIService
	sleep       *sleep.Service
	clipboard   *clipboard.Service
	network     *network.Service
	compositor  *compositor.Service
	caffeine    *caffeine.Service
	gamemode    *gamemode.Service
	powerprof   *powerprofile.Service
	nightlight  *nightlight.Service

	shutdownCh  chan struct{}
	shutdownOnce sync.Once

	qsCmd *exec.Cmd
}

// New wires every service into a freshly constructed server. The caller is
// expected to call Run() next.
func New() (*Daemon, error) {
	p := paths.New()
	d := &Daemon{
		paths:      p,
		srv:        ipc.NewServer(p.SocketPath()),
		shutdownCh: make(chan struct{}),
	}

	// Migrate states.json before any service reads from it. Idempotent.
	configSvc := configsvc.NewService(p)
	if err := configSvc.MigrateStates(); err != nil {
		log.Printf("[ambxst] states migrate: %v", err)
	}

	uiSvc := svc.NewUIService()
	uiSvc.Register(d.srv)

	sysMon := systemmonitor.NewService(2000, []string{"/"})
	sysMon.Register(d.srv)

	sleepSvc, err := sleep.NewService()
	if err != nil {
		return nil, fmt.Errorf("sleep service: %w", err)
	}
	d.sleep = sleepSvc
	sleepSvc.Register(d.srv)

	weatherSvc := weather.NewService()
	weatherSvc.Register(d.srv)

	clipSvc := clipboard.NewService(d.paths)
	clipSvc.Register(d.srv)
	d.clipboard = clipSvc

	netSvc := network.NewService()
	netSvc.Register(d.srv)
	d.network = netSvc

	brightSvc := brightness.NewService()
	brightSvc.Register(d.srv)

	configSvc.Register(d.srv)

	compSvc := compositor.NewService(d.paths)
	compSvc.Register(d.srv)
	d.compositor = compSvc

	keySvc := keystore.NewService(d.paths)
	keySvc.Register(d.srv)

	linkSvc := linkpreview.NewService()
	linkSvc.Register(d.srv)

	gmSvc := gamemode.NewService(d.paths)
	gmSvc.Register(d.srv)
	d.gamemode = gmSvc

	caffeineSvc := caffeine.NewService(d.paths)
	caffeineSvc.Register(d.srv)
	d.caffeine = caffeineSvc

	powerprofSvc := powerprofile.NewService()
	powerprofSvc.Register(d.srv)
	d.powerprof = powerprofSvc

	nlSvc := nightlight.NewService(d.paths)
	nlSvc.Register(d.srv)
	d.nightlight = nlSvc

	// system.shutdown → triggers the same exit path as a terminal signal.
	d.srv.Register(&ipc.Service{
		Name: "system",
		Methods: map[string]ipc.HandlerFunc{
			"shutdown": func(_ json.RawMessage) (any, error) {
				d.TriggerShutdown()
				return "ok", nil
			},
		},
	})

	d.ui = uiSvc
	return d, nil
}

// Server returns the underlying IPC server. Exposed for advanced callers
// (e.g. tests) that need to issue calls directly.
func (d *Daemon) Server() *ipc.Server { return d.srv }

// TriggerShutdown requests a graceful shutdown. Safe to call multiple
// times; only the first call has any effect.
func (d *Daemon) TriggerShutdown() {
	d.shutdownOnce.Do(func() { close(d.shutdownCh) })
}

// Run blocks until the Quickshell child exits, an IPC shutdown is
// requested, or a terminating signal is received. On exit it tears down
// every child it owns in the right order:
//
//	1. close the IPC listener (refuse new connections)
//	2. SIGTERM → Quickshell; SIGKILL its process group if it ignores
//	3. compositor.Close()  → axctl daemon + axctl subscribe
//	4. clipboard.Close()   → wl-paste --watch
//	5. sleep.Close()       → dbus connection
func (d *Daemon) Run(qsBin, shellQML string) error {
	if err := d.srv.Listen(); err != nil {
		return fmt.Errorf("ipc listen: %w", err)
	}
	pidPath := pidFile()
	_ = os.WriteFile(pidPath, []byte(fmt.Sprintf("%d\n", os.Getpid())), 0o644)
	defer os.Remove(pidPath)
	defer d.srv.Close()

	if err := d.compositor.Manager().Start(); err != nil {
		log.Printf("[ambxst] compositor manager: %v (continuing)", err)
	}

	// Caffeine + Nightlight restore both depend on side effects that may
	// not be ready immediately: caffeine needs the axctl daemon socket
	// (spun up by the compositor service above), nightlight needs wlsunset
	// on PATH. Run them in a goroutine after a short delay so the axctl
	// child has time to bind its socket.
	go func() {
		time.Sleep(500 * time.Millisecond)
		if d.caffeine != nil {
			if _, err := d.caffeine.Restore(nil); err != nil {
				log.Printf("[ambxst] caffeine restore: %v", err)
			}
		}
		if d.nightlight != nil {
			if _, err := d.nightlight.Restore(nil); err != nil {
				log.Printf("[ambxst] nightlight restore: %v", err)
			}
		}
	}()

	if err := d.spawnQS(qsBin, shellQML); err != nil {
		return fmt.Errorf("spawn qs: %w", err)
	}

	go d.srv.Serve()

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM, syscall.SIGHUP)
	defer signal.Stop(sigCh)

	qsDone := make(chan error, 1)
	go func() { qsDone <- d.qsCmd.Wait() }()

	select {
	case s := <-sigCh:
		log.Printf("[ambxst] received %v, shutting down", s)
	case <-d.shutdownCh:
		log.Printf("[ambxst] shutdown requested via IPC")
	case err := <-qsDone:
		log.Printf("[ambxst] qs exited: %v", err)
	}

	d.shutdown()
	return nil
}

// spawnQS launches Quickshell as a child of the current process, in its
// own process group so a single SIGKILL cleans up all of qs's descendants.
func (d *Daemon) spawnQS(qsBin, shellQML string) error {
	cmd := exec.Command(qsBin, "-p", shellQML)
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	env := os.Environ()
	if os.Getenv("MALLOC_CONF") == "" {
		env = append(env, "MALLOC_CONF=dirty_decay_ms:1000,muzzy_decay_ms:1000")
	}
	cmd.Env = env
	if err := cmd.Start(); err != nil {
		return err
	}
	d.qsCmd = cmd
	return nil
}

func (d *Daemon) shutdown() {
	if d.qsCmd != nil && d.qsCmd.Process != nil {
		_ = d.qsCmd.Process.Signal(syscall.SIGTERM)
		done := make(chan struct{})
		go func() { _ = d.qsCmd.Wait(); close(done) }()
		select {
		case <-done:
		case <-time.After(1500 * time.Millisecond):
			if pgid, err := syscall.Getpgid(d.qsCmd.Process.Pid); err == nil && pgid > 0 {
				_ = syscall.Kill(-pgid, syscall.SIGKILL)
			} else {
				_ = d.qsCmd.Process.Kill()
			}
			<-done
		}
		d.qsCmd = nil
	}

	if d.compositor != nil && d.compositor.Manager() != nil {
		d.compositor.Manager().Close()
	}
	if d.clipboard != nil {
		d.clipboard.Close()
	}
	if d.sleep != nil {
		d.sleep.Close()
	}
	if d.nightlight != nil {
		d.nightlight.Close()
	}

	// Defensive sweep: any child that escaped the process group cleanup
	// (e.g. tail -f on a FIFO that survived Quickshell's SIGTERM) gets a
	// targeted kill. Cheap and idempotent.
	exec.Command("pkill", "-f", "tail -f /tmp/ambxst_ipc.pipe").Run()
	exec.Command("pkill", "-f", "axctl.*daemon").Run()
	exec.Command("pkill", "-f", "axctl subscribe").Run()
	exec.Command("pkill", "-f", "wl-paste --watch").Run()
	exec.Command("pkill", "-f", "wlsunset").Run()
}

// pidFile returns the daemon pid file path. Kept in sync with
// backend/cmd/ambxst/main.go so other invocations can probe the running
// process without touching the IPC socket.
func pidFile() string {
	if runtime := os.Getenv("XDG_RUNTIME_DIR"); runtime != "" {
		return filepath.Join(runtime, "ambxst.pid")
	}
	return "/tmp/ambxst.pid"
}

// EnsureConfigFiles copies preset JSON defaults if missing (legacy ensure_config_files).
func EnsureConfigFiles(p *paths.Paths, presetDir string) error {
	domains := []string{"theme", "bar", "workspaces", "overview", "notch", "compositor", "performance", "weather", "desktop", "lockscreen", "prefix", "system", "dock", "ai", "general"}
	configDir := filepath.Join(p.ConfigDir, "config")
	if err := os.MkdirAll(configDir, 0o755); err != nil {
		return err
	}
	for _, domain := range domains {
		dst := filepath.Join(configDir, domain+".json")
		if _, err := os.Stat(dst); err == nil {
			continue
		}
		src := filepath.Join(presetDir, domain+".json")
		data, err := os.ReadFile(src)
		if err != nil {
			continue
		}
		if err := os.WriteFile(dst, data, 0o644); err != nil {
			return err
		}
	}
	return nil
}
