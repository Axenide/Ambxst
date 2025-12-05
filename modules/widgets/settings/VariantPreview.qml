pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.config

Item {
    id: root

    required property string variantId
    required property string variantLabel
    property bool isSelected: false

    signal clicked

    width: 72
    height: 88

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        // Preview box - uses StyledRect with the variant
        // Now shows real-time changes since we modify Config directly
        StyledRect {
            id: previewRect
            Layout.preferredWidth: 64
            Layout.preferredHeight: 64
            Layout.alignment: Qt.AlignHCenter
            variant: root.variantId
            enableBorder: true

            // Selection indicator
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.color: Colors.primary
                border.width: root.isSelected ? 2 : 0
                radius: previewRect.radius

                Behavior on border.width {
                    enabled: (Config.animDuration ?? 0) > 0
                    NumberAnimation {
                        duration: (Config.animDuration ?? 0) / 2
                    }
                }
            }

            // Cube icon
            Text {
                anchors.centerIn: parent
                text: Icons.cube
                font.family: Icons.font
                font.pixelSize: 24
                color: previewRect.itemColor
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true

                onClicked: root.clicked()

                onEntered: hoverOverlay.opacity = 0.1
                onExited: hoverOverlay.opacity = 0
            }

            Rectangle {
                id: hoverOverlay
                anchors.fill: parent
                color: Colors.primary
                radius: previewRect.radius
                opacity: 0

                Behavior on opacity {
                    enabled: (Config.animDuration ?? 0) > 0
                    NumberAnimation {
                        duration: (Config.animDuration ?? 0) / 2
                    }
                }
            }
        }

        // Label
        Text {
            text: root.variantLabel
            font.family: Styling.defaultFont
            font.pixelSize: Styling.fontSize(0)
            color: root.isSelected ? Colors.primary : Colors.overBackground
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter

            Behavior on color {
                enabled: (Config.animDuration ?? 0) > 0
                ColorAnimation {
                    duration: (Config.animDuration ?? 0) / 2
                }
            }
        }
    }
}
