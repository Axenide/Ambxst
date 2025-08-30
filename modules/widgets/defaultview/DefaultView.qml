import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.theme
import qs.modules.services
import qs.config

Item {
    implicitWidth: userHostText.implicitWidth
    implicitHeight: userHostText.implicitHeight

    Process {
        id: hostnameProcess
        command: ["hostname"]
        running: true

        stdout: StdioCollector {
            id: hostnameCollector
            waitForEnd: true

            onStreamFinished: {}
        }
    }

    MouseArea {
        id: userHostArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            // Cycle through views: default -> dashboard -> overview -> launcher -> default
            if (Visibilities.currentActiveModule === "dashboard") {
                Visibilities.setActiveModule("overview");
            } else if (Visibilities.currentActiveModule === "overview") {
                Visibilities.setActiveModule("launcher");
            } else if (Visibilities.currentActiveModule === "launcher") {
                Visibilities.setActiveModule("");
            } else {
                Visibilities.setActiveModule("dashboard");
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: 14
            color: "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: Config.animDuration / 2
                }
            }
        }
    }

    Text {
        id: userHostText
        anchors.centerIn: parent
        text: `${Quickshell.env("USER")}@${hostnameCollector.text.trim()}`
        color: userHostArea.pressed ? Colors.adapter.overBackground : (userHostArea.containsMouse ? Colors.adapter.primary : Colors.adapter.overBackground)
        font.family: Config.theme.font
        font.pixelSize: Config.theme.fontSize
        font.weight: Font.Bold

        Behavior on color {
            ColorAnimation {
                duration: Config.animDuration / 2
            }
        }
    }
}
