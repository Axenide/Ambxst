package caffeine

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"sync"

	"ambxst/backend/pkg/ipc"
	"ambxst/backend/pkg/paths"
)

const stateKey = "caffeine"

// Service wraps an axctl idle inhibitor handle. It tracks a single inhibitor
// created on demand and tears it down on disable / shutdown.
type Service struct {
	paths *paths.Paths
	mu    sync.Mutex
	id    int
	want  bool

	runFn func(args ...string) ([]byte, error)

	subsMu sync.Mutex
	subs   []*ipc.Subscriber
}

func NewService(p *paths.Paths) *Service {
	s := &Service{paths: p}
	s.runFn = func(args ...string) ([]byte, error) {
		return exec.Command("axctl", args...).Output()
	}
	return s
}

func (s *Service) Register(srv *ipc.Server) {
	srv.Register(&ipc.Service{
		Name: "caffeine",
		Methods: map[string]ipc.HandlerFunc{
			"set":     s.set,
			"get":     s.get,
			"restore": s.Restore,
		},
		Subscribe: s.subscribe,
	})
}

func (s *Service) subscribe(sub *ipc.Subscriber) {
	s.subsMu.Lock()
	s.subs = append(s.subs, sub)
	s.subsMu.Unlock()

	s.mu.Lock()
	want := s.want
	id := s.id
	s.mu.Unlock()
	sub.Send("caffeine.state", map[string]any{"inhibit": want, "id": id})

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
	want := s.want
	id := s.id
	s.mu.Unlock()
	s.subsMu.Lock()
	subs := append([]*ipc.Subscriber(nil), s.subs...)
	s.subsMu.Unlock()
	for _, sub := range subs {
		sub.Send("caffeine.state", map[string]any{"inhibit": want, "id": id})
	}
}

// Close releases the inhibitor if one is active.
func (s *Service) Close() error {
	s.mu.Lock()
	id := s.id
	s.id = 0
	s.mu.Unlock()
	if id == 0 {
		return nil
	}
	_, err := s.runFn("system", "idle-inhibitor-destroy", strconv.Itoa(id))
	return err
}

func (s *Service) loadPersisted() bool {
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

func (s *Service) persist(v bool) {
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

type inhibitorCreateResp struct {
	ID int `json:"id"`
}

// create sends `axctl system idle-inhibitor-create <enable>` and parses the
// returned JSON `{ "id": N }`. enable=1 → active on creation, 0 → inactive.
func (s *Service) create(enable bool) (int, error) {
	out, err := s.runFn("system", "idle-inhibitor-create", b2s(enable))
	if err != nil {
		return 0, fmt.Errorf("axctl idle-inhibitor-create: %w", err)
	}
	var resp inhibitorCreateResp
	if err := json.Unmarshal(out, &resp); err != nil {
		return 0, fmt.Errorf("parse inhibitor id: %w (raw=%q)", err, strings.TrimSpace(string(out)))
	}
	if resp.ID == 0 {
		return 0, errors.New("axctl returned id=0")
	}
	return resp.ID, nil
}

// setEnable flips an existing inhibitor on or off.
func (s *Service) setEnable(id int, enable bool) error {
	if _, err := s.runFn("system", "idle-inhibitor-set", strconv.Itoa(id), b2s(enable)); err != nil {
		return fmt.Errorf("axctl idle-inhibitor-set: %w", err)
	}
	return nil
}

func (s *Service) destroy(id int) error {
	if _, err := s.runFn("system", "idle-inhibitor-destroy", strconv.Itoa(id)); err != nil {
		return fmt.Errorf("axctl idle-inhibitor-destroy: %w", err)
	}
	return nil
}

func (s *Service) set(params json.RawMessage) (any, error) {
	var p struct {
		Inhibit bool `json:"inhibit"`
	}
	if err := json.Unmarshal(params, &p); err != nil {
		return nil, err
	}
	s.mu.Lock()
	id := s.id
	s.mu.Unlock()

	if id == 0 {
		newID, err := s.create(p.Inhibit)
		if err != nil {
			return nil, err
		}
		s.mu.Lock()
		s.id = newID
		s.want = p.Inhibit
		s.mu.Unlock()
	} else {
		if err := s.setEnable(id, p.Inhibit); err != nil {
			return nil, err
		}
		s.mu.Lock()
		s.want = p.Inhibit
		s.mu.Unlock()
	}
	s.persist(p.Inhibit)
	s.broadcast()
	return map[string]any{"inhibit": p.Inhibit, "id": s.snapshotID()}, nil
}

func (s *Service) get(_ json.RawMessage) (any, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	return map[string]any{"inhibit": s.want, "id": s.id}, nil
}

// Restore is called once at boot to re-arm the inhibitor if it was active
// the last time the daemon died.
func (s *Service) Restore(_ json.RawMessage) (any, error) {
	if !s.loadPersisted() {
		return map[string]any{"inhibit": false}, nil
	}
	if s.snapshotID() != 0 {
		s.mu.Lock()
		s.want = true
		s.mu.Unlock()
		s.broadcast()
		return map[string]any{"inhibit": true}, nil
	}
	id, err := s.create(true)
	if err != nil {
		return nil, err
	}
	s.mu.Lock()
	s.id = id
	s.want = true
	s.mu.Unlock()
	s.broadcast()
	return map[string]any{"inhibit": true, "id": id}, nil
}

func (s *Service) snapshotID() int {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.id
}

func b2s(b bool) string {
	if b {
		return "1"
	}
	return "0"
}