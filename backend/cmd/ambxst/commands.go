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
	default:
		fmt.Printf("Error: Unknown target '%s'. Supported: hyprland\n", target)
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
	default:
		fmt.Printf("Error: Unknown target '%s'. Supported: hyprland\n", target)
		os.Exit(1)
	}
}

const hyprSource = "source = ~/.local/share/ambxst/hyprland.conf"
const hyprLuaSource = `loadfile(os.Getenv("HOME"))`

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

func installHyprland() {
	home, _ := os.UserHomeDir()
	hyprDir := filepath.Join(home, ".config/hypr")
	os.MkdirAll(hyprDir, 0o755)
	luaPath := filepath.Join(hyprDir, "hyprland.lua")
	confPath := filepath.Join(hyprDir, "hyprland.conf")

	luaSrc := `loadfile(os.getenv("HOME") .. "/.local/share/ambxst/hyprland.lua")()`
	if fileExists(luaPath) || !fileExists(confPath) {
		appendBlock(luaPath, luaSrc, hyprLuaBlock)
	} else {
		appendBlock(confPath, hyprSource, hyprConfBlock)
	}
}

func removeHyprland() {
	home, _ := os.UserHomeDir()
	hyprDir := filepath.Join(home, ".config/hypr")
	luaPath := filepath.Join(hyprDir, "hyprland.lua")
	confPath := filepath.Join(hyprDir, "hyprland.conf")
	luaSrc := "loadfile(os.getenv(\"HOME\") .. \"/.local/share/ambxst/hyprland.lua\")()"
	removeBlock(luaPath, luaSrc)
	removeBlock(confPath, hyprSource)
}

func appendBlock(path, source, block string) {
	if fileExists(path) {
		data, err := os.ReadFile(path)
		if err == nil && strings.Contains(string(data), source) {
			fmt.Printf("Ambxst Hyprland block already present in %s\n", path)
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
	fmt.Printf("Added Ambxst Hyprland block to %s\n", path)
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
			trimmed == "# OVERRIDES" ||
			trimmed == "-- OVERRIDES" ||
			trimmed == "# Down here you can write or source anything that you want to override from Ambxst's settings." ||
			trimmed == "-- Down here you can write or source anything that you want to override from Ambxst's settings."
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
	fmt.Printf("Removed Ambxst Hyprland block from %s\n", path)
}

func runGoodbye() {
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