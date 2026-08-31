package config

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"ambxst/backend/pkg/paths"
)

func newTestService(t *testing.T) *Service {
	t.Helper()
	dir := t.TempDir()
	return NewService(&paths.Paths{StateDir: dir})
}

func writeStates(t *testing.T, s *Service, v map[string]any) {
	t.Helper()
	data, _ := json.MarshalIndent(v, "", "  ")
	if err := os.WriteFile(s.paths.StatesFile(), data, 0o644); err != nil {
		t.Fatal(err)
	}
}

func readStates(t *testing.T, s *Service) map[string]any {
	t.Helper()
	data, err := os.ReadFile(s.paths.StatesFile())
	if err != nil {
		return nil
	}
	out := map[string]any{}
	_ = json.Unmarshal(data, &out)
	return out
}

func TestMigrateNightLightTrue(t *testing.T) {
	s := newTestService(t)
	writeStates(t, s, map[string]any{
		"nightLight":         true,
		"compositorLayout":   "scrolling",
		"animStyleSpeeds":    map[string]any{"hyprland": 120},
	})
	if err := s.MigrateStates(); err != nil {
		t.Fatal(err)
	}
	got := readStates(t, s)
	if _, ok := got["nightLight"]; ok {
		t.Fatal("nightLight key should have been removed")
	}
	nl, ok := got["nightlight"].(map[string]any)
	if !ok {
		t.Fatalf("expected nightlight to be an object, got %T", got["nightlight"])
	}
	if nl["active"] != true {
		t.Fatalf("expected nightlight.active=true, got %v", nl["active"])
	}
	if nl["temp"] != float64(4500) {
		t.Fatalf("expected default temp 4500, got %v", nl["temp"])
	}
	// compositorLayout is preserved (still in use).
	if got["compositorLayout"] != "scrolling" {
		t.Fatal("compositorLayout should be preserved")
	}
	// animStyleSpeeds is pruned.
	if _, ok := got["animStyleSpeeds"]; ok {
		t.Fatal("animStyleSpeeds should be pruned")
	}
}

func TestMigrateNightLightFalseAndExistingNewKey(t *testing.T) {
	s := newTestService(t)
	writeStates(t, s, map[string]any{
		"nightLight":         false,
		"nightlight":         map[string]any{"active": true, "temp": 4000},
		"animStyleSpeeds":    map[string]any{},
	})
	if err := s.MigrateStates(); err != nil {
		t.Fatal(err)
	}
	got := readStates(t, s)
	if _, ok := got["nightLight"]; ok {
		t.Fatal("nightLight should be removed")
	}
	// Existing nightlight key must NOT be overwritten by the legacy bool.
	nl := got["nightlight"].(map[string]any)
	if nl["active"] != true || nl["temp"] != float64(4000) {
		t.Fatalf("existing nightlight should be preserved, got %v", nl)
	}
}

func TestMigrateNoFileIsNoOp(t *testing.T) {
	s := newTestService(t)
	if err := s.MigrateStates(); err != nil {
		t.Fatalf("expected no error when file missing, got %v", err)
	}
}

func TestMigrateIdempotent(t *testing.T) {
	s := newTestService(t)
	writeStates(t, s, map[string]any{
		"nightLight":      true,
		"animStyleSpeeds": map[string]any{"hyprland": 120},
	})
	for i := 0; i < 3; i++ {
		if err := s.MigrateStates(); err != nil {
			t.Fatal(err)
		}
	}
	got := readStates(t, s)
	if _, ok := got["nightLight"]; ok {
		t.Fatal("nightLight should remain removed across reruns")
	}
	if _, ok := got["animStyleSpeeds"]; ok {
		t.Fatal("animStyleSpeeds should remain pruned across reruns")
	}
	if _, ok := got["nightlight"]; !ok {
		t.Fatal("nightlight should be present")
	}
}

// touch ensures filepath import is used even if test file changes.
var _ = filepath.Join