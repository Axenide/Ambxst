package mods

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"reflect"
)

type updateJournal struct {
	Phase    string `json:"phase"`
	Previous State  `json:"previous"`
	Next     State  `json:"next"`
}

func (m *Manager) journalPath() string {
	return filepath.Join(m.paths.ModsDir(), "update-transaction.json")
}
func (m *Manager) backupPath() string { return filepath.Join(m.paths.ModsDir(), "previous-packages") }

func (m *Manager) readJournal() (updateJournal, error) {
	var journal updateJournal
	data, err := os.ReadFile(m.journalPath())
	if err == nil {
		err = json.Unmarshal(data, &journal)
	}
	return journal, err
}

func (m *Manager) writeJournal(j updateJournal) error {
	data, err := json.Marshal(j)
	if err != nil {
		return err
	}
	return writeAtomic(m.journalPath(), data, 0o600)
}

// recoverInterruptedUpdate runs before any state read. A journal remains until
// package placement and the state file have both been committed.
func (m *Manager) recoverInterruptedUpdate() error {
	j, err := m.readJournal()
	if os.IsNotExist(err) {
		return nil
	}
	if err != nil {
		return fmt.Errorf("read update recovery journal: %w", err)
	}
	if j.Phase != "prepared" && j.Phase != "restoring" {
		return nil
	}
	return m.restoreJournal(j)
}

func (m *Manager) restoreJournal(j updateJournal) error {
	j.Phase = "restoring"
	if err := m.writeJournal(j); err != nil {
		return err
	}
	if _, err := os.Stat(m.backupPath()); err == nil {
		// Copy the backup so another interruption can repeat recovery.
		restore := filepath.Join(m.paths.ModsDir(), ".restore-packages")
		if err := os.RemoveAll(restore); err != nil {
			return err
		}
		if err := copyTree(m.backupPath(), restore, nil); err != nil {
			return err
		}
		if err := os.RemoveAll(m.paths.ModPackagesDir()); err != nil {
			return err
		}
		if err := os.Rename(restore, m.paths.ModPackagesDir()); err != nil {
			return err
		}
	} else if !os.IsNotExist(err) {
		return err
	}
	if err := m.saveState(j.Previous); err != nil {
		return err
	}
	if err := os.Remove(m.paths.ModPendingActivationFile()); err != nil && !os.IsNotExist(err) {
		return err
	}
	if err := os.Remove(m.journalPath()); err != nil {
		return err
	}
	_ = os.RemoveAll(m.backupPath())
	m.affectedCache = nil
	return nil
}

func (m *Manager) restoreUpdate(state State) (bool, error) {
	j, err := m.readJournal()
	if os.IsNotExist(err) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	if j.Next.ActiveGeneration != state.ActiveGeneration {
		return false, nil
	}
	// Preserve later installs and load-order changes. An update backup only
	// belongs to the exact package set it replaced.
	current, expected := cloneState(state), cloneState(j.Next)
	for i := range current.Mods {
		current.Mods[i].AutoUpdate = ""
	}
	for i := range expected.Mods {
		expected.Mods[i].AutoUpdate = ""
	}
	if !reflect.DeepEqual(current.Mods, expected.Mods) {
		return false, nil
	}
	j.Previous.AutoUpdate = state.AutoUpdate
	j.Previous.UpdateIntervalHours = state.UpdateIntervalHours
	j.Previous.Disabled = state.Disabled
	j.Previous.BypassVersionCheck = state.BypassVersionCheck
	for i := range j.Previous.Mods {
		if index, ok := findInstalled(state, j.Previous.Mods[i].ID); ok {
			j.Previous.Mods[i].AutoUpdate = state.Mods[index].AutoUpdate
		}
	}
	m.updateState()
	if m.updates.Blocked == nil {
		m.updates.Blocked = map[string]string{}
	}
	for _, mod := range j.Next.Mods {
		if i, ok := findInstalled(j.Previous, mod.ID); ok && j.Previous.Mods[i].Revision != mod.Revision {
			m.updates.Blocked[mod.ID] = mod.Revision
		}
	}
	m.updates.Phase, m.updates.PlanID, m.updates.CanApply = "recovered", "", false
	if err := m.saveUpdates(); err != nil {
		return false, err
	}
	return true, m.restoreJournal(j)
}

