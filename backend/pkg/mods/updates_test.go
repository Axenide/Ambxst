package mods

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func updateFixture(t *testing.T, enabled bool) (*Manager, string, func(string)) {
	t.Helper()
	root := t.TempDir()
	base := filepath.Join(root, "base")
	writeTestFile(t, filepath.Join(base, "shell.qml"), "ShellRoot {}\n")
	writeTestFile(t, filepath.Join(base, "version"), "1.2.5\n")
	t.Setenv("AMBXST_SHELL", base)
	source := filepath.Join(root, "source")
	writeTestFile(t, filepath.Join(source, "Feature.qml"), "Item {}\n")
	writeVersion := func(version string) {
		manifest := Manifest{ManifestVersion: 1, ID: "example.update", Name: "Update fixture", Version: version, Operations: []Operation{{Type: "overlay", Source: "Feature.qml", Target: "Feature.qml"}}}
		data, err := json.Marshal(manifest)
		if err != nil {
			t.Fatal(err)
		}
		writeTestFile(t, filepath.Join(source, ManifestFile), string(data))
	}
	writeVersion("1.0.0")
	m := NewManager(testPaths(root))
	if _, err := m.Install(source); err != nil {
		t.Fatal(err)
	}
	if enabled {
		if _, err := m.SetEnabled("example.update", true); err != nil {
			t.Fatal(err)
		}
		if err := m.MarkHealthy(); err != nil {
			t.Fatal(err)
		}
	}
	return m, source, writeVersion
}

func TestUpdatePreviewDoesNotModifyInstalledPackages(t *testing.T) {
	m, _, writeVersion := updateFixture(t, true)
	before, _ := m.Status()
	writeVersion("1.1.0")
	preview, err := m.CheckUpdates(nil, false)
	if err != nil {
		t.Fatal(err)
	}
	if !preview.Updates.CanApply || preview.Mods[0].Version != "1.0.0" || preview.ActiveGeneration != before.ActiveGeneration {
		t.Fatalf("preview changed active state: %#v", preview)
	}
	applied, err := m.ApplyUpdates(preview.Updates.PlanID, true)
	if err != nil {
		t.Fatal(err)
	}
	if applied.Mods[0].Version != "1.1.0" || !applied.RestartRequired {
		t.Fatalf("update was not applied: %#v", applied)
	}
	if _, err := m.Remove("example.update"); err == nil {
		t.Fatal("mutation during startup trial was allowed")
	}
	if recovered, err := m.RecoverFailedActivation(); err != nil || !recovered {
		t.Fatalf("recovery: %v, %v", recovered, err)
	}
	after, err := m.Status()
	if err != nil {
		t.Fatal(err)
	}
	if after.Mods[0].Version != "1.0.0" || after.ActiveGeneration != before.ActiveGeneration {
		t.Fatalf("recovery did not restore packages and generation: %#v", after)
	}
}

func TestManualUpdateTargetsOneModWithAutomaticUpdatesOff(t *testing.T) {
	m, source, writeVersion := updateFixture(t, false)
	otherSource := filepath.Join(t.TempDir(), "other")
	writeOtherVersion := func(version string) {
		t.Helper()
		manifest, err := LoadManifest(source)
		if err != nil {
			t.Fatal(err)
		}
		manifest.ID = "example.other"
		manifest.Version = version
		manifest.Operations[0].Target = "Other.qml"
		data, err := json.Marshal(manifest)
		if err != nil {
			t.Fatal(err)
		}
		writeTestFile(t, filepath.Join(otherSource, ManifestFile), string(data))
		writeTestFile(t, filepath.Join(otherSource, "Feature.qml"), "Item {}\n")
	}
	writeOtherVersion("1.0.0")
	if _, err := m.Install(otherSource); err != nil {
		t.Fatal(err)
	}
	if _, err := m.SetUpdatePolicy("", "off"); err != nil {
		t.Fatal(err)
	}
	if _, err := m.SetUpdatePolicy("example.update", "off"); err != nil {
		t.Fatal(err)
	}
	writeVersion("1.0.1")
	writeOtherVersion("1.0.1")
	all, err := m.CheckUpdates(nil, false)
	if err != nil {
		t.Fatal(err)
	}
	if !all.Updates.CanApply || len(all.Updates.Items) != 2 {
		t.Fatalf("missing updates: %#v", all.Updates)
	}
	single, err := m.CheckUpdates([]string{"example.update"}, false)
	if err != nil {
		t.Fatal(err)
	}
	if !single.Updates.CanApply || len(single.Updates.Items) != 1 {
		t.Fatalf("wrong update scope: %#v", single.Updates)
	}
	if _, err := m.ApplyUpdates(all.Updates.PlanID, true); err == nil {
		t.Fatal("superseded bulk preview was accepted")
	}
	result, err := m.ApplyUpdates(single.Updates.PlanID, true)
	if err != nil {
		t.Fatal(err)
	}
	for _, mod := range result.Mods {
		expected := "1.0.0"
		if mod.ID == "example.update" {
			expected = "1.0.1"
		}
		if mod.Version != expected {
			t.Fatalf("%s: got %s, want %s", mod.ID, mod.Version, expected)
		}
	}
}

