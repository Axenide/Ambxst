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

    implicitWidth: buttonsRow.implicitWidth + padding * 2
    implicitHeight: Math.max(buttonSize, buttonsRow.implicitHeight) + padding * 2

    Item {
        anchors.fill: parent
        anchors.margins: root.padding

        // Sliding highlight
        StyledRect {
            id: highlight
            variant: "focus"
            z: 0
            radius: Styling.radius(-6)

            property Item activeItem: repeater.itemAt(root.currentIndex)
            width: activeItem ? activeItem.width : root.buttonSize
            height: parent.height
            x: activeItem ? activeItem.x : 0

            Behavior on x {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 2
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on width {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 2
                    easing.type: Easing.OutCubic
                }
            }
        }

        // Buttons
        RowLayout {
            id: buttonsRow
            anchors.fill: parent
            spacing: root.spacing
            z: 1

            Repeater {
                id: repeater
                model: root.options

                Button {
                    id: optionButton
                    required property var modelData
                    required property int index

                    Layout.fillHeight: true
                    Layout.minimumWidth: root.buttonSize
                    Layout.preferredWidth: contentRow.implicitWidth + 16 // Add some padding

                    focusPolicy: Qt.NoFocus
                    hoverEnabled: true
                    flat: true

                    background: Rectangle {
                        color: "transparent"
                    }

                    contentItem: RowLayout {
                        id: contentRow
                        anchors.centerIn: parent
                        spacing: 8

                        // Image Icon
                        Image {
                            mipmap: true
                            visible: typeof optionButton.modelData === "object" && !!optionButton.modelData.image
                            source: visible ? optionButton.modelData.image : ""
                            sourceSize.width: 16
                            sourceSize.height: 16
                            width: 16
                            height: 16
                            fillMode: Image.PreserveAspectFit
                            opacity: root.currentIndex === optionButton.index ? 1.0 : 0.7
                        }

                        // Font Icon
                        Text {
                            visible: typeof optionButton.modelData === "object" && !!optionButton.modelData.icon && !optionButton.modelData.image
                            text: visible ? optionButton.modelData.icon : ""
                            color: root.currentIndex === optionButton.index ? Styling.srItem("overprimary") : Colors.overBackground
                            font.family: Icons.font
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

                        // Label
                        Text {
                            visible: typeof optionButton.modelData !== "object" || !!optionButton.modelData.label
                            text: typeof optionButton.modelData === "object" ? (optionButton.modelData.label || "") : optionButton.modelData
                            color: root.currentIndex === optionButton.index ? Styling.srItem("overprimary") : Colors.overBackground
                            font.family: Config.theme.font
                            font.pixelSize: 14
                            font.weight: root.currentIndex === optionButton.index ? Font.DemiBold : Font.Normal
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
                    }

                    onClicked: {
                        root.currentIndex = optionButton.index;
                        root.indexChanged(optionButton.index);
                    }

                    StyledToolTip {
                        visible: optionButton.hovered && typeof optionButton.modelData === "object" && !!optionButton.modelData.tooltip
                        tooltipText: typeof optionButton.modelData === "object" ? (optionButton.modelData.tooltip || "") : ""
                    }
                }
            }
        }
    }
}
