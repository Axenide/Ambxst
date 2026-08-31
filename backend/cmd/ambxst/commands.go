package main

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
)

func isSocketUp() bool {
	_, err := os.Stat(socketPath())
	return err == nil || isPipe(socketPath()) || isUnixSocket(socketPath())
}

func isPipe(path string) bool {
	info, err := os.Stat(path)
	if err != nil {
		return false
	}
	return info.Mode()&os.ModeNamedPipe != 0
}

func isUnixSocket(path string) bool {
	info, err := os.Stat(path)
	if err != nil {
		return false
	}
	return info.Mode()&os.ModeSocket != 0
}

// detachAttr returns process attributes for full detach.
func detachAttr() *syscall.SysProcAttr {
	return &syscall.SysProcAttr{Setsid: true}
}

func runUpdate() {
	fmt.Println("Updating Ambxst...")
	cmd := exec.Command("sh", "-c", "curl -fsSL get.axeni.de/ambxst | sh")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: update failed: %v\n", err)
	}
	restartAmbxst()
}

func runRefresh() {
	fmt.Println("Refreshing Ambxst profile...")
	execCommand("nix", "profile", "upgrade", "Ambxst", "--refresh", "--impure")
}

func runInstall(targets []string) {
	target := ""
	if len(targets) > 0 {
		target = targets[0]
	}
	switch target {
	case "hyprland":
		installHyprland()
	case "niri":
		installSimpleTarget(niriConfig)
	case "mango":
		installSimpleTarget(mangoConfig)
	default:
		fmt.Printf("Error: Unknown target '%s'. Supported: hyprland, niri, mango\n", target)
		os.Exit(1)
	}
}

func runRemove(targets []string) {
	target := ""
	if len(targets) > 0 {
		target = targets[0]
	}
	switch target {
	case "hyprland":
		removeHyprland()
	case "niri":
		removeSimpleTarget(niriConfig)
	case "mango":
		removeSimpleTarget(mangoConfig)
	default:
		fmt.Printf("Error: Unknown target '%s'. Supported: hyprland, niri, mango\n", target)
		os.Exit(1)
	}
}

// Block detection markers — the first line of each block is the stable
// identity used for both append detection and removal. Using the inner
// content (e.g. the loadfile(...)() line, or the include/source path) was
// fragile: if the user edited the inner path, the next run of
// `ambxst install <target>` would not match the marker and would re-append
// the entire block, producing duplicate imports. The comment line at the
// top of the block is immutable and unique to Ambxst, which is why
// removeBlock already lists "# Ambxst", "-- Ambxst", and "// Ambxst" in
// its isRemove set — we now use the same convention for detection.
const (
	hyprLuaMarker  = "-- Ambxst"
	hyprConfMarker = "# Ambxst"
)

const hyprConfBlock = `# Ambxst
source = ~/.local/share/ambxst/hyprland.conf

# OVERRIDES
# Down here you can write or source anything that you want to override from Ambxst's settings.
`

const hyprLuaBlock = `-- Ambxst
loadfile(os.getenv("HOME") .. "/.local/share/ambxst/hyprland.lua")()

-- OVERRIDES
-- Down here you can write or source anything that you want to override from Ambxst's settings.
`

// simpleTarget describes a compositor whose Ambxst integration is a single
// include/source line in one config file. Hyprland is the exception with
// both .conf and .lua sides.
type simpleTarget struct {
	name    string
	relDir  string // under ~/.config
	relFile string // config file path under relDir
	marker  string // exact source line to detect presence / remove
	header  string // language-specific comment marker for the block
}

var niriConfig = simpleTarget{
	name:    "Niri",
	relDir:  "niri",
	relFile: "config.kdl",
	marker:  `include "~/.local/share/ambxst/niri.kdl"`,
	header:  "//",
}

var mangoConfig = simpleTarget{
	name:    "Mango",
	relDir:  "mango",
	relFile: "config.conf",
	marker:  `source = ~/.local/share/ambxst/mango.conf`,
	header:  "#",
}

