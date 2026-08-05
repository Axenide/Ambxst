package compositor

import (
	"fmt"
	"strings"
)

// ActionSpec is the catalog entry that maps an action id to a Hyprland
// dispatcher/argument/flags triple. Args are evaluated by the builder to
// produce the final argument string at resolution time.
//
// This is a direct port of config/KeybindActions.js. The QML BindsPanel
// still consults the JS file for UI; this Go copy is used solely by the
// TOML renderer.
type ActionSpec struct {
	ID          string
	Label       string
	Category    string
	Dispatcher  string
	Argument    string
	Flags       string
	Args        []ActionArg
	ArgumentFn  func(args map[string]any) string
	Hidden      bool
}

type ActionArg struct {
	Key          string
	Label        string
	Placeholder  string
	DefaultValue string
}

// Resolved captures the final dispatcher call after running the
// argument builder.
type Resolved struct {
	Dispatcher string
	Argument   string
	Flags      string
}

// catalog is a 1:1 port of ACTION_CATALOG from KeybindActions.js.
var catalog = []ActionSpec{
	{ID: "ambxst.launcher", Label: "Open Launcher", Category: "Ambxst", Dispatcher: "exec", Argument: "ambxst run launcher", Flags: "r"},
	{ID: "ambxst.dashboard", Label: "Open Dashboard", Category: "Ambxst", Dispatcher: "exec", Argument: "ambxst run dashboard"},
	{ID: "ambxst.assistant", Label: "Open Assistant", Category: "Ambxst", Dispatcher: "exec", Argument: "ambxst run assistant"},
	{ID: "ambxst.clipboard", Label: "Open Clipboard", Category: "Ambxst", Dispatcher: "exec", Argument: "ambxst run clipboard"},
	{ID: "ambxst.emoji", Label: "Open Emoji", Category: "Ambxst", Dispatcher: "exec", Argument: "ambxst run emoji"},
	{ID: "ambxst.notes", Label: "Open Notes", Category: "Ambxst", Dispatcher: "exec", Argument: "ambxst run notes"},
	{ID: "ambxst.tmux", Label: "Open Tmux", Category: "Ambxst", Dispatcher: "exec", Argument: "ambxst run tmux"},
	{ID: "ambxst.wallpapers", Label: "Open Wallpapers", Category: "Ambxst", Dispatcher: "exec", Argument: "ambxst run wallpapers"},
	{ID: "ambxst.config", Label: "Open Settings", Category: "Ambxst", Dispatcher: "exec", Argument: "ambxst run config"},
	{ID: "ambxst.overview", Label: "Open Overview", Category: "Ambxst", Dispatcher: "exec", Argument: "ambxst run overview"},
	{ID: "ambxst.powermenu", Label: "Open Power Menu", Category: "Ambxst", Dispatcher: "exec", Argument: "ambxst run powermenu"},
	{ID: "ambxst.tools", Label: "Open Tools", Category: "Ambxst", Dispatcher: "exec", Argument: "ambxst run tools"},
	{ID: "ambxst.screenshot", Label: "Take Screenshot", Category: "Ambxst", Dispatcher: "exec", Argument: "ambxst run screenshot"},
	{ID: "ambxst.screenrecord", Label: "Screen Record", Category: "Ambxst", Dispatcher: "exec", Argument: "ambxst run screenrecord"},
	{ID: "ambxst.lens", Label: "Open Lens", Category: "Ambxst", Dispatcher: "exec", Argument: "ambxst run lens"},
	{ID: "ambxst.reload", Label: "Reload Ambxst", Category: "Ambxst", Dispatcher: "exec", Argument: "ambxst reload"},
	{ID: "ambxst.quit", Label: "Quit Ambxst", Category: "Ambxst", Dispatcher: "exec", Argument: "ambxst quit"},

	{ID: "window.close", Label: "Close Window", Category: "Window", Dispatcher: "killactive", Argument: ""},
	{ID: "window.focus", Label: "Focus Window", Category: "Window", Dispatcher: "movefocus", Args: []ActionArg{{Key: "direction", Label: "Direction", Placeholder: "up/down/left/right", DefaultValue: "up"}}, ArgumentFn: func(args map[string]any) string { return directionToLetter(stringArg(args, "direction")) }},
	{ID: "window.move", Label: "Move Window", Category: "Window", Dispatcher: "movewindow", Args: []ActionArg{{Key: "direction", Label: "Direction", Placeholder: "up/down/left/right", DefaultValue: "left"}}, ArgumentFn: func(args map[string]any) string { return directionToLetter(stringArg(args, "direction")) }},
	{ID: "window.drag", Label: "Drag Window", Category: "Window", Dispatcher: "movewindow", Argument: "", Flags: "m"},
	{ID: "window.resize-drag", Label: "Resize Window (Drag)", Category: "Window", Dispatcher: "resizewindow", Argument: "", Flags: "m"},
	{ID: "window.resize", Label: "Resize Window", Category: "Window", Dispatcher: "resizeactive", Args: []ActionArg{{Key: "delta", Label: "Delta", Placeholder: "50 0", DefaultValue: "50 0"}}, ArgumentFn: func(args map[string]any) string { return strings.TrimSpace(stringArg(args, "delta")) }},

	{ID: "workspace.switch", Label: "Switch Workspace", Category: "Workspace", Dispatcher: "workspace", Args: []ActionArg{{Key: "index", Label: "Workspace", Placeholder: "1", DefaultValue: "1"}}, ArgumentFn: func(args map[string]any) string { return strings.TrimSpace(stringArg(args, "index")) }},
	{ID: "workspace.switch-relative", Label: "Switch Workspace (Relative)", Category: "Workspace", Dispatcher: "workspace", Args: []ActionArg{{Key: "offset", Label: "Offset", Placeholder: "+1 / -1", DefaultValue: "+1"}}, ArgumentFn: func(args map[string]any) string { return formatOffset(stringArg(args, "offset")) }},
	{ID: "workspace.switch-occupied", Label: "Switch Occupied Workspace", Category: "Workspace", Dispatcher: "workspace", Args: []ActionArg{{Key: "offset", Label: "Offset", Placeholder: "+1 / -1", DefaultValue: "+1"}}, ArgumentFn: func(args map[string]any) string { return "e" + formatOffset(stringArg(args, "offset")) }},
	{ID: "workspace.move-window", Label: "Move Window to Workspace", Category: "Workspace", Dispatcher: "movetoworkspace", Args: []ActionArg{{Key: "index", Label: "Workspace", Placeholder: "1", DefaultValue: "1"}}, ArgumentFn: func(args map[string]any) string { return strings.TrimSpace(stringArg(args, "index")) }},
	{ID: "workspace.move-window-silent", Label: "Move Window to Workspace (Silent)", Category: "Workspace", Dispatcher: "movetoworkspacesilent", Args: []ActionArg{{Key: "index", Label: "Workspace", Placeholder: "1", DefaultValue: "1"}}, ArgumentFn: func(args map[string]any) string { return strings.TrimSpace(stringArg(args, "index")) }},
	{ID: "workspace.toggle-special", Label: "Toggle Special Workspace", Category: "Workspace", Dispatcher: "togglespecialworkspace", Argument: ""},
	{ID: "workspace.move-window-special", Label: "Move Window to Special Workspace", Category: "Workspace", Dispatcher: "movetoworkspace", Argument: "special"},
	{ID: "workspace.move-window-special-silent", Label: "Move Window to Special Workspace (Silent)", Category: "Workspace", Dispatcher: "movetoworkspacesilent", Argument: "special"},

	{ID: "scrolling.focus", Label: "Focus", Category: "Window", Dispatcher: "movefocus", Args: []ActionArg{{Key: "direction", Label: "Direction", Placeholder: "up/down/left/right", DefaultValue: "up"}}, ArgumentFn: func(args map[string]any) string { return directionToLetter(stringArg(args, "direction")) }},
	{ID: "scrolling.move-window", Label: "Move Window", Category: "Window", Dispatcher: "movewindow", Args: []ActionArg{{Key: "direction", Label: "Direction", Placeholder: "up/down/left/right", DefaultValue: "left"}}, ArgumentFn: func(args map[string]any) string { return directionToLetter(stringArg(args, "direction")) }},
	{ID: "scrolling.resize-column", Label: "Resize Column", Category: "Scrolling Layout", Dispatcher: "layoutmsg", Args: []ActionArg{{Key: "delta", Label: "Delta", Placeholder: "+0.1 / -0.1", DefaultValue: "+0.1"}}, ArgumentFn: func(args map[string]any) string { return "colresize " + strings.TrimSpace(stringArg(args, "delta")) }},
	{ID: "scrolling.promote", Label: "Promote Column", Category: "Scrolling Layout", Dispatcher: "layoutmsg", Argument: "promote"},
	{ID: "scrolling.toggle-fit", Label: "Toggle Fit", Category: "Scrolling Layout", Dispatcher: "layoutmsg", Argument: "togglefit"},
	{ID: "scrolling.toggle-full-column", Label: "Toggle Full Column", Category: "Scrolling Layout", Dispatcher: "layoutmsg", Argument: "colresize +conf"},
	{ID: "scrolling.swap-column", Label: "Swap Column", Category: "Scrolling Layout", Dispatcher: "layoutmsg", Args: []ActionArg{{Key: "direction", Label: "Direction", Placeholder: "left/right", DefaultValue: "left"}}, ArgumentFn: func(args map[string]any) string { return "swapcol " + directionToLetter(stringArg(args, "direction")) }},
	{ID: "scrolling.move-column-workspace", Label: "Move Column to Workspace", Category: "Scrolling Layout", Dispatcher: "layoutmsg", Args: []ActionArg{{Key: "index", Label: "Workspace", Placeholder: "1", DefaultValue: "1"}}, ArgumentFn: func(args map[string]any) string { return "movecoltoworkspace " + strings.TrimSpace(stringArg(args, "index")) }},

	{ID: "media.play-pause", Label: "Play/Pause", Category: "Media", Dispatcher: "exec", Argument: "playerctl play-pause"},
	{ID: "media.play-pause-locked", Label: "Play/Pause (Locked)", Category: "Media", Dispatcher: "exec", Argument: "playerctl play-pause", Flags: "l"},
	{ID: "media.prev", Label: "Previous Track", Category: "Media", Dispatcher: "exec", Argument: "playerctl previous"},
	{ID: "media.next", Label: "Next Track", Category: "Media", Dispatcher: "exec", Argument: "playerctl next"},
	{ID: "media.stop-locked", Label: "Stop Playback (Locked)", Category: "Media", Dispatcher: "exec", Argument: "playerctl stop", Flags: "l"},

	{ID: "audio.volume-up", Label: "Volume Up", Category: "Audio", Dispatcher: "exec", Argument: "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 10%+", Flags: "le"},
	{ID: "audio.volume-down", Label: "Volume Down", Category: "Audio", Dispatcher: "exec", Argument: "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 10%-", Flags: "le"},
	{ID: "audio.mute-toggle", Label: "Mute Audio", Category: "Audio", Dispatcher: "exec", Argument: "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle", Flags: "le"},

	{ID: "brightness.up", Label: "Brightness Up", Category: "Brightness", Dispatcher: "exec", Argument: "ambxst brightness +5", Flags: "le"},
	{ID: "brightness.down", Label: "Brightness Down", Category: "Brightness", Dispatcher: "exec", Argument: "ambxst brightness -5", Flags: "le"},

	{ID: "system.calculator", Label: "Calculator", Category: "System", Dispatcher: "exec", Argument: `notify-send "Soon"`},
	{ID: "system.lock", Label: "Lock Session", Category: "System", Dispatcher: "exec", Argument: "loginctl lock-session"},
	{ID: "system.lock-locked", Label: "Lock Session (Locked)", Category: "System", Dispatcher: "exec", Argument: "loginctl lock-session", Flags: "l"},
	{ID: "system.dpms-off", Label: "Display Off", Category: "System", Dispatcher: "exec", Argument: "axctl monitor set-dpms 0 0", Flags: "l"},
	{ID: "system.dpms-on", Label: "Display On", Category: "System", Dispatcher: "exec", Argument: "axctl monitor set-dpms 0 1", Flags: "l"},

	{ID: "command.run", Label: "Run Command", Category: "Custom", Dispatcher: "exec", Args: []ActionArg{{Key: "command", Label: "Command", Placeholder: "command to run", DefaultValue: ""}}, ArgumentFn: func(args map[string]any) string { return strings.TrimSpace(stringArg(args, "command")) }},

	{ID: "legacy.dispatcher", Label: "Legacy Dispatcher", Category: "Advanced", Dispatcher: "", Args: []ActionArg{
		{Key: "dispatcher", Label: "Dispatcher", Placeholder: "dispatcher", DefaultValue: ""},
		{Key: "argument", Label: "Argument", Placeholder: "argument", DefaultValue: ""},
		{Key: "flags", Label: "Flags", Placeholder: "flags", DefaultValue: ""},
	}, Hidden: true},
}

