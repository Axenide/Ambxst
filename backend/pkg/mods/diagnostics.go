package mods

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"ambxst/backend/pkg/paths"
)

var diagnosticURL = regexp.MustCompile(`(?i)(?:https?|ssh)://[^\s"<>]+|[\w.-]+@[\w.-]+:[^\s"<>]+`)
var diagnosticPath = regexp.MustCompile(`(?:/[\w.~@+%-]+){2,}`)

func redactDiagnostic(value string) string {
	value = diagnosticURL.ReplaceAllString(value, "[source]")
	if home, err := os.UserHomeDir(); err == nil && home != "" {
		value = strings.ReplaceAll(value, home, "[home]")
	}
	return diagnosticPath.ReplaceAllString(value, "[path]")
}

func (m *Manager) Diagnostics() (map[string]string, error) {
	status, err := m.Status()
	if err != nil {
		return nil, err
	}
	// Allowlist fields. Settings, environment, sources, and raw process output
	// can contain credentials and are deliberately absent.
	type modReport struct {
		ID         string `json:"id"`
		Version    string `json:"version"`
		Revision   string `json:"revision"`
		Enabled    bool   `json:"enabled"`
		Order      int    `json:"order"`
		Valid      bool   `json:"valid"`
		Compatible bool   `json:"compatible"`
	}
	type updateFailure struct {
		ID   string `json:"id"`
		Code string `json:"code"`
	}
	report := struct {
		Version           string          `json:"ambxstVersion"`
		Revision          string          `json:"ambxstRevision"`
		Generation        string          `json:"generation"`
		GenerationCurrent bool            `json:"generationCurrent"`
		RestartRequired   bool            `json:"restartRequired"`
		UpdatePhase       string          `json:"updatePhase"`
		ErrorCode         string          `json:"updateErrorCode,omitempty"`
		Mods              []modReport     `json:"mods"`
		UpdateFailures    []updateFailure `json:"updateFailures,omitempty"`
	}{Version: status.BaseVersion, Revision: status.BaseRevision, Generation: status.ActiveGeneration, GenerationCurrent: status.GenerationCurrent, RestartRequired: status.RestartRequired, UpdatePhase: status.Updates.Phase, ErrorCode: status.Updates.ErrorCode, Mods: []modReport{}}
	for _, mod := range status.Mods {
		report.Mods = append(report.Mods, modReport{mod.ID, mod.Version, mod.Revision, mod.Enabled, mod.Order, mod.Valid, mod.Compatible})
	}
	for _, item := range status.Updates.Items {
		if item.ErrorCode != "" {
			report.UpdateFailures = append(report.UpdateFailures, updateFailure{item.ID, item.ErrorCode})
		}
	}
	data, err := json.MarshalIndent(report, "", "  ")
	if err != nil {
		return nil, err
	}
	return map[string]string{"text": redactDiagnostic(string(data))}, nil
}

type CompatibilityReport struct {
	Version       string `json:"version"`
	Composes      bool   `json:"composes"`
	RuntimeTested bool   `json:"runtimeTested"`
	Details       string `json:"details,omitempty"`
}

// CheckBaseCompatibility accepts a local candidate checkout. It neither
// updates the shell nor executes candidate QML.
func (m *Manager) CheckBaseCompatibility(base string) (CompatibilityReport, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if base == "" {
		base = paths.FindBaseShellSource()
	}
	base, err := filepath.Abs(base)
	if err != nil {
		return CompatibilityReport{}, err
	}
	if _, err := os.Stat(filepath.Join(base, "shell.qml")); err != nil {
		return CompatibilityReport{}, fmt.Errorf("candidate must contain shell.qml")
	}
	state, err := m.loadState()
	if err != nil {
		return CompatibilityReport{}, err
	}
	// A preflight reports declared compatibility even if live composition uses a bypass.
	state.BypassVersionCheck = false
	report := CompatibilityReport{Version: readTrimmed(filepath.Join(base, "version"))}
	generation, err := m.buildGenerationAt(state, base, m.paths.ModPackagesDir())
	if err != nil {
		report.Details = redactDiagnostic(err.Error())
		return report, nil
	}
	report.Composes = true
	_ = os.RemoveAll(generation)
	return report, nil
}
