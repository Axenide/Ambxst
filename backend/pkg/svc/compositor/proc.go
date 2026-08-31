package compositor

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"syscall"
	"time"
)

// State is the snapshot pushed to subscribers on every axctl subscribe event.
// Mirrors the shape AxctlService.qml consumed before the refactor.
type State struct {
	Windows    []json.RawMessage `json:"windows,omitempty"`
	Workspaces []json.RawMessage `json:"workspaces,omitempty"`
	Monitors   []json.RawMessage `json:"monitors,omitempty"`
}

const subscribeRetryDelay = 500 * time.Millisecond
const socketWaitStep = 100 * time.Millisecond
const socketWaitTimeout = 5 * time.Second

// Manager owns the long-running axctl children (axctl daemon, axctl subscribe)
// and exposes their state to the rest of the compositor service. The Manager
// is started once by the daemon and shut down on daemon exit; child processes
// are placed in their own process group so a single SIGKILL cleans them up.
type Manager struct {
	tomlPath  string
	configDir string

	mu      sync.RWMutex
	state   State
	started bool

	daemonCmd *exec.Cmd
	subCmdMu  sync.Mutex
	subCmd    *exec.Cmd

	subsMu      sync.Mutex
	subscribers map[chan State]struct{}

	stopCh chan struct{}
	wg     sync.WaitGroup
}

// NewManager constructs a Manager. nil defaults to the same XDG layout the
// QML side used so the on-disk layout does not change.
func NewManager(p PathResolver) *Manager {
	m := &Manager{
		stopCh:      make(chan struct{}),
		subscribers: make(map[chan State]struct{}),
	}
	if p == nil {
		m.tomlPath = defaultTomlPath()
	} else {
		m.tomlPath = p.AxctlToml()
	}
	m.configDir = filepath.Dir(m.tomlPath)
	return m
}

// Start ensures the axctl config dir exists, then launches axctl daemon
// followed by axctl subscribe. Both children run in their own process group
// so Close() can SIGKILL the whole group in one shot.
func (m *Manager) Start() error {
	if _, err := exec.LookPath("axctl"); err != nil {
		return fmt.Errorf("axctl not found in PATH: %w", err)
	}
	if err := os.MkdirAll(m.configDir, 0o755); err != nil {
		return fmt.Errorf("create config dir: %w", err)
	}

	m.mu.Lock()
	if m.started {
		m.mu.Unlock()
		return nil
	}
	m.mu.Unlock()

	if err := m.startDaemon(); err != nil {
		return err
	}

	m.wg.Add(1)
	go m.subscribeLoop()

	m.mu.Lock()
	m.started = true
	m.mu.Unlock()
	return nil
}

func (m *Manager) startDaemon() error {
	cmd := exec.Command("axctl", "-c", m.tomlPath, "daemon")
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	cmd.Stdout = io.Discard
	cmd.Stderr = io.Discard
	if err := cmd.Start(); err != nil {
		return fmt.Errorf("axctl daemon: %w", err)
	}
	m.daemonCmd = cmd
	return nil
}

// axctlSocketPath reproduces the path axctl itself uses for its IPC socket.
func axctlSocketPath() string {
	return fmt.Sprintf("/tmp/axctl-%d.sock", os.Getuid())
}

// waitForSocket blocks until the axctl socket exists or the timeout elapses.
func waitForSocket(path string, timeout time.Duration) error {
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		if info, err := os.Stat(path); err == nil && info.Mode()&os.ModeSocket != 0 {
			return nil
		}
		time.Sleep(socketWaitStep)
	}
	return fmt.Errorf("axctl socket %s did not appear", path)
}

// subscribeLoop keeps an axctl subscribe process alive. It waits for the
// daemon socket before launching, and re-launches on premature exit (e.g.
// the daemon being restarted, a transient disconnect).
func (m *Manager) subscribeLoop() {
	defer m.wg.Done()
	for {
		select {
		case <-m.stopCh:
			return
		default:
		}

		if err := waitForSocket(axctlSocketPath(), socketWaitTimeout); err != nil {
			fmt.Fprintf(os.Stderr, "[compositor] %v\n", err)
			return
		}

		cmd := exec.Command("axctl", "subscribe")
		cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
		stdout, err := cmd.StdoutPipe()
		if err != nil {
			time.Sleep(subscribeRetryDelay)
			continue
		}
		cmd.Stderr = io.Discard
		if err := cmd.Start(); err != nil {
			time.Sleep(subscribeRetryDelay)
			continue
		}

		m.subCmdMu.Lock()
		m.subCmd = cmd
		m.subCmdMu.Unlock()

		m.readSubscribe(stdout)

		m.subCmdMu.Lock()
		m.subCmd = nil
		m.subCmdMu.Unlock()

		_ = cmd.Wait()

		select {
		case <-m.stopCh:
			return
		case <-time.After(subscribeRetryDelay):
		}
	}
}

