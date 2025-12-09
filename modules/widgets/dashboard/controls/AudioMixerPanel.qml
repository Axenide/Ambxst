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

    property bool showOutput: true  // true = output, false = input

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        // Titlebar
        PanelTitlebar {
            title: "Sound"
            
            actions: [
                {
                    icon: Audio.protectionEnabled ? Icons.shieldCheck : Icons.shield,
                    tooltip: Audio.protectionEnabled ? "Volume protection enabled" : "Volume protection disabled",
                    onClicked: function() { Audio.setProtectionEnabled(!Audio.protectionEnabled); }
                },
                {
                    icon: Icons.externalLink,
                    tooltip: "Open PipeWire Volume Control",
                    onClicked: function() { Quickshell.execDetached(["pwvucontrol"]); }
                }
            ]

            // Output/Input segmented switch
            SegmentedSwitch {
                currentIndex: root.showOutput ? 0 : 1
                options: [
                    { icon: Icons.speakerHigh, tooltip: "Output" },
                    { icon: Icons.mic, tooltip: "Input" }
                ]
                onIndexChanged: index => {
                    root.showOutput = (index === 0);
                }
            }
        }

        // Scrollable content
        Flickable {
            id: flickable
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: contentColumn.implicitHeight
            clip: true

            ColumnLayout {
                id: contentColumn
                width: flickable.width
                spacing: 8

                // Section: Devices
                Text {
                    text: root.showOutput ? "Output Device" : "Input Device"
                    font.family: Config.theme.font
                    font.pixelSize: Config.theme.fontSize - 1
                    font.weight: Font.Medium
                    color: Colors.overSurfaceVariant
                }

                // Device list
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
                    font.pixelSize: Config.theme.fontSize - 1
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
                    font.pixelSize: Config.theme.fontSize - 1
                    color: Colors.outline
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 16
                }
            }
        }
    }
}
