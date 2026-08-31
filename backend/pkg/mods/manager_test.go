package mods

import (
	"archive/tar"
	"archive/zip"
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"testing"

	"ambxst/backend/pkg/paths"
)

func TestManagerInstallEnableDisable(t *testing.T) {
	root := t.TempDir()
	base := filepath.Join(root, "base")
	writeTestFile(t, filepath.Join(base, "shell.qml"), "ShellRoot {}\n")
	writeTestFile(t, filepath.Join(base, "version"), "1.2.5\n")
	writeTestFile(t, filepath.Join(base, "assets", "ambxst", "icon.svg"), "<svg/>\n")
	t.Setenv("AMBXST_SHELL", base)
	t.Setenv("AMBXST_MODS_DISABLED", "1")

	packageRoot := filepath.Join(root, "package")
	writeTestFile(t, filepath.Join(packageRoot, "payload", "Feature.qml"), "Item {}\n")
	manifest := Manifest{
		ManifestVersion: APIVersion,
		ID:              "example.feature",
		Name:            "Example feature",
		Version:         "1.0.0",
		Compatibility: Compatibility{
			API:    APIVersion,
			Ambxst: ">=1.2.0 <1.3.0",
		},
		Operations: []Operation{{
			Type:   "overlay",
			Source: "payload/Feature.qml",
			Target: "modules/example/Feature.qml",
		}},
	}
	data, err := json.Marshal(manifest)
	if err != nil {
		t.Fatal(err)
	}
	writeTestFile(t, filepath.Join(packageRoot, ManifestFile), string(data))

	p := &paths.Paths{
		ConfigDir: filepath.Join(root, "config"),
		DataDir:   filepath.Join(root, "data"),
		StateDir:  filepath.Join(root, "state"),
		CacheDir:  filepath.Join(root, "cache"),
	}
	manager := NewManager(p)
	status, err := manager.Install(packageRoot)
	if err != nil {
		t.Fatal(err)
	}
	if len(status.Mods) != 1 || status.Mods[0].Enabled {
		t.Fatalf("unexpected install status: %#v", status.Mods)
	}

	status, err = manager.SetEnabled("example.feature", true)
	if err != nil {
		t.Fatal(err)
	}
	if status.ActiveGeneration == "" || !status.Mods[0].Enabled {
		t.Fatalf("mod was not activated: %#v", status)
	}
	activePath := filepath.Join(p.ModGenerationsDir(), status.ActiveGeneration)
	if _, err := os.Stat(filepath.Join(activePath, "modules", "example", "Feature.qml")); err != nil {
		t.Fatalf("generation does not contain the overlay: %v", err)
	}
	if _, err := os.Stat(filepath.Join(activePath, "assets", "ambxst", "icon.svg")); err != nil {
		t.Fatalf("base asset directory was omitted: %v", err)
	}
	if _, err := os.Stat(p.ModPendingActivationFile()); err != nil {
		t.Fatalf("activation was not marked pending: %v", err)
	}
	writeTestFile(t, filepath.Join(base, "version"), "1.2.6\n")
	status, err = manager.Status()
	if err != nil {
		t.Fatal(err)
	}
	if status.GenerationCurrent || status.GenerationError == "" {
		t.Fatalf("stale generation was not reported: %#v", status)
	}
	if manager.HasPendingActivation() {
		t.Fatal("stale generation retained a startup health check")
	}

	status, err = manager.SetEnabled("example.feature", false)
	if err != nil {
		t.Fatal(err)
	}
	if status.ActiveGeneration != "" || status.Mods[0].Enabled {
		t.Fatalf("mod was not disabled: %#v", status)
	}
	if _, err := os.Stat(p.ModPendingActivationFile()); !os.IsNotExist(err) {
		t.Fatalf("pending activation still exists: %v", err)
	}
}

func TestManagerRecoversFailedActivation(t *testing.T) {
	root := t.TempDir()
	base := filepath.Join(root, "base")
	writeTestFile(t, filepath.Join(base, "shell.qml"), "ShellRoot {}\n")
	writeTestFile(t, filepath.Join(base, "version"), "1.2.5\n")
	t.Setenv("AMBXST_SHELL", base)

	packageRoot := filepath.Join(root, "package")
	writeTestFile(t, filepath.Join(packageRoot, "Feature.qml"), "Item {}\n")
	manifest := Manifest{
		ManifestVersion: APIVersion,
		ID:              "example.recovery",
		Name:            "Recovery fixture",
		Version:         "1.0.0",
		Operations: []Operation{{
			Type: "overlay", Source: "Feature.qml", Target: "Feature.qml",
		}},
	}
	data, _ := json.Marshal(manifest)
	writeTestFile(t, filepath.Join(packageRoot, ManifestFile), string(data))

	p := &paths.Paths{
		ConfigDir: filepath.Join(root, "config"),
		DataDir:   filepath.Join(root, "data"),
		StateDir:  filepath.Join(root, "state"),
		CacheDir:  filepath.Join(root, "cache"),
	}
	manager := NewManager(p)
	if _, err := manager.Install(packageRoot); err != nil {
		t.Fatal(err)
	}
	if _, err := manager.SetEnabled("example.recovery", true); err != nil {
		t.Fatal(err)
	}
	recovered, err := manager.RecoverFailedActivation()
	if err != nil {
		t.Fatal(err)
	}
	if !recovered {
		t.Fatal("pending activation was not recovered")
	}
	status, err := manager.Status()
	if err != nil {
		t.Fatal(err)
	}
	if status.ActiveGeneration != "" || status.Mods[0].Enabled {
		t.Fatalf("failed generation remained active: %#v", status)
	}
}

