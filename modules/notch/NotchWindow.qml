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
import qs.config
import qs.modules.widgets.osd
import "./NotchNotificationView.qml"

PanelWindow {
    id: notchPanel

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"

    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Get this screen's visibility state
    readonly property var screenVisibilities: Visibilities.getForScreen(screen.name)
    readonly property bool isScreenFocused: Hyprland.focusedMonitor && Hyprland.focusedMonitor.name === screen.name

    // Get the bar position for this screen
    readonly property string barPosition: Config.bar?.position ?? "top"
    readonly property string notchPosition: Config.notchPosition ?? "top"

    // Get the bar panel for this screen to check its state
    readonly property var barPanelRef: Visibilities.barPanels[screen.name]

    // Check if bar is pinned (use bar state directly)
    readonly property bool barPinned: {
        if (barPanelRef && typeof barPanelRef.pinned !== 'undefined') {
            return barPanelRef.pinned;
        }
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

    // Fullscreen detection - check if active toplevel is fullscreen
    readonly property bool activeWindowFullscreen: {
        const toplevel = ToplevelManager.activeToplevel;
        if (!toplevel || !toplevel.activated)
            return false;
        return toplevel.fullscreen === true;
    }

    // Should auto-hide: when bar is NOT same side (always), unpinned OR when fullscreen
    // This ensures notch follows bar's auto-hide behavior regardless of position, but always hides if bar is not at the same side
    readonly property bool shouldAutoHide: barPosition !== notchPosition || !barPinned || activeWindowFullscreen

    // Check if the bar for this screen is vertical
    readonly property bool isBarVertical: barPosition === "left" || barPosition === "right"

    // Notch state properties
    readonly property bool screenNotchOpen: screenVisibilities ? (screenVisibilities.launcher || screenVisibilities.dashboard || screenVisibilities.powermenu || screenVisibilities.tools) : false
    readonly property bool hasActiveNotifications: Notifications.popupList.length > 0

    // Hover state with delay to prevent flickering
    property bool hoverActive: false
    property bool showingOSD: false

    // Track if mouse is over any notch-related area
    readonly property bool isMouseOverNotch: notchMouseAreaHover.hovered || notchRegionHover.hovered

    // Reveal logic:
    readonly property bool reveal: {
        // If not auto-hiding (pinned and not fullscreen), always show
        if (!shouldAutoHide) return true;
        
        // Show on interaction (hover, open, notifications)
        // This works even in fullscreen, ensuring hover always works
        if (screenNotchOpen || hasActiveNotifications || hoverActive || barHoverActive || showingOSD) {
            return true;
        }
        
        // Show on desktop (no active window) - but NOT if fullscreen mode forced auto-hide
        // (activeWindowFullscreen implies there IS an active window)
        if (!activeWindowFullscreen && !ToplevelManager.activeToplevel?.activated) {
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
            if (!notchPanel.isMouseOverNotch) {
                notchPanel.hoverActive = false;
            }
        }
    }

    property var suspendConnections: Connections {
        target: SuspendManager
        function onPreparingForSleep() {
            hideDelayTimer.stop();
            notchPanel.hoverActive = false;
            // Force close any open modules to ensure a clean state on wake
            Visibilities.setActiveModule("");
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

    HyprlandFocusGrab {
        id: focusGrab
        windows: {
            let windowList = [notchPanel];
            // Agregar la barra de esta pantalla al focus grab cuando el notch este abierto
            if (barPanelRef && (screenVisibilities.launcher || screenVisibilities.dashboard || screenVisibilities.powermenu || screenVisibilities.tools)) {
                windowList.push(barPanelRef);
            }
            return windowList;
        }
        active: notchPanel.screenNotchOpen

        onCleared: {
            Visibilities.setActiveModule("");
        }
    }

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay

    mask: Region {
        item: notchPanel.reveal ? notchRegionContainer : notchHoverRegion
    }

    Component.onCompleted: {
        Visibilities.registerNotchPanel(screen.name, notchPanel);
        Visibilities.registerNotch(screen.name, notchContainer);
    }

    Component.onDestruction: {
        Visibilities.unregisterNotchPanel(screen.name);
        Visibilities.unregisterNotch(screen.name);
    }

    // Default view component - user@host text
    Component {
        id: defaultViewComp
        DefaultView {}
    }

    // Launcher view component
    Component {
        id: launcherViewComp
        LauncherView {}
    }

    // Dashboard view component
    Component {
        id: dashboardViewComp
        DashboardView {}
    }

    // Power menu view component
    Component {
        id: powermenuViewComp
        PowerMenuView {}
    }

    // Tools menu view component
    Component {
        id: toolsMenuViewComp
        ToolsMenuView {}
    }

    // Notification view component
    Component {
        id: notificationViewComp
        NotchNotificationView {}
    }

    // OSD view component
    Component {
        id: osdViewComp
        OSDView {}
    }

    Timer {
        id: osdTimer
        interval: 2000
        repeat: false
        onTriggered: {
            if (notchPanel.isMouseOverNotch) {
                osdTimer.restart();
                return;
            }

            if (notchContainer.stackView.currentItem && notchContainer.stackView.currentItem.hasOwnProperty("showVolume")) {
                notchContainer.stackView.pop();
                
                // Back to default view
                notchContainer.isShowingDefault = true;
                notchContainer.isShowingNotifications = false;
                notchPanel.showingOSD = false;
            }
        }
    }

    property bool startupComplete: false
    Timer {
        id: startupTimer
        interval: 3000
        running: true
        repeat: false
        onTriggered: {
            console.log("[NotchWindow] Startup complete");
            notchPanel.startupComplete = true;
        }
    }

    function showOSD(type, value, icon) {
        console.log("[NotchWindow] showOSD called with type:", type, "value:", value);
        // Do not show OSD if notch is already open with a menu
        if (notchPanel.screenNotchOpen) {
            console.log("[NotchWindow] OSD skipped: screenNotchOpen is true");
            return;
        }
        
        // Do not show OSD on startup
        if (!notchPanel.startupComplete) {
            console.log("[NotchWindow] OSD skipped: startup not complete");
            return;
        }

        const currentItem = notchContainer.stackView.currentItem;
        const isOSD = currentItem && currentItem.hasOwnProperty("showVolume"); // Check for OSDView property
        console.log("[NotchWindow] Current item is OSD?", isOSD);

        if (isOSD) {
            console.log("[NotchWindow] Updating existing OSD");
            // Update existing OSDView
            if (type === "volume") {
                currentItem.showVolume = true;
                currentItem.volumeValue = value;
            } else if (type === "mic") {
                currentItem.showMic = true;
                currentItem.micValue = value;
            } else if (type === "brightness") {
                currentItem.showBrightness = true;
                currentItem.brightnessValue = value;
            }
            osdTimer.restart();
            notchPanel.showingOSD = true;
        } else {
            // Not current, push new OSDView
            if (notchContainer.stackView.depth === 1) {
                var props = { 
                    showVolume: false, 
                    showMic: false, 
                    showBrightness: false,
                    volumeValue: 0, 
                    micValue: 0, 
                    brightnessValue: 0,
                    onKeepAlive: () => osdTimer.restart() 
                };
                
                if (type === "volume") {
                    props.showVolume = true;
                    props.volumeValue = value;
                } else if (type === "mic") {
                     props.showMic = true;
                     props.micValue = value;
                } else if (type === "brightness") {
                     props.showBrightness = true;
                     props.brightnessValue = value;
                }
                
                notchContainer.stackView.push(osdViewComp, props);
                notchContainer.isShowingDefault = false;
                osdTimer.restart();
                notchPanel.showingOSD = true;
            }
        }
    }

    Connections {
        target: Audio
        function onValueChanged() {
             console.log("[NotchWindow] Audio.onValueChanged received, value:", Audio.value);
             showOSD("volume", Audio.value, Audio.volumeIcon(Audio.value, Audio.muted));
        }
        function onMutedChanged() {
             console.log("[NotchWindow] Audio.onMutedChanged received, muted:", Audio.muted);
             showOSD("volume", Audio.value, Audio.volumeIcon(Audio.value, Audio.muted));
        }
    }

    Connections {
        target: Audio
        function onMicValueChanged() {
             console.log("[NotchWindow] Audio.onMicValueChanged received, value:", Audio.micValue);
             showOSD("mic", Audio.micValue, Audio.micMuted ? Icons.microphoneOff : Icons.microphone);
        }
        function onMicMutedChanged() {
             console.log("[NotchWindow] Audio.onMicMutedChanged received, muted:", Audio.micMuted);
             showOSD("mic", Audio.micValue, Audio.micMuted ? Icons.microphoneOff : Icons.microphone);
        }
    }

    Connections {
        target: Brightness
        function onBrightnessChanged() {
             // Find internal screen monitor
             const monitor = Brightness.monitors.find(m => Brightness.isInternalScreen(m.screen) && m.screen.name === screen.name);
             if (monitor) {
                 showOSD("brightness", monitor.brightness, Icons.sun);
             } else {
                 // Fallback to any monitor if needed, or just the first one associated
                 if (Brightness.monitors.length > 0) {
                      showOSD("brightness", Brightness.monitors[0].brightness, Icons.sun);
                 }
             }
        }
    }

        // Hover region for detecting mouse when notch is hidden (doesn't block clicks)
    // Placed outside notchRegionContainer so it can work with mask independently
    Item {
        id: notchHoverRegion

        // Width follows the notch, height is small hover region when hidden
        width: notchRegionContainer.width + 20
        height: notchPanel.reveal ? notchRegionContainer.height : Math.max(Config.notch?.hoverRegionHeight ?? 8, 8)

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: notchPanel.notchPosition === "top" ? parent.top : undefined
        anchors.bottom: notchPanel.notchPosition === "bottom" ? parent.bottom : undefined

        Behavior on height {

            enabled: Config.animDuration > 0 && notchPanel.shouldAutoHide
            NumberAnimation {
                duration: Config.animDuration / 4
                easing.type: Easing.OutCubic
            }
        }

        // HoverHandler doesn't block mouse events
        HoverHandler {
            id: notchMouseAreaHover
            enabled: notchPanel.shouldAutoHide
        }
    }

    Item {
        id: notchRegionContainer
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: notchPanel.notchPosition === "top" ? parent.top : undefined
        anchors.bottom: notchPanel.notchPosition === "bottom" ? parent.bottom : undefined
        
        width: Math.max(notchAnimationContainer.width, notificationPopupContainer.visible ? notificationPopupContainer.width : 0)
        height: notchAnimationContainer.height + (notificationPopupContainer.visible ? notificationPopupContainer.height + notificationPopupContainer.anchors.topMargin : 0)

        // HoverHandler to detect when mouse is over the revealed notch
        HoverHandler {
            id: notchRegionHover
            enabled: notchPanel.shouldAutoHide
        }

        // Animation container for reveal/hide
        Item {
            id: notchAnimationContainer
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: notchPanel.notchPosition === "top" ? parent.top : undefined
            anchors.bottom: notchPanel.notchPosition === "bottom" ? parent.bottom : undefined

            width: notchContainer.width
            height: notchContainer.height + (notchPanel.notchPosition === "top" ? notchContainer.anchors.topMargin : notchContainer.anchors.bottomMargin)

            // Opacity animation
            opacity: notchPanel.reveal ? 1 : 0
            Behavior on opacity {
                enabled: Config.animDuration > 0 && notchPanel.shouldAutoHide
                NumberAnimation {
                    duration: Config.animDuration / 2
                    easing.type: Easing.OutCubic
                }
            }

            // Slide animation (slide up when hidden)
            transform: Translate {
                y: {
                    if (notchPanel.reveal) return 0;
                    if (notchPanel.notchPosition === "top")
                        return -(Math.max(notchContainer.height, 50) + 16);
                    else
                        return (Math.max(notchContainer.height, 50) + 16);
                }
                Behavior on y {
                    enabled: Config.animDuration > 0 && notchPanel.shouldAutoHide
                    NumberAnimation {
                        duration: Config.animDuration / 2
                        easing.type: Easing.OutCubic
                    }
                }
            }

            // Center notch
            Notch {
                id: notchContainer
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: notchPanel.notchPosition === "top" ? parent.top : undefined
                anchors.bottom: notchPanel.notchPosition === "bottom" ? parent.bottom : undefined

                anchors.topMargin: notchPanel.notchPosition === "top" ? (Config.notchTheme === "default" ? 0 : (Config.notchTheme === "island" ? 4 : 0)) : 0
                anchors.bottomMargin: notchPanel.notchPosition === "bottom" ? (Config.notchTheme === "default" ? 0 : (Config.notchTheme === "island" ? 4 : 0)) : 0

                layer.enabled: true
                layer.effect: Shadow {}

                defaultViewComponent: defaultViewComp
                launcherViewComponent: launcherViewComp
                dashboardViewComponent: dashboardViewComp
                powermenuViewComponent: powermenuViewComp
                toolsMenuViewComponent: toolsMenuViewComp
                notificationViewComponent: notificationViewComp
                osdViewComponent: osdViewComp
                visibilities: screenVisibilities

                // Handle global keyboard events
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape && notchPanel.screenNotchOpen) {
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
            anchors.top: notchPanel.notchPosition === "top" ? notchAnimationContainer.bottom : undefined
            anchors.bottom: notchPanel.notchPosition === "bottom" ? notchAnimationContainer.top : undefined
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: notchPanel.notchPosition === "top" ? 4 : 0
            anchors.bottomMargin: notchPanel.notchPosition === "bottom" ? 4 : 0
            
            width: Math.round(popupHovered ? 420 + 48 : 320 + 48)
            height: shouldShowNotificationPopup ? (popupHovered ? notificationPopup.implicitHeight + 32 : notificationPopup.implicitHeight + 32) : 0
            clip: false
            visible: height > 0
            z: 999
            radius: Styling.radius(20)

            // Apply same reveal animation as notch
            opacity: notchPanel.reveal ? 1 : 0
            Behavior on opacity {
                enabled: Config.animDuration > 0 && notchPanel.shouldAutoHide
                NumberAnimation {
                    duration: Config.animDuration / 2
                    easing.type: Easing.OutCubic
                }
            }

            transform: Translate {
                y: {
                    if (notchPanel.reveal) return 0;
                    if (notchPanel.notchPosition === "top")
                        return -(notchContainer.height + 16);
                    else
                        return (notchContainer.height + 16);
                }
                Behavior on y {
                    enabled: Config.animDuration > 0 && notchPanel.shouldAutoHide
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
                if (!notchPanel.hasActiveNotifications || !notchPanel.screenNotchOpen)
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
                notchContainer.stackView.push(launcherViewComp);
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
                notchContainer.stackView.push(dashboardViewComp);
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
                notchContainer.stackView.push(powermenuViewComp);
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
                notchContainer.stackView.push(toolsMenuViewComp);
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
}
