package mods

import (
	"os"
	"path/filepath"
	"testing"
)

func TestManifestRejectsUnsafeOverlayTarget(t *testing.T) {
	root := t.TempDir()
	writeTestFile(t, filepath.Join(root, "payload.qml"), "Item {}\n")
	manifest := Manifest{
		ManifestVersion: APIVersion,
		ID:              "example.mod",
		Name:            "Example",
		Version:         "1.0.0",
		Operations: []Operation{{
			Type:   "overlay",
			Source: "payload.qml",
			Target: "../shell.qml",
		}},
	}
	if err := manifest.Validate(root); err == nil {
		t.Fatal("expected unsafe target to fail validation")
	}
}

func TestManifestRejectsUndeclaredDependencySource(t *testing.T) {
	root := t.TempDir()
	writeTestFile(t, filepath.Join(root, "payload.qml"), "Item {}\n")
	manifest := Manifest{
		ManifestVersion:   APIVersion,
		ID:                "example.mod",
		Name:              "Example",
		Version:           "1.0.0",
		DependencySources: map[string]string{"example.base": "https://example.test/base.git"},
		Operations: []Operation{{
			Type: "overlay", Source: "payload.qml", Target: "payload.qml",
		}},
	}
	if err := manifest.Validate(root); err == nil {
		t.Fatal("expected undeclared dependency source to fail validation")
	}
}

func TestPatchTargets(t *testing.T) {
	path := filepath.Join(t.TempDir(), "change.patch")
	writeTestFile(t, path, "--- a/one.qml\n+++ b/one.qml\n@@ -1 +1 @@\n-old\n+new\n--- /dev/null\n+++ b/two.qml\n@@ -0,0 +1 @@\n+new\n")
	targets, err := patchTargets(path)
	if err != nil {
		t.Fatal(err)
	}
	if len(targets) != 2 || targets[0] != "one.qml" || targets[1] != "two.qml" {
		t.Fatalf("unexpected patch targets: %#v", targets)
	}
}

func TestCompactPlayerVolumeScrollExample(t *testing.T) {
	root := filepath.Join("..", "..", "..", "examples", "mods", "compact-player-volume-scroll")
	manifest, err := LoadManifest(root)
	if err != nil {
		t.Fatal(err)
	}
	if manifest.ID != "community.compact-player-volume-scroll" {
		t.Fatalf("unexpected example id %q", manifest.ID)
	}
	files, err := manifest.AffectedFiles(root)
	if err != nil {
		t.Fatal(err)
	}
	if len(files) != 1 || files[0] != "modules/widgets/defaultview/CompactPlayer.qml" {
		t.Fatalf("unexpected example targets: %#v", files)
	}
}

func writeTestFile(t *testing.T, path, content string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
}
