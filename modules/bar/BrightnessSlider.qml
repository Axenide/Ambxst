import QtQuick
import QtQuick.Layouts
import qs.modules.services
import qs.modules.components
import qs.modules.theme
import qs.config

Item {
    id: root

    required property var bar

    property bool vertical: bar.orientation === "vertical"
    property bool isHovered: false
    property bool externalBrightnessChange: false
    property bool isExpanded: false

    property real iconRotation: (brightnessSlider.value / 1.0) * 180
    property real iconScale: 0.8 + (brightnessSlider.value / 1.0) * 0.2

    property bool layerEnabled: true

    function updateSliderFromMonitor(forceAnimation: bool): void {
        if (!currentMonitor || !currentMonitor.ready || brightnessSlider.isDragging)
            return;
        brightnessSlider.value = currentMonitor.brightness;
        if (forceAnimation) {
            root.externalBrightnessChange = true;
            externalChangeTimer.restart();
        }
    }

    Behavior on iconRotation {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: 400
            easing.type: Easing.OutCubic
        }
    }
    Behavior on iconScale {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: 400
            easing.type: Easing.OutCubic
        }
    }

    HoverHandler {
        onHoveredChanged: {
            root.isHovered = hovered;
            // Contraer cuando el mouse sale completamente del componente
            if (!hovered && root.isExpanded && !brightnessSlider.isDragging) {
                root.isExpanded = false;
            }
        }
    }

    Layout.preferredWidth: root.vertical ? 36 : 36
    Layout.preferredHeight: root.vertical ? 36 : 36

    states: [
        State {
            name: "expanded"
            when: root.isExpanded || brightnessSlider.isDragging || root.externalBrightnessChange
            PropertyChanges {
                target: root
                Layout.preferredWidth: root.vertical ? 36 : 150
                Layout.preferredHeight: root.vertical ? 150 : 36
            }
        }
    ]

    transitions: Transition {
        NumberAnimation {
            properties: "implicitWidth,implicitHeight,Layout.preferredWidth,Layout.preferredHeight"
            duration: 200
            easing.type: Easing.OutCubic
        }
    }

    Layout.fillWidth: root.vertical
    Layout.fillHeight: !root.vertical

    property var currentMonitor: Brightness.getMonitorForScreen(bar.screen)

    Component.onCompleted: updateSliderFromMonitor(false)

    onCurrentMonitorChanged: updateSliderFromMonitor(false)

    StyledRect {
        variant: "bg"
        anchors.fill: parent
        enableShadow: root.layerEnabled

        Rectangle {
            anchors.fill: parent
            color: Styling.srItem("overprimary")
            opacity: root.isHovered && !root.isExpanded ? 0.25 : 0
            radius: parent.radius ?? 0

            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 2
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: false
            onClicked: {
                root.isExpanded = !root.isExpanded;
            }
            onWheel: wheel => {
                if (root.isExpanded) {
                    if (wheel.angleDelta.y > 0) {
                        brightnessSlider.value = Math.min(1, brightnessSlider.value + 0.1);
                    } else {
                        brightnessSlider.value = Math.max(0, brightnessSlider.value - 0.1);
                    }
                }
            }
        }

        StyledSlider {
            id: brightnessSlider
            anchors.fill: parent
            anchors.margins: 8
            anchors.rightMargin: root.vertical ? 8 : 16
            anchors.topMargin: root.vertical ? 16 : 8
            vertical: root.vertical
            smoothDrag: true
            value: 0
            resizeParent: false
            wavy: true
            scroll: root.isExpanded
            iconClickable: root.isExpanded
            sliderVisible: root.isExpanded || isDragging || root.externalBrightnessChange
            wavyAmplitude: (root.isExpanded || isDragging || root.externalBrightnessChange) ? (1.5 * value) : 0
            wavyFrequency: (root.isExpanded || isDragging || root.externalBrightnessChange) ? (8.0 * value) : 0
            iconPos: root.vertical ? "end" : "start"
            icon: Icons.sun
            iconRotation: root.iconRotation
            iconScale: root.iconScale
            progressColor: Styling.srItem("overprimary")

            onValueChanged: {
                if (currentMonitor && currentMonitor.ready) {
                    currentMonitor.setBrightness(value);
                }
            }

            onIconClicked: {}

            Connections {
                target: currentMonitor
                ignoreUnknownSignals: true
                function onBrightnessChanged() {
                    root.updateSliderFromMonitor(true);
                }
                function onReadyChanged() {
                    root.updateSliderFromMonitor(false);
                }
            }

            Connections {
                target: brightnessSlider
                function onIconHovered(hovered) {
                // No hacer nada aquí, el HoverHandler principal maneja todo
                }
            }
        }

        Timer {
            id: externalChangeTimer
            interval: 1000
            onTriggered: root.externalBrightnessChange = false
        }
    }
}
