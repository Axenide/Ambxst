package compositor

import (
	"strings"
	"testing"
)

// TestRenderMatchesCurrentAxctlToml feeds a hand-crafted input that mirrors
// the real ~/.config/ambxst configuration and asserts the rendered output
// contains every meaningful key=value pair that ships in the current
// axctl.toml. It's a structural parity check, not byte-for-byte: the QML
// writer had hand-rolled quirks (e.g. mixed line spacing) that we don't
// reproduce.
func TestRenderMatchesCurrentAxctlToml(t *testing.T) {
	in := realishInput()
	out := Render(in)

	// Spot-check the structural keys that the QML writer always emits.
	// If any of these drift, the daemon-side parser or axctl's TOML
	// loader will break.
	required := []string{
		"[target]\nhyprland = \"hyprland.lua\"\n",
		"niri = \"niri.kdl\"\n",
		"mango = \"mango.conf\"\n",
		"[startup]\nexec-once = \"ambxst\"\n",
		"[appearance.gaps]\ninner = 2\nouter = 4\n",
		"[appearance.border]\nwidth = 2\n",
		"[appearance.shadow]\nenabled = true\nsize = 8\n",
		"[appearance.animations]\nenabled = true\n",
		"[appearance.blur]\nenabled = true\nsize = 4\npasses = 2\n",
		"[general]\nlayout = \"scrolling\"\n",
		"[[keybinds]]\nmodifiers = [\"SUPER\"]\nkey = \"Super_L\"",
		"argument = \"ambxst run launcher\"",
		"dispatcher = \"killactive\"",
		"namespace = \"quickshell\"\nno_anim = true",
		"namespace = \"fabric\"\nblur = true\nignore_alpha_value = 0.4",
		"namespace = \"ambxst\"\nblur = true\nblur_popups = true\nno_anim = true\nignore_alpha_value = 0.5",
		"[input]\n[input.keyboard]\nlayouts = \"\"\nvariants = \"\"\n",
	}
	for _, want := range required {
		if !strings.Contains(out, want) {
			t.Errorf("missing required fragment %q in rendered TOML:\n---\n%s---", want, out)
		}
	}
}

// realishInput mirrors the actual ~/.config/ambxst data shape: gaps 2/4,
// border 2, rounding 16, layout "scrolling", a handful of core binds,
// and a representative custom bind set.
func realishInput() Input {
	return Input{
		Compositor: CompositorConfig{
			GapsIn:    2,
			GapsOut:   4,
			BorderSize: 2,
			Rounding:  16,
			ActiveBorderColor:   []string{"primary"},
			ActiveBorderAngle:   45,
			InactiveBorderColor: []string{"surface"},
			InactiveBorderAngle: 45,
			Shadow: ShadowConfig{
				Enabled: true, Range: 8, RenderPower: 3, IgnoreWindow: true,
				Color: "shadow", ColorInactive: "shadow", Opacity: 0.5,
				Offset: "0 0", Scale: 1.0,
			},
			Blur: BlurConfig{
				Enabled: true, Size: 4, Passes: 2,
				IgnoreOpacity: true, IgnoreAlphaValue: 0.2,
				NewOptimizations: true, Contrast: 1.0, Brightness: 1.0,
				Special: true, Vibrancy: 0.0, VibrancyDarkness: 0.0,
			},
			Animations: Animations{Enabled: true},
		},
		Theme:  ThemeConfig{SrBgOpacity: 1.0, SrBarBgOpacity: 0.0, ShadowColor: "#00000080", ShadowOpacity: 0.5},
		Bar:    BarConfig{Position: "top"},
		Layout: "scrolling",
		Keybinds: KeybindsConfig{
			Ambxst: map[string]Keybind{
				"launcher":  {Modifiers: []string{"SUPER"}, Key: "Super_L", Action: Action{ID: "ambxst.launcher"}},
				"dashboard": {Modifiers: []string{"SUPER"}, Key: "D", Action: Action{ID: "ambxst.dashboard"}},
			},
			System: map[string]Keybind{
				"overview": {Modifiers: []string{"SUPER"}, Key: "TAB", Action: Action{ID: "ambxst.overview"}},
			},
			Custom: []CustomBind{
				{
					Name: "Close Window",
					Keys: []KeySpec{{Modifiers: []string{"SUPER"}, Key: "C"}},
					Actions: []Action{{ID: "window.close"}},
					Enabled: true,
				},
			},
		},
	}
}
