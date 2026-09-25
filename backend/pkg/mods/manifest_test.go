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

func TestManifestRejectsNegativeSettingsSection(t *testing.T) {
	root := t.TempDir()
	writeTestFile(t, filepath.Join(root, "payload.qml"), "Item {}\n")
	manifest := Manifest{
		ManifestVersion: APIVersion,
		ID:              "example.mod",
		Name:            "Example",
		Version:         "1.0.0",
		SettingsMenu:    &SettingsMenuRef{Section: -1, Index: -2},
		Operations: []Operation{{
			Type: "overlay", Source: "payload.qml", Target: "payload.qml",
		}},
	}
	if err := manifest.Validate(root); err == nil {
		t.Fatal("expected a negative settings section to fail validation")
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

func TestLoadManifestKeepsUnknownFields(t *testing.T) {
	root := t.TempDir()
	manifest := `{
	  "manifestVersion": 1,
	  "id": "example.future",
	  "name": "Future fixture",
	  "version": "1.0.0",
	  "sponsorUrl": "https://example.invalid",
	  "operations": [{"type": "overlay", "source": "Feature.qml", "target": "Feature.qml"}]
	}`
	if err := os.WriteFile(filepath.Join(root, "Feature.qml"), []byte("Item {}\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(root, ManifestFile), []byte(manifest), 0o644); err != nil {
		t.Fatal(err)
	}
	loaded, err := LoadManifest(root)
	if err != nil {
		t.Fatalf("a package using a newer manifest key was rejected: %v", err)
	}
	if len(loaded.UnknownFields) != 1 || loaded.UnknownFields[0] != "sponsorUrl" {
		t.Fatalf("the unknown key was not reported: %#v", loaded.UnknownFields)
	}
}

func TestLoadManifestDetectsLegacySettingsMenu(t *testing.T) {
	root := t.TempDir()
	patch := `diff --git a/modules/widgets/dashboard/controls/SettingsTab.qml b/modules/widgets/dashboard/controls/SettingsTab.qml
--- a/modules/widgets/dashboard/controls/SettingsTab.qml
+++ b/modules/widgets/dashboard/controls/SettingsTab.qml
@@ -1,2 +1,4 @@
 items: [
+    { label: "Calendar", section:11 },
+    { component: "CalendarPanel.qml", section: 11 },
 ]
`
	writeTestFile(t, filepath.Join(root, "feature.patch"), patch)
	writeManifest := `{
  "manifestVersion": 1,
  "id": "example.legacy",
  "name": "Legacy settings panel",
  "version": "1.0.0",
  "operations": [{"type": "patch", "source": "feature.patch"}]
}`
	writeTestFile(t, filepath.Join(root, ManifestFile), writeManifest)

	manifest, err := LoadManifest(root)
	if err != nil {
		t.Fatal(err)
	}
	menus := settingsMenusForManifest(manifest)
	if !manifest.SettingsMenuDetected || len(menus) != 1 || menus[0].Section != 11 || menus[0].Index != -2 {
		t.Fatalf("legacy settings menu was not detected: %#v", manifest)
	}
}

func TestLoadManifestDetectsMultipleLegacySettingsMenus(t *testing.T) {
	root := t.TempDir()
	patch := `diff --git a/modules/widgets/dashboard/controls/SettingsTab.qml b/modules/widgets/dashboard/controls/SettingsTab.qml
--- a/modules/widgets/dashboard/controls/SettingsTab.qml
+++ b/modules/widgets/dashboard/controls/SettingsTab.qml
@@ -1,2 +1,6 @@
 items: [
+    { label: "First", section: 11 },
+    { component: "FirstPanel.qml", section: 11 },
+    { label: "Second", section: 12 },
+    { component: "SecondPanel.qml", section: 12 },
 ]
`
	writeTestFile(t, filepath.Join(root, "feature.patch"), patch)
	writeTestFile(t, filepath.Join(root, ManifestFile), `{
  "manifestVersion": 1,
  "id": "example.multiple",
  "name": "Multiple settings panels",
  "version": "1.0.0",
  "operations": [{"type": "patch", "source": "feature.patch"}]
}`)

	manifest, err := LoadManifest(root)
	if err != nil {
		t.Fatal(err)
	}
	menus := settingsMenusForManifest(manifest)
	if len(menus) != 2 || menus[0] != (SettingsMenuRef{Section: 11, Index: -3}) ||
		menus[1] != (SettingsMenuRef{Section: 12, Index: -2}) {
		t.Fatalf("multiple settings menus were not detected as a group: %#v", menus)
	}
}