func TestTopologicalOrderUsesDependenciesBeforeUserOrder(t *testing.T) {
	installed := []InstalledMod{
		{ID: "child", Order: 0, Enabled: true},
		{ID: "base", Order: 1, Enabled: true},
	}
	manifests := map[string]Manifest{
		"child": {ID: "child", Dependencies: []string{"base"}},
		"base":  {ID: "base"},
	}
	ordered, err := topologicalOrder(installed, manifests)
	if err != nil {
		t.Fatal(err)
	}
	if len(ordered) != 2 || ordered[0] != "base" || ordered[1] != "child" {
		t.Fatalf("unexpected order: %#v", ordered)
	}
}

func TestParseGitHubTreeSource(t *testing.T) {
	repository, ref, subdirectory, ok := parseGitHubTreeSource(
		"https://github.com/flathead/ambxst-mods/tree/main/packages/i18n",
	)
	if !ok {
		t.Fatal("expected GitHub tree URL to be recognized")
	}
	if repository != "https://github.com/flathead/ambxst-mods.git" || ref != "main" || subdirectory != "packages/i18n" {
		t.Fatalf("unexpected GitHub tree source: %q %q %q", repository, ref, subdirectory)
	}
	if _, _, _, ok := parseGitHubTreeSource("https://example.com/owner/repo/tree/main/package"); ok {
		t.Fatal("non-GitHub URL was recognized as a tree source")
	}
}

func TestGitHubTreeSourceIntegration(t *testing.T) {
	if os.Getenv("AMBXST_TEST_GITHUB") != "1" {
		t.Skip("set AMBXST_TEST_GITHUB=1 to run network integration tests")
	}
	root := t.TempDir()
	base := filepath.Join(root, "base")
	writeTestFile(t, filepath.Join(base, "shell.qml"), "ShellRoot {}\n")
	writeTestFile(t, filepath.Join(base, "version"), "1.2.5\n")
	t.Setenv("AMBXST_SHELL", base)

	manager := NewManager(testPaths(root))
	status, err := manager.Install("https://github.com/flathead/ambxst-mods/tree/main/packages/i18n")
	if err != nil {
		t.Fatal(err)
	}
	if len(status.Mods) != 1 || status.Mods[0].ID != "community.i18n" || status.Mods[0].SourceType != "git-subdir" {
		t.Fatalf("unexpected tree install status: %#v", status.Mods)
	}
}

func TestManagerInstallsAndEnablesRequiredMods(t *testing.T) {
	root := t.TempDir()
	base := filepath.Join(root, "base")
	writeTestFile(t, filepath.Join(base, "shell.qml"), "ShellRoot {}\n")
	writeTestFile(t, filepath.Join(base, "version"), "1.2.5\n")
	t.Setenv("AMBXST_SHELL", base)
	t.Setenv("AMBXST_MODS_DISABLED", "1")

	dependencyRoot := writeOverlayPackage(t, root, "dependency", "example.i18n", "I18n.qml")
	parentRoot := filepath.Join(root, "parent")
	writeTestFile(t, filepath.Join(parentRoot, "Feature.qml"), "Item {}\n")
	parentManifest := Manifest{
		ManifestVersion:   APIVersion,
		ID:                "example.feature",
		Name:              "Feature",
		Version:           "1.0.0",
		Dependencies:      []string{"example.i18n"},
		DependencySources: map[string]string{"example.i18n": dependencyRoot},
		Operations: []Operation{{
			Type: "overlay", Source: "Feature.qml", Target: "Feature.qml",
		}},
	}
	data, err := json.Marshal(parentManifest)
	if err != nil {
		t.Fatal(err)
	}
	writeTestFile(t, filepath.Join(parentRoot, ManifestFile), string(data))

	manager := NewManager(testPaths(root))
	status, err := manager.Install(parentRoot)
	if err != nil {
		t.Fatal(err)
	}
	if len(status.Mods[0].DependencyState) != 1 || status.Mods[0].DependencyState[0].Installed {
		t.Fatalf("missing dependency was not reported: %#v", status.Mods[0].DependencyState)
	}

	status, err = manager.InstallDependencies("example.feature")
	if err != nil {
		t.Fatal(err)
	}
	if len(status.Mods) != 2 || status.Mods[0].Enabled || !status.Mods[1].Enabled {
		t.Fatalf("unexpected dependency state: %#v", status.Mods)
	}
	if !status.Mods[0].DependencyState[0].Installed || !status.Mods[0].DependencyState[0].Enabled {
		t.Fatalf("ready dependency was not reported: %#v", status.Mods[0].DependencyState)
	}
	active := filepath.Join(manager.paths.ModGenerationsDir(), status.ActiveGeneration)
	if _, err := os.Stat(filepath.Join(active, "I18n.qml")); err != nil {
		t.Fatalf("dependency was not composed: %v", err)
	}

	status, err = manager.SetEnabled("example.feature", true)
	if err != nil {
		t.Fatal(err)
	}
	if !status.Mods[0].Enabled || !status.Mods[1].Enabled {
		t.Fatalf("parent and dependency were not enabled: %#v", status.Mods)
	}
}

