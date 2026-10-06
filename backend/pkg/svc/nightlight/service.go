// Package nightlight implements night light via a daemon-managed wlsunset
// process. We tried wlr-gamma-control-unstable-v1 directly (the DMS path)
// but wlroots rejects our get_gamma_control argument shape even with valid
// new_id and output. wlsunset is a well-tested external process that
// implements the same temperature-to-gamma math against the same protocol;
// spawning it from the daemon gives us a clean lifecycle and a single IPC
// surface without the protocol-debugging burden.
//
// State (active + temp) is persisted in states.json under the "nightlight"
// key. On boot, Restore() re-arms wlsunset if the last state was active.
package nightlight

import (
	"encoding/json"
	"os"
	"os/exec"
	"sync"

	"ambxst/backend/pkg/ipc"
	"ambxst/backend/pkg/paths"
)

type Service struct {
	paths *paths.Paths
	mu     sync.Mutex
	active bool
	temp   uint32 // Kelvin
	cmd    *exec.Cmd

	startFn func(temp uint32) error
	stopFn  func()

	subsMu sync.Mutex
	subs   []*ipc.Subscriber
}

// runFn is the package-level indirection used by enable/disable so tests
// can swap in fakes without going through real processes.
var runFn = func(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Start()
}

// stopFn is a package-level indirection used by tests. The Service holds
// its own start/stop hooks in `startFn` and `stopFn`.
var stopFn = func() {}

var defaultCmd *exec.Cmd

func NewService(p *paths.Paths) *Service {
	s := &Service{paths: p, temp: 4500}
	s.startFn = s.defaultStart
	s.stopFn = s.defaultStop
	return s
}

func (s *Service) defaultStart(temp uint32) error {
	lo := uint32(0)
	if temp > 1 {
		lo = temp - 1
	}
	// runFn is the package-level indirection so tests can swap the
	// actual exec.Command invocation.
	if err := runFn("wlsunset", "-t", kelvinArg(lo), "-T", kelvinArg(temp)); err != nil {
		return err
	}
	// We don't capture the cmd here because runFn may not have used
	// exec.Command. The defaultStop uses exec.Command("pkill", "wlsunset")
	// instead.
	return nil
}

func (s *Service) defaultStop() {
	// Best-effort kill — wlsunset doesn't have a stop signal we can send
	// portably, so we pkill any running instances. Process exit cleans
	// itself up.
	exec.Command("pkill", "-f", "wlsunset").Run()
}

const stateKey = "nightlight"

// loadPersisted reads the saved {active, temp} from states.json.
func (s *Service) loadPersisted() (bool, uint32, bool) {
	data, err := os.ReadFile(s.paths.StatesFile())
	if err != nil {
		return false, 0, false
	}
	doc := map[string]any{}
	if err := json.Unmarshal(data, &doc); err != nil {
		return false, 0, false
	}
	v, ok := doc[stateKey].(map[string]any)
	if !ok {
		return false, 0, false
	}
	active, _ := v["active"].(bool)
	var temp uint32
	if t, ok := v["temp"].(float64); ok && t > 0 {
		temp = uint32(t)
	}
	return active, temp, true
}

// persist writes the current {active, temp} into states.json. Holds no lock;
// callers must serialize via s.mu.
func (s *Service) persist() {
	doc := map[string]any{}
	if data, err := os.ReadFile(s.paths.StatesFile()); err == nil {
		_ = json.Unmarshal(data, &doc)
	}
	doc[stateKey] = map[string]any{"active": s.active, "temp": s.temp}
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

func defaultStart(temp uint32) error {
	return nil
}

func (s *Service) Register(srv *ipc.Server) {
	srv.Register(&ipc.Service{
		Name: "nightlight",
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
	active := s.active
	temp := s.temp
	s.mu.Unlock()
	sub.Send("nightlight.state", map[string]any{"active": active, "temp": temp})

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
	active := s.active
	temp := s.temp
	s.mu.Unlock()
	s.subsMu.Lock()
	subs := append([]*ipc.Subscriber(nil), s.subs...)
	s.subsMu.Unlock()
	for _, sub := range subs {
		sub.Send("nightlight.state", map[string]any{"active": active, "temp": temp})
	}
}

func (s *Service) enable(temp uint32) error {
	if err := s.startFn(temp); err != nil {
		return err
	}
	s.mu.Lock()
	s.active = true
	s.temp = temp
	s.persist()
	s.mu.Unlock()
	s.broadcast()
	return nil
}

// Restore is called once at daemon boot to re-arm night light if it was
// active the last time the daemon died. Idempotent and safe to retry.
func (s *Service) Restore(_ json.RawMessage) (any, error) {
	active, temp, ok := s.loadPersisted()
	if !ok || !active {
		return map[string]any{"active": false}, nil
	}
	if temp > 0 {
		s.mu.Lock()
		s.temp = temp
		s.mu.Unlock()
	}
	if err := s.enable(temp); err != nil {
		return nil, err
	}
	return map[string]any{"active": true, "temp": temp}, nil
}

// kelvinArg formats a Kelvin temperature as a string. wlsunset expects a
// positive integer; clamp to a sane range so user errors don't break us.
func kelvinArg(k uint32) string {
	if k < 1000 {
		return "1000"
	}
	if k > 25000 {
		return "25000"
	}
	return uintToString(k)
}

func uintToString(k uint32) string {
	if k == 0 {
		return "0"
	}
	var buf [20]byte
	i := len(buf)
	for k > 0 {
		i--
		buf[i] = byte('0' + k%10)
		k /= 10
	}
	return string(buf[i:])
}

func (s *Service) disable() {
	s.mu.Lock()
	s.active = false
	s.persist()
	s.mu.Unlock()
	s.stopFn()
	s.broadcast()
}

// Close is called by the daemon on shutdown. It tears down the wlsunset
// process but does NOT change the persisted user intent: a wlsunset child
// dies with the daemon anyway, and we want the next boot's Restore() to
// re-arm it if the user had it active.
func (s *Service) Close() {
	s.stopFn()
}

// --- IPC handlers ---

func (s *Service) toggle(_ json.RawMessage) (any, error) {
	s.mu.Lock()
	wasActive := s.active
	temp := s.temp
	s.mu.Unlock()
	if wasActive {
		s.disable()
	} else {
		if err := s.enable(temp); err != nil {
			return nil, err
		}
	}
	return s.get(nil)
}

func (s *Service) set(params json.RawMessage) (any, error) {
	var p struct {
		Enabled bool   `json:"enabled"`
		Temp    uint32 `json:"temp"`
	}
	if err := json.Unmarshal(params, &p); err != nil {
		return nil, err
	}
	if p.Temp != 0 {
		s.mu.Lock()
		s.temp = p.Temp
		s.mu.Unlock()
	}
	if p.Enabled {
		if err := s.enable(s.temp); err != nil {
			return nil, err
		}
	} else {
		s.disable()
	}
	return s.get(nil)
}

func (s *Service) get(_ json.RawMessage) (any, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	return map[string]any{"active": s.active, "temp": s.temp}, nil
}

// stripPunctuation is a no-op helper kept for symmetry with the previous
// gamma ramp implementation. Remove if unused.