package main

import (
	"encoding/json"
	"fmt"
	"os"
	"strconv"
	"strings"

	modpkg "ambxst/backend/pkg/mods"
	"ambxst/backend/pkg/paths"
	"ambxst/backend/pkg/svc/notify"
)

func runMods(args []string) {
	command := "list"
	if len(args) > 0 {
		command = args[0]
		if runModUpdateCommand(command, args[1:]) {
			return
		}
	}
	if command == "open-url" {
		if len(args) != 2 {
			modsUsage("Usage: ambxst mods open-url <ambxst://mods/install?source=...>")
		}
		action, err := parseModURL(args[1])
		if err != nil {
			notifyModURLResult(action, err)
			fmt.Fprintln(os.Stderr, "Error:", err)
			os.Exit(1)
		}
		progress := startModProgress(modCommandProgressLabel(action.command))
		status, err := runModCommand(action.command, []string{action.command, action.value})
		progress.finish(err)
		notifyModURLResult(action, err)
		if err != nil {
			fmt.Fprintln(os.Stderr, "Error:", err)
			os.Exit(1)
		}
		printModStatus(status)
		return
	}

	switch command {
	case "list", "status":
	case "install":
		if len(args) != 2 {
			modsUsage("Usage: ambxst mods install <directory|archive|git-url>")
		}
	case "install-dependencies":
		if len(args) != 2 {
			modsUsage("Usage: ambxst mods install-dependencies <id>")
		}
	case "enable", "disable":
		if len(args) != 2 {
			modsUsage("Usage: ambxst mods " + command + " <id>")
		}
	case "remove", "update":
		if len(args) != 2 {
			modsUsage("Usage: ambxst mods " + command + " <id>")
		}
	case "move":
		if len(args) != 3 || (args[2] != "up" && args[2] != "down") {
			modsUsage("Usage: ambxst mods move <id> <up|down>")
		}
	case "position":
		if len(args) != 4 || !validPositionKind(args[2]) || !validPositionValue(args[3]) {
			modsUsage("Usage: ambxst mods position <id> <menu|tab|bar> <number|auto>")
		}
	case "rebuild", "rollback":
		if len(args) != 1 {
			modsUsage("Usage: ambxst mods " + command)
		}
	case "bypass":
		if len(args) != 2 || (args[1] != "on" && args[1] != "off") {
			modsUsage("Usage: ambxst mods bypass <on|off>")
		}
	case "help", "--help", "-h":
		modsUsage("")
	default:
		modsUsage("Unknown mods command: " + command)
	}
	progress := startModProgress(modCommandProgressLabel(command))
	status, err := runModCommand(command, args)
	progress.finish(err)
	if err != nil {
		fmt.Fprintln(os.Stderr, "Error:", err)
		os.Exit(1)
	}
	printModStatus(status)
	if status.RestartRequired && isAlive() {
		fmt.Println("Restart Ambxst to load the active generation.")
	}
}

func notifyModURLResult(action modURLAction, resultErr error) {
	summary := "Ambxst mod link"
	body := "The mod link is invalid."
	urgency := "critical"
	if resultErr == nil {
		urgency = "normal"
		if action.command == "install" {
			body = "The mod was installed and remains disabled until you enable it."
		}
	} else if action.command == "install" {
		body = "The mod could not be installed. Run the link command in a terminal for details."
	}
	params := map[string]any{
		"summary":    summary,
		"body":       body,
		"appName":    "Ambxst",
		"urgency":    urgency,
		"replaceKey": "mods-url",
	}
	if isAlive() {
		if _, err := newClient().Call("notify.send", params); err == nil {
			return
		}
	}
	_ = notify.SendFallback(summary, body, urgency)
}

func runModCommand(command string, args []string) (modpkg.Status, error) {
	switch command {
	case "list", "status":
		return callMods("status", nil)
	case "install":
		return callMods("install", map[string]any{"source": args[1]})
	case "install-dependencies":
		return callMods("installDependencies", map[string]any{"id": args[1]})
	case "enable", "disable":
		return callMods("setEnabled", map[string]any{"id": args[1], "enabled": command == "enable"})
	case "remove", "update":
		return callMods(command, map[string]any{"id": args[1]})
	case "move":
		direction := 1
		if args[2] == "up" {
			direction = -1
		}
		return callMods("move", map[string]any{"id": args[1], "direction": direction})
	case "position":
		params := map[string]any{"id": args[1], "kind": args[2], "position": nil}
		if args[3] != "auto" {
			position, _ := strconv.Atoi(args[3])
			params["position"] = position
		}
		return callMods("setPosition", params)
	case "rebuild", "rollback":
		return callMods(command, nil)
	case "bypass":
		return callMods("setBypassVersionCheck", map[string]any{"enabled": args[1] == "on"})
	default:
		return modpkg.Status{}, fmt.Errorf("unsupported mods command %q", command)
	}
}