func TestUpdateRejectsStalePreview(t *testing.T) {
	m, _, writeVersion := updateFixture(t, false)
	writeVersion("1.1.0")
	preview, err := m.CheckUpdates(nil, false)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := m.SetUpdatePolicy("", "on"); err != nil {
		t.Fatal(err)
	}
	if _, err := m.ApplyUpdates(preview.Updates.PlanID, true); err == nil {
		t.Fatal("stale preview applied")
	}
	status, _ := m.Status()
	if status.Mods[0].Version != "1.0.0" {
		t.Fatal("stale preview modified packages")
	}
}

func TestUpdatePermissionChangesRequireReview(t *testing.T) {
	m, source, writeVersion := updateFixture(t, false)
	writeVersion("1.1.0")
	manifest, _ := LoadManifest(source)
	manifest.Permissions = []string{"Reads files"}
	data, _ := json.Marshal(manifest)
	writeTestFile(t, filepath.Join(source, ManifestFile), string(data))
	preview, err := m.CheckUpdates(nil, false)
	if err != nil {
		t.Fatal(err)
	}
	if !preview.Updates.RequiresReview {
		t.Fatal("permission change not reported")
	}
	if _, err := m.ApplyUpdates(preview.Updates.PlanID, false); err == nil {
		t.Fatal("unreviewed permission change applied")
	}
	if _, err := m.ApplyUpdates(preview.Updates.PlanID, true); err != nil {
		t.Fatal(err)
	}
}

func TestUpdateCompositionFailureKeepsWorkingGeneration(t *testing.T) {
	m, source, writeVersion := updateFixture(t, true)
	before, _ := m.Status()
	writeVersion("1.1.0")
	manifest, _ := LoadManifest(source)
	manifest.Operations[0].Target = "shell.qml"
	data, _ := json.Marshal(manifest)
	writeTestFile(t, filepath.Join(source, ManifestFile), string(data))
	preview, err := m.CheckUpdates(nil, false)
	if err != nil {
		t.Fatal(err)
	}
	if preview.Updates.CanApply || preview.Updates.ErrorCode != "composition_failed" {
		t.Fatalf("conflict was not blocked: %#v", preview.Updates)
	}
	if preview.ActiveGeneration != before.ActiveGeneration || preview.Mods[0].Version != "1.0.0" {
		t.Fatal("failed composition changed installed state")
	}
}

func TestInterruptedUpdateRestoresPackages(t *testing.T) {
	m, _, _ := updateFixture(t, true)
	state, _ := m.loadState()
	if err := m.writeJournal(updateJournal{Phase: "prepared", Previous: state, Next: state}); err != nil {
		t.Fatal(err)
	}
	if err := os.Rename(m.paths.ModPackagesDir(), m.backupPath()); err != nil {
		t.Fatal(err)
	}
	restarted := NewManager(m.paths)
	status, err := restarted.Status()
	if err != nil {
		t.Fatal(err)
	}
	if len(status.Mods) != 1 || status.Mods[0].Version != "1.0.0" {
		t.Fatal("interrupted update lost the package")
	}
	if _, err := os.Stat(m.journalPath()); !os.IsNotExist(err) {
		t.Fatal("recovery journal was not completed")
	}
}

func TestUpdatePolicyInheritance(t *testing.T) {
	state := State{}
	mod := InstalledMod{SourceType: "git"}
	if automaticEnabled(state, mod) {
		t.Fatal("automatic updates defaulted on")
	}
	state.AutoUpdate = true
	if !automaticEnabled(state, mod) {
		t.Fatal("global preference not inherited")
	}
	mod.AutoUpdate = "off"
	if automaticEnabled(state, mod) {
		t.Fatal("individual opt-out ignored")
	}
	state.AutoUpdate, mod.AutoUpdate = false, "on"
	if !automaticEnabled(state, mod) {
		t.Fatal("individual opt-in ignored")
	}
	mod.SourceType = "local"
	if automaticEnabled(state, mod) {
		t.Fatal("local source was automatically updated")
	}
}

func TestLocalizationDeclaration(t *testing.T) {
	root := t.TempDir()
	if warnings := localizationWarnings(nil, root); len(warnings) > 0 {
		t.Fatal(warnings)
	}
	l := &Localization{Mode: "translated", DefaultLanguage: "en", Languages: []string{"en", "ru"}, Resources: map[string]string{"ru": "ru.json"}}
	writeTestFile(t, filepath.Join(root, "ru.json"), `{"name":"Localized name"}`)
	if warnings := localizationWarnings(l, root); len(warnings) > 0 {
		t.Fatal(warnings)
	}
	l.Resources["ru"] = "../outside.json"
	if warnings := localizationWarnings(l, root); len(warnings) == 0 {
		t.Fatal("unsafe translation path accepted")
	}
}

