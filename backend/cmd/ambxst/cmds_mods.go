package main

import (
	"encoding/json"
	"fmt"
	"os"

	modpkg "ambxst/backend/pkg/mods"
	"ambxst/backend/pkg/paths"
)

func runMods(args []string) {
	command := "list"
	if len(args) > 0 {
		command = args[0]
	}

	var (
		status modpkg.Status
		err    error
	)
	switch command {
	case "list", "status":
		status, err = callMods("status", nil)
	case "install":
		if len(args) != 2 {
			modsUsage("Usage: ambxst mods install <directory|archive|git-url>")
		}
		status, err = callMods("install", map[string]any{"source": args[1]})
	case "install-dependencies":
		if len(args) != 2 {
			modsUsage("Usage: ambxst mods install-dependencies <id>")
		}
		status, err = callMods("installDependencies", map[string]any{"id": args[1]})
	case "enable", "disable":
		if len(args) != 2 {
			modsUsage("Usage: ambxst mods " + command + " <id>")
		}
		status, err = callMods("setEnabled", map[string]any{"id": args[1], "enabled": command == "enable"})
	case "remove", "update":
		if len(args) != 2 {
			modsUsage("Usage: ambxst mods " + command + " <id>")
		}
		status, err = callMods(command, map[string]any{"id": args[1]})
	case "move":
		if len(args) != 3 || (args[2] != "up" && args[2] != "down") {
			modsUsage("Usage: ambxst mods move <id> <up|down>")
		}
		direction := 1
		if args[2] == "up" {
			direction = -1
		}
		status, err = callMods("move", map[string]any{"id": args[1], "direction": direction})
	case "rebuild", "rollback":
		if len(args) != 1 {
			modsUsage("Usage: ambxst mods " + command)
		}
		status, err = callMods(command, nil)
	case "help", "--help", "-h":
		modsUsage("")
	default:
		modsUsage("Unknown mods command: " + command)
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, "Error:", err)
		os.Exit(1)
	}
	printModStatus(status)
	if status.RestartRequired && isAlive() {
		fmt.Println("Restart Ambxst to load the active generation.")
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
	case "rebuild":
		return manager.Rebuild()
	case "rollback":
		return manager.Rollback()
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
	if len(status.Mods) == 0 {
		fmt.Println("No mods installed.")
		return
	}
	for _, mod := range status.Mods {
		state := "disabled"
		if mod.Enabled {
			state = "enabled"
		}
		fmt.Printf("%-9s %-28s %s\n", state, mod.ID, mod.Version)
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
		"    list                             Show installed mods and generation state\n" +
		"    install <source>                 Install from a directory, archive, or Git URL\n" +
		"    install-dependencies <id>        Install and enable a mod's requirements\n" +
		"    enable <id>                      Enable a mod and build a generation\n" +
		"    disable <id>                     Disable a mod and build a generation\n" +
		"    update <id>                      Refresh a mod from its original source\n" +
		"    remove <id>                      Remove a mod package\n" +
		"    move <id> <up|down>              Change patch load order\n" +
		"    rebuild                          Rebuild the enabled mod set\n" +
		"    rollback                         Activate the previous generation\n" +
		"    help                             Show this help\n")
	if message != "" {
		os.Exit(2)
	}
	os.Exit(0)
}
