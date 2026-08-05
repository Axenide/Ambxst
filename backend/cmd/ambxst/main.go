package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"net"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"

	"ambxst/backend/pkg/daemon"
	"ambxst/backend/pkg/ipc"
	"ambxst/backend/pkg/paths"
)

var version = "dev"

func main() {
	args := os.Args[1:]

	if len(args) >= 1 {
		switch args[0] {
		case "version", "-v", "--version":
			fmt.Printf("Ambxst %s\n", readVersion())
			return
		case "help", "--help", "-h":
			showHelp()
			return
		case "daemon":
			if daemon.AlreadyRunning() {
				fmt.Println("[ambxst-daemon] already running")
				return
			}
			d, err := daemon.New()
			if err != nil {
				fmt.Fprintf(os.Stderr, "Error: %v\n", err)
				os.Exit(1)
			}
			if err := d.Serve(); err != nil {
				fmt.Fprintf(os.Stderr, "Error: %v\n", err)
				os.Exit(1)
			}
			return
		case "update":
			runUpdate()
			return
		case "refresh":
			runRefresh()
			return
		case "install":
			runInstall(args[1:])
			return
		case "remove":
			runRemove(args[1:])
			return
		case "goodbye":
			runGoodbye()
			return
		}
	}

	ensureConfigFiles()
	if len(args) == 0 {
		launch()
		return
	}

	switch args[0] {
	case "run":
		cmd := ""
		if len(args) > 1 {
			cmd = args[1]
		}
		if cmd == "" {
			fmt.Println("Error: No command specified for run")
			os.Exit(1)
		}
		mustCall("ui.run", map[string]any{"command": cmd})
	case "lock":
		mustCall("ui.run", map[string]any{"command": "lockscreen"})
	case "reload":
		restartAmbxst()
	case "quit":
		quitAmbxst()
	case "screen":
		runScreen(args[1:])
	case "suspend":
		doSuspend()
	case "brightness":
		runBrightness(args[1:])
	case "colorpicker":
		os.Exit(runColorPicker())
	case "lockwall":
		os.Exit(runLockWall(args[1:]))
	case "thumbs":
		os.Exit(runThumbs(args[1:], 140, true))
	case "dthumbs":
		os.Exit(runThumbs(args[1:], 64, false))
	case "ipc":
		os.Exit(runIpc(args[1:]))
	case "chatlist":
		os.Exit(runChatList(args[1:]))
	case "writeshader":
		os.Exit(runWriteShader(args[1:]))
	default:
		fmt.Printf("Error: Unknown command '%s'\n", args[0])
		showHelp()
		os.Exit(1)
	}
}

func readVersion() string {
	// Try the version file next to the binary.
	if exe, err := os.Executable(); err == nil {
		repo := filepath.Dir(filepath.Dir(exe))
		if data, err := os.ReadFile(filepath.Join(repo, "version")); err == nil {
			return strings.TrimSpace(string(data))
		}
	}
	return version
}

func ensureDefaultSocket() {
	// Ensure runtime dir exists for the socket.
	runtime := os.Getenv("XDG_RUNTIME_DIR")
	if runtime == "" {
		os.Setenv("XDG_RUNTIME_DIR", "/tmp")
	}
}

func ensureConfigFiles() {
	if err := daemon.EnsureConfigFiles(paths.New(), defaultPresetDir()); err != nil {
		fmt.Fprintf(os.Stderr, "Error: failed to ensure config: %v\n", err)
	}
}

func socketPath() string {
	p := paths.New()
	return p.SocketPath()
}

func newClient() *ipc.Client {
	return ipc.NewClient(socketPath())
}

// runIpc dispatches a JSON-RPC call to the daemon. Two subcommands are
// supported:
//
//	ambxst ipc call <service.method> <json>
//
// The <json> argument is the raw params payload; pass an empty string to
// invoke a parameterless method.
func runIpc(args []string) int {
	if len(args) < 2 || args[0] != "call" {
		fmt.Fprintln(os.Stderr, "Usage: ambxst ipc call <service.method> <json>")
		return 2
	}
	method := args[1]
	var params any
	if len(args) >= 3 && args[2] != "" {
		if err := json.Unmarshal([]byte(args[2]), &params); err != nil {
			fmt.Fprintf(os.Stderr, "Error: invalid JSON payload: %v\n", err)
			return 2
		}
	}
	if !isSocketUp() {
		fmt.Fprintln(os.Stderr, "Error: Ambxst daemon is not running")
		return 1
	}
	res, err := newClient().Call(method, params)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		return 1
	}
	if len(res) > 0 {
		fmt.Println(string(res))
	}
	return 0
}

