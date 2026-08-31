package mods

import (
	"archive/tar"
	"archive/zip"
	"compress/gzip"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"time"

	"ambxst/backend/pkg/paths"
)

const stateVersion = 1

const (
	maxPackageFiles = 10000
	maxPackageBytes = 128 << 20
)

type Manager struct {
	paths *paths.Paths
	mu    sync.Mutex
}

type State struct {
	Version            int            `json:"version"`
	Mods               []InstalledMod `json:"mods"`
	ActiveGeneration   string         `json:"activeGeneration,omitempty"`
	PreviousGeneration string         `json:"previousGeneration,omitempty"`
}

type InstalledMod struct {
	ID          string `json:"id"`
	Enabled     bool   `json:"enabled"`
	Order       int    `json:"order"`
	Source      string `json:"source"`
	SourceType  string `json:"sourceType"`
	Revision    string `json:"revision,omitempty"`
	InstalledAt string `json:"installedAt"`
}

type ModInfo struct {
	ID                 string   `json:"id"`
	Name               string   `json:"name"`
	Version            string   `json:"version"`
	Description        string   `json:"description"`
	License            string   `json:"license,omitempty"`
	Author             string   `json:"author,omitempty"`
	Enabled            bool     `json:"enabled"`
	Order              int      `json:"order"`
	Source             string   `json:"source"`
	SourceType         string   `json:"sourceType"`
	Revision           string   `json:"revision,omitempty"`
	Dependencies       []string `json:"dependencies,omitempty"`
	Conflicts          []string `json:"conflicts,omitempty"`
	Commands           []string `json:"commands,omitempty"`
	Permissions        []string `json:"permissions,omitempty"`
	AffectedFiles      []string `json:"affectedFiles"`
	HasSettings        bool     `json:"hasSettings"`
	Valid              bool     `json:"valid"`
	Error              string   `json:"error,omitempty"`
	Compatible         bool     `json:"compatible"`
	CompatibilityError string   `json:"compatibilityError,omitempty"`
}

type ModSettings struct {
	ID              string         `json:"id"`
	Fields          []SettingField `json:"fields"`
	Values          map[string]any `json:"values"`
	RestartRequired bool           `json:"restartRequired,omitempty"`
}

type Status struct {
	BasePath           string    `json:"basePath"`
	BaseVersion        string    `json:"baseVersion"`
	BaseRevision       string    `json:"baseRevision,omitempty"`
	ActiveGeneration   string    `json:"activeGeneration,omitempty"`
	PreviousGeneration string    `json:"previousGeneration,omitempty"`
	GenerationCurrent  bool      `json:"generationCurrent"`
	GenerationError    string    `json:"generationError,omitempty"`
	RestartRequired    bool      `json:"restartRequired"`
	Mods               []ModInfo `json:"mods"`
}

type generationMetadata struct {
	ID           string   `json:"id"`
	CreatedAt    string   `json:"createdAt"`
	BasePath     string   `json:"basePath"`
	BaseVersion  string   `json:"baseVersion"`
	BaseRevision string   `json:"baseRevision,omitempty"`
	Mods         []string `json:"mods"`
}

type pendingActivation struct {
	Generation         string `json:"generation"`
	PreviousGeneration string `json:"previousGeneration,omitempty"`
}

func NewManager(p *paths.Paths) *Manager {
	return &Manager{paths: p}
}

func (m *Manager) Status() (Status, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	state, err := m.loadState()
	if err != nil {
		return Status{}, err
	}
	return m.statusFor(state)
}

func (m *Manager) Install(source string) (Status, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	source = strings.TrimSpace(source)
	if source == "" {
		return Status{}, fmt.Errorf("source is required")
	}
	if err := os.MkdirAll(m.paths.ModPackagesDir(), 0o755); err != nil {
		return Status{}, err
	}
	tmp, err := os.MkdirTemp(m.paths.ModPackagesDir(), ".install-")
	if err != nil {
		return Status{}, err
	}
	defer os.RemoveAll(tmp)

	packageRoot := filepath.Join(tmp, "package")
	sourceType := "local"
	if isGitSource(source) {
		sourceType = "git"
		if err := runCommandTimeout(5*time.Minute, "", "git", "clone", "--depth=1", source, packageRoot); err != nil {
			return Status{}, fmt.Errorf("clone source: %w", err)
		}
	} else {
		absolute, err := filepath.Abs(source)
		if err != nil {
			return Status{}, err
		}
		info, err := os.Stat(absolute)
		if err != nil {
			return Status{}, fmt.Errorf("inspect source: %w", err)
		}
		if info.IsDir() {
			if err := copyTree(absolute, packageRoot, func(path string, entry fs.DirEntry) bool {
				return path != absolute && entry.IsDir() && entry.Name() == ".git"
			}); err != nil {
				return Status{}, fmt.Errorf("copy source: %w", err)
			}
		} else {
			sourceType = "archive"
			if err := extractPackageArchive(absolute, packageRoot); err != nil {
				return Status{}, err
			}
		}
		source = absolute
	}
	packageRoot, err = locatePackageRoot(packageRoot)
	if err != nil {
		return Status{}, err
	}

	manifest, err := LoadManifest(packageRoot)
	if err != nil {
		return Status{}, err
	}
	state, err := m.loadState()
	if err != nil {
		return Status{}, err
	}
	if _, ok := findInstalled(state, manifest.ID); ok {
		return Status{}, fmt.Errorf("mod %q is already installed", manifest.ID)
	}
	destination := filepath.Join(m.paths.ModPackagesDir(), manifest.ID)
	if _, err := os.Stat(destination); err == nil {
		return Status{}, fmt.Errorf("package directory already exists for %q", manifest.ID)
	}
	if err := os.Rename(packageRoot, destination); err != nil {
		return Status{}, fmt.Errorf("store package: %w", err)
	}
	revision := gitRevision(destination)
	state.Mods = append(state.Mods, InstalledMod{
		ID:          manifest.ID,
		Enabled:     false,
		Order:       len(state.Mods),
		Source:      source,
		SourceType:  sourceType,
		Revision:    revision,
		InstalledAt: time.Now().UTC().Format(time.RFC3339),
	})
	if err := m.saveState(state); err != nil {
		os.RemoveAll(destination)
		return Status{}, err
	}
	return m.statusFor(state)
}

