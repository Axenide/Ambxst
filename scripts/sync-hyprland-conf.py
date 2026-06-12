#!/usr/bin/env python3
"""Sync Ambxst compositor config + keybinds to hyprland.conf and hyprland.lua"""
import json, re, os

BASE = os.path.expanduser('~/.config/ambxst/config')
BINDS_PATH = os.path.expanduser('~/.config/ambxst/binds.json')
CONF_PATH = os.path.expanduser('~/.local/share/ambxst/hyprland.conf')
LUA_PATH = os.path.expanduser('~/.local/share/ambxst/hyprland.lua')
AXCTL_TOML_PATH = os.path.expanduser('~/.local/share/ambxst/axctl.toml')
COMPOSITOR_PATH = os.path.join(BASE, 'compositor.json')

with open(COMPOSITOR_PATH) as f:
    cfg = json.load(f)

# ============================================================================
#  ACTION RESOLVER — mirrors KeybindActions.js
# ============================================================================

def direction_letter(direction):
    d = (direction or "").lower()
    if d in ("up", "u"): return "u"
    if d in ("down", "d"): return "d"
    if d in ("left", "l"): return "l"
    if d in ("right", "r"): return "r"
    return ""

ACTION_MAP = {
    # Ambxst core actions
    "ambxst.launcher":        ("exec", "ambxst run launcher", "r"),
    "ambxst.dashboard":       ("exec", "ambxst run dashboard"),
    "ambxst.assistant":       ("exec", "ambxst run assistant"),
    "ambxst.clipboard":       ("exec", "ambxst run clipboard"),
    "ambxst.emoji":           ("exec", "ambxst run emoji"),
    "ambxst.notes":           ("exec", "ambxst run notes"),
    "ambxst.tmux":            ("exec", "ambxst run tmux"),
    "ambxst.wallpapers":      ("exec", "ambxst run wallpapers"),
    "ambxst.config":          ("exec", "ambxst run config"),
    "ambxst.overview":        ("exec", "ambxst run overview"),
    "ambxst.powermenu":       ("exec", "ambxst run powermenu"),
    "ambxst.tools":           ("exec", "ambxst run tools"),
    "ambxst.screenshot":      ("exec", "ambxst run screenshot"),
    "ambxst.screenrecord":    ("exec", "ambxst run screenrecord"),
    "ambxst.lens":            ("exec", "ambxst run lens"),
    "ambxst.reload":          ("exec", "ambxst reload"),
    "ambxst.quit":            ("exec", "ambxst quit"),
    "ambxst.toggle-metrics":  ("exec", "ambxst run toggle-metrics"),
    "ambxst.lock":            ("exec", "ambxst lock"),

    # Window actions
    # Window movement: SUPER + drag = MOVE (via m flag)
    # Window resize: click border + drag = RESIZE nativo (via resize_on_border)
    # resize-drag no genera bind nativo - lo maneja resize_on_border
    "window.close":                ("killactive", ""),
    "window.focus":                ("movefocus", "direction"),
    "window.move":                 ("movewindow", "direction"),
    "window.drag":                 ("movewindow", "", "m"),
    "window.resize-drag":          ("", ""),  # No bind nativo - lo maneja resize_on_border
    "window.resize":               ("resizeactive", "delta"),
    "window.resize-expand":        ("resizeactive", "50 50"),
    "window.resize-shrink":        ("resizeactive", "-50 -50"),

    # Workspace actions
    "workspace.switch":            ("workspace", "index"),
    "workspace.switch-relative":   ("workspace", "offset"),
    "workspace.switch-occupied":   ("workspace", "offset", "", "e"),
    "workspace.move-window":       ("movetoworkspace", "index"),
    "workspace.move-window-silent":("movetoworkspacesilent", "index"),
    "workspace.toggle-special":    ("togglespecialworkspace", ""),
    "workspace.move-window-special":("movetoworkspace", "special"),
    "workspace.move-window-special-silent":("movetoworkspacesilent", "special"),

    # Scrolling layout actions
    "scrolling.focus":             ("movefocus", "direction"),
    "scrolling.move-window":       ("movewindow", "direction"),
    "scrolling.resize-column":     ("layoutmsg", "delta", "", "colresize "),
    "scrolling.promote":           ("layoutmsg", "promote"),
    "scrolling.toggle-fit":        ("layoutmsg", "togglefit"),
    "scrolling.toggle-full-column":("layoutmsg", "colresize +conf"),
    "scrolling.swap-column":       ("layoutmsg", "direction", "", "swapcol "),
    "scrolling.move-column-workspace":("layoutmsg", "index", "", "movecoltoworkspace "),

    # Free Layout actions (Windows-style hyprctl commands)
    "free.snap-left":              ("exec", "hyprctl dispatch centerwindow && hyprctl dispatch resizeactive -50% 0"),
    "free.snap-right":             ("exec", "hyprctl dispatch centerwindow && hyprctl dispatch resizeactive 50% 0"),
    "free.snap-top":               ("exec", "hyprctl dispatch centerwindow && hyprctl dispatch resizeactive 0 -50%"),
    "free.snap-bottom":            ("exec", "hyprctl dispatch centerwindow && hyprctl dispatch resizeactive 0 50%"),
    "free.snap-center":            ("exec", "hyprctl dispatch centerwindow"),
    "free.snap-maximize":          ("fullscreen", "1"),
    "free.snap-restore":           ("fullscreen", "0"),
    "free.snap-top-left":          ("exec", "hyprctl dispatch movewindow pixel exact 0 0,active && hyprctl dispatch resizeactive 50% 50%"),
    "free.snap-top-right":         ("exec", "hyprctl dispatch movewindow pixel exact 50% 0,active && hyprctl dispatch resizeactive 50% 50%"),
    "free.snap-bottom-left":       ("exec", "hyprctl dispatch movewindow pixel exact 0 50%,active && hyprctl dispatch resizeactive 50% 50%"),
    "free.snap-bottom-right":      ("exec", "hyprctl dispatch movewindow pixel exact 50% 50%,active && hyprctl dispatch resizeactive 50% 50%"),
    "free.toggle-tile":            ("togglefloating", ""),
    "free.show-desktop":           ("exec", "hyprctl dispatch workspaceopt allfloat"),
    "free.workspace-left":         ("exec", "hyprctl dispatch movewindow m:-1"),
    "free.workspace-right":        ("exec", "hyprctl dispatch movewindow m:+1"),

    # Media actions
    "media.play-pause":            ("exec", "playerctl play-pause"),
    "media.play-pause-locked":     ("exec", "playerctl play-pause", "l"),
    "media.prev":                  ("exec", "playerctl previous"),
    "media.next":                  ("exec", "playerctl next"),
    "media.stop-locked":           ("exec", "playerctl stop", "l"),

    # Audio actions
    "audio.volume-up":             ("exec", "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 10%+", "le"),
    "audio.volume-down":           ("exec", "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 10%-", "le"),
    "audio.mute-toggle":           ("exec", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle", "le"),

    # Brightness actions
    "brightness.up":               ("exec", "ambxst brightness +5", "le"),
    "brightness.down":             ("exec", "ambxst brightness -5", "le"),

    # System actions
    "system.calculator":           ("exec", "notify-send \"Soon\""),
    "system.lock":                 ("exec", "loginctl lock-session"),
    "system.lock-locked":          ("exec", "loginctl lock-session", "l"),
    "system.dpms-off":             ("exec", "axctl monitor set-dpms 0 0", "l"),
    "system.dpms-on":              ("exec", "axctl monitor set-dpms 0 1", "l"),

    # Custom command
    "command.run":                 ("exec", "command"),
}


def resolve_action(action):
    """Resolve an action dict to (dispatcher, argument, flags)."""
    if not action:
        return None

    # Already resolved form
    if action.get("dispatcher"):
        return (action["dispatcher"], action.get("argument", ""), action.get("flags", ""))

    action_id = action.get("id", "")
    args = action.get("args", {})
    entry = ACTION_MAP.get(action_id)

    if not entry:
        return None

    dispatcher = entry[0]
    arg_spec = entry[1] if len(entry) > 1 else ""
    flags = entry[2] if len(entry) > 2 else ""
    prefix = entry[3] if len(entry) > 3 else ""

    # Resolve argument
    if arg_spec == "direction":
        argument = direction_letter(args.get("direction", ""))
    elif arg_spec == "index":
        argument = str(args.get("index", ""))
    elif arg_spec == "offset":
        raw = str(args.get("offset", ""))
        if raw and (raw.startswith("+") or raw.startswith("-")):
            argument = raw
        else:
            num = int(raw) if raw else 0
            argument = f"+{num}" if num >= 0 else str(num)
    elif arg_spec == "delta":
        argument = str(args.get("delta", ""))
    elif arg_spec == "command":
        argument = str(args.get("command", ""))
    elif arg_spec == "special":
        argument = "special"
    else:
        argument = str(arg_spec) if arg_spec else ""

    # Handle prefix (layoutmsg commands)
    if prefix and argument:
        argument = prefix + argument

    return (dispatcher, argument, flags)


def build_bind_line(modifiers, key, dispatcher, argument, flags):
    """Build a hyprland.conf bind line."""
    if not key:
        return None

    mods_str = " ".join(modifiers) if modifiers else ""

    if not dispatcher:
        return None

    # Mouse bind with 'm' flag (for move only)
    if "m" in flags:
        if argument:
            if not mods_str:
                return f"bind = , {key}, {dispatcher}, {argument}, m"
            return f"bind = {mods_str}, {key}, {dispatcher}, {argument}, m"
        else:
            if not mods_str:
                return f"bind = , {key}, {dispatcher}, m"
            return f"bind = {mods_str}, {key}, {dispatcher}, m"

    bind_type = "bind"
    if "r" in flags:
        bind_type = "bindr"
    elif "l" in flags:
        bind_type = "bindl"
    # 'e' (floating) — keep as bind since hyprland doesn't have a native single-char flag for that

    # Build the argument part (skip if empty to avoid trailing comma)
    arg_part = f", {argument}" if argument else ""

    if not mods_str:
        return f"{bind_type} = , {key}, {dispatcher}{arg_part}"

    return f"{bind_type} = {mods_str}, {key}, {dispatcher}{arg_part}"


def build_lua_bind(modifiers, key, dispatcher, argument, flags):
    """Build a hyprland.lua hl.bind() call."""
    if not key or not dispatcher:
        return None

    mods_lua = "{ " + ", ".join(f'"{m}"' for m in (modifiers or [])) + " }" if modifiers else "{}"

    # Build flags for lua
    lua_flags = []
    if "l" in flags:
        lua_flags.append("locked = true")
    if "r" in flags:
        lua_flags.append("release = true")
    if "m" in flags:
        lua_flags.append("mouse = true")

    flags_str = ", " + ", ".join(lua_flags) if lua_flags else ""

    return f'hl.bind({{ mods = {mods_lua}, key = "{key}", dispatcher = "{dispatcher}", arg = "{argument}"{flags_str} }})'


def process_ambxst_binds(binds_data):
    """Process the 'ambxst' section of binds.json."""
    lines = []
    lua_lines = []

    ambxst = binds_data.get("ambxst", {})

    # Process core keys (launcher, dashboard, etc.)
    core_keys = ["launcher", "dashboard", "assistant", "clipboard", "emoji",
                  "notes", "tmux", "wallpapers"]
    for key_name in core_keys:
        bind = ambxst.get(key_name)
        if not bind:
            continue
        resolved = resolve_action(bind.get("action", {}))
        if not resolved:
            continue
        dispatcher, argument, flags = resolved
        line = build_bind_line(bind.get("modifiers", []), bind.get("key", ""), dispatcher, argument, flags)
        lua = build_lua_bind(bind.get("modifiers", []), bind.get("key", ""), dispatcher, argument, flags)
        if line:
            lines.append(line)
        if lua:
            lua_lines.append(lua)

    # Process system keys
    system = ambxst.get("system", {})
    sys_keys = ["overview", "powermenu", "config", "lockscreen", "tools",
                 "screenshot", "screenrecord", "lens", "reload", "quit", "toggle-metrics"]
    for key_name in sys_keys:
        bind = system.get(key_name)
        if not bind:
            continue
        resolved = resolve_action(bind.get("action", {}))
        if not resolved:
            continue
        dispatcher, argument, flags = resolved
        line = build_bind_line(bind.get("modifiers", []), bind.get("key", ""), dispatcher, argument, flags)
        lua = build_lua_bind(bind.get("modifiers", []), bind.get("key", ""), dispatcher, argument, flags)
        if line:
            lines.append(line)
        if lua:
            lua_lines.append(lua)

    return lines, lua_lines


def process_custom_binds(binds_data):
    """Process the 'custom' array of binds.json."""
    lines = []
    lua_lines = []
    custom = binds_data.get("custom", [])

    for bind in custom:
        if bind.get("enabled") is False:
            continue

        keys = bind.get("keys", [])
        actions = bind.get("actions", [])

        if not keys or not actions:
            continue

        for key_obj in keys:
            if not key_obj or not key_obj.get("key"):
                continue

            for action in actions:
                resolved = resolve_action(action)
                if not resolved:
                    continue
                dispatcher, argument, flags = resolved
                line = build_bind_line(key_obj.get("modifiers", []), key_obj.get("key", ""), dispatcher, argument, flags)
                lua = build_lua_bind(key_obj.get("modifiers", []), key_obj.get("key", ""), dispatcher, argument, flags)
                if line:
                    lines.append(line)
                if lua:
                    lua_lines.append(lua)

    return lines, lua_lines


def build_binds_block():
    """Build the keybinds section for hyprland.conf and .lua."""
    try:
        with open(BINDS_PATH) as f:
            binds_data = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return "", ""

    core_lines, core_lua = process_ambxst_binds(binds_data)
    custom_lines, custom_lua = process_custom_binds(binds_data)

    # Remove duplicates while preserving order
    seen = set()
    deduped = []
    for line in core_lines + custom_lines:
        if line not in seen:
            deduped.append(line)
            seen.add(line)

    if not deduped:
        return "", ""

    block = "# === AMBXST KEYBINDS ===\n"
    block += "# Synced from Ambxst binds.json\n"
    for line in deduped:
        block += line + "\n"

    # Windows-style default keybinds for Free layout
    if cfg.get('layout') == 'free':
        block += "\n# Windows-style keybinds (Free layout)\n"
        block += "bind = SUPER, Left, exec, hyprctl dispatch centerwindow && hyprctl dispatch resizeactive -50% 0\n"
        block += "bind = SUPER, Right, exec, hyprctl dispatch centerwindow && hyprctl dispatch resizeactive 50% 0\n"
        block += "bind = SUPER, Up, exec, hyprctl dispatch fullscreen 1\n"
        block += "bind = SUPER, Down, exec, hyprctl dispatch fullscreen 0\n"
        block += "bind = SUPER SHIFT, Left, exec, hyprctl dispatch movewindow m:-1\n"
        block += "bind = SUPER SHIFT, Right, exec, hyprctl dispatch movewindow m:+1\n"
        block += "bind = SUPER, D, exec, hyprctl dispatch workspaceopt allfloat\n"
        block += "\n"

    block += "# === END KEYBINDS ===\n"

    seen_lua = set()
    deduped_lua = []
    for line in core_lua + custom_lua:
        if line not in seen_lua:
            deduped_lua.append(line)
            seen_lua.add(line)

    lua_block = "-- === AMBXST KEYBINDS ===\n"
    lua_block += "-- Synced from Ambxst binds.json\n"
    for line in deduped_lua:
        lua_block += line + "\n"
    lua_block += "-- === END KEYBINDS ===\n"

    return block, lua_block


# ============================================================================
#  Format helpers
# ============================================================================
def fmt(val):
    if isinstance(val, bool):
        return 'true' if val else 'false'
    if isinstance(val, list):
        return ' '.join(str(v) for v in val)
    if isinstance(val, float):
        s = f'{val:.2f}'.rstrip('0').rstrip('.')
        return s if '.' in s else s + '.0'
    if isinstance(val, str) and val == '':
        return ''
    return str(val)

def fmt_lua(val):
    if isinstance(val, bool):
        return 'true' if val else 'false'
    if isinstance(val, list):
        return '{ "' + '", "'.join(str(v) for v in val) + '" }'
    if isinstance(val, float):
        s = f'{val:.2f}'.rstrip('0').rstrip('.')
        return s if '.' in s else s + '.0'
    if isinstance(val, str):
        return '"' + val + '"'
    return str(val)

def resolve_color(name):
    if not name or name == 'shadow':
        return '0xee1a1a1a'
    return name

# ============================================================================
#  hyprland.conf - BLOCK syntax
# ============================================================================
def build_conf_block():
    lines = ['# === AMBXST COMPOSITOR ===', '# Applied by Ambxst', '']

    def sec(name, keys, indent=''):
        lines.append(indent + name + ' {')
        for ck, kw in keys:
            if ck in cfg:
                lines.append(indent + '  ' + kw + ' = ' + fmt(cfg[ck]))
        lines.append(indent + '}')

    # Determine if Free Layout (floating mode)
    _is_free = cfg.get('layout') == 'free'

    if _is_free:
        # Free Layout: windowrule float ALL windows
        lines.append('windowrule = match:class .*, float on')
        lines.append('')

    # Smart Resize Anchors: override resize_on_border + grab area
    _smart = cfg.get('smartResizeAnchors', True)
    if _smart:
        cfg.update({'resizeOnBorder': True, 'extendBorderGrabArea': 10})
    else:
        cfg.update({'resizeOnBorder': False, 'extendBorderGrabArea': 0})

    sec('general', [
        ('borderSize','border_size'), ('gapsIn','gaps_in'), ('gapsOut','gaps_out'),
        ('allowTearing','allow_tearing'),
        ('hoverIconOnBorder','hover_icon_on_border'),
        ('resizeOnBorder','resize_on_border'),
        ('extendBorderGrabArea','extend_border_grab_area'),
    ] + ([] if _is_free else [('layout','layout')]))

    lines.append('')

    lines.append('decoration {')
    for k, kw in [('rounding','rounding'), ('roundingPower','rounding_power'),
                  ('activeOpacity','active_opacity'), ('inactiveOpacity','inactive_opacity'),
                  ('fullscreenOpacity','fullscreen_opacity'),
                  ('dimInactive','dim_inactive'), ('dimStrength','dim_strength'),
                  ('dimAround','dim_around'), ('dimSpecial','dim_special')]:
        if k in cfg: lines.append('  ' + kw + ' = ' + fmt(cfg[k]))
    lines.append('')
    lines.append('  shadow {')
    for k, kw in [('shadowRange','range'), ('shadowRenderPower','render_power'),
                  ]:
        if k in cfg: lines.append('    ' + kw + ' = ' + fmt(cfg[k]))
    lines.append('    color = ' + resolve_color(cfg.get('shadowColor', 'shadow')))
    lines.append('    color_inactive = ' + resolve_color(cfg.get('shadowColorInactive', 'shadow')))
    lines.append('  }')
    lines.append('')
    lines.append('  blur {')
    for k, kw in [('blurSize','size'), ('blurPasses','passes'),
                  ('blurIgnoreOpacity','ignore_opacity'),
                  ('blurNewOptimizations','new_optimizations'),
                  ('blurXray','xray'), ('blurNoise','noise'), ('blurContrast','contrast'),
                  ('blurBrightness','brightness'), ('blurVibrancy','vibrancy'),
                  ('blurVibrancyDarkness','vibrancy_darkness')]:
        if k in cfg: lines.append('    ' + kw + ' = ' + fmt(cfg[k]))
    lines.append('  }')
    lines.append('}')

    lines.append('')
    lines.append('input {')
    for k, kw in [('kbLayout','kb_layout'), ('kbVariant','kb_variant'),
                  ('kbOptions','kb_options'),
                  ('numlockByDefault','numlock_by_default'),
                  ('repeatRate','repeat_rate'), ('repeatDelay','repeat_delay'),
                  ('mouseSensitivity','sensitivity'),
                  ('followMouse','follow_mouse'),
                  ('mouseNaturalScroll','natural_scroll'),
                  ('mouseScrollFactor','scroll_factor'),
                  ('mouseLeftHanded','left_handed'),
                  ('mouseRefocus','mouse_refocus'),
                  ('floatSwitchOverrideFocus','float_switch_override_focus')]:
        if k in cfg: lines.append('  ' + kw + ' = ' + fmt(cfg[k]))
    if cfg.get('mouseAccelProfile'): lines.append('  accel_profile = ' + cfg['mouseAccelProfile'])
    lines.append('')
    lines.append('  touchpad {')
    for k, kw in [('touchpadDisableWhileTyping','disable_while_typing'),
                  ('touchpadNaturalScroll','natural_scroll'),

                  ('touchpadClickfingerBehavior','clickfinger_behavior'),
                  ('touchpadMiddleButtonEmulation','middle_button_emulation'),
                  ('touchpadDragLock','drag_lock'),
                  ('touchpadScrollFactor','scroll_factor')]:
        if k in cfg: lines.append('    ' + kw + ' = ' + fmt(cfg[k]))
    if cfg.get('touchpadTapButtonMap'): lines.append('    tap_button_map = ' + cfg['touchpadTapButtonMap'])
    lines.append('  }')
    lines.append('}')

    for sec_name, keys in [
        ('cursor', [('noHardwareCursors','no_hardware_cursors'),
                    ('enableHyprcursor','enable_hyprcursor'), ('noWarps','no_warps'),
                    ('persistentWarps','persistent_warps'),
                    ('warpOnChangeWorkspace','warp_on_change_workspace'),
                    ('cursorZoomFactor','zoom_factor'),
                    ('cursorInactiveTimeout','inactive_timeout'),
                    ('cursorHideOnKeyPress','hide_on_key_press'),
                    ('cursorHideOnTouch','hide_on_touch'),
                    ('cursorHideOnTablet','hide_on_tablet')]),
        ('gestures', [('workspaceSwipeCreateNew','workspace_swipe_create_new'),
                      ('workspaceSwipeForever','workspace_swipe_forever'),
                      ('workspaceSwipeCancelRatio','workspace_swipe_cancel_ratio'),
                      ('workspaceSwipeMinSpeedToForce','workspace_swipe_min_speed_to_force'),
                      ('workspaceSwipeDirectionLock','workspace_swipe_direction_lock'),
                      ('workspaceSwipeDistance','workspace_swipe_distance'),
                      ('workspaceSwipeInvert','workspace_swipe_invert'),
                      ('workspaceSwipeTouch','workspace_swipe_touch'),
                      ('workspaceSwipeTouchInvert','workspace_swipe_touch_invert')]),
        ('misc', [('vrr','vrr'), ('mouseMoveEnablesDpms','mouse_move_enables_dpms'),
                  ('mouseMoveEnablesDpms','mouse_move_enables_dpms'),
                  ('keyPressEnablesDpms','key_press_enables_dpms'),
                  ('disableAutoreload','disable_autoreload'),
                  ('focusOnActivate','focus_on_activate'),
                  ('animateManualResizes','animate_manual_resizes'),
                  ('animateMouseWindowdragging','animate_mouse_windowdragging'),
                  ('disableHyprlandLogo','disable_hyprland_logo'),
                  ('disableSplashRendering','disable_splash_rendering'),
                  ('forceDefaultWallpaper','force_default_wallpaper'),
                  ]),
        ('xwayland', [('xwaylandEnabled','enabled'),
                      ('xwaylandForceZeroScaling','force_zero_scaling'),
                      ('xwaylandUseNearestNeighbor','use_nearest_neighbor')]),
    ]:
        lines.append('')
        lines.append(sec_name + ' {')
        for ck, kw in keys:
            if ck in cfg: lines.append('  ' + kw + ' = ' + fmt(cfg[ck]))
        lines.append('}')

    lines.append('# === END COMPOSITOR ===')
    return '\n'.join(lines) + '\n'

# ============================================================================
#  hyprland.lua - hl.config() syntax  
# ============================================================================
def build_lua_block():
    lines = [
        '-- === AMBXST COMPOSITOR ===',
        '-- Ambxst compositor settings',
        'hl.config({',
    ]

    _is_free = cfg.get('layout') == 'free'

    sections = {
        'general': [('borderSize','border_size'), ('gapsIn','gaps_in'), ('gapsOut','gaps_out'),
                    ('allowTearing','allow_tearing'), ('resizeOnBorder','resize_on_border'),
                    ('extendBorderGrabArea','extend_border_grab_area'),
                    ('hoverIconOnBorder','hover_icon_on_border'),
        ] + ([] if _is_free else [('layout','layout')]),
        'decoration': [('rounding','rounding'), ('roundingPower','rounding_power'),
                       ('activeOpacity','active_opacity'), ('inactiveOpacity','inactive_opacity'),
                       ('fullscreenOpacity','fullscreen_opacity'),
                       ('dimInactive','dim_inactive'), ('dimStrength','dim_strength'),
                       ('dimAround','dim_around'), ('dimSpecial','dim_special')],
        'input': [('kbLayout','kb_layout'), ('kbVariant','kb_variant'),
                  ('kbOptions','kb_options'),
                  ('numlockByDefault','numlock_by_default'),
                  ('repeatRate','repeat_rate'), ('repeatDelay','repeat_delay'),
                  ('mouseSensitivity','sensitivity'),
                  ('followMouse','follow_mouse'),
                  ('mouseNaturalScroll','natural_scroll'),
                  ('mouseScrollFactor','scroll_factor'),
                  ('mouseLeftHanded','left_handed'),
                  ('mouseRefocus','mouse_refocus'),
                  ('floatSwitchOverrideFocus','float_switch_override_focus')],
        'cursor': [('noHardwareCursors','no_hardware_cursors'),
                   ('enableHyprcursor','enable_hyprcursor'), ('noWarps','no_warps'),
                   ('persistentWarps','persistent_warps'),
                   ('warpOnChangeWorkspace','warp_on_change_workspace'),
                   ('cursorZoomFactor','zoom_factor'),
                   ('cursorInactiveTimeout','inactive_timeout'),
                   ('cursorHideOnKeyPress','hide_on_key_press'),
                   ('cursorHideOnTouch','hide_on_touch'),
                   ('cursorHideOnTablet','hide_on_tablet')],
        'gestures': [('workspaceSwipeCreateNew','workspace_swipe_create_new'),
                     ('workspaceSwipeForever','workspace_swipe_forever'),
                     ('workspaceSwipeCancelRatio','workspace_swipe_cancel_ratio'),
                     ('workspaceSwipeMinSpeedToForce','workspace_swipe_min_speed_to_force'),
                     ('workspaceSwipeDirectionLock','workspace_swipe_direction_lock'),
                     ('workspaceSwipeDistance','workspace_swipe_distance'),
                     ('workspaceSwipeInvert','workspace_swipe_invert'),
                     ('workspaceSwipeTouch','workspace_swipe_touch'),
                     ('workspaceSwipeTouchInvert','workspace_swipe_touch_invert')],
        'misc': [('vrr','vrr'),
                 ('mouseMoveEnablesDpms','mouse_move_enables_dpms'),
                 ('keyPressEnablesDpms','key_press_enables_dpms'),
                 ('disableAutoreload','disable_autoreload'),
                 ('focusOnActivate','focus_on_activate'),
                 ('animateManualResizes','animate_manual_resizes'),
                 ('animateMouseWindowdragging','animate_mouse_windowdragging'),
                 ('disableHyprlandLogo','disable_hyprland_logo'),
                 ('disableSplashRendering','disable_splash_rendering'),
                 ('forceDefaultWallpaper','force_default_wallpaper'),
                 ],
        'xwayland': [('xwaylandEnabled','enabled'),
                     ('xwaylandForceZeroScaling','force_zero_scaling'),
                     ('xwaylandUseNearestNeighbor','use_nearest_neighbor')],
        'dwindle': [('dwindlePreserveSplit','preserve_split'),
                    ('dwindlePseudotile','pseudotile'),
                    ('dwindleForceSplit','force_split'),
                    ('dwindleSmartSplit','smart_split'),
                    ('dwindleDefaultSplitRatio','default_split_ratio'),
                    ('dwindleSplitWidthMultiplier','split_width_multiplier'),
                    ('dwindlePermanentDirectionOverride','permanent_direction_override'),
                    ('dwindleUseActiveForSplits','use_active_for_splits'),
                    ('dwindleSmartResizing','smart_resizing')],
        'master': [('masterOrientation','orientation'), ('masterMfact','mfact'),
                   ('masterNewStatus','new_status'), ('masterNewOnTop','new_on_top'),
                   ('masterNewOnActive','new_on_active'),
                   ('masterSmartResizing','smart_resizing'),
                   ('masterAllowSmallSplit','allow_small_split')],
        'scrolling': [('scrollingColumnWidth','column_width'),
                      ('scrollingExplicitColumnWidths','explicit_column_widths'),
                      ('scrollingDirection','direction'),
                      ('scrollingFullscreenOnOneColumn','fullscreen_on_one_column'),
                      ('scrollingFocusFitMethod','focus_fit_method'),
                      ('scrollingFollowFocus','follow_focus'),
                      ('scrollingFollowMinVisible','follow_min_visible')],
    }

    for section, keys in sections.items():
        lines.append(f'    {section} = {{')
        for ck, kw in keys:
            if ck in cfg:
                lines.append(f'        {kw} = {fmt_lua(cfg[ck])},')
        lines.append('    },')

    lines.append('})')

    # Free Layout: windowrule float for all windows (lua syntax)
    if _is_free:
        # Insert at the top, right after the marker
        lines.insert(2, '-- Free Layout: float all windows')
        lines.insert(3, '-- hl.windowrule("float, class:.*") - old syntax')
        lines.insert(4, 'hl.windowrule("match:class .*, float on")')
        lines.insert(4, '')

    lines.append('-- === END COMPOSITOR ===')
    return '\n'.join(lines) + '\n'

# ============================================================================
#  axctl.toml - TOML format (syncs compositor settings to axctl daemon)
# ============================================================================
def build_toml_block():
    """Build the compositor settings section for axctl.toml."""
    lines = ['# === AMBXST COMPOSITOR ===', '# Synced from compositor.json', '']

    def toml_val(val):
        if isinstance(val, bool):
            return 'true' if val else 'false'
        if isinstance(val, list):
            return '[' + ', '.join(toml_val(v) for v in val) + ']'
        if isinstance(val, float):
            s = f'{val:.2f}'.rstrip('0').rstrip('.')
            return s if '.' in s else s + '.0'
        if isinstance(val, str):
            return '"' + val.replace('\\', '\\\\').replace('"', '\\"') + '"'
        return str(val)

    def fmt_t(val, fixed=None):
        if isinstance(val, bool):
            return 'true' if val else 'false'
        if isinstance(val, float):
            if fixed:
                return f'{val:.{fixed}f}'
            return str(val)
        if isinstance(val, int):
            return str(val)
        return str(val)

    # Gaps
    if 'gapsIn' in cfg or 'gapsOut' in cfg:
        lines.append('[appearance.gaps]')
        if 'gapsIn' in cfg: lines.append(f'inner = {cfg["gapsIn"]}')
        if 'gapsOut' in cfg: lines.append(f'outer = {cfg["gapsOut"]}')
        lines.append('')

    # Border
    lines.append('[appearance.border]')
    if 'borderSize' in cfg: lines.append(f'width = {cfg["borderSize"]}')
    if 'rounding' in cfg: lines.append(f'rounding = {cfg["rounding"]}')
    if 'roundingPower' in cfg: lines.append(f'rounding_power = {fmt_t(cfg["roundingPower"], 1)}')
    lines.append('')

    # Opacity
    lines.append('[appearance.opacity]')
    if 'activeOpacity' in cfg: lines.append(f'active = {fmt_t(cfg["activeOpacity"], 2)}')
    if 'inactiveOpacity' in cfg: lines.append(f'inactive = {fmt_t(cfg["inactiveOpacity"], 2)}')
    if 'fullscreenOpacity' in cfg: lines.append(f'fullscreen = {fmt_t(cfg["fullscreenOpacity"], 2)}')
    lines.append('')

    # Dim
    lines.append('[appearance.dim]')
    if 'dimInactive' in cfg: lines.append(f'enabled = {fmt_t(cfg["dimInactive"])}')
    if 'dimStrength' in cfg: lines.append(f'strength = {fmt_t(cfg["dimStrength"], 2)}')
    if 'dimAround' in cfg: lines.append(f'around = {fmt_t(cfg["dimAround"], 2)}')
    if 'dimSpecial' in cfg: lines.append(f'special = {fmt_t(cfg["dimSpecial"], 2)}')
    lines.append('')

    # Blur
    lines.append('[appearance.blur]')
    if 'blurEnabled' in cfg: lines.append(f'enabled = {fmt_t(cfg["blurEnabled"])}')
    if 'blurSize' in cfg: lines.append(f'size = {cfg["blurSize"]}')
    if 'blurPasses' in cfg: lines.append(f'passes = {cfg["blurPasses"]}')
    if 'blurIgnoreOpacity' in cfg: lines.append(f'ignore_opacity = {fmt_t(cfg["blurIgnoreOpacity"])}')
    if 'blurNewOptimizations' in cfg: lines.append(f'new_optimizations = {fmt_t(cfg["blurNewOptimizations"])}')
    if 'blurXray' in cfg: lines.append(f'xray = {fmt_t(cfg["blurXray"])}')
    if 'blurNoise' in cfg: lines.append(f'noise = {fmt_t(cfg["blurNoise"], 3)}')
    if 'blurContrast' in cfg: lines.append(f'contrast = {fmt_t(cfg["blurContrast"], 2)}')
    if 'blurBrightness' in cfg: lines.append(f'brightness = {fmt_t(cfg["blurBrightness"], 2)}')
    if 'blurVibrancy' in cfg: lines.append(f'vibrancy = {fmt_t(cfg["blurVibrancy"], 2)}')
    if 'blurVibrancyDarkness' in cfg: lines.append(f'vibrancy_darkness = {fmt_t(cfg["blurVibrancyDarkness"], 2)}')
    if 'blurSpecial' in cfg: lines.append(f'special = {fmt_t(cfg["blurSpecial"])}')
    if 'blurPopups' in cfg: lines.append(f'popups = {fmt_t(cfg["blurPopups"])}')
    lines.append('')

    # Shadow
    lines.append('[appearance.shadow]')
    if 'shadowEnabled' in cfg: lines.append(f'enabled = {fmt_t(cfg["shadowEnabled"])}')
    if 'shadowRange' in cfg: lines.append(f'range = {cfg["shadowRange"]}')
    if 'shadowRenderPower' in cfg: lines.append(f'render_power = {cfg["shadowRenderPower"]}')
    if 'shadowOffset' in cfg: lines.append(f'offset = {toml_val(cfg["shadowOffset"])}')
    if 'shadowScale' in cfg: lines.append(f'scale = {fmt_t(cfg["shadowScale"], 2)}')
    lines.append('')

    # Animations
    lines.append('[appearance.animations]')
    if 'animationsEnabled' in cfg: lines.append(f'enabled = {fmt_t(cfg["animationsEnabled"])}')
    lines.append('')

    # General
    _is_free = cfg.get('layout') == 'free'
    lines.append('[general]')
    if 'layout' in cfg and not _is_free: lines.append(f'layout = {toml_val(cfg["layout"])}')
    if 'allowTearing' in cfg: lines.append(f'allow_tearing = {fmt_t(cfg["allowTearing"])}')
    if 'resizeOnBorder' in cfg: lines.append(f'resize_on_border = {fmt_t(cfg["resizeOnBorder"])}')
    if 'extendBorderGrabArea' in cfg: lines.append(f'extend_border_grab_area = {cfg["extendBorderGrabArea"]}')
    if 'hoverIconOnBorder' in cfg: lines.append(f'hover_icon_on_border = {fmt_t(cfg["hoverIconOnBorder"])}')
    lines.append('')

    # Free Layout grid & snap config
    if _is_free:
        lines.append('[general.free]')
        if 'freeGridSize' in cfg: lines.append(f'grid_size = {cfg["freeGridSize"]}')
        if 'freeSnapSensitivity' in cfg: lines.append(f'snap_sensitivity = {cfg["freeSnapSensitivity"]}')
        if 'freeSnapEdges' in cfg: lines.append(f'snap_edges = {fmt_t(cfg["freeSnapEdges"])}')
        if 'freeSnapCenter' in cfg: lines.append(f'snap_center = {fmt_t(cfg["freeSnapCenter"])}')
        if 'freeSnapGaps' in cfg: lines.append(f'snap_gaps = {cfg["freeSnapGaps"]}')
        if 'freeTileByDefault' in cfg: lines.append(f'tile_by_default = {fmt_t(cfg["freeTileByDefault"])}')
        if 'freeMaximizedByDefault' in cfg: lines.append(f'maximized_by_default = {fmt_t(cfg["freeMaximizedByDefault"])}')
        lines.append('')

    # Snap
    lines.append('[general.snap]')
    if 'snapEnabled' in cfg: lines.append(f'enabled = {fmt_t(cfg["snapEnabled"])}')
    if 'snapWindowGap' in cfg: lines.append(f'window_gap = {cfg["snapWindowGap"]}')
    if 'snapMonitorGap' in cfg: lines.append(f'monitor_gap = {cfg["snapMonitorGap"]}')
    if 'snapBorderOverlap' in cfg: lines.append(f'border_overlap = {fmt_t(cfg["snapBorderOverlap"])}')
    if 'snapRespectGaps' in cfg: lines.append(f'respect_gaps = {fmt_t(cfg["snapRespectGaps"])}')
    lines.append('')

    lines.append('# === END COMPOSITOR ===')
    return '\n'.join(lines) + '\n'


# ============================================================================
#  FILE WRITING
# ============================================================================

marker = '# === AMBXST COMPOSITOR ==='
end_marker = '# === END COMPOSITOR ==='
lua_marker = '-- === AMBXST COMPOSITOR ==='
lua_end_marker = '-- === END COMPOSITOR ==='

binds_marker = '# === AMBXST KEYBINDS ==='
binds_end_marker = '# === END KEYBINDS ==='
lua_binds_marker = '-- === AMBXST KEYBINDS ==='
lua_binds_end_marker = '-- === END KEYBINDS ==='

conf_block = build_conf_block()
lua_block = build_lua_block()
binds_block, lua_binds_block = build_binds_block()

# --- hyprland.conf ---
with open(CONF_PATH) as f:
    content = f.read()

# Remove and re-insert compositor block
content = re.sub(re.escape(marker) + '.*?' + re.escape(end_marker), '', content, flags=re.DOTALL).strip()
content += '\n' + conf_block

# Remove and re-insert keybinds block
if binds_block:
    content = re.sub(re.escape(binds_marker) + '.*?' + re.escape(binds_end_marker), '', content, flags=re.DOTALL).strip()
    content += '\n' + binds_block

with open(CONF_PATH, 'w') as f:
    f.write(content)
print(f'hyprland.conf: {len(conf_block)} chars (compositor), {len(binds_block)} chars (keybinds)')

# --- hyprland.lua ---
with open(LUA_PATH) as f:
    content = f.read()

content = re.sub(re.escape(lua_marker) + '.*?' + re.escape(lua_end_marker), '', content, flags=re.DOTALL).strip()
content += '\n' + lua_block

if lua_binds_block:
    content = re.sub(re.escape(lua_binds_marker) + '.*?' + re.escape(lua_binds_end_marker), '', content, flags=re.DOTALL).strip()
    content += '\n' + lua_binds_block

with open(LUA_PATH, 'w') as f:
    f.write(content)
print(f'hyprland.lua: {len(lua_block)} chars (compositor), {len(lua_binds_block)} chars (keybinds)')

# --- axctl.toml ---
toml_block = build_toml_block()

try:
    with open(AXCTL_TOML_PATH) as f:
        toml_content = f.read()

    # Remove everything from [appearance] through the last section before [[keybinds]]
    # This clears old values from CompositorTomlWriter that may conflict
    pattern = re.compile(
        r'\n?\[appearance\].*?(?=\n?\[\[keybinds\]\]|\n?# === AMBXST|\Z)',
        re.DOTALL
    )
    toml_content = pattern.sub('', toml_content).strip()

    # Also remove old marker block if present
    toml_content = re.sub(
        re.escape('# === AMBXST COMPOSITOR ===') + '.*?' + re.escape('# === END COMPOSITOR ==='),
        '', toml_content, flags=re.DOTALL
    ).strip()

    # Insert the new block after [startup] section, before [[keybinds]]
    # Find insertion point: either before [[keybinds]] or at end of file
    keybinds_match = re.search(r'^\[\[keybinds\]\]', toml_content, re.MULTILINE)
    if keybinds_match:
        # Find the line before [[keybinds]] and insert there
        before = toml_content[:keybinds_match.start()].rstrip()
        after = toml_content[keybinds_match.start():]
        toml_content = before + '\n\n' + toml_block.strip() + '\n\n' + after
    else:
        toml_content += '\n\n' + toml_block

    with open(AXCTL_TOML_PATH, 'w') as f:
        f.write(toml_content)
    print(f'axctl.toml: {len(toml_block)} chars (synced)')
except FileNotFoundError:
    print(f'axctl.toml: CREATED at {AXCTL_TOML_PATH}')
    with open(AXCTL_TOML_PATH, 'w') as f:
        f.write(toml_block)
    print(f'axctl.toml: {len(toml_block)} chars')

print('Done - hyprctl reload & axctl config reload recommended')
