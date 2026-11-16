package compositor

import (
	"encoding/json"
	"fmt"
	"io"
	"net"
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
	Windows      []json.RawMessage `json:"windows,omitempty"`
	Workspaces   []json.RawMessage `json:"workspaces,omitempty"`
	Monitors     []json.RawMessage `json:"monitors,omitempty"`
	OverviewOpen *bool             `json:"overview_open,omitempty"`
}

type Update struct {
	State  *State
	Method string
	Params json.RawMessage
}

const subscribeRetryDelay = 500 * time.Millisecond
const socketWaitStep = 100 * time.Millisecond
const socketWaitTimeout = 5 * time.Second

// Manager connects Ambxst to axctl and exposes its compositor state. It may
// start axctl when needed, but axctl outlives the shell process that started it.
type Manager struct {
	tomlPath  string
	configDir string

	mu      sync.RWMutex
	state   State
	started bool

	daemonCmd *exec.Cmd
	daemonMu  sync.Mutex
	subConnMu sync.Mutex

	subsMu      sync.Mutex
	subscribers map[chan Update]struct{}

	stopCh  chan struct{}
	wg      sync.WaitGroup
	subConn net.Conn
	rpcMu   sync.Mutex
	rpcConn net.Conn
}

// NewManager constructs a Manager. nil defaults to the same XDG layout the
// QML side used so the on-disk layout does not change.
func NewManager(p PathResolver) *Manager {
	m := &Manager{
		stopCh:      make(chan struct{}),
		subscribers: make(map[chan Update]struct{}),
	}
	if p == nil {
		m.tomlPath = defaultTomlPath()
	} else {
		m.tomlPath = p.AxctlToml()
	}
	m.configDir = filepath.Dir(m.tomlPath)
	return m
}

// Start ensures the axctl config dir exists, reuses a running daemon when
// possible, and connects an event subscriber.
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

	if socketAlive(axctlSocketPath()) {
		fmt.Fprintln(os.Stderr, "[compositor] using existing axctl daemon")
	} else if err := m.startDaemon(); err != nil {
		return err
	}

	m.daemonMu.Lock()
	ownsDaemon := m.daemonCmd != nil
	m.daemonMu.Unlock()
	if ownsDaemon {
		m.wg.Add(1)
		go m.daemonLoop()
	}
	m.wg.Add(1)
	go m.subscribeLoop()

	m.mu.Lock()
	m.started = true
	m.mu.Unlock()
	return nil
}

// hyprlandChildEnv returns the environment for axctl children with a
// corrected HYPRLAND_INSTANCE_SIGNATURE when the inherited one points to
// a dead Hyprland session. Stale signatures are commonly inherited from
// tmux servers or terminals that survived a compositor restart, leaving
// axctl (and therefore the shell) silently blind to window state.
// Auto-heal only when the current signature is provably dead and exactly
// one live instance answers.
func hyprlandChildEnv() []string {
	env := os.Environ()
	sig := os.Getenv("HYPRLAND_INSTANCE_SIGNATURE")
	runtimeDir := os.Getenv("XDG_RUNTIME_DIR")
	if sig == "" || runtimeDir == "" {
		return env
	}
	sock := filepath.Join(runtimeDir, "hypr", sig, ".socket.sock")
	if socketAlive(sock) {
		return env
	}
	matches, _ := filepath.Glob(filepath.Join(runtimeDir, "hypr", "*", ".socket.sock"))
	var live []string
	for _, m := range matches {
		if socketAlive(m) {
			live = append(live, m)
		}
	}
	if len(live) != 1 {
		return env
	}
	liveSig := filepath.Base(filepath.Dir(live[0]))
	for i, kv := range env {
		if strings.HasPrefix(kv, "HYPRLAND_INSTANCE_SIGNATURE=") {
			env[i] = "HYPRLAND_INSTANCE_SIGNATURE=" + liveSig
		}
	}
	fmt.Fprintf(os.Stderr, "[compositor] inherited HYPRLAND_INSTANCE_SIGNATURE is dead; using live session %s\n", liveSig)
	return env
}

// socketAlive reports whether a unix socket path has a listening peer.
func socketAlive(path string) bool {
	conn, err := net.Dial("unix", path)
	if err != nil {
		return false
	}
	conn.Close()
	return true
}

