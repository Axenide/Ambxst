package main

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
)

const brightnessSaveFile = "/tmp/ambxst_brightness_saved.txt"

// runBrightness mirrors the legacy `ambxst brightness` CLI command.
func runBrightness(args []string) {
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

	// -l/--list
	if arg2 == "-l" || arg2 == "--list" {
		fmt.Println("Monitors:")
		out, err := exec.Command("bash", "-c",
			"hyprctl monitors -j 2>/dev/null | jq -r '.[] | \"  \\(.name)\"'").
			CombinedOutput()
		if err != nil || len(out) == 0 {
			fmt.Println("Error: Could not list monitors")
			os.Exit(1)
		}
		fmt.Print(string(out))
		return
	}

	// -r/--restore
	if arg2 == "-r" || arg2 == "--restore" {
		if !fileExists(brightnessSaveFile) {
			fmt.Println("Error: No saved brightness found. Use -s to save first.")
			os.Exit(1)
		}
		monitor := arg3
		if monitor == "" {
			lines := readLines(brightnessSaveFile)
			for _, line := range lines {
				parts := strings.SplitN(line, ":", 2)
				if len(parts) != 2 {
					continue
				}
				normalized := percentToNorm(parts[1])
				ipcBrightnessSet(normalized, parts[0])
			}
			fmt.Println("Restored brightness for all monitors")
		} else {
			value := ""
			for _, line := range readLines(brightnessSaveFile) {
				if strings.HasPrefix(line, monitor+":") {
					value = strings.SplitN(line, ":", 2)[1]
				}
			}
			if value == "" {
				fmt.Printf("Error: No saved brightness for monitor %s\n", monitor)
				os.Exit(1)
			}
			ipcBrightnessSet(percentToNorm(value), monitor)
			fmt.Printf("Restored brightness for %s to %s%%\n", monitor, value)
		}
		return
	}

	value := ""
	monitor := ""
	saveFlag := false
	relativeMode := false
	relativeDelta := ""

	if isNumber(arg2) {
		value = arg2
		if arg3 == "-s" || arg3 == "--save" {
			saveFlag = true
		} else if arg3 != "" && arg3 != "-s" && arg3 != "--save" {
			monitor = arg3
			if arg4 == "-s" || arg4 == "--save" {
				saveFlag = true
			}
		}
	} else if isRelative(arg2) {
		relativeMode = true
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
		saveBrightness(monitor)
		return
	} else {
		fmt.Println("Error: Invalid brightness value. Must be 0-100 or +/-delta.")
		os.Exit(1)
	}

	// Relative mode: adjust
	if relativeMode {
		normalized := relativeDeltaNorm(relativeDelta)
		ipcBrightnessAdjust(normalized, monitor)
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

	if saveFlag {
		saveBrightness(monitor)
	}

	normalized := percentToNorm(value)
	if monitor == "" {
		ipcBrightnessSet(normalized, "")
		fmt.Printf("Set brightness to %s%% for all monitors\n", value)
	} else {
		ipcBrightnessSet(normalized, monitor)
		fmt.Printf("Set brightness to %s%% for %s\n", value, monitor)
	}
}

func ipcBrightnessSet(normalized, monitor string) {
	params := map[string]any{"value": normalized, "monitor": monitor}
	if hasSocketUp() {
		mustCallQuiet("brightness.set", params)
		return
	}
	// Fallback via qs ipc (only when shell is up, not daemon).
	exec.Command("sh", "-c", "qs ipc --pid $(cat /tmp/ambxst.pid 2>/dev/null) call brightness set "+normalized+" "+monitor).Run()
}

func ipcBrightnessAdjust(delta, monitor string) {
	params := map[string]any{"delta": delta, "monitor": monitor}
	if hasSocketUp() {
		mustCallQuiet("brightness.adjust", params)
		return
	}
	exec.Command("sh", "-c", "qs ipc --pid $(cat /tmp/ambxst.pid 2>/dev/null) call brightness adjust "+delta+" "+monitor).Run()
}

func hasSocketUp() bool { return isAlive() }

func mustCallQuiet(method string, params any) {
	_ = mustCallNoExit(method, params)
}

func mustCallNoExit(method string, params any) error {
	c := newClient()
	_, err := c.Call(method, params)
	return err
}

func saveBrightness(monitor string) {
	lines := brightnessList()
	if monitor == "" {
		// Save all
		f, err := os.Create(brightnessSaveFile)
		if err != nil {
			fmt.Println("Warning: could not save brightness")
			return
		}
		defer f.Close()
		for _, l := range lines {
			parts := strings.SplitN(l, ":", 2)
			if len(parts) == 2 {
				fmt.Fprintf(f, "%s:%s\n", parts[0], parts[1])
			}
		}
		fmt.Println("Saved current brightness for all monitors")
	} else {
		saved := map[string]string{}
		for _, l := range readLines(brightnessSaveFile) {
			parts := strings.SplitN(l, ":", 2)
			if len(parts) == 2 {
				saved[parts[0]] = parts[1]
			}
		}
		current := ""
		for _, l := range brightnessList() {
			if strings.HasPrefix(l, monitor+":") {
				current = strings.SplitN(l, ":", 2)[1]
			}
		}
		if current == "" {
			fmt.Printf("Error: Monitor %s not found\n", monitor)
			os.Exit(1)
		}
		saved[monitor] = current
		f, _ := os.Create(brightnessSaveFile)
		for k, v := range saved {
			fmt.Fprintf(f, "%s:%s\n", k, v)
		}
		f.Close()
		fmt.Printf("Saved current brightness for %s (%s%%)\n", monitor, current)
	}
}

func brightnessList() []string {
	script := filepath.Join(shellDir(), "scripts", "brightness_list.sh")
	if fileExists(script) {
		out, err := exec.Command("bash", script).Output()
		if err == nil {
			return strings.Split(strings.TrimSpace(string(out)), "\n")
		}
	}
	return nil
}

func percentToNorm(p string) string {
	f, err := strconv.ParseFloat(p, 64)
	if err != nil {
		return "0"
	}
	return fmt.Sprintf("%.2f", f/100)
}

func relativeDeltaNorm(delta string) string {
	f, err := strconv.ParseFloat(delta, 64)
	if err != nil {
		return "0"
	}
	return fmt.Sprintf("%.2f", f/100)
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

func readLines(path string) []string {
	f, err := os.Open(path)
	if err != nil {
		return nil
	}
	defer f.Close()
	var lines []string
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		lines = append(lines, sc.Text())
	}
	return lines
}