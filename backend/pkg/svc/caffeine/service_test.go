package caffeine

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"sync"
	"testing"
	"time"

	"ambxst/backend/pkg/paths"
)

func newTestService(t *testing.T) (*Service, *fakeRunner) {
	t.Helper()
	dir := t.TempDir()
	states := filepath.Join(dir, "states.json")
	if err := os.WriteFile(states, []byte(`{}`), 0o644); err != nil {
		t.Fatal(err)
	}
	s := NewService(&paths.Paths{StateDir: dir})
	f := &fakeRunner{}
	s.runFn = f.run
	return s, f
}

type fakeRunner struct {
	mu         sync.Mutex
	calls      [][]string
	create     []byte
	createErr  error
	setErr     error
	destroyErr error
}

func (f *fakeRunner) run(args ...string) ([]byte, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.calls = append(f.calls, args)
	switch args[0] {
	case "system":
		switch args[1] {
		case "idle-inhibitor-create":
			return f.create, f.createErr
		case "idle-inhibitor-set":
			return nil, f.setErr
		case "idle-inhibitor-destroy":
			return nil, f.destroyErr
		}
	}
	return nil, errors.New("unexpected: " + args[0])
}

func TestSetCreatesInhibitor(t *testing.T) {
	s, f := newTestService(t)
	f.create = []byte(`{"id": 42}`)
	out, err := s.set(json.RawMessage(`{"inhibit":true}`))
	if err != nil {
		t.Fatal(err)
	}
	m := out.(map[string]any)
	if m["inhibit"] != true || m["id"] != 42 {
		t.Fatalf("got %v", m)
	}
}

func TestSetUpdatesExistingInhibitor(t *testing.T) {
	s, f := newTestService(t)
	f.create = []byte(`{"id": 7}`)
	if _, err := s.set(json.RawMessage(`{"inhibit":true}`)); err != nil {
		t.Fatal(err)
	}
	f.calls = nil
	if _, err := s.set(json.RawMessage(`{"inhibit":false}`)); err != nil {
		t.Fatal(err)
	}
	if len(f.calls) != 1 || f.calls[0][1] != "idle-inhibitor-set" {
		t.Fatalf("expected idle-inhibitor-set, got %v", f.calls)
	}
	if f.calls[0][3] != "0" {
		t.Fatalf("expected arg=0, got %v", f.calls[0])
	}
}

func TestSetErrorFromAxctl(t *testing.T) {
	s, f := newTestService(t)
	f.createErr = errors.New("axctl died")
	_, err := s.set(json.RawMessage(`{"inhibit":true}`))
	if err == nil {
		t.Fatal("expected error when axctl fails")
	}
}

func TestRestoreAfterReboot(t *testing.T) {
	s, f := newTestService(t)
	if err := os.WriteFile(s.paths.StatesFile(), []byte(`{"caffeine": true}`), 0o644); err != nil {
		t.Fatal(err)
	}
	f.create = []byte(`{"id": 99}`)
	out, err := s.Restore(nil)
	if err != nil {
		t.Fatal(err)
	}
	m := out.(map[string]any)
	if m["inhibit"] != true || m["id"] != 99 {
		t.Fatalf("got %v", m)
	}
}

func TestRestoreRetriesUntilAxctlReady(t *testing.T) {
	s, f := newTestService(t)
	if err := os.WriteFile(s.paths.StatesFile(), []byte(`{"caffeine": true}`), 0o644); err != nil {
		t.Fatal(err)
	}
	restoreDeadline = time.Second
	retryInterval = 5 * time.Millisecond
	t.Cleanup(func() { restoreDeadline = 15 * time.Second; retryInterval = 250 * time.Millisecond })

	f.createErr = errors.New("socket not ready")
	go func() {
		time.Sleep(50 * time.Millisecond)
		f.mu.Lock()
		f.createErr = nil
		f.create = []byte(`{"id": 3}`)
		f.mu.Unlock()
	}()
	out, err := s.Restore(nil)
	if err != nil {
		t.Fatalf("restore should succeed after retry: %v", err)
	}
	if m := out.(map[string]any); m["id"] != 3 {
		t.Fatalf("got %v", m)
	}
}

func TestRestoreSkippedWhenNotPersisted(t *testing.T) {
	s, f := newTestService(t)
	out, _ := s.Restore(nil)
	if m := out.(map[string]any); m["inhibit"] != false {
		t.Fatalf("expected inhibit=false, got %v", m)
	}
	if len(f.calls) != 0 {
		t.Fatalf("axctl should not be called, got %v", f.calls)
	}
}

func TestCloseDestroysInhibitor(t *testing.T) {
	s, f := newTestService(t)
	f.create = []byte(`{"id": 5}`)
	if _, err := s.set(json.RawMessage(`{"inhibit":true}`)); err != nil {
		t.Fatal(err)
	}
	if err := s.Close(); err != nil {
		t.Fatal(err)
	}
	if len(f.calls) < 2 || f.calls[len(f.calls)-1][1] != "idle-inhibitor-destroy" {
		t.Fatalf("expected destroy call, got %v", f.calls)
	}
	if s.snapshotID() != 0 {
		t.Fatalf("id should be 0 after Close")
	}
}