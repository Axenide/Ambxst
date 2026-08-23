import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.services
import qs.config
import qs.modules.theme
import qs.modules.bar
import qs.modules.globals

QtObject {
    id: root

    property Process compositorProcess: Process {}

    property var currentAnimationConfig: null
    property Process readAnimationsProcess: Process {
        command: ["axctl", "config", "get-animations"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text);
                    if (Array.isArray(parsed) && parsed.length > 0) {
                        // axctl config get-animations returns [animations, beziers]
                        currentAnimationConfig = parsed;
                    }
                } catch (e) {
                    console.error("CompositorConfig: Error parsing animations:", e);
                }
            }
        }
    }

    property var barInstances: []

    function registerBar(barInstance) {
        barInstances.push(barInstance);
    }

    function getBarOrientation() {
        if (barInstances.length > 0) {
            return barInstances[0].orientation || "horizontal";
        }
        const position = Config.bar.position || "top";
        return (position === "left" || position === "right") ? "vertical" : "horizontal";
    }

    property Timer applyTimer: Timer {
        interval: 100
        repeat: false
        onTriggered: applyCompositorConfigInternal()
    }

    function getColorValue(colorName) {
        const resolved = Config.resolveColor(colorName);
        // Convert HEX string to color, or return if already a color.
        return (typeof resolved === 'string') ? Qt.color(resolved) : resolved;
    }

    function formatColorForCompositor(color) {
        // AxctlService expects colors in format: rgb(rrggbb) or rgba(rrggbbaa)
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

    // Emits a Lua literal for a JS value. Used to build the hl.config({...})
    // table that we dispatch to Hyprland via the compositor.eval JSON-RPC
    // method. Strings get JSON-style quoting (then escaped to be safe inside
    // the Lua source we build), numbers/bools map to their Lua equivalents,
    // arrays become {a, b, c}, plain objects become {key = value, ...}.
    // null/undefined become nil. Keys with hyphens (none today) are rejected.
    function luaLiteral(value) {
        if (value === null || value === undefined) return "nil";
        const t = typeof value;
        if (t === "string") {
            return JSON.stringify(value);
        }
        if (t === "number") {
            if (!isFinite(value)) return "nil";
            return String(value);
        }
        if (t === "boolean") return value ? "true" : "false";
        if (Array.isArray(value)) {
            const items = value.map(luaLiteral);
            return "{" + items.join(", ") + "}";
        }
        if (t === "object") {
            const parts = [];
            for (const key in value) {
                if (!Object.prototype.hasOwnProperty.call(value, key)) continue;
                if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(key)) continue;
                parts.push(key + " = " + luaLiteral(value[key]));
            }
            return "{" + parts.join(", ") + "}";
        }
        return "nil";
    }

    // Builds the border color value in Hyprland Lua syntax. Single colors
    // become a quoted string; multi-color gradients become a table with
    // colors/angle fields, matching the example in hyprland's repo:
    //   active_border = { colors = { "...", "..." }, angle = 45 }
    function formatBorderColorForLua(colorNames, angle, fallbackName) {
        if (colorNames && colorNames.length > 1) {
            const colors = colorNames.map(n => formatColorForCompositor(getColorValue(n)));
            return luaLiteral({ colors: colors, angle: angle });
        }
        const singleName = (colorNames && colorNames.length === 1) ? colorNames[0] : fallbackName;
        const color = getColorValue(singleName);
        return JSON.stringify(formatColorForCompositor(color));
    }

    function applyCompositorConfig() {
        readAnimationsProcess.running = true;
        applyTimer.restart();
    }

    function applyCompositorConfigInternal() {
        // Ensure adapters are loaded before applying config.
        if (!Config.loader.loaded) {
            console.log("CompositorConfig: Esperando que se cargue Config...");
            return;
        }

        // Wait for layout to be ready.
        if (!GlobalStates.compositorLayoutReady) {
            console.log("CompositorConfig: Esperando que se detecte el layout de AxctlService...");
            return;
        }

        const c = Config.compositor;

        // Determine border colors in Lua-ready form. Sync forces
        // compositorBorderColor; otherwise we honour the configured list
        // (supports gradients via the table form).
        const borderColors = c.syncBorderColor ? null : c.activeBorderColor;
        const activeBorderLua = formatBorderColorForLua(borderColors, c.borderAngle, Config.compositorBorderColor);

        const inactiveColors = c.inactiveBorderColor;
        const inactiveBorderLua = formatBorderColorForLua(inactiveColors, c.inactiveBorderAngle, "surface");

        // Shadow colors.
        const shadowBase = getColorValue(Config.compositorShadowColor);
        const shadowInactive = getColorValue(c.shadowColorInactive);
        const shadowOpacity = c.shadowOpacity !== undefined ? c.shadowOpacity : Config.compositorShadowOpacity;
        const shadowColorRgba = formatColorForCompositor(
            Qt.rgba(shadowBase.r, shadowBase.g, shadowBase.b, shadowBase.a * shadowOpacity)
        );
        const shadowColorInactiveRgba = formatColorForCompositor(
            Qt.rgba(shadowInactive.r, shadowInactive.g, shadowInactive.b, shadowInactive.a * shadowOpacity)
        );

        const hlGeneral = {
            gaps_in: c.gapsIn,
            gaps_out: c.gapsOut,
            border_size: Config.compositorBorderSize,
            col: {
                active_border: activeBorderLua,
                inactive_border: inactiveBorderLua,
            },
        };
        if (GlobalStates.compositorLayout) {
            hlGeneral.layout = GlobalStates.compositorLayout;
        }

        const hlConfig = {
            general: hlGeneral,
            decoration: {
                rounding: Config.compositorRounding,
                active_opacity: c.activeOpacity !== undefined ? c.activeOpacity : 1.0,
                inactive_opacity: c.inactiveOpacity !== undefined ? c.inactiveOpacity : 1.0,
                shadow: {
                    enabled: c.shadowEnabled,
                    range: c.shadowRange,
                    render_power: c.shadowRenderPower,
                    sharp: c.shadowSharp,
                    // shadow:ignore_window was removed in Hyprland 0.56.
                    // Keep reading the value from Config so the persisted
                    // setting survives in case it returns, but do not
                    // dispatch it: hl.config() rejects unknown keys and
                    // aborts the rest of the table in some Hyprland
                    // versions.
                    color: shadowColorRgba,
                    color_inactive: shadowColorInactiveRgba,
                    offset: c.shadowOffset || "0 0",
                    scale: c.shadowScale !== undefined ? c.shadowScale : 1.0,
                },
                blur: {
                    enabled: c.blurEnabled,
                    size: c.blurSize,
                    passes: c.blurPasses,
                    ignore_opacity: c.blurIgnoreOpacity,
                    new_optimizations: c.blurNewOptimizations,
                    xray: c.blurXray,
                    noise: c.blurNoise,
                    contrast: c.blurContrast,
                    brightness: c.blurBrightness,
                    vibrancy: c.blurVibrancy,
                    vibrancy_darkness: c.blurVibrancyDarkness,
                    special: c.blurSpecial,
                    popups: c.blurPopups,
                    popups_ignorealpha: c.blurPopupsIgnorealpha,
                    input_methods: c.blurInputMethods,
                    input_methods_ignorealpha: c.blurInputMethodsIgnorealpha,
                },
            },
        };

        // Hyprland's hl.config() replaces the given top-level tables, so we
        // only include sections that have meaningful changes. To keep behaviour
        // simple and predictable we always send general + decoration; layer
        // rules + animations + animations are persisted via the TOML path
        // below, since hl.layer_rule / hl.animation are handle-returning
        // builder calls that don't fit the table-replace model.
        const luaExpression = "hl.config(" + luaLiteral(hlConfig) + ")";

        // Live dispatch through the ambxst backend so the change reaches
        // Hyprland immediately, independent of the fsnotify watcher in
        // axctl. The backend shells out via `axctl config raw-batch
        // "eval hl.config({...})"`; the TOML write below is the
        // persistence leg of the round-trip — the watcher regenerates
        // hyprland.{lua,conf} once it detects the new TOML contents.
        BackendService.notify("compositor.eval", { expression: luaExpression });

        // Persist by regenerating the TOML so the new values survive a
        // shell restart and any unrelated compositor change picks them up
        // via the watcher (when that path works).
        CompositorTomlWriter.callWrite();
    }

    property Connections configConnections: Connections {
        target: Config.loader
        function onFileChanged() {
            applyCompositorConfig();
        }
        function onLoaded() {
            applyCompositorConfig();
        }
    }

    property Connections compositorConfigConnections: Connections {
        target: Config.compositor

        function onBorderSizeChanged() {
            applyCompositorConfig();
        }
        function onRoundingChanged() {
            applyCompositorConfig();
        }
        function onGapsInChanged() {
            applyCompositorConfig();
        }
        function onGapsOutChanged() {
            applyCompositorConfig();
        }
        function onActiveBorderColorChanged() {
            applyCompositorConfig();
        }
        function onInactiveBorderColorChanged() {
            applyCompositorConfig();
        }
        function onBorderAngleChanged() {
            applyCompositorConfig();
        }
        function onInactiveBorderAngleChanged() {
            applyCompositorConfig();
        }
        function onSyncRoundnessChanged() {
            applyCompositorConfig();
        }
        function onSyncBorderWidthChanged() {
            applyCompositorConfig();
        }
        function onSyncBorderColorChanged() {
            applyCompositorConfig();
        }
        function onSyncShadowOpacityChanged() {
            applyCompositorConfig();
        }
        function onSyncShadowColorChanged() {
            applyCompositorConfig();
        }
        function onShadowEnabledChanged() {
            applyCompositorConfig();
        }
        function onShadowRangeChanged() {
            applyCompositorConfig();
        }
        function onShadowRenderPowerChanged() {
            applyCompositorConfig();
        }
        function onShadowSharpChanged() {
            applyCompositorConfig();
        }
        function onShadowIgnoreWindowChanged() {
            applyCompositorConfig();
        }
        function onShadowColorChanged() {
            applyCompositorConfig();
        }
        function onShadowColorInactiveChanged() {
            applyCompositorConfig();
        }
        function onShadowOpacityChanged() {
            applyCompositorConfig();
        }
        function onShadowOffsetChanged() {
            applyCompositorConfig();
        }
        function onShadowScaleChanged() {
            applyCompositorConfig();
        }
        function onBlurEnabledChanged() {
            applyCompositorConfig();
        }
        function onBlurSizeChanged() {
            applyCompositorConfig();
        }
        function onBlurPassesChanged() {
            applyCompositorConfig();
        }
        function onBlurIgnoreOpacityChanged() {
            applyCompositorConfig();
        }
        function onBlurExplicitIgnoreAlphaChanged() {
            applyCompositorConfig();
        }
        function onBlurIgnoreAlphaValueChanged() {
            applyCompositorConfig();
        }
        function onBlurNewOptimizationsChanged() {
            applyCompositorConfig();
        }
        function onBlurXrayChanged() {
            applyCompositorConfig();
        }
        function onBlurNoiseChanged() {
            applyCompositorConfig();
        }
        function onBlurContrastChanged() {
            applyCompositorConfig();
        }
        function onBlurBrightnessChanged() {
            applyCompositorConfig();
        }
        function onBlurVibrancyChanged() {
            applyCompositorConfig();
        }
        function onBlurVibrancyDarknessChanged() {
            applyCompositorConfig();
        }
        function onBlurSpecialChanged() {
            applyCompositorConfig();
        }
        function onBlurPopupsChanged() {
            applyCompositorConfig();
        }
        function onBlurPopupsIgnorealphaChanged() {
            applyCompositorConfig();
        }
        function onBlurInputMethodsChanged() {
            applyCompositorConfig();
        }
        function onBlurInputMethodsIgnorealphaChanged() {
            applyCompositorConfig();
        }
    }

    property Connections colorsConnections: Connections {
        target: Colors
        function onFileChanged() {
            applyCompositorConfig();
        }
        function onLoaded() {
            applyCompositorConfig();
        }
    }

    property Connections barConnections: Connections {
        target: Config.bar
        function onPositionChanged() {
            applyCompositorConfig();
        }
    }

    property Connections srBgConnections: Connections {
        target: Config.theme.srBg
        function onOpacityChanged() {
            applyCompositorConfig();
        }
    }

    property Connections srBarBgConnections: Connections {
        target: Config.theme.srBarBg
        function onOpacityChanged() {
            applyCompositorConfig();
        }
    }

    property Connections globalStatesConnections: Connections {
        target: GlobalStates
        function onCompositorLayoutChanged() {
            applyCompositorConfig();
        }
        function onCompositorLayoutReadyChanged() {
            if (GlobalStates.compositorLayoutReady) {
                applyCompositorConfig();
            }
        }
    }


    Component.onCompleted: {
        // Apply immediately if Config is already loaded.
        if (Config.loader.loaded) {
            applyCompositorConfig();
        }
        // Otherwise, handled by onLoaded.
    }
}
