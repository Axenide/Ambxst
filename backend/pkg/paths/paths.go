package paths

import (
	"os"
	"path/filepath"
	"strings"
)

// Paths resolves XDG dirs for the shell.
type Paths struct {
	ConfigDir string
	DataDir   string
	StateDir  string
	CacheDir  string
}

func xdg(base, env, def string) string {
	if v := os.Getenv(env); v != "" {
		return v
	}
	home, err := os.UserHomeDir()
	if err != nil {
		home = "/tmp"
	}
	return filepath.Join(home, def)
}

// New resolves the standard dirs for ambxst.
func New() *Paths {
	return &Paths{
		ConfigDir: filepath.Join(xdg("", "XDG_CONFIG_HOME", ".config"), "ambxst"),
		DataDir:   filepath.Join(xdg("", "XDG_DATA_HOME", ".local/share"), "ambxst"),
		StateDir:  filepath.Join(xdg("", "XDG_STATE_HOME", ".local/state"), "ambxst"),
		CacheDir:  filepath.Join(xdg("", "XDG_CACHE_HOME", ".cache"), "ambxst"),
	}
}

func (p *Paths) Config(domain string) string {
	return filepath.Join(p.ConfigDir, "config", domain+".json")
}

func (p *Paths) SocketPath() string {
	return filepath.Join(os.Getenv("XDG_RUNTIME_DIR"), "ambxst.sock")
}

func (p *Paths) AxctlToml() string {
	return filepath.Join(p.DataDir, "axctl.toml")
}

func (p *Paths) StatesFile() string {
	return filepath.Join(p.StateDir, "states.json")
}

func (p *Paths) UsageFile() string {
	return filepath.Join(p.CacheDir, "usage.json")
}

func (p *Paths) NotificationsFile() string {
	return filepath.Join(p.CacheDir, "notifications.json")
}

func (p *Paths) UpdateCheckFile() string {
	return filepath.Join(p.CacheDir, "update_check.json")
}

func (p *Paths) ColorsFile() string {
	return filepath.Join(p.CacheDir, "colors.json")
}

func (p *Paths) ClipboardDB() string {
	return filepath.Join(p.DataDir, "clipboard.db")
}

func (p *Paths) ClipboardDataDir() string {
	return filepath.Join(p.DataDir, "clipboard-data")
}

func (p *Paths) KeysDB() string {
	return filepath.Join(p.DataDir, "keys.db")
}

func (p *Paths) PinnedAppsFile() string {
	return filepath.Join(p.DataDir, "pinnedapps.json")
}

func (p *Paths) ActivePresetFile() string {
	return filepath.Join(p.ConfigDir, "active_preset")
}

func (p *Paths) KeybindsFile() string {
	return filepath.Join(p.ConfigDir, "binds.json")
}

// ShellPathFile stores the repo location for the installed binary
// (/usr/local/bin) to find shell sources and scripts.
func (p *Paths) ShellPathFile() string {
	return filepath.Join(p.DataDir, "shell_repo")
}

func (p *Paths) ModsDir() string {
	return filepath.Join(p.DataDir, "mods")
}

func (p *Paths) ModPackagesDir() string {
	return filepath.Join(p.ModsDir(), "packages")
}

func (p *Paths) ModGenerationsDir() string {
	return filepath.Join(p.ModsDir(), "generations")
}

func (p *Paths) ModPendingActivationFile() string {
	return filepath.Join(p.ModsDir(), "pending-activation.json")
}

func (p *Paths) ModStateFile() string {
	return filepath.Join(p.ConfigDir, "mods.json")
}

func (p *Paths) ModSettingsDir() string {
	return filepath.Join(p.ConfigDir, "mods")
}

// ShellSourceDir returns the absolute path to the Ambxst shell source
// tree (see FindShellSource for the lookup rules). Callers that already
// hold a *Paths simply ignore it; the receiver is unused.
func (p *Paths) ShellSourceDir() string {
	return FindShellSource()
}

// userDir reads a directory entry from ~/.config/user-dirs.dirs,
// falling back to ~/ <def>.
func userDir(key, def string) string {
	home, err := os.UserHomeDir()
	if err != nil {
		home = "/tmp"
	}
	fallback := filepath.Join(home, def)

	data, err := os.ReadFile(filepath.Join(home, ".config", "user-dirs.dirs"))
	if err != nil {
		return fallback
	}
	for _, line := range strings.Split(string(data), "\n") {
		line = strings.TrimSpace(line)
		if !strings.HasPrefix(line, "XDG_"+key+"_DIR") {
			continue
		}
		eq := strings.Index(line, "=")
		if eq < 0 {
			continue
		}
		val := strings.TrimSpace(line[eq+1:])
		val = strings.Trim(val, `"'`)
		switch {
		case strings.HasPrefix(val, "$HOME"):
			return filepath.Join(home, strings.TrimPrefix(strings.TrimPrefix(val, "$HOME"), "/"))
		case strings.HasPrefix(val, "/"):
			return val
		}
	}
	return fallback
}

// PicturesDir mirrors xdg-user-dir PICTURES.
func (p *Paths) PicturesDir() string {
	return userDir("PICTURES", "Pictures")
}

// VideosDir mirrors xdg-user-dir VIDEOS.
func (p *Paths) VideosDir() string {
	return userDir("VIDEOS", "Videos")
}
