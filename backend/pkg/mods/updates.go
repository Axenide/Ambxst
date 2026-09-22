package mods

import (
	"ambxst/backend/pkg/paths"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"sort"
	"strings"
	"time"
)

type UpdateItem struct {
	ID                string            `json:"id"`
	FromVersion       string            `json:"fromVersion"`
	ToVersion         string            `json:"toVersion"`
	Revision          string            `json:"revision"`
	FromRevision      string            `json:"fromRevision,omitempty"`
	Changelog         string            `json:"changelog,omitempty"`
	ChangelogFile     string            `json:"changelogFile,omitempty"`
	Deprecated        bool              `json:"deprecated"`
	DeprecatedReason  string            `json:"deprecatedReason,omitempty"`
	State             string            `json:"state"`
	Details           string            `json:"details,omitempty"`
	ErrorCode         string            `json:"errorCode,omitempty"`
	ReviewReasons     []string          `json:"reviewReasons,omitempty"`
	Files             []string          `json:"files,omitempty"`
	Dependencies      []string          `json:"dependencies,omitempty"`
	Permissions       []string          `json:"permissions,omitempty"`
	Commands          []string          `json:"commands,omitempty"`
	DependencySources map[string]string `json:"dependencySources,omitempty"`
}

type UpdateState struct {
	Busy            bool              `json:"busy"`
	Phase           string            `json:"phase"`
	LastAttempt     string            `json:"lastAttempt,omitempty"`
	LastSuccess     string            `json:"lastSuccess,omitempty"`
	NextCheck       string            `json:"nextCheck,omitempty"`
	Failures        int               `json:"failures,omitempty"`
	PlanID          string            `json:"planId,omitempty"`
	CanApply        bool              `json:"canApply"`
	RequiresReview  bool              `json:"requiresReview"`
	RestartRequired bool              `json:"restartRequired"`
	ErrorCode       string            `json:"errorCode,omitempty"`
	Details         string            `json:"details,omitempty"`
	Items           []UpdateItem      `json:"items"`
	Blocked         map[string]string `json:"blocked,omitempty"`
}

type preparedUpdate struct {
	id               string
	directory        string
	fingerprint      string
	base             string
	next             State
	generation       string
	contentDigest    string
	generationDigest string
}

func updateIntervalHours(state State) int {
	switch state.UpdateIntervalHours {
	case 1, 6, 24, 168:
		return state.UpdateIntervalHours
	default:
		return 24
	}
}

func (m *Manager) SetUpdateInterval(hours int) (Status, error) {
	if hours != 1 && hours != 6 && hours != 24 && hours != 168 {
		return Status{}, fmt.Errorf("update interval must be 1, 6, 24, or 168 hours")
	}
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
	previewCurrent := false
	if m.updatePlan != nil {
		fingerprint, err := m.updateFingerprint(state, m.updatePlan.base)
		if err != nil {
			return Status{}, err
		}
		previewCurrent = fingerprint == m.updatePlan.fingerprint
	}
	state.UpdateIntervalHours = hours
	if err := m.saveState(state); err != nil {
		return Status{}, err
	}
	m.updateState()
	// The schedule does not change the reviewed candidates or opt-in policy.
	if m.updatePlan != nil && previewCurrent {
		fingerprint, err := m.updateFingerprint(state, m.updatePlan.base)
		if err != nil {
			return Status{}, err
		}
		m.updatePlan.next.UpdateIntervalHours = hours
		m.updatePlan.fingerprint = fingerprint
	}
	m.updates.NextCheck = time.Now().Add(time.Duration(hours) * time.Hour).UTC().Format(time.RFC3339)
	if err := m.saveUpdates(); err != nil {
		return Status{}, err
	}
	return m.statusFor(state)
}

func updatePolicy(mod InstalledMod) string {
	if mod.AutoUpdate == "on" || mod.AutoUpdate == "off" {
		return mod.AutoUpdate
	}
	return "inherit"
}

func automaticSource(mod InstalledMod) bool {
	return mod.SourceType == "git" || mod.SourceType == "git-subdir"
}

func automaticEnabled(state State, mod InstalledMod) bool {
	return automaticSource(mod) && (updatePolicy(mod) == "on" || (updatePolicy(mod) == "inherit" && state.AutoUpdate))
}