var catalogIndex = func() map[string]ActionSpec {
	m := make(map[string]ActionSpec, len(catalog))
	for _, a := range catalog {
		m[a.ID] = a
	}
	return m
}()

// GetActionById returns the spec for id, or false if not found.
func GetActionById(id string) (ActionSpec, bool) {
	a, ok := catalogIndex[id]
	return a, ok
}

// ResolveAction maps an {id, args} (or {dispatcher, argument, flags} legacy
// shape) into a concrete Hyprland dispatcher call. Returns nil if the action
// cannot be resolved.
func ResolveAction(action Action) *Resolved {
	if action.ID == "" && action.Dispatcher == "" {
		return nil
	}
	if action.Dispatcher != "" {
		return &Resolved{
			Dispatcher: action.Dispatcher,
			Argument:   action.Argument,
			Flags:      action.Flags,
		}
	}
	spec, ok := GetActionById(action.ID)
	if !ok {
		return nil
	}
	if spec.ID == "legacy.dispatcher" {
		return &Resolved{
			Dispatcher: stringArg(action.Args, "dispatcher"),
			Argument:   stringArg(action.Args, "argument"),
			Flags:      stringArg(action.Args, "flags"),
		}
	}
	arg := spec.Argument
	if spec.ArgumentFn != nil {
		arg = spec.ArgumentFn(action.Args)
	}
	return &Resolved{
		Dispatcher: spec.Dispatcher,
		Argument:   arg,
		Flags:      spec.Flags,
	}
}

