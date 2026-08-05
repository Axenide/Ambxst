package daemon

import (
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"

	"ambxst/backend/pkg/ipc"
	"ambxst/backend/pkg/paths"
	"ambxst/backend/pkg/svc"
	"ambxst/backend/pkg/svc/brightness"
	"ambxst/backend/pkg/svc/clipboard"
	"ambxst/backend/pkg/svc/compositor"
	configsvc "ambxst/backend/pkg/svc/config"
	"ambxst/backend/pkg/svc/keystore"
	"ambxst/backend/pkg/svc/linkpreview"
	"ambxst/backend/pkg/svc/network"
	"ambxst/backend/pkg/svc/sleep"
	"ambxst/backend/pkg/svc/systemmonitor"
	"ambxst/backend/pkg/svc/weather"
)

// Daemon orchestrates the background IPC server.
type Daemon struct {
	paths     *paths.Paths
	srv       *ipc.Server
	ui        *svc.UIService
	sleep     *sleep.Service
	clipboard *clipboard.Service
	network   *network.Service
}

func New() (*Daemon, error) {
	d := &Daemon{paths: paths.New()}

	srv := ipc.NewServer(d.paths.SocketPath())

	uiSvc := svc.NewUIService()
	uiSvc.Register(srv)

	sysMon := systemmonitor.NewService(2000, []string{"/"})
	sysMon.Register(srv)

	sleepSvc, err := sleep.NewService()
	if err != nil {
		return nil, fmt.Errorf("sleep service: %w", err)
	}
	d.sleep = sleepSvc
	sleepSvc.Register(srv)

	weatherSvc := weather.NewService()
	weatherSvc.Register(srv)

	clipSvc := clipboard.NewService(d.paths)
	clipSvc.Register(srv)
	d.clipboard = clipSvc

	netSvc := network.NewService()
	netSvc.Register(srv)
	d.network = netSvc

	brightSvc := brightness.NewService()
	brightSvc.Register(srv)

	configSvc := configsvc.NewService(d.paths)
	configSvc.Register(srv)

	compositorSvc := compositor.NewService(d.paths)
	compositorSvc.Register(srv)

	keySvc := keystore.NewService(d.paths)
	keySvc.Register(srv)

	linkSvc := linkpreview.NewService()
	linkSvc.Register(srv)

	d.ui = uiSvc
	d.srv = srv
	return d, nil
}

// SocketPath returns the daemon socket path.
func (d *Daemon) SocketPath() string { return d.srv.SocketPath() }

// Serve listens and serves until SIGINT/SIGTERM.
func (d *Daemon) Serve() error {
	if err := d.srv.Listen(); err != nil {
		return fmt.Errorf("listen: %w", err)
	}
	pidPath := pidFile()
	if err := os.WriteFile(pidPath, []byte(fmt.Sprintf("%d\n", os.Getpid())), 0o644); err == nil {
		defer os.Remove(pidPath)
	}
	defer d.srv.Close()
	defer func() {
		if d.sleep != nil {
			d.sleep.Close()
		}
		if d.clipboard != nil {
			d.clipboard.Close()
		}
	}()

	fmt.Printf("[ambxst-daemon] listening on %s\n", d.srv.SocketPath())

	sig := make(chan os.Signal, 1)
	signal.Notify(sig, syscall.SIGINT, syscall.SIGTERM)
	done := make(chan error, 1)
	go func() {
		done <- d.srv.Serve()
	}()

	select {
	case err := <-done:
		return err
	case <-sig:
		fmt.Println("[ambxst-daemon] shutting down")
		return nil
	}
}

// pidFile returns the daemon pid file path.
func pidFile() string {
	if runtime := os.Getenv("XDG_RUNTIME_DIR"); runtime != "" {
		return filepath.Join(runtime, "ambxst-daemon.pid")
	}
	return "/tmp/ambxst-daemon.pid"
}

// AlreadyRunning reports whether a daemon pid file points to a live process.
// Guards against a second instance stealing the socket after removing it.
func AlreadyRunning() bool {
	data, err := os.ReadFile(pidFile())
	if err != nil {
		return false
	}
	pid, err := strconv.Atoi(strings.TrimSpace(string(data)))
	if err != nil || pid <= 0 || pid == os.Getpid() {
		return false
	}
	proc := filepath.Join("/proc", strconv.Itoa(pid))
	_, err = os.Stat(proc)
	return err == nil
}

// Spawn detached daemon, waiting for the socket to appear.
func SpawnDetached(p *paths.Paths) error {
	exe, err := os.Executable()
	if err != nil {
		return err
	}
	cmd := exec.Command(exe, "daemon")
	cmd.Stdout = nil
	cmd.Stderr = nil
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	if err := cmd.Start(); err != nil {
		return err
	}
	if cmd.Process != nil {
		cmd.Process.Release()
	}
	return nil
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