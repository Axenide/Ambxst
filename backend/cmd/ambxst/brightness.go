package main

import (
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"syscall"
)

// runBrightness drives Quickshell IPC directly for set/adjust/pull so the
// CLI recycles the exact same path the UI sliders use:
//
//	CLI keybind
//	  └─ qs ipc call brightness.adjust/set <value> ""
//	       └─ QML IpcHandler
//	            └─ mon.setBrightness(value)  ← slider-equivalent
//	                 ├─ monitor.brightness = value  (QML state → OSD fires)
//	                 └─ setTimer.restart()           (debounced write)
//
// This was the design of the 1.1.5 bash CLI. By dropping the parallel
// `axctl brightness ...` call we avoid a second ddcutil write per bind
// press — that's what produced the latency on DDC displays and the bus
// saturation under key-repeat. Save/restore still go through axctl
// because they're file-backed operations and don't need OSD updates
// (restore additionally calls `brightness.pull` so the OSD does fire
// after the hardware restore completes).
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
		runBrightnessRestore(arg3)
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
		fmt.Fprintln(os.Stderr, "Error: Invalid brightness value. Must be 0-100 or +/-delta.")
		os.Exit(1)
	}

	if saveFlag {
		if monitor == "" {
			axctlRun("brightness", "save")
		} else {
			axctlRun("brightness", "save", monitor)
		}
	}

	qsPid := readQsPidOrExit()

	if relativeDelta != "" {
		normalized := relativeDeltaNorm(relativeDelta)
		notifyQsBrightness(qsPid, "adjust", strconv.FormatFloat(normalized, 'g', -1, 64), monitor)
		if monitor == "" {
			fmt.Printf("Adjusted brightness by %s%% for all monitors\n", relativeDelta)
		} else {
			fmt.Printf("Adjusted brightness by %s%% for %s\n", relativeDelta, monitor)
		}
		return
	}

	vInt, _ := strconv.Atoi(value)
	if vInt < 0 || vInt > 100 {
		fmt.Fprintln(os.Stderr, "Error: Brightness must be between 0 and 100")
		os.Exit(1)
	}
	normalized := percentToNorm(value)
	notifyQsBrightness(qsPid, "set", strconv.FormatFloat(normalized, 'g', -1, 64), monitor)
	if monitor == "" {
		fmt.Printf("Set brightness to %s%% for all monitors\n", value)
	} else {
		fmt.Printf("Set brightness to %s%% for %s\n", value, monitor)
	}
}

// runBrightnessRestore writes the saved values back to hardware via axctl
// then asks the running shell to re-read each monitor via `brightness.pull`,
// which fires the OSD. The pull goes through ddcutil/brightnessctl
// independently of axctl — same source of truth (the kernel/DDC device) as
// the slider path, so OSD reflects what actually landed.
func runBrightnessRestore(monitor string) {
	qsPid := readQsPidOrExit()
	if monitor == "" {
		axctlRun("brightness", "restore")
	} else {
		axctlRun("brightness", "restore", monitor)
	}
	notifyQsBrightness(qsPid, "pull", "", monitor)
	if monitor == "" {
		fmt.Println("Restored brightness for all monitors")
	} else {
		fmt.Printf("Restored brightness for %s\n", monitor)
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

// readQsPidOrExit returns the supervised Quickshell PID or exits with a
// clear error. Mirrors the legacy bash script behavior where every
// brightness invocation required a running Ambxst shell — we don't fall
// back to axctl because that would re-introduce the duplicate ddcutil
// write the CLI was specifically designed to avoid.
func readQsPidOrExit() int {
	if !hasBinary("qs") {
		fmt.Fprintln(os.Stderr, "Error: qs not found in PATH")
		os.Exit(1)
	}
	pid := readQsPid()
	if pid == 0 {
		fmt.Fprintln(os.Stderr, "Error: Ambxst is not running")
		os.Exit(1)
	}
	return pid
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
// <arg0> <monitorOrEmpty>`. Failure is fatal here (the caller already
// resolved QS via readQsPidOrExit), so a non-zero exit signals "shutting
// down" or "IPC disconnect" to the user.
func notifyQsBrightness(pid int, method, arg0, monitor string) {
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
