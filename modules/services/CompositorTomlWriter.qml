pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.modules.globals
import "../../config/KeybindActions.js" as KeybindActions

/**
 * CompositorTomlWriter - Generates TOML configuration for axctl
 * Writes to ~/.local/share/nothingless/axctl.toml
 */
Singleton {
    id: root

    property string outputPath: (Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")) + "/nothingless/axctl.toml"

    property Process writeProcess: Process {
        running: false
        stdout: SplitParser {}
    }
    property Process hyprctlProcess: Process {
        running: false
        stdout: SplitParser {}
    }

    function getColorValue(colorName) {
        const resolved = Config.resolveColor(colorName);
        return (typeof resolved === 'string') ? Qt.color(resolved) : resolved;
    }

    function formatColorForCompositor(color) {
        const r = Math.round(color.r * 255).toString(16).padStart(2, '0');
        const g = Math.round(color.g * 255).toString(16).padStart(2, '0');
        const b = Math.round(color.b * 255).toString(16).padStart(2, '0');
        const a = Math.round(color.a * 255).toString(16).padStart(2, '0');

        if (color.a === 1.0) {
            return `rgb(${r}${g}${b})`;
        } else {
            return `rgba(${r}${g}${b}${a})`;
        }
    }

    function colorToHex(color, includeAlpha = false) {
        const r = Math.round(color.r * 255).toString(16).padStart(2, '0');
        const g = Math.round(color.g * 255).toString(16).padStart(2, '0');
        const b = Math.round(color.b * 255).toString(16).padStart(2, '0');

        if (includeAlpha) {
            const a = Math.round(color.a * 255).toString(16).padStart(2, '0');
            return `#${r}${g}${b}${a}`;
        }
        return `#${r}${g}${b}`;
    }

    function resolveColorToHex(colorName, alpha = 1.0) {
        const resolved = Config.resolveColor(colorName);
        const color = (typeof resolved === 'string') ? Qt.color(resolved) : resolved;
        if (alpha < 1.0) {
            return colorToHex(Qt.rgba(color.r, color.g, color.b, alpha), true);
        }
        return colorToHex(color, false);
    }

    function formatBorderColors(colorNames, angle) {
        if (!colorNames || colorNames.length === 0) {
            return [];
        }
        
        if (colorNames.length > 1) {
            // Multi-color gradient
            const formattedColors = colorNames.map(colorName => {
                const color = getColorValue(colorName);
                return formatColorForCompositor(color);
            }).join(" ");
            return [`${formattedColors} ${angle}deg`];
        } else {
            // Single color
            const color = getColorValue(colorNames[0]);
            return [formatColorForCompositor(color)];
        }
    }

    function formatInactiveBorderColors(colorNames, angle) {
        if (!colorNames || colorNames.length === 0) {
            return [];
        }
        
        if (colorNames.length > 1) {
            // Multi-color gradient - force full opacity
            const formattedColors = colorNames.map(colorName => {
                const color = getColorValue(colorName);
                const colorWithFullOpacity = Qt.rgba(color.r, color.g, color.b, 1.0);
                return formatColorForCompositor(colorWithFullOpacity);
            }).join(" ");
            return [`${formattedColors} ${angle}deg`];
        } else {
            // Single color - force full opacity
            const color = getColorValue(colorNames[0] || "surface");
            const colorWithFullOpacity = Qt.rgba(color.r, color.g, color.b, 1.0);
            return [formatColorForCompositor(colorWithFullOpacity)];
        }
    }

    function formatShadowColors(colorName, opacity) {
        const color = getColorValue(colorName);
        const colorWithOpacity = Qt.rgba(color.r, color.g, color.b, color.a * opacity);
        return formatColorForCompositor(colorWithOpacity);
    }

    function getBarOrientation() {
        const position = Config.bar.position || "top";
        return (position === "left" || position === "right") ? "vertical" : "horizontal";
    }

    function calculateIgnoreAlpha() {
        let ignoreAlphaValue = 0.0;

        if (Config.compositor.blurExplicitIgnoreAlpha) {
            ignoreAlphaValue = Config.compositor.blurIgnoreAlphaValue;
        } else {
            const barBgOpacity = (Config.theme.srBarBg && Config.theme.srBarBg.opacity !== undefined) ? Config.theme.srBarBg.opacity : 0;
            const bgOpacity = (Config.theme.srBg && Config.theme.srBg.opacity !== undefined) ? Config.theme.srBg.opacity : 1.0;
            ignoreAlphaValue = (barBgOpacity > 0 ? Math.min(barBgOpacity, bgOpacity) : bgOpacity);
        }

        return ignoreAlphaValue.toFixed(2);
    }

    function generateToml() {
        let toml = "";

        toml += "[startup]\n";
        toml += "exec-once = \"nothingless\"\n";

        function tomlEscape(str) {
            if (str === null || str === undefined)
                return "";
            return String(str)
                .replace(/\\/g, "\\\\")
                .replace(/\"/g, "\\\"")
                .replace(/\n/g, "\\n");
        }

        function tomlString(str) {
            return "\"" + tomlEscape(str) + "\"";
        }

        function tomlStringArray(arr) {
            if (!arr || arr.length === 0)
                return "[]";
            const parts = arr.map(s => tomlString(s));
            return "[" + parts.join(", ") + "]";
        }

        function pushKeybindEntry(modifiers, key, dispatcher, argument, flags) {
            if (!key || String(key).trim().length === 0)
                return;
            const normalized = normalizeKeybindDispatcher(dispatcher || "", argument || "");
            toml += "\n[[keybinds]]\n";
            toml += `modifiers = ${tomlStringArray(modifiers || [])}\n`;
            toml += `key = ${tomlString(String(key))}\n`;
            toml += `dispatcher = ${tomlString(normalized.dispatcher)}\n`;
            toml += `argument = ${tomlString(normalized.argument)}\n`;
            toml += `flags = ${tomlString(flags || "")}\n`;
            toml += "enabled = true\n";
        }

        function normalizeKeybindDispatcher(dispatcher, argument) {
            if (dispatcher === "layoutmsg") {
                if (argument.indexOf("focus ") === 0) {
                    return { dispatcher: "movefocus", argument: argument.split(" ")[1] || "" };
                }
                if (argument.indexOf("movewindowto ") === 0) {
                    return { dispatcher: "movewindow", argument: argument.split(" ")[1] || "" };
                }
            }
            return { dispatcher: dispatcher, argument: argument };
        }

        function resolveBindAction(action, fallback) {
            const resolved = KeybindActions.resolveAction(action || fallback);
            if (!resolved) return null;
            return {
                dispatcher: resolved.dispatcher || "",
                argument: resolved.argument || "",
                flags: resolved.flags || ""
            };
        }

        function actionCompatibleWithLayout(action) {
            if (!action)
                return false;
            if (!action.layouts || action.layouts.length === 0)
                return true;
            return action.layouts.indexOf(GlobalStates.compositorLayout) !== -1;
        }

        // Appearance section
        toml += "[appearance]\n";

        // Gaps
        toml += "[appearance.gaps]\n";
        toml += `inner = ${Config.compositor.gapsIn}\n`;
        toml += `outer = ${Config.compositor.gapsOut}\n`;

        // Border
        toml += "[appearance.border]\n";
        toml += `width = ${Config.compositorBorderSize}\n`;

        // Active border colors (supports gradients)
        const borderColors = Config.compositor.syncBorderColor ? [Config.compositorBorderColor] : Config.compositor.activeBorderColor;
        const activeBorderFormatted = formatBorderColors(borderColors || ["primary"], Config.compositor.borderAngle);
        if (activeBorderFormatted.length > 0) {
            toml += `active_color = "${activeBorderFormatted[0]}"\n`;
        }

        // Inactive border colors (supports gradients)
        const inactiveBorderColors = Config.compositor.inactiveBorderColor;
        const inactiveBorderFormatted = formatInactiveBorderColors(inactiveBorderColors, Config.compositor.inactiveBorderAngle);
        if (inactiveBorderFormatted.length > 0) {
            toml += `inactive_color = "${inactiveBorderFormatted[0]}"\n`;
        }

        toml += `rounding = ${Config.compositorRounding}\n`;

        // Opacity
        toml += "[appearance.opacity]\n";
        toml += `active = ${Config.compositor.activeOpacity.toFixed(2)}\n`;
        toml += `inactive = ${Config.compositor.inactiveOpacity.toFixed(2)}\n`;
        toml += `fullscreen = ${Config.compositor.fullscreenOpacity.toFixed(2)}\n`;

        // Dim
        toml += "[appearance.dim]\n";
        toml += `enabled = ${Config.compositor.dimInactive}\n`;
        toml += `strength = ${Config.compositor.dimStrength.toFixed(2)}\n`;
        toml += `around = ${Config.compositor.dimAround.toFixed(2)}\n`;
        toml += `special = ${Config.compositor.dimSpecial.toFixed(2)}\n`;

        // Blur - all settings
        toml += "[appearance.blur]\n";
        toml += `enabled = ${Config.compositor.blurEnabled}\n`;
        toml += `size = ${Config.compositor.blurSize}\n`;
        toml += `passes = ${Config.compositor.blurPasses}\n`;
        toml += `ignore_opacity = ${Config.compositor.blurIgnoreOpacity}\n`;
        toml += `new_optimizations = ${Config.compositor.blurNewOptimizations}\n`;
        toml += `xray = ${Config.compositor.blurXray}\n`;
        toml += `noise = ${Config.compositor.blurNoise.toFixed(3)}\n`;
        toml += `contrast = ${Config.compositor.blurContrast.toFixed(2)}\n`;
        toml += `brightness = ${Config.compositor.blurBrightness.toFixed(2)}\n`;
        toml += `vibrancy = ${Config.compositor.blurVibrancy.toFixed(2)}\n`;
        toml += `vibrancy_darkness = ${Config.compositor.blurVibrancyDarkness.toFixed(2)}\n`;
        toml += `special = ${Config.compositor.blurSpecial}\n`;
        toml += `popups = ${Config.compositor.blurPopups}\n`;

        // Shadow - all settings
        toml += "[appearance.shadow]\n";
        toml += `enabled = ${Config.compositor.shadowEnabled}\n`;
        toml += `range = ${Config.compositor.shadowRange}\n`;
        toml += `render_power = ${Config.compositor.shadowRenderPower}\n`;
        toml += `sharp = ${Config.compositor.shadowSharp}\n`;
        toml += `ignore_window = ${Config.compositor.shadowIgnoreWindow}\n`;
        toml += `offset = "${Config.compositor.shadowOffset}"\n`;
        toml += `scale = ${Config.compositor.shadowScale.toFixed(2)}\n`;
        const shadowColorFormatted = formatShadowColors(Config.compositorShadowColor, Config.compositorShadowOpacity);
        toml += `color = "${shadowColorFormatted}"\n`;
        const inactiveShadowColorFormatted = formatShadowColors(Config.compositor.shadowColorInactive, Config.compositorShadowOpacity);
        toml += `color_inactive = "${inactiveShadowColorFormatted}"\n`;

        // Animations
        toml += "[appearance.animations]\n";
        toml += `enabled = ${Config.compositor.animationsEnabled}\n`;

        // General
        toml += "\n[general]\n";
        if (GlobalStates.compositorLayout && GlobalStates.compositorLayout.length > 0) {
            toml += `layout = "${GlobalStates.compositorLayout}"\n`;
        }
        toml += `allow_tearing = ${Config.compositor.allowTearing}\n`;
        toml += `resize_on_border = ${Config.compositor.resizeOnBorder}\n`;
        toml += `extend_border_grab_area = ${Config.compositor.extendBorderGrabArea}\n`;
        toml += `hover_icon_on_border = ${Config.compositor.hoverIconOnBorder}\n`;

        // Snap
        toml += "\n[general.snap]\n";
        toml += `enabled = ${Config.compositor.snapEnabled}\n`;
        toml += `window_gap = ${Config.compositor.snapWindowGap}\n`;
        toml += `monitor_gap = ${Config.compositor.snapMonitorGap}\n`;
        toml += `border_overlap = ${Config.compositor.snapBorderOverlap}\n`;
        toml += `respect_gaps = ${Config.compositor.snapRespectGaps}\n`;

        // Keybinds
        if (Config.keybindsLoader.loaded && Config.keybindsLoader.adapter) {
            const adapter = Config.keybindsLoader.adapter;
            const nothingless = adapter.nothingless;

            function pushCoreBind(keybind) {
                if (!keybind)
                    return;
                const resolved = resolveBindAction(keybind.action, keybind);
                if (!resolved)
                    return;
                pushKeybindEntry(
                    keybind.modifiers || [],
                    keybind.key || "",
                    resolved.dispatcher,
                    resolved.argument,
                    resolved.flags
                );
            }

            if (nothingless) {
                pushCoreBind(nothingless.launcher);
                pushCoreBind(nothingless.dashboard);
                pushCoreBind(nothingless.assistant);
                pushCoreBind(nothingless.clipboard);
                pushCoreBind(nothingless.emoji);
                pushCoreBind(nothingless.notes);
                pushCoreBind(nothingless.tmux);
                pushCoreBind(nothingless.wallpapers);

                if (nothingless.system) {
                    pushCoreBind(nothingless.system.overview);
                    pushCoreBind(nothingless.system.powermenu);
                    pushCoreBind(nothingless.system.config);
                    pushCoreBind(nothingless.system.lockscreen);
                    pushCoreBind(nothingless.system.tools);
                    pushCoreBind(nothingless.system.screenshot);
                    pushCoreBind(nothingless.system.screenrecord);
                    pushCoreBind(nothingless.system.lens);
                    if (nothingless.system.reload) pushCoreBind(nothingless.system.reload);
                    if (nothingless.system.quit) pushCoreBind(nothingless.system.quit);
                    if (nothingless.system && nothingless.system["toggle-metrics"]) pushCoreBind(nothingless.system["toggle-metrics"]);
                }
            }

            if (adapter.custom && adapter.custom.length > 0) {
                for (let i = 0; i < adapter.custom.length; i++) {
                    const bind = adapter.custom[i];
                    if (bind && bind.enabled === false)
                        continue;

                    if (bind && bind.keys && bind.actions) {
                        for (let k = 0; k < bind.keys.length; k++) {
                            const keyObj = bind.keys[k];
                            if (!keyObj || !keyObj.key)
                                continue;
                            for (let a = 0; a < bind.actions.length; a++) {
                                const action = bind.actions[a];
                                if (!actionCompatibleWithLayout(action))
                                    continue;
                                const resolved = resolveBindAction(action, action);
                                if (!resolved)
                                    continue;
                                pushKeybindEntry(
                                    keyObj.modifiers || [],
                                    keyObj.key || "",
                                    resolved.dispatcher,
                                    resolved.argument,
                                    resolved.flags
                                );
                            }
                        }
                    } else if (bind) {
                        // Legacy single-key format
                        const resolved = resolveBindAction(bind.action, bind);
                        if (!resolved)
                            continue;
                        pushKeybindEntry(
                            bind.modifiers || [],
                            bind.key || "",
                            resolved.dispatcher,
                            resolved.argument,
                            resolved.flags
                        );
                    }
                }
            }
        }

        // Layer rules for quickshell
        toml += "\n[[layer_rules]]\n";
        toml += "namespace = \"quickshell\"\n";
        toml += "no_anim = true\n";

        toml += "\n[[layer_rules]]\n";
        toml += "namespace = \"quickshell\"\n";
        toml += "blur = true\n";

        toml += "\n[[layer_rules]]\n";
        toml += "namespace = \"quickshell\"\n";
        toml += "blur_popups = true\n";

        // Dynamic ignorealpha based on blur settings
        const ignoreAlphaValue = calculateIgnoreAlpha();
        toml += "\n[[layer_rules]]\n";
        toml += "namespace = \"quickshell\"\n";
        toml += "ignore_alpha = true\n";
        toml += `ignore_alpha_value = ${ignoreAlphaValue}\n`;
        // Additional layer rules
        toml += "\n[[layer_rules]]\n";
        toml += "namespace = \"selection\"\n";
        toml += "no_anim = true\n";

        toml += "\n[[layer_rules]]\n";
        toml += "namespace = \"fabric\"\n";
        toml += "blur = true\n";
        toml += "ignore_alpha_value = 0.4\n";

        toml += "\n[[layer_rules]]\n";
        toml += "namespace = \"nothingless\"\n";
        toml += "blur = true\n";
        toml += "blur_popups = true\n";
        toml += "no_anim = true\n";
        toml += "ignore_alpha_value = 0.5\n";

        toml += "\n[[layer_rules]]\n";
        toml += "namespace = \"overview\"\n";
        toml += "blur = true\n";
        toml += "blur_popups = true\n";
        toml += "no_anim = true\n";

        toml += "\n[[layer_rules]]\n";
        toml += "namespace = \"presets\"\n";
        toml += "blur = true\n";
        toml += "blur_popups = true\n";
        toml += "no_anim = true\n";



        // Input section
        toml += "\n[input]\n";
        toml += "[input.keyboard]\n";
        toml += `layout = "${Config.compositor.kbLayout}"\n`;
        if (Config.compositor.kbVariant) {
            toml += `variant = "${Config.compositor.kbVariant}"\n`;
        }
        if (Config.compositor.kbOptions) {
            toml += `options = "${Config.compositor.kbOptions}"\n`;
        }
        toml += `numlock_by_default = ${Config.compositor.numlockByDefault}\n`;
        toml += `repeat_rate = ${Config.compositor.repeatRate}\n`;
        toml += `repeat_delay = ${Config.compositor.repeatDelay}\n`;

        toml += "\n[input.mouse]\n";
        toml += `sensitivity = ${Config.compositor.mouseSensitivity.toFixed(2)}\n`;
        if (Config.compositor.mouseAccelProfile) {
            toml += `accel_profile = "${Config.compositor.mouseAccelProfile}"\n`;
        }
        toml += `follow_mouse = ${Config.compositor.followMouse}\n`;
        toml += `natural_scroll = ${Config.compositor.mouseNaturalScroll}\n`;
        toml += `scroll_factor = ${Config.compositor.mouseScrollFactor.toFixed(1)}\n`;
        toml += `left_handed = ${Config.compositor.mouseLeftHanded}\n`;
        toml += `mouse_refocus = ${Config.compositor.mouseRefocus}\n`;
        toml += `float_switch_override_focus = ${Config.compositor.floatSwitchOverrideFocus}\n`;

        toml += "\n[input.touchpad]\n";
        toml += `disable_while_typing = ${Config.compositor.touchpadDisableWhileTyping}\n`;
        toml += `natural_scroll = ${Config.compositor.touchpadNaturalScroll}\n`;
        toml += `tap_to_click = ${Config.compositor.touchpadTapToClick}\n`;
        toml += `clickfinger_behavior = ${Config.compositor.touchpadClickfingerBehavior}\n`;
        if (Config.compositor.touchpadTapButtonMap) {
            toml += `tap_button_map = "${Config.compositor.touchpadTapButtonMap}"\n`;
        }
        toml += `middle_button_emulation = ${Config.compositor.touchpadMiddleButtonEmulation}\n`;
        toml += `drag_lock = ${Config.compositor.touchpadDragLock}\n`;
        toml += `scroll_factor = ${Config.compositor.touchpadScrollFactor.toFixed(1)}\n`;

        // Cursor
        toml += "\n[cursor]\n";
        toml += `no_hardware_cursors = ${Config.compositor.noHardwareCursors}\n`;
        toml += `enable_hyprcursor = ${Config.compositor.enableHyprcursor}\n`;
        toml += `no_warps = ${Config.compositor.noWarps}\n`;
        toml += `persistent_warps = ${Config.compositor.persistentWarps}\n`;
        toml += `warp_on_change_workspace = ${Config.compositor.warpOnChangeWorkspace}\n`;
        toml += `zoom_factor = ${Config.compositor.cursorZoomFactor.toFixed(1)}\n`;
        toml += `inactive_timeout = ${Config.compositor.cursorInactiveTimeout}\n`;
        toml += `hide_on_key_press = ${Config.compositor.cursorHideOnKeyPress}\n`;
        toml += `hide_on_touch = ${Config.compositor.cursorHideOnTouch}\n`;
        toml += `hide_on_tablet = ${Config.compositor.cursorHideOnTablet}\n`;

        // Gestures
        toml += "\n[gestures]\n";
        toml += "[gestures.workspace_swipe]\n";
        toml += `create_new = ${Config.compositor.workspaceSwipeCreateNew}\n`;
        toml += `forever = ${Config.compositor.workspaceSwipeForever}\n`;
        toml += `cancel_ratio = ${Config.compositor.workspaceSwipeCancelRatio.toFixed(2)}\n`;
        toml += `min_speed_to_force = ${Config.compositor.workspaceSwipeMinSpeedToForce}\n`;
        toml += `direction_lock = ${Config.compositor.workspaceSwipeDirectionLock}\n`;
        toml += `use_r = ${Config.compositor.workspaceSwipeUseR}\n`;
        toml += `distance = ${Config.compositor.workspaceSwipeDistance}\n`;
        toml += `invert = ${Config.compositor.workspaceSwipeInvert}\n`;
        toml += `touch = ${Config.compositor.workspaceSwipeTouch}\n`;
        toml += `touch_invert = ${Config.compositor.workspaceSwipeTouchInvert}\n`;

        // Dwindle
        toml += "\n[dwindle]\n";
        toml += `preserve_split = ${Config.compositor.dwindlePreserveSplit}\n`;
        toml += `pseudotile = ${Config.compositor.dwindlePseudotile}\n`;
        toml += `force_split = ${Config.compositor.dwindleForceSplit}\n`;
        toml += `smart_split = ${Config.compositor.dwindleSmartSplit}\n`;
        toml += `default_split_ratio = ${Config.compositor.dwindleDefaultSplitRatio.toFixed(2)}\n`;
        toml += `split_width_multiplier = ${Config.compositor.dwindleSplitWidthMultiplier.toFixed(1)}\n`;
        toml += `permanent_direction_override = ${Config.compositor.dwindlePermanentDirectionOverride}\n`;
        toml += `use_active_for_splits = ${Config.compositor.dwindleUseActiveForSplits}\n`;
        toml += `smart_resizing = ${Config.compositor.dwindleSmartResizing}\n`;
        toml += `special_scale_factor = ${Config.compositor.dwindleSpecialScaleFactor.toFixed(2)}\n`;

        // Master
        toml += "\n[master]\n";
        toml += `orientation = "${Config.compositor.masterOrientation}"\n`;
        toml += `mfact = ${Config.compositor.masterMfact.toFixed(2)}\n`;
        toml += `new_status = "${Config.compositor.masterNewStatus}"\n`;
        toml += `new_on_top = ${Config.compositor.masterNewOnTop}\n`;
        toml += `new_on_active = "${Config.compositor.masterNewOnActive}"\n`;
        toml += `smart_resizing = ${Config.compositor.masterSmartResizing}\n`;
        toml += `special_scale_factor = ${Config.compositor.masterSpecialScaleFactor.toFixed(2)}\n`;
        toml += `allow_small_split = ${Config.compositor.masterAllowSmallSplit}\n`;

        // Scrolling
        toml += "\n[scrolling]\n";
        toml += `column_width = ${Config.compositor.scrollingColumnWidth.toFixed(2)}\n`;
        if (Config.compositor.scrollingExplicitColumnWidths) {
            toml += `explicit_column_widths = "${Config.compositor.scrollingExplicitColumnWidths}"\n`;
        }
        toml += `direction = "${Config.compositor.scrollingDirection}"\n`;
        toml += `fullscreen_on_one_column = ${Config.compositor.scrollingFullscreenOnOneColumn}\n`;
        toml += `focus_fit_method = "${Config.compositor.scrollingFocusFitMethod}"\n`;
        toml += `follow_focus = ${Config.compositor.scrollingFollowFocus}\n`;
        toml += `follow_min_visible = ${Config.compositor.scrollingFollowMinVisible.toFixed(2)}\n`;

        // XWayland
        toml += "\n[xwayland]\n";
        toml += `enabled = ${Config.compositor.xwaylandEnabled}\n`;
        toml += `force_zero_scaling = ${Config.compositor.xwaylandForceZeroScaling}\n`;
        toml += `use_nearest_neighbor = ${Config.compositor.xwaylandUseNearestNeighbor}\n`;

        // Misc
        toml += "\n[misc]\n";
        toml += `vrr = ${Config.compositor.vrr}\n`;
        toml += `vfr = ${Config.compositor.vfr}\n`;
        toml += `mouse_move_enables_dpms = ${Config.compositor.mouseMoveEnablesDpms}\n`;
        toml += `key_press_enables_dpms = ${Config.compositor.keyPressEnablesDpms}\n`;
        toml += `disable_autoreload = ${Config.compositor.disableAutoreload}\n`;
        toml += `focus_on_activate = ${Config.compositor.focusOnActivate}\n`;
        toml += `animate_manual_resizes = ${Config.compositor.animateManualResizes}\n`;
        toml += `animate_mouse_windowdragging = ${Config.compositor.animateMouseWindowdragging}\n`;
        toml += `disable_hyprland_logo = ${Config.compositor.disableHyprlandLogo}\n`;
        toml += `disable_splash_rendering = ${Config.compositor.disableSplashRendering}\n`;
        toml += `force_default_wallpaper = ${Config.compositor.forceDefaultWallpaper}\n`;
        toml += `no_update_news = ${Config.compositor.noUpdateNews}\n`;

        return toml;
    }

    function writeTomlFile() {
        const tomlContent = generateToml();
        const escapedPath = root.outputPath.replace(/'/g, "'\\''");
        const escapedContent = tomlContent.replace(/'/g, "'\\''");

        writeProcess.command = ["bash", "-c", `mkdir -p "$(dirname '${escapedPath}')" && echo '${escapedContent}' > '${escapedPath}'`];
        writeProcess.running = true;
        console.log("CompositorTomlWriter: Written TOML to", root.outputPath);
    }

    function writeHyprlandConfig() {
        const dataDir = (Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")) + "/nothingless";
        const hyprPath = dataDir + "/hyprland.conf";
        const luaPath = dataDir + "/hyprland.lua";

        // Minimal static config — only the axctl daemon exec-once.
        // NothingLess itself is started by the daemon via [startup] exec-once in axctl.toml.
        // This matches Ambxst's architecture exactly.
        let hypr = "# NothingLess auto-generated config\n";
        hypr += "# Sourced by ~/.config/hypr/hyprland.conf\n";
        hypr += "# NothingLess is started by axctl daemon, not directly by Hyprland.\n\n";

        hypr += "exec-once = axctl -c ~/.local/share/nothingless/axctl.toml daemon\n\n";

        hypr += "# Qt/Quickshell GPU acceleration\n";
        hypr += "env = QSG_RHI_BACKEND,opengl\n";
        hypr += "env = QSG_RENDER_LOOP,threaded\n";
        hypr += "env = QT_QUICK_BACKEND,opengl\n\n";

        hypr += "# Prevent Hyprland logo/wallpaper flash before NothingLess loads\n";
        hypr += "misc {\n";
        hypr += "    force_default_wallpaper = -1\n";
        hypr += "    disable_hyprland_logo = true\n";
        hypr += "}\n";

        const escPath = hyprPath.replace(/'/g, "'\\\\'");
        const escCfg = hypr.replace(/'/g, "'\\\\'");
        hyprctlProcess.command = ["bash", "-c", "mkdir -p $(dirname '" + escPath + "') && echo '" + escCfg + "' > '" + escPath + "' && echo '" + escCfg + "' > '" + luaPath.replace(/'/g, "'\\\\'") + "'"];
        hyprctlProcess.running = true;
    }

    function refresh() {
        writeTomlFile();
        writeHyprlandConfig();
    }

    Component.onCompleted: {
        Qt.callLater(() => {
            if (Config.loader.loaded) {
                refresh();
            }
        });
    }

    property Connections configConnections: Connections {
        target: Config.loader
        function onLoaded() {
            refresh();
        }
    }

    property Connections keybindsConnections: Connections {
        target: Config.keybindsLoader
        function onLoaded() { writeTomlFile(); }
        function onFileChanged() { writeTomlFile(); }
        function onAdapterUpdated() { writeTomlFile(); }
        function onPathChanged() { writeTomlFile(); }
    }

    // Compositor section connections
    property Connections compositorConnections: Connections {
        target: Config.compositor
        
        // Border settings
        function onShowBorderChanged() { writeTomlFile(); }
        function onBorderSizeChanged() { writeTomlFile(); }
        function onRoundingChanged() { writeTomlFile(); }
        function onRoundingPowerChanged() { writeTomlFile(); }
        function onGapsInChanged() { writeTomlFile(); }
        function onGapsOutChanged() { writeTomlFile(); }
        function onActiveBorderColorChanged() { writeTomlFile(); }
        function onInactiveBorderColorChanged() { writeTomlFile(); }
        function onBorderAngleChanged() { writeTomlFile(); }
        function onInactiveBorderAngleChanged() { writeTomlFile(); }
        function onResizeOnBorderChanged() { writeTomlFile(); }
        function onExtendBorderGrabAreaChanged() { writeTomlFile(); }
        function onHoverIconOnBorderChanged() { writeTomlFile(); }
        
        // Sync settings that affect derived values
        function onSyncRoundnessChanged() { writeTomlFile(); }
        function onSyncBorderWidthChanged() { writeTomlFile(); }
        function onSyncBorderColorChanged() { writeTomlFile(); }
        function onSyncShadowOpacityChanged() { writeTomlFile(); }
        function onSyncShadowColorChanged() { writeTomlFile(); }

        // Layout
        function onLayoutChanged() { writeTomlFile(); }
        function onAllowTearingChanged() { writeTomlFile(); }

        // Snap
        function onSnapEnabledChanged() { writeTomlFile(); }
        function onSnapWindowGapChanged() { writeTomlFile(); }
        function onSnapMonitorGapChanged() { writeTomlFile(); }
        function onSnapBorderOverlapChanged() { writeTomlFile(); }
        function onSnapRespectGapsChanged() { writeTomlFile(); }

        // Opacity & Dim
        function onActiveOpacityChanged() { writeTomlFile(); }
        function onInactiveOpacityChanged() { writeTomlFile(); }
        function onFullscreenOpacityChanged() { writeTomlFile(); }
        function onDimInactiveChanged() { writeTomlFile(); }
        function onDimStrengthChanged() { writeTomlFile(); }
        function onDimAroundChanged() { writeTomlFile(); }
        function onDimSpecialChanged() { writeTomlFile(); }
        
        // Shadow settings
        function onShadowEnabledChanged() { writeTomlFile(); }
        function onShadowRangeChanged() { writeTomlFile(); }
        function onShadowRenderPowerChanged() { writeTomlFile(); }
        function onShadowSharpChanged() { writeTomlFile(); }
        function onShadowIgnoreWindowChanged() { writeTomlFile(); }
        function onShadowColorChanged() { writeTomlFile(); }
        function onShadowColorInactiveChanged() { writeTomlFile(); }
        function onShadowOpacityChanged() { writeTomlFile(); }
        function onShadowOffsetChanged() { writeTomlFile(); }
        function onShadowScaleChanged() { writeTomlFile(); }
        
        // Blur settings
        function onBlurEnabledChanged() { writeTomlFile(); }
        function onBlurSizeChanged() { writeTomlFile(); }
        function onBlurPassesChanged() { writeTomlFile(); }
        function onBlurIgnoreOpacityChanged() { writeTomlFile(); }
        function onBlurExplicitIgnoreAlphaChanged() { writeTomlFile(); }
        function onBlurIgnoreAlphaValueChanged() { writeTomlFile(); }
        function onBlurNewOptimizationsChanged() { writeTomlFile(); }
        function onBlurXrayChanged() { writeTomlFile(); }
        function onBlurNoiseChanged() { writeTomlFile(); }
        function onBlurContrastChanged() { writeTomlFile(); }
        function onBlurBrightnessChanged() { writeTomlFile(); }
        function onBlurVibrancyChanged() { writeTomlFile(); }
        function onBlurVibrancyDarknessChanged() { writeTomlFile(); }
        function onBlurSpecialChanged() { writeTomlFile(); }
        function onBlurPopupsChanged() { writeTomlFile(); }
        function onBlurPopupsIgnorealphaChanged() { writeTomlFile(); }
        function onBlurInputMethodsChanged() { writeTomlFile(); }
        function onBlurInputMethodsIgnorealphaChanged() { writeTomlFile(); }

        // Animations
        function onAnimationsEnabledChanged() { writeTomlFile(); }

        // Input: Keyboard
        function onKbLayoutChanged() { writeTomlFile(); }
        function onKbVariantChanged() { writeTomlFile(); }
        function onKbOptionsChanged() { writeTomlFile(); }
        function onNumlockByDefaultChanged() { writeTomlFile(); }
        function onRepeatRateChanged() { writeTomlFile(); }
        function onRepeatDelayChanged() { writeTomlFile(); }

        // Input: Mouse
        function onMouseSensitivityChanged() { writeTomlFile(); }
        function onMouseAccelProfileChanged() { writeTomlFile(); }
        function onFollowMouseChanged() { writeTomlFile(); }
        function onMouseNaturalScrollChanged() { writeTomlFile(); }
        function onMouseScrollFactorChanged() { writeTomlFile(); }
        function onMouseLeftHandedChanged() { writeTomlFile(); }
        function onMouseRefocusChanged() { writeTomlFile(); }
        function onFloatSwitchOverrideFocusChanged() { writeTomlFile(); }

        // Input: Touchpad
        function onTouchpadDisableWhileTypingChanged() { writeTomlFile(); }
        function onTouchpadNaturalScrollChanged() { writeTomlFile(); }
        function onTouchpadTapToClickChanged() { writeTomlFile(); }
        function onTouchpadClickfingerBehaviorChanged() { writeTomlFile(); }
        function onTouchpadTapButtonMapChanged() { writeTomlFile(); }
        function onTouchpadMiddleButtonEmulationChanged() { writeTomlFile(); }
        function onTouchpadDragLockChanged() { writeTomlFile(); }
        function onTouchpadScrollFactorChanged() { writeTomlFile(); }

        // Cursor
        function onNoHardwareCursorsChanged() { writeTomlFile(); }
        function onEnableHyprcursorChanged() { writeTomlFile(); }
        function onNoWarpsChanged() { writeTomlFile(); }
        function onPersistentWarpsChanged() { writeTomlFile(); }
        function onWarpOnChangeWorkspaceChanged() { writeTomlFile(); }
        function onCursorZoomFactorChanged() { writeTomlFile(); }
        function onCursorInactiveTimeoutChanged() { writeTomlFile(); }
        function onCursorHideOnKeyPressChanged() { writeTomlFile(); }
        function onCursorHideOnTouchChanged() { writeTomlFile(); }
        function onCursorHideOnTabletChanged() { writeTomlFile(); }

        // Gestures
        function onWorkspaceSwipeCreateNewChanged() { writeTomlFile(); }
        function onWorkspaceSwipeForeverChanged() { writeTomlFile(); }
        function onWorkspaceSwipeCancelRatioChanged() { writeTomlFile(); }
        function onWorkspaceSwipeMinSpeedToForceChanged() { writeTomlFile(); }
        function onWorkspaceSwipeDirectionLockChanged() { writeTomlFile(); }
        function onWorkspaceSwipeUseRChanged() { writeTomlFile(); }
        function onWorkspaceSwipeDistanceChanged() { writeTomlFile(); }
        function onWorkspaceSwipeInvertChanged() { writeTomlFile(); }
        function onWorkspaceSwipeTouchChanged() { writeTomlFile(); }
        function onWorkspaceSwipeTouchInvertChanged() { writeTomlFile(); }

        // Dwindle
        function onDwindlePreserveSplitChanged() { writeTomlFile(); }
        function onDwindlePseudotileChanged() { writeTomlFile(); }
        function onDwindleForceSplitChanged() { writeTomlFile(); }
        function onDwindleSmartSplitChanged() { writeTomlFile(); }
        function onDwindleDefaultSplitRatioChanged() { writeTomlFile(); }
        function onDwindleSplitWidthMultiplierChanged() { writeTomlFile(); }
        function onDwindlePermanentDirectionOverrideChanged() { writeTomlFile(); }
        function onDwindleUseActiveForSplitsChanged() { writeTomlFile(); }
        function onDwindleSmartResizingChanged() { writeTomlFile(); }
        function onDwindleSpecialScaleFactorChanged() { writeTomlFile(); }

        // Master
        function onMasterOrientationChanged() { writeTomlFile(); }
        function onMasterMfactChanged() { writeTomlFile(); }
        function onMasterNewStatusChanged() { writeTomlFile(); }
        function onMasterNewOnTopChanged() { writeTomlFile(); }
        function onMasterNewOnActiveChanged() { writeTomlFile(); }
        function onMasterSmartResizingChanged() { writeTomlFile(); }
        function onMasterSpecialScaleFactorChanged() { writeTomlFile(); }
        function onMasterAllowSmallSplitChanged() { writeTomlFile(); }

        // Scrolling
        function onScrollingColumnWidthChanged() { writeTomlFile(); }
        function onScrollingExplicitColumnWidthsChanged() { writeTomlFile(); }
        function onScrollingDirectionChanged() { writeTomlFile(); }
        function onScrollingFullscreenOnOneColumnChanged() { writeTomlFile(); }
        function onScrollingFocusFitMethodChanged() { writeTomlFile(); }
        function onScrollingFollowFocusChanged() { writeTomlFile(); }
        function onScrollingFollowMinVisibleChanged() { writeTomlFile(); }

        // XWayland
        function onXwaylandEnabledChanged() { writeTomlFile(); }
        function onXwaylandForceZeroScalingChanged() { writeTomlFile(); }
        function onXwaylandUseNearestNeighborChanged() { writeTomlFile(); }

        // Monitor Globals / Misc
        function onVrrChanged() { writeTomlFile(); }
        function onVfrChanged() { writeTomlFile(); }
        function onMouseMoveEnablesDpmsChanged() { writeTomlFile(); }
        function onKeyPressEnablesDpmsChanged() { writeTomlFile(); }
        function onDisableAutoreloadChanged() { writeTomlFile(); }
        function onFocusOnActivateChanged() { writeTomlFile(); }
        function onAnimateManualResizesChanged() { writeTomlFile(); }
        function onAnimateMouseWindowdraggingChanged() { writeTomlFile(); }
        function onDisableHyprlandLogoChanged() { writeTomlFile(); }
        function onDisableSplashRenderingChanged() { writeTomlFile(); }
        function onForceDefaultWallpaperChanged() { writeTomlFile(); }
        function onNoUpdateNewsChanged() { writeTomlFile(); }
        function onEnforcePermissionsChanged() { writeTomlFile(); }
    }

    // Theme connections (for blur ignorealpha calculation and shadow color sync)
    property Connections themeConnections: Connections {
        target: Config.theme
        function onSrBarBgChanged() { writeTomlFile(); }
        function onSrBgChanged() { writeTomlFile(); }
        function onShadowColorChanged() { writeTomlFile(); }
        function onShadowOpacityChanged() { writeTomlFile(); }
    }

    // Bar position connection (for workspace animation orientation)
    property Connections barConnections: Connections {
        target: Config.bar
        function onPositionChanged() { writeTomlFile(); }
    }

    // GlobalStates connection (for layout)
    property Connections globalStatesConnections: Connections {
        target: GlobalStates
        function onCompositorLayoutChanged() { writeTomlFile(); }
    }
}
