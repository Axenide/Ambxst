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
    property string _lastBatchCmd: ""

    property var currentAnimationConfig: null
    property Process readAnimationsProcess: Process {
        command: ["axctl", "config", "get-animations"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    if (!text || text.trim().length === 0) { return; }
                    const parsed = JSON.parse(text);
                    if (Array.isArray(parsed) && parsed.length > 0) {
                        currentAnimationConfig = parsed;
                    }
                } catch (e) {
                    // Silently ignore - axctl returns non-JSON when no custom animations
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

    function applyCompositorConfigInternal(writeFile = true) {
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
            if (GlobalStates.compositorLayout === "free") {
                // Free layout: NOT a real hyprland layout
                // Apply windowrule for new windows
                batchCommand += ` ; keyword windowrule match:class .*, float on`;
                // Float all existing windows via external command
                floatAllProcess.running = true;
            } else {
                // Leaving Free layout: re-tile all floating windows
                tileAllProcess.running = true;
                // Regular tiling layouts
                batchCommand += ` ; keyword general:layout ${GlobalStates.compositorLayout}`;
            }
        }
        batchCommand += ` ; keyword decoration:rounding ${Config.compositorRounding}`;
        batchCommand += ` ; keyword decoration:shadow:enabled ${Config.compositor.shadowEnabled}`;
        batchCommand += ` ; keyword decoration:shadow:range ${Config.compositor.shadowRange}`;
        batchCommand += ` ; keyword decoration:shadow:render_power ${Config.compositor.shadowRenderPower}`;
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

        // Opacity
        batchCommand += ` ; keyword decoration:active_opacity ${Config.compositor.activeOpacity.toFixed(2)}`;
        batchCommand += ` ; keyword decoration:inactive_opacity ${Config.compositor.inactiveOpacity.toFixed(2)}`;
        batchCommand += ` ; keyword decoration:fullscreen_opacity ${Config.compositor.fullscreenOpacity.toFixed(2)}`;

        // Dim
        batchCommand += ` ; keyword decoration:dim_inactive ${Config.compositor.dimInactive}`;
        batchCommand += ` ; keyword decoration:dim_strength ${Config.compositor.dimStrength.toFixed(2)}`;
        batchCommand += ` ; keyword decoration:dim_around ${Config.compositor.dimAround.toFixed(2)}`;
        batchCommand += ` ; keyword decoration:dim_special ${Config.compositor.dimSpecial.toFixed(2)}`;

        // Rounding power
        batchCommand += ` ; keyword decoration:rounding_power ${Config.compositor.roundingPower.toFixed(1)}`;

        // General extras
        batchCommand += ` ; keyword general:allow_tearing ${Config.compositor.allowTearing}`;
        batchCommand += ` ; keyword general:resize_on_border ${Config.compositor.resizeOnBorder}`;
        batchCommand += ` ; keyword general:extend_border_grab_area ${Config.compositor.extendBorderGrabArea}`;
        batchCommand += ` ; keyword general:hover_icon_on_border ${Config.compositor.hoverIconOnBorder}`;

        // Snap
        batchCommand += ` ; keyword general:snap:enabled ${Config.compositor.snapEnabled}`;
        batchCommand += ` ; keyword general:snap:window_gap ${Config.compositor.snapWindowGap}`;
        batchCommand += ` ; keyword general:snap:monitor_gap ${Config.compositor.snapMonitorGap}`;
        batchCommand += ` ; keyword general:snap:border_overlap ${Config.compositor.snapBorderOverlap}`;
        batchCommand += ` ; keyword general:snap:respect_gaps ${Config.compositor.snapRespectGaps}`;

        // Animations
        batchCommand += ` ; keyword animations:enabled ${Config.compositor.animationsEnabled}`;

        // Input: Keyboard
        batchCommand += ` ; keyword input:kb_layout ${Config.compositor.kbLayout}`;
        if (Config.compositor.kbVariant) batchCommand += ` ; keyword input:kb_variant ${Config.compositor.kbVariant}`;
        if (Config.compositor.kbOptions) batchCommand += ` ; keyword input:kb_options ${Config.compositor.kbOptions}`;
        batchCommand += ` ; keyword input:numlock_by_default ${Config.compositor.numlockByDefault}`;
        batchCommand += ` ; keyword input:repeat_rate ${Config.compositor.repeatRate}`;
        batchCommand += ` ; keyword input:repeat_delay ${Config.compositor.repeatDelay}`;

        // Input: Mouse
        batchCommand += ` ; keyword input:sensitivity ${Config.compositor.mouseSensitivity.toFixed(2)}`;
        if (Config.compositor.mouseAccelProfile) batchCommand += ` ; keyword input:accel_profile ${Config.compositor.mouseAccelProfile}`;
        batchCommand += ` ; keyword input:follow_mouse ${Config.compositor.followMouse}`;
        batchCommand += ` ; keyword input:natural_scroll ${Config.compositor.mouseNaturalScroll}`;
        batchCommand += ` ; keyword input:scroll_factor ${Config.compositor.mouseScrollFactor.toFixed(1)}`;
        batchCommand += ` ; keyword input:left_handed ${Config.compositor.mouseLeftHanded}`;
        batchCommand += ` ; keyword input:mouse_refocus ${Config.compositor.mouseRefocus}`;
        batchCommand += ` ; keyword input:float_switch_override_focus ${Config.compositor.floatSwitchOverrideFocus}`;

        // Input: Touchpad
        batchCommand += ` ; keyword input:touchpad:disable_while_typing ${Config.compositor.touchpadDisableWhileTyping}`;
        batchCommand += ` ; keyword input:touchpad:natural_scroll ${Config.compositor.touchpadNaturalScroll}`;
        batchCommand += ` ; keyword input:touchpad:clickfinger_behavior ${Config.compositor.touchpadClickfingerBehavior}`;
        if (Config.compositor.touchpadTapButtonMap) batchCommand += ` ; keyword input:touchpad:tap_button_map ${Config.compositor.touchpadTapButtonMap}`;
        batchCommand += ` ; keyword input:touchpad:middle_button_emulation ${Config.compositor.touchpadMiddleButtonEmulation}`;
        batchCommand += ` ; keyword input:touchpad:drag_lock ${Config.compositor.touchpadDragLock}`;
        batchCommand += ` ; keyword input:touchpad:scroll_factor ${Config.compositor.touchpadScrollFactor.toFixed(1)}`;

        // Cursor
        batchCommand += ` ; keyword cursor:no_hardware_cursors ${Config.compositor.noHardwareCursors}`;
        batchCommand += ` ; keyword cursor:enable_hyprcursor ${Config.compositor.enableHyprcursor}`;
        batchCommand += ` ; keyword cursor:no_warps ${Config.compositor.noWarps}`;
        batchCommand += ` ; keyword cursor:persistent_warps ${Config.compositor.persistentWarps}`;
        batchCommand += ` ; keyword cursor:warp_on_change_workspace ${Config.compositor.warpOnChangeWorkspace}`;
        batchCommand += ` ; keyword cursor:zoom_factor ${Config.compositor.cursorZoomFactor.toFixed(1)}`;
        batchCommand += ` ; keyword cursor:inactive_timeout ${Config.compositor.cursorInactiveTimeout}`;
        batchCommand += ` ; keyword cursor:hide_on_key_press ${Config.compositor.cursorHideOnKeyPress}`;
        batchCommand += ` ; keyword cursor:hide_on_touch ${Config.compositor.cursorHideOnTouch}`;
        batchCommand += ` ; keyword cursor:hide_on_tablet ${Config.compositor.cursorHideOnTablet}`;

        // Gestures
        batchCommand += ` ; keyword gestures:workspace_swipe_create_new ${Config.compositor.workspaceSwipeCreateNew}`;
        batchCommand += ` ; keyword gestures:workspace_swipe_forever ${Config.compositor.workspaceSwipeForever}`;
        batchCommand += ` ; keyword gestures:workspace_swipe_cancel_ratio ${Config.compositor.workspaceSwipeCancelRatio.toFixed(2)}`;
        batchCommand += ` ; keyword gestures:workspace_swipe_min_speed_to_force ${Config.compositor.workspaceSwipeMinSpeedToForce}`;
        batchCommand += ` ; keyword gestures:workspace_swipe_direction_lock ${Config.compositor.workspaceSwipeDirectionLock}`;
        batchCommand += ` ; keyword gestures:workspace_swipe_use_r ${Config.compositor.workspaceSwipeUseR}`;
        batchCommand += ` ; keyword gestures:workspace_swipe_distance ${Config.compositor.workspaceSwipeDistance}`;
        batchCommand += ` ; keyword gestures:workspace_swipe_invert ${Config.compositor.workspaceSwipeInvert}`;
        batchCommand += ` ; keyword gestures:workspace_swipe_touch ${Config.compositor.workspaceSwipeTouch}`;
        batchCommand += ` ; keyword gestures:workspace_swipe_touch_invert ${Config.compositor.workspaceSwipeTouchInvert}`;

        // Dwindle
        batchCommand += ` ; keyword dwindle:preserve_split ${Config.compositor.dwindlePreserveSplit}`;
        batchCommand += ` ; keyword dwindle:pseudotile ${Config.compositor.dwindlePseudotile}`;
        batchCommand += ` ; keyword dwindle:force_split ${Config.compositor.dwindleForceSplit}`;
        batchCommand += ` ; keyword dwindle:smart_split ${Config.compositor.dwindleSmartSplit}`;
        batchCommand += ` ; keyword dwindle:default_split_ratio ${Config.compositor.dwindleDefaultSplitRatio.toFixed(2)}`;
        batchCommand += ` ; keyword dwindle:split_width_multiplier ${Config.compositor.dwindleSplitWidthMultiplier.toFixed(1)}`;
        batchCommand += ` ; keyword dwindle:permanent_direction_override ${Config.compositor.dwindlePermanentDirectionOverride}`;
        batchCommand += ` ; keyword dwindle:use_active_for_splits ${Config.compositor.dwindleUseActiveForSplits}`;
        batchCommand += ` ; keyword dwindle:smart_resizing ${Config.compositor.dwindleSmartResizing}`;
        batchCommand += ` ; keyword dwindle:special_scale_factor ${Config.compositor.dwindleSpecialScaleFactor.toFixed(2)}`;

        // Master
        batchCommand += ` ; keyword master:orientation ${Config.compositor.masterOrientation}`;
        batchCommand += ` ; keyword master:mfact ${Config.compositor.masterMfact.toFixed(2)}`;
        batchCommand += ` ; keyword master:new_status ${Config.compositor.masterNewStatus}`;
        batchCommand += ` ; keyword master:new_on_top ${Config.compositor.masterNewOnTop}`;
        batchCommand += ` ; keyword master:new_on_active ${Config.compositor.masterNewOnActive}`;
        batchCommand += ` ; keyword master:smart_resizing ${Config.compositor.masterSmartResizing}`;
        batchCommand += ` ; keyword master:special_scale_factor ${Config.compositor.masterSpecialScaleFactor.toFixed(2)}`;
        batchCommand += ` ; keyword master:allow_small_split ${Config.compositor.masterAllowSmallSplit}`;

        // Scrolling
        batchCommand += ` ; keyword scrolling:column_width ${Config.compositor.scrollingColumnWidth.toFixed(2)}`;
        if (Config.compositor.scrollingExplicitColumnWidths) batchCommand += ` ; keyword scrolling:explicit_column_widths ${Config.compositor.scrollingExplicitColumnWidths}`;
        batchCommand += ` ; keyword scrolling:direction ${Config.compositor.scrollingDirection}`;
        batchCommand += ` ; keyword scrolling:fullscreen_on_one_column ${Config.compositor.scrollingFullscreenOnOneColumn}`;
        batchCommand += ` ; keyword scrolling:focus_fit_method ${Config.compositor.scrollingFocusFitMethod}`;
        batchCommand += ` ; keyword scrolling:follow_focus ${Config.compositor.scrollingFollowFocus}`;
        batchCommand += ` ; keyword scrolling:follow_min_visible ${Config.compositor.scrollingFollowMinVisible.toFixed(2)}`;

        // XWayland
        batchCommand += ` ; keyword xwayland:enabled ${Config.compositor.xwaylandEnabled}`;
        batchCommand += ` ; keyword xwayland:force_zero_scaling ${Config.compositor.xwaylandForceZeroScaling}`;
        batchCommand += ` ; keyword xwayland:use_nearest_neighbor ${Config.compositor.xwaylandUseNearestNeighbor}`;

        // Misc
        batchCommand += ` ; keyword misc:vrr ${Config.compositor.vrr}`;
        batchCommand += ` ; keyword misc:mouse_move_enables_dpms ${Config.compositor.mouseMoveEnablesDpms}`;
        batchCommand += ` ; keyword misc:key_press_enables_dpms ${Config.compositor.keyPressEnablesDpms}`;
        batchCommand += ` ; keyword misc:disable_autoreload ${Config.compositor.disableAutoreload}`;
        batchCommand += ` ; keyword misc:focus_on_activate ${Config.compositor.focusOnActivate}`;
        batchCommand += ` ; keyword misc:animate_manual_resizes ${Config.compositor.animateManualResizes}`;
        batchCommand += ` ; keyword misc:animate_mouse_windowdragging ${Config.compositor.animateMouseWindowdragging}`;
        batchCommand += ` ; keyword misc:disable_hyprland_logo ${Config.compositor.disableHyprlandLogo}`;
        batchCommand += ` ; keyword misc:disable_splash_rendering ${Config.compositor.disableSplashRendering}`;
        batchCommand += ` ; keyword misc:force_default_wallpaper ${Config.compositor.forceDefaultWallpaper}`;

        // Animations and layer rules
        batchCommand += ` ; keyword animation windows,1,2.5,myBezier,popin 80%`;
        batchCommand += ` ; keyword animation border,1,2.5,myBezier`;
        batchCommand += ` ; keyword animation fade,1,2.5,myBezier`;
        batchCommand += ` ; ${workspaceCommand}`;
        // Note: workspaceCommand is dynamically calculated based on current animations and orientation.

        console.log(`CompositorConfig: Applying ignorealpha: ${ignoreAlphaValue}, explicit: ${Config.compositor.blurExplicitIgnoreAlpha}`);
        batchCommand += ` ; keyword layerrule noanim,quickshell ; keyword layerrule blur,quickshell ; keyword layerrule blurpopups,quickshell ; keyword layerrule ignorealpha ${ignoreAlphaValue},quickshell`;
        console.log("CompositorConfig: Applying compositor batch command:", batchCommand);
        root._lastBatchCmd = batchCommand;
        compositorProcess.command = ["axctl", "config", "raw-batch", batchCommand];
        compositorProcess.running = true;

        // Also write to hyprland.conf for persistence
        if (writeFile) {
            root.writeConfigToFile(batchCommand);
        }
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

        // Opacity & Dim
        function onActiveOpacityChanged() { applyCompositorConfig(); }
        function onInactiveOpacityChanged() { applyCompositorConfig(); }
        function onFullscreenOpacityChanged() { applyCompositorConfig(); }
        function onDimInactiveChanged() { applyCompositorConfig(); }
        function onDimStrengthChanged() { applyCompositorConfig(); }
        function onDimAroundChanged() { applyCompositorConfig(); }
        function onDimSpecialChanged() { applyCompositorConfig(); }
        function onRoundingPowerChanged() { applyCompositorConfig(); }

        // General extras
        function onAllowTearingChanged() { applyCompositorConfig(); }
        function onResizeOnBorderChanged() { applyCompositorConfig(); }
        function onExtendBorderGrabAreaChanged() { applyCompositorConfig(); }
        function onHoverIconOnBorderChanged() { applyCompositorConfig(); }

        // Snap
        function onSnapEnabledChanged() { applyCompositorConfig(); }
        function onSnapWindowGapChanged() { applyCompositorConfig(); }
        function onSnapMonitorGapChanged() { applyCompositorConfig(); }
        function onSnapBorderOverlapChanged() { applyCompositorConfig(); }
        function onSnapRespectGapsChanged() { applyCompositorConfig(); }

        // Animations
        function onAnimationsEnabledChanged() { applyCompositorConfig(); }

        // Input: Keyboard
        function onKbLayoutChanged() { applyCompositorConfig(); }
        function onKbVariantChanged() { applyCompositorConfig(); }
        function onKbOptionsChanged() { applyCompositorConfig(); }
        function onNumlockByDefaultChanged() { applyCompositorConfig(); }
        function onRepeatRateChanged() { applyCompositorConfig(); }
        function onRepeatDelayChanged() { applyCompositorConfig(); }

        // Input: Mouse
        function onMouseSensitivityChanged() { applyCompositorConfig(); }
        function onMouseAccelProfileChanged() { applyCompositorConfig(); }
        function onFollowMouseChanged() { applyCompositorConfig(); }
        function onMouseNaturalScrollChanged() { applyCompositorConfig(); }
        function onMouseScrollFactorChanged() { applyCompositorConfig(); }
        function onMouseLeftHandedChanged() { applyCompositorConfig(); }
        function onMouseRefocusChanged() { applyCompositorConfig(); }
        function onFloatSwitchOverrideFocusChanged() { applyCompositorConfig(); }

        // Input: Touchpad
        function onTouchpadDisableWhileTypingChanged() { applyCompositorConfig(); }
        function onTouchpadNaturalScrollChanged() { applyCompositorConfig(); }
        function onTouchpadTapToClickChanged() { applyCompositorConfig(); }
        function onTouchpadClickfingerBehaviorChanged() { applyCompositorConfig(); }
        function onTouchpadTapButtonMapChanged() { applyCompositorConfig(); }
        function onTouchpadMiddleButtonEmulationChanged() { applyCompositorConfig(); }
        function onTouchpadDragLockChanged() { applyCompositorConfig(); }
        function onTouchpadScrollFactorChanged() { applyCompositorConfig(); }

        // Cursor
        function onNoHardwareCursorsChanged() { applyCompositorConfig(); }
        function onEnableHyprcursorChanged() { applyCompositorConfig(); }
        function onNoWarpsChanged() { applyCompositorConfig(); }
        function onPersistentWarpsChanged() { applyCompositorConfig(); }
        function onWarpOnChangeWorkspaceChanged() { applyCompositorConfig(); }
        function onCursorZoomFactorChanged() { applyCompositorConfig(); }
        function onCursorInactiveTimeoutChanged() { applyCompositorConfig(); }
        function onCursorHideOnKeyPressChanged() { applyCompositorConfig(); }
        function onCursorHideOnTouchChanged() { applyCompositorConfig(); }
        function onCursorHideOnTabletChanged() { applyCompositorConfig(); }

        // Gestures
        function onWorkspaceSwipeCreateNewChanged() { applyCompositorConfig(); }
        function onWorkspaceSwipeForeverChanged() { applyCompositorConfig(); }
        function onWorkspaceSwipeCancelRatioChanged() { applyCompositorConfig(); }
        function onWorkspaceSwipeMinSpeedToForceChanged() { applyCompositorConfig(); }
        function onWorkspaceSwipeDirectionLockChanged() { applyCompositorConfig(); }
        function onWorkspaceSwipeUseRChanged() { applyCompositorConfig(); }
        function onWorkspaceSwipeDistanceChanged() { applyCompositorConfig(); }
        function onWorkspaceSwipeInvertChanged() { applyCompositorConfig(); }
        function onWorkspaceSwipeTouchChanged() { applyCompositorConfig(); }
        function onWorkspaceSwipeTouchInvertChanged() { applyCompositorConfig(); }

        // Dwindle
        function onDwindlePreserveSplitChanged() { applyCompositorConfig(); }
        function onDwindlePseudotileChanged() { applyCompositorConfig(); }
        function onDwindleForceSplitChanged() { applyCompositorConfig(); }
        function onDwindleSmartSplitChanged() { applyCompositorConfig(); }
        function onDwindleDefaultSplitRatioChanged() { applyCompositorConfig(); }
        function onDwindleSplitWidthMultiplierChanged() { applyCompositorConfig(); }
        function onDwindlePermanentDirectionOverrideChanged() { applyCompositorConfig(); }
        function onDwindleUseActiveForSplitsChanged() { applyCompositorConfig(); }
        function onDwindleSmartResizingChanged() { applyCompositorConfig(); }
        function onDwindleSpecialScaleFactorChanged() { applyCompositorConfig(); }

        // Master
        function onMasterOrientationChanged() { applyCompositorConfig(); }
        function onMasterMfactChanged() { applyCompositorConfig(); }
        function onMasterNewStatusChanged() { applyCompositorConfig(); }
        function onMasterNewOnTopChanged() { applyCompositorConfig(); }
        function onMasterNewOnActiveChanged() { applyCompositorConfig(); }
        function onMasterSmartResizingChanged() { applyCompositorConfig(); }
        function onMasterSpecialScaleFactorChanged() { applyCompositorConfig(); }
        function onMasterAllowSmallSplitChanged() { applyCompositorConfig(); }

        // Scrolling
        function onScrollingColumnWidthChanged() { applyCompositorConfig(); }
        function onScrollingExplicitColumnWidthsChanged() { applyCompositorConfig(); }
        function onScrollingDirectionChanged() { applyCompositorConfig(); }
        function onScrollingFullscreenOnOneColumnChanged() { applyCompositorConfig(); }
        function onScrollingFocusFitMethodChanged() { applyCompositorConfig(); }
        function onScrollingFollowFocusChanged() { applyCompositorConfig(); }
        function onScrollingFollowMinVisibleChanged() { applyCompositorConfig(); }

        // XWayland
        function onXwaylandEnabledChanged() { applyCompositorConfig(); }
        function onXwaylandForceZeroScalingChanged() { applyCompositorConfig(); }
        function onXwaylandUseNearestNeighborChanged() { applyCompositorConfig(); }

        // Misc
        function onVrrChanged() { applyCompositorConfig(); }
        function onVfrChanged() { applyCompositorConfig(); }
        function onMouseMoveEnablesDpmsChanged() { applyCompositorConfig(); }
        function onKeyPressEnablesDpmsChanged() { applyCompositorConfig(); }
        function onDisableAutoreloadChanged() { applyCompositorConfig(); }
        function onFocusOnActivateChanged() { applyCompositorConfig(); }
        function onAnimateManualResizesChanged() { applyCompositorConfig(); }
        function onAnimateMouseWindowdraggingChanged() { applyCompositorConfig(); }
        function onDisableHyprlandLogoChanged() { applyCompositorConfig(); }
        function onDisableSplashRenderingChanged() { applyCompositorConfig(); }
        function onForceDefaultWallpaperChanged() { applyCompositorConfig(); }
        function onNoUpdateNewsChanged() { applyCompositorConfig(); }
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

    // Write config to hyprland.conf — reads values directly from Config.compositor
    // No dependency on batchCommand, always gets current values
        function writeConfigToFile(batchCmd) {
        // Call the Python sync script which reads compositor.json directly
        const scriptPath = Quickshell.env("HOME") + "/Documentos/GitHub/Ambxst/scripts/sync-hyprland-conf.py";
        syncProcess.command = ["python3", scriptPath];
        syncProcess.running = true;
    }

    property Process syncProcess: Process {
        id: syncProcess
        running: false
        onExited: (code) => {
            if (code === 0) {
                console.log("Config written to hyprland.conf/lua via sync script");
                // Reload axctl daemon so it picks up the new config
                reloadProcess.command = ["axctl", "reload"];
                reloadProcess.running = true;
            } else {
                console.error("sync-hyprland-conf.py failed, code:", code);
            }
        }
    }

    property Process reloadProcess: Process {
        id: reloadProcess
        running: false
    }

    property Process writeConfProcess: Process {
        id: writeConfProcess
        running: false
        onExited: (code) => {
            if (code === 0) {
                console.log("Config written to hyprland.conf (auto-reload handles reload)");
            } else {
                console.error("Failed to write hyprland.conf, code:", code);
            }
        }
    }

    // Float all existing windows when switching to Free layout
    property Process floatAllProcess: Process {
        command: ["bash", "-c", "hyprctl -j clients | python3 -c 'import json,sys; cs=json.load(sys.stdin); [print(c[\"address\"]) for c in cs if not c[\"floating\"]]' | while read addr; do hyprctl dispatch togglefloating address:$addr; done"]
        running: false
        onExited: (code) => {
            console.log("FloatAllProcess exited with code:", code);
        }
    }

    // Tile all floating windows when leaving Free layout
    property Process tileAllProcess: Process {
        command: ["bash", "-c", "hyprctl -j clients | python3 -c 'import json,sys; cs=json.load(sys.stdin); [print(c[\"address\"]) for c in cs if c[\"floating\"]]' | while read addr; do hyprctl dispatch togglefloating address:$addr; done"]
        running: false
        onExited: (code) => {
            console.log("TileAllProcess exited with code:", code);
        }
    }

    // Force re-apply when Config.compositor adapter becomes available
    // Also reassign the connections target (QML Connections may not rebind target)
    property QtObject compWatch: Config.compositor
    onCompWatchChanged: {
        if (root.compWatch) {
            root.applyCompositorConfig();
        }
        // Re-assign Connections target in case it was null during init
        Qt.callLater(() => {
            if (root.compWatch && !root.compositorConfigConnections.target) {
                root.compositorConfigConnections.target = root.compWatch;
            }
        });
    }

    // Removed globalStateConnections - it was redundant.
    // Every Config.compositor property already has its own handler
    // (above in compositorConfigConnections) that calls applyCompositorConfig().
    // That covers: dispatch + writeConfig + reload.
    // This ADDITIONAL connection caused double dispatch, double file write,
    // and double axctl reload on every property change.

    // Re-apply settings when Hyprland config is reloaded (user edits hyprland.conf)
    property Connections axctlConnections: Connections {
        target: AxctlService
        function onRawEvent(event) {
            if (event && event.name === "configreloaded") {
                console.log("CompositorConfig: Hyprland config reloaded, reapplying settings...");
                applyCompositorConfigInternal(false);  // Don't write file (already correct)
            }
        }

        function onConfigReloaded() {
            console.log("CompositorConfig: Config reloaded signal, reapplying settings...");
            applyCompositorConfigInternal(false);
        }

        function onSubscribeReady() {
            console.log("CompositorConfig: Subscribe reconnected, reapplying settings...");
            applyCompositorConfig();
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
