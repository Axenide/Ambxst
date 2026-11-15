package nightlight

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"testing"

	"ambxst/backend/pkg/paths"
)

// withFakeCommand swaps the package-level command runner for the duration
// of a test. Returns a pointer to the recorded calls slice.
func withFakeCommand(t *testing.T) *[][]string {
	t.Helper()
	calls := &[][]string{}
	oldRun := runFn
	runFn = func(name string, args ...string) error {
		c := append([]string{name}, args...)
		*calls = append(*calls, c)
		return nil
	}
	t.Cleanup(func() { runFn = oldRun })
	return calls
}

func newServiceForTest(t *testing.T) *Service {
	t.Helper()
	s := NewService(&paths.Paths{StateDir: t.TempDir()})
	// Override the Service's process hooks so we don't shell out.
	runFn = func(name string, args ...string) error { return nil }
	s.startFn = func(_ uint32) error { return nil }
	s.stopFn = func() {}
	t.Cleanup(func() {})
	return s
}

func TestEnableUsesWlsunset(t *testing.T) {
	calls := [][]string{}
	oldRun := runFn
	runFn = func(name string, args ...string) error {
		calls = append(calls, append([]string{name}, args...))
		return nil
	}
	t.Cleanup(func() { runFn = oldRun })

	s := NewService(&paths.Paths{StateDir: t.TempDir()})
	// Restore the real startFn so we exercise the default path.
	s.startFn = s.defaultStart
	if err := s.enable(3000); err != nil {
		t.Fatal(err)
	}
	if len(calls) != 1 || calls[0][0] != "wlsunset" {
		t.Fatalf("expected one wlsunset call, got %v", calls)
	}
	args := calls[0][1:]
	if len(args) != 4 || args[0] != "-t" || args[2] != "-T" {
		t.Fatalf("unexpected args: %v", args)
	}
	if args[1] != "2999" || args[3] != "3000" {
		t.Fatalf("expected 2999/3000, got %s/%s", args[1], args[3])
	}
}

func TestSetAndGetRoundTrip(t *testing.T) {
	s := newServiceForTest(t)
	out, err := s.set(json.RawMessage(`{"enabled":true,"temp":3500}`))
	if err != nil {
		t.Fatal(err)
	}
	m := out.(map[string]any)
	if m["active"] != true || m["temp"] != uint32(3500) {
		t.Fatalf("unexpected: %v", m)
	}
}

func TestDisableClearsActive(t *testing.T) {
	s := newServiceForTest(t)
	_ = s.enable(4500)
	s.disable()
	m, _ := s.get(nil)
	if m.(map[string]any)["active"] != false {
		t.Fatalf("expected active=false after disable, got %v", m)
	}
}

func TestEnableFailsWhenStartFails(t *testing.T) {
	s := NewService(&paths.Paths{StateDir: t.TempDir()})
	s.startFn = func(_ uint32) error { return errors.New("nope") }
	if err := s.enable(4500); err == nil {
		t.Fatal("expected error when startFn fails")
	}
}

func TestKelvinArgClamps(t *testing.T) {
	cases := map[uint32]string{
		0:      "1000",
		500:    "1000",
		1000:   "1000",
		6500:   "6500",
		25000:  "25000",
		100000: "25000",
	}
	for in, want := range cases {
		if got := kelvinArg(in); got != want {
			t.Errorf("kelvinArg(%d) = %s, want %s", in, got, want)
		}
	}
}

func TestRestoreReArmsWhenPersisted(t *testing.T) {
	dir := t.TempDir()
	states := filepath.Join(dir, "states.json")
	if err := os.WriteFile(states, []byte(`{"nightlight":{"active":true,"temp":3500}}`), 0o644); err != nil {
		t.Fatal(err)
	}
	s := NewService(&paths.Paths{StateDir: dir})
	// Hook start so we don't actually shell out.
	started := false
	s.startFn = func(_ uint32) error { started = true; return nil }
	out, err := s.Restore(nil)
	if err != nil {
		t.Fatal(err)
	}
	m := out.(map[string]any)
	if !started {
		t.Fatal("expected start to be called")
	}
	if m["active"] != true || m["temp"] != uint32(3500) {
		t.Fatalf("unexpected restore result: %v", m)
	}
}