func (m *Manager) ApplyUpdates(planID string, reviewed bool, ids ...string) (Status, error) {
	if !m.updateMu.TryLock() {
		return Status{}, fmt.Errorf("an update operation is already running")
	}
	defer m.updateMu.Unlock()
	m.mu.Lock()
	defer m.mu.Unlock()
	state, err := m.loadState()
	if err != nil {
		return Status{}, err
	}
	plan := m.updatePlan
	if plan == nil || plan.id != planID || !m.updates.CanApply {
		return Status{}, fmt.Errorf("update plan expired; check for updates again")
	}
	selected := map[string]bool{}
	for _, id := range ids {
		selected[id] = true
	}
	available := map[string]bool{}
	for _, item := range m.updates.Items {
		if item.State != "available" || (len(selected) > 0 && !selected[item.ID]) {
			continue
		}
		available[item.ID] = true
		if !reviewed && len(selected) > 0 {
			index, ok := findInstalled(state, item.ID)
			if !ok || !periodicChecksEnabled(state) || !automaticEnabled(state, state.Mods[index]) || len(item.ReviewReasons) > 0 {
				return Status{}, fmt.Errorf("this update requires manual confirmation")
			}
		}
	}
	for id := range selected {
		if !available[id] {
			return Status{}, fmt.Errorf("mod %s has no prepared update", id)
		}
	}
	if len(selected) == 0 && m.updates.RequiresReview && !reviewed {
		return Status{}, fmt.Errorf("review the update changes before applying")
	}
	if _, pending := m.readPendingActivation(); pending {
		return Status{}, fmt.Errorf("restart or recover the pending generation before updating")
	}
	fingerprint, err := m.updateFingerprint(state, plan.base)
	if err != nil {
		return Status{}, err
	}
	if fingerprint != plan.fingerprint {
		m.updates.CanApply, m.updates.Phase = false, "check_again"
		_ = m.saveUpdates()
		return Status{}, fmt.Errorf("installed packages or the base changed; check for updates again")
	}
	digest, err := treeDigest(filepath.Join(plan.directory, "packages"))
	if err != nil || digest != plan.contentDigest {
		return Status{}, fmt.Errorf("prepared packages changed; check for updates again")
	}
	if plan.generation != "" {
		digest, err = treeDigest(plan.generation)
		if err != nil || digest != plan.generationDigest {
			return Status{}, fmt.Errorf("prepared generation changed; check for updates again")
		}
	}
	original := plan
	if len(selected) > 0 && len(selected) < countAvailable(m.updates.Items) {
		plan, err = m.selectPreparedUpdates(state, original, selected)
		if err != nil {
			return Status{}, err
		}
		defer os.RemoveAll(plan.directory)
		// Remove the unused generation if the transaction fails.
		defer func() {
			if m.updatePlan != nil && plan.generation != "" {
				_ = os.RemoveAll(plan.generation)
			}
		}()
	}
	next := cloneState(plan.next)
	if plan.generation != "" {
		next.PreviousGeneration = m.knownGoodGeneration(state)
		next.ActiveGeneration = filepath.Base(plan.generation)
	}
	if err := os.RemoveAll(m.backupPath()); err != nil {
		return Status{}, err
	}
	j := updateJournal{Phase: "prepared", Previous: state, Next: next}
	if err := m.writeJournal(j); err != nil {
		return Status{}, err
	}
	rollback := func(cause error) (Status, error) {
		if err := m.restoreJournal(j); err != nil {
			return Status{}, fmt.Errorf("%v; recovery failed: %w", cause, err)
		}
		return Status{}, cause
	}
	if err := os.Rename(m.paths.ModPackagesDir(), m.backupPath()); err != nil {
		return rollback(err)
	}
	if err := os.Rename(filepath.Join(plan.directory, "packages"), m.paths.ModPackagesDir()); err != nil {
		return rollback(err)
	}
	if plan.generation != "" {
		if err := m.writePendingActivation(next.ActiveGeneration, next.PreviousGeneration); err != nil {
			return rollback(err)
		}
	}
	if err := m.saveState(next); err != nil {
		return rollback(err)
	}
	j.Phase = "committed"
	if err := m.writeJournal(j); err != nil {
		return rollback(err)
	}
	m.affectedCache = nil
	m.updatePlan = nil
	m.updates.CanApply, m.updates.PlanID, m.updates.Phase = false, "", "applied"
	for i := range m.updates.Items {
		if m.updates.Items[i].State == "available" && available[m.updates.Items[i].ID] {
			m.updates.Items[i].State = "updated"
		}
	}
	m.updates.RestartRequired = plan.generation != ""
	if countAvailable(m.updates.Items) > 0 {
		m.updates.Phase = "partial"
	}
	_ = m.saveUpdates()
	_ = os.RemoveAll(plan.directory)
	if original != plan {
		_ = os.RemoveAll(original.directory)
		if original.generation != "" {
			_ = os.RemoveAll(original.generation)
		}
	}
	return m.statusForRestart(next, plan.generation != "")
}

func countAvailable(items []UpdateItem) int {
	count := 0
	for _, item := range items {
		if item.State == "available" {
			count++
		}
	}
	return count
}

// Compose exact staged candidates with the installed versions of all unselected mods.
func (m *Manager) selectPreparedUpdates(state State, original *preparedUpdate, selected map[string]bool) (*preparedUpdate, error) {
	dir, err := os.MkdirTemp(m.paths.ModsDir(), ".selected-")
	if err != nil {
		return nil, err
	}
	plan := &preparedUpdate{directory: dir, base: original.base, next: cloneState(state)}
	keep := false
	defer func() {
		if !keep {
			_ = os.RemoveAll(dir)
			if plan.generation != "" {
				_ = os.RemoveAll(plan.generation)
			}
		}
	}()
	packages := filepath.Join(dir, "packages")
	if err := copyTree(m.paths.ModPackagesDir(), packages, nil); err != nil {
		return nil, err
	}
	restart := false
	for i, mod := range state.Mods {
		if !selected[mod.ID] {
			continue
		}
		target := filepath.Join(packages, mod.ID)
		if err := os.RemoveAll(target); err != nil {
			return nil, err
		}
		if err := copyTree(filepath.Join(original.directory, "packages", mod.ID), target, nil); err != nil {
			return nil, err
		}
		plan.next.Mods[i].Revision = original.next.Mods[i].Revision
		restart = restart || mod.Enabled
	}
	if restart {
		plan.generation, err = m.buildGenerationAt(plan.next, original.base, packages)
		if err != nil {
			return nil, err
		}
	}
	keep = true
	return plan, nil
}

// Package mutations wait for the startup trial so recovery cannot discard a
// subsequent install, removal, or reordering.
func (m *Manager) guardUpdateTrial() error {
	if err := m.recoverInterruptedUpdate(); err != nil {
		return err
	}
	if _, pending := m.readPendingActivation(); !pending {
		return nil
	}
	j, err := m.readJournal()
	if os.IsNotExist(err) {
		return nil
	}
	if err != nil {
		return err
	}
	if j.Phase == "committed" {
		return fmt.Errorf("restart or recover the pending update before changing mods")
	}
	return nil
}
