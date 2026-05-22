import QtQuick
import QtQuick.Controls
import Quickshell.Services.Notifications
import qs.modules.theme
import qs.modules.components
import qs.config

Button {
    id: root
    property bool visibleWhen: true
    property int urgency: NotificationUrgency.Normal

    anchors.fill: parent
    hoverEnabled: true
    visible: visibleWhen

    background: Item {
        id: buttonBg
        property color iconColor: urgency == NotificationUrgency.Critical ? Colors.shadow : (root.pressed ? Colors.overError : Colors.error)
        
        Rectangle {
            anchors.fill: parent
            visible: urgency == NotificationUrgency.Critical
            color: parent.parent.hovered ? Qt.lighter(Colors.criticalRed, 1.3) : Colors.criticalRed
            radius: Styling.radius(4)

            Behavior on color {
                enabled: Config.animDuration > 0
                ColorAnimation {
                    duration: Config.animDuration
                }
            }
        }

        StyledRect {
            id: styledBg
            anchors.fill: parent
            visible: urgency != NotificationUrgency.Critical
            variant: parent.parent.pressed ? "error" : (parent.parent.hovered ? "focus" : "common")
            radius: Styling.radius(4)
        }
    }

    contentItem: Text {
        text: Icons.cancel
        textFormat: Text.RichText
        font.family: Icons.font
        font.pixelSize: 16
        color: root.background.iconColor
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
