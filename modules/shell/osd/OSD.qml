pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.modules.components
import qs.modules.theme
import qs.modules.services
import qs.modules.globals
import qs.config

PanelWindow {
    id: root

    property ShellScreen targetScreen
    screen: targetScreen

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "ambxst+:osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    WlrLayershell.margins.bottom: 100

    color: "transparent"

    // Keep the PanelWindow alive whenever visible OR while the exit animation
    // is still playing (opacity > 0). Binding only to GlobalStates.osdVisible
    // would hide the window immediately on dismiss, cutting the fade-out dead.
    visible: GlobalStates.osdVisible || osdRect.opacity > 0

    // Internal state for responsiveness
    property real osdValue: 0
    property bool osdMuted: false

    // Centering wrapper
    Item {
        anchors.fill: parent

        StyledRect {
            id: osdRect
            variant: "popup"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            implicitWidth: 240
            implicitHeight: 56
            radius: Styling.radius(16)

            // Slide-in from below when visible, slide out down when hiding
            property real slideY: GlobalStates.osdVisible ? 0 : 16
            transform: Translate { y: osdRect.slideY }

            Behavior on slideY {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration
                    easing.type: Easing.OutQuart
                }
            }

            opacity: GlobalStates.osdVisible ? 1.0 : 0.0
            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration
                    easing.type: Easing.OutQuart
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 16
                anchors.topMargin: 8
                anchors.bottomMargin: 8
                spacing: 12

                Text {
                    id: iconText
                    text: {
                        if (GlobalStates.osdIndicator === "volume") {
                            return Audio.volumeIcon(root.osdValue, root.osdMuted);
                        } else if (GlobalStates.osdIndicator === "mic") {
                            return root.osdMuted ? Icons.micSlash : Icons.mic;
                        } else {
                            return Icons.sun;
                        }
                    }
                    font.family: Icons.font
                    font.pixelSize: Styling.fontSize(6)
                    color: Colors.overBackground
                    Layout.alignment: Qt.AlignVCenter

                    rotation: GlobalStates.osdIndicator === "brightness" ? (root.osdValue * 180) : 0
                    scale: GlobalStates.osdIndicator === "brightness" ? (0.8 + (root.osdValue * 0.2)) : 1

                    Behavior on rotation {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutQuart
                        }
                    }

                    Behavior on scale {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutQuart
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            text: {
                                if (GlobalStates.osdIndicator === "volume")
                                    return "Volume";
                                if (GlobalStates.osdIndicator === "mic")
                                    return "Microphone";
                                if (GlobalStates.osdIndicator === "brightness")
                                    return "Brightness";
                                return "";
                            }
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(0)
                            font.bold: false
                            color: Colors.overBackground
                            Layout.alignment: Qt.AlignBottom
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            // Show percentage value; clamp display to avoid "-0%"
                            text: Math.max(0, Math.round(root.osdValue * 100)) + "%"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(0)
                            font.bold: false
                            color: Colors.overBackground
                            Layout.alignment: Qt.AlignBottom

                            Behavior on text {
                                enabled: false // text changes should be instant
                            }
                        }
                    }

                    StyledSlider {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 12
                        value: root.osdValue
                        wavy: false
                        enabled: false
                        thickness: 3
                        handleSpacing: 0
                        progressColor: root.osdMuted ? Colors.outline : Styling.srItem("overprimary")
                        backgroundColor: Styling.tint(Colors.overBackground, 0.2)
                    }
                }
            }
        }
    }

    // Hovering pauses the auto-hide timer; clicking dismisses immediately.
    // Scoped to the pill (osdRect) so the transparent 100px bottom margin
    // strip doesn't swallow clicks meant for windows beneath the OSD.
    MouseArea {
        anchors.fill: osdRect
        hoverEnabled: true
        onEntered: hideTimer.stop()
        onExited: hideTimer.restart()
        onClicked: GlobalStates.osdVisible = false
    }

    Timer {
        id: hideTimer
        interval: 3000
        onTriggered: GlobalStates.osdVisible = false
    }

    Connections {
        target: GlobalStates
        function onOsdVisibleChanged() {
            if (GlobalStates.osdVisible) {
                hideTimer.restart();
            }
        }
    }

    // Service connections — direct and responsive
    Connections {
        target: Audio
        function onVolumeChanged(volume, muted, node) {
            root.osdValue = Audio.gainToSlider(volume);
            root.osdMuted = muted;
            GlobalStates.osdIndicator = "volume";
            GlobalStates.osdVisible = true;
            hideTimer.restart();
        }
        function onMicVolumeChanged(volume, muted, node) {
            root.osdValue = Audio.gainToSlider(volume);
            root.osdMuted = muted;
            GlobalStates.osdIndicator = "mic";
            GlobalStates.osdVisible = true;
            hideTimer.restart();
        }
    }

    Connections {
        target: Brightness
        function onBrightnessChanged(value, screen) {
            // Only react if the change is for this screen, or synced across all screens
            if (!screen || !root.targetScreen || screen.name === root.targetScreen.name || Brightness.syncBrightness) {
                root.osdValue = value;
                root.osdMuted = false;
                GlobalStates.osdIndicator = "brightness";
                GlobalStates.osdVisible = true;
                hideTimer.restart();
            }
        }
    }
}
