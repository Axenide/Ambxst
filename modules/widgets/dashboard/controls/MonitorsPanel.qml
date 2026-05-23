import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.modules.theme
import qs.modules.components
import qs.config

Item {
    id: root
    implicitHeight: layout.implicitHeight
    Layout.fillWidth: true

    ColumnLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 8

        Text {
            text: "Connected: " + Quickshell.screens.length + " monitor(s)"
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            color: Colors.outline
        }

        Repeater {
            model: Quickshell.screens.length

            delegate: Rectangle {
                required property int index
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                color: Colors.surface
                radius: 8
                border.color: Colors.outline
                border.width: 1

                property var scr: Quickshell.screens[index]

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: parent.parent.scr ? parent.parent.scr.name + "  " + parent.parent.scr.width + "x" + parent.parent.scr.height : "Monitor " + (index + 1)
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(0)
                            font.bold: true
                            color: Colors.overSurface
                        }

                        Text {
                            text: parent.parent.scr ? "Position: " + (parent.parent.scr.x || 0) + "x" + (parent.parent.scr.y || 0) : ""
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            color: Colors.outline
                        }
                    }
                }
            }
        }

        Button {
            text: "Reset all positions"
            Layout.fillWidth: true
            Layout.topMargin: 8
            onClicked: {
                for (var i = 0; i < Quickshell.screens.length; i++) {
                    var s = Quickshell.screens[i];
                    Qt.createQmlObject('import Quickshell.Io; Process { command: ["bash", "-c", "hyprctl keyword monitor ' + s.name + ',preferred,0x0,1"]; running: true }', root);
                }
            }
        }
    }
}