func mustCall(method string, params any) json.RawMessage {
	client := newClient()
	if !isSocketUp() {
		fmt.Fprintln(os.Stderr, "Error: Ambxst daemon is not running")
		os.Exit(1)
	}
	res, err := client.Call(method, params)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
	return res
}

// pidPath mirrors daemon.pidFile so the launcher can validate the
// running PID. Kept in sync with backend/pkg/daemon/daemon.go.
func pidPath() string {
	if runtime := os.Getenv("XDG_RUNTIME_DIR"); runtime != "" {
		return filepath.Join(runtime, "ambxst-daemon.pid")
	}
	return "/tmp/ambxst-daemon.pid"
}

// isAlive returns true only when the daemon is actually reachable:
// the socket file exists, a process is listening on it, and the PID
// file (if any) points to a live process. Stale state from previous
// daemon crashes is cleaned up so a subsequent launch can spawn a
// fresh daemon.
func isAlive() bool {
	sock := socketPath()

	// 1) Socket file present?
	info, err := os.Stat(sock)
	if err != nil || info.Mode()&os.ModeSocket == 0 {
		return false
	}

	// 2) Anything listening? Probe with a short connect.
	c, err := net.DialTimeout("unix", sock, 500*time.Millisecond)
	if err != nil {
		os.Remove(sock)
		os.Remove(pidPath())
		return false
	}
	c.Close()

	// 3) PID file (if present) must point to a live process.
	if data, err := os.ReadFile(pidPath()); err == nil {
		pidStr := strings.TrimSpace(string(data))
		if pid, err := strconv.Atoi(pidStr); err == nil {
			if proc, err := os.FindProcess(pid); err == nil {
				if err := proc.Signal(syscall.Signal(0)); err != nil {
					os.Remove(sock)
					os.Remove(pidPath())
					return false
				}
			}
		}
	}
	return true
}

func launch() {
	// daemon_priority.sh equivalent: kill competing daemons, start easyeffects service
	runDetached("pkill -f 'dunst|mako|swaync'")
	runDetached("pkill -f 'easyeffects.*gapplication-service' ; nohup easyeffects --gapplication-service >/dev/null 2>&1 &")

	// Spawn the daemon if not running, wait for socket.
	if !isAlive() {
		fmt.Println("[ambxst] starting backend daemon...")
		if err := daemon.SpawnDetached(paths.New()); err != nil {
			fmt.Fprintf(os.Stderr, "Error: failed to start daemon: %v\n", err)
		}
		waitForSocket(5 * time.Second)
	}

	p := paths.New()
	presetDir := defaultPresetDir()
	if err := daemon.EnsureConfigFiles(p, presetDir); err != nil {
		fmt.Fprintf(os.Stderr, "Error: failed to ensure config: %v\n", err)
	}

	// QS_ICON_THEME
	iconTheme, err := exec.Command("gsettings", "get", "org.gnome.desktop.interface", "icon-theme").Output()
	if err == nil {
		os.Setenv("QS_ICON_THEME", strings.Trim(strings.TrimSpace(string(iconTheme)), "'"))
	}

	os.Setenv("QT_QPA_PLATFORMTHEME", "qt6ct")
	os.Unsetenv("HL_INITIAL_WORKSPACE_TOKEN")

	// Write PID for compat with old tooling; qs replaces this shell process.
	shellId := ""
	if exe, err := os.Executable(); err == nil {
		_ = exe
	}

	qsBin := os.Getenv("AMBXST_QS")
	if qsBin == "" {
		qsBin = "qs"
	}
	shellQML := filepath.Join(shellDir(), "shell.qml")
	if nixgl := os.Getenv("AMBXST_NIXGL"); nixgl != "" {
		execCommand(nixgl, qsBin, "-p", shellQML)
	} else {
		execCommand(qsBin, "-p", shellQML)
	}
	_ = shellId
}

