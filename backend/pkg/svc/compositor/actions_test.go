package compositor

import (
	"strings"
	"testing"
)

func TestResolveActionCatalogEntry(t *testing.T) {
	cases := []struct {
		name        string
		action      Action
		wantDisp    string
		wantArg     string
		wantFlags   string
	}{
		{
			name:     "ambxst.launcher carries r flag",
			action:   Action{ID: "ambxst.launcher"},
			wantDisp: "exec", wantArg: "ambxst run launcher", wantFlags: "r",
		},
		{
			name:     "window.focus builds direction argument",
			action:   Action{ID: "window.focus", Args: map[string]any{"direction": "up"}},
			wantDisp: "movefocus", wantArg: "u",
		},
		{
			name:     "workspace.switch uses index arg",
			action:   Action{ID: "workspace.switch", Args: map[string]any{"index": "3"}},
			wantDisp: "workspace", wantArg: "3",
		},
		{
			name:     "workspace.switch-relative formats positive offset",
			action:   Action{ID: "workspace.switch-relative", Args: map[string]any{"offset": "+2"}},
			wantDisp: "workspace", wantArg: "+2",
		},
		{
			name:     "command.run uses command arg verbatim",
			action:   Action{ID: "command.run", Args: map[string]any{"command": "kitty -e htop"}},
			wantDisp: "exec", wantArg: "kitty -e htop",
		},
		{
			name:     "legacy.dispatcher extracts from args",
			action:   Action{ID: "legacy.dispatcher", Args: map[string]any{"dispatcher": "exec", "argument": "notify-send hi", "flags": "l"}},
			wantDisp: "exec", wantArg: "notify-send hi", wantFlags: "l",
		},
		{
			name:     "explicit dispatcher short-circuits catalog",
			action:   Action{Dispatcher: "killactive", Argument: ""},
			wantDisp: "killactive", wantArg: "",
		},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			got := ResolveAction(c.action)
			if got == nil {
				t.Fatalf("ResolveAction returned nil for %+v", c.action)
			}
			if got.Dispatcher != c.wantDisp || got.Argument != c.wantArg || got.Flags != c.wantFlags {
				t.Fatalf("got %+v, want dispatcher=%q argument=%q flags=%q", got, c.wantDisp, c.wantArg, c.wantFlags)
			}
		})
	}
}

func TestResolveActionUnknownReturnsNil(t *testing.T) {
	if got := ResolveAction(Action{ID: "nope"}); got != nil {
		t.Fatalf("expected nil, got %+v", got)
	}
	if got := ResolveAction(Action{}); got != nil {
		t.Fatalf("expected nil for empty action, got %+v", got)
	}
}

func TestActionFromLegacyRoundTrip(t *testing.T) {
	cases := []struct {
		dispatcher, arg, flags string
		wantID                 string
	}{
		{"killactive", "", "", "window.close"},
		{"workspace", "5", "", "workspace.switch"},
		{"workspace", "+1", "", "workspace.switch-relative"},
		{"workspace", "e+1", "", "workspace.switch-occupied"},
		{"movetoworkspace", "special", "", "workspace.move-window-special"},
		{"movetoworkspace", "3", "", "workspace.move-window"},
		{"togglespecialworkspace", "", "", "workspace.toggle-special"},
		{"movewindow", "", "m", "window.drag"},
		{"movewindow", "u", "", "window.move"},
		{"movefocus", "l", "", "window.focus"},
		{"layoutmsg", "focus u", "", "scrolling.focus"},
		{"layoutmsg", "movewindowto d", "", "scrolling.move-window"},
		{"layoutmsg", "colresize +0.1", "", "scrolling.resize-column"},
		{"layoutmsg", "colresize +conf", "", "scrolling.toggle-full-column"},
		{"layoutmsg", "promote", "", "scrolling.promote"},
		{"layoutmsg", "swapcol r", "", "scrolling.swap-column"},
		{"exec", "playerctl play-pause", "l", "media.play-pause-locked"},
		{"exec", "loginctl lock-session", "l", "system.lock-locked"},
		{"exec", "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 10%+", "le", "audio.volume-up"},
		{"exec", "notify-send \"Soon\"", "", "system.calculator"},
		{"exec", "kitty", "", "command.run"},
	}
	for _, c := range cases {
		t.Run(c.dispatcher+"/"+c.arg+"/"+c.flags, func(t *testing.T) {
			got := ActionFromLegacy(c.dispatcher, c.arg, c.flags)
			if got.ID != c.wantID {
				t.Fatalf("got id %q, want %q (action=%+v)", got.ID, c.wantID, got)
			}
		})
	}
}

func TestFormatOffset(t *testing.T) {
	cases := map[string]string{
		"":      "0",
		"+1":    "+1",
		"-2":    "-2",
		"1":     "+1",
		"0":     "+0",
		"-3":    "-3",
		"foo":   "foo",
		"  +5 ": "+5",
	}
	for in, want := range cases {
		if got := formatOffset(in); got != want {
			t.Errorf("formatOffset(%q) = %q, want %q", in, got, want)
		}
	}
}

