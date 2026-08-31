package preset

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"ambxst/backend/pkg/paths"
)

// makePresetRoot arranges the directory layout the service expects:
//   - userDir = t.TempDir() — service reads <ConfigDir>/presets from it.
//   - shellDir = t.TempDir() with assets/presets/ inside it.
// Returns ConfigDir and ShellSourceDir-like values.
func makePresetRoot(t *testing.T) (userConfigDir string) {
	t.Helper()
	userConfigDir = t.TempDir()
	if err := os.MkdirAll(filepath.Join(userConfigDir, "presets"), 0o755); err != nil {
		t.Fatal(err)
	}
	return
}

func writePresetFiles(t *testing.T, dir string, files map[string]string) {
	t.Helper()
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	for n, content := range files {
		if err := os.WriteFile(filepath.Join(dir, n), []byte(content), 0o644); err != nil {
			t.Fatal(err)
		}
	}
}

// makeShellAssets arranges <dir>/assets/presets and returns dir itself so
// FindShellSource can be coerced via AMBXST_SHELL.
func makeShellAssets(t *testing.T) string {
	t.Helper()
	src := t.TempDir()
	if err := os.MkdirAll(filepath.Join(src, "assets", "presets"), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("AMBXST_SHELL", src)
	if err := os.WriteFile(filepath.Join(src, "shell.qml"), []byte("// stub"), 0o644); err != nil {
		t.Fatal(err)
	}
	return src
}

func TestScanFindsOfficialAndUser(t *testing.T) {
	userConfigDir := makePresetRoot(t)
	shellAssets := makeShellAssets(t)

	writePresetFiles(t, filepath.Join(userConfigDir, "presets", "MyCustom"), map[string]string{
		"theme.json": "{}",
		"bar.json":   "{}",
		"info.json":  `{"author": "Alice"}`,
	})
	writePresetFiles(t, filepath.Join(shellAssets, "assets", "presets", "Ambxst Default"), map[string]string{
		"theme.json": "{}",
		"bar.json":   "{}",
		"info.json":  `{"author": "Ambxst"}`,
		// Excluded file — must not appear in ConfigFiles.
		"system.json": "{}",
	})

	svc := &Service{paths: &paths.Paths{ConfigDir: userConfigDir}}
	got := svc.scan()
	if len(got) != 2 {
		t.Fatalf("expected 2 presets, got %d: %+v", len(got), got)
	}

	byName := map[string]Preset{}
	for _, p := range got {
		byName[p.Name] = p
	}
	if byName["MyCustom"].Official {
		t.Error("MyCustom should not be official")
	}
	if byName["MyCustom"].Author != "Alice" {
		t.Errorf("MyCustom author mismatch: %s", byName["MyCustom"].Author)
	}
	if !byName["Ambxst Default"].Official {
		t.Error("Ambxst Default should be official")
	}
	for _, f := range byName["Ambxst Default"].ConfigFiles {
		base := strings.TrimSuffix(f, ".js")
		if base == "system" || base == "ai" || base == "prefix" || base == "weather" {
			t.Errorf("excluded file leaked into ConfigFiles: %s", f)
		}
	}
}

func TestScanIgnoresInfoOnly(t *testing.T) {
	userConfigDir := makePresetRoot(t)
	makeShellAssets(t)
	if err := os.MkdirAll(filepath.Join(userConfigDir, "presets", "Blank"), 0o755); err != nil {
		t.Fatal(err)
	}
	_ = os.WriteFile(filepath.Join(userConfigDir, "presets", "Blank", "info.json"),
		[]byte(`{"author":"X"}`), 0o644)

	svc := &Service{paths: &paths.Paths{ConfigDir: userConfigDir}}
	got := svc.scan()
	if len(got) != 0 {
		t.Fatalf("info-only folder should produce 0 presets, got %d", len(got))
	}
}

func TestScanSortsAlphabeticallyWithinBucket(t *testing.T) {
	userConfigDir := makePresetRoot(t)
	makeShellAssets(t)
	for _, name := range []string{"Zeta", "Alpha", "Mid"} {
		writePresetFiles(t, filepath.Join(userConfigDir, "presets", name), map[string]string{
			"theme.json": "{}",
		})
	}

	svc := &Service{paths: &paths.Paths{ConfigDir: userConfigDir}}
	got := svc.scan()
	want := []string{"Alpha", "Mid", "Zeta"}
	gotNames := make([]string, 0, len(got))
	for _, p := range got {
		gotNames = append(gotNames, p.Name)
	}
	if !equal(gotNames, want) {
		t.Fatalf("sort mismatch: got %v, want %v", gotNames, want)
	}
}

func TestScanOfficialFirstThenUser(t *testing.T) {
	userConfigDir := makePresetRoot(t)
	shellAssets := makeShellAssets(t)
	for _, name := range []string{"BUser", "AUser"} {
		writePresetFiles(t, filepath.Join(userConfigDir, "presets", name), map[string]string{
			"theme.json": "{}",
		})
	}
	for _, name := range []string{"ZOff", "AOff"} {
		writePresetFiles(t, filepath.Join(shellAssets, "assets", "presets", name), map[string]string{
			"theme.json": "{}",
		})
	}

	svc := &Service{paths: &paths.Paths{ConfigDir: userConfigDir}}
	got := svc.scan()
	if len(got) != 4 {
		t.Fatalf("expected 4 presets, got %d", len(got))
	}
	if !got[0].Official || got[0].Name != "AOff" {
		t.Errorf("first preset should be AOff (official, alpha): %+v", got[0])
	}
	if !got[1].Official || got[1].Name != "ZOff" {
		t.Errorf("second preset should be ZOff (official, alpha): %+v", got[1])
	}
	if got[2].Official || got[2].Name != "AUser" {
		t.Errorf("third preset should be AUser: %+v", got[2])
	}
}

func TestLoadUnknownReturnsError(t *testing.T) {
	userConfigDir := makePresetRoot(t)
	makeShellAssets(t)
	svc := &Service{paths: &paths.Paths{ConfigDir: userConfigDir}}
	res, err := svc.load(json.RawMessage(`{"name":"missing"}`))
	if err != nil {
		t.Fatal(err)
	}
	m, _ := res.(map[string]any)
	if ok, _ := m["ok"].(bool); ok {
		t.Error("expected ok=false for unknown preset")
	}
	if _, present := m["error"]; !present {
		t.Error("expected error key in response")
	}
}

func equal(a, b []string) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}