func (m *Manager) SetUpdatePolicy(id, policy string) (Status, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	state, err := m.loadState()
	if err != nil {
		return Status{}, err
	}
	if policy != "on" && policy != "off" && policy != "inherit" {
		return Status{}, fmt.Errorf("invalid update policy")
	}
	if id == "" {
		if policy == "inherit" {
			return Status{}, fmt.Errorf("global policy cannot inherit")
		}
		state.AutoUpdate = policy == "on"
	} else {
		i, ok := findInstalled(state, id)
		if !ok {
			return Status{}, fmt.Errorf("mod is not installed")
		}
		state.Mods[i].AutoUpdate = policy
	}
	if err := m.saveState(state); err != nil {
		return Status{}, err
	}
	m.notifyUpdate()
	return m.statusFor(state)
}

func (m *Manager) DiscardUpdates() (Status, error) {
	if !m.updateMu.TryLock() {
		return Status{}, fmt.Errorf("an update operation is already running")
	}
	defer m.updateMu.Unlock()
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.updatePlan != nil {
		if err := os.RemoveAll(m.updatePlan.directory); err != nil {
			return Status{}, err
		}
		if m.updatePlan.generation != "" {
			_ = os.RemoveAll(m.updatePlan.generation)
		}
		m.updatePlan = nil
	}
	m.updateState()
	m.updates.PlanID, m.updates.CanApply, m.updates.Phase = "", false, "deferred"
	m.updates.NextCheck = time.Now().Add(24 * time.Hour).UTC().Format(time.RFC3339)
	if err := m.saveUpdates(); err != nil {
		return Status{}, err
	}
	state, err := m.loadState()
	if err != nil {
		return Status{}, err
	}
	return m.statusFor(state)
}

func (m *Manager) updateState() UpdateState {
	if !m.updatesLoaded {
		data, _ := os.ReadFile(filepath.Join(m.paths.ModsDir(), "updates.json"))
		_ = json.Unmarshal(data, &m.updates)
		if strings.HasPrefix(m.updates.PlanID, ".candidates-") && filepath.Base(m.updates.PlanID) == m.updates.PlanID {
			_ = os.RemoveAll(filepath.Join(m.paths.ModsDir(), m.updates.PlanID))
		}
		m.updates.Busy, m.updates.CanApply = false, false
		m.updates.PlanID = ""
		if m.updates.Phase == "checking" || m.updates.Phase == "applying" || m.updates.Phase == "ready" {
			m.updates.Phase = "check_again"
		}
		m.updatesLoaded = true
	}
	return m.updates
}

func (m *Manager) saveUpdates() error {
	data, err := json.MarshalIndent(m.updates, "", "  ")
	if err != nil {
		return err
	}
	err = writeAtomic(filepath.Join(m.paths.ModsDir(), "updates.json"), data, 0o600)
	m.notifyUpdate()
	return err
}

func (m *Manager) notifyUpdate() {
	m.eventsMu.Lock()
	defer m.eventsMu.Unlock()
	for ch := range m.listeners {
		select {
		case ch <- struct{}{}:
		default:
		}
	}
}

func treeDigest(root string) (string, error) {
	h := sha256.New()
	err := filepath.WalkDir(root, func(path string, entry fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if entry.IsDir() {
			if entry.Name() == ".git" {
				return filepath.SkipDir
			}
			return nil
		}
		rel, _ := filepath.Rel(root, path)
		info, err := entry.Info()
		if err != nil {
			return err
		}
		fmt.Fprintf(h, "%s\x00%v\x00", rel, info.Mode())
		var data []byte
		if info.Mode()&os.ModeSymlink != 0 {
			target, linkErr := os.Readlink(path)
			data, err = []byte(target), linkErr
		} else {
			data, err = os.ReadFile(path)
		}
		if err != nil {
			return err
		}
		h.Write(data)
		h.Write([]byte{0})
		return nil
	})
	if os.IsNotExist(err) {
		return "", nil
	}
	return hex.EncodeToString(h.Sum(nil)), err
}

func (m *Manager) updateFingerprint(state State, base string) (string, error) {
	packages, err := treeDigest(m.paths.ModPackagesDir())
	if err != nil {
		return "", err
	}
	baseDigest, err := treeDigest(base)
	if err != nil {
		return "", err
	}
	data, _ := json.Marshal(state)
	h := sha256.Sum256(append(data, []byte(packages+baseDigest)...))
	return hex.EncodeToString(h[:]), nil
}