func (m *Manager) startDaemon() error {
	cmd := exec.Command("axctl", "-c", m.tomlPath, "daemon")
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	cmd.Env = hyprlandChildEnv()
	cmd.Stdout = io.Discard
	cmd.Stderr = io.Discard
	if err := cmd.Start(); err != nil {
		return fmt.Errorf("axctl daemon: %w", err)
	}
	m.daemonMu.Lock()
	m.daemonCmd = cmd
	m.daemonMu.Unlock()
	return nil
}

// daemonLoop supervises the axctl daemon: if it exits prematurely (crash,
// stray pkill, OOM) it is relaunched with backoff. Without this a dead
// axctl daemon silently leaves the shell without window/workspace state —
// the subscribe loop keeps retrying against a socket nothing serves.
func (m *Manager) daemonLoop() {
	defer m.wg.Done()
	backoff := time.Second
	for {
		select {
		case <-m.stopCh:
			return
		default:
		}

		m.daemonMu.Lock()
		cmd := m.daemonCmd
		m.daemonMu.Unlock()
		if cmd == nil {
			if err := m.startDaemon(); err != nil {
				fmt.Fprintf(os.Stderr, "[compositor] %v\n", err)
				select {
				case <-m.stopCh:
					return
				case <-time.After(backoff):
				}
				continue
			}
			m.daemonMu.Lock()
			cmd = m.daemonCmd
			m.daemonMu.Unlock()
		}

		waitCh := make(chan struct{})
		go func() {
			_ = cmd.Wait()
			close(waitCh)
		}()

		select {
		case <-m.stopCh:
			return
		case <-waitCh:
		}

		m.daemonMu.Lock()
		if m.daemonCmd == cmd {
			m.daemonCmd = nil
		}
		m.daemonMu.Unlock()

		fmt.Fprintf(os.Stderr, "[compositor] axctl daemon exited; restarting in %v\n", backoff)
		select {
		case <-m.stopCh:
			return
		case <-time.After(backoff):
		}
		if backoff < 10*time.Second {
			backoff *= 2
		}
	}
}