func TestManagerRejectsDependencyWithUnexpectedID(t *testing.T) {
	root := t.TempDir()
	base := filepath.Join(root, "base")
	writeTestFile(t, filepath.Join(base, "shell.qml"), "ShellRoot {}\n")
	writeTestFile(t, filepath.Join(base, "version"), "1.2.5\n")
	t.Setenv("AMBXST_SHELL", base)

	wrongRoot := writeOverlayPackage(t, root, "wrong", "example.wrong", "Wrong.qml")
	parentRoot := filepath.Join(root, "parent")
	writeTestFile(t, filepath.Join(parentRoot, "Feature.qml"), "Item {}\n")
	manifest := Manifest{
		ManifestVersion:   APIVersion,
		ID:                "example.feature",
		Name:              "Feature",
		Version:           "1.0.0",
		Dependencies:      []string{"example.required"},
		DependencySources: map[string]string{"example.required": wrongRoot},
		Operations: []Operation{{
			Type: "overlay", Source: "Feature.qml", Target: "Feature.qml",
		}},
	}
	data, _ := json.Marshal(manifest)
	writeTestFile(t, filepath.Join(parentRoot, ManifestFile), string(data))

	manager := NewManager(testPaths(root))
	if _, err := manager.Install(parentRoot); err != nil {
		t.Fatal(err)
	}
	if _, err := manager.InstallDependencies("example.feature"); err == nil {
		t.Fatal("expected mismatched dependency id to fail")
	}
	status, err := manager.Status()
	if err != nil {
		t.Fatal(err)
	}
	if len(status.Mods) != 1 || status.Mods[0].Enabled {
		t.Fatalf("failed dependency install changed state: %#v", status.Mods)
	}
}

func TestManagerComposesNonOverlappingPatchesToSameFile(t *testing.T) {
	root := t.TempDir()
	base := filepath.Join(root, "base")
	writeTestFile(t, filepath.Join(base, "shell.qml"), "first\ntwo\nmiddle\nfour\nlast\n")
	writeTestFile(t, filepath.Join(base, "version"), "1.2.5\n")
	t.Setenv("AMBXST_SHELL", base)
	t.Setenv("AMBXST_MODS_DISABLED", "1")

	first := filepath.Join(root, "first")
	writePatchPackage(t, first, "example.first", "@@ -1,2 +1,2 @@\n-first\n+one\n two\n")
	second := filepath.Join(root, "second")
	writePatchPackage(t, second, "example.second", "@@ -4,2 +4,2 @@\n four\n-last\n+five\n")

	manager := NewManager(testPaths(root))
	if _, err := manager.Install(first); err != nil {
		t.Fatal(err)
	}
	if _, err := manager.Install(second); err != nil {
		t.Fatal(err)
	}
	if _, err := manager.SetEnabled("example.first", true); err != nil {
		t.Fatal(err)
	}
	status, err := manager.SetEnabled("example.second", true)
	if err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(filepath.Join(manager.paths.ModGenerationsDir(), status.ActiveGeneration, "shell.qml"))
	if err != nil {
		t.Fatal(err)
	}
	if string(data) != "one\ntwo\nmiddle\nfour\nfive\n" {
		t.Fatalf("patches were not composed in order: %q", data)
	}
}

func TestManagerMovesModToExactPosition(t *testing.T) {
	root := t.TempDir()
	base := filepath.Join(root, "base")
	writeTestFile(t, filepath.Join(base, "shell.qml"), "ShellRoot {}\n")
	writeTestFile(t, filepath.Join(base, "version"), "1.2.5\n")
	t.Setenv("AMBXST_SHELL", base)
	t.Setenv("AMBXST_MODS_DISABLED", "1")

	manager := NewManager(testPaths(root))
	for i, id := range []string{"example.first", "example.second", "example.third"} {
		packageRoot := writeOverlayPackage(t, root, id, id, fmt.Sprintf("Feature%d.qml", i))
		if _, err := manager.Install(packageRoot); err != nil {
			t.Fatal(err)
		}
		if _, err := manager.SetEnabled(id, true); err != nil {
			t.Fatal(err)
		}
	}

	status, err := manager.MoveTo("example.first", 2)
	if err != nil {
		t.Fatal(err)
	}
	want := []string{"example.second", "example.third", "example.first"}
	for i, mod := range status.Mods {
		if mod.ID != want[i] || mod.Order != i {
			t.Fatalf("unexpected order at %d: %#v", i, status.Mods)
		}
	}
}

