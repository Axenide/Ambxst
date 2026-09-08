package main

import (
	"encoding/json"
	"fmt"
	"net"
	"os"
	"os/exec"
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
		case "mods":
			runMods(args[1:])
			return
		}
	}

	ensureConfigFiles()

	if len(args) == 0 {
		runShell()
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
	case "wallpaper":
		os.Exit(runWallpaper(args[1:]))
	case "preset":
		os.Exit(runPreset(args[1:]))
	default:
		fmt.Printf("Error: Unknown command '%s'\n", args[0])
		showHelp()
		os.Exit(1)
	}
}

func readVersion() string {
	if exe, err := os.Executable(); err == nil {
		repo := filepath.Dir(filepath.Dir(exe))
		if data, err := os.ReadFile(filepath.Join(repo, "version")); err == nil {
			return strings.TrimSpace(string(data))
		}
	}
	return version
}

func ensureConfigFiles() {
	if err := daemon.EnsureConfigFiles(paths.New(), defaultPresetDir()); err != nil {
		fmt.Fprintf(os.Stderr, "Error: failed to ensure config: %v\n", err)
	}
}

func socketPath() string {
	return paths.New().SocketPath()
}

func newClient() *ipc.Client {
	return ipc.NewClient(socketPath())
}

// runIpc dispatches a JSON-RPC call to the running ambxst process.
//
//	ambxst ipc call <service.method> <json>
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
	if !isAlive() {
		fmt.Fprintln(os.Stderr, "Error: Ambxst is not running")
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
	if !isAlive() {
		fmt.Fprintln(os.Stderr, "Error: Ambxst is not running")
		os.Exit(1)
	}
	res, err := client.Call(method, params)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
	return res
}

// isAlive returns true only when the daemon is actually reachable: the
// socket file exists, a process is listening on it, and the PID file
// points to a live process. Stale state from previous crashes is cleaned
// up so a subsequent launch can spawn a fresh instance.
func isAlive() bool {
	sock := socketPath()

	info, err := os.Stat(sock)
	if err != nil || info.Mode()&os.ModeSocket == 0 {
		return false
	}

	c, err := net.DialTimeout("unix", sock, 500*time.Millisecond)
	if err != nil {
		os.Remove(sock)
		os.Remove(pidPath())
		return false
	}
	c.Close()

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

func pidPath() string {
	if runtime := os.Getenv("XDG_RUNTIME_DIR"); runtime != "" {
		return filepath.Join(runtime, "ambxst.pid")
	}
	return "/tmp/ambxst.pid"
}

// runShell becomes the unified ambxst process: starts the IPC server,
// supervises the compositor process manager, spawns Quickshell, and blocks
// until shutdown. If another instance is alive we ask it to shut down via
// IPC and fall back to SIGTERMing the pidfile process so the user can
// transparently upgrade from older builds that lack system.shutdown.
func runShell() {
	if isAlive() {
		if _, err := newClient().Call("system.shutdown", nil); err == nil {
			waitForDeath(5 * time.Second)
		} else {
			killPIDFile()
			waitForDeath(2 * time.Second)
		}
		// Sweep children the previous daemon may have leaked (e.g. an
		// older build that didn't track wl-paste/axctl). Run before
		// initialising the new daemon so we don't double-start.
		cleanupOrphans()
	}

	runDetached("pkill -f 'dunst|mako|swaync'")
	runDetached("pkill -f 'easyeffects.*gapplication-service' ; nohup easyeffects --gapplication-service >/dev/null 2>&1 &")

	if iconTheme, err := exec.Command("gsettings", "get", "org.gnome.desktop.interface", "icon-theme").Output(); err == nil {
		os.Setenv("QS_ICON_THEME", strings.Trim(strings.TrimSpace(string(iconTheme)), "'"))
	}
	os.Setenv("QT_QPA_PLATFORMTHEME", "qt6ct")
	os.Unsetenv("HL_INITIAL_WORKSPACE_TOKEN")

	d, err := daemon.New()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: init daemon: %v\n", err)
		os.Exit(1)
	}

	qsBin := os.Getenv("AMBXST_QS")
	if qsBin == "" {
		qsBin = "qs"
	}
	shellQML := filepath.Join(shellDir(), "shell.qml")

	if err := d.Run(qsBin, shellQML); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}

