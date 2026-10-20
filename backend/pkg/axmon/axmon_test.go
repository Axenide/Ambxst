package axmon

import "testing"

// Fixtures mirror live `axctl monitor list` from a scale-2 eDP-2
// (2880x1800 physical → 1440x900 logical) next to a scale-1 DP-2.
// Width/height are physical pixels, x/y are logical pixels, and current
// axctl reports the explicit logical extents.
func testMonitors() []Monitor {
	return []Monitor{
		{Name: "eDP-2", Width: 2880, Height: 1800, LogicalW: 1440, LogicalH: 900, Scale: 2, IsFocused: true,
			Metadata: map[string]interface{}{"x": float64(0), "y": float64(0), "transform": float64(0)}},
		{Name: "DP-2", Width: 1920, Height: 1080, LogicalW: 1920, LogicalH: 1080, Scale: 1,
			Metadata: map[string]interface{}{"x": float64(1440), "y": float64(0), "transform": float64(0)}},
	}
}

// Rotated output: Hyprland reports the transformed (swapped) physical
// size and logical extents divide by scale the same way.
func rotatedMonitor() Monitor {
	return Monitor{Name: "HDMI-A-1", Width: 1080, Height: 1920, LogicalW: 540, LogicalH: 960, Scale: 2,
		Metadata: map[string]interface{}{"x": float64(3360), "y": float64(0), "transform": float64(1)}}
}

// Legacy fixture: pre-logical-field axctl on niri already reports
// width/height in logical pixels; accessors must fall back to raw
// width/height so behavior is unchanged against old axctl.
func legacyMonitors() []Monitor {
	return []Monitor{
		{Name: "DP-1", Width: 1440, Height: 900, Scale: 2, IsFocused: true,
			Metadata: map[string]interface{}{"x": float64(0), "y": float64(0), "transform": float64(0)}},
		{Name: "DP-2", Width: 1920, Height: 1080, Scale: 1,
			Metadata: map[string]interface{}{"x": float64(1440), "y": float64(0), "transform": float64(0)}},
	}
}

func TestGeometryAccessors(t *testing.T) {
	ms := testMonitors()
	m := ms[1]
	if m.X() != 1440 || m.Y() != 0 {
		t.Fatalf("position: got %d,%d", m.X(), m.Y())
	}
	if m.Transform() != 0 {
		t.Fatalf("transform: got %d", m.Transform())
	}
	if m.EffectiveScale() != 1 {
		t.Fatalf("scale: got %v", m.EffectiveScale())
	}
}

func TestLogicalSizeAccessors(t *testing.T) {
	ms := testMonitors()
	if w, h := ms[0].LogicalWidth(), ms[0].LogicalHeight(); w != 1440 || h != 900 {
		t.Fatalf("eDP-2 logical: got %dx%d want 1440x900", w, h)
	}
	if w, h := ms[1].LogicalWidth(), ms[1].LogicalHeight(); w != 1920 || h != 1080 {
		t.Fatalf("DP-2 logical: got %dx%d want 1920x1080", w, h)
	}
	r := rotatedMonitor()
	if w, h := r.LogicalWidth(), r.LogicalHeight(); w != 540 || h != 960 {
		t.Fatalf("rotated logical: got %dx%d want 540x960", w, h)
	}
}

func TestLogicalSizeLegacyFallback(t *testing.T) {
	ms := legacyMonitors()
	if w, h := ms[0].LogicalWidth(), ms[0].LogicalHeight(); w != 1440 || h != 900 {
		t.Fatalf("legacy logical: got %dx%d want 1440x900", w, h)
	}
	if w, h := ms[1].LogicalWidth(), ms[1].LogicalHeight(); w != 1920 || h != 1080 {
		t.Fatalf("legacy scale-1 logical: got %dx%d want 1920x1080", w, h)
	}
}

func TestEffectiveScaleFallback(t *testing.T) {
	m := Monitor{Name: "eDP-1", Scale: 0}
	if m.EffectiveScale() != 1.0 {
		t.Fatalf("expected 1.0 fallback, got %v", m.EffectiveScale())
	}
}

func TestFindByName(t *testing.T) {
	ms := testMonitors()
	m, ok := FindByName(ms, "DP-2")
	if !ok || m.Scale != 1 {
		t.Fatalf("find failed: %v %v", ok, m)
	}
	if _, ok := FindByName(ms, "missing"); ok {
		t.Fatal("expected miss")
	}
}

func TestFocused(t *testing.T) {
	ms := testMonitors()
	m, ok := Focused(ms)
	if !ok || m.Name != "eDP-2" {
		t.Fatalf("focused: %v %v", ok, m)
	}
	none := []Monitor{{Name: "A"}, {Name: "B"}}
	if m, _ := Focused(none); m.Name != "A" {
		t.Fatalf("fallback expected first, got %s", m.Name)
	}
}

func TestContaining(t *testing.T) {
	ms := testMonitors()
	cases := []struct {
		x, y int
		want string
	}{
		{720, 450, "eDP-2"},
		{2000, 500, "DP-2"},
		{1439, 899, "eDP-2"},
		// Boundary: DP-2 starts at logical x=1440. With raw physical
		// extents (0+2880) this point wrongly resolved to eDP-2.
		{1440, 0, "DP-2"},
		{1440, 899, "DP-2"},
		{0, 0, "eDP-2"},
		{-50, -50, ""},
		{5000, 5000, ""},
		{1439, 900, ""},
	}
	for _, c := range cases {
		m, ok := Containing(ms, c.x, c.y)
		got := ""
		if ok {
			got = m.Name
		}
		if got != c.want {
			t.Fatalf("Containing(%d,%d): got %q want %q", c.x, c.y, got, c.want)
		}
	}
}

func TestContainingRotated(t *testing.T) {
	ms := append(testMonitors(), rotatedMonitor())
	m, ok := Containing(ms, 3600, 480)
	if !ok || m.Name != "HDMI-A-1" {
		t.Fatalf("Containing(3600,480): got %v %v", m, ok)
	}
	// Rotated logical extents cap at y=960; deeper points must not leak
	// into the rotated output.
	if _, ok := Containing(ms, 3600, 1000); ok {
		t.Fatal("point below rotated extent should not resolve")
	}
}

func TestContainingLegacyFallback(t *testing.T) {
	ms := legacyMonitors()
	cases := []struct {
		x, y int
		want string
	}{
		{720, 450, "DP-1"},
		{2000, 500, "DP-2"},
		{1439, 899, "DP-1"},
		{1440, 0, "DP-2"},
	}
	for _, c := range cases {
		m, ok := Containing(ms, c.x, c.y)
		got := ""
		if ok {
			got = m.Name
		}
		if got != c.want {
			t.Fatalf("legacy Containing(%d,%d): got %q want %q", c.x, c.y, got, c.want)
		}
	}
}
