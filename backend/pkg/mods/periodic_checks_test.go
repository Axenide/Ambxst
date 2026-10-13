package mods

import (
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"time"
)

func TestPeriodicChecksAreIndependentOfInstallation(t *testing.T) {
	m, _, writeVersion := updateFixture(t, false)
	status, err := m.SetPeriodicChecks(true)
	if err != nil || !status.PeriodicChecks || status.AutoUpdate {
		t.Fatalf("check-only preference: %#v, %v", status, err)
	}
	writeVersion("1.0.1")
	preview, err := m.CheckUpdates(nil, false)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := m.SetPeriodicChecks(false); err != nil {
		t.Fatal(err)
	}
	result, err := m.ApplyUpdates(preview.Updates.PlanID, true)
	if err != nil || result.PeriodicChecks || result.Mods[0].Version != "1.0.1" {
		t.Fatalf("manual update or saved preference lost: %#v, %v", result, err)
	}
	if _, err := m.SetUpdatePolicy("", "on"); err != nil {
		t.Fatal(err)
	}
	status, _ = m.Status()
	if status.PeriodicChecks {
		t.Fatal("installation policy enabled scheduled checks")
	}
}

func TestPeriodicCheckMigrationAndDue(t *testing.T) {
	now := time.Now()
	enabled, disabled := true, false
	state := State{Mods: []InstalledMod{{ID: "example.mod", SourceType: "git"}}}
	if periodicChecksEnabled(state) {
		t.Fatal("new users were opted in")
	}
	state.AutoUpdate = true
	if !periodicChecksEnabled(state) {
		t.Fatal("legacy automatic updates were disabled")
	}
	state.PeriodicChecks = &disabled
	if automaticDue(state, UpdateState{}, false, now) {
		t.Fatal("explicit pause ignored")
	}
	state.AutoUpdate = false
	state.PeriodicChecks = &enabled
	updates := UpdateState{Scheduled: true, CanApply: true}
	if !automaticDue(state, updates, false, now) {
		t.Fatal("check-only schedule stopped at an available update")
	}
	updates.Scheduled = false
	if !automaticDue(state, updates, false, now) {
		t.Fatal("manual preview blocked scheduled discovery")
	}
	state.Mods[0].SourceType = "local"
	if automaticDue(state, UpdateState{}, false, now) {
		t.Fatal("local source was polled")
	}
}

func TestScheduledDiscoveryAndSelectiveInstallation(t *testing.T) {
	for _, enabled := range []bool{false, true} {
		t.Run(map[bool]string{false: "disabled", true: "enabled"}[enabled], func(t *testing.T) {
			testScheduledSelection(t, enabled, "")
		})
	}
}

func TestScheduledCompositionUsesOnlyAutomaticCandidates(t *testing.T) {
	for _, id := range []string{"example.manual", "example.review", "example.auto"} {
		t.Run(id, func(t *testing.T) { testScheduledSelection(t, true, id) })
	}
}