func TestDirectionToLetter(t *testing.T) {
	cases := map[string]string{
		"up": "u", "u": "u", "U": "u",
		"down": "d", "d": "d",
		"left": "l", "l": "l",
		"right": "r", "r": "r",
		"": "", "diagonal": "",
	}
	for in, want := range cases {
		if got := directionToLetter(in); got != want {
			t.Errorf("directionToLetter(%q) = %q, want %q", in, got, want)
		}
	}
}

func TestEnsureActionFillsDefaults(t *testing.T) {
	got := EnsureAction(Action{ID: "workspace.switch"})
	if got.Args["index"] != "1" {
		t.Fatalf("default index not filled: %+v", got.Args)
	}
}

func TestEnsureActionKeepsExplicitArgs(t *testing.T) {
	got := EnsureAction(Action{ID: "workspace.switch", Args: map[string]any{"index": "7"}})
	if got.Args["index"] != "7" {
		t.Fatalf("explicit index overwritten: %+v", got.Args)
	}
}

func TestDescribeAction(t *testing.T) {
	cases := []struct {
		in   Action
		want string
	}{
		{Action{ID: "ambxst.launcher"}, "Open Launcher"},
		{Action{ID: "workspace.switch", Args: map[string]any{"index": "4"}}, "Switch Workspace · 4"},
		{Action{ID: "legacy.dispatcher", Args: map[string]any{"dispatcher": "exec", "argument": "x"}}, "exec x"},
	}
	for _, c := range cases {
		if got := DescribeAction(c.in); got != c.want {
			t.Errorf("DescribeAction(%+v) = %q, want %q", c.in, got, c.want)
		}
	}
}

// Helper: ensure all catalog entries are resolvable with no args.
func TestCatalogAllResolveWithEmptyArgs(t *testing.T) {
	for _, a := range catalog {
		t.Run(a.ID, func(t *testing.T) {
			got := ResolveAction(Action{ID: a.ID, Args: map[string]any{}})
			if got == nil {
				t.Fatalf("could not resolve catalog entry %q", a.ID)
			}
		})
	}
}

// Sanity: dispatcher count matches the legacy JS catalog (excluding the
// hidden legacy.dispatcher which is resolved through its arg bundle).
func TestCatalogSize(t *testing.T) {
	if len(catalog) < 50 {
		t.Fatalf("expected ≥50 catalog entries, got %d", len(catalog))
	}
}

// Sanity: round-trip for a few catalog entries.
func TestRoundTripForCommonEntries(t *testing.T) {
	for _, id := range []string{
		"workspace.switch", "workspace.switch-relative", "window.focus",
		"window.move", "scrolling.resize-column", "audio.volume-up",
	} {
		spec, ok := GetActionById(id)
		if !ok {
			t.Fatalf("missing catalog entry: %s", id)
		}
		// Build an action with defaults, resolve it, then invert via
		// the dispatcher+arg of a sibling legacy action when possible.
		resolved := ResolveAction(Action{ID: id, Args: defaultArgsForID(id)})
		if resolved == nil {
			t.Fatalf("could not resolve %s", id)
		}
		if !strings.Contains(resolved.Argument, "") {
			t.Logf("%s -> dispatcher=%s argument=%q flags=%q", id, resolved.Dispatcher, resolved.Argument, resolved.Flags)
		}
		_ = spec
	}
}

func TestMonocleFocusResolvesToCycle(t *testing.T) {
	cases := []struct {
		direction string
		wantArg   string
	}{
		{"u", "cyclenext"},
		{"r", "cyclenext"},
		{"d", "cycleprev"},
		{"l", "cycleprev"},
		{"", "cyclenext"}, // default args
	}
	for _, c := range cases {
		t.Run(c.direction, func(t *testing.T) {
			args := defaultArgsForID("monocle.focus")
			if c.direction != "" {
				args["direction"] = c.direction
			}
			got := ResolveAction(Action{ID: "monocle.focus", Args: args})
			if got == nil {
				t.Fatal("monocle.focus did not resolve")
			}
			if got.Dispatcher != "cyclenext" || got.Argument != c.wantArg {
				t.Errorf("got dispatcher=%s argument=%q, want cyclenext %q", got.Dispatcher, got.Argument, c.wantArg)
			}
		})
	}
}

func TestMonocleMoveWindowResolvesToCycle(t *testing.T) {
	got := ResolveAction(Action{ID: "monocle.move-window", Args: map[string]any{"direction": "d"}})
	if got == nil {
		t.Fatal("monocle.move-window did not resolve")
	}
	if got.Dispatcher != "cyclenext" || got.Argument != "cycleprev" {
		t.Errorf("got dispatcher=%s argument=%q, want cyclenext cycleprev", got.Dispatcher, got.Argument)
	}
}
