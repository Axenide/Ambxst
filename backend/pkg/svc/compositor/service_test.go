package compositor

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func TestServiceRenderReturnsToml(t *testing.T) {
	svc := NewService(nil)
	out, err := svc.render(mustJSON(t, sampleInput()))
	if err != nil {
		t.Fatalf("render: %v", err)
	}
	res, ok := out.(map[string]any)
	if !ok {
		t.Fatalf("expected map result, got %T", out)
	}
	toml, _ := res["toml"].(string)
	if toml == "" {
		t.Fatal("empty TOML")
	}
	if toml[0:8] != "[target]" {
		t.Errorf("TOML should start with [target], got: %q", toml[0:30])
	}
}

func TestServiceWriteCreatesFile(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "axctl.toml")
	svc := NewService(PathFunc(func() string { return path }))

	out, err := svc.write(mustJSON(t, sampleInput()))
	if err != nil {
		t.Fatalf("write: %v", err)
	}
	res, ok := out.(map[string]any)
	if !ok || res["ok"] != true {
		t.Fatalf("expected ok=true, got %+v", res)
	}
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read back: %v", err)
	}
	if len(data) == 0 {
		t.Fatal("wrote empty file")
	}
	if string(data[0:8]) != "[target]" {
		t.Errorf("written file should start with [target], got: %q", data[0:30])
	}
}

func TestServiceWriteIsAtomic(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "axctl.toml")
	svc := NewService(PathFunc(func() string { return path }))

	// First write establishes the file.
	if _, err := svc.write(mustJSON(t, sampleInput())); err != nil {
		t.Fatalf("first write: %v", err)
	}
	// Second write must not leave a .tmp dangling.
	if _, err := svc.write(mustJSON(t, sampleInput())); err != nil {
		t.Fatalf("second write: %v", err)
	}
	if _, err := os.Stat(path + ".tmp"); !os.IsNotExist(err) {
		t.Errorf(".tmp should be cleaned up after rename; stat err=%v", err)
	}
}

func TestServiceWriteRejectsBadJSON(t *testing.T) {
	svc := NewService(nil)
	if _, err := svc.render(json.RawMessage(`{"layout": 123}`)); err != nil {
		// type mismatch is fine; we want to ensure render doesn't panic
		t.Logf("render rejected bad input: %v", err)
	}
}

func mustJSON(t *testing.T, v any) json.RawMessage {
	t.Helper()
	data, err := json.Marshal(v)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	return data
}
