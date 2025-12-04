import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import qs.modules.theme
import qs.modules.globals
import qs.config

Button {
    id: root

    required property string buttonIcon
    required property string tooltipText
    required property var onToggle
    property bool iconTint: false
    property bool iconFullTint: false
    property int iconSize: 18
    property bool enableShadow: true

    implicitWidth: 36
    implicitHeight: 36

    // Check if buttonIcon is a single character (icon font) or a file path
    readonly property bool isIconPath: buttonIcon.length > 1

    background: StyledRect {
        variant: "bg"
        enableShadow: root.enableShadow && Config.bar.showBackground
        Rectangle {
            anchors.fill: parent
            color: Colors.primary
            opacity: root.pressed ? 0.5 : (root.hovered ? 0.25 : 0)
            radius: parent.radius ?? 0

            Behavior on opacity {
                enabled: (Config.animDuration ?? 0) > 0
                NumberAnimation {
                    duration: (Config.animDuration ?? 0) / 2
                }
            }
        }
    }

    contentItem: Item {
        // Text icon (single character)
        Text {
            visible: !root.isIconPath
            anchors.fill: parent
            text: root.buttonIcon
            textFormat: Text.RichText
            font.family: Icons.font
            font.pixelSize: 18
            color: root.pressed ? Colors.background : Colors.primary
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        // Image icon (SVG/PNG)
        Image {
            id: iconImage
            visible: root.isIconPath
            anchors.centerIn: parent
            width: root.iconSize
            height: root.iconSize
            source: root.isIconPath ? root.buttonIcon : ""
            sourceSize: Qt.size(width * 2, height * 2)
            fillMode: Image.PreserveAspectFit
            smooth: true
            asynchronous: true
            layer.enabled: root.iconTint || root.iconFullTint
            layer.effect: MultiEffect {
                brightness: root.iconFullTint ? 1.0 : 0.1
                contrast: root.iconFullTint ? 0.0 : -0.25
                colorization: root.iconFullTint ? 1.0 : 0.25
                colorizationColor: Colors.primary
            }
        }
    }

    onClicked: root.onToggle()

    ToolTip.visible: false
    ToolTip.text: root.tooltipText
    ToolTip.delay: 1000
}
