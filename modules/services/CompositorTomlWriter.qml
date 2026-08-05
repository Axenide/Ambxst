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

    function gatherInput() {
        // Resolved border color/opacity, matching the QML aliases defined
        // in Config.qml:3476-3480.
        const borderSize = Config.compositorBorderSize;
        const borderColor = Config.compositorBorderColor;
        const rounding = Config.compositorRounding;
        const shadowColor = Config.compositorShadowColor;
        const shadowOpacity = Config.compositorShadowOpacity;

        return {
            compositor: {
                gapsIn: Config.compositor.gapsIn,
                gapsOut: Config.compositor.gapsOut,
                borderSize: borderSize,
                rounding: rounding,
                syncBorderColor: Config.compositor.syncBorderColor,
                borderColor: borderColor,
                activeBorderColor: Config.compositor.activeBorderColor,
                activeBorderAngle: Config.compositor.borderAngle,
                inactiveBorderColor: Config.compositor.inactiveBorderColor,
                inactiveBorderAngle: Config.compositor.inactiveBorderAngle,
                shadow: {
                    enabled: Config.compositor.shadowEnabled,
                    range: Config.compositor.shadowRange,
                    renderPower: Config.compositor.shadowRenderPower,
                    sharp: Config.compositor.shadowSharp,
                    ignoreWindow: Config.compositor.shadowIgnoreWindow,
                    color: shadowColor,
                    colorInactive: Config.compositor.shadowColorInactive,
                    opacity: shadowOpacity,
                    offset: Config.compositor.shadowOffset,
                    scale: Config.compositor.shadowScale,
                },
                blur: {
                    enabled: Config.compositor.blurEnabled,
                    size: Config.compositor.blurSize,
                    passes: Config.compositor.blurPasses,
                    ignoreOpacity: Config.compositor.blurIgnoreOpacity,
                    explicitIgnoreAlpha: Config.compositor.blurExplicitIgnoreAlpha,
                    ignoreAlphaValue: Config.compositor.blurIgnoreAlphaValue,
                    newOptimizations: Config.compositor.blurNewOptimizations,
                    xray: Config.compositor.blurXray,
                    noise: Config.compositor.blurNoise,
                    contrast: Config.compositor.blurContrast,
                    brightness: Config.compositor.blurBrightness,
                    vibrancy: Config.compositor.blurVibrancy,
                    vibrancyDarkness: Config.compositor.blurVibrancyDarkness,
                    special: Config.compositor.blurSpecial,
                    popups: Config.compositor.blurPopups,
                    popupsIgnorealpha: Config.compositor.blurPopupsIgnorealpha,
                    inputMethods: Config.compositor.blurInputMethods,
                    inputMethodsIgnorealpha: Config.compositor.blurInputMethodsIgnorealpha,
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

    function callWrite() {
        const payload = JSON.stringify(gatherInput());
        // The daemon exposes a unix socket; Quickshell.Io.Process doesn't
        // speak the JSON-RPC framing directly, so we run the ambxst CLI
        // with a transient request via stdin. The CLI command
        // "ambxst ipc compositor.write <json>" is the simplest transport
        // we can rely on without coupling to the socket protocol here.
        ipcProcess.command = ["ambxst", "ipc", "call", "compositor.write", payload];
        ipcProcess.running = true;
        console.log("CompositorTomlWriter: requested compositor.write via ambxst CLI");
    }

    Component.onCompleted: {
        // Deferred first write (3s after boot) to keep startup snappy and
        // give the daemon time to come up.
        tomlDeferTimer.start();
    }

    Timer {
        id: tomlDeferTimer
        interval: 3000
        running: false
        repeat: false
        onTriggered: root.callWrite()
    }

    // Match the previous QML signal set so we don't lose regen triggers.
    property Connections configConnections: Connections {
        target: Config.loader
        function onLoaded() { root.callWrite(); }
    }

    property Connections keybindsConnections: Connections {
        target: Config.keybindsLoader
        function onLoaded() { root.callWrite(); }
        function onFileChanged() { root.callWrite(); }
        function onAdapterUpdated() { root.callWrite(); }
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
