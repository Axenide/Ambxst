package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// validMatugenSchemes mirrors the matugen schemes shipped with the
// Ambxst bundles. Kept server-side so `ambxst wallpaper -scheme X`
// can validate the input without having to talk to Quickshell first.
var validMatugenSchemes = []string{
	"scheme-content",
	"scheme-expressive",
	"scheme-fidelity",
	"scheme-fruit-salad",
	"scheme-monochrome",
	"scheme-neutral",
	"scheme-rainbow",
	"scheme-tonal-spot",
}

// runWallpaper implements `ambxst wallpaper <file> [-scheme ...] [-oled]
// [-tint] [-monitor ...]`. It resolves the file path, validates flags,
// then dispatches the request to the daemon via the wallpaper.set IPC
// method. The daemon broadcasts it to the QML side, which actually
// applies the change.
func runWallpaper(args []string) int {
	fs, err := parseWallpaperFlags(args)
	if err != nil {
		fmt.Fprintln(os.Stderr, err.Error())
		return 2
	}
	if !isAlive() {
		fmt.Fprintln(os.Stderr, "Error: Ambxst is not running")
		return 1
	}

	abs, err := filepath.Abs(fs.path)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: invalid path: %v\n", err)
		return 1
	}
	if _, err := os.Stat(abs); err != nil {
		fmt.Fprintf(os.Stderr, "Error: wallpaper not found: %s\n", abs)
		return 1
	}

	params := map[string]any{"path": abs}
	if fs.scheme != "" {
		params["scheme"] = fs.scheme
	}
	if fs.oledSet {
		params["oled"] = fs.oled
	}
	if fs.tintSet {
		params["tint"] = fs.tint
	}
	if fs.monitor != "" {
		params["monitor"] = fs.monitor
	}

	res, err := newClient().Call("wallpaper.set", params)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		return 1
	}
	if len(res) > 0 {
		fmt.Println(string(res))
	}
	fmt.Printf("Wallpaper set: %s\n", abs)
	return 0
}

type wallpaperFlags struct {
	path    string
	scheme  string
	oledSet bool
	oled    bool
	tintSet bool
	tint    bool
	monitor string
}

func parseWallpaperFlags(args []string) (*wallpaperFlags, error) {
	fs := &wallpaperFlags{}
	i := 0
	for i < len(args) {
		a := args[i]
		switch a {
		case "-scheme", "--scheme":
			if i+1 >= len(args) {
				return nil, fmt.Errorf("Usage: ambxst wallpaper <file> [-scheme <scheme>] [-oled] [-tint] [-monitor <id|name>]")
			}
			fs.scheme = args[i+1]
			if !isValidScheme(fs.scheme) {
				return nil, fmt.Errorf("Error: unknown scheme %q. Available: %s", fs.scheme, strings.Join(validMatugenSchemes, ", "))
			}
			i += 2
		case "-oled", "--oled":
			fs.oledSet = true
			fs.oled = true
			i++
		case "-tint", "--tint":
			fs.tintSet = true
			fs.tint = true
			i++
		case "-monitor", "--monitor", "-m":
			if i+1 >= len(args) {
				return nil, fmt.Errorf("Usage: ambxst wallpaper <file> [-scheme <scheme>] [-oled] [-tint] [-monitor <id|name>]")
			}
			fs.monitor = args[i+1]
			i += 2
		default:
			if strings.HasPrefix(a, "-") {
				return nil, fmt.Errorf("Error: unknown flag %s", a)
			}
			if fs.path != "" {
				return nil, fmt.Errorf("Error: multiple wallpaper paths provided (%s and %s)", fs.path, a)
			}
			fs.path = a
			i++
		}
	}
	if fs.path == "" {
		return nil, fmt.Errorf("Usage: ambxst wallpaper <file> [-scheme <scheme>] [-oled] [-tint] [-monitor <id|name>]")
	}
	return fs, nil
}

func isValidScheme(scheme string) bool {
	for _, s := range validMatugenSchemes {
		if s == scheme {
			return true
		}
	}
	return false
}

// runPreset implements `ambxst preset [...]`.
//
//	ambxst preset               → list presets (shortcut for `ambxst preset -l`)
//	ambxst preset -l            → list presets
//	ambxst preset "Name"        → apply preset
func runPreset(args []string) int {
	if !isAlive() {
		fmt.Fprintln(os.Stderr, "Error: Ambxst is not running")
		return 1
	}

	// `ambxst preset` with no args == `ambxst preset -l`
	if len(args) == 0 {
		return presetList()
	}

	first := args[0]
	if first == "-l" || first == "--list" || first == "-h" || first == "--help" {
		return presetList()
	}

	if strings.HasPrefix(first, "-") {
		fmt.Fprintf(os.Stderr, "Error: unknown flag %s\n", first)
		fmt.Fprintln(os.Stderr, "Usage: ambxst preset [-l] [\"Preset Name\"]")
		return 2
	}

	name := strings.Join(args, " ")
	res, err := newClient().Call("preset.load", map[string]any{"name": name})
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		return 1
	}
	if len(res) > 0 {
		var parsed map[string]any
		_ = json.Unmarshal(res, &parsed)
		if ok, _ := parsed["ok"].(bool); ok {
			fmt.Printf("Preset applied: %s\n", name)
			return 0
		}
		if errMsg, _ := parsed["error"].(string); errMsg != "" {
			fmt.Fprintf(os.Stderr, "Error: %s\n", errMsg)
			return 1
		}
	}
	fmt.Printf("Preset applied: %s\n", name)
	return 0
}

func presetList() int {
	res, err := newClient().Call("preset.list", nil)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		return 1
	}
	var presets []struct {
		Name      string `json:"name"`
		Official  bool   `json:"official"`
		Author    string `json:"author"`
		AuthorURL string `json:"authorUrl"`
	}
	if err := json.Unmarshal(res, &presets); err != nil {
		fmt.Fprintf(os.Stderr, "Error: decoding preset list: %v\n", err)
		return 1
	}
	if len(presets) == 0 {
		fmt.Println("No presets found.")
		return 0
	}

	// Find longest name for column alignment.
	maxName := 0
	for _, p := range presets {
		if len(p.Name) > maxName {
			maxName = len(p.Name)
		}
	}

	official := []presetRow{}
	user := []presetRow{}
	for _, p := range presets {
		row := presetRow{Name: p.Name, Tag: "", Author: p.Author}
		if p.Official {
			row.Tag = "[official]"
			official = append(official, row)
		} else {
			row.Tag = "[user]"
			user = append(user, row)
		}
	}
	sort.SliceStable(official, func(i, j int) bool { return strings.ToLower(official[i].Name) < strings.ToLower(official[j].Name) })
	sort.SliceStable(user, func(i, j int) bool { return strings.ToLower(user[i].Name) < strings.ToLower(user[j].Name) })

	printRows("Official presets", official, maxName)
	if len(user) > 0 {
		printRows("User presets", user, maxName)
	}
	return 0
}

type presetRow struct {
	Name   string
	Tag    string
	Author string
}

func printRows(title string, rows []presetRow, maxName int) {
	fmt.Println(title + ":")
	for _, r := range rows {
		author := ""
		if r.Author != "" && r.Author != "Unknown" {
			author = " — " + r.Author
		}
		fmt.Printf("  %-*s  %-10s%s\n", maxName, r.Name, r.Tag, author)
	}
}
