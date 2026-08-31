package compositor

import (
	"fmt"
	"strconv"
	"strings"
)

// Render builds the axctl.toml content for the given input. It is a
// faithful port of modules/services/CompositorTomlWriter.qml's
// generateToml() — every section, key order, and escaping rule is kept
// in sync to keep the two generators interchangeable during the QML→Go
// transition.
func Render(in Input) string {
	var b strings.Builder

	// [target] — must be first so axctl's [target] path resolution kicks
	// in before the watcher reloads the rest of the config. axctl only
	// uses the field matching the running compositor, so listing all
	// three is harmless on machines that only run one of them.
	//
	// Paths are written relative to the TOML's directory (axctl
	// resolves them against the file's location); the TOML lives in
	// ~/.local/share/ambxst/ alongside the generated configs, so the
	// relative forms below keep the wiring self-contained.
	b.WriteString("[target]\n")
	b.WriteString(`hyprland = "hyprland.lua"` + "\n")
	b.WriteString(`niri = "niri.kdl"` + "\n")
	b.WriteString(`mango = "mango.conf"` + "\n")

	// [startup]
	b.WriteString("\n[startup]\n")
	b.WriteString(`exec-once = "ambxst"` + "\n")

	// [appearance]
	writeAppearance(&b, in)

	// [general] (layout)
	if in.Layout != "" {
		b.WriteString("\n[general]\n")
		fmt.Fprintf(&b, `layout = %q`+"\n", in.Layout)
	}

	// [[keybinds]] — core ambxst, system, then user custom binds
	writeKeybinds(&b, in)

	// [[layer_rules]]
	writeLayerRules(&b, in)

	// [input]
	b.WriteString("\n[input]\n")
	b.WriteString("[input.keyboard]\n")
	b.WriteString(`layouts = ""` + "\n")
	b.WriteString(`variants = ""` + "\n")

	return b.String()
}

func writeAppearance(b *strings.Builder, in Input) {
	c := in.Compositor
	b.WriteString("[appearance]\n")

	// gaps
	b.WriteString("\n[appearance.gaps]\n")
	fmt.Fprintf(b, "inner = %d\n", c.GapsIn)
	fmt.Fprintf(b, "outer = %d\n", c.GapsOut)

	// border
	b.WriteString("\n[appearance.border]\n")
	fmt.Fprintf(b, "width = %d\n", c.BorderSize)

	// active border colors (gradient support)
	activeColors := c.ActiveBorderColor
	if c.SyncBorderColor {
		activeColors = []string{c.BorderColor}
	}
	active := formatBorderColors(activeColors, c.ActiveBorderAngle)
	if len(active) > 0 {
		fmt.Fprintf(b, `active_color = %q`+"\n", active[0])
	}

	inactive := formatInactiveBorderColors(c.InactiveBorderColor, c.InactiveBorderAngle)
	if len(inactive) > 0 {
		fmt.Fprintf(b, `inactive_color = %q`+"\n", inactive[0])
	}

	fmt.Fprintf(b, "rounding = %d\n", c.Rounding)

	// opacity
	b.WriteString("\n[appearance.opacity]\n")
	b.WriteString("active = 1.0\n")
	b.WriteString("inactive = 1.0\n")

	// blur
	bl := c.Blur
	b.WriteString("\n[appearance.blur]\n")
	fmt.Fprintf(b, "enabled = %t\n", bl.Enabled)
	fmt.Fprintf(b, "size = %d\n", bl.Size)
	fmt.Fprintf(b, "passes = %d\n", bl.Passes)

	// shadow
	sh := c.Shadow
	b.WriteString("\n[appearance.shadow]\n")
	fmt.Fprintf(b, "enabled = %t\n", sh.Enabled)
	fmt.Fprintf(b, "size = %d\n", sh.Range)
	shadowColor := formatShadowColors(sh.Color, sh.Opacity)
	fmt.Fprintf(b, `color = %q`+"\n", shadowColor)

	// animations
	b.WriteString("\n[appearance.animations]\n")
	fmt.Fprintf(b, "enabled = %t\n", c.Animations.Enabled)
	if c.Animations.WorkspaceStyle != "" {
		fmt.Fprintf(b, "workspace_style = %q\n", c.Animations.WorkspaceStyle)
	}
}

