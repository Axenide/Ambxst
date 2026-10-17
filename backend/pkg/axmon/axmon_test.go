package axmon

import "testing"

// Fixtures mirror live `axctl monitor list`: width/height are PHYSICAL
// pixels, x/y are LOGICAL pixels (2880-wide scale-2 output followed by
// the next output at x=1440, i.e. 2880/2).
func testMonitors() []Monitor {
	return []Monitor{
		{Name: "eDP-2", Width: 2880, Height: 1800, Scale: 2, IsFocused: true,
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

func TestLogicalSize(t *testing.T) {
	ms := testMonitors()
	if w, h := ms[0].LogicalWidth(), ms[0].LogicalHeight(); w != 1440 || h != 900 {
		t.Fatalf("eDP-2 logical: got %dx%d want 1440x900", w, h)
	}
	if w, h := ms[1].LogicalWidth(), ms[1].LogicalHeight(); w != 1920 || h != 1080 {
		t.Fatalf("DP-2 logical: got %dx%d want 1920x1080", w, h)
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
