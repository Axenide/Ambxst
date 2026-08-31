package paths

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func TestFindShellSourcePrefersActiveGeneration(t *testing.T) {
	root := t.TempDir()
	base := filepath.Join(root, "base")
	t.Setenv("HOME", root)
	t.Setenv("XDG_DATA_HOME", filepath.Join(root, "data"))
	t.Setenv("AMBXST_SHELL", base)
	t.Setenv("AMBXST_MODS_DISABLED", "")
	p := New()
	active := filepath.Join(p.ModGenerationsDir(), "generation")
	for _, directory := range []string{base, active} {
		if err := os.MkdirAll(directory, 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(directory, "shell.qml"), []byte("ShellRoot {}\n"), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	if err := os.WriteFile(filepath.Join(base, "version"), []byte("1.2.5\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	metadata, err := json.Marshal(modGenerationMetadata{
		ID:          filepath.Base(active),
		BasePath:    base,
		BaseVersion: "1.2.5",
	})
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(active, ".ambxst-generation.json"), metadata, 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Dir(p.ModStateFile()), 0o755); err != nil {
		t.Fatal(err)
	}
	state, err := json.Marshal(modStateSource{ActiveGeneration: filepath.Base(active)})
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(p.ModStateFile(), state, 0o644); err != nil {
		t.Fatal(err)
	}
	if got := FindShellSource(); got != active {
		t.Fatalf("FindShellSource = %q, want %q", got, active)
	}

	if err := os.WriteFile(filepath.Join(base, "version"), []byte("1.3.0\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if got := FindShellSource(); got != base {
		t.Fatalf("stale generation source = %q, want %q", got, base)
	}

	t.Setenv("AMBXST_MODS_DISABLED", "1")
	if got := FindShellSource(); got != base {
		t.Fatalf("disabled mod source = %q, want %q", got, base)
	}
}