func TestDiagnosticsExcludePrivateData(t *testing.T) {
	m, _, _ := updateFixture(t, false)
	m.updateState()
	m.updates.Details = "secret-token https://user:password@example.test/repo?token=secret /home/private/data"
	report, err := m.Diagnostics()
	if err != nil {
		t.Fatal(err)
	}
	for _, secret := range []string{"secret", "password", "private", m.paths.ConfigDir} {
		if strings.Contains(report["text"], secret) {
			t.Fatalf("report exposed %q", secret)
		}
	}
}

func TestCandidateCompatibilityDoesNotActivate(t *testing.T) {
	m, _, _ := updateFixture(t, true)
	before, _ := m.Status()
	report, err := m.CheckBaseCompatibility("")
	if err != nil {
		t.Fatal(err)
	}
	if !report.Composes || report.RuntimeTested {
		t.Fatalf("unexpected evidence: %#v", report)
	}
	after, _ := m.Status()
	if after.ActiveGeneration != before.ActiveGeneration {
		t.Fatal("preflight changed active generation")
	}
}

func TestAutomaticUpdateSchedule(t *testing.T) {
	now := time.Now().UTC()
	state := State{AutoUpdate: true, Mods: []InstalledMod{{SourceType: "git"}}}
	updates := UpdateState{NextCheck: now.Add(time.Hour).Format(time.RFC3339)}
	if automaticDue(state, updates, false, now) {
		t.Fatal("checked before deadline")
	}
	updates.NextCheck = now.Add(-time.Hour).Format(time.RFC3339)
	if !automaticDue(state, updates, false, now) {
		t.Fatal("overdue check skipped")
	}
	if automaticDue(state, updates, true, now) {
		t.Fatal("checked during startup trial")
	}
	updates.CanApply = true
	if !automaticDue(state, updates, false, now) {
		t.Fatal("pending review blocked discovery")
	}
	updates.CanApply = false
	state.Disabled = true
	if automaticDue(state, updates, false, now) {
		t.Fatal("checked while mods were disabled")
	}
}

func TestUpdateRejectsChangedCandidateContents(t *testing.T) {
	m, _, writeVersion := updateFixture(t, false)
	writeVersion("1.1.0")
	preview, err := m.CheckUpdates(nil, false)
	if err != nil {
		t.Fatal(err)
	}
	writeTestFile(t, filepath.Join(m.updatePlan.directory, "packages", "example.update", "Feature.qml"), "changed after review")
	if _, err := m.ApplyUpdates(preview.Updates.PlanID, true); err == nil {
		t.Fatal("changed candidate applied")
	}
}

func TestRollbackPreservesLaterInstalledMods(t *testing.T) {
	m, _, writeVersion := updateFixture(t, false)
	writeVersion("1.1.0")
	if _, err := m.Update("example.update"); err != nil {
		t.Fatal(err)
	}
	extra := writeOverlayPackage(t, t.TempDir(), "extra", "example.extra", "Extra.qml")
	if _, err := m.Install(extra); err != nil {
		t.Fatal(err)
	}
	_, _ = m.Rollback()
	status, err := m.Status()
	if err != nil {
		t.Fatal(err)
	}
	if len(status.Mods) != 2 {
		t.Fatal("rollback discarded a later installation")
	}
}

func TestUpdateReportsCompositionFailure(t *testing.T) {
	m, source, writeVersion := updateFixture(t, true)
	writeVersion("1.1.0")
	manifest, _ := LoadManifest(source)
	manifest.Operations[0].Target = "shell.qml"
	data, _ := json.Marshal(manifest)
	writeTestFile(t, filepath.Join(source, ManifestFile), string(data))
	if _, err := m.Update("example.update"); err == nil || !strings.Contains(err.Error(), "example.update") {
		t.Fatalf("update of a candidate that cannot compose returned %v", err)
	}
	status, _ := m.Status()
	if status.Mods[0].Version != "1.0.0" {
		t.Fatal("failed update changed the installed package")
	}
}

func TestFailedStartRestoresUpdateAfterMenuIndexChange(t *testing.T) {
	m, source, writeVersion := updateFixture(t, true)
	writeVersion("1.1.0")
	manifest, _ := LoadManifest(source)
	manifest.SettingsMenu = &SettingsMenuRef{Section: 11, Index: -2}
	data, _ := json.Marshal(manifest)
	writeTestFile(t, filepath.Join(source, ManifestFile), string(data))
	preview, err := m.CheckUpdates(nil, false)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := m.ApplyUpdates(preview.Updates.PlanID, true); err != nil {
		t.Fatal(err)
	}
	// The menu index only affects the running shell, so it stays editable
	// during the startup trial.
	if _, err := m.SetMenuIndex("example.update", 3); err != nil {
		t.Fatal(err)
	}
	if recovered, err := m.RecoverFailedActivation(); err != nil || !recovered {
		t.Fatalf("recovery: %v, %v", recovered, err)
	}
	status, err := m.Status()
	if err != nil {
		t.Fatal(err)
	}
	if status.Mods[0].Version != "1.0.0" {
		t.Fatalf("failed update kept package %s", status.Mods[0].Version)
	}
	state, _ := m.loadState()
	if state.Mods[0].MenuIndex == nil || *state.Mods[0].MenuIndex != 3 {
		t.Fatal("recovery discarded the menu index chosen during the trial")
	}
}
