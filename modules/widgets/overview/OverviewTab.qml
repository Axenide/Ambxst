import QtQuick
import qs.modules.theme

Rectangle {
    color: "transparent"
    implicitWidth: 400
    implicitHeight: 300

    Text {
        anchors.centerIn: parent
        text: "Widgets"
        color: Colors.adapter.overSurfaceVariant
        font.family: Styling.defaultFont
        font.pixelSize: 16
        font.weight: Font.Medium
    }
}