// CheckUpdates stages exact candidates. The running packages are never fetched into.
func (m *Manager) CheckUpdates(ids []string, automatic bool) (Status, error) {
	if !m.updateMu.TryLock() {
		return Status{}, fmt.Errorf("an update operation is already running")
	}
	defer m.updateMu.Unlock()
	m.mu.Lock()
	state, err := m.loadState()
	if err != nil {
		m.mu.Unlock()
		return Status{}, err
	}
	m.updateState()
	if m.updates.Busy {
		m.mu.Unlock()
		return Status{}, fmt.Errorf("an update operation is already running")
	}
	if m.updatePlan != nil {
		os.RemoveAll(m.updatePlan.directory)
		if m.updatePlan.generation != "" {
			os.RemoveAll(m.updatePlan.generation)
		}
		m.updatePlan = nil
	}
	base := paths.FindBaseShellSource()
	fingerprint, err := m.updateFingerprint(state, base)
	if err != nil {
		m.mu.Unlock()
		return Status{}, err
	}
	if err = os.MkdirAll(m.paths.ModsDir(), 0o755); err != nil {
		m.mu.Unlock()
		return Status{}, err
	}
	dir, err := os.MkdirTemp(m.paths.ModsDir(), ".candidates-")
	if err != nil {
		m.mu.Unlock()
		return Status{}, err
	}
	packages := filepath.Join(dir, "packages")
	if len(state.Mods) > 0 {
		err = copyTree(m.paths.ModPackagesDir(), packages, nil)
	} else {
		err = os.MkdirAll(packages, 0o755)
	}
	if err != nil {
		os.RemoveAll(dir)
		m.mu.Unlock()
		return Status{}, err
	}
	last := m.updates
	m.updates = UpdateState{Busy: true, Phase: "checking", PlanID: filepath.Base(dir), LastAttempt: time.Now().UTC().Format(time.RFC3339), LastSuccess: last.LastSuccess, Failures: last.Failures, Blocked: last.Blocked, Items: []UpdateItem{}}
	_ = m.saveUpdates()
	m.mu.Unlock()
	keep := false
	defer func() {
		if !keep {
			os.RemoveAll(dir)
		}
	}()
	selected := map[string]bool{}
	for _, id := range ids {
		if _, ok := findInstalled(state, id); !ok {
			return m.finishUpdateError("not_installed", fmt.Errorf("mod %s is not installed", id))
		}
		selected[id] = true
	}
	next := cloneState(state)
	items := []UpdateItem{}
	changed, restart, review, failed := false, false, false, false
	for i, mod := range state.Mods {
		if len(ids) > 0 && !selected[mod.ID] {
			continue
		}
		if automatic && !automaticEnabled(state, mod) {
			continue
		}
		oldRoot := filepath.Join(packages, mod.ID)
		old, loadErr := LoadManifest(oldRoot)
		item := UpdateItem{ID: mod.ID, FromVersion: old.Version, FromRevision: mod.Revision, State: "current"}
		if loadErr != nil {
			item.ErrorCode = "invalid_package"
			item.State, item.Details = "failed", loadErr.Error()
			items = append(items, item)
			failed = true
			continue
		}
		candidate := filepath.Join(dir, "fetch-"+mod.ID)
		if automatic && mod.SourceType == "git-subdir" {
			if repository, ref, _, ok := parseGitHubTreeSource(mod.Source); ok {
				if err := remoteBranchExists(repository, ref); err != nil {
					item.State, item.ErrorCode, item.Details = "failed", "fetch_failed", err.Error()
					items = append(items, item)
					failed = true
					continue
				}
			}
		}
		fetched, fetchErr := fetchUpdate(mod, oldRoot, candidate)
		if fetchErr != nil {
			item.ErrorCode = "fetch_failed"
			item.State, item.Details = "failed", fetchErr.Error()
			items = append(items, item)
			failed = true
			continue
		}
		manifest, loadErr := LoadManifest(fetched.root)
		if loadErr == nil && manifest.ID != mod.ID {
			loadErr = fmt.Errorf("updated package changed its id")
		}
		if loadErr != nil {
			item.ErrorCode = "invalid_package"
			item.State, item.Details = "failed", loadErr.Error()
			items = append(items, item)
			failed = true
			continue
		}
		item.ToVersion, item.Revision = manifest.Version, fetched.revision
		oldDigest, digestErr := treeDigest(oldRoot)
		newDigest, newErr := treeDigest(fetched.root)
		if digestErr != nil || newErr != nil {
			item.ErrorCode = "read_failed"
			item.State = "failed"
			item.Details = "Cannot read package contents"
			items = append(items, item)
			failed = true
			continue
		}
		if oldDigest == newDigest {
			items = append(items, item)
			continue
		}
		item.State = "available"
		item.Deprecated, item.DeprecatedReason = manifest.isDeprecated(), manifest.deprecationReason()
		if item.Deprecated {
			item.ReviewReasons = append(item.ReviewReasons, "deprecated")
		}
		item.Changelog, item.ChangelogFile = readChangelog(fetched.root, manifest.Changelog)
		item.Files, loadErr = manifest.AffectedFiles(fetched.root)
		if loadErr != nil {
			item.ErrorCode = "invalid_package"
			item.State, item.Details = "failed", loadErr.Error()
			items = append(items, item)
			failed = true
			continue
		}
		item.Dependencies, item.Permissions = manifest.Dependencies, manifest.Permissions
		item.Commands, item.DependencySources = manifest.Commands, manifest.DependencySources
		if !reflect.DeepEqual(sortedStrings(old.Dependencies), sortedStrings(manifest.Dependencies)) || !reflect.DeepEqual(old.DependencySources, manifest.DependencySources) {
			item.ReviewReasons = append(item.ReviewReasons, "dependencies")
		}
		if !reflect.DeepEqual(sortedStrings(old.Permissions), sortedStrings(manifest.Permissions)) || !reflect.DeepEqual(sortedStrings(old.Commands), sortedStrings(manifest.Commands)) {
			item.ReviewReasons = append(item.ReviewReasons, "permissions")
		}
		if last.Blocked[mod.ID] == fetched.revision && fetched.revision != "" {
			item.ReviewReasons = append(item.ReviewReasons, "failed_before")
		}
		if err := checkCompatibility(manifest, base); err != nil {
			if !state.BypassVersionCheck {
				item.ErrorCode = "incompatible"
				item.State, item.Details = "failed", err.Error()
				items = append(items, item)
				failed = true
				continue
			}
			item.ReviewReasons = append(item.ReviewReasons, "version_bypass")
		}
		if len(item.ReviewReasons) > 0 {
			review = true
		}
		if err := os.RemoveAll(oldRoot); err != nil {
			return m.finishUpdateError("stage_failed", err)
		}
		if err := os.Rename(fetched.root, oldRoot); err != nil {
			return m.finishUpdateError("stage_failed", err)
		}
		next.Mods[i].Revision = fetched.revision
		changed = true
		restart = restart || mod.Enabled
		items = append(items, item)
	}
	var generation string
	var compositionErr error
	if changed && restart {
		generation, compositionErr = m.buildGenerationAt(next, base, packages)
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	m.updates.Items, m.updates.RequiresReview, m.updates.RestartRequired = items, review, restart
	m.updates.Busy = false
	m.updates.Phase = "current"
	if failed || compositionErr != nil {
		m.updates.Failures++
	} else {
		m.updates.Failures = 0
		m.updates.LastSuccess = time.Now().UTC().Format(time.RFC3339)
	}
	delay := time.Duration(updateIntervalHours(state)) * time.Hour
	if m.updates.Failures > 0 {
		delay = time.Hour * time.Duration(1<<min(m.updates.Failures-1, 5))
		if delay > 24*time.Hour {
			delay = 24 * time.Hour
		}
	}
	m.updates.NextCheck = time.Now().Add(delay).UTC().Format(time.RFC3339)
	if compositionErr != nil {
		m.updates.Phase, m.updates.ErrorCode, m.updates.Details = "failed", "composition_failed", compositionErr.Error()
		if m.updates.Blocked == nil {
			m.updates.Blocked = map[string]string{}
		}
		for _, item := range items {
			if item.State == "available" && item.Revision != "" {
				m.updates.Blocked[item.ID] = item.Revision
			}
		}
	}
	if changed && compositionErr == nil {
		id := filepath.Base(dir)
		digest, err := treeDigest(packages)
		if err != nil {
			return Status{}, err
		}
		m.updatePlan = &preparedUpdate{id: id, directory: dir, fingerprint: fingerprint, base: base, next: next, generation: generation, contentDigest: digest}
		if generation != "" {
			m.updatePlan.generationDigest, err = treeDigest(generation)
			if err != nil {
				m.updatePlan = nil
				return Status{}, err
			}
		}
		m.updates.PlanID, m.updates.CanApply, m.updates.Phase = id, true, "ready"
		keep = true
	} else if failed {
		m.updates.Phase = "failed"
	}
	if err := m.saveUpdates(); err != nil {
		return Status{}, err
	}
	current, err := m.loadState()
	if err != nil {
		return Status{}, err
	}
	return m.statusFor(current)
}

func (m *Manager) finishUpdateError(code string, err error) (Status, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.updates.Busy, m.updates.CanApply = false, false
	m.updates.Phase, m.updates.ErrorCode, m.updates.Details = "failed", code, err.Error()
	m.updates.Failures++
	m.updates.NextCheck = time.Now().Add(time.Hour).UTC().Format(time.RFC3339)
	_ = m.saveUpdates()
	return Status{}, err
}

func fetchUpdate(mod InstalledMod, installed, destination string) (acquired, error) {
	if mod.SourceType != "git" {
		return acquirePackage(mod.Source, destination)
	}
	// Copy the installed clone to preserve its tracked branch and fast-forward policy.
	if err := copyTree(installed, destination, nil); err != nil {
		return acquired{}, err
	}
	cmd := exec.Command("git", "symbolic-ref", "--quiet", "--short", "HEAD")
	cmd.Dir = destination
	if _, err := cmd.Output(); err != nil {
		return acquired{}, fmt.Errorf("pinned revision requires a manual source change")
	}
	remote := exec.Command("git", "remote", "get-url", "origin")
	remote.Dir = destination
	url, err := remote.Output()
	if err != nil || strings.TrimSpace(string(url)) != mod.Source {
		return acquired{}, fmt.Errorf("update source changed; reinstall from the intended source")
	}
	if err := runCommandTimeout(5*time.Minute, destination, "git", "pull", "--ff-only"); err != nil {
		return acquired{}, err
	}
	return acquired{root: destination, source: mod.Source, sourceType: mod.SourceType, revision: gitRevision(destination)}, nil
}

func remoteBranchExists(repository, ref string) error {
	ctx, cancel := context.WithTimeout(context.Background(), time.Minute)
	defer cancel()
	cmd := exec.CommandContext(ctx, "git", "ls-remote", "--exit-code", "--heads", repository, "refs/heads/"+ref)
	cmd.Env = append(os.Environ(), "GIT_TERMINAL_PROMPT=0")
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("cannot verify a tracked branch; pinned revisions require manual updates")
	}
	return nil
}