func TestConsecutiveBuildsKeepLastKnownGoodGeneration(t *testing.T) {
	root := t.TempDir()
	base := filepath.Join(root, "base")
	writeTestFile(t, filepath.Join(base, "shell.qml"), "ShellRoot {}\n")
	writeTestFile(t, filepath.Join(base, "version"), "1.2.5\n")
	t.Setenv("AMBXST_SHELL", base)

	p := testPaths(root)
	manager := NewManager(p)
	first := writeOverlayPackage(t, root, "first", "example.first", "First.qml")
	second := writeOverlayPackage(t, root, "second", "example.second", "Second.qml")
	if _, err := manager.Install(first); err != nil {
		t.Fatal(err)
	}
	if _, err := manager.Install(second); err != nil {
		t.Fatal(err)
	}
	if _, err := manager.SetEnabled("example.first", true); err != nil {
		t.Fatal(err)
	}
	status, err := manager.SetEnabled("example.second", true)
	if err != nil {
		t.Fatal(err)
	}
	if status.PreviousGeneration != "" {
		t.Fatalf("untested generation became a rollback target: %#v", status)
	}
	recovered, err := manager.RecoverFailedActivation()
	if err != nil || !recovered {
		t.Fatalf("recover pending generation: recovered=%v err=%v", recovered, err)
	}
	status, err = manager.Status()
	if err != nil {
		t.Fatal(err)
	}
	if status.ActiveGeneration != "" || status.Mods[0].Enabled || status.Mods[1].Enabled {
		t.Fatalf("recovery did not restore the base generation: %#v", status)
	}
}

func TestRollbackDoesNotExposeUntestedGeneration(t *testing.T) {
	root := t.TempDir()
	base := filepath.Join(root, "base")
	writeTestFile(t, filepath.Join(base, "shell.qml"), "ShellRoot {}\n")
	writeTestFile(t, filepath.Join(base, "version"), "1.2.5\n")
	t.Setenv("AMBXST_SHELL", base)

	p := testPaths(root)
	manager := NewManager(p)
	first := writeOverlayPackage(t, root, "first", "example.first", "First.qml")
	second := writeOverlayPackage(t, root, "second", "example.second", "Second.qml")
	if _, err := manager.Install(first); err != nil {
		t.Fatal(err)
	}
	if _, err := manager.Install(second); err != nil {
		t.Fatal(err)
	}
	firstStatus, err := manager.SetEnabled("example.first", true)
	if err != nil {
		t.Fatal(err)
	}
	if err := manager.MarkHealthy(); err != nil {
		t.Fatal(err)
	}
	if _, err := manager.SetEnabled("example.second", true); err != nil {
		t.Fatal(err)
	}
	status, err := manager.Rollback()
	if err != nil {
		t.Fatal(err)
	}
	if status.ActiveGeneration != firstStatus.ActiveGeneration || status.PreviousGeneration != "" {
		t.Fatalf("untested generation remained available: %#v", status)
	}
	if _, err := os.Stat(p.ModPendingActivationFile()); !os.IsNotExist(err) {
		t.Fatalf("rollback left a pending activation: %v", err)
	}
}

func TestBaseActivationCanRecoverKnownGoodGeneration(t *testing.T) {
	root := t.TempDir()
	base := filepath.Join(root, "base")
	writeTestFile(t, filepath.Join(base, "shell.qml"), "ShellRoot {}\n")
	writeTestFile(t, filepath.Join(base, "version"), "1.2.5\n")
	t.Setenv("AMBXST_SHELL", base)

	p := testPaths(root)
	manager := NewManager(p)
	packageRoot := writeOverlayPackage(t, root, "source", "example.base-recovery", "Feature.qml")
	if _, err := manager.Install(packageRoot); err != nil {
		t.Fatal(err)
	}
	active, err := manager.SetEnabled("example.base-recovery", true)
	if err != nil {
		t.Fatal(err)
	}
	if err := manager.MarkHealthy(); err != nil {
		t.Fatal(err)
	}
	disabled, err := manager.SetEnabled("example.base-recovery", false)
	if err != nil {
		t.Fatal(err)
	}
	if disabled.ActiveGeneration != "" || !disabled.RestartRequired || !manager.HasPendingActivation() {
		t.Fatalf("base activation was not tracked: %#v", disabled)
	}
	recovered, err := manager.RecoverFailedActivation()
	if err != nil || !recovered {
		t.Fatalf("recover base activation: recovered=%v err=%v", recovered, err)
	}
	status, err := manager.Status()
	if err != nil {
		t.Fatal(err)
	}
	if status.ActiveGeneration != active.ActiveGeneration || !status.Mods[0].Enabled {
		t.Fatalf("known-good generation was not restored: %#v", status)
	}
}