// killPIDFile sends SIGTERM to the process recorded in the pidfile. Used
// to migrate from older ambxst builds that don't expose system.shutdown.
func killPIDFile() {
	data, err := os.ReadFile(pidPath())
	if err != nil {
		return
	}
	pid, err := strconv.Atoi(strings.TrimSpace(string(data)))
	if err != nil || pid <= 0 {
		return
	}
	if proc, err := os.FindProcess(pid); err == nil {
		_ = proc.Signal(syscall.SIGTERM)
	}
}

func shellDir() string {
	if dir := paths.FindShellSource(); dir != "" {
		return dir
	}
	return filepath.Join(os.Getenv("HOME"), ".local/src/ambxst")
}

func defaultPresetDir() string {
	return filepath.Join(shellDir(), "assets", "presets", "Ambxst Default")
}

func runDetached(cmd string) {
	exec.Command("sh", "-c", cmd).Start()
}

func execCommand(name string, args ...string) {
	cmd := exec.Command(name, args...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}

// restartAmbxst triggers a full restart by asking the running instance to
// shut down via IPC, waiting for it to actually die, and re-execing
// ourselves in the background.
func restartAmbxst() {
	if isAlive() {
		_, _ = newClient().Call("system.shutdown", nil)
		waitForDeath(5 * time.Second)
	}
	exe, _ := os.Executable()
	cmd := exec.Command(exe)
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	if err := cmd.Start(); err == nil {
		cmd.Process.Release()
	}
}

func waitForDeath(timeout time.Duration) {
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		if !isAlive() {
			return
		}
		time.Sleep(100 * time.Millisecond)
	}
}

// quitAmbxst asks the running instance to shut down. Falls back to a
// pkill sweep only if the daemon is unresponsive (no socket, no pidfile).
func quitAmbxst() {
	if isAlive() {
		if _, err := newClient().Call("system.shutdown", nil); err == nil {
			waitForDeath(5 * time.Second)
			fmt.Println("Ambxst stopped.")
			return
		}
	}
	cleanupOrphans()
	fmt.Println("Ambxst stopped.")
}

func cleanupOrphans() {
	exec.Command("pkill", "-f", "tail -f /tmp/ambxst_ipc.pipe").Run()
	exec.Command("pkill", "-f", "axctl.*daemon").Run()
	exec.Command("pkill", "-f", "axctl subscribe").Run()
	exec.Command("pkill", "-f", "qs.*shell.qml").Run()
	exec.Command("pkill", "-f", "wl-paste --watch").Run()
	os.Remove("/tmp/ambxst_ipc.pipe")
}

func showHelp() {
	fmt.Print(`Ambxst CLI - Desktop Environment Control

Usage: ambxst [COMMAND]

Commands:
    (none)                            Launch Ambxst
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
    install <target>                 Install compositor config (hyprland, niri, mango)
    remove <target>                  Remove compositor config (hyprland, niri, mango)
    colorpicker                      Pick a screen color (interactive loupe)
    lockwall <wallpaper> <data>      Extract lockscreen frame from video/GIF
    thumbs <config> <cache> [fall]   Generate wallpaper thumbnails (140x140)
    dthumbs <dir> <cache>            Generate desktop thumbnails (64x64)
    ipc call <method> <json>         Send a raw JSON-RPC call to the daemon
    wallpaper <file>                Set wallpaper (with optional flags)
        -scheme <name>              Use a specific matugen color scheme
        -oled                       Enable OLED mode for this wallpaper only
        -tint                       Enable tint for this wallpaper only
        -monitor <id|name>          Apply to a specific monitor
    preset [-l|"Name"]              List or apply a preset (name supports quotes)
    mods [command]                   Manage Ambxst modifications
    help                             Show this help message
    version, -v, --version           Show Ambxst version
    goodbye                          Uninstall Ambxst
`)
}

func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}