func callMods(method string, params map[string]any) (modpkg.Status, error) {
	if isAlive() {
		result, err := newClient().Call("mods."+method, params)
		if err != nil {
			return modpkg.Status{}, err
		}
		var status modpkg.Status
		if err := json.Unmarshal(result, &status); err != nil {
			return modpkg.Status{}, err
		}
		return status, nil
	}

	manager := modpkg.NewManager(paths.New())
	switch method {
	case "status":
		return manager.Status()
	case "install":
		return manager.Install(params["source"].(string))
	case "installDependencies":
		return manager.InstallDependencies(params["id"].(string))
	case "setEnabled":
		return manager.SetEnabled(params["id"].(string), params["enabled"].(bool))
	case "remove":
		return manager.Remove(params["id"].(string))
	case "update":
		return manager.Update(params["id"].(string))
	case "move":
		return manager.Move(params["id"].(string), params["direction"].(int))
	case "setPosition":
		var position *int
		if value, ok := params["position"].(int); ok {
			position = &value
		}
		return manager.SetPosition(params["id"].(string), params["kind"].(string), position)
	case "rebuild":
		return manager.Rebuild()
	case "rollback":
		return manager.Rollback()
	case "setBypassVersionCheck":
		return manager.SetBypassVersionCheck(params["enabled"].(bool))
	default:
		return modpkg.Status{}, fmt.Errorf("unsupported mods method %q", method)
	}
}

func printModStatus(status modpkg.Status) {
	fmt.Printf("Ambxst %s", status.BaseVersion)
	if status.BaseRevision != "" {
		fmt.Printf(" (%s)", shortModRevision(status.BaseRevision))
	}
	fmt.Println()
	if status.ActiveGeneration == "" {
		fmt.Println("Active generation: base")
	} else {
		fmt.Println("Active generation:", status.ActiveGeneration)
	}
	if status.BypassVersionCheck {
		fmt.Println("Version check: bypassed")
	}
	if len(status.Mods) == 0 {
		fmt.Println("No mods installed.")
		return
	}
	for _, mod := range status.Mods {
		state := "disabled"
		if mod.Enabled {
			state = "enabled"
		}
		fmt.Printf("%-9s %-28s %s%s\n", state, mod.ID, mod.Version, modPositionSummary(mod))
	}
}

func shortModRevision(revision string) string {
	if len(revision) > 12 {
		return revision[:12]
	}
	return revision
}

func modsUsage(message string) {
	if message != "" {
		fmt.Fprintln(os.Stderr, message)
		fmt.Fprintln(os.Stderr)
	}
	fmt.Print("Ambxst Mods\n\n" +
		"Usage: ambxst mods <command>\n\n" +
		"Commands:\n" +
		"    check-updates [id ...]           Prepare an update preview\n" +
		"    apply-updates <plan-id>          Apply the reviewed preview\n" +
		"    auto-update <on|off|inherit> [id] Set automatic update policy\n" +
		"    check-interval <1|6|24|168>       Set automatic check interval in hours\n" +
		"    periodic-checks <on|off>          Enable or pause scheduled mod checks\n" +
		"    check-compatibility [directory]  Test composition against a candidate base\n" +
		"    diagnostics                      Print a report without settings or sources\n" +
		"    base                             Use the base shell on the next start\n" +
		"    list                             Show installed mods and generation state\n" +
		"    install <source>                 Install from a directory, archive, or Git URL\n" +
		"    open-url <ambxst-url>            Handle an install link from a browser\n" +
		"    install-dependencies <id>        Install and enable a mod's requirements\n" +
		"    enable <id>                      Enable a mod and build a generation\n" +
		"    disable <id>                     Disable a mod and build a generation\n" +
		"    update <id>                      Refresh a mod from its original source\n" +
		"    remove <id>                      Remove a mod package\n" +
		"    move <id> <up|down>              Change patch load order\n" +
		"    position <id> <menu|tab|bar> <n|auto>\n" +
		"                                     Place a mod's menu entry, Dashboard tab, or bar widget\n" +
		"    rebuild                          Rebuild the enabled mod set\n" +
		"    rollback                         Activate the previous generation\n" +
		"    bypass <on|off>                  Toggle the Ambxst version compatibility requirement\n" +
		"    help                             Show this help\n")
	if message != "" {
		os.Exit(2)
	}
	os.Exit(0)
}

func validPositionKind(kind string) bool {
	return kind == modpkg.PositionMenu || kind == modpkg.PositionTab || kind == modpkg.PositionBar
}

func validPositionValue(value string) bool {
	if value == "auto" {
		return true
	}
	_, err := strconv.Atoi(value)
	return err == nil
}

// modPositionSummary lists the positions a mod uses; "auto" marks load order.
func modPositionSummary(mod modpkg.ModInfo) string {
	var parts []string
	describe := func(kind string, position int, pinned bool) {
		value := strconv.Itoa(position)
		if !pinned {
			value += " auto"
		}
		parts = append(parts, kind+" "+value)
	}
	if mod.HasSettingsMenu {
		parts = append(parts, "menu "+strconv.Itoa(mod.SettingsMenuIndex))
	}
	if mod.HasTabPosition {
		describe("tab", mod.TabPosition, mod.TabPositionPinned)
	}
	if mod.HasBarPosition {
		describe("bar", mod.BarPosition, mod.BarPositionPinned)
	}
	if len(parts) == 0 {
		return ""
	}
	return "  [" + strings.Join(parts, ", ") + "]"
}
