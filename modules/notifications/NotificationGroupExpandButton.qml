import QtQuick
import QtQuick.Controls
import qs.modules.theme
import qs.config

Button {
    id: root
    property int count: 1
    property bool expanded: false
    property real fontSize: 14

    visible: count > 1
    width: 24
    height: 24

    background: Rectangle {
        color: root.pressed ? Colors.adapter.primary : (root.hovered ? Colors.surfaceBright : Colors.surfaceContainerHigh)
        radius: Config.roundness

        Behavior on color {
            ColorAnimation {
                duration: Config.animDuration / 2
            }
        }
    }

    contentItem: Text {
        text: root.expanded ? Icons.caretUp : Icons.caretDown
        font.family: Icons.font
        font.pixelSize: root.fontSize
        color: root.pressed ? Colors.adapter.overPrimary : (root.hovered ? Colors.adapter.overBackground : Colors.adapter.primary)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