func shellDir() string {
	// Precedence: env override > auto-detect from binary location > path file.
	if dir := os.Getenv("AMBXST_SHELL"); dir != "" {
		return dir
	}
	if exe, err := os.Executable(); err == nil {
		// In dev, the binary lives at <repo>/ambxst (repo root) or inside
		// <repo>/backend or <repo>/backend/bin (legacy layouts).
		parent := filepath.Dir(exe)
		// <repo>/<binary> => repo = parent.
		if fileExists(filepath.Join(parent, "shell.qml")) {
			return parent
		}
		// <repo>/backend/<binary> => repo = parent's parent.
		if filepath.Base(parent) == "backend" {
			return filepath.Dir(parent)
		}
		// <repo>/backend/bin/<binary> => repo = grandparent.
		if filepath.Base(parent) == "bin" && filepath.Base(filepath.Dir(parent)) == "backend" {
			return filepath.Dir(filepath.Dir(parent))
		}
	}
	// Installed to /usr/local/bin: the installer writes the repo location so
	// the binary can still find shell sources and scripts.
	if p := paths.New().ShellPathFile(); p != "" {
		if data, err := os.ReadFile(p); err == nil {
			dir := strings.TrimSpace(string(data))
			if fileExists(filepath.Join(dir, "shell.qml")) {
				return dir
			}
		}
	}
	if cwd, err := os.Getwd(); err == nil && fileExists(filepath.Join(cwd, "shell.qml")) {
		return cwd
	}
	return filepath.Join(os.Getenv("HOME"), ".local/src/ambxst")
}

func execCommand(name string, args ...string) {
	cmd := exec.Command(name, args...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	// jemalloc (used by Qt/Quickshell) retains freed memory in its arenas
	// without returning it to the OS, inflating RSS by ~100-150MB at idle.
	// A short decay pushes the memory back without affecting performance.
	if os.Getenv("MALLOC_CONF") == "" {
		cmd.Env = append(os.Environ(), "MALLOC_CONF=dirty_decay_ms:1000,muzzy_decay_ms:1000")
	}
	if err := cmd.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}

func defaultPresetDir() string {
	return filepath.Join(shellDir(), "assets", "presets", "Ambxst Default")
}

func waitForSocket(timeout time.Duration) {
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		if isAlive() {
			return
		}
		time.Sleep(50 * time.Millisecond)
	}
}

func runDetached(cmd string) {
	exec.Command("sh", "-c", cmd).Start()
}

func restartAmbxst() {
	quitAmbxst()
	time.Sleep(300 * time.Millisecond)
	// Re-exec ourselves in background to relaunch the shell.
	exe, _ := os.Executable()
	cmd := exec.Command(exe)
	cmd.SysProcAttr = detachAttr()
	if err := cmd.Start(); err == nil {
		cmd.Process.Release()
	}
}

func quitAmbxst() {
	// Kill axctl daemons (survive parent death).
	runDetached("pkill -f 'axctl.*daemon'")
	runDetached("pkill -f 'axctl subscribe'")

	// Kill the qs shell matching shell.qml.
	pid := findShellPID()
	if pid != "" {
		exec.Command("sh", "-c", "kill "+pid).Run()
	}
	<-time.After(200 * time.Millisecond)
	_ = pid
	fmt.Println("Ambxst stopped.")
}

func findShellPID() string {
	cmd := exec.Command("sh", "-c", "pgrep -f 'qs.*shell.qml' | head -1")
	out, err := cmd.Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(out))
}

func restartAmbxstWait() {
	// placeholder for reload that relaunches through CLI
}

func showHelp() {
	fmt.Print(`Ambxst CLI - Desktop Environment Control

Usage: ambxst [COMMAND]

Commands:
    (none)                            Launch Ambxst
    daemon                           Run the ambxst backend daemon
    update                           Update Ambxst
    refresh                          Refresh local/dev profile (for developers)
    lock                             Activate lockscreen
    run <command>                    Send a UI command to the shell
    reload                           Restart Ambxst
    quit                             Stop Ambxst
    screen [on|off]                  Control DPMS
    suspend                          Suspend the system
    brightness <percent> [monitor]   Set brightness (0-100)
    brightness +/-<delta> [monitor]  Adjust brightness relatively
    brightness -s [monitor]          Save current brightness
    brightness -r [monitor]          Restore saved brightness
    brightness -l                    List monitors and their brightness
    install <target>                 Install compositor config (hyprland)
    remove <target>                  Remove compositor config (hyprland)
    colorpicker                      Pick a screen color (slurp+grim+magick)
    lockwall <wallpaper> <data>      Extract lockscreen frame from video/GIF
    thumbs <config> <cache> [fall]   Generate wallpaper thumbnails (140x140)
    dthumbs <dir> <cache>            Generate desktop thumbnails (64x64)
    help                             Show this help message
    version, -v, --version           Show Ambxst version
    goodbye                          Uninstall Ambxst
`)
}

func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}