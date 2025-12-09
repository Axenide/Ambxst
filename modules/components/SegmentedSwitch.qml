pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.modules.theme
import qs.config

// A segmented switch with sliding highlight, similar to iOS segmented control
StyledRect {
    id: root
    variant: "common"
    radius: Styling.radius(-4)

    // Model: array of { icon: "...", tooltip: "..." } or just strings for text labels
    property var options: []
    property int currentIndex: 0
    property int buttonSize: 28
    property int spacing: 2
    property int padding: 2

    signal indexChanged(int index)

    implicitWidth: options.length * buttonSize + (options.length - 1) * spacing + padding * 2
    implicitHeight: buttonSize + padding * 2

    Item {
        anchors.fill: parent
        anchors.margins: root.padding

        // Sliding highlight
        StyledRect {
            id: highlight
            variant: "focus"
            z: 0
            radius: Styling.radius(-6)

            width: root.buttonSize
            height: parent.height
            x: root.currentIndex * (root.buttonSize + root.spacing)

            Behavior on x {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 2
                    easing.type: Easing.OutCubic
                }
            }
        }

        // Buttons
        RowLayout {
            anchors.fill: parent
            spacing: root.spacing
            z: 1

            Repeater {
                model: root.options

                Button {
                    id: optionButton
                    required property var modelData
                    required property int index

                    Layout.fillHeight: true
                    Layout.preferredWidth: root.buttonSize

                    focusPolicy: Qt.NoFocus
                    hoverEnabled: true
                    flat: true

                    background: Rectangle {
                        color: "transparent"
                    }

                    contentItem: Text {
                        text: typeof optionButton.modelData === "object" ? (optionButton.modelData.icon || "") : optionButton.modelData
                        color: root.currentIndex === optionButton.index 
                            ? Config.resolveColor(Config.theme.srOverPrimary.itemColor)
                            : Colors.overBackground
                        font.family: typeof optionButton.modelData === "object" && optionButton.modelData.icon ? Icons.font : Config.theme.font
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter

                        Behavior on color {
                            enabled: Config.animDuration > 0
                            ColorAnimation {
                                duration: Config.animDuration / 2
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    onClicked: {
                        root.currentIndex = optionButton.index;
                        root.indexChanged(optionButton.index);
                    }

                    StyledToolTip {
                        visible: optionButton.hovered && typeof optionButton.modelData === "object" && optionButton.modelData.tooltip
                        tooltipText: typeof optionButton.modelData === "object" ? (optionButton.modelData.tooltip || "") : ""
                    }
                }
            }
        }
    }
}
