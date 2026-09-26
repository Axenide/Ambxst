package mods

import (
	"encoding/json"
	"path/filepath"
	"testing"
	"time"
)

func TestUpdateInterval(t *testing.T) {
	m, _, writeVersion := updateFixture(t, false)
	status, _ := m.Status()
	if status.UpdateIntervalHours != 24 {
		t.Fatal("legacy state must default to daily checks")
	}
	for _, hours := range []int{1, 6, 24, 168} {
		status, err := m.SetUpdateInterval(hours)
		if err != nil || status.UpdateIntervalHours != hours || status.AutoUpdate {
			t.Fatalf("interval changed opt-in or was not saved: %#v, %v", status, err)
		}
		due, err := time.Parse(time.RFC3339, status.Updates.NextCheck)
		if err != nil || time.Until(due) < time.Duration(hours)*time.Hour-time.Minute {
			t.Fatal("next check did not use the selected interval")
		}
	}
	if _, err := m.SetUpdateInterval(2); err == nil {
		t.Fatal("unsupported interval accepted")
	}
	writeVersion("1.1.0")
	preview, err := m.CheckUpdates(nil, false)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := m.SetUpdateInterval(6); err != nil {
		t.Fatal(err)
	}
	if _, err := m.ApplyUpdates(preview.Updates.PlanID, true); err != nil {
		t.Fatalf("schedule invalidated a valid preview: %v", err)
	}
	status, _ = m.Status()
	if status.UpdateIntervalHours != 6 {
		t.Fatal("apply lost the schedule")
	}
}

func TestIntervalDoesNotRefreshStalePreview(t *testing.T) {
	m, _, writeVersion := updateFixture(t, false)
	writeVersion("1.1.0")
	preview, err := m.CheckUpdates(nil, false)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := m.SetUpdatePolicy("", "on"); err != nil {
		t.Fatal(err)
	}
	if _, err := m.SetUpdateInterval(6); err != nil {
		t.Fatal(err)
	}
	if _, err := m.ApplyUpdates(preview.Updates.PlanID, true); err == nil {
		t.Fatal("schedule change revived a stale preview")
	}
}

func TestDeprecatedUpdateRequiresReview(t *testing.T) {
	for _, alias := range []bool{false, true} {
		t.Run(map[bool]string{false: "canonical", true: "alias"}[alias], func(t *testing.T) {
			m, source, _ := updateFixture(t, false)
			manifest, err := LoadManifest(source)
			if err != nil {
				t.Fatal(err)
			}
			if alias {
				manifest.Depricated, manifest.DepricatedReason = true, "Included in Ambxst."
			} else {
				manifest.Deprecated, manifest.DeprecatedReason = true, "Included in Ambxst."
			}
			data, _ := json.Marshal(manifest)
			writeTestFile(t, filepath.Join(source, ManifestFile), string(data))
			preview, err := m.CheckUpdates(nil, false)
			if err != nil {
				t.Fatal(err)
			}
			if !preview.Updates.RequiresReview || !preview.Updates.Items[0].Deprecated {
				t.Fatal("deprecated candidate did not require review")
			}
			if _, err := m.ApplyUpdates(preview.Updates.PlanID, false); err == nil {
				t.Fatal("deprecated candidate applied without review")
			}
			status, err := m.ApplyUpdates(preview.Updates.PlanID, true)
			if err != nil {
				t.Fatal(err)
			}
			if !status.Mods[0].Deprecated || status.Mods[0].DeprecatedReason != "Included in Ambxst." {
				t.Fatal("installed deprecation metadata missing")
			}
		})
	}
}
