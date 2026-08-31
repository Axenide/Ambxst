package gamemode

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"ambxst/backend/pkg/paths"
)

func newTestService(t *testing.T) (*Service, string) {
	t.Helper()
	dir := t.TempDir()
	states := filepath.Join(dir, "states.json")
	if err := os.WriteFile(states, []byte(`{}`), 0o644); err != nil {
		t.Fatal(err)
	}
	svc := NewService(&paths.Paths{StateDir: dir})
	svc.applyFn = func(_ bool) error { return nil }
	return svc, states
}

func TestSetAndGetRoundTrip(t *testing.T) {
	svc, _ := newTestService(t)
	out, err := svc.set(json.RawMessage(`{"enabled":true}`))
	if err != nil {
		t.Fatalf("set: %v", err)
	}
	m, ok := out.(map[string]any)
	if !ok || m["enabled"] != true {
		t.Fatalf("unexpected set result: %v", out)
	}
	out, err = svc.get(nil)
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	m = out.(map[string]any)
	if m["enabled"] != true {
		t.Fatalf("get returned %v after set(true)", m["enabled"])
	}
}

func TestGetRestoresFromDisk(t *testing.T) {
	svc, _ := newTestService(t)
	if err := os.WriteFile(svc.paths.StatesFile(), []byte(`{"gameMode": true}`), 0o644); err != nil {
		t.Fatal(err)
	}
	out, _ := svc.get(nil)
	m := out.(map[string]any)
	if m["enabled"] != true {
		t.Fatalf("expected get to restore true, got %v", m["enabled"])
	}
}

func TestToggleFlipsState(t *testing.T) {
	svc, _ := newTestService(t)
	first, _ := svc.toggle(nil)
	m := first.(map[string]any)
	initial := m["enabled"].(bool)

	second, _ := svc.toggle(nil)
	m = second.(map[string]any)
	if m["enabled"] == initial {
		t.Fatalf("toggle did not flip: initial=%v after=%v", initial, m["enabled"])
	}
}