// ActionFromLegacy is the inverse of ResolveAction: it maps a raw
// {dispatcher, argument, flags} triple into a catalog action id/args.
// Used when the binds.json still carries pre-normalized entries.
func ActionFromLegacy(dispatcher, argument, flags string) Action {
	arg := strings.TrimSpace(argument)
	switch dispatcher {
	case "killactive":
		return Action{ID: "window.close", Args: map[string]any{}}
	case "workspace":
		switch {
		case strings.HasPrefix(arg, "e"):
			return Action{ID: "workspace.switch-occupied", Args: map[string]any{"offset": arg[1:]}}
		case strings.HasPrefix(arg, "+"), strings.HasPrefix(arg, "-"):
			return Action{ID: "workspace.switch-relative", Args: map[string]any{"offset": arg}}
		default:
			return Action{ID: "workspace.switch", Args: map[string]any{"index": arg}}
		}
	case "movetoworkspace":
		if arg == "special" {
			return Action{ID: "workspace.move-window-special", Args: map[string]any{}}
		}
		return Action{ID: "workspace.move-window", Args: map[string]any{"index": arg}}
	case "movetoworkspacesilent":
		if arg == "special" {
			return Action{ID: "workspace.move-window-special-silent", Args: map[string]any{}}
		}
		return Action{ID: "workspace.move-window-silent", Args: map[string]any{"index": arg}}
	case "togglespecialworkspace":
		return Action{ID: "workspace.toggle-special", Args: map[string]any{}}
	case "movewindow":
		if flags == "m" {
			return Action{ID: "window.drag", Args: map[string]any{}}
		}
		return Action{ID: "window.move", Args: map[string]any{"direction": arg}}
	case "resizewindow":
		if flags == "m" {
			return Action{ID: "window.resize-drag", Args: map[string]any{}}
		}
		return Action{ID: "window.resize", Args: map[string]any{"delta": arg}}
	case "movefocus":
		return Action{ID: "window.focus", Args: map[string]any{"direction": arg}}
	case "resizeactive":
		return Action{ID: "window.resize", Args: map[string]any{"delta": arg}}
	case "layoutmsg":
		parts := strings.SplitN(arg, " ", 2)
		head := ""
		rest := ""
		if len(parts) > 0 {
			head = parts[0]
		}
		if len(parts) > 1 {
			rest = parts[1]
		}
		switch {
		case head == "focus":
			return Action{ID: "scrolling.focus", Args: map[string]any{"direction": rest}}
		case head == "movewindowto":
			return Action{ID: "scrolling.move-window", Args: map[string]any{"direction": rest}}
		case head == "colresize":
			if rest == "+conf" {
				return Action{ID: "scrolling.toggle-full-column", Args: map[string]any{}}
			}
			return Action{ID: "scrolling.resize-column", Args: map[string]any{"delta": rest}}
		case arg == "promote":
			return Action{ID: "scrolling.promote", Args: map[string]any{}}
		case arg == "togglefit":
			return Action{ID: "scrolling.toggle-fit", Args: map[string]any{}}
		case head == "swapcol":
			return Action{ID: "scrolling.swap-column", Args: map[string]any{"direction": rest}}
		case head == "movecoltoworkspace":
			return Action{ID: "scrolling.move-column-workspace", Args: map[string]any{"index": rest}}
		}
	case "exec":
		switch {
		case arg == "playerctl play-pause" && flags == "l":
			return Action{ID: "media.play-pause-locked", Args: map[string]any{}}
		case arg == "playerctl play-pause":
			return Action{ID: "media.play-pause", Args: map[string]any{}}
		case arg == "playerctl previous":
			return Action{ID: "media.prev", Args: map[string]any{}}
		case arg == "playerctl next":
			return Action{ID: "media.next", Args: map[string]any{}}
		case arg == "playerctl stop" && flags == "l":
			return Action{ID: "media.stop-locked", Args: map[string]any{}}
		case strings.HasPrefix(arg, "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 10%+"):
			return Action{ID: "audio.volume-up", Args: map[string]any{}}
		case strings.HasPrefix(arg, "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 10%-"):
			return Action{ID: "audio.volume-down", Args: map[string]any{}}
		case strings.HasPrefix(arg, "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"):
			return Action{ID: "audio.mute-toggle", Args: map[string]any{}}
		case strings.HasPrefix(arg, "ambxst brightness +5"):
			return Action{ID: "brightness.up", Args: map[string]any{}}
		case strings.HasPrefix(arg, "ambxst brightness -5"):
			return Action{ID: "brightness.down", Args: map[string]any{}}
		case arg == `notify-send "Soon"`:
			return Action{ID: "system.calculator", Args: map[string]any{}}
		case arg == "loginctl lock-session" && flags == "l":
			return Action{ID: "system.lock-locked", Args: map[string]any{}}
		case arg == "loginctl lock-session":
			return Action{ID: "system.lock", Args: map[string]any{}}
		case arg == "axctl monitor set-dpms 0 0":
			return Action{ID: "system.dpms-off", Args: map[string]any{}}
		case arg == "axctl monitor set-dpms 0 1":
			return Action{ID: "system.dpms-on", Args: map[string]any{}}
		}
		return Action{ID: "command.run", Args: map[string]any{"command": arg}}
	}
	return Action{ID: "legacy.dispatcher", Args: map[string]any{
		"dispatcher": dispatcher,
		"argument":   arg,
		"flags":      flags,
	}}
}

