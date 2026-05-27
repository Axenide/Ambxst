import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import qs.modules.bar.workspaces
import qs.modules.theme
import qs.modules.bar.clock
import qs.modules.bar.systray
import qs.modules.widgets.defaultview
import qs.modules.bar.tasktray
import qs.modules.widgets.overview
import qs.modules.widgets.dashboard
import qs.modules.widgets.powermenu
import qs.modules.widgets.presets
import qs.modules.corners
import qs.modules.components
import qs.modules.services
import qs.modules.globals
import qs.modules.bar
import qs.config
import "." as Bar
Item {
    id: root
    required property ShellScreen screen
    property string barPosition: {
        const global = (Config.bar && Config.bar.position !== undefined && ["top", "bottom", "left", "right"].includes(Config.bar.position) ? Config.bar.position : "top");
        return PerMonitorConfig.resolve(screen.name, "bar", "position", global);
    }
    property string barMode: (Config.bar && Config.bar.barMode) || "extended"
    property string orientation: barPosition === "left" || barPosition === "right" ? "vertical" : "horizontal"
    // Auto-hide properties
    onPinnedChanged: {
        if (Config.bar && Config.bar.pinnedOnStartup !== pinned) {
            Config.bar.pinnedOnStartup = pinned;
        }
    }
    property bool pinned: (Config.bar && Config.bar.pinnedOnStartup !== undefined ? Config.bar.pinnedOnStartup : true) && !(Config.bar && Config.bar.hoverToReveal !== undefined ? Config.bar.hoverToReveal : false)
    // Monitor reference and reference to toplevels on monitor
    readonly property var compositorMonitor: AxctlService.monitorFor(screen)
    readonly property var toplevels: (!compositorMonitor || !compositorMonitor.activeWorkspace || !AxctlService.clients.values) ? [] : AxctlService.clients.values.filter(c => c.workspace.id === compositorMonitor.activeWorkspace.id)
    // Fullscreen detection - use ToplevelManager (native Wayland) for reliable detection
    readonly property bool activeWindowFullscreen: {
        const toplevel = ToplevelManager.activeToplevel;
        if (!toplevel || !toplevel.activated)
            return false;
        return toplevel.fullscreen === true;
    }
    // Whether auto-hide should be active (not pinned, or fullscreen forces it)
    readonly property bool shouldAutoHide: !pinned || activeWindowFullscreen
    onShouldAutoHideChanged: {
        if (!shouldAutoHide) {
            hoverActive = false;
            hideDelayTimer.stop();
        }
    }
    // Hover state with delay to prevent flickering
    property bool hoverActive: false
    // Track if mouse is over bar area
    property bool isMouseOverBar: false
    // Check if notch hover is active (for synchronized reveal when bar is at same side)
    // NOTE: We access Visibilities.notchPanels directly because UnifiedShellPanel registers itself as the panel ref
    readonly property var notchPanelRef: Visibilities.notchPanels[screen.name]
    readonly property string notchPosition: (Config.notchPosition !== undefined ? Config.notchPosition : "top")
    readonly property bool notchHoverActive: {
        if (barPosition !== notchPosition)
            return false;
        if (notchPanelRef) {
            // UnifiedShellPanel exposes 'notchHoverActive' property alias pointing to notchContent.hoverActive
            // We need to check if that property exists on the panel object
            if (typeof notchPanelRef.notchHoverActive !== 'undefined') {
                return notchPanelRef.notchHoverActive;
            }
            // Fallback for compatibility
            if (typeof notchPanelRef.hoverActive !== 'undefined') {
                return notchPanelRef.hoverActive;
            }
        }
        return false;
    }
    // Check if notch is open (dashboard, powermenu, etc.)
    readonly property var screenVisibilities: Visibilities.getForScreen(screen.name)
    readonly property bool notchOpen: screenVisibilities ? (screenVisibilities.launcher || screenVisibilities.dashboard || screenVisibilities.powermenu || screenVisibilities.tools) : false
    // Radius logic for "Squished" style
    readonly property real outerRadius: Styling.radius(0)
    readonly property real innerRadius: (Config.bar && Config.bar.pillStyle === "squished") ? Styling.radius(0) / 2 : Styling.radius(0)
    readonly property bool pinButtonVisible: (Config.bar && Config.bar.showPinButton !== undefined ? Config.bar.showPinButton : true)
    // Check if there's an adjacent monitor on the bar's edge side
    readonly property bool _hasAdjacentMonitor: {
        const mon = root.compositorMonitor;
        if (!mon || !AxctlService.monitors || !AxctlService.monitors.values) return false;
        const edgeX = root.barPosition === "left" ? mon.x : (root.barPosition === "right" ? mon.x + mon.width : 0);
        const edgeY = root.barPosition === "top" ? mon.y : (root.barPosition === "bottom" ? mon.y + mon.height : 0);
        const others = AxctlService.monitors.values.filter(m => m.name !== mon.name);
        for (let i = 0; i < others.length; i++) {
            const o = others[i];
            if (root.barPosition === "left" || root.barPosition === "right") {
                // Check horizontal adjacency (same Y range, touching at X edge)
                if (o.y + o.height > mon.y && o.y < mon.y + mon.height) {
                    if (root.barPosition === "left" && o.x + o.width === edgeX) return true;
                    if (root.barPosition === "right" && o.x === edgeX) return true;
                }
            } else {
                // Check vertical adjacency (same X range, touching at Y edge)
                if (o.x + o.width > mon.x && o.x < mon.x + mon.width) {
                    if (root.barPosition === "top" && o.y + o.height === edgeY) return true;
                    if (root.barPosition === "bottom" && o.y === edgeY) return true;
                }
            }
        }
        return false;
    }
    // Effective hover region height: 2px when at screen edge, 8px when adjacent monitor exists
    readonly property int _effectiveHoverRegion: root._hasAdjacentMonitor ? 8 : (Config.bar && Config.bar.hoverRegionHeight !== undefined ? Config.bar.hoverRegionHeight : 2)
    // Reveal logic
    readonly property bool reveal: {
        // If not auto-hiding, always reveal
        if (!shouldAutoHide)
            return true;
        // If fullscreen and not available on fullscreen, hide
        if (activeWindowFullscreen && !(Config.bar && Config.bar.availableOnFullscreen !== undefined ? Config.bar.availableOnFullscreen : false)) {
            return false;
        }
        // Show if: hovering, notch hovering, or notch open
        return isMouseOverBar || hoverActive || notchHoverActive || notchOpen;
    }

    // Mouse proximity timer — requires hovering at edge for 200ms before showing
    property bool _mousePending: false
    Timer {
        id: showDelayTimer
        interval: 200
        repeat: false
        onTriggered: {
            if (root.isMouseOverBar && root.shouldAutoHide) {
                root.hoverActive = true;
            }
            root._mousePending = false;
        }
    }
    // Timer to delay hiding the bar after mouse leaves
    Timer {
        id: hideDelayTimer
        interval: 800
        repeat: false
        onTriggered: {
            if (!root.isMouseOverBar && !root._mousePending) {
                root.hoverActive = false;
            }
        }
    }
    // Watch for mouse state changes
    onIsMouseOverBarChanged: {
        if (isMouseOverBar) {
            // Don't show immediately — wait a moment to confirm intent
            hideDelayTimer.stop();
            root._mousePending = true;
            showDelayTimer.restart();
        } else {
            // Mouse left the hover zone
            showDelayTimer.stop();
            root._mousePending = false;
            if (shouldAutoHide) {
                // Brief delay before hiding (allows moving back to the edge)
                hideDelayTimer.restart();
            } else {
                hoverActive = false;
            }
        }
    }
    // Integrated dock configuration
    readonly property bool integratedDockEnabled: (Config.dock && Config.dock.enabled !== undefined ? Config.dock.enabled : false) && (Config.dock && Config.dock.theme !== undefined ? Config.dock.theme : "default") === "integrated"
    // Map dock position for integrated based on orientation
    readonly property string integratedDockPosition: {
        const pos = (Config.dock && Config.dock.position !== undefined ? Config.dock.position : "center");
        if (root.orientation === "horizontal") {
            if (pos === "left" || pos === "start")
                return "start";
            if (pos === "right" || pos === "end")
                return "end";
            return "center";
        }
        // Vertical always falls back to center logic inside the column but we treat it as appended to group
        return "center";
    }
    // Radius helpers for dock connections
    readonly property bool dockAtStart: integratedDockEnabled && integratedDockPosition === "start"
    readonly property bool dockAtEnd: integratedDockEnabled && integratedDockPosition === "end"
    readonly property int frameOffset: (Config.bar && Config.bar.frameEnabled !== undefined ? Config.bar.frameEnabled : false) ? (Config.bar && Config.bar.frameThickness !== undefined ? Config.bar.frameThickness : 6) : 0
    // Size derived from barBg properties
    readonly property int barPadding: barBg.padding
    readonly property int topOuterMargin: (orientation === "vertical" || barPosition === "top") ? barBg.outerMargin : 0
    readonly property int bottomOuterMargin: (orientation === "vertical" || barPosition === "bottom") ? barBg.outerMargin : 0
    readonly property int leftOuterMargin: (orientation === "horizontal" || barPosition === "left") ? barBg.outerMargin : 0
    readonly property int rightOuterMargin: (orientation === "horizontal" || barPosition === "right") ? barBg.outerMargin : 0
    readonly property int contentImplicitWidth: orientation === "horizontal" ? (horizontalLoader.item && horizontalLoader.item.implicitWidth !== undefined ? horizontalLoader.item.implicitWidth : 0) : (verticalLoader.item && verticalLoader.item.implicitWidth !== undefined ? verticalLoader.item.implicitWidth : 0)
    readonly property int contentImplicitHeight: orientation === "horizontal" ? (horizontalLoader.item && horizontalLoader.item.implicitHeight !== undefined ? horizontalLoader.item.implicitHeight : 0) : (verticalLoader.item && verticalLoader.item.implicitHeight !== undefined ? verticalLoader.item.implicitHeight : 0)
    readonly property int barTargetWidth: orientation === "vertical" ? (contentImplicitWidth + 2 * barPadding) : 0
    readonly property int barTargetHeight: orientation === "horizontal" ? (contentImplicitHeight + 2 * barPadding) : 0
    readonly property bool actualContainBar: (Config.bar && Config.bar.containBar !== undefined ? Config.bar.containBar : false) && (Config.bar && Config.bar.frameEnabled !== undefined ? Config.bar.frameEnabled : false)
    readonly property int totalBarWidth: barTargetWidth + 
        ((root.barPosition === "left" || root.orientation === "horizontal") ? (root.frameOffset + root.leftOuterMargin) : 0) +
        ((root.barPosition === "right" || root.orientation === "horizontal") ? (root.frameOffset + root.rightOuterMargin) : 0)
    readonly property int totalBarHeight: barTargetHeight + 
        ((root.barPosition === "top" || root.orientation === "vertical") ? (root.frameOffset + root.topOuterMargin) : 0) +
        ((root.barPosition === "bottom" || root.orientation === "vertical") ? (root.frameOffset + root.bottomOuterMargin) : 0)
    // Base outer margin for reservation logic (4px + border when !containBar)
    readonly property int baseOuterMargin: barBg.outerMargin
    // Shadow logic for bar components
    readonly property bool shadowsEnabled: Config.showBackground && (!actualContainBar || (Config.bar && Config.bar.keepBarShadow !== undefined ? Config.bar.keepBarShadow : false))
    // The hitbox for the mask
    property alias barHitbox: barMouseArea
    // MouseArea for hover detection - contains bar content (like Dock)
    MouseArea {
        id: barMouseArea
        hoverEnabled: false
        acceptedButtons: Qt.NoButton
        propagateComposedEvents: true
        // HoverHandler for bar hover detection (without blocking child hovers)
        HoverHandler {
            id: barHoverHandler
            enabled: !bar.islandModeActive
            onHoveredChanged: {
                if (!bar.islandModeActive) {
                    root.isMouseOverBar = barHoverHandler.hovered;
                }
            }
        }
        // Size includes margins
        width: {
            if (root.orientation === "vertical") return root.reveal ? root.totalBarWidth : Math.max(root._effectiveHoverRegion, 2) + root.frameOffset;
            // Dynamic mode: always wrap content, never full width
            if (root.barMode === "dynamic") {
                const contentW = root.contentImplicitWidth + 2 * root.barPadding + (root.shouldAutoHide ? 0 : root.frameOffset * 2);
                return root.reveal ? contentW : Math.max(contentW, root._effectiveHoverRegion);
            }
            return root.width; // extended mode: full width
        }
        height: {
            if (root.orientation === "horizontal") return root.reveal ? root.totalBarHeight : Math.max(root._effectiveHoverRegion, 2) + root.frameOffset;
            // Dynamic mode: always wrap content, never full height
            if (root.barMode === "dynamic") {
                const contentH = root.contentImplicitHeight + 2 * root.barPadding + (root.shouldAutoHide ? 0 : root.frameOffset * 2);
                return root.reveal ? contentH : Math.max(contentH, root._effectiveHoverRegion);
            }
            return root.height; // extended mode: full height
        }
        // Position using x/y
        x: {
            if (root.barMode === "dynamic" && root.orientation === "horizontal") {
                // Dynamic horizontal: center in parent
                return (parent.width - width) / 2;
            }
            if (root.barPosition === "right") return parent.width - width;
            return 0;
        }
        y: {
            if (root.barMode === "dynamic" && root.orientation === "vertical") {
                // Dynamic vertical: center in parent
                return (parent.height - height) / 2;
            }
            if (root.barPosition === "bottom") return parent.height - height;
            return 0;
        }
        Behavior on x {
            enabled: Anim.animationsEnabled && root.orientation === "vertical"
            NumberAnimation {
                duration: Anim.standardSmall
                easing.type: Anim.easing("standard").type
                easing.bezierCurve: Anim.easing("standard").bezierCurve
            }
        }
        Behavior on y {
            enabled: Anim.animationsEnabled && root.orientation === "horizontal"
            NumberAnimation {
                duration: Anim.standardSmall
                easing.type: Anim.easing("standard").type
                easing.bezierCurve: Anim.easing("standard").bezierCurve
            }
        }
        Behavior on width {
            enabled: Anim.animationsEnabled && root.orientation === "vertical"
            NumberAnimation {
                duration: Anim.standardSmall
                easing.type: Anim.easing("standard").type
                easing.bezierCurve: Anim.easing("standard").bezierCurve
            }
        }
        Behavior on height {
            enabled: Anim.animationsEnabled && root.orientation === "horizontal"
            NumberAnimation {
                duration: Anim.standardSmall
                easing.type: Anim.easing("standard").type
                easing.bezierCurve: Anim.easing("standard").bezierCurve
            }
        }
        // Bar content inside MouseArea (clicks pass through to children)
        Item {
            id: bar
            anchors {
                top: (root.barPosition === "top" || root.orientation === "vertical") ? parent.top : undefined
                bottom: (root.barPosition === "bottom" || root.orientation === "vertical") ? parent.bottom : undefined
                left: (root.barPosition === "left" || root.orientation === "horizontal") ? parent.left : undefined
                right: (root.barPosition === "right" || root.orientation === "horizontal") ? parent.right : undefined
                topMargin: (root.barPosition === "top" || root.orientation === "vertical") ? (root.frameOffset + root.topOuterMargin) : 0
                bottomMargin: (root.barPosition === "bottom" || root.orientation === "vertical") ? (root.frameOffset + root.bottomOuterMargin) : 0
                leftMargin: (root.barPosition === "left" || root.orientation === "horizontal") ? (root.frameOffset + root.leftOuterMargin) : 0
                rightMargin: (root.barPosition === "right" || root.orientation === "horizontal") ? (root.frameOffset + root.rightOuterMargin) : 0
            }
            // layer.enabled: true
            // layer.effect: Shadow {}
            // Opacity — hide bar when island mode is active (notch IS the bar)
            readonly property bool islandModeActive: root.barMode === "dynamic" && (Config.notchTheme || "default") === "island" && root.barPosition === (Config.notchPosition || "top")
            opacity: islandModeActive ? 0 : (root.reveal ? 1 : 0)
            enabled: !islandModeActive
            Behavior on opacity {
                enabled: Anim.animationsEnabled
                NumberAnimation {
                    duration: Anim.standardSmall
                    easing.type: Anim.easing("standard").type
                    easing.bezierCurve: Anim.easing("standard").bezierCurve
                }
            }
            // Slide animation
            transform: Translate {
                x: {
                    if (!root.shouldAutoHide)
                        return 0;
                    if (root.barPosition === "left")
                        return root.reveal ? 0 : -bar.width - (root.frameOffset + root.leftOuterMargin);
                    if (root.barPosition === "right")
                        return root.reveal ? 0 : bar.width + (root.frameOffset + root.rightOuterMargin);
                    return 0;
                }
                y: {
                    if (!root.shouldAutoHide)
                        return 0;
                    if (root.barPosition === "top")
                        return root.reveal ? 0 : -bar.height - (root.frameOffset + root.topOuterMargin);
                    if (root.barPosition === "bottom")
                        return root.reveal ? 0 : bar.height + (root.frameOffset + root.bottomOuterMargin);
                    return 0;
                }
                Behavior on x {
                    enabled: Anim.animationsEnabled
                    NumberAnimation {
                        duration: Anim.spatialFast
                        easing.type: Anim.easing("spatial").type
                        easing.bezierCurve: Anim.easing("spatial").bezierCurve
                    }
                }
                Behavior on y {
                    enabled: Anim.animationsEnabled
                    NumberAnimation {
                        duration: Anim.spatialFast
                        easing.type: Anim.easing("spatial").type
                        easing.bezierCurve: Anim.easing("spatial").bezierCurve
                    }
                }
            }
            states: [
                State {
                    name: "top"
                    when: root.barPosition === "top"
                    PropertyChanges {
                        target: bar
                        height: root.barTargetHeight
                    }
                },
                State {
                    name: "bottom"
                    when: root.barPosition === "bottom"
                    PropertyChanges {
                        target: bar
                        height: root.barTargetHeight
                    }
                },
                State {
                    name: "left"
                    when: root.barPosition === "left"
                    PropertyChanges {
                        target: bar
                        width: root.barTargetWidth
                    }
                },
                State {
                    name: "right"
                    when: root.barPosition === "right"
                    PropertyChanges {
                        target: bar
                        width: root.barTargetWidth
                    }
                }
            ]


            BarBg {
                id: barBg
                anchors.fill: parent
                position: root.barPosition
                Loader {
                    id: horizontalLoader
                    active: root.orientation === "horizontal"
                    anchors.fill: parent
                    sourceComponent: RowLayout {
                        spacing: 4
                        // Obtener referencia al notch de esta pantalla
                        readonly property var notchContainer: Visibilities.getNotchForScreen(root.screen.name)
                        // Island condition for inline loader
                        readonly property bool _islandCondition: root.barMode === "dynamic" && (Config.notchTheme || "default") === "island" && root.barPosition === (Config.notchPosition || "top")
                        
                        // Spacers and island only in island mode — use Item with width: 0 when inactive
                        Item {
                            Layout.fillWidth: _islandCondition
                            Layout.preferredWidth: _islandCondition ? -1 : 0
                            visible: _islandCondition
                        }

                        Loader {
                            id: inlineIslandLoader
                            visible: active
                            Layout.alignment: Qt.AlignVCenter
                            asynchronous: true
                            source: Qt.resolvedUrl("IslandContent.qml")
                            z: 0
                            active: _islandCondition

                            opacity: active ? 1 : 0
                            scale: active ? 1 : 0.9
                            Behavior on opacity {
                                enabled: Anim.animationsEnabled
                                NumberAnimation {
                                    duration: Anim.emphasizedNormal
                                    easing.type: Anim.easing("emphasized").type
                                    easing.bezierCurve: Anim.easing("emphasized").bezierCurve
                                }
                            }
                            Behavior on scale {
                                enabled: Anim.animationsEnabled
                                NumberAnimation {
                                    duration: Anim.emphasizedNormal
                                    easing.type: Anim.springSnappy().type
                                    easing.bezierCurve: Anim.springSnappy().bezierCurve
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var v = Visibilities.getForScreen(root.screen.name);
                                    if (v) v.launcher = !v.launcher;
                                }
                            }
                        }

                        Item {
                            Layout.fillWidth: _islandCondition
                            Layout.preferredWidth: _islandCondition ? -1 : 0
                            visible: _islandCondition
                        }

                        LauncherButton {
                            id: launcherButton
                            visible: !Config.bar.hiddenIcons.includes("launcher")
                            startRadius: root.outerRadius
                            endRadius: root.innerRadius
                            enableShadow: root.shadowsEnabled
                            Layout.alignment: Qt.AlignVCenter
                        }
                        Workspaces {
                            visible: !Config.bar.hiddenIcons.includes("workspaces")
                            orientation: root.orientation
                            bar: QtObject {
                                property var screen: root.screen
                            }
                            startRadius: root.innerRadius
                            endRadius: root.innerRadius
                            Layout.alignment: Qt.AlignVCenter
                        }
                        LayoutSelectorButton {
            visible: !Config.bar.hiddenIcons.includes("layout")
                            id: layoutSelectorButton
                            bar: root
                            layerEnabled: root.shadowsEnabled
                            startRadius: root.innerRadius
                            endRadius: (root.pinButtonVisible) ? root.innerRadius : (root.dockAtStart ? root.innerRadius : root.outerRadius)
                            Layout.alignment: Qt.AlignVCenter
                        }
                        // Pin button (horizontal)
                        Loader {
                            active: (Config.bar && Config.bar.showPinButton !== undefined ? Config.bar.showPinButton : true)
                            visible: active
                            Layout.alignment: Qt.AlignVCenter
                            sourceComponent: Button {
                                id: pinButton
                                implicitWidth: 36
                                implicitHeight: 36
                                background: StyledRect {
                                    id: pinButtonBg
                                    variant: root.pinned ? "primary" : "bg"
                                    enableShadow: root.shadowsEnabled
                                    property real startRadius: root.innerRadius
                                    property real endRadius: root.dockAtStart ? root.innerRadius : root.outerRadius
                                    topLeftRadius: startRadius
                                    bottomLeftRadius: startRadius
                                    topRightRadius: endRadius
                                    bottomRightRadius: endRadius
                                    Rectangle {
                                        anchors.fill: parent
                                        color: Styling.srItem("overprimary")
                                        opacity: root.pinned ? 0 : (pinButton.pressed ? 0.5 : (pinButton.hovered ? 0.25 : 0))
                                        radius: (parent.radius !== undefined ? parent.radius : 0)
                                        Behavior on opacity {
                                            enabled: Anim.animationsEnabled
                                            NumberAnimation {
                                                duration: Anim.standardSmall
                                            }
                                        }
                                    }
                                }
                                contentItem: Text {
                                    text: Icons.pin
                                    font.family: Icons.font
                                    font.pixelSize: 18
                                    color: root.pinned ? pinButtonBg.item : (pinButton.pressed ? Colors.background : (Styling.srItem("overprimary") || Colors.foreground))
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    rotation: root.pinned ? 0 : 45
                                    Behavior on rotation {
                                        enabled: Anim.animationsEnabled
                                        NumberAnimation {
                                            duration: Anim.standardSmall
                                        }
                                    }
                                    Behavior on color {
                                        enabled: Anim.animationsEnabled
                                        ColorAnimation {
                                            duration: Anim.standardSmall
                                        }
                                    }
                                }
                                onClicked: root.pinned = !root.pinned
                                StyledToolTip {
                                    show: pinButton.hovered
                                    tooltipText: root.pinned ? "Unpin bar" : "Pin bar"
                                }
                            }
                        }
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: root.orientation === "horizontal" && integratedDockEnabled
                            Bar.IntegratedDock {
                                bar: root
                                orientation: root.orientation
                                anchors.verticalCenter: parent.verticalCenter
                                enableShadow: root.shadowsEnabled
                                // Connect to left/right groups if at start/end
                                startRadius: root.dockAtStart ? root.innerRadius : root.outerRadius
                                endRadius: root.dockAtEnd ? root.innerRadius : root.outerRadius
                                // Calculate target position based on config
                                property real targetX: {
                                    if (integratedDockPosition === "start")
                                        return 0;
                                    if (integratedDockPosition === "end")
                                        return parent.width - width;
                                    // Center logic (reactive using parent.x + margin offset)
                                    // RowLayout has anchors.margins: 4, so offset is 4
                                    return (bar.width - width) / 2 - (parent.x + 4);
                                }
                                // Clamp the x position so it never leaves the container (preventing overlap)
                                x: Math.max(0, Math.min(parent.width - width, targetX))
                                width: Math.min(implicitWidth, parent.width)
                                height: implicitHeight
                            }
                        }
                        Item {
                            Layout.fillWidth: true
                            visible: !(root.orientation === "horizontal" && integratedDockEnabled)
                        }
                        PresetsButton {
                            id: presetsButton
                            visible: !Config.bar.hiddenIcons.includes("presets")
                            startRadius: root.dockAtEnd ? root.innerRadius : root.outerRadius
                            endRadius: root.innerRadius
                            enableShadow: root.shadowsEnabled
                            Layout.alignment: Qt.AlignVCenter
                        }
                        ToolsButton {
            visible: !Config.bar.hiddenIcons.includes("tools")
                            id: toolsButton
                            startRadius: root.innerRadius
                            endRadius: root.innerRadius
                            enableShadow: root.shadowsEnabled
                            Layout.alignment: Qt.AlignVCenter
                        }
                        SysTray {
                            visible: !Config.bar.hiddenIcons.includes("systray")
                            bar: root
                            enableShadow: root.shadowsEnabled
                            startRadius: root.innerRadius
                            endRadius: root.innerRadius
                            Layout.alignment: Qt.AlignVCenter
                        }
                        TaskTray {
                            visible: !Config.bar.hiddenIcons.includes("tasktray")
                            bar: root
                            startRadius: root.innerRadius
                            endRadius: root.innerRadius
                            Layout.alignment: Qt.AlignVCenter
                        }
                        ControlsButton {
            visible: !Config.bar.hiddenIcons.includes("controls")
                            id: controlsButton
                            bar: root
                            layerEnabled: root.shadowsEnabled
                            startRadius: root.innerRadius
                            endRadius: root.innerRadius
                            Layout.alignment: Qt.AlignVCenter
                        }
                        Bar.BatteryIndicator {
            visible: !Config.bar.hiddenIcons.includes("battery")
                            id: batteryIndicator
                            bar: root
                            layerEnabled: root.shadowsEnabled
                            startRadius: root.innerRadius
                            endRadius: root.innerRadius
                            Layout.alignment: Qt.AlignVCenter
                        }
                        Clock {
                            id: clockComponent
                            visible: !Config.bar.hiddenIcons.includes("clock")
                            bar: root
                            layerEnabled: root.shadowsEnabled
                            startRadius: root.innerRadius
                            endRadius: root.innerRadius
                            Layout.alignment: Qt.AlignVCenter
                        }
                        PowerButton {
                            id: powerButton
                            visible: !Config.bar.hiddenIcons.includes("power")
                            startRadius: root.innerRadius
                            endRadius: root.outerRadius
                            enableShadow: root.shadowsEnabled
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }
                Loader {
                    id: verticalLoader
                    active: root.orientation === "vertical"
                    anchors.fill: parent
                    sourceComponent: ColumnLayout {
                        spacing: 4
                        LauncherButton {
                            id: launcherButtonVert
                            visible: !Config.bar.hiddenIcons.includes("launcher")
                            Layout.preferredHeight: 36
                            Layout.fillWidth: true
                            startRadius: root.outerRadius
                            endRadius: root.innerRadius
                            vertical: true
                            enableShadow: root.shadowsEnabled
                        }
                        SysTray {
                            visible: !Config.bar.hiddenIcons.includes("systray")
                            bar: root
                            enableShadow: root.shadowsEnabled
                            startRadius: root.innerRadius
                            endRadius: root.innerRadius
                            Layout.preferredHeight: 36
                            Layout.fillWidth: true
                        }
                        TaskTray {
                            visible: !Config.bar.hiddenIcons.includes("tasktray")
                            bar: root
                            startRadius: root.innerRadius
                            endRadius: root.innerRadius
                            Layout.preferredHeight: 36
                            Layout.fillWidth: true
                        }
                        ToolsButton {
                            id: toolsButtonVert
                            visible: !Config.bar.hiddenIcons.includes("tools")
                            startRadius: root.innerRadius
                            endRadius: root.innerRadius
                            vertical: true
                            enableShadow: root.shadowsEnabled
                            Layout.preferredHeight: 36
                            Layout.fillWidth: true
                        }
                        PresetsButton {
                            id: presetsButtonVert
                            visible: !Config.bar.hiddenIcons.includes("presets")
                            startRadius: root.innerRadius
                            endRadius: root.outerRadius
                            vertical: true
                            enableShadow: root.shadowsEnabled
                            Layout.preferredHeight: 36
                            Layout.fillWidth: true
                        }
                        // Vertical spacer before center group
                        Item { Layout.fillHeight: true; Layout.fillWidth: true }

                        LayoutSelectorButton {
                            id: layoutSelectorButtonVert
                            visible: !Config.bar.hiddenIcons.includes("layout")
                            bar: root
                            layerEnabled: root.shadowsEnabled
                            Layout.fillWidth: true
                            startRadius: root.outerRadius
                            endRadius: root.innerRadius
                            vertical: true
                        }
                        Workspaces {
                            id: workspacesVert
                            visible: !Config.bar.hiddenIcons.includes("workspaces")
                            orientation: root.orientation
                            bar: QtObject {
                                property var screen: root.screen
                            }
                            Layout.fillWidth: true
                            startRadius: root.innerRadius
                            endRadius: root.innerRadius
                        }
                        // Pin button (vertical)
                        Loader {
                            active: (Config.bar && Config.bar.showPinButton !== undefined ? Config.bar.showPinButton : true)
                            visible: active
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter
                            sourceComponent: Button {
                                id: pinButtonV
                                implicitWidth: 36
                                implicitHeight: 36
                                background: StyledRect {
                                    id: pinButtonVBg
                                    variant: root.pinned ? "primary" : "bg"
                                    enableShadow: root.shadowsEnabled
                                    property real startRadius: root.innerRadius
                                    property real endRadius: root.integratedDockEnabled ? root.innerRadius : root.outerRadius
                                    topLeftRadius: startRadius
                                    topRightRadius: startRadius
                                    bottomLeftRadius: endRadius
                                    bottomRightRadius: endRadius
                                    Rectangle {
                                        anchors.fill: parent
                                        color: Styling.srItem("overprimary")
                                        opacity: root.pinned ? 0 : (pinButtonV.pressed ? 0.5 : (pinButtonV.hovered ? 0.25 : 0))
                                        radius: (parent.radius !== undefined ? parent.radius : 0)
                                        Behavior on opacity {
                                            enabled: Anim.animationsEnabled
                                            NumberAnimation {
                                                duration: Anim.standardSmall
                                            }
                                        }
                                    }
                                }
                                contentItem: Text {
                                    text: Icons.pin
                                    font.family: Icons.font
                                    font.pixelSize: 18
                                    color: root.pinned ? pinButtonVBg.item : (pinButtonV.pressed ? Colors.background : (Styling.srItem("overprimary") || Colors.foreground))
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    rotation: root.pinned ? 0 : 45
                                    Behavior on rotation {
                                        enabled: Anim.animationsEnabled
                                        NumberAnimation {
                                            duration: Anim.standardSmall
                                        }
                                    }
                                    Behavior on color {
                                        enabled: Anim.animationsEnabled
                                        ColorAnimation {
                                            duration: Anim.standardSmall
                                        }
                                    }
                                }
                                onClicked: root.pinned = !root.pinned
                                StyledToolTip {
                                    show: pinButtonV.hovered
                                    tooltipText: root.pinned ? "Unpin bar" : "Pin bar"
                                }
                            }
                        }
                        // Vertical spacer after center group (pushes center items up)
                        Item { Layout.fillHeight: true; Layout.fillWidth: true; visible: !integratedDockEnabled }
                        // Integrated dock fills space when enabled
                        Bar.IntegratedDock {
                            bar: root
                            orientation: root.orientation
                            visible: integratedDockEnabled
                            Layout.fillHeight: true
                            Layout.fillWidth: true
                            enableShadow: root.shadowsEnabled
                            startRadius: root.innerRadius
                            endRadius: root.outerRadius
                        }
                        ControlsButton {
                            id: controlsButtonVert
                            visible: !Config.bar.hiddenIcons.includes("controls")
                            bar: root
                            layerEnabled: root.shadowsEnabled
                            startRadius: root.outerRadius
                            endRadius: root.innerRadius
                            Layout.fillWidth: true
                        }
                        Bar.BatteryIndicator {
            visible: !Config.bar.hiddenIcons.includes("battery")
                            id: batteryIndicatorVert
                            bar: root
                            layerEnabled: root.shadowsEnabled
                            startRadius: root.innerRadius
                            endRadius: root.innerRadius
                            Layout.fillWidth: true
                        }
                        Clock {
                            id: clockComponentVert
                            visible: !Config.bar.hiddenIcons.includes("clock")
                            bar: root
                            layerEnabled: root.shadowsEnabled
                            startRadius: root.innerRadius
                            endRadius: root.innerRadius
                            Layout.fillWidth: true
                        }
                        PowerButton {
                            id: powerButtonVert
                            visible: !Config.bar.hiddenIcons.includes("power")
                            Layout.preferredHeight: 36
                            Layout.fillWidth: true
                            startRadius: root.innerRadius
                            endRadius: root.outerRadius
                            vertical: true
                            enableShadow: root.shadowsEnabled
                        }
                    }
                }
            }
        }
    }
}
