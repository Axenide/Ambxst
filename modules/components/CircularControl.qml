import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.config

StyledRect {
    id: root
    variant: "pane"
    backgroundOpacity: showBackground ? -1 : 0
    enableBorder: showBackground

    property bool showBackground: true

    required property string icon
    required property real value
    required property color accentColor
    required property bool isToggleable
    required property bool isToggled

    signal controlValueChanged(real newValue)
    signal toggled
    signal draggingChanged(bool isDragging)

    property real iconRotation: 0
    property bool enableIconRotation: false
    property real iconScale: 1.0
    property real handleSpacing: 6
    property real handleSize: 8
    property real lineWidth: 4
    property real gapAngle: 45

    radius: Styling.radius(4)
    width: 48
    height: 48

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        preventStealing: true

        property real dragStartY: 0
        property real dragStartValue: 0
        property bool isDragging: false
        property bool wasDragging: false

        onClicked: {
            // Only trigger toggle if we didn't drag
            if (root.isToggleable && !wasDragging) {
                root.toggled();
            }
        }

        onPressed: mouse => {
            dragStartY = mouse.y;
            dragStartValue = root.value;
            isDragging = false;
            wasDragging = false;
        }

        onPositionChanged: mouse => {
            if (!pressed)
                return;

            let deltaY = dragStartY - mouse.y;
            if (Math.abs(deltaY) > 3) {
                if (!isDragging) {
                    isDragging = true;
                    wasDragging = true;
                    root.draggingChanged(true);
                }
                let deltaValue = deltaY / 100.0;
                let newValue = Math.round(Math.max(0, Math.min(1, dragStartValue + deltaValue)) * 100) / 100;
                root.controlValueChanged(newValue);
            }
        }

        onReleased: {
            if (isDragging) {
                root.draggingChanged(false);
            }
            isDragging = false;
        }

        onWheel: wheel => {
            if (wheel.angleDelta.y > 0) {
                let newValue = Math.round(Math.min(1, root.value + 0.1) * 100) / 100;
                root.controlValueChanged(newValue);
            } else {
                let newValue = Math.round(Math.max(0, root.value - 0.1) * 100) / 100;
                root.controlValueChanged(newValue);
            }
        }
    }

    Item {
        id: progressCanvas
        anchors.centerIn: parent
        width: 48
        height: 48

        property real angle: root.value * (360 - 2 * root.gapAngle)
        property real radius: 16

        Canvas {
            id: canvas
            anchors.fill: parent
            antialiasing: true

            onPaint: {
                let ctx = getContext("2d");
                ctx.reset();

                let centerX = width / 2;
                let centerY = height / 2;
                let radius = progressCanvas.radius;
                let lineWidth = root.lineWidth;

                ctx.lineCap = "round";

                let baseStartAngle = (Math.PI / 2) + (root.gapAngle * Math.PI / 180);
                let progressAngleRad = progressCanvas.angle * Math.PI / 180;
                let handleGapRad = root.handleSpacing * (360 / (2 * Math.PI * radius)) * Math.PI / 180;
                let handleSizeRad = root.handleSize * (360 / (2 * Math.PI * radius)) * Math.PI / 180;

                // Dibujar progreso (desde inicio hasta valor actual - gap)
                let progressEndAngle = baseStartAngle + progressAngleRad - handleGapRad;
                if (progressCanvas.angle > 1 && progressEndAngle > (baseStartAngle + 0.01)) {
                    ctx.strokeStyle = root.accentColor;
                    ctx.lineWidth = lineWidth;
                    ctx.beginPath();
                    ctx.arc(centerX, centerY, radius, baseStartAngle, progressEndAngle, false);
                    ctx.stroke();
                }

                // Dibujar handle (línea radial sobresaliente en la posición actual)
                if (progressCanvas.angle >= 0) {
                    let handleAngle = baseStartAngle + progressAngleRad;
                    let innerRadius = radius - 2;
                    let outerRadius = radius + 4;

                    let innerX = centerX + innerRadius * Math.cos(handleAngle);
                    let innerY = centerY + innerRadius * Math.sin(handleAngle);
                    let outerX = centerX + outerRadius * Math.cos(handleAngle);
                    let outerY = centerY + outerRadius * Math.sin(handleAngle);

                    ctx.strokeStyle = Colors.overBackground;
                    ctx.lineWidth = lineWidth;
                    ctx.beginPath();
                    ctx.moveTo(innerX, innerY);
                    ctx.lineTo(outerX, outerY);
                    ctx.stroke();
                }

                // Dibujar resto (desde valor actual + gap hasta el final)
                let remainingStart = baseStartAngle + progressAngleRad + handleGapRad;
                let totalAngle = (360 - 2 * root.gapAngle) * Math.PI / 180;
                let remainingEnd = baseStartAngle + totalAngle;

                if (remainingStart < remainingEnd) {
                    ctx.strokeStyle = Colors.outline;
                    ctx.lineWidth = lineWidth;
                    ctx.beginPath();
                    ctx.arc(centerX, centerY, radius, remainingStart, remainingEnd, false);
                    ctx.stroke();
                }
            }

            Connections {
                target: progressCanvas
                function onAngleChanged() {
                    canvas.requestPaint();
                }
            }

            Connections {
                target: root
                function onAccentColorChanged() {
                    canvas.requestPaint();
                }
            }
        }

        Behavior on angle {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
    }

    Text {
        anchors.centerIn: parent
        text: root.icon
        color: Colors.overBackground
        font.family: Icons.font
        font.pixelSize: 18
        rotation: root.enableIconRotation ? root.iconRotation : 0
        scale: root.iconScale

        Behavior on color {
            enabled: Config.animDuration > 0
            ColorAnimation {
                duration: Config.animDuration / 2
                easing.type: Easing.OutQuart
            }
        }

        Behavior on rotation {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: 400
                easing.type: Easing.OutCubic
            }
        }

        Behavior on scale {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: 400
                easing.type: Easing.OutCubic
            }
        }
    }
}