func TestRestoreSkippedWhenNotPersisted(t *testing.T) {
	dir := t.TempDir()
	states := filepath.Join(dir, "states.json")
	if err := os.WriteFile(states, []byte(`{}`), 0o644); err != nil {
		t.Fatal(err)
	}
	s := NewService(&paths.Paths{StateDir: dir})
	started := false
	s.startFn = func(_ uint32) error { started = true; return nil }
	out, err := s.Restore(nil)
	if err != nil {
		t.Fatal(err)
	}
	if started {
		t.Fatal("start should not have been called")
	}
	if m := out.(map[string]any); m["active"] != false {
		t.Fatalf("expected inactive, got %v", m)
	}
}

func TestPersistenceRoundTrip(t *testing.T) {
	s := newServiceForTest(t)
	if err := s.enable(3500); err != nil {
		t.Fatal(err)
	}
	active, temp, ok := s.loadPersisted()
	if !ok {
		t.Fatal("expected state to be persisted")
	}
	if !active || temp != 3500 {
		t.Fatalf("got active=%v temp=%d", active, temp)
	}
	s.disable()
	active, _, _ = s.loadPersisted()
	if active {
		t.Fatal("expected active=false after disable")
	}
}

// countingService returns a service whose start/stop hooks record calls.
func countingService(t *testing.T) (*Service, *[]uint32, *int) {
	t.Helper()
	s := NewService(&paths.Paths{StateDir: t.TempDir()})
	starts := &[]uint32{}
	stops := new(int)
	s.startFn = func(temp uint32) error { *starts = append(*starts, temp); return nil }
	s.stopFn = func() { *stops++ }
	return s, starts, stops
}

func TestSetOmittedEnabledKeepsActive(t *testing.T) {
	s, starts, stops := countingService(t)
	if err := s.enable(4500); err != nil {
		t.Fatal(err)
	}
	out, err := s.set(json.RawMessage(`{"temp":3500}`))
	if err != nil {
		t.Fatal(err)
	}
	m := out.(map[string]any)
	if m["active"] != true || m["temp"] != uint32(3500) {
		t.Fatalf("temp-only set must keep night light on: %v", m)
	}
	if len(*starts) != 2 || (*starts)[1] != 3500 || *stops != 1 {
		t.Fatalf("expected old instance stopped then restarted at 3500: starts=%v stops=%d", *starts, *stops)
	}
}

func TestSetOmittedEnabledKeepsInactive(t *testing.T) {
	s, starts, _ := countingService(t)
	out, err := s.set(json.RawMessage(`{"temp":3200}`))
	if err != nil {
		t.Fatal(err)
	}
	m := out.(map[string]any)
	if m["active"] != false || m["temp"] != uint32(3200) {
		t.Fatalf("unexpected: %v", m)
	}
	if len(*starts) != 0 {
		t.Fatalf("must not start while inactive: %v", *starts)
	}
}

func TestSetExplicitFalseDisables(t *testing.T) {
	s, _, stops := countingService(t)
	_ = s.enable(4500)
	out, err := s.set(json.RawMessage(`{"enabled":false}`))
	if err != nil {
		t.Fatal(err)
	}
	if out.(map[string]any)["active"] != false || *stops != 1 {
		t.Fatalf("expected disabled, stops=%d", *stops)
	}
}

func TestSetSameStateDoesNotRespawn(t *testing.T) {
	s, starts, _ := countingService(t)
	_ = s.enable(4500)
	if _, err := s.set(json.RawMessage(`{"enabled":true,"temp":4500}`)); err != nil {
		t.Fatal(err)
	}
	if len(*starts) != 1 {
		t.Fatalf("redundant set respawned wlsunset: %v", *starts)
	}
}

func TestTemperatureRetargetsWithoutTogglingState(t *testing.T) {
	s, starts, _ := countingService(t)
	out, err := s.temperature(json.RawMessage(`{"temp":3800}`))
	if err != nil {
		t.Fatal(err)
	}
	if out.(map[string]any)["active"] != false || len(*starts) != 0 {
		t.Fatalf("temperature must not enable: %v starts=%v", out, *starts)
	}
	_ = s.enable(3800)
	out, _ = s.temperature(json.RawMessage(`{"temp":2800}`))
	if m := out.(map[string]any); m["active"] != true || m["temp"] != uint32(2800) {
		t.Fatalf("unexpected: %v", m)
	}
}

func TestTemperatureRequiresTemp(t *testing.T) {
	s, _, _ := countingService(t)
	if _, err := s.temperature(json.RawMessage(`{}`)); err == nil {
		t.Fatal("expected error for missing temp")
	}
}