func installHyprland() {
	home, _ := os.UserHomeDir()
	hyprDir := filepath.Join(home, ".config/hypr")
	os.MkdirAll(hyprDir, 0o755)
	luaPath := filepath.Join(hyprDir, "hyprland.lua")
	confPath := filepath.Join(hyprDir, "hyprland.conf")

	if isHomeManagerManaged(luaPath) || isHomeManagerManaged(confPath) {
		printHomeManagerHyprlandGuidance(luaPath, confPath)
		return
	}

	if fileExists(luaPath) || !fileExists(confPath) {
		appendBlock(luaPath, hyprLuaMarker, hyprLuaBlock)
	} else {
		appendBlock(confPath, hyprConfMarker, hyprConfBlock)
	}
}

func removeHyprland() {
	home, _ := os.UserHomeDir()
	hyprDir := filepath.Join(home, ".config/hypr")
	luaPath := filepath.Join(hyprDir, "hyprland.lua")
	confPath := filepath.Join(hyprDir, "hyprland.conf")
	if isHomeManagerManaged(luaPath) || isHomeManagerManaged(confPath) {
		return
	}
	removeBlock(luaPath, hyprLuaMarker)
	removeBlock(confPath, hyprConfMarker)
}

// isHomeManagerManaged returns true when path is a symlink whose target
// lives inside the Nix store, which is the home-manager pattern (HM places
// every managed file under <store-path>/home-manager-files/...). Writing
// through such a symlink fails with EACCES because the target is read-only.
//
// We use Lstat to detect the symlink itself, then Readlink to grab the
// raw target string. Readlink is preferred over EvalSymlinks here: it does
// not require the target to exist (HM never leaves dangling symlinks, but
// a partially-activated state or a manual rm -rf can), and it returns the
// link text exactly as written by HM, which is always an absolute
// /nix/store/... path.
func isHomeManagerManaged(path string) bool {
	info, err := os.Lstat(path)
	if err != nil {
		return false
	}
	if info.Mode()&os.ModeSymlink == 0 {
		return false
	}
	target, err := os.Readlink(path)
	if err != nil {
		return false
	}
	return strings.HasPrefix(target, "/nix/store/")
}

func printHomeManagerHyprlandGuidance(luaPath, confPath string) {
	managed := luaPath
	if isHomeManagerManaged(confPath) {
		managed = confPath
	}
	fmt.Fprintf(os.Stderr,
		"Ambxst: %s is managed by home-manager (symlink into /nix/store).\n"+
			"Ambxst will not modify it directly. Add this to your home.nix instead:\n\n"+
			"  wayland.windowManager.hyprland.enable = false;\n"+
			"  xdg.configFile.\"hypr/hyprland.lua\".text = ''\n"+
			"    loadfile(os.getenv(\"HOME\") .. \"/.local/share/ambxst/hyprland.lua\")()\n\n"+
			"    -- OVERRIDES (hl.* API, Hyprland >=0.56)\n"+
			"    hl.config({ input = { kb_layout = \"latam\" } })\n"+
			"    hl.monitor({ output = \"\", mode = \"preferred\", scale = 1 })\n"+
			"    hl.bind(\"SUPER + Return\", hl.dsp.exec_cmd(\"kitty\"))\n"+
			"  '';\n\n"+
			"Ambxst regenerates ~/.local/share/ambxst/hyprland.lua on every\n"+
			"theme/gaps/binds change — no rebuild required for cosmetic tweaks.\n",
		managed)
}

func installSimpleTarget(t simpleTarget) {
	home, _ := os.UserHomeDir()
	dir := filepath.Join(home, ".config", t.relDir)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		return
	}
	path := filepath.Join(dir, t.relFile)
	block := fmt.Sprintf("%s Ambxst\n%s\n\n%s OVERRIDES\n%s Down here you can write or %s anything that you want to override from Ambxst's settings.\n",
		t.header, t.marker, t.header, t.header, includeKeyword(t.name))
	// Use the comment marker (first line) as the detection key, not the
	// inner include/source path — see hyprLuaMarker/hyprConfMarker above
	// for the rationale.
	appendBlock(path, t.header+" Ambxst", block)
}

func removeSimpleTarget(t simpleTarget) {
	home, _ := os.UserHomeDir()
	path := filepath.Join(home, ".config", t.relDir, t.relFile)
	removeBlock(path, t.header+" Ambxst")
}