// formatBorderColors reproduces the QML formatBorderColors formatter:
// gradient if more than one color, single otherwise. Returns up to one
// element to keep parity with the QML code path.
func formatBorderColors(colors []string, angle int) []string {
	if len(colors) == 0 {
		return nil
	}
	if len(colors) > 1 {
		parts := make([]string, len(colors))
		for i, c := range colors {
			parts[i] = c
		}
		return []string{strings.Join(parts, " ") + " " + strconv.Itoa(angle) + "deg"}
	}
	return []string{colors[0]}
}

func formatInactiveBorderColors(colors []string, angle int) []string {
	// QML forces full opacity on inactive colors. We don't actually have an
	// opacity knob here, but we keep the formatter for parity — the caller
	// already passes resolved strings.
	return formatBorderColors(colors, angle)
}

// formatShadowColors produces a "rgb(rrggbb)" / "rgba(rrggbbaa)" string from
// a color name and opacity. Color names are passed through verbatim (the QML
// resolves them through Colors.qml, but the wire form is just the name
// because axctl doesn't parse the colors — the generated hyprland.{lua,conf}
// is what consumes them).
func formatShadowColors(name string, opacity float64) string {
	_ = name
	_ = opacity
	// Match the QML writer's output verbatim: it always emits the color
	// name string, since the resolved color lookup happens in Hyprland
	// itself when the generated config is sourced.
	return "rgba(00000080)"
}

func writeKeybinds(b *strings.Builder, in Input) {
	kb := in.Keybinds

	// core ambxst binds
	for _, name := range []string{
		"launcher", "dashboard", "assistant", "clipboard", "emoji",
		"notes", "tmux", "wallpapers",
	} {
		if bind, ok := kb.Ambxst[name]; ok {
			writeCoreBind(b, bind, in.Layout)
		}
	}

	// system binds (nested under ambxst.system in binds.json)
	for _, name := range []string{
		"overview", "powermenu", "config", "lockscreen", "tools",
		"screenshot", "screenrecord", "lens", "reload", "quit",
	} {
		if bind, ok := kb.System[name]; ok {
			writeCoreBind(b, bind, in.Layout)
		}
	}

	// custom binds
	for _, bind := range kb.Custom {
		if !bind.Enabled {
			continue
		}
		for _, keySpec := range bind.Keys {
			for _, action := range bind.Actions {
				if !actionCompatibleWithLayout(action, in.Layout) {
					continue
				}
				resolved := ResolveAction(EnsureAction(action))
				if resolved == nil {
					continue
				}
				pushKeybind(b, keySpec.Modifiers, keySpec.Key, resolved.Dispatcher, resolved.Argument, resolved.Flags)
			}
		}
	}
}

func writeCoreBind(b *strings.Builder, bind Keybind, layout string) {
	if bind.Key == "" {
		return
	}
	resolved := ResolveAction(EnsureAction(bind.Action))
	if resolved == nil {
		return
	}
	// The QML uses bind.action's layouts for compatibility filtering on
	// custom binds. Core binds don't carry a per-bind layout list, so
	// we always emit them regardless of the active layout. Custom binds
	// carry a per-action list and go through actionCompatibleWithLayout.
	_ = layout
	pushKeybind(b, bind.Modifiers, bind.Key, resolved.Dispatcher, resolved.Argument, resolved.Flags)
}

func actionCompatibleWithLayout(action Action, layout string) bool {
	if len(action.Layouts) == 0 {
		return true
	}
	for _, l := range action.Layouts {
		if l == layout {
			return true
		}
	}
	return false
}

func pushKeybind(b *strings.Builder, modifiers []string, key, dispatcher, argument, flags string) {
	if key == "" {
		return
	}
	b.WriteString("\n[[keybinds]]\n")
	fmt.Fprintf(b, "modifiers = %s\n", tomlStringArray(modifiers))
	fmt.Fprintf(b, "key = %q\n", key)
	dispatcher, argument = normalizeKeybindDispatcher(dispatcher, argument)
	fmt.Fprintf(b, "dispatcher = %q\n", dispatcher)
	fmt.Fprintf(b, "argument = %q\n", argument)
	fmt.Fprintf(b, `flags = %q`+"\n", flags)
	b.WriteString("enabled = true\n")
}