// axctlSocketPath reproduces the path axctl itself uses for its IPC socket
// (runtime dir first, legacy /tmp fallback — must stay in sync with axctl's
// defaultSocketPath).
func axctlSocketPath() string {
	if runtime := os.Getenv("XDG_RUNTIME_DIR"); runtime != "" {
		return filepath.Join(runtime, "axctl.sock")
	}
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

func (m *Manager) waitForSocket() error {
	deadline := time.Now().Add(socketWaitTimeout)
	for time.Now().Before(deadline) {
		select {
		case <-m.stopCh:
			return fmt.Errorf("axctl subscription stopped")
		default:
		}
		if info, err := os.Stat(axctlSocketPath()); err == nil && info.Mode()&os.ModeSocket != 0 {
			return nil
		}
		time.Sleep(socketWaitStep)
	}
	return fmt.Errorf("axctl socket %s did not appear", axctlSocketPath())
}

// subscribeLoop keeps one direct JSON-RPC subscription alive and reconnects
// when axctl restarts.
func (m *Manager) subscribeLoop() {
	defer m.wg.Done()
	for {
		select {
		case <-m.stopCh:
			return
		default:
		}

		if err := m.waitForSocket(); err != nil {
			select {
			case <-m.stopCh:
				return
			default:
			}
			fmt.Fprintf(os.Stderr, "[compositor] %v\n", err)
			continue
		}

		conn, err := net.DialTimeout("unix", axctlSocketPath(), socketWaitTimeout)
		if err != nil {
			if !m.waitRetry() {
				return
			}
			continue
		}
		m.subConnMu.Lock()
		m.subConn = conn
		m.subConnMu.Unlock()
		request := map[string]any{"id": 1, "method": "System.Subscribe", "params": map[string]any{}}
		if err := json.NewEncoder(conn).Encode(request); err != nil {
			conn.Close()
			m.clearSubscribeConn(conn)
			if !m.waitRetry() {
				return
			}
			continue
		}
		decoder := json.NewDecoder(conn)
		var response struct {
			Error string `json:"error"`
		}
		if err := decoder.Decode(&response); err != nil || response.Error != "" {
			conn.Close()
			m.clearSubscribeConn(conn)
			if err != nil {
				fmt.Fprintf(os.Stderr, "[compositor] axctl subscribe: %v\n", err)
			} else {
				fmt.Fprintf(os.Stderr, "[compositor] axctl subscribe: %s\n", response.Error)
			}
			if !m.waitRetry() {
				return
			}
			continue
		}
		m.readSubscribe(decoder)
		conn.Close()
		m.clearSubscribeConn(conn)
		if !m.waitRetry() {
			return
		}
	}
}

func (m *Manager) readSubscribe(decoder *json.Decoder) {
	for {
		var payload struct {
			Method string          `json:"method"`
			Params json.RawMessage `json:"params"`
			State  json.RawMessage `json:"state"`
		}
		if err := decoder.Decode(&payload); err != nil {
			return
		}
		if len(payload.State) > 0 {
			var state State
			if json.Unmarshal(payload.State, &state) == nil {
				m.setState(state)
				m.broadcast(Update{State: &state})
			}
		}
		if payload.Method != "" && payload.Method != "State.Dump" {
			m.broadcast(Update{Method: payload.Method, Params: payload.Params})
		}
	}
}

func (m *Manager) clearSubscribeConn(conn net.Conn) {
	m.subConnMu.Lock()
	if m.subConn == conn {
		m.subConn = nil
	}
	m.subConnMu.Unlock()
}

func (m *Manager) waitRetry() bool {
	select {
	case <-m.stopCh:
		return false
	case <-time.After(subscribeRetryDelay):
		return true
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

func (m *Manager) broadcast(update Update) {
	m.subsMu.Lock()
	defer m.subsMu.Unlock()
	for c := range m.subscribers {
		select {
		case c <- update:
		default:
			close(c)
			delete(m.subscribers, c)
		}
	}
}

// Subscribe returns state and axctl event updates until cancelled.
func (m *Manager) Subscribe() (<-chan Update, func()) {
	ch := make(chan Update, 256)
	m.subsMu.Lock()
	m.subscribers[ch] = struct{}{}
	m.subsMu.Unlock()
	state := m.State()
	ch <- Update{State: &state}
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
	cmd.Env = hyprlandChildEnv()
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

func (m *Manager) dialRPC() (net.Conn, error) {
	deadline := time.Now().Add(socketWaitTimeout)
	var lastErr error
	for time.Now().Before(deadline) {
		conn, err := net.DialTimeout("unix", axctlSocketPath(), socketWaitStep)
		if err == nil {
			return conn, nil
		}
		lastErr = err
		select {
		case <-m.stopCh:
			return nil, fmt.Errorf("connect to axctl: manager stopped")
		case <-time.After(socketWaitStep):
		}
	}
	return nil, fmt.Errorf("connect to axctl socket %s: %w", axctlSocketPath(), lastErr)
}

func (m *Manager) Call(method string, params any) (json.RawMessage, error) {
	m.rpcMu.Lock()
	defer m.rpcMu.Unlock()
	if m.rpcConn == nil {
		conn, err := m.dialRPC()
		if err != nil {
			return nil, err
		}
		m.rpcConn = conn
	}
	conn := m.rpcConn
	if err := conn.SetDeadline(time.Now().Add(10 * time.Second)); err != nil {
		conn.Close()
		m.rpcConn = nil
		return nil, err
	}
	request := map[string]any{"id": 1, "method": method, "params": params}
	if err := json.NewEncoder(conn).Encode(request); err != nil {
		conn.Close()
		m.rpcConn = nil
		return nil, err
	}
	var response struct {
		Result json.RawMessage `json:"result"`
		Error  string          `json:"error"`
	}
	if err := json.NewDecoder(conn).Decode(&response); err != nil {
		conn.Close()
		m.rpcConn = nil
		return nil, err
	}
	_ = conn.SetDeadline(time.Time{})
	if response.Error != "" {
		return nil, fmt.Errorf("axctl %s: %s", method, response.Error)
	}
	return response.Result, nil
}

// Close stops Ambxst's subscription without terminating the shared axctl
// daemon. Safe to call multiple times.
func (m *Manager) Close() {
	m.mu.Lock()
	started := m.started
	m.started = false
	m.mu.Unlock()
	if !started {
		return
	}

	close(m.stopCh)

	m.subConnMu.Lock()
	if m.subConn != nil {
		_ = m.subConn.Close()
		m.subConn = nil
	}
	m.subConnMu.Unlock()
	m.rpcMu.Lock()
	if m.rpcConn != nil {
		_ = m.rpcConn.Close()
		m.rpcConn = nil
	}
	m.rpcMu.Unlock()

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