func (m *Manager) readSubscribe(r io.Reader) {
	sc := bufio.NewScanner(r)
	sc.Buffer(make([]byte, 0, 64*1024), 8*1024*1024)
	for sc.Scan() {
		line := sc.Bytes()
		if len(line) == 0 {
			continue
		}
		var payload struct {
			State json.RawMessage `json:"state"`
		}
		if err := json.Unmarshal(line, &payload); err != nil {
			continue
		}
		if len(payload.State) == 0 {
			continue
		}
		var st State
		if err := json.Unmarshal(payload.State, &st); err != nil {
			continue
		}
		m.setState(st)
		m.broadcast(st)
	}
}

func (m *Manager) setState(st State) {
	m.mu.Lock()
	m.state = st
	m.mu.Unlock()
}

// State returns the last known snapshot.
func (m *Manager) State() State {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.state
}

func (m *Manager) broadcast(st State) {
	m.subsMu.Lock()
	subs := make([]chan State, 0, len(m.subscribers))
	for c := range m.subscribers {
		subs = append(subs, c)
	}
	m.subsMu.Unlock()
	for _, c := range subs {
		select {
		case c <- st:
		default:
		}
	}
}

// Subscribe returns a channel that receives every state update and a cancel
// function that removes the subscription. The channel is closed when the
// Manager shuts down.
func (m *Manager) Subscribe() (<-chan State, func()) {
	ch := make(chan State, 16)
	m.subsMu.Lock()
	m.subscribers[ch] = struct{}{}
	m.subsMu.Unlock()
	cancel := func() {
		m.subsMu.Lock()
		if _, ok := m.subscribers[ch]; ok {
			delete(m.subscribers, ch)
			close(ch)
		}
		m.subsMu.Unlock()
	}
	return ch, cancel
}

// Dispatch runs an axctl one-shot command. The returned stdout/stderr is
// captured and forwarded; exit code is reported.
func (m *Manager) Dispatch(args []string) (string, int, error) {
	if len(args) == 0 {
		return "", 0, fmt.Errorf("dispatch: empty args")
	}
	cmd := exec.Command("axctl", args...)
	out, err := cmd.CombinedOutput()
	exit := 0
	if err != nil {
		if ee, ok := err.(*exec.ExitError); ok {
			exit = ee.ExitCode()
		} else {
			return strings.TrimSpace(string(out)), 0, err
		}
	}
	return strings.TrimSpace(string(out)), exit, nil
}

// Eval runs a Hyprland Lua expression via axctl's raw-batch wrapper around
// `hyprctl eval <expr>`. Used by the QML shell to push live config changes
// (border colors, rounding, opacities, etc.) without going through the
// TOML regen + watcher + reload cycle, which Hyprland 0.56's Lua config
// does not re-source on a plain `hyprctl reload` for in-progress changes
// and which the fsnotify watcher in axctl currently misses on atomic
// writes to ~/.local/share/ambxst/axctl.toml.
func (m *Manager) Eval(expression string) (string, int, error) {
	expression = strings.TrimSpace(expression)
	if expression == "" {
		return "", 0, fmt.Errorf("eval: empty expression")
	}
	return m.Dispatch([]string{"config", "raw-batch", "eval " + expression})
}

// Close kills the axctl process group, then waits for the read goroutine to
// drain. Safe to call multiple times.
func (m *Manager) Close() {
	m.mu.Lock()
	started := m.started
	m.started = false
	m.mu.Unlock()
	if !started {
		return
	}

	close(m.stopCh)

	m.subCmdMu.Lock()
	sub := m.subCmd
	m.subCmd = nil
	m.subCmdMu.Unlock()

	m.killGroup(sub)
	m.killGroup(m.daemonCmd)

	done := make(chan struct{})
	go func() { m.wg.Wait(); close(done) }()
	select {
	case <-done:
	case <-time.After(2 * time.Second):
	}

	m.subsMu.Lock()
	for c := range m.subscribers {
		close(c)
		delete(m.subscribers, c)
	}
	m.subsMu.Unlock()
}

func (m *Manager) killGroup(cmd *exec.Cmd) {
	if cmd == nil || cmd.Process == nil {
		return
	}
	pgid, err := syscall.Getpgid(cmd.Process.Pid)
	if err != nil || pgid <= 0 {
		pgid = cmd.Process.Pid
	}
	_ = syscall.Kill(-pgid, syscall.SIGKILL)
	_, _ = cmd.Process.Wait()
}
