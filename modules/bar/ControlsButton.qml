pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.services
import qs.modules.components
import qs.modules.theme
import qs.config

Item {
    id: root

    required property var bar

    property bool vertical: bar.orientation === "vertical"
    property bool isHovered: false
    property bool layerEnabled: true

    property real radius: 0
    property real startRadius: radius
    property real endRadius: radius

    // Popup visibility state (tracks intent, not animation)
    property bool popupOpen: controlsPopup.isOpen

    Layout.preferredWidth: 36
    Layout.preferredHeight: 36
    Layout.fillWidth: vertical
    Layout.fillHeight: !vertical

    StyledToolTip {
        show: root.isHovered && !root.popupOpen
        tooltipText: "Audio & Brightness Controls"
    }

    HoverHandler {
        onHoveredChanged: root.isHovered = hovered
    }

    // Main button
    StyledRect {
        id: buttonBg
        variant: root.popupOpen ? "primary" : "bg"
        anchors.fill: parent
        enableShadow: root.layerEnabled

        topLeftRadius: root.vertical ? root.startRadius : root.startRadius
        topRightRadius: root.vertical ? root.startRadius : root.endRadius
        bottomLeftRadius: root.vertical ? root.endRadius : root.startRadius
        bottomRightRadius: root.vertical ? root.endRadius : root.endRadius

        Rectangle {
            anchors.fill: parent
            color: Styling.srItem("overprimary")
            opacity: root.popupOpen ? 0 : (root.isHovered ? 0.25 : 0)
            radius: parent.radius ?? 0

            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 2
                }
            }
        }

        Text {
            anchors.centerIn: parent
            text: Icons.faders
            font.family: Icons.font
            font.pixelSize: 18
            color: root.popupOpen ? buttonBg.item : Styling.srItem("overprimary")
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: false
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    Quickshell.execDetached(["pavucontrol"]);
                    return;
                } else if (mouse.button === Qt.LeftButton) {
                    controlsPopup.toggle();
                }
            }
            onWheel: wheel => {
                if (wheel.angleDelta.y > 0)
                    Audio.incrementVolume();
                else if (wheel.angleDelta.y < 0)
                    Audio.decrementVolume();
            }
        }
    }

    // Controls popup
    BarPopup {
        id: controlsPopup
        anchorItem: buttonBg
        bar: root.bar
        popupPadding: 16

        contentWidth: 220
        // Fixed height calculation to prevent expansion animation on first open
        // 3 rows * 36px + 2 gaps * 12px = 132px
        contentHeight: 132 + popupPadding * 2

        ColumnLayout {
            id: slidersColumn
            anchors.fill: parent
            spacing: 12

            // Volume Slider
            ControlSliderRow {
                id: volumeRow
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                Layout.rightMargin: 8

                icon: {
                    if (Audio.sink?.audio?.muted)
                        return Icons.speakerSlash;
                    const vol = Audio.sink?.audio?.volume ?? 0;
                    if (vol < 0.01)
                        return Icons.speakerX;
                    if (vol < 0.19)
                        return Icons.speakerNone;
                    if (vol < 0.49)
                        return Icons.speakerLow;
                    return Icons.speakerHigh;
                }
                sliderValue: Audio.sink?.audio?.volume ?? 0
                progressColor: Audio.sink?.audio?.muted ? Colors.outline : Styling.srItem("overprimary")
                wavy: true
                wavyAmplitude: Audio.sink?.audio?.muted ? 0.5 : 1.5 * sliderValue
                wavyFrequency: Audio.sink?.audio?.muted ? 1.0 : 8.0 * sliderValue

                onValueChanged: newValue => {
                    if (Audio.sink?.audio) {
                        Audio.sink.audio.volume = newValue;
                    }
                }

                onIconClicked: {
                    if (Audio.sink?.audio) {
                        Audio.sink.audio.muted = !Audio.sink.audio.muted;
                    }
                }

                Connections {
                    target: Audio.sink?.audio ?? null
                    ignoreUnknownSignals: true
                    function onVolumeChanged() {
                        if (Audio.sink?.audio) {
                            volumeRow.sliderValue = Audio.sink.audio.volume;
                        }
                    }
                }
            }

            // Microphone Slider
            ControlSliderRow {
                id: micRow
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                Layout.rightMargin: 8

                icon: Audio.source?.audio?.muted ? Icons.micSlash : Icons.mic
                sliderValue: Audio.source?.audio?.volume ?? 0
                progressColor: Audio.source?.audio?.muted ? Colors.outline : Styling.srItem("overprimary")
                wavy: true
                wavyAmplitude: Audio.source?.audio?.muted ? 0.5 : 1.5 * sliderValue
                wavyFrequency: Audio.source?.audio?.muted ? 1.0 : 8.0 * sliderValue

                onValueChanged: newValue => {
                    if (Audio.source?.audio) {
                        Audio.source.audio.volume = newValue;
                    }
                }

                onIconClicked: {
                    if (Audio.source?.audio) {
                        Audio.source.audio.muted = !Audio.source.audio.muted;
                    }
                }

                Connections {
                    target: Audio.source?.audio ?? null
                    ignoreUnknownSignals: true
                    function onVolumeChanged() {
                        if (Audio.source?.audio) {
                            micRow.sliderValue = Audio.source.audio.volume;
                        }
                    }
                }
            }

            // Brightness Slider
            ControlSliderRow {
                id: brightnessRow
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                Layout.rightMargin: 8

                property var currentMonitor: Brightness.getMonitorForScreen(root.bar.screen)

                icon: Icons.sun
                sliderValue: currentMonitor?.brightness ?? 0.5
                progressColor: Styling.srItem("overprimary")
                wavy: true
                wavyAmplitude: 1.5 * sliderValue
                wavyFrequency: 8.0 * sliderValue
                iconRotation: (sliderValue / 1.0) * 180
                iconScale: 0.8 + (sliderValue / 1.0) * 0.2

                onValueChanged: newValue => {
                    if (Brightness.syncBrightness) {
                        for (let i = 0; i < Brightness.monitors.length; i++) {
                            let mon = Brightness.monitors[i];
                            if (mon && mon.ready) {
                                mon.setBrightness(newValue);
                            }
                        }
                    } else if (currentMonitor && currentMonitor.ready) {
                        currentMonitor.setBrightness(newValue);
                    }
                }

                onIconClicked: {}

                Connections {
                    target: brightnessRow.currentMonitor ?? null
                    ignoreUnknownSignals: true
                    function onBrightnessChanged() {
                        if (brightnessRow.currentMonitor) {
                            brightnessRow.sliderValue = brightnessRow.currentMonitor.brightness;
                        }
                    }
                    function onReadyChanged() {
                        if (brightnessRow.currentMonitor?.ready) {
                            brightnessRow.sliderValue = brightnessRow.currentMonitor.brightness;
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        // Initialize values
        if (Audio.sink?.audio)
            volumeRow.sliderValue = Audio.sink.audio.volume;
        if (Audio.source?.audio)
            micRow.sliderValue = Audio.source.audio.volume;
        if (brightnessRow.currentMonitor?.ready)
            brightnessRow.sliderValue = brightnessRow.currentMonitor.brightness;
    }
}
