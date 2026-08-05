pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.modules.globals

/**
 * CompositorTomlWriter - Thin IPC client.
 *
 * Renders ~/.local/share/ambxst/axctl.toml by delegating to the
 * compositor service in the ambxst backend. The TOML generation logic,
 * the KeybindActions catalog and all keybind resolution live in
 * `backend/pkg/svc/compositor/` (see compositor.Render, compositor.ResolveAction).
 *
 * This singleton only:
 *   1. Assembles the input JSON from Config + Theme + GlobalStates.
 *   2. Calls "compositor.write" on the daemon.
 *   3. Re-fires the call whenever one of the upstream signals changes.
 */
Singleton {
    id: root

    property string outputPath: (Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")) + "/ambxst/axctl.toml"

    property Process ipcProcess: Process {
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
        }
        return `rgba(${r}${g}${b}${a})`;
    }

    function getBarOrientation() {
        const position = Config.bar.position || "top";
        return (position === "left" || position === "right") ? "vertical" : "horizontal";
    }

    // Fallback values mirror the JsonAdapter defaults in Config.qml so
    // the TOML always has usable color names even if Config.compositor
    // hasn't loaded yet when gatherInput() is called. Without these,
    // undefined var values are dropped by JSON.stringify, leaving the
    // border section empty in the generated hyprland.{lua,conf}.
    function colorOr(arr, fallback) {
        if (Array.isArray(arr) && arr.length > 0) return arr;
        return fallback;
    }
    function intOr(val, fallback) {
        return (val === undefined || val === null) ? fallback : val;
    }
    function boolOr(val, fallback) {
        return (val === undefined || val === null) ? fallback : val;
    }

    // Resolves a color name (e.g. "primary") through Config.resolveColor
    // and formats it as the rgba string Hyprland expects. Falls back
    // to a known-good rgba when the name can't be resolved, so the
    // generated Lua never lands on a bare "primary" string.
    function resolveColorName(name, fallbackRgba) {
        try {
            const v = Config.resolveColor(name);
            const color = (typeof v === 'string') ? Qt.color(v) : v;
            if (color && color.r !== undefined) {
                return formatColorForCompositor(color);
            }
        } catch (e) { /* swallow and fall through */ }
        return fallbackRgba;
    }

    function resolveColorList(names, fallbackRgba) {
        if (!Array.isArray(names) || names.length === 0) return [fallbackRgba];
        const out = [];
        for (let i = 0; i < names.length; i++) {
            out.push(resolveColorName(names[i], fallbackRgba));
        }
        return out;
    }

    function gatherInput() {
        // Resolved border color/opacity, matching the QML aliases defined
        // in Config.qml:3476-3480.
        const c = Config.compositor;
        const borderSize = c.borderSize;
        const rounding = intOr(c.rounding, 16);
        // Resolve the active border color. If syncBorderColor is on, the
        // alias Config.compositorBorderColor already points at the synced
        // theme value; if not, use the first entry of activeBorderColor.
        // In both cases the value is a NAME — convert to rgba here so
        // the TOML and downstream Lua carry a value Hyprland understands.
        const activeRgba = resolveColorName(
            boolOr(c.syncBorderColor, false) ? "primary" : (c.activeBorderColor && c.activeBorderColor[0]) || "primary",
            "rgb(87abf8)"
        );
        const inactiveRgba = resolveColorName(
            c.inactiveBorderColor && c.inactiveBorderColor[0] || "surface",
            "rgb(272937)"
        );
        const shadowColor = resolveColorName(c.shadowColor || "shadow", "rgba(00000080)");
        const shadowColorInactive = resolveColorName(c.shadowColorInactive || "shadow", "rgba(00000080)");

        // Debug breadcrumb so we can see what the QML is actually
        // resolving at runtime without needing a full Quickshell
        // debug session.
        console.log("CompositorTomlWriter:gatherInput", JSON.stringify({
            activeBorder: c.activeBorderColor,
            activeRgba: activeRgba,
            inactiveBorder: c.inactiveBorderColor,
            inactiveRgba: inactiveRgba,
            shadowColor: c.shadowColor,
            shadowRgba: shadowColor,
        }));

        return {
            compositor: {
                gapsIn: intOr(c.gapsIn, 0),
                gapsOut: intOr(c.gapsOut, 0),
                borderSize: intOr(borderSize, 2),
                rounding: rounding,
                syncBorderColor: boolOr(c.syncBorderColor, false),
                borderColor: activeRgba,
                activeBorderColor: [activeRgba],
                activeBorderAngle: intOr(c.borderAngle, 45),
                inactiveBorderColor: [inactiveRgba],
                inactiveBorderAngle: intOr(c.inactiveBorderAngle, 45),
                shadow: {
                    enabled: boolOr(c.shadowEnabled, true),
                    range: intOr(c.shadowRange, 8),
                    renderPower: intOr(c.shadowRenderPower, 3),
                    sharp: boolOr(c.shadowSharp, false),
                    ignoreWindow: boolOr(c.shadowIgnoreWindow, true),
                    color: shadowColor,
                    colorInactive: shadowColorInactive,
                    opacity: c.shadowOpacity !== undefined ? c.shadowOpacity : 0.5,
                    offset: c.shadowOffset || "0 0",
                    scale: c.shadowScale !== undefined ? c.shadowScale : 1.0,
                },
                blur: {
                    enabled: boolOr(c.blurEnabled, true),
                    size: intOr(c.blurSize, 4),
                    passes: intOr(c.blurPasses, 2),
                    ignoreOpacity: boolOr(c.blurIgnoreOpacity, true),
                    explicitIgnoreAlpha: boolOr(c.blurExplicitIgnoreAlpha, false),
                    ignoreAlphaValue: c.blurIgnoreAlphaValue !== undefined ? c.blurIgnoreAlphaValue : 0.2,
                    newOptimizations: boolOr(c.blurNewOptimizations, true),
                    xray: boolOr(c.blurXray, false),
                    noise: c.blurNoise !== undefined ? c.blurNoise : 0.0,
                    contrast: c.blurContrast !== undefined ? c.blurContrast : 1.0,
                    brightness: c.blurBrightness !== undefined ? c.blurBrightness : 1.0,
                    vibrancy: c.blurVibrancy !== undefined ? c.blurVibrancy : 0.0,
                    vibrancyDarkness: c.blurVibrancyDarkness !== undefined ? c.blurVibrancyDarkness : 0.0,
                    special: boolOr(c.blurSpecial, true),
                    popups: boolOr(c.blurPopups, false),
                    popupsIgnorealpha: c.blurPopupsIgnorealpha !== undefined ? c.blurPopupsIgnorealpha : 0.2,
                    inputMethods: boolOr(c.blurInputMethods, false),
                    inputMethodsIgnorealpha: c.blurInputMethodsIgnorealpha !== undefined ? c.blurInputMethodsIgnorealpha : 0.2,
                },
                animations: {
                    enabled: true,
                },
            },
            theme: {
                srBarBgOpacity: (Config.theme.srBarBg && Config.theme.srBarBg.opacity !== undefined) ? Config.theme.srBarBg.opacity : 0,
                srBgOpacity: (Config.theme.srBg && Config.theme.srBg.opacity !== undefined) ? Config.theme.srBg.opacity : 1.0,
                shadowColor: Config.theme.shadowColor,
                shadowOpacity: Config.theme.shadowOpacity,
            },
            bar: {
                position: Config.bar.position,
            },
            layout: GlobalStates.compositorLayout,
            keybinds: gatherKeybinds(),
        };
    }

    function gatherKeybinds() {
        const adapter = Config.keybindsLoader.adapter;
        if (!adapter)
            return { ambxst: {}, system: {}, custom: [] };

        const toAction = (a) => a ? { id: a.id, args: a.args || {} } : null;

        const ambxstMap = adapter.ambxst || {};
        const ambxst = {};
        for (const k of ["launcher", "dashboard", "assistant", "clipboard", "emoji", "notes", "tmux", "wallpapers"]) {
            if (ambxstMap[k])
                ambxst[k] = {
                    modifiers: ambxstMap[k].modifiers || [],
                    key: ambxstMap[k].key || "",
                    action: toAction(ambxstMap[k].action),
                };
        }

        const sys = ambxstMap.system || {};
        const system = {};
        for (const k of ["overview", "powermenu", "config", "lockscreen", "tools", "screenshot", "screenrecord", "lens", "reload", "quit"]) {
            if (sys[k])
                system[k] = {
                    modifiers: sys[k].modifiers || [],
                    key: sys[k].key || "",
                    action: toAction(sys[k].action),
                };
        }

        return {
            ambxst: ambxst,
            system: system,
            custom: Array.isArray(adapter.custom) ? adapter.custom : [],
        };
    }

    // Fallback writer used when the ambxst daemon is unreachable.
    // Reproduces the [target] block the Go service produces so the
    // axctl watcher still finds a valid TOML during daemon restarts
    // or when the IPC socket is stale. The QML previously had the
    // full generator in-tree; this is a deliberately minimal subset
    // covering the [target] section only — enough to keep the chain
    // alive, not enough to compete with the Go service.
    property Process fallbackProcess: Process {
        stdout: SplitParser {}
    }

    function fallbackWrite() {
        const escapedPath = root.outputPath.replace(/'/g, "'\\''");
        // The Go service writes relative paths so the wiring follows
        // the TOML directory. The minimal fallback reproduces the
        // same hyprland target line so axctl at least resolves a
        // valid path during the outage.
        const content = "[target]\nhyprland = \"hyprland.lua\"\n";
        fallbackProcess.command = ["bash", "-c", `mkdir -p "$(dirname '${escapedPath}')" && printf '%s' '${content.replace(/'/g, "'\\''")}' > '${escapedPath}'`];
        fallbackProcess.running = true;
        console.warn("CompositorTomlWriter: daemon unreachable, wrote fallback [target] only");
    }

    function callWrite() {
        const payload = JSON.stringify(gatherInput());
        // The daemon exposes a unix socket; Quickshell.Io.Process doesn't
        // speak the JSON-RPC framing directly, so we run the ambxst CLI
        // with a transient request. If the daemon is down (e.g. socket
        // file is stale), the CLI exits with code 1; we then fall back
        // to a minimal direct write so axctl still has a valid TOML
        // to watch and the rest of the shell keeps working.
        ipcProcess.command = ["ambxst", "ipc", "call", "compositor.write", payload];
        ipcProcess.exited.connect(function(code) {
            if (code !== 0) {
                console.warn("CompositorTomlWriter: daemon call failed, using fallback");
                fallbackWrite();
            }
        });
        ipcProcess.running = true;
        console.log("CompositorTomlWriter: requested compositor.write via ambxst CLI");
    }

    // Tracks whether the QML's keybind adapter is ready. We hold the
    // initial TOML regen until both the daemon's compositor service
    // and the binds.json adapter are populated, so the very first
    // write doesn't go out with an empty keybinds block.
    property bool configReady: false
    property bool keybindsReady: false

    Component.onCompleted: {
        // Defer first write to give the daemon time to come up and
        // the keybinds adapter time to load. The write fires from
        // onReady() once both flags are true; if either is still
        // missing after 6s we fire anyway with whatever we have
        // (the fallback writer will still emit a usable [target]).
        configReady = !!Config.loader.loaded;
        keybindsReady = !!(Config.keybindsLoader.adapter && Config.keybindsLoader.adapter.ambxst);
        if (configReady && keybindsReady) {
            callWrite();
        } else {
            tomlDeferTimer.start();
            tomlTimeoutTimer.start();
        }
    }

    function _onReady() {
        if (configReady && keybindsReady) {
            tomlDeferTimer.stop();
            tomlTimeoutTimer.stop();
            callWrite();
        }
    }

    Timer {
        id: tomlDeferTimer
        interval: 3000
        running: false
        repeat: true
        onTriggered: _onReady()
    }

    Timer {
        id: tomlTimeoutTimer
        interval: 6000
        running: false
        repeat: false
        onTriggered: {
            console.warn("CompositorTomlWriter: config or keybinds not ready after 6s, writing with available data");
            callWrite();
        }
    }

    // Match the previous QML signal set so we don't lose regen triggers.
    property Connections configConnections: Connections {
        target: Config.loader
        function onLoaded() {
            root.configReady = true;
            root._onReady();
        }
    }

    property Connections keybindsConnections: Connections {
        target: Config.keybindsLoader
        function onLoaded() {
            root.keybindsReady = !!(Config.keybindsLoader.adapter && Config.keybindsLoader.adapter.ambxst);
            root._onReady();
        }
        function onFileChanged() { root.callWrite(); }
        function onAdapterUpdated() {
            root.keybindsReady = !!(Config.keybindsLoader.adapter && Config.keybindsLoader.adapter.ambxst);
            root._onReady();
        }
        function onPathChanged() { root.callWrite(); }
    }

    property Connections compositorConnections: Connections {
        target: Config.compositor
        function onBorderSizeChanged() { root.callWrite(); }
        function onRoundingChanged() { root.callWrite(); }
        function onGapsInChanged() { root.callWrite(); }
        function onGapsOutChanged() { root.callWrite(); }
        function onActiveBorderColorChanged() { root.callWrite(); }
        function onInactiveBorderColorChanged() { root.callWrite(); }
        function onBorderAngleChanged() { root.callWrite(); }
        function onInactiveBorderAngleChanged() { root.callWrite(); }
        function onSyncRoundnessChanged() { root.callWrite(); }
        function onSyncBorderWidthChanged() { root.callWrite(); }
        function onSyncBorderColorChanged() { root.callWrite(); }
        function onSyncShadowOpacityChanged() { root.callWrite(); }
        function onSyncShadowColorChanged() { root.callWrite(); }
        function onShadowEnabledChanged() { root.callWrite(); }
        function onShadowRangeChanged() { root.callWrite(); }
        function onShadowRenderPowerChanged() { root.callWrite(); }
        function onShadowSharpChanged() { root.callWrite(); }
        function onShadowIgnoreWindowChanged() { root.callWrite(); }
        function onShadowColorChanged() { root.callWrite(); }
        function onShadowColorInactiveChanged() { root.callWrite(); }
        function onShadowOpacityChanged() { root.callWrite(); }
        function onShadowOffsetChanged() { root.callWrite(); }
        function onShadowScaleChanged() { root.callWrite(); }
        function onBlurEnabledChanged() { root.callWrite(); }
        function onBlurSizeChanged() { root.callWrite(); }
        function onBlurPassesChanged() { root.callWrite(); }
        function onBlurIgnoreOpacityChanged() { root.callWrite(); }
        function onBlurExplicitIgnoreAlphaChanged() { root.callWrite(); }
        function onBlurIgnoreAlphaValueChanged() { root.callWrite(); }
        function onBlurNewOptimizationsChanged() { root.callWrite(); }
        function onBlurXrayChanged() { root.callWrite(); }
        function onBlurNoiseChanged() { root.callWrite(); }
        function onBlurContrastChanged() { root.callWrite(); }
        function onBlurBrightnessChanged() { root.callWrite(); }
        function onBlurVibrancyChanged() { root.callWrite(); }
        function onBlurVibrancyDarknessChanged() { root.callWrite(); }
        function onBlurSpecialChanged() { root.callWrite(); }
        function onBlurPopupsChanged() { root.callWrite(); }
        function onBlurPopupsIgnorealphaChanged() { root.callWrite(); }
        function onBlurInputMethodsChanged() { root.callWrite(); }
        function onBlurInputMethodsIgnorealphaChanged() { root.callWrite(); }
    }

    property Connections themeConnections: Connections {
        target: Config.theme
        function onSrBarBgChanged() { root.callWrite(); }
        function onSrBgChanged() { root.callWrite(); }
        function onShadowColorChanged() { root.callWrite(); }
        function onShadowOpacityChanged() { root.callWrite(); }
    }

    property Connections barConnections: Connections {
        target: Config.bar
        function onPositionChanged() { root.callWrite(); }
    }

    property Connections globalStatesConnections: Connections {
        target: GlobalStates
        function onCompositorLayoutChanged() { root.callWrite(); }
    }
}
