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

    property string barPosition: (Config.bar && Config.bar.position !== undefined && ["top", "bottom", "left", "right"].includes(Config.bar.position) ? Config.bar.position : "top")
    property string orientation: barPosition === "left" || barPosition === "right" ? "vertical" : "horizontal"

    // Auto-hide properties
    onPinnedChanged: {
        if (Config.bar && Config.bar.pinnedOnStartup !== pinned) {
            Config.bar.pinnedOnStartup = pinned;
        }
    }

    property bool pinned: (Config.bar && Config.bar.pinnedOnStartup !== undefined ? Config.bar.pinnedOnStartup : true)

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
    readonly property bool isMouseOverBar: barMouseArea.containsMouse

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

    // Reveal logic
    readonly property bool reveal: {
        // If not auto-hiding, always reveal
        if (!shouldAutoHide)
            return true;

        // If fullscreen and not available on fullscreen, hide
        if (activeWindowFullscreen && !(Config.bar && Config.bar.availableOnFullscreen !== undefined ? Config.bar.availableOnFullscreen : false)) {
            return false;
        }

        // Show if: hovering, notch hovering (when at top), notch open
        // IMPORTANT: notchHoverActive must be checked to synchronize with notch
        return isMouseOverBar || hoverActive || notchHoverActive || notchOpen;
    }

    // Timer to delay hiding the bar after mouse leaves
    Timer {
        id: hideDelayTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (!root.isMouseOverBar) {
                root.hoverActive = false;
            }
        }
    }

    // Watch for mouse state changes
    onIsMouseOverBarChanged: {
        if (isMouseOverBar) {
            hideDelayTimer.stop();
            hoverActive = true;
        } else {
            // Si está fijada, podemos resetear el hoverActive inmediatamente
            // Si está en auto-hide, usamos el timer para dar margen
            if (shouldAutoHide) {
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
        hoverEnabled: true

        // Size includes margins
        width: root.orientation === "horizontal" ? root.width : (root.reveal ? root.totalBarWidth : Math.max((Config.bar && Config.bar.hoverRegionHeight !== undefined ? Config.bar.hoverRegionHeight : 8), 4) + root.frameOffset)
        height: root.orientation === "vertical" ? root.height : (root.reveal ? root.totalBarHeight : Math.max((Config.bar && Config.bar.hoverRegionHeight !== undefined ? Config.bar.hoverRegionHeight : 8), 4) + root.frameOffset)


        // Position using x/y
        x: {
            if (root.barPosition === "right") return parent.width - width;
            return 0;
        }
        y: {
            if (root.barPosition === "bottom") return parent.height - height;
            return 0;
        }

        Behavior on x {
            enabled: (Config.animDuration !== undefined ? Config.animDuration : 0) > 0 && root.orientation === "vertical"
            NumberAnimation {
                duration: (Config.animDuration !== undefined ? Config.animDuration : 0) / 4
                easing.type: Easing.OutCubic
            }
        }
        Behavior on y {
            enabled: (Config.animDuration !== undefined ? Config.animDuration : 0) > 0 && root.orientation === "horizontal"
            NumberAnimation {
                duration: (Config.animDuration !== undefined ? Config.animDuration : 0) / 4
                easing.type: Easing.OutCubic
            }
        }

        Behavior on width {
            enabled: (Config.animDuration !== undefined ? Config.animDuration : 0) > 0 && root.orientation === "vertical"
            NumberAnimation {
                duration: (Config.animDuration !== undefined ? Config.animDuration : 0) / 4
                easing.type: Easing.OutCubic
            }
        }
        Behavior on height {
            enabled: (Config.animDuration !== undefined ? Config.animDuration : 0) > 0 && root.orientation === "horizontal"
            NumberAnimation {
                duration: (Config.animDuration !== undefined ? Config.animDuration : 0) / 4
                easing.type: Easing.OutCubic
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

            // Opacity animation
            opacity: root.reveal ? 1 : 0
            Behavior on opacity {
                enabled: (Config.animDuration !== undefined ? Config.animDuration : 0) > 0
                NumberAnimation {
                    duration: (Config.animDuration !== undefined ? Config.animDuration : 0) / 2
                    easing.type: Easing.OutCubic
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
                    enabled: (Config.animDuration !== undefined ? Config.animDuration : 0) > 0
                    NumberAnimation {
                        duration: (Config.animDuration !== undefined ? Config.animDuration : 0) / 2
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on y {
                    enabled: (Config.animDuration !== undefined ? Config.animDuration : 0) > 0
                    NumberAnimation {
                        duration: (Config.animDuration !== undefined ? Config.animDuration : 0) / 2
                        easing.type: Easing.OutCubic
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

                        LauncherButton {
                            id: launcherButton
                            startRadius: root.outerRadius
                            endRadius: root.innerRadius
                            enableShadow: root.shadowsEnabled
                        }

                        Workspaces {
                            orientation: root.orientation
                            bar: QtObject {
                                property var screen: root.screen
                            }
                            startRadius: root.innerRadius
                            endRadius: root.innerRadius
                        }

                        LayoutSelectorButton {
                            id: layoutSelectorButton
                            bar: root
                            layerEnabled: root.shadowsEnabled
                            startRadius: root.innerRadius
                            endRadius: (root.pinButtonVisible) ? root.innerRadius : (root.dockAtStart ? root.innerRadius : root.outerRadius)
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
                                    
                                    // PinButton is typically last in group 1 (unless IntegratedDock follows at start)
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
                                            enabled: (Config.animDuration !== undefined ? Config.animDuration : 0) > 0
                                            NumberAnimation {
                                                duration: (Config.animDuration !== undefined ? Config.animDuration : 0) / 2
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
                                        enabled: (Config.animDuration !== undefined ? Config.animDuration : 0) > 0
                                        NumberAnimation {
                                            duration: (Config.animDuration !== undefined ? Config.animDuration : 0) / 2
                                        }
                                    }

                                    Behavior on color {
                                        enabled: (Config.animDuration !== undefined ? Config.animDuration : 0) > 0
                                        ColorAnimation {
                                            duration: (Config.animDuration !== undefined ? Config.animDuration : 0) / 2
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
                            startRadius: root.dockAtEnd ? root.innerRadius : root.outerRadius
                            endRadius: root.innerRadius
                            enableShadow: root.shadowsEnabled
                        }

                        ToolsButton {
                            id: toolsButton
                            startRadius: root.innerRadius
                            endRadius: root.innerRadius
                            enableShadow: root.shadowsEnabled
                        }

                        SysTray {
                            bar: root
                            enableShadow: root.shadowsEnabled
                            startRadius: root.innerRadius
                            endRadius: root.innerRadius
                        }

                        ControlsButton {
                            id: controlsButton
                            bar: root
                            layerEnabled: root.shadowsEnabled
                            startRadius: root.innerRadius
                            endRadius: root.innerRadius
                        }

                        Bar.BatteryIndicator {
                            id: batteryIndicator
                            bar: root
                            layerEnabled: root.shadowsEnabled
                            startRadius: root.innerRadius
                            endRadius: root.innerRadius
                        }

                        Clock {
                            id: clockComponent
                            bar: root
                            layerEnabled: root.shadowsEnabled
                            startRadius: root.innerRadius
                            endRadius: root.innerRadius
                        }

                        PowerButton {
                            id: powerButton
                            startRadius: root.innerRadius
                            endRadius: root.outerRadius
                            enableShadow: root.shadowsEnabled
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
                            Layout.preferredHeight: 36
                            startRadius: root.outerRadius
                            endRadius: root.innerRadius
                            vertical: true
                            enableShadow: root.shadowsEnabled
                        }

                        SysTray {
                            bar: root
                            enableShadow: root.shadowsEnabled
                            startRadius: root.innerRadius
                            endRadius: root.innerRadius
                        }

                        ToolsButton {
                            id: toolsButtonVert
                            startRadius: root.innerRadius
                            endRadius: root.innerRadius
                            vertical: true
                            enableShadow: root.shadowsEnabled
                        }

                        PresetsButton {
                            id: presetsButtonVert
                            startRadius: root.innerRadius
                            endRadius: root.outerRadius
                            vertical: true
                            enableShadow: root.shadowsEnabled
                        }

                        // Center Group Container
                        Item {
                            Layout.fillHeight: true
                            Layout.fillWidth: true

                            ColumnLayout {
                                anchors.horizontalCenter: parent.horizontalCenter

                                // Calculate target position to be absolutely centered in the bar (vertically)
                                property real targetY: {
                                    if (!parent || !bar)
                                        return 0;

                                    // Force re-evaluation when parent moves
                                    var _trigger = parent.y;

                                    var parentPos = parent.mapToItem(bar, 0, 0);
                                    return (bar.height - height) / 2 - parentPos.y;
                                }

                                // Clamp y position
                                y: Math.max(0, Math.min(parent.height - height, targetY))

                                height: Math.min(parent.height, implicitHeight)
                                width: parent.width
                                spacing: 4

                                LayoutSelectorButton {
                                    id: layoutSelectorButtonVert
                                    bar: root
                                    layerEnabled: root.shadowsEnabled
                                    Layout.alignment: Qt.AlignHCenter
                                    startRadius: root.outerRadius
                                    endRadius: root.innerRadius
                                    vertical: true
                                }

                                Workspaces {
                                    id: workspacesVert
                                    orientation: root.orientation
                                    bar: QtObject {
                                        property var screen: root.screen
                                    }
                                    Layout.alignment: Qt.AlignHCenter
                                    startRadius: root.innerRadius
                                    endRadius: root.innerRadius
                                }

                                // Pin button (vertical)
                                Loader {
                                    active: (Config.bar && Config.bar.showPinButton !== undefined ? Config.bar.showPinButton : true)
                                    visible: active
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
                                            // In vertical, dock is always appended to this group if enabled
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
                                                    enabled: (Config.animDuration !== undefined ? Config.animDuration : 0) > 0
                                                    NumberAnimation {
                                                        duration: (Config.animDuration !== undefined ? Config.animDuration : 0) / 2
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
                                                enabled: (Config.animDuration !== undefined ? Config.animDuration : 0) > 0
                                                NumberAnimation {
                                                    duration: (Config.animDuration !== undefined ? Config.animDuration : 0) / 2
                                                }
                                            }

                                            Behavior on color {
                                                enabled: (Config.animDuration !== undefined ? Config.animDuration : 0) > 0
                                                ColorAnimation {
                                                    duration: (Config.animDuration !== undefined ? Config.animDuration : 0) / 2
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
                            }

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
                        }

                        ControlsButton {
                            id: controlsButtonVert
                            bar: root
                            layerEnabled: root.shadowsEnabled
                            startRadius: root.outerRadius
                            endRadius: root.innerRadius
                        }

                        Bar.BatteryIndicator {
                            id: batteryIndicatorVert
                            bar: root
                            layerEnabled: root.shadowsEnabled
                            startRadius: root.innerRadius
                            endRadius: root.innerRadius
                        }

                        Clock {
                            id: clockComponentVert
                            bar: root
                            layerEnabled: root.shadowsEnabled
                            startRadius: root.innerRadius
                            endRadius: root.innerRadius
                        }

                        PowerButton {
                            id: powerButtonVert
                            Layout.preferredHeight: 36
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
