import QtQuick
import QtQuick.Layouts
import qs.modules.services
import qs.modules.components
import qs.modules.theme
import qs.config

Item {
    id: root

    required property var bar

    // Orientación derivada de la barra
    property bool vertical: bar.orientation === "vertical"

    // Estado de hover para activar wavy
    property bool isHovered: false
    property bool externalVolumeChange: false
    property bool isExpanded: false

    property bool layerEnabled: true

    HoverHandler {
        onHoveredChanged: {
            root.isHovered = hovered;
            // Contraer cuando el mouse sale completamente del componente
            if (!hovered && root.isExpanded && !micSlider.isDragging) {
                root.isExpanded = false;
            }
        }
    }

    // Tamaño basado en hover para StyledRect con animación
    Layout.preferredWidth: root.vertical ? 36 : 36
    Layout.preferredHeight: root.vertical ? 36 : 36

    states: [
        State {
            name: "expanded"
            when: root.isExpanded || micSlider.isDragging
            PropertyChanges {
                target: root
                Layout.preferredWidth: root.vertical ? 36 : 150
                Layout.preferredHeight: root.vertical ? 150 : 36
            }
        }
    ]

    transitions: Transition {
        NumberAnimation {
            properties: "Layout.preferredWidth,Layout.preferredHeight"
            duration: Config.animDuration
            easing.type: Easing.OutCubic
        }
    }
    Layout.fillWidth: root.vertical
    Layout.fillHeight: !root.vertical

    Component.onCompleted: micSlider.value = Audio.source?.audio?.volume ?? 0

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
                        micSlider.value = Math.min(1, micSlider.value + 0.1);
                    } else {
                        micSlider.value = Math.max(0, micSlider.value - 0.1);
                    }
                }
            }
        }

        StyledSlider {
            id: micSlider
            anchors.fill: parent
            anchors.margins: 8
            anchors.rightMargin: root.vertical ? 8 : 16
            anchors.topMargin: root.vertical ? 16 : 8
            vertical: root.vertical
            // size: (root.isHovered || micSlider.isDragging) ? 128 : 80
            smoothDrag: true
            value: 0
            resizeParent: false
            wavy: true
            scroll: root.isExpanded
            iconClickable: root.isExpanded
            sliderVisible: root.isExpanded || micSlider.isDragging || root.externalVolumeChange
            wavyAmplitude: (root.isExpanded || micSlider.isDragging || root.externalVolumeChange) ? (Audio.source?.audio?.muted ? 0.5 : 1.5 * value) : 0
            wavyFrequency: (root.isExpanded || micSlider.isDragging || root.externalVolumeChange) ? (Audio.source?.audio?.muted ? 1.0 : 8.0 * value) : 0
            iconPos: root.vertical ? "end" : "start"
            icon: Audio.source?.audio?.muted ? Icons.micSlash : Icons.mic
            progressColor: Audio.source?.audio?.muted ? Colors.outline : Styling.srItem("overprimary")

            onValueChanged: {
                if (Audio.source?.audio) {
                    Audio.source.audio.volume = value;
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
                        micSlider.value = Audio.source.audio.volume;
                        root.externalVolumeChange = true;
                        externalChangeTimer.restart();
                    }
                }
            }

            Connections {
                target: micSlider
                function onIconHovered(hovered) {
                // No hacer nada aquí, el HoverHandler principal maneja todo
                }
            }
        }

        Timer {
            id: externalChangeTimer
            interval: 1000
            onTriggered: root.externalVolumeChange = false
        }
    }
}