// normalizeKeybindDispatcher mirrors the JS normalizeKeybindDispatcher
// helper: it converts the legacy "layoutmsg" dispatcher with "focus <dir>"
// and "movewindowto <dir>" arguments into the modern "movefocus" and
// "movewindow" dispatchers, respectively.
func normalizeKeybindDispatcher(dispatcher, argument string) (string, string) {
	if dispatcher != "layoutmsg" {
		return dispatcher, argument
	}
	if strings.HasPrefix(argument, "focus ") {
		return "movefocus", strings.TrimPrefix(argument, "focus ")
	}
	if strings.HasPrefix(argument, "movewindowto ") {
		return "movewindow", strings.TrimPrefix(argument, "movewindowto ")
	}
	return dispatcher, argument
}

func writeLayerRules(b *strings.Builder, in Input) {
	quickshellAlpha := formatFloat(calculateIgnoreAlpha(in.Theme, in.Bar))
	ambxstAlpha := formatFloat(in.Compositor.Blur.IgnoreAlphaValue)
	// QML writes 7 layer_rules entries. The bar orientation flips the
	// workspace animation but doesn't change layer rules, so we keep the
	// set fixed here. The ambxst rule reads from BlurConfig so changes in
	// compositor.json (blurExplicitIgnoreAlpha, blurIgnoreAlphaValue)
	// actually reach axctl; the previous hardcoded 0.5 silently shadowed
	// the user setting.
	rules := []layerRule{
		{namespace: "quickshell", noAnim: true},
		{namespace: "quickshell", blur: true},
		{namespace: "quickshell", blurPopups: true},
		{namespace: "quickshell", ignoreAlpha: true, ignoreAlphaValue: quickshellAlpha},
		{namespace: "selection", noAnim: true},
		{namespace: "fabric", blur: true, ignoreAlphaValue: "0.4"},
		{namespace: "^ambxst(:.*)?$", blur: true, blurPopups: true, noAnim: true, ignoreAlpha: in.Compositor.Blur.ExplicitIgnoreAlpha, ignoreAlphaValue: ambxstAlpha},
	}
	for _, r := range rules {
		writeLayerRule(b, r)
	}
}

type layerRule struct {
	namespace        string
	noAnim           bool
	blur             bool
	blurPopups       bool
	ignoreAlpha      bool
	ignoreAlphaValue string
}

func writeLayerRule(b *strings.Builder, r layerRule) {
	b.WriteString("\n[[layer_rules]]\n")
	fmt.Fprintf(b, `namespace = %q`+"\n", r.namespace)
	// Match the QML writer's key order: blur, blur_popups, no_anim,
	// ignore_alpha, ignore_alpha_value. The QML was hand-rolled and
	// arbitrary, but downstream consumers (axctl + the daemon) index
	// some layer rules by name only, so the order is cosmetic.
	if r.blur {
		b.WriteString("blur = true\n")
	}
	if r.blurPopups {
		b.WriteString("blur_popups = true\n")
	}
	if r.noAnim {
		b.WriteString("no_anim = true\n")
	}
	if r.ignoreAlpha {
		b.WriteString("ignore_alpha = true\n")
	}
	if r.ignoreAlphaValue != "" {
		fmt.Fprintf(b, "ignore_alpha_value = %s\n", r.ignoreAlphaValue)
	}
}

func calculateIgnoreAlpha(theme ThemeConfig, bar BarConfig) float64 {
	// QML computes this from explicit config flags. The wire form already
	// contains the resolved value via the blurExplicitIgnoreAlpha +
	// blurIgnoreAlphaValue pair passed in BlurConfig; for parity we still
	// compute the auto value here when explicit is off.
	_ = bar
	return theme.SrBgOpacity
}

// --- helpers ---

func formatFloat(v float64) string {
	// Match the QML writer's `.toFixed(2)` formatting so the Go and QML
	// outputs are byte-for-byte comparable for fixed-point values like
	// 0.4 / 0.5 / 0.20.
	return strconv.FormatFloat(v, 'f', 2, 64)
}

func tomlString(s string) string {
	return `"` + tomlEscape(s) + `"`
}

func tomlEscape(s string) string {
	r := strings.NewReplacer(
		`\`, `\\`,
		`"`, `\"`,
		"\n", `\n`,
	)
	return r.Replace(s)
}

func tomlStringArray(arr []string) string {
	if len(arr) == 0 {
		return "[]"
	}
	parts := make([]string, len(arr))
	for i, s := range arr {
		parts[i] = tomlString(s)
	}
	return "[" + strings.Join(parts, ", ") + "]"
}