func testScheduledSelection(t *testing.T, enabled bool, brokenID string) {
	t.Helper()
	m, _, _ := updateFixture(t, false)
	if _, err := m.Remove("example.update"); err != nil {
		t.Fatal(err)
	}
	git := func(dir string, args ...string) {
		t.Helper()
		cmd := exec.Command("git", append([]string{"-c", "commit.gpgsign=false", "-c", "user.name=Test", "-c", "user.email=test@example.com", "-C", dir}, args...)...)
		if output, err := cmd.CombinedOutput(); err != nil {
			t.Fatalf("git: %v: %s", err, output)
		}
	}
	sources := map[string]string{}
	for _, id := range []string{"example.auto", "example.manual", "example.review"} {
		source := filepath.Join(t.TempDir(), id+".git")
		manifest := Manifest{ManifestVersion: 1, ID: id, Name: id, Version: "1.0.0",
			Operations: []Operation{{Type: "overlay", Source: "Feature.qml", Target: id + ".qml"}}}
		data, _ := json.Marshal(manifest)
		writeTestFile(t, filepath.Join(source, ManifestFile), string(data))
		writeTestFile(t, filepath.Join(source, "Feature.qml"), "Item {}\n")
		git(source, "init", "-b", "main")
		git(source, "add", ".")
		git(source, "commit", "-m", "Initial package")
		if _, err := m.Install(source); err != nil {
			t.Fatal(err)
		}
		clone := filepath.Join(t.TempDir(), "clone")
		git(source, "clone", source, clone)
		if err := copyTree(clone, filepath.Join(m.paths.ModPackagesDir(), id), nil); err != nil {
			t.Fatal(err)
		}
		state, err := m.loadState()
		if err != nil {
			t.Fatal(err)
		}
		index, _ := findInstalled(state, id)
		state.Mods[index].SourceType = "git"
		state.Mods[index].Revision = gitRevision(source)
		if err := m.saveState(state); err != nil {
			t.Fatal(err)
		}
		sources[id] = source
	}
	if enabled {
		for id := range sources {
			if _, err := m.SetEnabled(id, true); err != nil {
				t.Fatal(err)
			}
			if err := m.MarkHealthy(); err != nil {
				t.Fatal(err)
			}
		}
	}
	if _, err := m.SetPeriodicChecks(true); err != nil {
		t.Fatal(err)
	}
	for _, id := range []string{"example.auto", "example.review"} {
		if _, err := m.SetUpdatePolicy(id, "on"); err != nil {
			t.Fatal(err)
		}
	}
	for id, source := range sources {
		manifest, _ := LoadManifest(source)
		manifest.Version = "1.0.1"
		if id == "example.review" {
			manifest.Permissions = []string{"Reads files"}
		}
		if id == brokenID {
			manifest.Operations = []Operation{{Type: "patch", Source: "broken.patch"}}
			writeTestFile(t, filepath.Join(source, "broken.patch"), "--- a/shell.qml\n+++ b/shell.qml\n@@ -1 +1 @@\n-Missing context\n+ShellRoot {}\n")
		}
		data, _ := json.Marshal(manifest)
		writeTestFile(t, filepath.Join(source, ManifestFile), string(data))
		git(source, "add", ".")
		git(source, "commit", "-m", "Update package")
	}
	preview, err := m.checkUpdates(nil, true, true)
	if err != nil || preview.Updates.CanApply || len(preview.Updates.Items) != 3 {
		t.Fatalf("discovery: %#v, %v", preview.Updates, err)
	}
	if _, err := m.ApplyUpdates(preview.Updates.PlanID, true); err == nil {
		t.Fatal("discovery bypassed manual preparation")
	}
	for _, mod := range preview.Mods {
		if mod.Version != "1.0.0" {
			t.Fatal("discovery installed an update")
		}
	}
	state, _ := m.loadState()
	ids := automaticCandidates(state, preview.Updates.Items)
	if len(ids) != 1 || ids[0] != "example.auto" {
		t.Fatalf("wrong automatic candidates: %v", ids)
	}
	if _, err := m.ApplyUpdates(preview.Updates.PlanID, false, "example.manual"); err == nil {
		t.Fatal("manual-only package installed automatically")
	}
	if _, err := m.ApplyUpdates(preview.Updates.PlanID, false, "example.review"); err == nil {
		t.Fatal("permission change installed automatically")
	}
	applied, err := m.ApplyUpdates(preview.Updates.PlanID, false, ids...)
	if brokenID == "example.auto" {
		if err == nil {
			t.Fatal("invalid automatic candidate was installed")
		}
		status, statusErr := m.Status()
		if statusErr != nil || status.Updates.ErrorCode != "composition_failed" {
			t.Fatalf("missing composition failure: %+v, %v", status.Updates, statusErr)
		}
		if len(status.Updates.Blocked) != 1 || status.Updates.Blocked[brokenID] == "" {
			t.Fatalf("blocked unrelated candidates: %v", status.Updates.Blocked)
		}
		for _, mod := range status.Mods {
			if mod.Version != "1.0.0" {
				t.Fatal("failed composition changed installed packages")
			}
		}
		return
	}
	if err != nil {
		t.Fatal(err)
	}
	for _, mod := range applied.Mods {
		expected := "1.0.0"
		if mod.ID == "example.auto" {
			expected = "1.0.1"
		}
		if mod.Version != expected {
			t.Fatalf("%s: got %s, want %s", mod.ID, mod.Version, expected)
		}
	}
	for _, item := range applied.Updates.Items {
		expected := "available"
		if item.ID == "example.auto" {
			expected = "updated"
		}
		if item.State != expected {
			t.Fatalf("lost remaining update: %#v", item)
		}
	}
	if enabled {
		if !applied.RestartRequired {
			t.Fatal("enabled update did not require restart")
		}
		if _, err := m.SetPeriodicChecks(false); err != nil {
			t.Fatal(err)
		}
		recovered, err := m.RecoverFailedActivation()
		if err != nil || !recovered {
			t.Fatalf("recovery: %v, %v", recovered, err)
		}
		status, err := m.Status()
		if err != nil {
			t.Fatal(err)
		}
		if status.PeriodicChecks {
			t.Fatal("recovery lost the paused schedule")
		}
		for _, mod := range status.Mods {
			if mod.Version != "1.0.0" {
				t.Fatalf("recovery lost original package: %#v", mod)
			}
		}
	}
}