func TestInstallZipArchiveAndPersistSettings(t *testing.T) {
	root := t.TempDir()
	packageRoot := filepath.Join(root, "source")
	writeTestFile(t, filepath.Join(packageRoot, "Feature.qml"), "Item {}\n")
	writeTestFile(t, filepath.Join(packageRoot, "settings.json"), `{
  "version": 1,
  "fields": [{"key":"limit","label":"Limit","type":"integer","default":3,"minimum":1,"maximum":5}]
}`)
	manifest := Manifest{
		ManifestVersion: APIVersion,
		ID:              "example.archive",
		Name:            "Archive fixture",
		Version:         "1.0.0",
		Settings:        &SettingsRef{Schema: "settings.json"},
		Operations: []Operation{{
			Type: "overlay", Source: "Feature.qml", Target: "Feature.qml",
		}},
	}
	data, err := json.Marshal(manifest)
	if err != nil {
		t.Fatal(err)
	}
	writeTestFile(t, filepath.Join(packageRoot, ManifestFile), string(data))

	archivePath := filepath.Join(root, "package.zip")
	archiveFile, err := os.Create(archivePath)
	if err != nil {
		t.Fatal(err)
	}
	zipWriter := zip.NewWriter(archiveFile)
	for _, name := range []string{ManifestFile, "Feature.qml", "settings.json"} {
		entry, err := zipWriter.Create("package/" + name)
		if err != nil {
			t.Fatal(err)
		}
		contents, err := os.ReadFile(filepath.Join(packageRoot, name))
		if err != nil {
			t.Fatal(err)
		}
		if _, err := entry.Write(contents); err != nil {
			t.Fatal(err)
		}
	}
	if err := zipWriter.Close(); err != nil {
		t.Fatal(err)
	}
	if err := archiveFile.Close(); err != nil {
		t.Fatal(err)
	}

	manager := NewManager(testPaths(root))
	status, err := manager.Install(archivePath)
	if err != nil {
		t.Fatal(err)
	}
	if len(status.Mods) != 1 || status.Mods[0].SourceType != "archive" {
		t.Fatalf("unexpected archive install status: %#v", status.Mods)
	}
	settings, err := manager.Settings("example.archive")
	if err != nil || settings.Values["limit"] != float64(3) {
		t.Fatalf("unexpected default settings: %#v err=%v", settings, err)
	}
	if _, err := manager.SetSetting("example.archive", "limit", float64(7)); err == nil {
		t.Fatal("out-of-range setting was accepted")
	}
	settings, err = manager.SetSetting("example.archive", "limit", float64(5))
	if err != nil || settings.Values["limit"] != float64(5) {
		t.Fatalf("setting was not persisted: %#v err=%v", settings, err)
	}
}

func TestUpdateLocalSourceRestoresPackageOnValidationFailure(t *testing.T) {
	root := t.TempDir()
	base := filepath.Join(root, "base")
	writeTestFile(t, filepath.Join(base, "shell.qml"), "ShellRoot {}\n")
	writeTestFile(t, filepath.Join(base, "version"), "1.2.5\n")
	t.Setenv("AMBXST_SHELL", base)

	packageRoot := filepath.Join(root, "source")
	writeTestFile(t, filepath.Join(packageRoot, "Feature.qml"), "Item { property int value: 1 }\n")
	writeManifest := func(id, version string) {
		manifest := Manifest{
			ManifestVersion: APIVersion,
			ID:              id,
			Name:            "Local update fixture",
			Version:         version,
			Operations: []Operation{{
				Type: "overlay", Source: "Feature.qml", Target: "Feature.qml",
			}},
		}
		data, err := json.Marshal(manifest)
		if err != nil {
			t.Fatal(err)
		}
		writeTestFile(t, filepath.Join(packageRoot, ManifestFile), string(data))
	}
	writeManifest("example.local-update", "1.0.0")

	manager := NewManager(testPaths(root))
	if _, err := manager.Install(packageRoot); err != nil {
		t.Fatal(err)
	}
	writeTestFile(t, filepath.Join(packageRoot, "Feature.qml"), "Item { property int value: 2 }\n")
	writeManifest("example.local-update", "1.1.0")
	status, err := manager.Update("example.local-update")
	if err != nil {
		t.Fatal(err)
	}
	if status.Mods[0].Version != "1.1.0" || status.RestartRequired {
		t.Fatalf("local update was not installed cleanly: %#v", status)
	}

	writeManifest("example.changed-id", "2.0.0")
	if _, err := manager.Update("example.local-update"); err == nil {
		t.Fatal("package id change was accepted")
	}
	status, err = manager.Status()
	if err != nil {
		t.Fatal(err)
	}
	if status.Mods[0].Version != "1.1.0" {
		t.Fatalf("failed update replaced the installed package: %#v", status.Mods[0])
	}
}

func TestPackageTarRejectsPathTraversal(t *testing.T) {
	var buffer bytes.Buffer
	writer := tar.NewWriter(&buffer)
	contents := []byte("unsafe")
	if err := writer.WriteHeader(&tar.Header{Name: "../outside", Mode: 0o644, Size: int64(len(contents))}); err != nil {
		t.Fatal(err)
	}
	if _, err := writer.Write(contents); err != nil {
		t.Fatal(err)
	}
	if err := writer.Close(); err != nil {
		t.Fatal(err)
	}
	if err := extractTar(&buffer, t.TempDir(), false, maxPackageFiles, maxPackageBytes); err == nil {
		t.Fatal("archive path traversal was accepted")
	}
}

