package axmon

import (
	"encoding/json"
	"fmt"
	"math"
	"os/exec"
)

type Monitor struct {
	ID        string                 `json:"id"`
	Name      string                 `json:"name"`
	Width     int                    `json:"width"`
	Height    int                    `json:"height"`
	Scale     float64                `json:"scale"`
	IsFocused bool                   `json:"is_focused"`
	Metadata  map[string]interface{} `json:"metadata,omitempty"`
}

func (m Monitor) X() int {
	if v, ok := m.Metadata["x"].(float64); ok {
		return int(v)
	}
	return 0
}

func (m Monitor) Y() int {
	if v, ok := m.Metadata["y"].(float64); ok {
		return int(v)
	}
	return 0
}

func (m Monitor) Transform() int {
	if v, ok := m.Metadata["transform"].(float64); ok {
		return int(v)
	}
	return 0
}

func (m Monitor) EffectiveScale() float64 {
	if m.Scale > 0 {
		return m.Scale
	}
	return 1.0
}

// NOTE: `axctl monitor list` reports width/height in PHYSICAL pixels but
// x/y in LOGICAL pixels (observed live: a 2880-wide scale-2 output is
// followed by the next output at x=1440). Always use LogicalWidth and
// LogicalHeight when comparing against logical coordinates.

// LogicalWidth returns the width in logical pixels.
func (m Monitor) LogicalWidth() int {
	s := m.EffectiveScale()
	if s <= 0 {
		return m.Width
	}
	return int(math.Round(float64(m.Width) / s))
}

// LogicalHeight returns the height in logical pixels.
func (m Monitor) LogicalHeight() int {
	s := m.EffectiveScale()
	if s <= 0 {
		return m.Height
	}
	return int(math.Round(float64(m.Height) / s))
}

// List returns the current monitor layout via axctl.
func List() ([]Monitor, error) {
	out, err := exec.Command("axctl", "monitor", "list").Output()
	if err != nil {
		return nil, fmt.Errorf("axctl monitor list: %w", err)
	}
	var monitors []Monitor
	if err := json.Unmarshal(out, &monitors); err != nil {
		return nil, fmt.Errorf("parse monitors: %w", err)
	}
	return monitors, nil
}

// FindByName returns the monitor with the given output name.
func FindByName(monitors []Monitor, name string) (*Monitor, bool) {
	for i := range monitors {
		if monitors[i].Name == name {
			return &monitors[i], true
		}
	}
	return nil, false
}

// Focused returns the focused monitor, or the first one.
func Focused(monitors []Monitor) (*Monitor, bool) {
	for i := range monitors {
		if monitors[i].IsFocused {
			return &monitors[i], true
		}
	}
	if len(monitors) > 0 {
		return &monitors[0], true
	}
	return nil, false
}

// Containing resolves which monitor holds a logical global point.
// Extents use logical dimensions: raw width/height are physical pixels
// while x/y are logical, so comparing a logical point against the raw
// width overextends scaled outputs into their neighbor.
func Containing(monitors []Monitor, x, y int) (*Monitor, bool) {
	for i := range monitors {
		m := &monitors[i]
		mx, my := m.X(), m.Y()
		if x >= mx && x < mx+m.LogicalWidth() && y >= my && y < my+m.LogicalHeight() {
			return m, true
		}
	}
	return nil, false
}