func (m *Manager) SetEnabled(id string, enabled bool) (Status, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	state, err := m.loadState()
	if err != nil {
		return Status{}, err
	}
	index, ok := findInstalled(state, id)
	if !ok {
		return Status{}, fmt.Errorf("mod %q is not installed", id)
	}
	if state.Mods[index].Enabled == enabled {
		return m.statusFor(state)
	}
	next := cloneState(state)
	next.Mods[index].Enabled = enabled
	if err := m.composeAndActivate(state, &next); err != nil {
		return Status{}, err
	}
	return m.statusForRestart(next, true)
}

func (m *Manager) Rebuild() (Status, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	state, err := m.loadState()
	if err != nil {
		return Status{}, err
	}
	hasEnabled := false
	for _, installed := range state.Mods {
		hasEnabled = hasEnabled || installed.Enabled
	}
	if !hasEnabled && state.ActiveGeneration == "" {
		return m.statusFor(state)
	}
	next := cloneState(state)
	if err := m.composeAndActivate(state, &next); err != nil {
		return Status{}, err
	}
	restart := state.ActiveGeneration != "" || hasEnabled
	return m.statusForRestart(next, restart)
}

func (m *Manager) Remove(id string) (Status, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	state, err := m.loadState()
	if err != nil {
		return Status{}, err
	}
	index, ok := findInstalled(state, id)
	if !ok {
		return Status{}, fmt.Errorf("mod %q is not installed", id)
	}
	next := cloneState(state)
	next.Mods = append(next.Mods[:index], next.Mods[index+1:]...)
	for i := range next.Mods {
		next.Mods[i].Order = i
	}
	if state.Mods[index].Enabled {
		if err := m.composeAndActivate(state, &next); err != nil {
			return Status{}, err
		}
	} else if err := m.saveState(next); err != nil {
		return Status{}, err
	}
	if err := os.RemoveAll(filepath.Join(m.paths.ModPackagesDir(), id)); err != nil {
		return Status{}, fmt.Errorf("remove package: %w", err)
	}
	if err := os.Remove(filepath.Join(m.paths.ModSettingsDir(), id+".json")); err != nil && !os.IsNotExist(err) {
		return Status{}, fmt.Errorf("remove settings: %w", err)
	}
	return m.statusForRestart(next, state.Mods[index].Enabled)
}

func (m *Manager) Move(id string, direction int) (Status, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if direction != -1 && direction != 1 {
		return Status{}, fmt.Errorf("direction must be -1 or 1")
	}
	state, err := m.loadState()
	if err != nil {
		return Status{}, err
	}
	index, ok := findInstalled(state, id)
	if !ok {
		return Status{}, fmt.Errorf("mod %q is not installed", id)
	}
	target := index + direction
	if target < 0 || target >= len(state.Mods) {
		return m.statusFor(state)
	}
	next := cloneState(state)
	next.Mods[index], next.Mods[target] = next.Mods[target], next.Mods[index]
	for i := range next.Mods {
		next.Mods[i].Order = i
	}
	rebuild := next.Mods[index].Enabled && next.Mods[target].Enabled
	if rebuild {
		if err := m.composeAndActivate(state, &next); err != nil {
			return Status{}, err
		}
	} else if err := m.saveState(next); err != nil {
		return Status{}, err
	}
	return m.statusForRestart(next, rebuild)
}

func (m *Manager) Update(id string) (Status, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	state, err := m.loadState()
	if err != nil {
		return Status{}, err
	}
	index, ok := findInstalled(state, id)
	if !ok {
		return Status{}, fmt.Errorf("mod %q is not installed", id)
	}
	installed := state.Mods[index]
	packageRoot := filepath.Join(m.paths.ModPackagesDir(), id)
	if installed.SourceType != "git" {
		return m.updateLocalSource(state, index, installed, packageRoot)
	}
	oldRevision := gitRevision(packageRoot)
	if err := runCommandTimeout(5*time.Minute, packageRoot, "git", "pull", "--ff-only"); err != nil {
		return Status{}, fmt.Errorf("update mod: %w", err)
	}
	manifest, err := LoadManifest(packageRoot)
	if err != nil || manifest.ID != id {
		_ = runCommand(packageRoot, "git", "reset", "--hard", oldRevision)
		if err != nil {
			return Status{}, err
		}
		return Status{}, fmt.Errorf("updated package changed its id")
	}
	next := cloneState(state)
	next.Mods[index].Revision = gitRevision(packageRoot)
	if installed.Enabled {
		if err := m.composeAndActivate(state, &next); err != nil {
			_ = runCommand(packageRoot, "git", "reset", "--hard", oldRevision)
			return Status{}, err
		}
	} else if err := m.saveState(next); err != nil {
		_ = runCommand(packageRoot, "git", "reset", "--hard", oldRevision)
		return Status{}, err
	}
	return m.statusForRestart(next, installed.Enabled)
}

