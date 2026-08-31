package axmon

import "testing"

func testMonitors() []Monitor {
	return []Monitor{
		{Name: "DP-1", Width: 1920, Height: 1080, Scale: 1.25, IsFocused: true,
			Metadata: map[string]interface{}{"x": float64(0), "y": float64(0), "transform": float64(0)}},
		{Name: "HDMI-A-1", Width: 1080, Height: 1920, Scale: 2,
			Metadata: map[string]interface{}{"x": float64(1920), "y": float64(100), "transform": float64(1)}},
	}
}

func TestGeometryAccessors(t *testing.T) {
	ms := testMonitors()
	m := ms[1]
	if m.X() != 1920 || m.Y() != 100 {
		t.Fatalf("position: got %d,%d", m.X(), m.Y())
	}
	if m.Transform() != 1 {
		t.Fatalf("transform: got %d", m.Transform())
	}
	if m.EffectiveScale() != 2 {
		t.Fatalf("scale: got %v", m.EffectiveScale())
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
	m, ok := FindByName(ms, "HDMI-A-1")
	if !ok || m.Scale != 2 {
		t.Fatalf("find failed: %v %v", ok, m)
	}
	if _, ok := FindByName(ms, "missing"); ok {
		t.Fatal("expected miss")
	}
}

func TestFocused(t *testing.T) {
	ms := testMonitors()
	m, ok := Focused(ms)
	if !ok || m.Name != "DP-1" {
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
		{960, 540, "DP-1"},
		{2000, 200, "HDMI-A-1"},
		{1919, 1079, "DP-1"},
		{-50, -50, ""},
		{5000, 5000, ""},
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