// EnsureAction fills in default args for an action that only has an id.
// Idempotent; never mutates the input.
func EnsureAction(action Action) Action {
	if action.ID != "" {
		out := action
		if out.Args == nil {
			out.Args = defaultArgsForID(out.ID)
		}
		return out
	}
	if action.Dispatcher != "" {
		return ActionFromLegacy(action.Dispatcher, action.Argument, action.Flags)
	}
	return action
}

func defaultArgsForID(id string) map[string]any {
	spec, ok := GetActionById(id)
	if !ok {
		return map[string]any{}
	}
	out := make(map[string]any, len(spec.Args))
	for _, f := range spec.Args {
		out[f.Key] = f.DefaultValue
	}
	return out
}

// DescribeAction returns a human-readable summary; mirrors describeAction in
// the JS catalog. Not used by the TOML renderer; kept for parity so the Go
// and JS sides stay in lockstep.
func DescribeAction(action Action) string {
	if action.ID == "" {
		return ""
	}
	spec, ok := GetActionById(action.ID)
	if !ok {
		return ""
	}
	if spec.ID == "legacy.dispatcher" {
		dispatcher, _ := action.Args["dispatcher"].(string)
		argument, _ := action.Args["argument"].(string)
		if argument == "" {
			return dispatcher
		}
		return dispatcher + " " + argument
	}
	if len(spec.Args) == 0 {
		return spec.Label
	}
	parts := make([]string, 0, len(spec.Args))
	for _, f := range spec.Args {
		if v, ok := action.Args[f.Key].(string); ok && v != "" {
			parts = append(parts, v)
		}
	}
	if len(parts) == 0 {
		return spec.Label
	}
	return spec.Label + " · " + strings.Join(parts, " ")
}

// --- helpers ---

func stringArg(args map[string]any, key string) string {
	if args == nil {
		return ""
	}
	v, _ := args[key].(string)
	return v
}

func directionToLetter(direction string) string {
	switch strings.ToLower(strings.TrimSpace(direction)) {
	case "up", "u":
		return "u"
	case "down", "d":
		return "d"
	case "left", "l":
		return "l"
	case "right", "r":
		return "r"
	}
	return ""
}

func formatOffset(value string) string {
	v := strings.TrimSpace(value)
	if v == "" {
		return "0"
	}
	if strings.HasPrefix(v, "+") || strings.HasPrefix(v, "-") {
		return v
	}
	// Keep "+"/"-" prefix from the JS version: any non-empty numeric value
	// without a sign gets a leading "+" so hyprland interprets it as relative.
	var n int
	if _, err := fmt.Sscanf(v, "%d", &n); err != nil {
		return v
	}
	if n >= 0 {
		return "+" + v
	}
	return v
}
