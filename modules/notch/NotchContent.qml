import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.modules.globals
import qs.modules.theme
import qs.modules.widgets.defaultview
import qs.modules.widgets.dashboard
import qs.modules.widgets.powermenu
import qs.modules.widgets.tools
import qs.modules.services
import qs.modules.components
import qs.modules.widgets.launcher
import qs.modules.bar.workspaces
import qs.config
import "./NotchNotificationView.qml"

Item {
    id: root

    required property ShellScreen screen
    property bool unifiedEffectActive: false

    // Get this screen's visibility state
    readonly property var screenVisibilities: Visibilities.getForScreen(screen.name)
    readonly property bool isScreenFocused: Hyprland.focusedMonitor && Hyprland.focusedMonitor.name === screen.name

    // Monitor reference and refrence to toplevels on monitor
    readonly property var hyprlandMonitor: Hyprland.monitorFor(screen)
    readonly property var toplevels: hyprlandMonitor.activeWorkspace.toplevels.values

    // Check if there are any windows on the current monitor and workspace
    readonly property bool hasWindows: {
        if (!hyprlandMonitor) return false;
        const activeWorkspaceId = hyprlandMonitor.activeWorkspace.id;
        const monId = hyprlandMonitor.id;
        const wins = HyprlandData.windowList;
        for (let i = 0; i < wins.length; i++) {
            // We only care about windows on the current monitor and workspace
            // that are not floating (floating windows usually don't trigger auto-hide)
            if (wins[i].monitor === monId && wins[i].workspace.id === activeWorkspaceId && !wins[i].floating) {
                return true;
            }
        }
        return false;
    }

    // Get the bar position for this screen
    readonly property string barPosition: Config.bar?.position ?? "top"
    readonly property string notchPosition: Config.notchPosition ?? "top"

    // Get the bar panel for this screen to check its state
    readonly property var barPanelRef: Visibilities.barPanels[screen.name]

    // Check if bar is pinned (use bar state directly)
    readonly property bool barPinned: {
        // If barPanelRef exists, trust its pinned state explicitly
        if (barPanelRef && typeof barPanelRef.pinned !== 'undefined') {
            return barPanelRef.pinned;
        }
        // Fallback to config only if panel ref is missing
        return Config.bar?.pinnedOnStartup ?? true;
    }
    
    // Check if bar is hovering (for synchronized reveal when bar is at same side)
    readonly property bool barHoverActive: {
        if (barPosition !== notchPosition)
            return false;
        if (barPanelRef && typeof barPanelRef.hoverActive !== 'undefined') {
            return barPanelRef.hoverActive;
        }
        return false;
    }

    // Fullscreen detection - check if active toplevel is fullscreen on this screen
    readonly property bool activeWindowFullscreen: {
        if (!hyprlandMonitor || !toplevels) return false;

        // Check all toplevels on active workspcace
        for (var i = 0; i < toplevels.length; i++) {
            // Checks first if the wayland handle is ready
            if (toplevels[i].wayland && toplevels[i].wayland.fullscreen == true) {
               return true;
            }
        }
        return false;
    }

    // Should auto-hide logic:
    // 1. If notch and bar are on different sides: hide if keepHidden is ON, OR if windows/fullscreen are present
    // 2. If notch and bar are on same side: hide only if bar is unpinned OR if fullscreen is present
    readonly property bool shouldAutoHide: {
        if (barPosition !== notchPosition) {
            if (Config.notch?.keepHidden ?? false) return true;
            return hasWindows || activeWindowFullscreen;
        }
        return !barPinned || activeWindowFullscreen;
    }

    // Check if the bar for this screen is vertical
    readonly property bool isBarVertical: barPosition === "left" || barPosition === "right"

    // Notch state properties
    readonly property bool screenNotchOpen: screenVisibilities ? (screenVisibilities.launcher || screenVisibilities.dashboard || screenVisibilities.powermenu || screenVisibilities.tools) : false
    readonly property bool hasActiveNotifications: Notifications.popupList.length > 0

    // Hover state with delay to prevent flickering
    property bool hoverActive: false

    // Track if mouse is over any notch-related area
    readonly property bool isMouseOverNotch: notchMouseAreaHover.hovered || notchRegionHover.hovered

    readonly property real reportedNotchWidth: Math.max(
        notchContainer.implicitWidth ?? 0,
        notchContainer.width ?? 0,
        notchRegionContainer.width ?? 0
    )

    onReportedNotchWidthChanged: {
        if (root.screen && root.screen.name)
            Visibilities.setNotchWidth(root.screen.name, reportedNotchWidth);
    }

    // Reveal logic:
    readonly property bool reveal: {
        // If keepHidden is true, ONLY show on interaction
        // UNLESS notch and bar are on same side (e.g. both top), then keepHidden is IGNORED for sync consistency
        if ((Config.notch?.keepHidden ?? false) && barPosition !== notchPosition) {
            return (screenNotchOpen || hasActiveNotifications || hoverActive || barHoverActive);
        }

        // If not auto-hiding (pinned and not fullscreen), always show
        if (!shouldAutoHide) return true;
        
        // Show on interaction (hover, open, notifications)
        // This works even in fullscreen, ensuring hover always works
        if (screenNotchOpen || hasActiveNotifications || hoverActive || barHoverActive) {
            return true;
        }
        
        return false;
    }

    // Timer to delay hiding the notch after mouse leaves
    Timer {
        id: hideDelayTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (!root.isMouseOverNotch) {
                root.hoverActive = false;
            }
        }
    }

    // Watch for mouse state changes
    onIsMouseOverNotchChanged: {
        if (isMouseOverNotch) {
            // Immediately show when mouse enters any notch area
            hideDelayTimer.stop();
            hoverActive = true;
        } else {
            // Delay hiding when mouse leaves
            hideDelayTimer.restart();
        }
    }

    // The hitbox for the mask
    readonly property Item notchHitbox: root.reveal ? notchRegionContainer : notchHoverRegion

    // Default view component - user@host text
    Component {
        id: defaultViewComponent
        DefaultView {}
    }

    // Persistent views to avoid creation lag when opening the notch
    LauncherView {
        id: persistentLauncherView
        visible: false
    }

    DashboardView {
        id: persistentDashboardView
        visible: false
    }

    // Persistent power menu view
    PowerMenuView {
        id: persistentPowerMenuView
        visible: false
    }

    // Persistent tools menu view
    ToolsMenuView {
        id: persistentToolsMenuView
        visible: false
    }

    // Notification view component
    Component {
        id: notificationViewComponent
        NotchNotificationView {}
    }

    // Hover region for detecting mouse when notch is hidden (doesn't block clicks)
    Item {
        id: notchHoverRegion

        // Width follows the notch, height is small hover region when hidden
        width: notchRegionContainer.width + 20
        height: root.reveal ? notchRegionContainer.height : Math.max(Config.notch?.hoverRegionHeight ?? 8, 8)

        x: (parent.width - width) / 2
        y: root.notchPosition === "top" ? 0 : parent.height - height

        Behavior on height {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration / 4
                easing.type: Easing.OutCubic
            }
        }

        // HoverHandler doesn't block mouse events
        HoverHandler {
            id: notchMouseAreaHover
            enabled: true
        }
    }

    Item {
        id: notchRegionContainer
        
        width: Math.max(notchAnimationContainer.width, notificationPopupContainer.visible ? notificationPopupContainer.width : 0)
        height: notchAnimationContainer.height + (notificationPopupContainer.visible ? notificationPopupContainer.height + notificationPopupContainer.anchors.topMargin : 0)

        x: (parent.width - width) / 2
        y: root.notchPosition === "top" ? 0 : parent.height - height

        // HoverHandler to detect when mouse is over the revealed notch
        HoverHandler {
            id: notchRegionHover
            enabled: true
        }

        // Animation container for reveal/hide
        Item {
            id: notchAnimationContainer
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: root.notchPosition === "top" ? parent.top : undefined
            anchors.bottom: root.notchPosition === "bottom" ? parent.bottom : undefined

            width: notchContainer.width
            height: notchContainer.height + (root.notchPosition === "top" ? notchContainer.anchors.topMargin : notchContainer.anchors.bottomMargin)

            // Opacity animation
            opacity: root.reveal ? 1 : 0
            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 2
                    easing.type: Easing.OutCubic
                }
            }

            // Slide animation (slide up when hidden)
            transform: Translate {
                y: {
                    if (root.reveal) return 0;
                    if (root.notchPosition === "top")
                        return -(Math.max(notchContainer.height, 50) + 16);
                    else
                        return (Math.max(notchContainer.height, 50) + 16);
                }
                Behavior on y {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration / 2
                        easing.type: Easing.OutCubic
                    }
                }
            }

            // Center notch
            Notch {
                id: notchContainer
                unifiedEffectActive: root.unifiedEffectActive
                parentHovered: root.isMouseOverNotch
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: root.notchPosition === "top" ? parent.top : undefined
                anchors.bottom: root.notchPosition === "bottom" ? parent.bottom : undefined

                readonly property int frameOffset: Config.bar?.frameEnabled ? (Config.bar?.frameThickness ?? 6) : 0

                anchors.topMargin: (root.notchPosition === "top" ? (Config.notchTheme === "default" ? 0 : (Config.notchTheme === "island" ? 4 : 0)) : 0) + (root.notchPosition === "top" ? frameOffset : 0)
                anchors.bottomMargin: (root.notchPosition === "bottom" ? (Config.notchTheme === "default" ? 0 : (Config.notchTheme === "island" ? 4 : 0)) : 0) + (root.notchPosition === "bottom" ? frameOffset : 0)

                // layer.enabled: true
                // layer.effect: Shadow {}

                defaultViewComponent: defaultViewComponent
                launcherViewComponent: null
                dashboardViewComponent: null
                powermenuViewComponent: null
                toolsMenuViewComponent: null
                notificationViewComponent: notificationViewComponent
                visibilities: root.screenVisibilities

                // Handle global keyboard events
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape && root.screenNotchOpen) {
                        Visibilities.setActiveModule("");
                        event.accepted = true;
                    }
                }
            }
        }

        // Popup de notificaciones debajo del notch
        StyledRect {
            id: notificationPopupContainer
            variant: "bg"
            anchors.top: root.notchPosition === "top" ? notchAnimationContainer.bottom : undefined
            anchors.bottom: root.notchPosition === "bottom" ? notchAnimationContainer.top : undefined
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: root.notchPosition === "top" ? 4 : 0
            anchors.bottomMargin: root.notchPosition === "bottom" ? 4 : 0
            
            width: Math.round(popupHovered ? 420 + 48 : 320 + 48)
            height: shouldShowNotificationPopup ? (popupHovered ? notificationPopup.implicitHeight + 32 : notificationPopup.implicitHeight + 32) : 0
            clip: false
            visible: height > 0
            z: 999
            radius: Styling.radius(20)

            // Apply same reveal animation as notch
            opacity: root.reveal ? 1 : 0
            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 2
                    easing.type: Easing.OutCubic
                }
            }

            transform: Translate {
                y: {
                    if (root.reveal) return 0;
                    if (root.notchPosition === "top")
                        return -(notchContainer.height + 16);
                    else
                        return (notchContainer.height + 16);
                }
                Behavior on y {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration / 2
                        easing.type: Easing.OutCubic
                    }
                }
            }

            layer.enabled: true
            layer.effect: Shadow {}

            property bool popupHovered: false

            readonly property bool shouldShowNotificationPopup: {
                // Mostrar solo si hay notificaciones y el notch esta expandido
                if (!root.hasActiveNotifications || !root.screenNotchOpen)
                    return false;

                // NO mostrar si estamos en el launcher (widgets tab con currentTab === 0)
                if (screenVisibilities.dashboard) {
                    // Solo ocultar si estamos en el widgets tab (dashboard tab 0) Y mostrando el launcher (widgetsTab index 0)
                    return !(GlobalStates.dashboardCurrentTab === 0 && GlobalStates.widgetsTabCurrentIndex === 0);
                }

                return true;
            }

            Behavior on width {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.2
                }
            }

            Behavior on height {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration
                    easing.type: Easing.OutQuart
                }
            }

            HoverHandler {
                id: popupHoverHandler
                enabled: notificationPopupContainer.shouldShowNotificationPopup

                onHoveredChanged: {
                    notificationPopupContainer.popupHovered = hovered;
                }
            }

            NotchNotificationView {
                id: notificationPopup
                anchors.fill: parent
                anchors.margins: 16
                visible: notificationPopupContainer.shouldShowNotificationPopup
                opacity: visible ? 1 : 0
                notchHovered: notificationPopupContainer.popupHovered

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                }
            }
        }
    }

    // Listen for dashboard and powermenu state changes
    Connections {
        target: screenVisibilities

        function onLauncherChanged() {
            if (screenVisibilities.launcher) {
                notchContainer.stackView.push(persistentLauncherView);
                Qt.callLater(() => {
                    if (notchContainer.stackView.currentItem) {
                        notchContainer.stackView.currentItem.forceActiveFocus();
                    }
                });
            } else {
                if (notchContainer.stackView.depth > 1) {
                    notchContainer.stackView.pop();
                    notchContainer.isShowingDefault = true;
                    notchContainer.isShowingNotifications = false;
                }
            }
        }

        function onDashboardChanged() {
            if (screenVisibilities.dashboard) {
                notchContainer.stackView.push(persistentDashboardView);
                Qt.callLater(() => {
                    if (notchContainer.stackView.currentItem) {
                        notchContainer.stackView.currentItem.forceActiveFocus();
                    }
                });
            } else {
                if (notchContainer.stackView.depth > 1) {
                    notchContainer.stackView.pop();
                    notchContainer.isShowingDefault = true;
                    notchContainer.isShowingNotifications = false;
                }
            }
        }

        function onPowermenuChanged() {
            if (screenVisibilities.powermenu) {
                notchContainer.stackView.push(persistentPowerMenuView);
                Qt.callLater(() => {
                    if (notchContainer.stackView.currentItem) {
                        notchContainer.stackView.currentItem.forceActiveFocus();
                    }
                });
            } else {
                if (notchContainer.stackView.depth > 1) {
                    notchContainer.stackView.pop();
                    notchContainer.isShowingDefault = true;
                    notchContainer.isShowingNotifications = false;
                }
            }
        }

        function onToolsChanged() {
            if (screenVisibilities.tools) {
                notchContainer.stackView.push(persistentToolsMenuView);
                Qt.callLater(() => {
                    if (notchContainer.stackView.currentItem) {
                        notchContainer.stackView.currentItem.forceActiveFocus();
                    }
                });
            } else {
                if (notchContainer.stackView.depth > 1) {
                    notchContainer.stackView.pop();
                    notchContainer.isShowingDefault = true;
                    notchContainer.isShowingNotifications = false;
                }
            }
        }
    }

    // Export some internal items for Visibilities
    property alias notchContainerRef: notchContainer
    property alias notchRegionWidth: notchRegionContainer.width

    Component.onCompleted: {
        if (root.screen && root.screen.name)
            Visibilities.setNotchWidth(root.screen.name, reportedNotchWidth);
    }

    Component.onDestruction: {
        if (root.screen && root.screen.name)
            Visibilities.clearNotchWidth(root.screen.name);
    }
}
