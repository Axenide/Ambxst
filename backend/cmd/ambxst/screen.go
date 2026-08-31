package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"

	"ambxst/backend/pkg/svc/notify"
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
		notifyShell("Screen "+sub, "axctl is required to control the screen", "critical")
		os.Exit(1)
	}
	monitors, err := exec.Command("axctl", "monitor", "list").Output()
	if err != nil {
		notifyShell("Screen "+sub, "Failed to list monitors via axctl", "critical")
		os.Exit(1)
	}
	var list []struct {
		ID any `json:"id"`
	}
	if err := json.Unmarshal(monitors, &list); err != nil {
		notifyShell("Screen "+sub, "Failed to parse monitor list", "critical")
		os.Exit(1)
	}
	for _, m := range list {
		id := fmt.Sprintf("%v", m.ID)
		if err := exec.Command("axctl", "monitor", "set-dpms", id, state).Run(); err != nil {
			notifyShell("Screen "+sub, "Failed to set DPMS on monitor "+id, "critical")
			os.Exit(1)
		}
	}
}

func hasBinary(name string) bool {
	_, err := exec.LookPath(name)
	return err == nil
}

// notifyShell routes a notification through the running ambxst daemon so
// it appears in the same lifecycle as any other Ambxst notification
// (tracked, dismissable, visible in popup/notch/dashboard). Falls back to
// notify-send only when the daemon is not running — useful during boot or
// when running the binary in isolation outside the shell.
func notifyShell(summary, body, urgency string) {
	params := map[string]any{
		"summary":  summary,
		"body":     body,
		"appName":  "Ambxst",
		"urgency":  urgency,
	}
	if _, err := newClient().Call("notify.send", params); err != nil {
		_ = notify.SendFallback(summary, body, urgency)
	}
}