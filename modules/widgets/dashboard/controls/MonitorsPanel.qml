import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

Item {
    id: root
    implicitHeight: layout.implicitHeight
    Layout.fillWidth: true

    ColumnLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 14

        // ── Visual arrangement with drag & drop ──
        MonitorArrangementView {
            id: arrangementView
            Layout.fillWidth: true
        }

        // ── Section title ──
        Text {
            text: "Per-Monitor Settings"
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            font.weight: Font.Medium
            color: Colors.outline
            Layout.topMargin: 4
        }

        // ── Individual monitor cards ──
        Repeater {
            model: Quickshell.screens

            delegate: MonitorCard {
                required property int index
                required property var modelData
                monitorIndex: index
                screen: modelData
                Layout.fillWidth: true
            }
        }

        // ── Actions ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Button {
                text: "Reset Positions"
                Layout.fillWidth: true
                onClicked: {
                    for (var j = 0; j < Quickshell.screens.length; j++) {
                        var s = Quickshell.screens[j];
                        AxctlService.dispatch("monitor " + s.name + ",preferred,0x0,auto");
                    }
                }
            }

            Button {
                text: "Detect Displays"
                Layout.fillWidth: true
                onClicked: {
                    AxctlService.dispatch("monitor all,preferred,auto,auto");
                }
            }
        }
    }
}
