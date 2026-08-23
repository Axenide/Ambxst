package compositor

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"

	"ambxst/backend/pkg/ipc"
)

// Service exposes the TOML generator + axctl process supervisor over
// JSON-RPC. Render/write keep the historical signature for backwards
// compatibility with QML callers; state/dispatch/subscribe are the new
// surface for managing the live axctl children owned by the daemon.
type Service struct {
	paths PathResolver
	mgr   *Manager
}

// PathResolver is the minimal surface the service needs from *paths.Paths.
// Defined as an interface so tests can stub the TOML path without bringing
// in the full paths package.
type PathResolver interface {
	AxctlToml() string
}

// PathFunc adapts a plain function to the PathResolver interface.
type PathFunc func() string

func (f PathFunc) AxctlToml() string { return f() }

// NewService constructs the compositor service. When p is non-nil, a
// Manager is attached so state/dispatch/subscribe are available.
func NewService(p PathResolver) *Service {
	s := &Service{paths: p}
	if p != nil {
		s.mgr = NewManager(p)
	}
	return s
}

// Manager returns the underlying process supervisor. Returns nil when the
// service was constructed without a path resolver.
func (s *Service) Manager() *Manager { return s.mgr }

func (s *Service) Register(srv *ipc.Server) {
	methods := map[string]ipc.HandlerFunc{
		"render": s.render,
		"write":  s.write,
	}
	if s.mgr != nil {
		methods["state"] = s.state
		methods["dispatch"] = s.dispatch
		methods["eval"] = s.eval
	}
	srv.Register(&ipc.Service{
		Name:      "compositor",
		Methods:   methods,
		Subscribe: s.subscribe,
	})
}

// render returns the generated TOML without writing it to disk. Useful
// for unit tests, dry-runs, and clients that prefer to write themselves.
func (s *Service) render(params json.RawMessage) (any, error) {
	var in Input
	if err := json.Unmarshal(params, &in); err != nil {
		return nil, fmt.Errorf("compositor.render: %w", err)
	}
	return map[string]any{"toml": Render(in)}, nil
}

// write renders and atomically writes the TOML to the canonical path.
// The daemon's caller doesn't need a lock here because the service
// serializes Render() (pure) and the rename is atomic; concurrent writes
// just produce whichever result was last flushed.
func (s *Service) write(params json.RawMessage) (any, error) {
	var in Input
	if err := json.Unmarshal(params, &in); err != nil {
		return nil, fmt.Errorf("compositor.write: %w", err)
	}
	content := Render(in)
	var path string
	if s.paths != nil {
		path = s.paths.AxctlToml()
	} else {
		path = defaultTomlPath()
	}
	if err := atomicWrite(path, []byte(content)); err != nil {
		return nil, fmt.Errorf("compositor.write: %w", err)
	}
	return map[string]any{"ok": true, "path": path}, nil
}

func (s *Service) state(_ json.RawMessage) (any, error) {
	if s.mgr == nil {
		return nil, fmt.Errorf("compositor: process manager not initialized")
	}
	st := s.mgr.State()
	return map[string]any{
		"windows":    st.Windows,
		"workspaces": st.Workspaces,
		"monitors":   st.Monitors,
	}, nil
}

func (s *Service) dispatch(params json.RawMessage) (any, error) {
	if s.mgr == nil {
		return nil, fmt.Errorf("compositor: process manager not initialized")
	}
	var p struct {
		Args []string `json:"args"`
	}
	if err := json.Unmarshal(params, &p); err != nil {
		return nil, err
	}
	out, code, err := s.mgr.Dispatch(p.Args)
	return map[string]any{
		"stdout":    out,
		"exit_code": code,
		"error":     errString(err),
	}, nil
}

// eval runs a Hyprland Lua expression through axctl's raw-batch wrapper
// (which itself shells out to `hyprctl eval <expr>`). The QML side sends
// `hl.config({...})` updates here so live changes apply immediately
// without waiting on the TOML watcher.
func (s *Service) eval(params json.RawMessage) (any, error) {
	if s.mgr == nil {
		return nil, fmt.Errorf("compositor: process manager not initialized")
	}
	var p struct {
		Expression string `json:"expression"`
	}
	if err := json.Unmarshal(params, &p); err != nil {
		return nil, fmt.Errorf("compositor.eval: %w", err)
	}
	out, code, err := s.mgr.Eval(p.Expression)
	return map[string]any{
		"stdout":    out,
		"exit_code": code,
		"error":     errString(err),
	}, nil
}

func (s *Service) subscribe(sub *ipc.Subscriber) {
	if s.mgr == nil {
		return
	}
	ch, cancel := s.mgr.Subscribe()
	go func() {
		defer cancel()
		for {
			select {
			case st, ok := <-ch:
				if !ok {
					return
				}
				sub.Send("compositor.state", map[string]any{
					"windows":    st.Windows,
					"workspaces": st.Workspaces,
					"monitors":   st.Monitors,
				})
			case <-sub.StopCh():
				return
			}
		}
	}()
}

func defaultTomlPath() string {
	dir := os.Getenv("XDG_DATA_HOME")
	if dir == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			home = "/tmp"
		}
		dir = filepath.Join(home, ".local", "share")
	}
	return filepath.Join(dir, "ambxst", "axctl.toml")
}

func atomicWrite(path string, data []byte) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, data, 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

func errString(err error) string {
	if err == nil {
		return ""
	}
	return err.Error()
}