func (m *Manager) updateLocalSource(state State, index int, installed InstalledMod, packageRoot string) (Status, error) {
	tmp, err := os.MkdirTemp(m.paths.ModPackagesDir(), ".update-")
	if err != nil {
		return Status{}, err
	}
	defer os.RemoveAll(tmp)

	updatedRoot := filepath.Join(tmp, "package")
	switch installed.SourceType {
	case "local":
		info, err := os.Stat(installed.Source)
		if err != nil {
			return Status{}, fmt.Errorf("inspect source: %w", err)
		}
		if !info.IsDir() {
			return Status{}, fmt.Errorf("local source is not a directory")
		}
		if err := copyTree(installed.Source, updatedRoot, func(path string, entry fs.DirEntry) bool {
			return path != installed.Source && entry.IsDir() && entry.Name() == ".git"
		}); err != nil {
			return Status{}, fmt.Errorf("copy source: %w", err)
		}
	case "archive":
		if err := extractPackageArchive(installed.Source, updatedRoot); err != nil {
			return Status{}, err
		}
	default:
		return Status{}, fmt.Errorf("mod %q has unsupported source type %q", installed.ID, installed.SourceType)
	}
	updatedRoot, err = locatePackageRoot(updatedRoot)
	if err != nil {
		return Status{}, err
	}
	manifest, err := LoadManifest(updatedRoot)
	if err != nil {
		return Status{}, err
	}
	if manifest.ID != installed.ID {
		return Status{}, fmt.Errorf("updated package changed its id")
	}

	backup := filepath.Join(tmp, "previous")
	if err := os.Rename(packageRoot, backup); err != nil {
		return Status{}, fmt.Errorf("prepare package update: %w", err)
	}
	restore := func() {
		_ = os.RemoveAll(packageRoot)
		_ = os.Rename(backup, packageRoot)
	}
	if err := os.Rename(updatedRoot, packageRoot); err != nil {
		restore()
		return Status{}, fmt.Errorf("store package update: %w", err)
	}

	next := cloneState(state)
	next.Mods[index].Revision = ""
	if installed.Enabled {
		if err := m.composeAndActivate(state, &next); err != nil {
			restore()
			return Status{}, err
		}
	} else if err := m.saveState(next); err != nil {
		restore()
		return Status{}, err
	}
	return m.statusForRestart(next, installed.Enabled)
}

func (m *Manager) Settings(id string) (ModSettings, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.loadSettings(id)
}

func (m *Manager) SetSetting(id, key string, value any) (ModSettings, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	settings, err := m.loadSettings(id)
	if err != nil {
		return ModSettings{}, err
	}
	var field *SettingField
	for i := range settings.Fields {
		if settings.Fields[i].Key == key {
			field = &settings.Fields[i]
			break
		}
	}
	if field == nil {
		return ModSettings{}, fmt.Errorf("unknown setting %q", key)
	}
	if err := validateSettingValue(*field, value); err != nil {
		return ModSettings{}, fmt.Errorf("setting %s: %w", key, err)
	}
	settings.Values[key] = value
	data, err := json.MarshalIndent(settings.Values, "", "  ")
	if err != nil {
		return ModSettings{}, err
	}
	path := filepath.Join(m.paths.ModSettingsDir(), id+".json")
	if err := writeAtomic(path, append(data, '\n'), 0o644); err != nil {
		return ModSettings{}, err
	}
	settings.RestartRequired = field.RestartRequired
	return settings, nil
}

func (m *Manager) Rollback() (Status, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	state, err := m.loadState()
	if err != nil {
		return Status{}, err
	}
	if state.PreviousGeneration == "" {
		return Status{}, fmt.Errorf("no previous generation is available")
	}
	previousPath := filepath.Join(m.paths.ModGenerationsDir(), state.PreviousGeneration)
	if _, err := os.Stat(filepath.Join(previousPath, "shell.qml")); err != nil {
		return Status{}, fmt.Errorf("previous generation is unavailable")
	}
	metadata, err := readGenerationMetadata(previousPath)
	if err != nil {
		return Status{}, err
	}
	pending, activationPending := m.readPendingActivation()
	next := cloneState(state)
	next.ActiveGeneration, next.PreviousGeneration = state.PreviousGeneration, state.ActiveGeneration
	if activationPending && pending.Generation == state.ActiveGeneration {
		if pending.PreviousGeneration != state.PreviousGeneration {
			return Status{}, fmt.Errorf("pending activation does not match mod state")
		}
		// Do not expose the untested generation as a rollback target.
		next.PreviousGeneration = ""
	}
	enabled := make(map[string]bool, len(metadata.Mods))
	for _, id := range metadata.Mods {
		enabled[id] = true
	}
	for i := range next.Mods {
		next.Mods[i].Enabled = enabled[next.Mods[i].ID]
	}
	if err := m.saveState(next); err != nil {
		return Status{}, err
	}
	// The target has already passed its startup trial.
	if err := os.Remove(m.paths.ModPendingActivationFile()); err != nil && !os.IsNotExist(err) {
		return Status{}, err
	}
	return m.statusForRestart(next, true)
}

func (m *Manager) HasPendingActivation() bool {
	m.mu.Lock()
	defer m.mu.Unlock()
	pending, ok := m.readPendingActivation()
	if !ok {
		return false
	}
	state, err := m.loadState()
	if err != nil || state.ActiveGeneration != pending.Generation {
		_ = os.Remove(m.paths.ModPendingActivationFile())
		return false
	}
	if state.ActiveGeneration == "" {
		return paths.FindBaseShellSource() != ""
	}
	generation := filepath.Join(m.paths.ModGenerationsDir(), state.ActiveGeneration)
	if paths.ValidateModGeneration(generation, paths.FindBaseShellSource()) != nil {
		return false
	}
	return true
}

func (m *Manager) MarkHealthy() error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if err := os.Remove(m.paths.ModPendingActivationFile()); err != nil && !os.IsNotExist(err) {
		return err
	}
	return nil
}

