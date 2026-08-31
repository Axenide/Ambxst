package gamemode

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"sync"

	"ambxst/backend/pkg/ipc"
	"ambxst/backend/pkg/paths"
)

const stateKey = "gameMode"

var disableKeywords = strings.Join([]string{
	"keyword animations:enabled 0",
	"keyword decoration:shadow:enabled 0",
	"keyword decoration:blur:enabled 0",
	"keyword general:gaps_in 0",
	"keyword general:gaps_out 0",
	"keyword general:border_size 1",
	"keyword decoration:rounding 0",
}, "; ")

type Service struct {
	paths *paths.Paths
	mu    sync.Mutex
	cur   bool

	applyFn func(enable bool) error

	subsMu sync.Mutex
	subs   []*ipc.Subscriber
}

func NewService(p *paths.Paths) *Service {
	s := &Service{paths: p}
	s.applyFn = s.defaultApply
	return s
}

func (s *Service) Register(srv *ipc.Server) {
	srv.Register(&ipc.Service{
		Name: "gamemode",
		Methods: map[string]ipc.HandlerFunc{
			"toggle": s.toggle,
			"set":    s.set,
			"get":    s.get,
		},
		Subscribe: s.subscribe,
	})
}

func (s *Service) subscribe(sub *ipc.Subscriber) {
	s.subsMu.Lock()
	s.subs = append(s.subs, sub)
	s.subsMu.Unlock()

	s.mu.Lock()
	cur := s.cur
	s.mu.Unlock()
	sub.Send("gamemode.state", map[string]any{"enabled": cur})

	go func() {
		<-sub.StopCh()
		s.subsMu.Lock()
		defer s.subsMu.Unlock()
		for i, x := range s.subs {
			if x == sub {
				s.subs = append(s.subs[:i], s.subs[i+1:]...)
				return
			}
		}
	}()
}

func (s *Service) broadcast() {
	s.mu.Lock()
	cur := s.cur
	s.mu.Unlock()
	s.subsMu.Lock()
	subs := append([]*ipc.Subscriber(nil), s.subs...)
	s.subsMu.Unlock()
	for _, sub := range subs {
		sub.Send("gamemode.state", map[string]any{"enabled": cur})
	}
}

// load reads the current persisted state from states.json.
func (s *Service) load() bool {
	data, err := os.ReadFile(s.paths.StatesFile())
	if err != nil {
		return false
	}
	doc := map[string]any{}
	if err := json.Unmarshal(data, &doc); err != nil {
		return false
	}
	v, ok := doc[stateKey].(bool)
	return ok && v
}

// save persists the current toggled state under the gameMode key.
func (s *Service) save(v bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	doc := map[string]any{}
	if data, err := os.ReadFile(s.paths.StatesFile()); err == nil {
		_ = json.Unmarshal(data, &doc)
	}
	doc[stateKey] = v
	out, err := json.MarshalIndent(doc, "", "  ")
	if err != nil {
		return
	}
	tmp := s.paths.StatesFile() + ".tmp"
	if err := os.WriteFile(tmp, out, 0o644); err != nil {
		return
	}
	_ = os.Rename(tmp, s.paths.StatesFile())
}

// applyFn is the side-effect hook used to mutate the compositor. Tests
// override this to avoid shelling out to axctl.
func (s *Service) defaultApply(enable bool) error {
	if enable {
		return s.runAxctl("config", "apply", disableKeywords)
	}
	return s.runAxctl("config", "reload")
}

func (s *Service) runAxctl(args ...string) error {
	cmd := exec.Command("axctl", args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func (s *Service) toggle(_ json.RawMessage) (any, error) {
	s.mu.Lock()
	next := !s.cur
	s.mu.Unlock()
	if err := s.applyFn(next); err != nil {
		return nil, fmt.Errorf("axctl: %w", err)
	}
	s.cur = next
	s.save(next)
	s.broadcast()
	return map[string]any{"enabled": next}, nil
}

func (s *Service) set(params json.RawMessage) (any, error) {
	var p struct {
		Enabled bool `json:"enabled"`
	}
	if err := json.Unmarshal(params, &p); err != nil {
		return nil, err
	}
	if err := s.applyFn(p.Enabled); err != nil {
		return nil, fmt.Errorf("axctl: %w", err)
	}
	s.mu.Lock()
	s.cur = p.Enabled
	s.mu.Unlock()
	s.save(p.Enabled)
	s.broadcast()
	return map[string]any{"enabled": p.Enabled}, nil
}

func (s *Service) get(_ json.RawMessage) (any, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.cur = s.load()
	return map[string]any{"enabled": s.cur}, nil
}