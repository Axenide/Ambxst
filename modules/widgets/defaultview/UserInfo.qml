import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.services
import qs.modules.globals
import qs.config

Item {
    implicitWidth: avatarClip.width
    implicitHeight: 40

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
            if (Visibilities.currentActiveModule === "dashboard") {
                Visibilities.setActiveModule("overview");
            } else if (Visibilities.currentActiveModule === "overview") {
                GlobalStates.launcherCurrentTab = 0;
                Visibilities.setActiveModule("launcher");
            } else if (Visibilities.currentActiveModule === "launcher") {
                Visibilities.setActiveModule("");
            } else {
                GlobalStates.dashboardCurrentTab = 0;
                Visibilities.setActiveModule("dashboard");
            }
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Item {
                width: 24
                height: 24

                ClippingRectangle {
                    id: avatarClip
                    anchors.centerIn: parent
                    width: 24
                    height: 24
                    radius: Styling.radius(0)
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: `file://${Quickshell.env("HOME")}/.face.icon`
                        fillMode: Image.PreserveAspectCrop
                    }
                }
            }

            Text {
                id: userHostText
                anchors.verticalCenter: parent.verticalCenter
                text: `${Quickshell.env("USER")}@${hostnameCollector.text.trim()}`
                color: userHostArea.pressed ? Colors.overBackground : (userHostArea.containsMouse ? Styling.srItem("overprimary") : Colors.overBackground)
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(0)
                font.weight: Font.Bold
                elide: Text.ElideRight
                width: Math.min(implicitWidth, 180 - avatarClip.width - 8)
                visible: false

                Behavior on color {
                    enabled: Config.animDuration > 0
                    ColorAnimation {
                        duration: Config.animDuration / 2
                    }
                }
            }
        }
    }
}
