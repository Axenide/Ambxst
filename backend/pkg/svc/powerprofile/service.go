package powerprofile

import (
	"encoding/json"
	"fmt"
	"os/exec"
	"strings"
	"sync"

	"ambxst/backend/pkg/ipc"
)

type backend int

const (
	backendNone backend = iota
	backendPowerProfilesCtl
	backendTLP
)

func (b backend) String() string {
	switch b {
	case backendPowerProfilesCtl:
		return "powerprofilesctl"
	case backendTLP:
		return "tlp"
	}
	return ""
}

type Service struct {
	mu      sync.Mutex
	b       backend
	profile string
	list    []string

	// execFn is overridable in tests.
	execFn func(name string, args ...string) ([]byte, error)

	subsMu sync.Mutex
	subs   []*ipc.Subscriber
}

func NewService() *Service {
	s := &Service{}
	s.execFn = func(name string, args ...string) ([]byte, error) {
		return exec.Command(name, args...).Output()
	}
	return s
}

func (s *Service) Register(srv *ipc.Server) {
	srv.Register(&ipc.Service{
		Name: "powerprofile",
		Methods: map[string]ipc.HandlerFunc{
			"set":       s.set,
			"current":   s.currentMethod,
			"available": s.available,
		},
		Subscribe: s.subscribe,
	})
}

func (s *Service) subscribe(sub *ipc.Subscriber) {
	s.detect()
	s.subsMu.Lock()
	s.subs = append(s.subs, sub)
	s.subsMu.Unlock()

	sub.Send("powerprofile.state", s.snapshotPublic())

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
	s.subsMu.Lock()
	subs := append([]*ipc.Subscriber(nil), s.subs...)
	s.subsMu.Unlock()
	payload := s.snapshotPublic()
	for _, sub := range subs {
		sub.Send("powerprofile.state", payload)
	}
}

func (s *Service) snapshotPublic() map[string]any {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.b == backendNone {
		return map[string]any{"available": false, "backend": "", "profile": "", "profiles": []string{}}
	}
	return map[string]any{
		"available": true,
		"backend":   s.b.String(),
		"profile":   s.profile,
		"profiles":  append([]string(nil), s.list...),
	}
}

// detect runs once to figure out which CLI is available and cache the
// profile list. Safe to call concurrently; subsequent calls are no-ops.
func (s *Service) detect() {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.b != backendNone {
		return
	}

	if out, err := s.execFn("powerprofilesctl", "version"); err == nil && len(out) > 0 {
		s.b = backendPowerProfilesCtl
		if cur, err := s.execFn("powerprofilesctl", "get"); err == nil {
			s.profile = strings.TrimSpace(string(cur))
		}
		if listOut, err := s.execFn("bash", "-c", "powerprofilesctl list 2>&1"); err == nil {
			s.list = parsePowerProfilesList(string(listOut))
		}
		if len(s.list) == 0 {
			s.list = []string{"power-saver", "balanced", "performance"}
		}
		return
	}

	if _, err := s.execFn("/sbin/tlp", "--version"); err == nil {
		s.b = backendTLP
		s.list = []string{"power-saver", "balanced", "performance"}
		if out, err := s.execFn("bash", "-c", "/sbin/tlp-stat -p 2>/dev/null | grep -i 'Active profile' | head -1"); err == nil {
			s.profile = parseTLPProfile(string(out))
		}
		return
	}

	s.b = backendNone
}

func parsePowerProfilesList(out string) []string {
	want := []string{"power-saver", "balanced", "performance"}
	seen := map[string]bool{}
	for _, line := range strings.Split(out, "\n") {
		line = strings.TrimSpace(line)
		line = strings.TrimPrefix(line, "*")
		line = strings.TrimSpace(line)
		line = strings.TrimSuffix(line, ":")
		if line == "" {
			continue
		}
		if !contains(want, line) {
			continue
		}
		seen[line] = true
	}
	got := make([]string, 0, len(want))
	for _, w := range want {
		if seen[w] {
			got = append(got, w)
		}
	}
	return got
}

func parseTLPProfile(line string) string {
	switch {
	case strings.Contains(line, "power-saver") || strings.Contains(line, "powersaver"):
		return "power-saver"
	case strings.Contains(line, "balanced"):
		return "balanced"
	case strings.Contains(line, "performance"):
		return "performance"
	}
	return ""
}

func contains(xs []string, v string) bool {
	for _, x := range xs {
		if x == v {
			return true
		}
	}
	return false
}

func (s *Service) snapshot() (backend, string, []string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.b, s.profile, append([]string(nil), s.list...)
}

func (s *Service) set(params json.RawMessage) (any, error) {
	var p struct {
		Profile string `json:"profile"`
	}
	if err := json.Unmarshal(params, &p); err != nil {
		return nil, err
	}
	if p.Profile == "" {
		return nil, fmt.Errorf("set: profile required")
	}
	s.detect()
	b, _, list := s.snapshot()
	if b == backendNone {
		return nil, fmt.Errorf("no power profile backend available")
	}
	if !contains(list, p.Profile) {
		return nil, fmt.Errorf("profile %q not in available list", p.Profile)
	}
	var cmd []string
	switch b {
	case backendPowerProfilesCtl:
		cmd = []string{"powerprofilesctl", "set", p.Profile}
	case backendTLP:
		cmd = []string{"sudo", "/sbin/tlp", p.Profile}
	default:
		return nil, fmt.Errorf("unsupported backend")
	}
	if _, err := s.execFn(cmd[0], cmd[1:]...); err != nil {
		return nil, err
	}
	s.mu.Lock()
	s.profile = p.Profile
	s.mu.Unlock()
	s.broadcast()
	return map[string]any{"profile": p.Profile, "backend": b.String()}, nil
}

func (s *Service) currentMethod(_ json.RawMessage) (any, error) {
	s.detect()
	b, cur, _ := s.snapshot()
	if b == backendNone {
		return map[string]any{"available": false}, nil
	}
	return map[string]any{
		"available": true,
		"backend":   b.String(),
		"profile":   cur,
	}, nil
}

func (s *Service) available(_ json.RawMessage) (any, error) {
	s.detect()
	b, _, list := s.snapshot()
	if b == backendNone {
		return map[string]any{"available": false, "profiles": []string{}}, nil
	}
	return map[string]any{
		"available": true,
		"backend":   b.String(),
		"profiles":  list,
	}, nil
}