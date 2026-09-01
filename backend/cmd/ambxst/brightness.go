package main

import (
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"syscall"
)

// runBrightness is a thin shim that drives both `axctl brightness` and the
// QML side via Quickshell IPC. The axctl call applies the hardware change
// (idempotent across multiple writers); the IPC hop notifies the running
// shell so the OSD fires and the in-QML brightness state stays consistent
// with what axctl reports.
//
// Replicates the legacy `ambxst brightness ...` CLI surface — existing
// keybinds (`Config.qml` default Hyprland binds) and the idle listener
// (`config/defaults/system.js`) keep working without modification.
func runBrightness(args []string) {
	if !hasBinary("axctl") {
		fmt.Fprintln(os.Stderr, "Error: axctl is required for brightness control")
		os.Exit(1)
	}

	arg2 := ""
	arg3 := ""
	arg4 := ""
	if len(args) > 0 {
		arg2 = args[0]
	}
	if len(args) > 1 {
		arg3 = args[1]
	}
	if len(args) > 2 {
		arg4 = args[2]
	}

	switch {
	case arg2 == "-l" || arg2 == "--list":
		axctlRun("brightness", "list")
		return
	case arg2 == "-r" || arg2 == "--restore":
		// Restore still goes through per-monitor `qs ipc set` so the OSD
		// fires once per affected monitor. axctl's restore only persists
		// back to hardware; without the IPC hop the OSD stays dark.
		qsPid := readQsPid()
		if qsPid == 0 {
			axctlRun("brightness", "restore")
			fmt.Println("Restored brightness for all monitors")
			return
		}
		monitor := arg3
		axctlRun("brightness", "restore")
		// The saved values live in axctl's own TSV; we don't read it here
		// (CLI can't easily parse). ask the QML side to pull them.
		notifyQsBrightness(qsPid, "restore", "", monitor)
		fmt.Println("Restored brightness for all monitors")
		return
	}

	value := ""
	monitor := ""
	saveFlag := false
	relativeDelta := ""

	if isNumber(arg2) {
		value = arg2
		if arg3 == "-s" || arg3 == "--save" {
			saveFlag = true
		} else if arg3 != "" {
			monitor = arg3
			if arg4 == "-s" || arg4 == "--save" {
				saveFlag = true
			}
		}
	} else if isRelative(arg2) {
		relativeDelta = arg2
		if arg3 != "" && arg3 != "-s" && arg3 != "--save" {
			monitor = arg3
			if arg4 == "-s" || arg4 == "--save" {
				saveFlag = true
			}
		} else if arg3 == "-s" || arg3 == "--save" {
			saveFlag = true
		}
	} else if arg2 == "-s" || arg2 == "--save" {
		monitor := arg3
		if monitor == "" {
			axctlRun("brightness", "save")
			fmt.Println("Saved current brightness for all monitors")
		} else {
			axctlRun("brightness", "save", monitor)
			fmt.Printf("Saved current brightness for %s\n", monitor)
		}
		return
	} else {
		fmt.Println("Error: Invalid brightness value. Must be 0-100 or +/-delta.")
		os.Exit(1)
	}

	if saveFlag {
		if monitor == "" {
			axctlRun("brightness", "save")
		} else {
			axctlRun("brightness", "save", monitor)
		}
	}

	if relativeDelta != "" {
		normalized := relativeDeltaNorm(relativeDelta)
		if monitor == "" {
			axctlRun("brightness", "adjust", fmt.Sprintf("%g", normalized))
		} else {
			axctlRun("brightness", "adjust", monitor, fmt.Sprintf("%g", normalized))
		}
		qsPid := readQsPid()
		if qsPid != 0 {
			notifyQsBrightness(qsPid, "adjust", strconv.FormatFloat(normalized, 'g', -1, 64), monitor)
		} else {
			fmt.Fprintln(os.Stderr, "Warning: Quickshell not running, OSD will not show")
		}
		if monitor == "" {
			fmt.Printf("Adjusted brightness by %s%% for all monitors\n", relativeDelta)
		} else {
			fmt.Printf("Adjusted brightness by %s%% for %s\n", relativeDelta, monitor)
		}
		return
	}

	vInt, _ := strconv.Atoi(value)
	if vInt < 0 || vInt > 100 {
		fmt.Println("Error: Brightness must be between 0 and 100")
		os.Exit(1)
	}
	normalized := percentToNorm(value)
	if monitor == "" {
		axctlRun("brightness", "set", fmt.Sprintf("%g", normalized))
	} else {
		axctlRun("brightness", "set", monitor, fmt.Sprintf("%g", normalized))
	}
	qsPid := readQsPid()
	if qsPid != 0 {
		notifyQsBrightness(qsPid, "set", strconv.FormatFloat(normalized, 'g', -1, 64), monitor)
	} else {
		fmt.Fprintln(os.Stderr, "Warning: Quickshell not running, OSD will not show")
	}
	if monitor == "" {
		fmt.Printf("Set brightness to %s%% for all monitors\n", value)
	} else {
		fmt.Printf("Set brightness to %s%% for %s\n", value, monitor)
	}
}