func includeKeyword(compositor string) string {
	if compositor == "Mango" {
		return "source"
	}
	return "include"
}

func appendBlock(path, source, block string) {
	if fileExists(path) {
		data, err := os.ReadFile(path)
		if err == nil && strings.Contains(string(data), source) {
			fmt.Printf("Ambxst block already present in %s\n", path)
			return
		}
	}
	f, err := os.OpenFile(path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		return
	}
	defer f.Close()
	info, _ := f.Stat()
	if info.Size() > 0 {
		fmt.Fprintf(f, "\n%s\n", block)
	} else {
		fmt.Fprintf(f, "%s\n", block)
	}
	fmt.Printf("Added Ambxst block to %s\n", path)
}

func removeBlock(path, source string) {
	if !fileExists(path) {
		return
	}
	in, err := os.Open(path)
	if err != nil {
		return
	}
	defer in.Close()

	lines := []string{}
	isRemove := func(line string) bool {
		trimmed := strings.TrimSuffix(line, "\r")
		return trimmed == source ||
			trimmed == "# Ambxst" ||
			trimmed == "-- Ambxst" ||
			trimmed == "// Ambxst" ||
			trimmed == "# OVERRIDES" ||
			trimmed == "-- OVERRIDES" ||
			trimmed == "// OVERRIDES" ||
			trimmed == "# Down here you can write or source anything that you want to override from Ambxst's settings." ||
			trimmed == "-- Down here you can write or source anything that you want to override from Ambxst's settings." ||
			trimmed == "// Down here you can write or include anything that you want to override from Ambxst's settings."
	}

	sc := bufio.NewScanner(in)
	for sc.Scan() {
		lines = append(lines, sc.Text())
	}
	out := []string{}
	for i, line := range lines {
		next := ""
		if i+1 < len(lines) {
			next = lines[i+1]
		}
		prev := ""
		if i > 0 {
			prev = lines[i-1]
		}
		if isRemove(line) {
			continue
		}
		if line == "" && (isRemove(prev) || isRemove(next)) {
			continue
		}
		out = append(out, line)
	}
	os.WriteFile(path, []byte(strings.Join(out, "\n")+"\n"), 0o644)
	fmt.Printf("Removed Ambxst block from %s\n", path)
}

func runGoodbye() {
	if isAlive() {
		quitAmbxst()
	}
	fmt.Println("Uninstalling Ambxst...")
	fmt.Print("Are you sure? (y/N): ")
	reader := bufio.NewReader(os.Stdin)
	reply, _ := reader.ReadString('\n')
	reply = strings.TrimSpace(reply)
	if reply != "y" && reply != "Y" {
		fmt.Println("Uninstall aborted.")
		os.Exit(0)
	}

	if fileExists("/etc/NIXOS") {
		cmd := exec.Command("nix", "profile", "list")
		out, _ := cmd.Output()
		if strings.Contains(string(out), "Ambxst") {
			fmt.Println("Removing from nix profile...")
			exec.Command("nix", "profile", "remove", "Ambxst").Run()
		}
		os.Exit(0)
	}

	fmt.Print("Remove configuration files? (y/N): ")
	reply2, _ := reader.ReadByte()
	if reply2 == 'y' || reply2 == 'Y' {
		home, _ := os.UserHomeDir()
		os.RemoveAll(filepath.Join(home, ".config/ambxst"))
		fmt.Println("Configuration files removed.")
	}
	fmt.Println("Ambxst uninstalled. :(")
}

func runShellScript(script string, args ...string) (string, error) {
	out, err := exec.Command("bash", append([]string{script}, args...)...).Output()
	return strings.TrimSpace(string(out)), err
}

func doSuspend() {
	if _, err := exec.LookPath("systemctl"); err == nil {
		exec.Command("systemctl", "suspend").Run()
	} else if _, err := exec.LookPath("loginctl"); err == nil {
		exec.Command("loginctl", "suspend").Run()
	} else {
		exec.Command("dbus-send", "--system", "--print-reply",
			"--dest=org.freedesktop.login1", "/org/freedesktop/login1",
			"org.freedesktop.login1.Manager.Suspend", "boolean:true").Run()
	}
}
