package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
)

func runScreen(args []string) {
	sub := ""
	if len(args) > 0 {
		sub = args[0]
	}
	state := ""
	switch sub {
	case "off":
		state = "0"
	case "on":
		state = "1"
	default:
		fmt.Println("Usage: ambxst screen [on|off]")
		os.Exit(1)
	}

	if !hasBinary("axctl") {
		notify("Screen "+sub, "axctl is required to control the screen")
		os.Exit(1)
	}
	monitors, err := exec.Command("axctl", "monitor", "list").Output()
	if err != nil {
		notify("Screen "+sub, "Failed to list monitors via axctl")
		os.Exit(1)
	}
	var list []struct {
		ID any `json:"id"`
	}
	if err := json.Unmarshal(monitors, &list); err != nil {
		notify("Screen "+sub, "Failed to parse monitor list")
		os.Exit(1)
	}
	for _, m := range list {
		id := fmt.Sprintf("%v", m.ID)
		if err := exec.Command("axctl", "monitor", "set-dpms", id, state).Run(); err != nil {
			notify("Screen "+sub, "Failed to set DPMS on monitor "+id)
			os.Exit(1)
		}
	}
}

func hasBinary(name string) bool {
	_, err := exec.LookPath(name)
	return err == nil
}

func notify(title, body string) {
	exec.Command("notify-send", title, body).Start()
}