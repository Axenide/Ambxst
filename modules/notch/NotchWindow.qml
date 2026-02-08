import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.modules.globals
import qs.config

/*
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

    readonly property alias screenVisibilities: notchContent.screenVisibilities
    readonly property alias notchPosition: notchContent.notchPosition
    readonly property alias hoverActive: notchContent.hoverActive
    readonly property alias screenNotchOpen: notchContent.screenNotchOpen
    readonly property alias reveal: notchContent.reveal

    HyprlandFocusGrab {
        id: focusGrab
        windows: {
            let windowList = [notchPanel];
            // Agregar la barra de esta pantalla al focus grab cuando el notch este abierto
            if (notchContent.barPanelRef && (screenVisibilities.launcher || screenVisibilities.dashboard || screenVisibilities.powermenu || screenVisibilities.tools)) {
                windowList.push(notchContent.barPanelRef);
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
        item: notchContent.notchHitbox
    }

    Component.onCompleted: {
        Visibilities.registerNotchPanel(screen.name, notchPanel);
        Visibilities.registerNotch(screen.name, notchContent.notchContainerRef);
    }

    Component.onDestruction: {
        Visibilities.unregisterNotchPanel(screen.name);
        Visibilities.unregisterNotch(screen.name);
    }

    NotchContent {
        id: notchContent
        anchors.fill: parent
        screen: notchPanel.screen
    }
}
*/
Item {
    id: notchPanel
    visible: false
}
