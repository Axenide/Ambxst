package paths

import (
	"os"
	"path/filepath"
	"strings"
)

// FindShellSource returns the absolute path to the Ambxst shell source
// tree, used to locate bundled assets (presets, wallpapers, etc.) the
// installed/launched binary otherwise doesn't ship alongside itself.
//
// Lookup order — first hit wins:
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
