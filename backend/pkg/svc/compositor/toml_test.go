package compositor

import (
	"strings"
	"testing"
)

func sampleInput() Input {
	return Input{
		Compositor: CompositorConfig{
			GapsIn:              2,
			GapsOut:             4,
			BorderSize:          2,
			Rounding:            16,
			SyncBorderColor:     false,
			BorderColor:         "primary",
			ActiveBorderColor:   []string{"primary"},
			ActiveBorderAngle:   45,
			InactiveBorderColor: []string{"surface"},
			InactiveBorderAngle: 45,
			Shadow: ShadowConfig{
				Enabled:       true,
				Range:         8,
				RenderPower:   3,
				Sharp:         false,
				IgnoreWindow:  true,
				Color:         "shadow",
				ColorInactive: "shadow",
				Opacity:       0.5,
				Offset:        "0 0",
				Scale:         1.0,
			},
			Blur: BlurConfig{
				Enabled:                 true,
				Size:                    4,
				Passes:                  2,
				IgnoreOpacity:           true,
				ExplicitIgnoreAlpha:     false,
				IgnoreAlphaValue:        0.2,
				NewOptimizations:        true,
				Xray:                    false,
				Noise:                   0.0,
				Contrast:                1.0,
				Brightness:              1.0,
				Vibrancy:                0.0,
				VibrancyDarkness:        0.0,
				Special:                 true,
				Popups:                  false,
				PopupsIgnorealpha:       0.2,
				InputMethods:            false,
				InputMethodsIgnorealpha: 0.2,
			},
			Animations: Animations{Enabled: true},
		},
		Theme: ThemeConfig{
			SrBarBgOpacity: 0.0,
			SrBgOpacity:    1.0,
			ShadowColor:    "#00000080",
			ShadowOpacity:  0.5,
		},
		Bar:    BarConfig{Position: "top"},
		Layout: "dwindle",
		Keybinds: KeybindsConfig{
			Ambxst: map[string]Keybind{
				"launcher":  {Modifiers: []string{"SUPER"}, Key: "Super_L", Action: Action{ID: "ambxst.launcher"}},
				"dashboard": {Modifiers: []string{"SUPER"}, Key: "D", Action: Action{ID: "ambxst.dashboard"}},
			},
			System: map[string]Keybind{
				"overview": {Modifiers: []string{"SUPER"}, Key: "TAB", Action: Action{ID: "ambxst.overview"}},
				"reload":   {Modifiers: []string{"SUPER", "ALT"}, Key: "B", Action: Action{ID: "ambxst.reload"}},
			},
			Custom: []CustomBind{
				{
					Name: "Close Window",
					Keys: []KeySpec{{Modifiers: []string{"SUPER"}, Key: "C"}},
					Actions: []Action{
						{ID: "window.close", Layouts: nil},
					},
					Enabled: true,
				},
				{
					Name: "Workspace 1",
					Keys: []KeySpec{{Modifiers: []string{"SUPER"}, Key: "1"}},
					Actions: []Action{
						{ID: "workspace.switch", Args: map[string]any{"index": "1"}, Layouts: nil},
					},
					Enabled: true,
				},
				{
					Name: "Layout-gated bind",
					Keys: []KeySpec{{Modifiers: []string{"SUPER"}, Key: "G"}},
					Actions: []Action{
						{ID: "ambxst.dashboard", Layouts: []string{"master"}},
					},
					Enabled: true,
				},
			},
		},
	}
}

func TestRenderTopLevelSections(t *testing.T) {
	out := Render(sampleInput())
	for _, section := range []string{"[target]", "[startup]", "[appearance]", "[general]", "[input]"} {
		if !strings.Contains(out, section) {
			t.Errorf("missing section %q in rendered TOML:\n%s", section, out)
		}
	}
}

func TestRenderTargetFirst(t *testing.T) {
	out := Render(sampleInput())
	targetIdx := strings.Index(out, "[target]")
	startupIdx := strings.Index(out, "[startup]")
	if targetIdx == -1 || startupIdx == -1 {
		t.Fatalf("missing [target] or [startup]:\n%s", out)
	}
	if targetIdx > startupIdx {
		t.Errorf("[target] should appear before [startup]; got target=%d startup=%d", targetIdx, startupIdx)
	}
}

func TestRenderHyprlandTarget(t *testing.T) {
	out := Render(sampleInput())
	want := `hyprland = "~/.local/share/ambxst/hyprland.lua"`
	if !strings.Contains(out, want) {
		t.Errorf("missing target line %q in:\n%s", want, out)
	}
}

func TestRenderLayoutSection(t *testing.T) {
	out := Render(sampleInput())
	if !strings.Contains(out, `[general]`) || !strings.Contains(out, `layout = "dwindle"`) {
		t.Errorf("missing [general] layout block:\n%s", out)
	}
}

func TestRenderSkipsLayoutWhenEmpty(t *testing.T) {
	in := sampleInput()
	in.Layout = ""
	out := Render(in)
	if strings.Contains(out, "[general]") {
		t.Errorf("expected no [general] block when layout is empty, got:\n%s", out)
	}
}

func TestRenderCoreBindsAppear(t *testing.T) {
	out := Render(sampleInput())
	mustContain := []string{
		`key = "Super_L"`,
		`key = "D"`,
		`key = "TAB"`,
		`key = "B"`,
		`dispatcher = "exec"`,
		`argument = "ambxst run launcher"`,
		`argument = "ambxst run dashboard"`,
		`argument = "ambxst run overview"`,
		`argument = "ambxst reload"`,
	}
	for _, want := range mustContain {
		if !strings.Contains(out, want) {
			t.Errorf("missing %q in:\n%s", want, out)
		}
	}
}