func TestExtractTarAcceptsPAXHeaders(t *testing.T) {
	var buffer bytes.Buffer
	writer := tar.NewWriter(&buffer)
	if err := writer.WriteHeader(&tar.Header{
		Name:     "pax_global_header",
		Typeflag: tar.TypeXGlobalHeader,
		PAXRecords: map[string]string{
			"comment": "test revision",
		},
	}); err != nil {
		t.Fatal(err)
	}
	contents := []byte("Item {}\n")
	if err := writer.WriteHeader(&tar.Header{Name: "shell.qml", Mode: 0o644, Size: int64(len(contents))}); err != nil {
		t.Fatal(err)
	}
	if _, err := writer.Write(contents); err != nil {
		t.Fatal(err)
	}
	if err := writer.Close(); err != nil {
		t.Fatal(err)
	}

	destination := t.TempDir()
	if err := extractTar(&buffer, destination, true, 0, 0); err != nil {
		t.Fatalf("extract PAX archive: %v", err)
	}
	if data, err := os.ReadFile(filepath.Join(destination, "shell.qml")); err != nil || string(data) != string(contents) {
		t.Fatalf("unexpected extracted file: data=%q err=%v", data, err)
	}
}

func TestStatusKeepsInvalidPackageVisible(t *testing.T) {
	root := t.TempDir()
	base := filepath.Join(root, "base")
	writeTestFile(t, filepath.Join(base, "shell.qml"), "ShellRoot {}\n")
	writeTestFile(t, filepath.Join(base, "version"), "1.2.5\n")
	t.Setenv("AMBXST_SHELL", base)

	p := testPaths(root)
	manager := NewManager(p)
	packageRoot := writeOverlayPackage(t, root, "source", "example.invalid", "Feature.qml")
	if _, err := manager.Install(packageRoot); err != nil {
		t.Fatal(err)
	}
	if err := os.Remove(filepath.Join(p.ModPackagesDir(), "example.invalid", ManifestFile)); err != nil {
		t.Fatal(err)
	}
	status, err := manager.Status()
	if err != nil {
		t.Fatal(err)
	}
	if len(status.Mods) != 1 || status.Mods[0].Valid || status.Mods[0].Error == "" {
		t.Fatalf("invalid package was hidden: %#v", status.Mods)
	}
}

func TestStatusReportsCompatibilityWithoutActivating(t *testing.T) {
	root := t.TempDir()
	base := filepath.Join(root, "base")
	writeTestFile(t, filepath.Join(base, "shell.qml"), "ShellRoot {}\n")
	writeTestFile(t, filepath.Join(base, "version"), "1.2.5\n")
	t.Setenv("AMBXST_SHELL", base)

	packageRoot := filepath.Join(root, "source")
	writeTestFile(t, filepath.Join(packageRoot, "Feature.qml"), "Item {}\n")
	manifest := Manifest{
		ManifestVersion: APIVersion,
		ID:              "example.incompatible",
		Name:            "Incompatible fixture",
		Version:         "1.0.0",
		Compatibility:   Compatibility{Ambxst: ">=2.0.0"},
		Operations: []Operation{{
			Type: "overlay", Source: "Feature.qml", Target: "Feature.qml",
		}},
	}
	data, err := json.Marshal(manifest)
	if err != nil {
		t.Fatal(err)
	}
	writeTestFile(t, filepath.Join(packageRoot, ManifestFile), string(data))

	manager := NewManager(testPaths(root))
	status, err := manager.Install(packageRoot)
	if err != nil {
		t.Fatal(err)
	}
	if len(status.Mods) != 1 || !status.Mods[0].Valid || status.Mods[0].Compatible || status.Mods[0].CompatibilityError == "" {
		t.Fatalf("compatibility state was not reported: %#v", status.Mods)
	}
}

func testPaths(root string) *paths.Paths {
	return &paths.Paths{
		ConfigDir: filepath.Join(root, "config"),
		DataDir:   filepath.Join(root, "data"),
		StateDir:  filepath.Join(root, "state"),
		CacheDir:  filepath.Join(root, "cache"),
	}
}

