import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import "../theme"

Rectangle {
    id: root

    required property var bar

    height: parent.height
    Layout.preferredWidth: rowLayout.implicitWidth + 8
    implicitWidth: rowLayout.implicitWidth + 8
    implicitHeight: parent.height - 8
    color: Colors.surfaceBright
    radius: 16

    RowLayout {
        id: rowLayout

        anchors.fill: parent
        anchors.margins: 4
        spacing: 8

        Repeater {
            model: SystemTray.items

            SysTrayItem {
                required property SystemTrayItem modelData

                bar: root.bar
                item: modelData
            }
        }
    }
}