func TestInstallationPolicyDoesNotStartSchedule(t *testing.T) {
	m, _, _ := updateFixture(t, false)
	status, err := m.SetUpdatePolicy("", "on")
	if err != nil || status.PeriodicChecks || !status.AutoUpdate {
		t.Fatalf("policy coupled to schedule: %#v, %v", status, err)
	}
}

func TestPeriodicChecksRPCRequiresExplicitChoice(t *testing.T) {
	m, _, _ := updateFixture(t, false)
	service := NewService(m)
	for _, input := range []string{"{}", "null", "{\"enabled\":null}", "{\"enabled\":\"yes\"}"} {
		if _, err := service.setPeriodicChecks(json.RawMessage(input)); err == nil {
			t.Fatalf("accepted %s", input)
		}
	}
}

func TestScheduleRunsWhenClockMovesBack(t *testing.T) {
	now := time.Now().UTC()
	state := State{AutoUpdate: true, UpdateIntervalHours: 168, Mods: []InstalledMod{{SourceType: "git"}}}
	updates := UpdateState{NextCheck: now.Add(168 * time.Hour).Format(time.RFC3339)}
	if automaticDue(state, updates, false, now) {
		t.Fatal("weekly deadline treated as a clock change")
	}
	// A deadline saved before the clock moved back a year.
	updates.NextCheck = now.AddDate(1, 0, 0).Format(time.RFC3339)
	if !automaticDue(state, updates, false, now) {
		t.Fatal("schedule waited for a deadline from before the clock change")
	}
}

func TestFailedChecksBackOffUpToWeeklyInterval(t *testing.T) {
	m, source, _ := updateFixture(t, false)
	if _, err := m.SetUpdateInterval(168); err != nil {
		t.Fatal(err)
	}
	if err := os.RemoveAll(source); err != nil {
		t.Fatal(err)
	}
	for _, failures := range []int{0, 7} {
		m.updates.Failures = failures
		status, err := m.CheckUpdates(nil, false)
		if err != nil {
			t.Fatal(err)
		}
		next, _ := time.Parse(time.RFC3339, status.Updates.NextCheck)
		wait := time.Until(next).Round(time.Hour)
		want := map[int]time.Duration{0: time.Hour, 7: 128 * time.Hour}[failures]
		if wait != want {
			t.Fatalf("failure %d waits %v, want %v", failures+1, wait, want)
		}
	}
}

func TestCheckingUnknownModKeepsSchedule(t *testing.T) {
	m, _, _ := updateFixture(t, false)
	if _, err := m.SetPeriodicChecks(true); err != nil {
		t.Fatal(err)
	}
	m.updates.NextCheck = time.Now().Add(20 * time.Hour).UTC().Format(time.RFC3339)
	before := m.updates
	if _, err := m.CheckUpdates([]string{"example.missing"}, false); err == nil {
		t.Fatal("unknown mod was checked")
	}
	if m.updates.NextCheck != before.NextCheck || m.updates.Failures != 0 || m.updates.Phase != before.Phase {
		t.Fatalf("a mistyped id changed the saved check: %#v", m.updates)
	}
}