// RecoverFailedActivation restores the generation that was active before the
// most recent transaction. It returns false when no pending activation exists.
func (m *Manager) RecoverFailedActivation() (bool, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	data, err := os.ReadFile(m.paths.ModPendingActivationFile())
	if os.IsNotExist(err) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	var pending pendingActivation
	if err := json.Unmarshal(data, &pending); err != nil {
		return false, fmt.Errorf("parse pending activation: %w", err)
	}
	state, err := m.loadState()
	if err != nil {
		return false, err
	}
	if state.ActiveGeneration != pending.Generation {
		_ = os.Remove(m.paths.ModPendingActivationFile())
		return false, nil
	}

	state.ActiveGeneration = pending.PreviousGeneration
	state.PreviousGeneration = ""
	enabled := make(map[string]bool)
	if state.ActiveGeneration != "" {
		metadata, err := readGenerationMetadata(filepath.Join(m.paths.ModGenerationsDir(), state.ActiveGeneration))
		if err != nil {
			return false, err
		}
		for _, id := range metadata.Mods {
			enabled[id] = true
		}
	}
	for i := range state.Mods {
		state.Mods[i].Enabled = enabled[state.Mods[i].ID]
	}
	if err := m.saveState(state); err != nil {
		return false, err
	}
	if err := os.Remove(m.paths.ModPendingActivationFile()); err != nil && !os.IsNotExist(err) {
		return false, err
	}
	return true, nil
}

func (m *Manager) composeAndActivate(previous State, next *State) error {
	knownGood := m.knownGoodGeneration(previous)
	enabled := 0
	for _, mod := range next.Mods {
		if mod.Enabled {
			enabled++
		}
	}
	if enabled == 0 {
		next.PreviousGeneration = knownGood
		next.ActiveGeneration = ""
		if knownGood != "" {
			if err := m.writePendingActivation("", knownGood); err != nil {
				return err
			}
		} else if err := os.Remove(m.paths.ModPendingActivationFile()); err != nil && !os.IsNotExist(err) {
			return err
		}
		if err := m.saveState(*next); err != nil {
			if knownGood != "" {
				_ = os.Remove(m.paths.ModPendingActivationFile())
			}
			return err
		}
		return nil
	}

	generation, err := m.buildGeneration(*next)
	if err != nil {
		return err
	}
	next.PreviousGeneration = knownGood
	next.ActiveGeneration = filepath.Base(generation)
	if err := m.writePendingActivation(next.ActiveGeneration, next.PreviousGeneration); err != nil {
		return err
	}
	if err := m.saveState(*next); err != nil {
		_ = os.Remove(m.paths.ModPendingActivationFile())
		return err
	}
	m.cleanupGenerations(*next)
	return nil
}

// knownGoodGeneration keeps consecutive, not-yet-started rebuilds anchored to
// the last generation that completed the startup health window.
func (m *Manager) knownGoodGeneration(state State) string {
	pending, ok := m.readPendingActivation()
	if !ok || pending.Generation != state.ActiveGeneration {
		return state.ActiveGeneration
	}
	return pending.PreviousGeneration
}

func (m *Manager) readPendingActivation() (pendingActivation, bool) {
	data, err := os.ReadFile(m.paths.ModPendingActivationFile())
	if err != nil {
		return pendingActivation{}, false
	}
	var pending pendingActivation
	if json.Unmarshal(data, &pending) != nil {
		return pendingActivation{}, false
	}
	return pending, true
}

func (m *Manager) writePendingActivation(generation, previous string) error {
	pending := pendingActivation{Generation: generation, PreviousGeneration: previous}
	data, err := json.MarshalIndent(pending, "", "  ")
	if err != nil {
		return err
	}
	return writeAtomic(m.paths.ModPendingActivationFile(), append(data, '\n'), 0o644)
}

func (m *Manager) buildGeneration(state State) (string, error) {
	base := paths.FindBaseShellSource()
	if base == "" {
		return "", fmt.Errorf("Ambxst base source was not found")
	}
	manifests, ordered, err := m.resolve(state, base)
	if err != nil {
		return "", err
	}
	if err := os.MkdirAll(m.paths.ModGenerationsDir(), 0o755); err != nil {
		return "", err
	}
	tmp, err := os.MkdirTemp(m.paths.ModGenerationsDir(), ".build-")
	if err != nil {
		return "", err
	}
	keep := false
	defer func() {
		if !keep {
			os.RemoveAll(tmp)
		}
	}()

	if err := exportBase(base, tmp); err != nil {
		return "", fmt.Errorf("export base source: %w", err)
	}
	owners := make(map[string]string)
	for _, id := range ordered {
		manifest := manifests[id]
		packageRoot := filepath.Join(m.paths.ModPackagesDir(), id)
		files, err := manifest.AffectedFiles(packageRoot)
		if err != nil {
			return "", fmt.Errorf("mod %s: %w", id, err)
		}
		for _, file := range files {
			if owner, exists := owners[file]; exists {
				return "", fmt.Errorf("mods %s and %s both modify %s", owner, id, file)
			}
			owners[file] = id
		}
		for _, operation := range manifest.Operations {
			if err := applyOperation(tmp, packageRoot, operation); err != nil {
				return "", fmt.Errorf("mod %s: %w", id, err)
			}
		}
	}
	if _, err := os.Stat(filepath.Join(tmp, "shell.qml")); err != nil {
		return "", fmt.Errorf("generation has no shell.qml")
	}
	baseVersion := readTrimmed(filepath.Join(base, "version"))
	baseRevision := gitRevision(base)
	hash := sha256.Sum256([]byte(baseRevision + strings.Join(ordered, "\x00") + time.Now().UTC().Format(time.RFC3339Nano)))
	id := time.Now().UTC().Format("20060102T150405Z") + "-" + hex.EncodeToString(hash[:4])
	metadata := generationMetadata{
		ID:           id,
		CreatedAt:    time.Now().UTC().Format(time.RFC3339),
		BasePath:     base,
		BaseVersion:  baseVersion,
		BaseRevision: baseRevision,
		Mods:         ordered,
	}
	data, _ := json.MarshalIndent(metadata, "", "  ")
	if err := os.WriteFile(filepath.Join(tmp, ".ambxst-generation.json"), append(data, '\n'), 0o644); err != nil {
		return "", err
	}
	final := filepath.Join(m.paths.ModGenerationsDir(), id)
	if err := os.Rename(tmp, final); err != nil {
		return "", err
	}
	keep = true
	return final, nil
}

