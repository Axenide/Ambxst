package paths

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

type modGenerationMetadata struct {
	ID           string `json:"id"`
	BasePath     string `json:"basePath"`
	BaseVersion  string `json:"baseVersion"`
	BaseRevision string `json:"baseRevision"`
}

type modStateSource struct {
	ActiveGeneration string `json:"activeGeneration"`
}

// FindShellSource returns the active Ambxst shell tree. A valid mod generation
// takes precedence unless AMBXST_MODS_DISABLED=1. Without one, the base source
// lookup below is used.
//
// Base source lookup order — first hit wins:
//  1. $AMBXST_SHELL — explicit override for development.
//  2. The directory containing the running binary, if shell.qml is a
//     sibling/ancestor (handles `go build` outputs in ./ and ./backend).
//  3. ShellPathFile (~/.local/share/ambxst/shell_repo), written by the
//     installer with the install target.
//  4. The current working directory, if shell.qml is here.
//  5. $HOME/.local/src/ambxst — the upstream dev default.
//
// Returns "" only when nothing matched (callers must handle the empty
// case for asset lookups).
func FindShellSource() string {
	base := FindBaseShellSource()
	p := New()
	if os.Getenv("AMBXST_MODS_DISABLED") != "1" {
		if dir := p.activeModGeneration(); ValidateModGeneration(dir, base) == nil {
			return dir
		}
	}
	return base
}

func (p *Paths) activeModGeneration() string {
	data, err := os.ReadFile(p.ModStateFile())
	if err != nil {
		return ""
	}
	var state modStateSource
	if json.Unmarshal(data, &state) != nil {
		return ""
	}
	id := state.ActiveGeneration
	if id == "" || id == "." || filepath.Base(id) != id {
		return ""
	}
	return filepath.Join(p.ModGenerationsDir(), id)
}

// ValidateModGeneration checks that a generated shell was composed from the
// current base source. A stale generation is never launched after an Ambxst
// update.
func ValidateModGeneration(generation, base string) error {
	if generation == "" || base == "" {
		return fmt.Errorf("generation or base source is unavailable")
	}
	if !fileExists(filepath.Join(generation, "shell.qml")) {
		return fmt.Errorf("generation has no shell.qml")
	}
	data, err := os.ReadFile(filepath.Join(generation, ".ambxst-generation.json"))
	if err != nil {
		return fmt.Errorf("read generation metadata: %w", err)
	}
	var metadata modGenerationMetadata
	if err := json.Unmarshal(data, &metadata); err != nil {
		return fmt.Errorf("parse generation metadata: %w", err)
	}
	if metadata.ID == "" || metadata.ID != filepath.Base(generation) {
		return fmt.Errorf("generation metadata does not match its directory")
	}
	baseVersion := readSourceValue(filepath.Join(base, "version"))
	if metadata.BaseVersion == "" || baseVersion == "" {
		return fmt.Errorf("generation or base version is unavailable")
	}
	if metadata.BaseVersion != baseVersion {
		return fmt.Errorf("generation uses Ambxst %s; base is %s", metadata.BaseVersion, baseVersion)
	}
	if metadata.BaseRevision != "" {
		cmd := exec.Command("git", "-C", base, "rev-parse", "HEAD")
		output, err := cmd.Output()
		if err != nil {
			return fmt.Errorf("read base revision: %w", err)
		}
		if revision := strings.TrimSpace(string(output)); revision != metadata.BaseRevision {
			return fmt.Errorf("generation was built from a different Ambxst revision")
		}
	} else if filepath.Clean(metadata.BasePath) != filepath.Clean(base) {
		return fmt.Errorf("generation was built from a different Ambxst source")
	}
	return nil
}

// FindBaseShellSource returns the unmodified Ambxst source tree. Mod
// composition uses this function so an active generation is never layered on
// top of another generation.
func FindBaseShellSource() string {
	if v := os.Getenv("AMBXST_SHELL"); v != "" {
		if _, err := os.Stat(filepath.Join(v, "shell.qml")); err == nil {
			return v
		}
	}
	if exe, err := os.Executable(); err == nil {
		parent := filepath.Dir(exe)
		if fileExists(filepath.Join(parent, "shell.qml")) {
			return parent
		}
		if filepath.Base(parent) == "backend" {
			if fileExists(filepath.Join(filepath.Dir(parent), "shell.qml")) {
				return filepath.Dir(parent)
			}
		}
		if filepath.Base(parent) == "bin" && filepath.Base(filepath.Dir(parent)) == "backend" {
			if fileExists(filepath.Join(filepath.Dir(filepath.Dir(parent)), "shell.qml")) {
				return filepath.Dir(filepath.Dir(parent))
			}
		}
	}
	p := New()
	if f := p.ShellPathFile(); f != "" {
		if data, err := os.ReadFile(f); err == nil {
			dir := strings.TrimSpace(string(data))
			if fileExists(filepath.Join(dir, "shell.qml")) {
				return dir
			}
		}
	}
	if cwd, err := os.Getwd(); err == nil && fileExists(filepath.Join(cwd, "shell.qml")) {
		return cwd
	}
	if home := os.Getenv("HOME"); home != "" {
		candidate := filepath.Join(home, ".local/src/ambxst")
		if fileExists(filepath.Join(candidate, "shell.qml")) {
			return candidate
		}
	}
	return ""
}

func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

func readSourceValue(path string) string {
	data, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(data))
}
