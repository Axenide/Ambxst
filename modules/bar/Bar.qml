import QtQuick
import QtQuick.Controls
import QtQuick.Effects
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

PanelWindow {
    id: panel
    property string barPosition: ["top", "bottom", "left", "right"].includes(Config.bar.position) ? Config.bar.position : "top"
    property string orientation: barPosition === "left" || barPosition === "right" ? "vertical" : "horizontal"

    // Auto-hide properties
    property bool pinned: Config.bar?.pinnedOnStartup ?? true

    // Fullscreen detection - check if active toplevel is fullscreen on this screen
    readonly property bool activeWindowFullscreen: {
        const toplevel = ToplevelManager.activeToplevel;
        if (!toplevel || !toplevel.activated)
            return false;
        // Check if the toplevel is fullscreen
        return toplevel.fullscreen === true;
    }

    // Whether auto-hide should be active (not pinned, or fullscreen forces it)
    readonly property bool shouldAutoHide: !pinned || activeWindowFullscreen

    // Hover state with delay to prevent flickering
    property bool hoverActive: false

    // Track if mouse is over bar area
    readonly property bool isMouseOverBar: barMouseArea.containsMouse

    // Check if notch hover is active (for synchronized reveal when bar is at top)
    readonly property var notchPanelRef: Visibilities.notchPanels[screen.name]
    readonly property bool notchHoverActive: {
        if (barPosition !== "top")
            return false;
        // Access the notch panel's hoverActive property if available
        if (notchPanelRef && typeof notchPanelRef.hoverActive !== 'undefined') {
            return notchPanelRef.hoverActive;
        }
        return false;
    }

    // Check if notch is open (dashboard, powermenu, etc.)
    readonly property var screenVisibilities: Visibilities.getForScreen(screen.name)
    readonly property bool notchOpen: screenVisibilities ? (screenVisibilities.dashboard || screenVisibilities.powermenu || screenVisibilities.tools) : false

    // Reveal logic
    readonly property bool reveal: {
        // If not auto-hiding, always reveal
        if (!shouldAutoHide)
            return true;

        // If fullscreen and not available on fullscreen, hide
        if (activeWindowFullscreen && !(Config.bar?.availableOnFullscreen ?? false)) {
            return false;
        }

        // Show if: hovering (when enabled), notch hovering (when at top), notch open, or no active window
        return hoverActive || notchHoverActive || notchOpen || !ToplevelManager.activeToplevel?.activated;
    }

    // Timer to delay hiding the bar after mouse leaves
    Timer {
        id: hideDelayTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (!panel.isMouseOverBar) {
                panel.hoverActive = false;
            }
        }
    }

    // Watch for mouse state changes
    onIsMouseOverBarChanged: {
        // Only process hover if hoverToReveal is enabled
        if (!(Config.bar?.hoverToReveal ?? true))
            return;

        if (isMouseOverBar) {
            hideDelayTimer.stop();
            hoverActive = true;
        } else {
            hideDelayTimer.restart();
        }
    }

    // Integrated dock configuration
    readonly property bool integratedDockEnabled: (Config.dock?.enabled ?? false) && (Config.dock?.theme ?? "default") === "integrated"
    // Map dock position for integrated based on orientation
    readonly property string integratedDockPosition: {
        const pos = Config.dock?.position ?? "center";

        if (panel.orientation === "horizontal") {
            if (pos === "left" || pos === "start")
                return "start";
            if (pos === "right" || pos === "end")
                return "end";
            return "center";
        }

        // Vertical always falls back to center (or default logic) for now
        // to match the reverted behavior where it ignores start/end.
        return "center";
    }

    anchors {
        top: barPosition !== "bottom"
        bottom: barPosition !== "top"
        left: barPosition !== "right"
        right: barPosition !== "left"
    }

    color: "transparent"

    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.layer: WlrLayer.Overlay


    // Reserve space only when revealed and pinned (not in auto-hide mode or fullscreen)
    exclusiveZone: (reveal && pinned && !activeWindowFullscreen) ? (Config.showBackground ? 44 : 40) : 0
    exclusionMode: ExclusionMode.Ignore

    // Altura implicita incluye espacio extra para animaciones / futuros elementos.
    implicitHeight: orientation === "horizontal" ? 200 : Screen.height

    // La mascara siempre apunta al MouseArea (igual que el Dock)
    mask: Region {
        item: barMouseArea
    }

    Component.onCompleted: {
        Visibilities.registerBar(screen.name, bar);
        Visibilities.registerBarPanel(screen.name, panel);
    }

    Component.onDestruction: {
        Visibilities.unregisterBar(screen.name);
        Visibilities.unregisterBarPanel(screen.name);
    }

    // MouseArea for hover detection - contains bar content (like Dock)
    MouseArea {
        id: barMouseArea
        hoverEnabled: true

        // Position and size based on bar position
        states: [
            State {
                name: "top"
                when: panel.barPosition === "top"
                PropertyChanges {
                    target: barMouseArea
                    x: 0
                    y: 0
                    width: panel.width
                    height: panel.reveal ? bar.height : Math.max(Config.bar?.hoverRegionHeight ?? 8, 4)
                }
            },
            State {
                name: "bottom"
                when: panel.barPosition === "bottom"
                PropertyChanges {
                    target: barMouseArea
                    x: 0
                    y: panel.height - (panel.reveal ? bar.height : Math.max(Config.bar?.hoverRegionHeight ?? 8, 4))
                    width: panel.width
                    height: panel.reveal ? bar.height : Math.max(Config.bar?.hoverRegionHeight ?? 8, 4)
                }
            },
            State {
                name: "left"
                when: panel.barPosition === "left"
                PropertyChanges {
                    target: barMouseArea
                    x: 0
                    y: 0
                    width: panel.reveal ? bar.width : Math.max(Config.bar?.hoverRegionHeight ?? 8, 4)
                    height: panel.height
                }
            },
            State {
                name: "right"
                when: panel.barPosition === "right"
                PropertyChanges {
                    target: barMouseArea
                    x: panel.width - (panel.reveal ? bar.width : Math.max(Config.bar?.hoverRegionHeight ?? 8, 4))
                    y: 0
                    width: panel.reveal ? bar.width : Math.max(Config.bar?.hoverRegionHeight ?? 8, 4)
                    height: panel.height
                }
            }
        ]

        Behavior on width {
            enabled: Config.animDuration > 0 && panel.shouldAutoHide && panel.orientation === "vertical"
            NumberAnimation {
                duration: Config.animDuration / 4
                easing.type: Easing.OutCubic
            }
        }
        Behavior on height {
            enabled: Config.animDuration > 0 && panel.shouldAutoHide && panel.orientation === "horizontal"
            NumberAnimation {
                duration: Config.animDuration / 4
                easing.type: Easing.OutCubic
            }
        }
        Behavior on y {
            enabled: Config.animDuration > 0 && panel.shouldAutoHide && panel.barPosition === "bottom"
            NumberAnimation {
                duration: Config.animDuration / 4
                easing.type: Easing.OutCubic
            }
        }
        Behavior on x {
            enabled: Config.animDuration > 0 && panel.shouldAutoHide && panel.barPosition === "right"
            NumberAnimation {
                duration: Config.animDuration / 4
                easing.type: Easing.OutCubic
            }
        }

        // Bar content inside MouseArea (clicks pass through to children)
        Item {
            id: bar

            layer.enabled: true
            layer.effect: Shadow {}

            // Opacity animation
            opacity: panel.reveal ? 1 : 0
            Behavior on opacity {
                enabled: Config.animDuration > 0 && panel.shouldAutoHide
                NumberAnimation {
                    duration: Config.animDuration / 2
                    easing.type: Easing.OutCubic
                }
            }

            // Slide animation
            transform: Translate {
                x: {
                    if (!panel.shouldAutoHide)
                        return 0;
                    if (panel.barPosition === "left")
                        return panel.reveal ? 0 : -bar.width;
                    if (panel.barPosition === "right")
                        return panel.reveal ? 0 : bar.width;
                    return 0;
                }
                y: {
                    if (!panel.shouldAutoHide)
                        return 0;
                    if (panel.barPosition === "top")
                        return panel.reveal ? 0 : -bar.height;
                    if (panel.barPosition === "bottom")
                        return panel.reveal ? 0 : bar.height;
                    return 0;
                }
                Behavior on x {
                    enabled: Config.animDuration > 0 && panel.shouldAutoHide
                    NumberAnimation {
                        duration: Config.animDuration / 2
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on y {
                    enabled: Config.animDuration > 0 && panel.shouldAutoHide
                    NumberAnimation {
                        duration: Config.animDuration / 2
                        easing.type: Easing.OutCubic
                    }
                }
            }

            states: [
                State {
                    name: "top"
                    when: panel.barPosition === "top"
                    AnchorChanges {
                        target: bar
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: undefined
                    }
                    PropertyChanges {
                        target: bar
                        width: undefined
                        height: 44
                    }
                },
                State {
                    name: "bottom"
                    when: panel.barPosition === "bottom"
                    AnchorChanges {
                        target: bar
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: undefined
                        anchors.bottom: parent.bottom
                    }
                    PropertyChanges {
                        target: bar
                        width: undefined
                        height: 44
                    }
                },
                State {
                    name: "left"
                    when: panel.barPosition === "left"
                    AnchorChanges {
                        target: bar
                        anchors.left: parent.left
                        anchors.right: undefined
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                    }
                    PropertyChanges {
                        target: bar
                        width: 44
                        height: undefined
                    }
                },
                State {
                    name: "right"
                    when: panel.barPosition === "right"
                    AnchorChanges {
                        target: bar
                        anchors.left: undefined
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                    }
                    PropertyChanges {
                        target: bar
                        width: 44
                        height: undefined
                    }
                }
            ]

            BarBg {
                id: barBg
                anchors.fill: parent
                position: panel.barPosition
            }

            RowLayout {
                id: horizontalLayout
                visible: panel.orientation === "horizontal"
                anchors.fill: parent
                anchors.margins: 4
                spacing: 4

                // Obtener referencia al notch de esta pantalla
                readonly property var notchContainer: Visibilities.getNotchForScreen(panel.screen.name)

                LauncherButton {
                    id: launcherButton
                }

                Workspaces {
                    id: workspacesRow
                    orientation: panel.orientation
                    bar: QtObject {
                        property var screen: panel.screen
                    }
                }


                LayoutSelectorButton {
                    id: layoutSelectorButton
                    bar: panel
                    layerEnabled: Config.showBackground
                }

                // Pin button (horizontal)
                Loader {
                    active: Config.bar?.showPinButton ?? true
                    visible: active
                    Layout.alignment: Qt.AlignVCenter

                    sourceComponent: Button {
                        id: pinButton
                        implicitWidth: 36
                        implicitHeight: 36

                        background: StyledRect {
                            id: pinButtonBg
                            variant: panel.pinned ? "primary" : "bg"
                            enableShadow: Config.showBackground
                            Rectangle {
                                anchors.fill: parent
                                color: Styling.srItem("overprimary")
                                opacity: panel.pinned ? 0 : (pinButton.pressed ? 0.5 : (pinButton.hovered ? 0.25 : 0))
                                radius: parent.radius ?? 0

                                Behavior on opacity {
                                    enabled: (Config.animDuration ?? 0) > 0
                                    NumberAnimation {
                                        duration: (Config.animDuration ?? 0) / 2
                                    }
                                }
                            }
                        }

                        contentItem: Text {
                            text: Icons.pin
                            font.family: Icons.font
                            font.pixelSize: 18
                            color: panel.pinned ? pinButtonBg.item : (pinButton.pressed ? Colors.background : (Styling.srItem("overprimary") || Colors.foreground))
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter

                            rotation: panel.pinned ? 0 : 45
                            Behavior on rotation {
                                enabled: Config.animDuration > 0
                                NumberAnimation {
                                    duration: Config.animDuration / 2
                                }
                            }

                            Behavior on color {
                                enabled: Config.animDuration > 0
                                ColorAnimation {
                                    duration: Config.animDuration / 2
                                }
                            }
                        }

                        onClicked: panel.pinned = !panel.pinned

                        StyledToolTip {
                            show: pinButton.hovered
                            tooltipText: panel.pinned ? "Unpin bar" : "Pin bar"
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: panel.orientation === "horizontal" && integratedDockEnabled

                    Bar.IntegratedDock {
                        bar: panel
                        orientation: panel.orientation
                        anchors.verticalCenter: parent.verticalCenter

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
                    visible: !(panel.orientation === "horizontal" && integratedDockEnabled)
                }

                PresetsButton {
                    id: presetsButton
                }

                ToolsButton {
                    id: toolsButton
                }

                SysTray {
                    bar: panel
                    layer.enabled: Config.showBackground
                }

                ControlsButton {
                    id: controlsButton
                    bar: panel
                    layerEnabled: Config.showBackground
                }

                Bar.BatteryIndicator {
                    id: batteryIndicator
                    bar: panel
                    layerEnabled: Config.showBackground
                }

                Clock {
                    id: clockComponent
                    bar: panel
                    layerEnabled: Config.showBackground
                }

            }

            ColumnLayout {
                id: verticalLayout
                visible: panel.orientation === "vertical"
                anchors.fill: parent
                anchors.margins: 4
                spacing: 4

                LauncherButton {
                    id: launcherButtonVert
                    Layout.preferredHeight: 36
                }

                SysTray {
                    bar: panel
                    layer.enabled: Config.showBackground
                }

                ToolsButton {
                    id: toolsButtonVert
                }

                PresetsButton {
                    id: presetsButtonVert
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
                            bar: panel
                            layerEnabled: Config.showBackground
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Workspaces {
                            id: workspacesVert
                            orientation: panel.orientation
                            bar: QtObject {
                                property var screen: panel.screen
                            }
                            Layout.alignment: Qt.AlignHCenter
                        }

                        // Pin button (vertical)
                        Loader {
                            active: Config.bar?.showPinButton ?? true
                            visible: active
                            Layout.alignment: Qt.AlignHCenter

                            sourceComponent: Button {
                                id: pinButtonV
                                implicitWidth: 36
                                implicitHeight: 36

                                background: StyledRect {
                                    id: pinButtonVBg
                                    variant: panel.pinned ? "primary" : "bg"
                                    enableShadow: Config.showBackground
                                    Rectangle {
                                        anchors.fill: parent
                                        color: Styling.srItem("overprimary")
                                        opacity: panel.pinned ? 0 : (pinButtonV.pressed ? 0.5 : (pinButtonV.hovered ? 0.25 : 0))
                                        radius: parent.radius ?? 0

                                        Behavior on opacity {
                                            enabled: (Config.animDuration ?? 0) > 0
                                            NumberAnimation {
                                                duration: (Config.animDuration ?? 0) / 2
                                            }
                                        }
                                    }
                                }

                                contentItem: Text {
                                    text: Icons.pin
                                    font.family: Icons.font
                                    font.pixelSize: 18
                                    color: panel.pinned ? pinButtonVBg.item : (pinButtonV.pressed ? Colors.background : (Styling.srItem("overprimary") || Colors.foreground))
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter

                                    rotation: panel.pinned ? 0 : 45
                                    Behavior on rotation {
                                        enabled: Config.animDuration > 0
                                        NumberAnimation {
                                            duration: Config.animDuration / 2
                                        }
                                    }

                                    Behavior on color {
                                        enabled: Config.animDuration > 0
                                        ColorAnimation {
                                            duration: Config.animDuration / 2
                                        }
                                    }
                                }

                                onClicked: panel.pinned = !panel.pinned

                                StyledToolTip {
                                    show: pinButtonV.hovered
                                    tooltipText: panel.pinned ? "Unpin bar" : "Pin bar"
                                }
                            }
                        }

                        Bar.IntegratedDock {
                            bar: panel
                            orientation: panel.orientation
                            visible: integratedDockEnabled
                            Layout.fillHeight: true
                            Layout.fillWidth: true
                        }
                    }
                }

                ControlsButton {
                    id: controlsButtonVert
                    bar: panel
                    layerEnabled: Config.showBackground
                }

                Bar.BatteryIndicator {
                    id: batteryIndicatorVert
                    bar: panel
                    layerEnabled: Config.showBackground
                }

                Clock {
                    id: clockComponentVert
                    bar: panel
                    layerEnabled: Config.showBackground
                }

            }
        }
    }
}