// axctlRun shells out to `axctl <args...>` and forwards stdout/stderr.
// Empty positional args are passed through to preserve the documented
// "<monitor>" parameter that distinguishes "all" from a specific target.
func axctlRun(args ...string) {
	cmd := exec.Command("axctl", args...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		if _, ok := err.(*exec.ExitError); ok {
			os.Exit(1)
		}
		fmt.Fprintf(os.Stderr, "Error: axctl: %v\n", err)
		os.Exit(1)
	}
}

// readQsPid returns the supervised Quickshell PID from
// $XDG_RUNTIME_DIR/ambxst-qs.pid, or 0 if the file is missing or the
// recorded process is no longer alive (stale pidfile after a crash).
func readQsPid() int {
	pidPath := qsPidPath()
	if pidPath == "" {
		return 0
	}
	data, err := os.ReadFile(pidPath)
	if err != nil {
		return 0
	}
	pid, err := strconv.Atoi(strings.TrimSpace(string(data)))
	if err != nil || pid <= 0 {
		_ = os.Remove(pidPath)
		return 0
	}
	proc, err := os.FindProcess(pid)
	if err != nil {
		return 0
	}
	if err := proc.Signal(syscall.Signal(0)); err != nil {
		_ = os.Remove(pidPath)
		return 0
	}
	return pid
}

func qsPidPath() string {
	if runtime := os.Getenv("XDG_RUNTIME_DIR"); runtime != "" {
		return runtime + "/ambxst-qs.pid"
	}
	return "/tmp/ambxst-qs.pid"
}

// notifyQsBrightness invokes `qs ipc --pid <pid> call brightness <method>
// <arg0> <monitorOrEmpty>` so the running shell updates its in-QML state
// and emits the brightnessChanged signal the OSD listens to.
//
// Failure is non-fatal: the axctl hardware write already succeeded, so
// brightness changed even if the IPC hop (and the OSD) doesn't fire.
func notifyQsBrightness(pid int, method, arg0, monitor string) {
	if !hasBinary("qs") {
		return
	}
	args := []string{"ipc", "--pid", strconv.Itoa(pid), "call", "brightness", method, arg0, monitor}
	cmd := exec.Command("qs", args...)
	cmd.Stdout = nil
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "Warning: qs ipc brightness %s: %v\n", method, err)
	}
}

func percentToNorm(p string) float64 {
	f, err := strconv.ParseFloat(p, 64)
	if err != nil {
		return 0
	}
	return f / 100
}

func relativeDeltaNorm(delta string) float64 {
	sign := 1.0
	s := delta
	if strings.HasPrefix(s, "-") {
		sign = -1
		s = s[1:]
	} else if strings.HasPrefix(s, "+") {
		s = s[1:]
	}
	f, err := strconv.ParseFloat(s, 64)
	if err != nil {
		return 0
	}
	return sign * f / 100
}

func isNumber(s string) bool {
	if s == "" {
		return false
	}
	if s[0] == '+' || s[0] == '-' {
		return false
	}
	n, err := strconv.Atoi(s)
	return err == nil && n >= 0 && n <= 100
}

func isRelative(s string) bool {
	if s == "" {
		return false
	}
	if s[0] != '+' && s[0] != '-' {
		return false
	}
	_, err := strconv.Atoi(s[1:])
	return err == nil && s[1:] != ""
}