func TestRenderCustomBindsAppear(t *testing.T) {
	out := Render(sampleInput())
	mustContain := []string{
		`key = "C"`,
		`dispatcher = "killactive"`,
		`key = "1"`,
		`dispatcher = "workspace"`,
		`argument = "1"`,
	}
	for _, want := range mustContain {
		if !strings.Contains(out, want) {
			t.Errorf("missing %q in:\n%s", want, out)
		}
	}
}

func TestRenderLayoutGatedBindExcluded(t *testing.T) {
	out := Render(sampleInput())
	// The "G" bind is gated to master, but the active layout is dwindle,
	// so it should be filtered out.
	if strings.Contains(out, `key = "G"`) {
		t.Errorf("layout-gated bind should be filtered out for dwindle layout:\n%s", out)
	}
}

func TestRenderLayoutGatedBindIncluded(t *testing.T) {
	in := sampleInput()
	in.Layout = "master"
	out := Render(in)
	if !strings.Contains(out, `key = "G"`) {
		t.Errorf("layout-gated bind should appear for master layout:\n%s", out)
	}
}

func TestRenderCustomBindDisabled(t *testing.T) {
	in := sampleInput()
	in.Keybinds.Custom[0].Enabled = false
	out := Render(in)
	// The disabled custom bind "Close Window" has key C. Confirm it's
	// absent while core ambxst binds (which also use SUPER+C patterns
	// elsewhere) remain present.
	closeLines := 0
	for _, line := range strings.Split(out, "\n") {
		if strings.Contains(line, `key = "C"`) {
			closeLines++
		}
	}
	if closeLines != 0 {
		t.Errorf("disabled custom bind should be skipped, found %d 'key = \"C\"' lines", closeLines)
	}
}

func TestRenderLayerRules(t *testing.T) {
	out := Render(sampleInput())
	for _, want := range []string{
		`namespace = "quickshell"`,
		`namespace = "overview"`,
		`namespace = "presets"`,
		`namespace = "fabric"`,
		`ignore_alpha_value = 0.4`,
		`ignore_alpha_value = 0.5`,
	} {
		if !strings.Contains(out, want) {
			t.Errorf("missing %q in layer rules:\n%s", want, out)
		}
	}
}

func TestRenderModifiersArray(t *testing.T) {
	out := Render(sampleInput())
	// The reload bind is SUPER+ALT; the rendering must produce an array.
	if !strings.Contains(out, `modifiers = ["SUPER", "ALT"]`) {
		t.Errorf("missing multi-modifier array form:\n%s", out)
	}
}

func TestRenderEmptyModifiers(t *testing.T) {
	in := sampleInput()
	in.Keybinds.Ambxst["launcher"] = Keybind{Modifiers: nil, Key: "Space", Action: Action{ID: "ambxst.launcher"}}
	out := Render(in)
	if !strings.Contains(out, `modifiers = []`) {
		t.Errorf("empty modifiers should render as []:\n%s", out)
	}
}

func TestRenderIgnoresUnknownAction(t *testing.T) {
	in := sampleInput()
	in.Keybinds.Ambxst["launcher"] = Keybind{Modifiers: []string{"SUPER"}, Key: "Z", Action: Action{ID: "no.such.action"}}
	out := Render(in)
	if strings.Contains(out, `key = "Z"`) {
		t.Errorf("unresolvable action should be dropped:\n%s", out)
	}
}

func TestRenderIgnoresEmptyKey(t *testing.T) {
	in := sampleInput()
	in.Keybinds.Ambxst["launcher"] = Keybind{Modifiers: []string{"SUPER"}, Key: "", Action: Action{ID: "ambxst.launcher"}}
	out := Render(in)
	if strings.Contains(out, "Super_L") {
		t.Errorf("empty-key bind should be dropped; Super_L leaked:\n%s", out)
	}
}

func TestNormalizeKeybindDispatcher(t *testing.T) {
	cases := []struct{ d, a, wd, wa string }{
		{"layoutmsg", "focus u", "movefocus", "u"},
		{"layoutmsg", "movewindowto d", "movewindow", "d"},
		{"layoutmsg", "colresize +0.1", "layoutmsg", "colresize +0.1"},
		{"movefocus", "l", "movefocus", "l"},
	}
	for _, c := range cases {
		gd, ga := normalizeKeybindDispatcher(c.d, c.a)
		if gd != c.wd || ga != c.wa {
			t.Errorf("normalizeKeybindDispatcher(%q,%q) = (%q,%q), want (%q,%q)", c.d, c.a, gd, ga, c.wd, c.wa)
		}
	}
}

func TestActionCompatibleWithLayout(t *testing.T) {
	if !actionCompatibleWithLayout(Action{Layouts: nil}, "dwindle") {
		t.Error("empty layouts should be compatible with everything")
	}
	if !actionCompatibleWithLayout(Action{Layouts: []string{"dwindle"}}, "dwindle") {
		t.Error("dwindle should match")
	}
	if actionCompatibleWithLayout(Action{Layouts: []string{"master"}}, "dwindle") {
		t.Error("master-only should not match dwindle")
	}
}

func TestEscapesSpecialChars(t *testing.T) {
	out := tomlEscape(`hi"world\foo` + "\nbar")
	want := `hi\"world\\foo\nbar`
	if out != want {
		t.Fatalf("got %q want %q", out, want)
	}
}
