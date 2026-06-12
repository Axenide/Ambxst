import QtQuick
import Quickshell
import qs.modules.widgets.dashboard.controls
import qs.modules.components
import qs.modules.globals
import qs.modules.theme
import qs.config

FloatingWindow {
    id: settingsWindow

    // Window properties
    implicitWidth: 900
    implicitHeight: 650
    visible: GlobalStates.settingsWindowVisible

    // Center on screen (approximate, since FloatingWindow usually centers by default or relies on WM)
    // We can't easily force center without screen geometry, but WM usually handles it.

    color: "transparent"

    // Use a StyledRect for the background and styling
    StyledRect {
        anchors.fill: parent
        variant: "bg"
        radius: 0

        // Settings Tab Content
        SettingsTab {
            anchors.fill: parent
            anchors.margins: 16
        }
    }

    // Close on visibility change from outside
    onVisibleChanged: {
        if (!visible && GlobalStates.settingsWindowVisible) {
            GlobalStates.settingsWindowVisible = false;
        }
    }

    // Sync visibility from GlobalStates
    Connections {
        target: GlobalStates
        function onSettingsWindowVisibleChanged() {
            settingsWindow.visible = GlobalStates.settingsWindowVisible;
        }
    }
}
