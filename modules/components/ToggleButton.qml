import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import qs.modules.services
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
    // Radius handling
    property real radius: 0
    property bool vertical: false // Set by parent if needed, or inferred? ToggleButton doesn't know orientation usually.
    // We will let parent set start/end radius directly or use radius as fallback
    property real startRadius: radius
    property real endRadius: radius

    implicitWidth: 36
    implicitHeight: 36

    // Check if buttonIcon is a single character (icon font) or a file path
    readonly property bool isIconPath: buttonIcon.length > 1

    background: StyledRect {
        id: bg
        variant: "bg"
        enableShadow: root.enableShadow && Config.showBackground

        // Map start/end to corners based on vertical property
        topLeftRadius: root.vertical ? root.startRadius : root.startRadius
        topRightRadius: root.vertical ? root.startRadius : root.endRadius
        bottomLeftRadius: root.vertical ? root.endRadius : root.startRadius
        bottomRightRadius: root.vertical ? root.endRadius : root.endRadius

        Rectangle {
            anchors.fill: parent
            color: parent.item || "transparent"
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
            color: root.pressed ? Colors.background : (Styling.srItem("overprimary") || Colors.foreground)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        // Image icon (SVG/PNG)
        Item {
            id: iconImageContainer
            visible: root.isIconPath
            anchors.centerIn: parent
            width: root.iconSize
            height: root.iconSize

            Image {
                id: iconImage
                anchors.fill: parent
                source: root.isIconPath ? root.buttonIcon : ""
                sourceSize: Qt.size(width * 2, height * 2)
                fillMode: Image.PreserveAspectFit
                smooth: true
                asynchronous: true
            }

            Tinted {
                anchors.fill: parent
                sourceItem: iconImage
                active: root.iconTint || root.iconFullTint
                fullTint: root.iconFullTint
            }
        }
    }

    onClicked: root.onToggle()

    ToolTip.visible: false
    ToolTip.text: root.tooltipText
    ToolTip.delay: 1000
}
