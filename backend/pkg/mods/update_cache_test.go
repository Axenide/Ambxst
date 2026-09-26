package mods

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func TestDiscoveryPersistsAcrossPartialChecksAndRestart(t *testing.T) {
	m, _, writeVersion := updateFixture(t, false)
	source := t.TempDir()
	manifest := Manifest{ManifestVersion: 1, ID: "example.other", Name: "Other", Version: "1.0.0", Operations: []Operation{{Type: "overlay", Source: "Other.qml", Target: "Other.qml"}}}
	write := func(version string) {
		manifest.Version = version
		data, _ := json.Marshal(manifest)
		writeTestFile(t, filepath.Join(source, ManifestFile), string(data))
		writeTestFile(t, filepath.Join(source, "Other.qml"), "Item {}\n")
	}
	write("1.0.0")
	if _, err := m.Install(source); err != nil {
		t.Fatal(err)
	}
	write("1.0.1")
	writeVersion("1.0.1")
	all, err := m.CheckUpdates(nil, false)
	if err != nil || countAvailable(all.Updates.Known) != 2 {
		t.Fatalf("discovery: %+v, %v", all.Updates, err)
	}
	single, err := m.CheckUpdates([]string{"example.update"}, false)
	if err != nil || len(single.Updates.Items) != 1 || countAvailable(single.Updates.Known) != 2 {
		t.Fatalf("partial check: %+v, %v", single.Updates, err)
	}
	if single.Updates.NextCheck != all.Updates.NextCheck {
		t.Fatal("partial check postponed other mods")
	}
	if _, err := m.DiscardUpdates(); err != nil {
		t.Fatal(err)
	}
	m = NewManager(m.paths)
	status, err := m.Status()
	if err != nil || status.Updates.CanApply || status.Updates.PlanID != "" || countAvailable(status.Updates.Known) != 2 {
		t.Fatalf("restart: %+v, %v", status.Updates, err)
	}
	if err := os.Remove(filepath.Join(source, ManifestFile)); err != nil {
		t.Fatal(err)
	}
	status, err = m.CheckUpdates([]string{"example.other"}, false)
	if err != nil || countAvailable(status.Updates.Known) != 2 {
		t.Fatalf("failed refresh lost discovery: %+v, %v", status.Updates, err)
	}
	preview, err := m.CheckUpdates([]string{"example.update"}, false)
	if err != nil {
		t.Fatal(err)
	}
	status, err = m.ApplyUpdates(preview.Updates.PlanID, true)
	if err != nil || countAvailable(status.Updates.Known) != 1 {
		t.Fatalf("apply: %+v, %v", status.Updates, err)
	}
	if _, err := m.Remove("example.other"); err != nil {
		t.Fatal(err)
	}
	status, _ = m.Status()
	if len(status.Updates.Known) != 0 {
		t.Fatal("removed mod kept a cached update")
	}
}

func TestDiscoveryClearsWhenSourceIsCurrent(t *testing.T) {
	m, _, writeVersion := updateFixture(t, false)
	writeVersion("1.0.1")
	if _, err := m.CheckUpdates(nil, false); err != nil {
		t.Fatal(err)
	}
	writeVersion("1.0.0")
	status, err := m.CheckUpdates(nil, false)
	if err != nil || countAvailable(status.Updates.Known) != 0 || len(status.Updates.Known) != 1 {
		t.Fatalf("current source: %+v, %v", status.Updates, err)
	}
}

func TestLegacyDiscoveryMigration(t *testing.T) {
	m, _, writeVersion := updateFixture(t, false)
	writeVersion("1.0.1")
	preview, err := m.CheckUpdates(nil, false)
	if err != nil {
		t.Fatal(err)
	}
	m.updates.Known = nil
	if err := m.saveUpdates(); err != nil {
		t.Fatal(err)
	}
	m = NewManager(m.paths)
	status, err := m.Status()
	if err != nil || countAvailable(status.Updates.Known) != 1 || status.Updates.CanApply {
		t.Fatalf("legacy results: %+v, %v", status.Updates, err)
	}
	if _, err := m.ApplyUpdates(preview.Updates.PlanID, true); err == nil {
		t.Fatal("cached result authorized installation")
	}
	state, err := m.loadState()
	if err != nil {
		t.Fatal(err)
	}
	state.Mods[0].Source = "different-source"
	if len(m.knownUpdatesFor(state)) != 0 {
		t.Fatal("source change kept cached result")
	}
}
