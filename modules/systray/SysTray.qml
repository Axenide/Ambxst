import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import "../theme"

StyledContainer {
    id: root

    required property var bar

    height: parent.height
    Layout.preferredWidth: rowLayout.implicitWidth + 16
    implicitWidth: rowLayout.implicitWidth + 16
    implicitHeight: rowLayout.implicitHeight + 16

    RowLayout {
        id: rowLayout

        anchors.fill: parent
        anchors.margins: 8
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
