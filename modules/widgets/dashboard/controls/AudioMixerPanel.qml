pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

Item {
    id: root

    property int maxContentWidth: 480
    readonly property int contentWidth: Math.min(width, maxContentWidth)
    readonly property real sideMargin: (width - contentWidth) / 2

    property bool showOutput: true  // true = output, false = input

    // Scrollable content - fills entire width for scroll/drag
    Flickable {
        id: flickable
        anchors.fill: parent
        contentHeight: contentColumn.implicitHeight
        clip: true

        ColumnLayout {
            id: contentColumn
            width: flickable.width
            spacing: 8

            // Header wrapper
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: titlebar.height

                PanelTitlebar {
                    id: titlebar
                    width: root.contentWidth
                    anchors.horizontalCenter: parent.horizontalCenter
                    title: "Sound"

                    actions: [
                        {
                            icon: Audio.protectionEnabled ? Icons.shieldCheck : Icons.shield,
                            tooltip: Audio.protectionEnabled ? "Volume protection enabled" : "Volume protection disabled",
                            onClicked: function () {
                                Audio.setProtectionEnabled(!Audio.protectionEnabled);
                            }
                        },
                        {
                            icon: Icons.popOpen,
                            tooltip: "Open PipeWire Volume Control",
                            onClicked: function () {
                                Quickshell.execDetached(["pavucontrol"]);
                            }
                        }
                    ]

                    // Output/Input toggle buttons
                    RowLayout {
                        spacing: 4

                        // Output Button
                        StyledRect {
                            id: outputBtn
                            property bool isSelected: root.showOutput
                            property bool isHovered: false

                            variant: isSelected ? "primary" : (isHovered ? "focus" : "common")
                            Layout.preferredHeight: 32
                            Layout.preferredWidth: outputContent.width + 24
                            radius: isSelected ? Styling.radius(-4) : Styling.radius(0)

                            Row {
                                id: outputContent
                                anchors.centerIn: parent
                                spacing: 8

                                Text {
                                    text: Icons.speakerHigh
                                    font.family: Icons.font
                                    font.pixelSize: 14
                                    color: outputBtn.item
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: "Output"
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-1)
                                    font.weight: Font.Medium
                                    color: outputBtn.item
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: outputBtn.isHovered = true
                                onExited: outputBtn.isHovered = false
                                onClicked: root.showOutput = true
                            }
                        }

                        // Input Button
                        StyledRect {
                            id: inputBtn
                            property bool isSelected: !root.showOutput
                            property bool isHovered: false

                            variant: isSelected ? "primary" : (isHovered ? "focus" : "common")
                            Layout.preferredHeight: 32
                            Layout.preferredWidth: inputContent.width + 24
                            radius: isSelected ? Styling.radius(-4) : Styling.radius(0)

                            Row {
                                id: inputContent
                                anchors.centerIn: parent
                                spacing: 8

                                Text {
                                    text: Icons.mic
                                    font.family: Icons.font
                                    font.pixelSize: 14
                                    color: inputBtn.item
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: "Input"
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-1)
                                    font.weight: Font.Medium
                                    color: inputBtn.item
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: inputBtn.isHovered = true
                                onExited: inputBtn.isHovered = false
                                onClicked: root.showOutput = false
                            }
                        }
                    }
                }
            }

            // Content wrapper - centered
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: innerContent.implicitHeight

                ColumnLayout {
                    id: innerContent
                    width: root.contentWidth
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8

                    // Section: Devices
                    Text {
                        text: root.showOutput ? "Output Device" : "Input Device"
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        font.weight: Font.Medium
                        color: Colors.overSurfaceVariant
                    }

                    // Device list
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Repeater {
                            model: root.showOutput ? Audio.outputDevices : Audio.inputDevices

                            delegate: AudioDeviceItem {
                                required property var modelData
                                Layout.fillWidth: true
                                node: modelData
                                isOutput: root.showOutput
                                isSelected: (root.showOutput ? Audio.sink : Audio.source) === modelData
                            }
                        }
                    }

                    // Separator
                    Separator {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 2
                        Layout.topMargin: 8
                        Layout.bottomMargin: 8
                    }

                    // Section: Volume Mixer
                    Text {
                        text: "Volume Mixer"
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        font.weight: Font.Medium
                        color: Colors.overSurfaceVariant
                    }

                    // Main volume control
                    AudioVolumeEntry {
                        Layout.fillWidth: true
                        node: root.showOutput ? Audio.sink : Audio.source
                        icon: root.showOutput ? Icons.speakerHigh : Icons.mic
                        isMainDevice: true
                    }

                    // App volume controls
                    Repeater {
                        model: root.showOutput ? Audio.outputAppNodes : Audio.inputAppNodes

                        delegate: AudioVolumeEntry {
                            required property var modelData
                            Layout.fillWidth: true
                            node: modelData
                            isMainDevice: false
                        }
                    }

                    // Empty state for apps
                    Text {
                        visible: (root.showOutput ? Audio.outputAppNodes : Audio.inputAppNodes).length === 0
                        text: "No applications using audio"
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        color: Colors.outline
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 16
                    }
                }
            }
        }
    }
}