// RunAutoUpdates belongs to the daemon. It never starts a second process or restarts QML.
func (m *Manager) RunAutoUpdates(stop <-chan struct{}) {
	timer := time.NewTimer(time.Minute)
	defer timer.Stop()
	for {
		select {
		case <-stop:
			return
		case <-timer.C:
		}
		m.mu.Lock()
		state, err := m.loadState()
		u := m.updateState()
		_, pending := m.readPendingActivation()
		ready := err == nil && automaticDue(state, u, pending, time.Now())
		m.mu.Unlock()
		if ready {
			status, err := m.CheckUpdates(nil, true)
			if err == nil && status.Updates.CanApply && !status.Updates.RequiresReview {
				select {
				case <-stop:
					return
				default:
				}
				_, _ = m.ApplyUpdates(status.Updates.PlanID, false)
			}
		}
		timer.Reset(15 * time.Minute)
	}
}

func automaticDue(state State, updates UpdateState, pending bool, now time.Time) bool {
	if state.Disabled || updates.Busy || updates.CanApply || pending {
		return false
	}
	due, _ := time.Parse(time.RFC3339, updates.NextCheck)
	if now.Before(due) {
		return false
	}
	for _, mod := range state.Mods {
		if automaticEnabled(state, mod) {
			return true
		}
	}
	return false
}

func sortedStrings(values []string) []string {
	result := append([]string{}, values...)
	sort.Strings(result)
	return result
}
