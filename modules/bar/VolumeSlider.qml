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
            if (!hovered && root.isExpanded && !volumeSlider.isDragging) {
                root.isExpanded = false;
            }
        }
    }

    // Tamaño basado en hover para StyledRect con animación
    // implicitWidth: root.vertical ? 4 : 36
    // implicitHeight: root.vertical ? 36 : 4
    Layout.preferredWidth: root.vertical ? 36 : 36
    Layout.preferredHeight: root.vertical ? 36 : 36

    states: [
        State {
            name: "expanded"
            when: root.isExpanded || volumeSlider.isDragging || root.externalVolumeChange
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
            duration: Config.animDuration
            easing.type: Easing.OutCubic
        }
    }
    Layout.fillWidth: root.vertical
    Layout.fillHeight: !root.vertical

    Component.onCompleted: volumeSlider.value = Audio.sink?.audio?.volume ?? 0

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
                        volumeSlider.value = Math.min(1, volumeSlider.value + 0.1);
                    } else {
                        volumeSlider.value = Math.max(0, volumeSlider.value - 0.1);
                    }
                }
            }
        }

        StyledSlider {
            id: volumeSlider
            anchors.fill: parent
            anchors.margins: 8
            anchors.rightMargin: root.vertical ? 8 : 16
            anchors.topMargin: root.vertical ? 16 : 8
            vertical: root.vertical
            // size: (root.isHovered || volumeSlider.isDragging) ? 128 : 80ered || volumeSlider.isDragging) ? 128 : 80
            smoothDrag: true
            value: 0
            resizeParent: false
            wavy: true
            scroll: root.isExpanded
            iconClickable: root.isExpanded
            sliderVisible: root.isExpanded || volumeSlider.isDragging || root.externalVolumeChange
            wavyAmplitude: (root.isExpanded || volumeSlider.isDragging || root.externalVolumeChange) ? (Audio.sink?.audio?.muted ? 0.5 : 1.5 * value) : 0
            wavyFrequency: (root.isExpanded || volumeSlider.isDragging || root.externalVolumeChange) ? (Audio.sink?.audio?.muted ? 1.0 : 8.0 * value) : 0
            iconPos: root.vertical ? "end" : "start"
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
            progressColor: Audio.sink?.audio?.muted ? Colors.outline : Styling.srItem("overprimary")

            onValueChanged: {
                if (Audio.sink?.audio) {
                    Audio.sink.audio.volume = value;
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
                        volumeSlider.value = Audio.sink.audio.volume;
                        root.externalVolumeChange = true;
                        externalChangeTimer.restart();
                    }
                }
            }

            Connections {
                target: volumeSlider
                function onIconHovered(hovered) {
                // No hacer nada aquí, el HoverHandler principal maneja todo
                }
            }

            Timer {
                id: externalChangeTimer
                interval: 1000
                onTriggered: root.externalVolumeChange = false
            }
        }
    }
}
