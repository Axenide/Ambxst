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

        // Determine active colors.
        let activeColorFormatted = "";
        // Force compositorBorderColor if syncBorderColor is enabled, otherwise use configured list (supports gradients).
        const borderColors = Config.compositor.syncBorderColor ? null : Config.compositor.activeBorderColor;

        if (borderColors && borderColors.length > 1) {
            // Multi-color gradient.
            const formattedColors = borderColors.map(colorName => {
                const color = getColorValue(colorName);
                return formatColorForCompositor(color);
            }).join(" ");
            activeColorFormatted = `${formattedColors} ${Config.compositor.borderAngle}deg`;
        } else {
            // Single color: if sync enabled or empty, use compositorBorderColor; otherwise use first element.
            const singleColorName = (borderColors && borderColors.length === 1) ? borderColors[0] : Config.compositorBorderColor;
            const activeColor = getColorValue(singleColorName);
            activeColorFormatted = formatColorForCompositor(activeColor);
        }

        // Determine inactive colors.
        let inactiveColorFormatted = "";
        const inactiveBorderColors = Config.compositor.inactiveBorderColor;

        if (inactiveBorderColors && inactiveBorderColors.length > 1) {
            // Multi-color gradient.
            const formattedColors = inactiveBorderColors.map(colorName => {
                const color = getColorValue(colorName);
                const colorWithFullOpacity = Qt.rgba(color.r, color.g, color.b, 1.0);
                return formatColorForCompositor(colorWithFullOpacity);
            }).join(" ");
            inactiveColorFormatted = `${formattedColors} ${Config.compositor.inactiveBorderAngle}deg`;
        } else {
            // Single color.
            const singleColorName = (inactiveBorderColors && inactiveBorderColors.length === 1) ? inactiveBorderColors[0] : "surface";
            const inactiveColor = getColorValue(singleColorName);
            const inactiveColorWithFullOpacity = Qt.rgba(inactiveColor.r, inactiveColor.g, inactiveColor.b, 1.0);
            inactiveColorFormatted = formatColorForCompositor(inactiveColorWithFullOpacity);
        }

        // Shadow colors.
        const shadowColor = getColorValue(Config.compositorShadowColor);
        const shadowColorInactive = getColorValue(Config.compositor.shadowColorInactive);
        const shadowColorWithOpacity = Qt.rgba(shadowColor.r, shadowColor.g, shadowColor.b, shadowColor.a * Config.compositorShadowOpacity);
        const shadowColorInactiveWithOpacity = Qt.rgba(shadowColorInactive.r, shadowColorInactive.g, shadowColorInactive.b, shadowColorInactive.a * Config.compositorShadowOpacity);
        const shadowColorFormatted = formatColorForCompositor(shadowColorWithOpacity);
        const shadowColorInactiveFormatted = formatColorForCompositor(shadowColorInactiveWithOpacity);

        const barOrientation = getBarOrientation();
        let speed = 2.5;
        let bezier = "default";
        
        if (currentAnimationConfig && currentAnimationConfig[0]) {
            const workspaceAnim = currentAnimationConfig[0].find(anim => anim.name === "workspaces");
            if (workspaceAnim) {
                speed = workspaceAnim.speed || speed;
                bezier = workspaceAnim.bezier || bezier;
            }
        }

        const workspacesAnimation = barOrientation === "vertical" ? `slidefadevert 20%` : `slidefade 20%`;
        const workspaceCommand = `keyword animation workspaces,1,${speed},${bezier},${workspacesAnimation}`;

        // Calculate ignorealpha.
        let ignoreAlphaValue = 0.0;

        if (Config.compositor.blurExplicitIgnoreAlpha) {
            ignoreAlphaValue = Config.compositor.blurIgnoreAlphaValue.toFixed(2);
        } else {
            // Dynamic ignorealpha based on StyledRect opacity.
            // Use min(barbg, bg) opacity if barbg > 0, else use bg.
            const barBgOpacity = (Config.theme.srBarBg && Config.theme.srBarBg.opacity !== undefined) ? Config.theme.srBarBg.opacity : 0;
            const bgOpacity = (Config.theme.srBg && Config.theme.srBg.opacity !== undefined) ? Config.theme.srBg.opacity : 1.0;
            ignoreAlphaValue = (barBgOpacity > 0 ? Math.min(barBgOpacity, bgOpacity) : bgOpacity).toFixed(2);
            console.log(`CompositorConfig: Auto ignorealpha calculated: ${ignoreAlphaValue} (bg: ${bgOpacity}, bar: ${barBgOpacity})`);
        }

        let batchCommand = "";
        batchCommand += `keyword general:border_size ${Config.compositorBorderSize}`;
        batchCommand += ` ; keyword general:gaps_in ${Config.compositor.gapsIn}`;
        batchCommand += ` ; keyword general:gaps_out ${Config.compositor.gapsOut}`;
        batchCommand += ` ; keyword general:col.active_border ${activeColorFormatted}`;
        batchCommand += ` ; keyword general:col.inactive_border ${inactiveColorFormatted}`;
        if (GlobalStates.compositorLayout) {
            batchCommand += ` ; keyword general:layout ${GlobalStates.compositorLayout}`;
        }
        batchCommand += ` ; keyword decoration:rounding ${Config.compositorRounding}`;
        batchCommand += ` ; keyword decoration:shadow:enabled ${Config.compositor.shadowEnabled}`;
        batchCommand += ` ; keyword decoration:shadow:range ${Config.compositor.shadowRange}`;
        batchCommand += ` ; keyword decoration:shadow:render_power ${Config.compositor.shadowRenderPower}`;
        batchCommand += ` ; keyword decoration:shadow:sharp ${Config.compositor.shadowSharp}`;
        batchCommand += ` ; keyword decoration:shadow:ignore_window ${Config.compositor.shadowIgnoreWindow}`;
        batchCommand += ` ; keyword decoration:shadow:color ${shadowColorFormatted}`;
        batchCommand += ` ; keyword decoration:shadow:color_inactive ${shadowColorInactiveFormatted}`;
        batchCommand += ` ; keyword decoration:shadow:offset ${Config.compositor.shadowOffset}`;
        batchCommand += ` ; keyword decoration:shadow:scale ${Config.compositor.shadowScale}`;
        batchCommand += ` ; keyword decoration:blur:enabled ${Config.compositor.blurEnabled}`;
        batchCommand += ` ; keyword decoration:blur:size ${Config.compositor.blurSize}`;
        batchCommand += ` ; keyword decoration:blur:passes ${Config.compositor.blurPasses}`;
        batchCommand += ` ; keyword decoration:blur:ignore_opacity ${Config.compositor.blurIgnoreOpacity}`;
        batchCommand += ` ; keyword decoration:blur:new_optimizations ${Config.compositor.blurNewOptimizations}`;
        batchCommand += ` ; keyword decoration:blur:xray ${Config.compositor.blurXray}`;
        batchCommand += ` ; keyword decoration:blur:noise ${Config.compositor.blurNoise}`;
        batchCommand += ` ; keyword decoration:blur:contrast ${Config.compositor.blurContrast}`;
        batchCommand += ` ; keyword decoration:blur:brightness ${Config.compositor.blurBrightness}`;
        batchCommand += ` ; keyword decoration:blur:vibrancy ${Config.compositor.blurVibrancy}`;
        batchCommand += ` ; keyword decoration:blur:vibrancy_darkness ${Config.compositor.blurVibrancyDarkness}`;
        batchCommand += ` ; keyword decoration:blur:special ${Config.compositor.blurSpecial}`;
        batchCommand += ` ; keyword decoration:blur:popups ${Config.compositor.blurPopups}`;
        batchCommand += ` ; keyword decoration:blur:popups_ignorealpha ${Config.compositor.blurPopupsIgnorealpha}`;
        batchCommand += ` ; keyword decoration:blur:input_methods ${Config.compositor.blurInputMethods}`;
        batchCommand += ` ; keyword decoration:blur:input_methods_ignorealpha ${Config.compositor.blurInputMethodsIgnorealpha}`;
        batchCommand += ` ; keyword bezier myBezier,0.4,0.0,0.2,1.0`;
        batchCommand += ` ; keyword animation windows,1,2.5,myBezier,popin 80%`;
        batchCommand += ` ; keyword animation border,1,2.5,myBezier`;
        batchCommand += ` ; keyword animation fade,1,2.5,myBezier`;
        batchCommand += ` ; ${workspaceCommand}`;
        // Note: workspaceCommand is dynamically calculated based on current animations and orientation.

        console.log(`CompositorConfig: Applying ignorealpha: ${ignoreAlphaValue}, explicit: ${Config.compositor.blurExplicitIgnoreAlpha}`);
        batchCommand += ` ; keyword layerrule noanim,quickshell ; keyword layerrule blur,quickshell ; keyword layerrule blurpopups,quickshell ; keyword layerrule ignorealpha ${ignoreAlphaValue},quickshell`;
        console.log("CompositorConfig: Refreshing TOML via CompositorTomlWriter");
        CompositorTomlWriter.refresh();
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
