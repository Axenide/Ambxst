pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.config
import qs.modules.theme
import qs.modules.components

// Icon toggle button shared by the bar and dock: a pin/unpin or overview
// toggle with a themed background. `barStyle` renders the corner-radius
// continuous background (with hover/press overlay) used by the bar; the dock
// style shows a focus background only while active or hovered.
Button {
    id: root

    property bool active: false
    property string glyph: ""
    property string tooltipText: ""
    property real buttonSize: 32
    property real iconPixelSize: 16
    property bool barStyle: false
    property bool enableShadow: true
    property real idleRotation: 0  // applied while !active
    property real tlRadius: -1  // -1 = fall back to radius
    property real trRadius: -1
    property real blRadius: -1
    property real brRadius: -1

    implicitWidth: root.buttonSize
    implicitHeight: root.buttonSize

    background: StyledRect {
        id: bgRect
        visible: root.barStyle || root.active || root.hovered
        variant: root.active ? "primary" : (root.barStyle ? "bg" : "focus")
        enableShadow: root.barStyle && root.enableShadow
        enableBorder: !root.barStyle
        radius: {
            if (!root.barStyle)
                return Styling.radius(-2);
            const cfg = Styling.getStyledRectConfig("bg");
            return cfg && cfg.radius !== undefined ? cfg.radius : Styling.radius(0);
        }
        topLeftRadius: root.tlRadius
        topRightRadius: root.trRadius
        bottomLeftRadius: root.blRadius
        bottomRightRadius: root.brRadius

        Rectangle {
            anchors.fill: parent
            visible: root.barStyle
            color: Styling.srItem("overprimary")
            opacity: root.active ? 0 : (root.pressed ? 0.5 : (root.hovered ? 0.25 : 0))
            radius: bgRect.radius

            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 2
                }
            }
        }
    }

    contentItem: Text {
        text: root.glyph
        font.family: Icons.font
        font.pixelSize: root.iconPixelSize
        color: root.barStyle ? (root.active ? bgRect.item : (root.pressed ? Colors.background : (Styling.srItem("overprimary") || Colors.foreground))) : (root.active ? Styling.srItem("primary") : Colors.overBackground)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        rotation: root.active ? 0 : root.idleRotation
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

    StyledToolTip {
        show: root.hovered
        tooltipText: root.tooltipText
    }
}