func (m *Manager) resolve(state State, base string) (map[string]Manifest, []string, error) {
	manifests := make(map[string]Manifest)
	installed := make(map[string]InstalledMod)
	for _, mod := range state.Mods {
		installed[mod.ID] = mod
		if !mod.Enabled {
			continue
		}
		manifest, err := LoadManifest(filepath.Join(m.paths.ModPackagesDir(), mod.ID))
		if err != nil {
			return nil, nil, fmt.Errorf("mod %s: %w", mod.ID, err)
		}
		if err := checkCompatibility(manifest, base); err != nil {
			return nil, nil, fmt.Errorf("mod %s: %w", mod.ID, err)
		}
		for _, command := range manifest.Commands {
			if _, err := exec.LookPath(command); err != nil {
				return nil, nil, fmt.Errorf("mod %s requires command %q", mod.ID, command)
			}
		}
		manifests[mod.ID] = manifest
	}
	for id, manifest := range manifests {
		for _, dependency := range manifest.Dependencies {
			dep, ok := installed[dependency]
			if !ok || !dep.Enabled {
				return nil, nil, fmt.Errorf("mod %s requires enabled mod %s", id, dependency)
			}
		}
		for _, conflict := range manifest.Conflicts {
			if other, ok := installed[conflict]; ok && other.Enabled {
				return nil, nil, fmt.Errorf("mods %s and %s conflict", id, conflict)
			}
		}
	}
	ordered, err := topologicalOrder(state.Mods, manifests)
	return manifests, ordered, err
}

func (m *Manager) statusFor(state State) (Status, error) {
	base := paths.FindBaseShellSource()
	status := Status{
		BasePath:           base,
		BaseVersion:        readTrimmed(filepath.Join(base, "version")),
		BaseRevision:       gitRevision(base),
		ActiveGeneration:   state.ActiveGeneration,
		PreviousGeneration: state.PreviousGeneration,
		GenerationCurrent:  true,
		Mods:               make([]ModInfo, 0, len(state.Mods)),
	}
	if pending, ok := m.readPendingActivation(); ok && pending.Generation == state.ActiveGeneration {
		status.RestartRequired = true
	}
	if state.ActiveGeneration != "" {
		generation := filepath.Join(m.paths.ModGenerationsDir(), state.ActiveGeneration)
		if err := paths.ValidateModGeneration(generation, base); err != nil {
			status.GenerationCurrent = false
			status.GenerationError = err.Error()
		}
	}
	for _, installed := range state.Mods {
		root := filepath.Join(m.paths.ModPackagesDir(), installed.ID)
		manifest, err := LoadManifest(root)
		if err != nil {
			status.Mods = append(status.Mods, ModInfo{
				ID:         installed.ID,
				Name:       installed.ID,
				Enabled:    installed.Enabled,
				Order:      installed.Order,
				Source:     installed.Source,
				SourceType: installed.SourceType,
				Revision:   installed.Revision,
				Valid:      false,
				Error:      err.Error(),
			})
			continue
		}
		files, err := manifest.AffectedFiles(root)
		if err != nil {
			status.Mods = append(status.Mods, ModInfo{
				ID:          manifest.ID,
				Name:        manifest.Name,
				Version:     manifest.Version,
				Description: manifest.Description,
				Enabled:     installed.Enabled,
				Order:       installed.Order,
				Source:      installed.Source,
				SourceType:  installed.SourceType,
				Revision:    installed.Revision,
				Valid:       false,
				Error:       err.Error(),
			})
			continue
		}
		compatibilityErr := checkCompatibility(manifest, base)
		compatibilityMessage := ""
		if compatibilityErr != nil {
			compatibilityMessage = compatibilityErr.Error()
		}
		status.Mods = append(status.Mods, ModInfo{
			ID:                 manifest.ID,
			Name:               manifest.Name,
			Version:            manifest.Version,
			Description:        manifest.Description,
			License:            manifest.License,
			Author:             manifest.Author,
			Enabled:            installed.Enabled,
			Order:              installed.Order,
			Source:             installed.Source,
			SourceType:         installed.SourceType,
			Revision:           installed.Revision,
			Dependencies:       manifest.Dependencies,
			Conflicts:          manifest.Conflicts,
			Commands:           manifest.Commands,
			Permissions:        manifest.Permissions,
			AffectedFiles:      files,
			HasSettings:        manifest.Settings != nil,
			Valid:              true,
			Compatible:         compatibilityErr == nil,
			CompatibilityError: compatibilityMessage,
		})
	}
	sort.SliceStable(status.Mods, func(i, j int) bool { return status.Mods[i].Order < status.Mods[j].Order })
	return status, nil
}

func (m *Manager) statusForRestart(state State, restart bool) (Status, error) {
	status, err := m.statusFor(state)
	if err != nil {
		return Status{}, err
	}
	status.RestartRequired = status.RestartRequired || restart
	return status, nil
}

