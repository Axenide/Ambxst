import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import "../theme"

Rectangle {
    id: root

    required property var bar

    height: parent.height
    Layout.preferredWidth: rowLayout.implicitWidth
    implicitWidth: rowLayout.implicitWidth
    implicitHeight: parent.height - 8
    color: Colors.surfaceBright
    radius: 0

    RowLayout {
        id: rowLayout

        anchors.centerIn: parent
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
