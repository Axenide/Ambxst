package brightness

import (
	"encoding/json"
	"fmt"
	"os/exec"
	"strconv"
	"strings"

	"ambxst/backend/pkg/ipc"
)

// Service applies per-monitor brightness changes. Mirrors Brightness.qml:
// internal panels (eDP/LVDS/DSI) use brightnessctl; external monitors use
// ddcutil. The CLI (`ambxst brightness ...`) drives this service.
type Service struct{}

func NewService() *Service {
	return &Service{}
}

func (s *Service) Register(srv *ipc.Server) {
	srv.Register(&ipc.Service{
		Name: "brightness",
		Methods: map[string]ipc.HandlerFunc{
			"set":    s.set,
			"adjust": s.adjust,
			"list":   s.list,
		},
	})
}

// set sets brightness for a monitor (or all). value: 0..1 float.
func (s *Service) set(params json.RawMessage) (any, error) {
	var p struct {
		Value   float64 `json:"value"`
		Monitor string  `json:"monitor"`
	}
	if err := json.Unmarshal(params, &p); err != nil {
		return nil, err
	}
	if p.Value < 0 {
		p.Value = 0
	}
	if p.Value > 1 {
		p.Value = 1
	}
	targets := s.targetsFor(p.Monitor)
	if len(targets) == 0 {
		return map[string]any{"error": "no monitors"}, nil
	}
	for _, t := range targets {
		t.apply(p.Value)
	}
	return map[string]any{"ok": true}, nil
}

// adjust adds a relative delta (-1..1) to the current brightness.
func (s *Service) adjust(params json.RawMessage) (any, error) {
	var p struct {
		Delta   float64 `json:"delta"`
		Monitor string  `json:"monitor"`
	}
	if err := json.Unmarshal(params, &p); err != nil {
		return nil, err
	}
	targets := s.targetsFor(p.Monitor)
	if len(targets) == 0 {
		return map[string]any{"error": "no monitors"}, nil
	}
	for _, t := range targets {
		cur, ok := t.current()
		if !ok {
			continue
		}
		v := cur + p.Delta
		if v < 0.05 {
			v = 0.05
		}
		if v > 1 {
			v = 1
		}
		t.apply(v)
	}
	return map[string]any{"ok": true}, nil
}

// list returns known monitor targets with their normalized brightness.
func (s *Service) list(params json.RawMessage) (any, error) {
	out := []map[string]any{}
	for _, t := range s.targetsFor("") {
		cur, ok := t.current()
		entry := map[string]any{
			"monitor": t.name,
			"kind":    t.kind,
		}
		if ok {
			entry["brightness"] = cur
		}
		out = append(out, entry)
	}
	return out, nil
}

// --- monitor targets ---

type target struct {
	name string
	kind string // "brightnessctl" | "ddcutil"
	bus  string
}

func (t *target) apply(value float64) {
	if t.kind == "ddcutil" {
		exec.Command("ddcutil", "-b", t.bus, "setvcp", "10", strconv.Itoa(int(value*100))).Run()
		return
	}
	exec.Command("brightnessctl", "--class", "backlight", "s", strconv.Itoa(int(value*100)), "--quiet").Run()
}

func (t *target) current() (float64, bool) {
	if t.kind == "ddcutil" {
		out, err := exec.Command("ddcutil", "-b", t.bus, "getvcp", "10").Output()
		if err != nil {
			return 0, false
		}
		var cur, max int
		for _, line := range strings.Split(string(out), "\n") {
			if strings.Contains(line, "current value") {
				fmt.Sscanf(line, "VCP 10 CTA-861 Feature: Display Luminance (current value = %d, max value = %d)", &cur, &max)
			}
		}
		if max <= 0 {
			fs := strings.Fields(string(out))
			if len(fs) >= 2 {
				max, _ = strconv.Atoi(fs[len(fs)-1])
				cur, _ = strconv.Atoi(fs[len(fs)-2])
			}
		}
		if max <= 0 {
			return 0, false
		}
		return float64(cur) / float64(max), true
	}
	out, err := exec.Command("sh", "-c", "brightnessctl g; brightnessctl m").Output()
	if err != nil {
		return 0, false
	}
	fs := strings.Fields(string(out))
	if len(fs) < 2 {
		return 0, false
	}
	cur, err1 := strconv.ParseFloat(fs[0], 64)
	max, err2 := strconv.ParseFloat(fs[1], 64)
	if err1 != nil || err2 != nil || max <= 0 {
		return 0, false
	}
	return cur / max, true
}

// targetsFor resolves the monitor(s) to adjust. With an empty name it
// returns all known internal devices + DDC displays.
func (s *Service) targetsFor(monitorName string) []*target {
	if monitorName != "" {
		// Per-monitor resolution from the shell side: Brightness.qml keeps
		// per-screen state. Here we map known internal devices by name match.
		return s.matchTargets(monitorName)
	}
	// All targets: internal backlights + ddc displays.
	internal := s.internalTargets()
	ddc := s.ddcTargets()
	return append(internal, ddc...)
}

func (s *Service) matchTargets(name string) []*target {
	// "backlight" matches all internal backlight devices.
	if name == "backlight" {
		return s.internalTargets()
	}
	// Internal panel names contain edp/lvds/dsi.
	lower := strings.ToLower(name)
	for _, t := range s.internalTargets() {
		if strings.Contains(lower, "edp") || strings.Contains(lower, "lvds") || strings.Contains(lower, "dsi") || name == t.name {
			return []*target{t}
		}
	}
	// External: DDC bus entries are matched by name/order like Brightness.qml.
	if strings.HasPrefix(lower, "ddc-") {
		bus := strings.TrimPrefix(lower, "ddc-")
		for _, t := range s.ddcTargets() {
			if t.name == "ddc-"+bus {
				return []*target{t}
			}
		}
	}
	ddc := s.ddcTargets()
	if len(ddc) > 0 {
		return ddc[:1]
	}
	return nil
}

func (s *Service) internalTargets() []*target {
	if _, err := exec.LookPath("brightnessctl"); err != nil {
		return nil
	}
	// Detect all backlight devices.
	out, err := exec.Command("sh", "-c", "ls /sys/class/backlight/ 2>/dev/null").Output()
	if err != nil {
		return nil
	}
	targets := []*target{}
	for _, dev := range strings.Fields(string(out)) {
		targets = append(targets, &target{
			name: "backlight-" + dev,
			kind: "brightnessctl",
		})
	}
	return targets
}

func (s *Service) ddcTargets() []*target {
	if _, err := exec.LookPath("ddcutil"); err != nil {
		return nil
	}
	out, err := exec.Command("ddcutil", "detect", "--brief").Output()
	if err != nil {
		return nil
	}
	targets := []*target{}
	blocks := strings.Split(string(out), "\n\n")
	for _, block := range blocks {
		if !strings.HasPrefix(block, "Display ") {
			continue
		}
		var bus string
		for _, line := range strings.Split(block, "\n") {
			line = strings.TrimSpace(line)
			if strings.HasPrefix(line, "I2C bus:") {
				if idx := strings.LastIndex(line, "/dev/i2c-"); idx >= 0 {
					bus = line[idx+len("/dev/i2c-"):]
				}
			}
		}
		if bus != "" {
			targets = append(targets, &target{name: "ddc-" + bus, kind: "ddcutil", bus: bus})
		}
	}
	return targets
}
