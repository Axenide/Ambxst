import QtQuick
import qs.modules.theme
import qs.config

Rectangle {
    color: "transparent"
    implicitWidth: 400
    implicitHeight: 300

    Text {
        anchors.centerIn: parent
        text: "Pins"
        color: Colors.adapter.overSurfaceVariant
        font.family: Config.theme.font
        font.pixelSize: 16
        font.weight: Font.Medium
    }
}