func TestManagerComposesPatchesThatShareContext(t *testing.T) {
	root := t.TempDir()
	base := filepath.Join(root, "base")
	original := "first\ntwo\nmiddle\nfour\nlast\n"
	writeTestFile(t, filepath.Join(base, "shell.qml"), original)
	writeTestFile(t, filepath.Join(base, "version"), "1.2.5\n")
	t.Setenv("AMBXST_SHELL", base)
	t.Setenv("AMBXST_MODS_DISABLED", "1")

	first := filepath.Join(root, "first")
	writeDiffPackage(t, first, "example.first", original, "first\ntwo\nMIDDLE\nfour\nlast\n")
	second := filepath.Join(root, "second")
	writeDiffPackage(t, second, "example.second", original, "first\ntwo\nmiddle\nfour\nfive\n")

	manager := NewManager(testPaths(root))
	if _, err := manager.Install(first); err != nil {
		t.Fatal(err)
	}
	if _, err := manager.Install(second); err != nil {
		t.Fatal(err)
	}
	if _, err := manager.SetEnabled("example.first", true); err != nil {
		t.Fatal(err)
	}
	status, err := manager.SetEnabled("example.second", true)
	if err != nil {
		t.Fatalf("second mod was refused although both edits are independent: %v", err)
	}
	data, err := os.ReadFile(filepath.Join(manager.paths.ModGenerationsDir(), status.ActiveGeneration, "shell.qml"))
	if err != nil {
		t.Fatal(err)
	}
	if string(data) != "first\ntwo\nMIDDLE\nfour\nfive\n" {
		t.Fatalf("shared context was not merged: %q", data)
	}
	if _, err := os.Stat(filepath.Join(manager.paths.ModGenerationsDir(), status.ActiveGeneration, ".git")); !os.IsNotExist(err) {
		t.Fatal("the generation still carries the composition repository")
	}
}

func TestManagerStopsOnOverlappingPatches(t *testing.T) {
	root := t.TempDir()
	base := filepath.Join(root, "base")
	original := "first\ntwo\nmiddle\nfour\nlast\n"
	writeTestFile(t, filepath.Join(base, "shell.qml"), original)
	writeTestFile(t, filepath.Join(base, "version"), "1.2.5\n")
	t.Setenv("AMBXST_SHELL", base)
	t.Setenv("AMBXST_MODS_DISABLED", "1")

	first := filepath.Join(root, "first")
	writeDiffPackage(t, first, "example.first", original, "first\ntwo\nalpha\nfour\nlast\n")
	second := filepath.Join(root, "second")
	writeDiffPackage(t, second, "example.second", original, "first\ntwo\nbeta\nfour\nlast\n")

	manager := NewManager(testPaths(root))
	if _, err := manager.Install(first); err != nil {
		t.Fatal(err)
	}
	if _, err := manager.Install(second); err != nil {
		t.Fatal(err)
	}
	if _, err := manager.SetEnabled("example.first", true); err != nil {
		t.Fatal(err)
	}
	previous, err := manager.Status()
	if err != nil {
		t.Fatal(err)
	}
	if _, err := manager.SetEnabled("example.second", true); err == nil {
		t.Fatal("two mods rewriting the same line were composed")
	}
	current, err := manager.Status()
	if err != nil {
		t.Fatal(err)
	}
	if current.ActiveGeneration != previous.ActiveGeneration {
		t.Fatal("a failed composition replaced the active generation")
	}
}

func TestUntestedBaseRevisionWarnsInsteadOfBlocking(t *testing.T) {
	root := t.TempDir()
	base := filepath.Join(root, "base")
	writeTestFile(t, filepath.Join(base, "shell.qml"), "first\ntwo\nlast\n")
	writeTestFile(t, filepath.Join(base, "version"), "1.2.5\n")
	t.Setenv("AMBXST_SHELL", base)
	t.Setenv("AMBXST_MODS_DISABLED", "1")

	source := filepath.Join(root, "source")
	writeDiffPackage(t, source, "example.untested", "first\ntwo\nlast\n", "first\ntwo\nfive\n")
	manifestPath := filepath.Join(source, ManifestFile)
	data, err := os.ReadFile(manifestPath)
	if err != nil {
		t.Fatal(err)
	}
	var manifest Manifest
	if err := json.Unmarshal(data, &manifest); err != nil {
		t.Fatal(err)
	}
	manifest.Compatibility = Compatibility{
		API:               APIVersion,
		Ambxst:            ">=1.2.5 <1.3.0",
		TestedBaseCommits: []string{"0123456789012345678901234567890123456789"},
	}
	updated, err := json.Marshal(manifest)
	if err != nil {
		t.Fatal(err)
	}
	writeTestFile(t, manifestPath, string(updated))

	manager := NewManager(testPaths(root))
	if _, err := manager.Install(source); err != nil {
		t.Fatal(err)
	}
	status, err := manager.SetEnabled("example.untested", true)
	if err != nil {
		t.Fatalf("an untested base revision blocked the build: %v", err)
	}
	if status.ActiveGeneration == "" {
		t.Fatal("no generation was activated")
	}
	if len(status.Mods) != 1 || !status.Mods[0].Compatible || !status.Mods[0].Untested {
		t.Fatalf("the untested base was not reported: %#v", status.Mods)
	}
}

