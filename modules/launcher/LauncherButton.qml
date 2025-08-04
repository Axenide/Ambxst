import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import qs.modules.theme
import qs.modules.globals
import qs.config

Button {
    id: root

    implicitWidth: 36
    implicitHeight: 36

    background: StyledContainer {
        color: root.pressed ? Colors.adapter.primary : (root.hovered ? Colors.adapter.surfaceBright : Colors.background)

        Behavior on color {
            ColorAnimation {
                duration: Configuration.animDuration / 2
            }
        }

        Behavior on border.color {
            ColorAnimation {
                duration: Configuration.animDuration / 2
            }
        }
    }

    contentItem: Text {
        text: Configuration.launcherIcon
        textFormat: Text.RichText
        font.family: Styling.iconFont
        font.pixelSize: 20
        color: root.pressed ? Colors.background : Colors.adapter.primary
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        Behavior on color {
            ColorAnimation {
                duration: Configuration.animDuration / 2
            }
        }
    }

    onClicked: {
        // Toggle launcher - si ya está abierto, se cierra; si no, abre launcher y cierra dashboard
        if (GlobalStates.launcherOpen) {
            GlobalStates.launcherOpen = false;
        } else {
            GlobalStates.dashboardOpen = false;
            GlobalStates.launcherOpen = true;
        }
    }

    ToolTip.visible: false
    ToolTip.text: "Open Application Launcher"
    ToolTip.delay: 1000
}