func (m *Manager) loadSettings(id string) (ModSettings, error) {
	state, err := m.loadState()
	if err != nil {
		return ModSettings{}, err
	}
	if _, ok := findInstalled(state, id); !ok {
		return ModSettings{}, fmt.Errorf("mod %q is not installed", id)
	}
	packageRoot := filepath.Join(m.paths.ModPackagesDir(), id)
	manifest, err := LoadManifest(packageRoot)
	if err != nil {
		return ModSettings{}, err
	}
	if manifest.Settings == nil {
		return ModSettings{ID: id, Fields: []SettingField{}, Values: map[string]any{}}, nil
	}
	schemaPath, err := safeJoin(packageRoot, manifest.Settings.Schema)
	if err != nil {
		return ModSettings{}, err
	}
	schema, err := LoadSettingsSchema(schemaPath)
	if err != nil {
		return ModSettings{}, err
	}
	values := make(map[string]any, len(schema.Fields))
	for _, field := range schema.Fields {
		values[field.Key] = field.Default
	}
	data, err := os.ReadFile(filepath.Join(m.paths.ModSettingsDir(), id+".json"))
	if err == nil {
		var stored map[string]any
		if json.Unmarshal(data, &stored) == nil {
			for _, field := range schema.Fields {
				if value, ok := stored[field.Key]; ok && validateSettingValue(field, value) == nil {
					values[field.Key] = value
				}
			}
		}
	}
	return ModSettings{ID: id, Fields: schema.Fields, Values: values}, nil
}

func (m *Manager) loadState() (State, error) {
	data, err := os.ReadFile(m.paths.ModStateFile())
	if os.IsNotExist(err) {
		return State{Version: stateVersion, Mods: []InstalledMod{}}, nil
	}
	if err != nil {
		return State{}, err
	}
	var state State
	if err := json.Unmarshal(data, &state); err != nil {
		return State{}, fmt.Errorf("parse mod state: %w", err)
	}
	if state.Version != stateVersion {
		return State{}, fmt.Errorf("unsupported mod state version %d", state.Version)
	}
	if state.Mods == nil {
		state.Mods = []InstalledMod{}
	}
	return state, nil
}

func (m *Manager) saveState(state State) error {
	state.Version = stateVersion
	data, err := json.MarshalIndent(state, "", "  ")
	if err != nil {
		return err
	}
	return writeAtomic(m.paths.ModStateFile(), append(data, '\n'), 0o644)
}

func (m *Manager) cleanupGenerations(state State) {
	entries, err := os.ReadDir(m.paths.ModGenerationsDir())
	if err != nil {
		return
	}
	protected := map[string]bool{state.ActiveGeneration: true, state.PreviousGeneration: true}
	var candidates []os.DirEntry
	for _, entry := range entries {
		if entry.IsDir() && !strings.HasPrefix(entry.Name(), ".") && !protected[entry.Name()] {
			candidates = append(candidates, entry)
		}
	}
	sort.Slice(candidates, func(i, j int) bool { return candidates[i].Name() > candidates[j].Name() })
	if len(candidates) <= 1 {
		return
	}
	for _, entry := range candidates[1:] {
		_ = os.RemoveAll(filepath.Join(m.paths.ModGenerationsDir(), entry.Name()))
	}
}

func applyOperation(generation, packageRoot string, op Operation) error {
	source, err := safeJoin(packageRoot, op.Source)
	if err != nil {
		return err
	}
	if op.Type == "patch" {
		if err := runCommand(generation, "git", "apply", "--check", "--whitespace=error-all", source); err != nil {
			return fmt.Errorf("patch check failed: %w", err)
		}
		if err := runCommand(generation, "git", "apply", "--whitespace=error-all", source); err != nil {
			return fmt.Errorf("apply patch: %w", err)
		}
		return nil
	}
	target, err := safeJoin(generation, op.Target)
	if err != nil {
		return err
	}
	if info, err := os.Stat(target); err == nil {
		if info.IsDir() {
			return fmt.Errorf("overlay target is a directory: %s", op.Target)
		}
		if !op.Replace {
			return fmt.Errorf("overlay target already exists: %s", op.Target)
		}
		hash, err := fileSHA256(target)
		if err != nil {
			return err
		}
		if !strings.EqualFold(hash, op.ExpectedSHA256) {
			return fmt.Errorf("overlay target changed: %s", op.Target)
		}
	} else {
		if !os.IsNotExist(err) {
			return err
		}
		if op.Replace {
			return fmt.Errorf("overlay target is missing: %s", op.Target)
		}
	}
	return copyFile(source, target)
}

func checkCompatibility(manifest Manifest, base string) error {
	baseVersion := readTrimmed(filepath.Join(base, "version"))
	if !matchesVersion(baseVersion, manifest.Compatibility.Ambxst) {
		return fmt.Errorf("Ambxst %s does not match %q", baseVersion, manifest.Compatibility.Ambxst)
	}
	if len(manifest.Compatibility.TestedBaseCommits) > 0 {
		revision := gitRevision(base)
		matched := false
		for _, allowed := range manifest.Compatibility.TestedBaseCommits {
			if strings.EqualFold(revision, allowed) {
				matched = true
				break
			}
		}
		if !matched {
			return fmt.Errorf("base revision %s has not been tested", shortRevision(revision))
		}
	}
	return nil
}

