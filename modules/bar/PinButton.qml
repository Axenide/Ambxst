pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.modules.theme
import qs.modules.components
import qs.config

Button {
    id: root

    required property var bar

    property bool vertical: bar.orientation === "vertical"
    property bool enableShadow: true

    property real radius: 0
    property real startRadius: radius
    property real endRadius: radius

    readonly property bool pinned: bar.pinned

    implicitWidth: 36
    implicitHeight: 36

    background: StyledRect {
        id: pinButtonBg
        variant: root.pinned ? "primary" : "bg"
        enableShadow: root.enableShadow

        property real startRadius: root.startRadius
        property real endRadius: root.endRadius

        topLeftRadius: root.vertical ? root.startRadius : root.startRadius
        topRightRadius: root.vertical ? root.startRadius : root.endRadius
        bottomLeftRadius: root.vertical ? root.endRadius : root.startRadius
        bottomRightRadius: root.vertical ? root.endRadius : root.endRadius

        Rectangle {
            anchors.fill: parent
            color: Styling.srItem("overprimary")
            opacity: root.pinned ? 0 : (root.pressed ? 0.5 : (root.hovered ? 0.25 : 0))
            radius: parent.radius ?? 0

            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 2
                }
            }
        }
    }

    contentItem: Text {
        text: Icons.pin
        font.family: Icons.font
        font.pixelSize: 18
        color: root.pinned ? pinButtonBg.item : (root.pressed ? Colors.background : (Styling.srItem("overprimary") || Colors.foreground))
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        rotation: root.pinned ? 0 : 45
        Behavior on rotation {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration / 2
            }
        }

        Behavior on color {
            enabled: Config.animDuration > 0
            ColorAnimation {
                duration: Config.animDuration / 2
            }
        }
    }

    onClicked: root.bar.pinned = !root.bar.pinned

    StyledToolTip {
        show: root.hovered
        tooltipText: root.pinned ? "Unpin bar" : "Pin bar"
    }
}
