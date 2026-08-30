package main

import (
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"
)

// runBrightness is a thin shim over `axctl brightness <action>`. It
// preserves the legacy `ambxst brightness ...` CLI surface so existing
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
		monitor := arg3
		if monitor == "" {
			axctlRun("brightness", "restore")
			fmt.Println("Restored brightness for all monitors")
		} else {
			axctlRun("brightness", "restore", monitor)
			fmt.Printf("Restored brightness for %s\n", monitor)
		}
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
		monitor = arg3
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
		delta := relativeDeltaNorm(relativeDelta)
		if monitor == "" {
			axctlRun("brightness", "adjust", fmt.Sprintf("%g", delta))
			fmt.Printf("Adjusted brightness by %s%% for all monitors\n", relativeDelta)
		} else {
			axctlRun("brightness", "adjust", monitor, fmt.Sprintf("%g", delta))
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
		fmt.Printf("Set brightness to %s%% for all monitors\n", value)
	} else {
		axctlRun("brightness", "set", monitor, fmt.Sprintf("%g", normalized))
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