func topologicalOrder(installed []InstalledMod, manifests map[string]Manifest) ([]string, error) {
	order := make(map[string]int)
	for _, mod := range installed {
		order[mod.ID] = mod.Order
	}
	visiting := make(map[string]bool)
	visited := make(map[string]bool)
	var result []string
	var visit func(string) error
	visit = func(id string) error {
		if visited[id] {
			return nil
		}
		if visiting[id] {
			return fmt.Errorf("dependency cycle includes %s", id)
		}
		visiting[id] = true
		deps := append([]string{}, manifests[id].Dependencies...)
		sort.SliceStable(deps, func(i, j int) bool { return order[deps[i]] < order[deps[j]] })
		for _, dependency := range deps {
			if _, ok := manifests[dependency]; !ok {
				return fmt.Errorf("mod %s requires unavailable mod %s", id, dependency)
			}
			if err := visit(dependency); err != nil {
				return err
			}
		}
		visiting[id] = false
		visited[id] = true
		result = append(result, id)
		return nil
	}
	ids := make([]string, 0, len(manifests))
	for id := range manifests {
		ids = append(ids, id)
	}
	sort.SliceStable(ids, func(i, j int) bool { return order[ids[i]] < order[ids[j]] })
	for _, id := range ids {
		if err := visit(id); err != nil {
			return nil, err
		}
	}
	return result, nil
}

func exportBase(base, destination string) error {
	if gitRevision(base) != "" {
		cmd := exec.Command("git", "-C", base, "archive", "--format=tar", "HEAD")
		stdout, err := cmd.StdoutPipe()
		if err != nil {
			return err
		}
		cmd.Stderr = os.Stderr
		if err := cmd.Start(); err != nil {
			return err
		}
		extractErr := extractTar(stdout, destination, true, 0, 0)
		if extractErr != nil {
			// Stop the producer before waiting. Otherwise git can block forever
			// writing to a pipe that is no longer being read.
			_ = stdout.Close()
			_ = cmd.Process.Kill()
		}
		waitErr := cmd.Wait()
		if extractErr != nil {
			return extractErr
		}
		return errors.Join(extractErr, waitErr)
	}
	return copyTree(base, destination, func(path string, entry fs.DirEntry) bool {
		relative, err := filepath.Rel(base, path)
		if err != nil || strings.Contains(relative, string(filepath.Separator)) {
			return false
		}
		name := entry.Name()
		return name == ".git" || name == ".ui-craft" || name == "dist" || name == "ambxst"
	})
}

func extractTar(reader io.Reader, destination string, allowSymlinks bool, maxFiles int, maxBytes int64) error {
	tarReader := tar.NewReader(reader)
	files := 0
	var totalBytes int64
	for {
		header, err := tarReader.Next()
		if errors.Is(err, io.EOF) {
			return nil
		}
		if err != nil {
			return err
		}
		files++
		totalBytes += header.Size
		if maxFiles > 0 && files > maxFiles {
			return fmt.Errorf("archive contains too many files")
		}
		if maxBytes > 0 && totalBytes > maxBytes {
			return fmt.Errorf("archive expands beyond the size limit")
		}
		target, err := safeJoin(destination, header.Name)
		if err != nil {
			return err
		}
		switch header.Typeflag {
		case tar.TypeXHeader, tar.TypeXGlobalHeader:
			// archive/tar applies PAX metadata to the following entry. Git uses
			// a global header for commit metadata in its default tar output.
			continue
		case tar.TypeDir:
			if err := os.MkdirAll(target, os.FileMode(header.Mode)&0o755); err != nil {
				return err
			}
		case tar.TypeReg:
			if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
				return err
			}
			file, err := os.OpenFile(target, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, os.FileMode(header.Mode)&0o755)
			if err != nil {
				return err
			}
			_, copyErr := io.Copy(file, tarReader)
			closeErr := file.Close()
			if err := errors.Join(copyErr, closeErr); err != nil {
				return err
			}
		case tar.TypeSymlink:
			if !allowSymlinks {
				return fmt.Errorf("package symlinks are not allowed: %s", header.Name)
			}
			cleanLink := filepath.Clean(header.Linkname)
			if filepath.IsAbs(cleanLink) || cleanLink == ".." || strings.HasPrefix(cleanLink, ".."+string(filepath.Separator)) {
				return fmt.Errorf("base archive contains unsafe symlink %q", header.Name)
			}
			if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
				return err
			}
			if err := os.Symlink(header.Linkname, target); err != nil {
				return err
			}
		default:
			return fmt.Errorf("archive contains unsupported entry %q", header.Name)
		}
	}
}

func extractPackageArchive(path, destination string) error {
	lower := strings.ToLower(path)
	switch {
	case strings.HasSuffix(lower, ".zip"):
		return extractZipPackage(path, destination)
	case strings.HasSuffix(lower, ".tar"):
		file, err := os.Open(path)
		if err != nil {
			return err
		}
		defer file.Close()
		return extractTar(file, destination, false, maxPackageFiles, maxPackageBytes)
	case strings.HasSuffix(lower, ".tar.gz"), strings.HasSuffix(lower, ".tgz"):
		file, err := os.Open(path)
		if err != nil {
			return err
		}
		defer file.Close()
		reader, err := gzip.NewReader(file)
		if err != nil {
			return fmt.Errorf("open gzip archive: %w", err)
		}
		defer reader.Close()
		return extractTar(reader, destination, false, maxPackageFiles, maxPackageBytes)
	default:
		return fmt.Errorf("unsupported package archive")
	}
}

