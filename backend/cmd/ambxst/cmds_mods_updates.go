package main

import (
	"encoding/json"
	"fmt"
	"os"
	"strconv"

	"ambxst/backend/pkg/mods"
	"ambxst/backend/pkg/paths"
)

func runModUpdateCommand(command string, args []string) bool {
	method := ""
	params := map[string]any{}
	switch command {
	case "check-updates":
		method = "checkUpdates"
		params["ids"] = args
	case "apply-updates":
		if len(args) != 1 {
			modsUsage("Usage: ambxst mods apply-updates <reviewed-plan-id>")
		}
		method, params["planId"], params["reviewed"] = "applyUpdates", args[0], true
	case "check-interval":
		if len(args) != 1 {
			modsUsage("Usage: ambxst mods check-interval <1|6|24|168>")
		}
		hours, err := strconv.Atoi(args[0])
		if err != nil {
			modsUsage("The interval must be a number of hours: 1, 6, 24, or 168")
		}
		method, params["hours"] = "setUpdateInterval", hours
	case "auto-update":
		if len(args) < 1 || len(args) > 2 {
			modsUsage("Usage: ambxst mods auto-update <on|off|inherit> [mod-id]")
		}
		method, params["policy"], params["id"] = "setUpdatePolicy", args[0], ""
		if len(args) == 2 {
			params["id"] = args[1]
		}
	case "periodic-checks":
		if len(args) != 1 || (args[0] != "on" && args[0] != "off") {
			modsUsage("Usage: ambxst mods periodic-checks <on|off>")
		}
		method, params["enabled"] = "setPeriodicChecks", args[0] == "on"
	case "diagnostics":
		if len(args) != 0 {
			modsUsage("Usage: ambxst mods diagnostics")
		}
		method = "diagnostics"
	case "check-compatibility":
		if len(args) > 1 {
			modsUsage("Usage: ambxst mods check-compatibility [candidate-directory]")
		}
		method, params["base"] = "checkCompatibility", ""
		if len(args) == 1 {
			params["base"] = args[0]
		}
	case "base":
		if len(args) != 0 {
			modsUsage("Usage: ambxst mods base")
		}
		method, params["enabled"] = "setModsEnabled", false
	default:
		return false
	}
	progress := startModProgress(modUpdateCommandProgressLabel(command))
	var result any
	var err error
	if isAlive() {
		var data json.RawMessage
		data, err = newClient().Call("mods."+method, params)
		if err == nil {
			err = json.Unmarshal(data, &result)
		}
	} else {
		manager := mods.NewManager(paths.New())
		switch method {
		case "checkUpdates":
			result, err = manager.CheckUpdates(args, false)
		case "applyUpdates":
			err = fmt.Errorf("the daemon must remain running between preview and apply; start the base shell with AMBXST_MODS_DISABLED=1 ambxst")
		case "setUpdatePolicy":
			result, err = manager.SetUpdatePolicy(params["id"].(string), params["policy"].(string))
		case "setUpdateInterval":
			result, err = manager.SetUpdateInterval(params["hours"].(int))
		case "setPeriodicChecks":
			result, err = manager.SetPeriodicChecks(params["enabled"].(bool))
		case "diagnostics":
			result, err = manager.Diagnostics()
		case "checkCompatibility":
			result, err = manager.CheckBaseCompatibility(params["base"].(string))
		case "setModsEnabled":
			result, err = manager.SetModsEnabled(false)
		}
	}
	progress.finish(err)
	if err != nil {
		fmt.Fprintln(os.Stderr, "Error:", err)
		os.Exit(1)
	}
	data, err := json.MarshalIndent(result, "", "  ")
	if err != nil {
		fmt.Fprintln(os.Stderr, "Error:", err)
		os.Exit(1)
	}
	fmt.Println(string(data))
	return true
}
