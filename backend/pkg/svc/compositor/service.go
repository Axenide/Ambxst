package compositor

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"

	"ambxst/backend/pkg/ipc"
)

// Service exposes the TOML generator over JSON-RPC. The QML shell
// assembles the input payload and calls "render" or "write"; the latter
// persists the result to the canonical axctl.toml path under
// $XDG_DATA_HOME/ambxst/axctl.toml (or ~/.local/share/ambxst/axctl.toml
// as a fallback).
type Service struct {
	paths PathResolver
}

type PathResolver interface {
	AxctlToml() string
}

// PathFunc adapts a plain function to the PathResolver interface, so the
// daemon can hand off the Paths struct without depending on the package
// directly.
type PathFunc func() string

func (f PathFunc) AxctlToml() string { return f() }

func NewService(p PathResolver) *Service {
	if p == nil {
		p = PathFunc(defaultTomlPath)
	}
	return &Service{paths: p}
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

func (s *Service) Register(srv *ipc.Server) {
	srv.Register(&ipc.Service{
		Name: "compositor",
		Methods: map[string]ipc.HandlerFunc{
			"render": s.render,
			"write":  s.write,
		},
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
	path := s.paths.AxctlToml()
	if err := atomicWrite(path, []byte(content)); err != nil {
		return nil, fmt.Errorf("compositor.write: %w", err)
	}
	return map[string]any{"ok": true, "path": path}, nil
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