func extractZipPackage(path, destination string) error {
	archive, err := zip.OpenReader(path)
	if err != nil {
		return fmt.Errorf("open zip archive: %w", err)
	}
	defer archive.Close()
	if len(archive.File) > maxPackageFiles {
		return fmt.Errorf("archive contains too many files")
	}
	var total uint64
	for _, entry := range archive.File {
		total += entry.UncompressedSize64
		if total > maxPackageBytes {
			return fmt.Errorf("archive expands beyond the size limit")
		}
		if entry.Mode()&os.ModeSymlink != 0 {
			return fmt.Errorf("package symlinks are not allowed: %s", entry.Name)
		}
		target, err := safeJoin(destination, entry.Name)
		if err != nil {
			return err
		}
		if entry.FileInfo().IsDir() {
			if err := os.MkdirAll(target, 0o755); err != nil {
				return err
			}
			continue
		}
		reader, err := entry.Open()
		if err != nil {
			return err
		}
		if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
			reader.Close()
			return err
		}
		output, err := os.OpenFile(target, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, entry.Mode().Perm()&0o755)
		if err != nil {
			reader.Close()
			return err
		}
		copyErr := func() error {
			_, err := io.Copy(output, reader)
			return errors.Join(err, output.Close(), reader.Close())
		}()
		if copyErr != nil {
			return copyErr
		}
	}
	return nil
}

func locatePackageRoot(root string) (string, error) {
	if _, err := os.Stat(filepath.Join(root, ManifestFile)); err == nil {
		return root, nil
	}
	entries, err := os.ReadDir(root)
	if err != nil {
		return "", err
	}
	var matches []string
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		candidate := filepath.Join(root, entry.Name())
		if _, err := os.Stat(filepath.Join(candidate, ManifestFile)); err == nil {
			matches = append(matches, candidate)
		}
	}
	if len(matches) != 1 {
		return "", fmt.Errorf("archive must contain one package manifest")
	}
	return matches[0], nil
}

func copyTree(source, destination string, skip func(string, fs.DirEntry) bool) error {
	info, err := os.Stat(source)
	if err != nil {
		return err
	}
	if !info.IsDir() {
		return fmt.Errorf("source is not a directory")
	}
	return filepath.WalkDir(source, func(path string, entry fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if skip != nil && path != source && skip(path, entry) {
			if entry.IsDir() {
				return filepath.SkipDir
			}
			return nil
		}
		relative, err := filepath.Rel(source, path)
		if err != nil {
			return err
		}
		target := filepath.Join(destination, relative)
		info, err := entry.Info()
		if err != nil {
			return err
		}
		if info.Mode()&os.ModeSymlink != 0 {
			return fmt.Errorf("symlinks are not allowed: %s", path)
		}
		if entry.IsDir() {
			return os.MkdirAll(target, info.Mode().Perm())
		}
		if !info.Mode().IsRegular() {
			return fmt.Errorf("unsupported file type: %s", path)
		}
		return copyFile(path, target)
	})
}

func copyFile(source, destination string) error {
	input, err := os.Open(source)
	if err != nil {
		return err
	}
	defer input.Close()
	info, err := input.Stat()
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(destination), 0o755); err != nil {
		return err
	}
	output, err := os.OpenFile(destination, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, info.Mode().Perm())
	if err != nil {
		return err
	}
	_, copyErr := io.Copy(output, input)
	return errors.Join(copyErr, output.Close())
}

func fileSHA256(path string) (string, error) {
	f, err := os.Open(path)
	if err != nil {
		return "", err
	}
	defer f.Close()
	hash := sha256.New()
	if _, err := io.Copy(hash, f); err != nil {
		return "", err
	}
	return hex.EncodeToString(hash.Sum(nil)), nil
}

func writeAtomic(path string, data []byte, mode os.FileMode) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	tmp, err := os.CreateTemp(filepath.Dir(path), ".tmp-")
	if err != nil {
		return err
	}
	tmpPath := tmp.Name()
	defer os.Remove(tmpPath)
	if err := tmp.Chmod(mode); err != nil {
		tmp.Close()
		return err
	}
	if _, err := tmp.Write(data); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Sync(); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	return os.Rename(tmpPath, path)
}

func runCommand(directory, name string, args ...string) error {
	return runCommandTimeout(0, directory, name, args...)
}

func runCommandTimeout(timeout time.Duration, directory, name string, args ...string) error {
	var (
		cmd    *exec.Cmd
		cancel context.CancelFunc
	)
	if timeout > 0 {
		ctx, stop := context.WithTimeout(context.Background(), timeout)
		cancel = stop
		cmd = exec.CommandContext(ctx, name, args...)
	} else {
		cmd = exec.Command(name, args...)
	}
	if cancel != nil {
		defer cancel()
	}
	cmd.Dir = directory
	output, err := cmd.CombinedOutput()
	if err != nil {
		message := strings.TrimSpace(string(output))
		if message != "" {
			return fmt.Errorf("%s: %w", message, err)
		}
		return err
	}
	return nil
}

func isGitSource(source string) bool {
	return strings.HasPrefix(source, "https://") || strings.HasPrefix(source, "ssh://") || strings.HasPrefix(source, "git@")
}

func gitRevision(directory string) string {
	if directory == "" {
		return ""
	}
	cmd := exec.Command("git", "-C", directory, "rev-parse", "HEAD")
	output, err := cmd.Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(output))
}

func shortRevision(revision string) string {
	if len(revision) > 12 {
		return revision[:12]
	}
	if revision == "" {
		return "unknown"
	}
	return revision
}

func readTrimmed(path string) string {
	data, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(data))
}

func readGenerationMetadata(root string) (generationMetadata, error) {
	data, err := os.ReadFile(filepath.Join(root, ".ambxst-generation.json"))
	if err != nil {
		return generationMetadata{}, fmt.Errorf("read generation metadata: %w", err)
	}
	var metadata generationMetadata
	if err := json.Unmarshal(data, &metadata); err != nil {
		return generationMetadata{}, fmt.Errorf("parse generation metadata: %w", err)
	}
	return metadata, nil
}

func findInstalled(state State, id string) (int, bool) {
	for i, mod := range state.Mods {
		if mod.ID == id {
			return i, true
		}
	}
	return -1, false
}

func cloneState(state State) State {
	cloned := state
	cloned.Mods = append([]InstalledMod{}, state.Mods...)
	return cloned
}
