package powerprofile

import (
	"encoding/json"
	"errors"
	"strings"
	"testing"
)

type execCall struct {
	name string
	args []string
	out  []byte
	err  error
}

type fakeExec struct {
	calls []execCall
	resp  map[string]execCall
}

func (f *fakeExec) run(name string, args ...string) ([]byte, error) {
	key := name
	if len(args) > 0 {
		key = name + " " + strings.Join(args, " ")
	}
	f.calls = append(f.calls, execCall{name: name, args: args})
	if c, ok := f.resp[key]; ok {
		return c.out, c.err
	}
	if c, ok := f.resp[name]; ok {
		return c.out, c.err
	}
	return nil, errors.New("not found: " + key)
}

func newTestService(t *testing.T, resp map[string]execCall) *Service {
	t.Helper()
	s := NewService()
	f := &fakeExec{resp: resp}
	s.execFn = f.run
	return s
}

func TestPowerProfilesCtlDetected(t *testing.T) {
	s := newTestService(t, map[string]execCall{
		"powerprofilesctl version": {out: []byte("powerprofilesctl 0.13\n")},
		"powerprofilesctl get":     {out: []byte("balanced\n")},
		"bash -c powerprofilesctl list 2>&1": {out: []byte("* balanced:\n  performance:\n* power-saver:\n")},
	})
	out, err := s.available(nil)
	if err != nil {
		t.Fatal(err)
	}
	m := out.(map[string]any)
	if m["available"] != true {
		t.Fatalf("expected available=true, got %v", m)
	}
	if m["backend"] != "powerprofilesctl" {
		t.Fatalf("backend=%v", m["backend"])
	}
	profiles, ok := m["profiles"].([]string)
	if !ok {
		t.Fatalf("profiles not []string: %T", m["profiles"])
	}
	want := []string{"power-saver", "balanced", "performance"}
	if len(profiles) != len(want) {
		t.Fatalf("profiles=%v want %v", profiles, want)
	}
	for i := range want {
		if profiles[i] != want[i] {
			t.Fatalf("profiles[%d]=%v want %v", i, profiles[i], want[i])
		}
	}
}

func TestTLPFallback(t *testing.T) {
	s := newTestService(t, map[string]execCall{
		"powerprofilesctl version": {err: errors.New("not found")},
		"/sbin/tlp --version":      {out: []byte("TLP 1.6\n")},
		"bash -c /sbin/tlp-stat -p 2>/dev/null | grep -i 'Active profile' | head -1": {
			out: []byte("Active profile: balanced"),
		},
	})
	out, err := s.currentMethod(nil)
	if err != nil {
		t.Fatal(err)
	}
	m := out.(map[string]any)
	if m["backend"] != "tlp" || m["profile"] != "balanced" {
		t.Fatalf("got %v", m)
	}
}

func TestNoneAvailable(t *testing.T) {
	s := newTestService(t, map[string]execCall{
		"powerprofilesctl version": {err: errors.New("missing")},
		"/sbin/tlp --version":      {err: errors.New("missing")},
	})
	out, _ := s.available(nil)
	m := out.(map[string]any)
	if m["available"] != false {
		t.Fatalf("expected unavailable, got %v", m)
	}
}

func TestSetRejectsUnknownProfile(t *testing.T) {
	s := newTestService(t, map[string]execCall{
		"powerprofilesctl version": {out: []byte("ok")},
		"powerprofilesctl get":     {out: []byte("balanced")},
		"bash -c powerprofilesctl list 2>&1": {out: []byte("* balanced:\n  performance:\n* power-saver:\n")},
	})
	_, err := s.set(json.RawMessage(`{"profile":"hyper-boost"}`))
	if err == nil {
		t.Fatalf("expected error for unknown profile")
	}
}

func TestParseTLPLine(t *testing.T) {
	cases := map[string]string{
		"Active profile: balanced":      "balanced",
		"Active profile = performance":  "performance",
		"Active profile: powersaver ok": "power-saver",
		"Active profile: idle":          "",
	}
	for in, want := range cases {
		got := parseTLPProfile(in)
		if got != want {
			t.Errorf("parseTLPProfile(%q) = %q, want %q", in, got, want)
		}
	}
}