func TestManagerKeepsBothInsertionsAtTheSameAnchor(t *testing.T) {
	root := t.TempDir()
	base := filepath.Join(root, "base")
	original := "header\nanchor\nfooter\n"
	writeTestFile(t, filepath.Join(base, "shell.qml"), original)
	writeTestFile(t, filepath.Join(base, "version"), "1.2.5\n")
	t.Setenv("AMBXST_SHELL", base)
	t.Setenv("AMBXST_MODS_DISABLED", "1")

	first := filepath.Join(root, "first")
	writeDiffPackage(t, first, "example.first", original, "header\nanchor\nwidget one\nfooter\n")
	second := filepath.Join(root, "second")
	writeDiffPackage(t, second, "example.second", original, "header\nanchor\nwidget two\nfooter\n")

	manager := NewManager(testPaths(root))
	if _, err := manager.Install(first); err != nil {
		t.Fatal(err)
	}
	if _, err := manager.Install(second); err != nil {
		t.Fatal(err)
	}
	if _, err := manager.SetEnabled("example.first", true); err != nil {
		t.Fatal(err)
	}
	status, err := manager.SetEnabled("example.second", true)
	if err != nil {
		t.Fatalf("two independent insertions were refused: %v", err)
	}
	data, err := os.ReadFile(filepath.Join(manager.paths.ModGenerationsDir(), status.ActiveGeneration, "shell.qml"))
	if err != nil {
		t.Fatal(err)
	}
	if string(data) != "header\nanchor\nwidget one\nwidget two\nfooter\n" {
		t.Fatalf("load order did not decide the insertion order: %q", data)
	}
}

func writeDiffPackage(t *testing.T, root, id, before, after string) {
	t.Helper()
	repo := t.TempDir()
	run := func(args ...string) {
		cmd := exec.Command("git", args...)
		cmd.Dir = repo
		if output, err := cmd.CombinedOutput(); err != nil {
			t.Fatalf("git %v: %v: %s", args, err, output)
		}
	}
	run("init", "-q")
	run("config", "user.email", "test@example.com")
	run("config", "user.name", "Test")
	writeTestFile(t, filepath.Join(repo, "shell.qml"), before)
	run("add", "shell.qml")
	run("commit", "-q", "-m", "base")
	writeTestFile(t, filepath.Join(repo, "shell.qml"), after)
	diff := exec.Command("git", "diff")
	diff.Dir = repo
	patch, err := diff.Output()
	if err != nil {
		t.Fatal(err)
	}
	writeTestFile(t, filepath.Join(root, "patches", "change.patch"), string(patch))
	manifest := Manifest{
		ManifestVersion: APIVersion,
		ID:              id,
		Name:            id,
		Version:         "1.0.0",
		Operations: []Operation{{
			Type: "patch", Source: "patches/change.patch",
		}},
	}
	data, err := json.Marshal(manifest)
	if err != nil {
		t.Fatal(err)
	}
	writeTestFile(t, filepath.Join(root, ManifestFile), string(data))
}

func writeOverlayPackage(t *testing.T, root, directory, id, target string) string {
	t.Helper()
	packageRoot := filepath.Join(root, directory)
	writeTestFile(t, filepath.Join(packageRoot, target), "Item {}\n")
	manifest := Manifest{
		ManifestVersion: APIVersion,
		ID:              id,
		Name:            id,
		Version:         "1.0.0",
		Operations: []Operation{{
			Type: "overlay", Source: target, Target: target,
		}},
	}
	data, err := json.Marshal(manifest)
	if err != nil {
		t.Fatal(err)
	}
	writeTestFile(t, filepath.Join(packageRoot, ManifestFile), string(data))
	return packageRoot
}

func writePatchPackage(t *testing.T, root, id, hunk string) {
	t.Helper()
	patch := "diff --git a/shell.qml b/shell.qml\n--- a/shell.qml\n+++ b/shell.qml\n" + hunk
	writeTestFile(t, filepath.Join(root, "patches", "change.patch"), patch)
	manifest := Manifest{
		ManifestVersion: APIVersion,
		ID:              id,
		Name:            id,
		Version:         "1.0.0",
		Operations: []Operation{{
			Type: "patch", Source: "patches/change.patch",
		}},
	}
	data, err := json.Marshal(manifest)
	if err != nil {
		t.Fatal(err)
	}
	writeTestFile(t, filepath.Join(root, ManifestFile), string(data))
}

func TestGitHubDirectoryInstallRecordsRevision(t *testing.T) {
	if testing.Short() {
		t.Skip("network integration test")
	}
	root := t.TempDir()
	base := filepath.Join(root, "base")
	writeTestFile(t, filepath.Join(base, "shell.qml"), "ShellRoot {}\n")
	writeTestFile(t, filepath.Join(base, "version"), "1.2.6\n")
	t.Setenv("AMBXST_SHELL", base)
	t.Setenv("AMBXST_MODS_DISABLED", "1")

	manager := NewManager(testPaths(root))
	status, err := manager.Install("https://github.com/flathead/ambxst-mods/tree/main/packages/volume-scroll")
	if err != nil {
		t.Skipf("network unavailable: %v", err)
	}
	if len(status.Mods) != 1 {
		t.Fatalf("expected one installed mod, got %#v", status.Mods)
	}
	if status.Mods[0].Revision == "" {
		t.Fatal("a GitHub directory install recorded no upstream revision")
	}
}
