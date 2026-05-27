pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.config

// A horizontal slider row with icon for use in popup controls
Item {
    id: root

    signal valueChanged(real newValue)
    signal iconClicked

    property string icon: ""
    property real sliderValue: 0
    property color progressColor: Styling.srItem("overprimary")
    property bool wavy: false
    property real wavyAmplitude: 0.8
    property real wavyFrequency: 8
    property real iconRotation: 0
    property real iconScale: 1

    // Internal animated properties
    property real _animatedWavyAmplitude: wavyAmplitude
    property real _animatedWavyFrequency: wavyFrequency
    property real _animatedIconRotation: iconRotation
    property real _animatedIconScale: iconScale

    // Animate wavy properties
    Behavior on _animatedWavyAmplitude {
        enabled: Anim.animationsEnabled
        NumberAnimation {
            duration: Anim.standardNormal
            easing.type: Anim.easing("standard").type
                        easing.bezierCurve: Anim.easing("standard").bezierCurve
        }
    }
    Behavior on _animatedWavyFrequency {
        enabled: Anim.animationsEnabled
        NumberAnimation {
            duration: Anim.standardNormal
            easing.type: Anim.easing("standard").type
                        easing.bezierCurve: Anim.easing("standard").bezierCurve
        }
    }
    Behavior on _animatedIconRotation {
        enabled: Anim.animationsEnabled
        NumberAnimation {
            duration: 400
            easing.type: Anim.easing("standard").type
                        easing.bezierCurve: Anim.easing("standard").bezierCurve
        }
    }
    Behavior on _animatedIconScale {
        enabled: Anim.animationsEnabled
        NumberAnimation {
            duration: 400
            easing.type: Anim.easing("standard").type
                        easing.bezierCurve: Anim.easing("standard").bezierCurve
        }
    }

    // Sync animated properties
    onWavyAmplitudeChanged: _animatedWavyAmplitude = wavyAmplitude
    onWavyFrequencyChanged: _animatedWavyFrequency = wavyFrequency
    onIconRotationChanged: _animatedIconRotation = iconRotation
    onIconScaleChanged: _animatedIconScale = iconScale

    implicitHeight: 36
    implicitWidth: 200

    RowLayout {
        anchors.fill: parent
        spacing: 8

        // Icon button
        Item {
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            Layout.alignment: Qt.AlignVCenter

            Text {
                id: iconText
                anchors.centerIn: parent
                text: root.icon
                font.family: Icons.font
                font.pixelSize: 18
                color: iconMouseArea.containsMouse ? Styling.srItem("overprimary") : Colors.overBackground
                rotation: root._animatedIconRotation
                scale: root._animatedIconScale

                Behavior on color {
                    enabled: Anim.animationsEnabled
                    ColorAnimation {
                        duration: Anim.standardSmall
                    }
                }
            }

            MouseArea {
                id: iconMouseArea
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.iconClicked()
            }
        }

        // Slider
        Item {
            id: sliderContainer
            Layout.fillWidth: true
            Layout.preferredHeight: 20
            Layout.alignment: Qt.AlignVCenter

            property real animatedProgress: root.sliderValue

            Behavior on animatedProgress {
                enabled: Anim.animationsEnabled
                NumberAnimation {
                    duration: Anim.standardNormal
                    easing.type: Anim.easing("standard").type
                        easing.bezierCurve: Anim.easing("standard").bezierCurve
                }
            }

            // Background track
            Rectangle {
                anchors.left: dragHandle.right
                anchors.leftMargin: 4
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 6
                radius: Styling.radius(0) / 4
                color: Colors.overSecondaryFixedVariant
            }

            // Progress fill (wavy or solid)
            Loader {
                active: false
                anchors.left: parent.left
                anchors.right: dragHandle.left
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                height: 32
                z: 1
                sourceComponent: CarouselProgress {
                    anchors.fill: parent
                    frequency: root._animatedWavyFrequency
                    color: root.progressColor
                    amplitudeMultiplier: root._animatedWavyAmplitude
                    lineWidth: 4
                    fullLength: sliderContainer.width
                    active: true
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: dragHandle.left
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                height: 6
                radius: Styling.radius(0) / 4
                color: root.progressColor
                visible: true
                z: 1
            }

            // Drag handle
            Rectangle {
                id: dragHandle
                anchors.verticalCenter: parent.verticalCenter
                x: sliderContainer.width * sliderContainer.animatedProgress - width / 2
                width: mouseArea.pressed ? 2 : 4
                height: mouseArea.pressed ? 20 : 16
                radius: Styling.radius(0)
                color: Colors.overBackground
                z: 2

                Behavior on width {
                    enabled: Anim.animationsEnabled
                    NumberAnimation {
                        duration: Anim.standardNormal
                        easing.type: Anim.easing("standard").type
                        easing.bezierCurve: Anim.easing("standard").bezierCurve
                    }
                }
                Behavior on height {
                    enabled: Anim.animationsEnabled
                    NumberAnimation {
                        duration: Anim.standardNormal
                        easing.type: Anim.easing("standard").type
                        easing.bezierCurve: Anim.easing("standard").bezierCurve
                    }
                }
            }

            // Tooltip
            StyledToolTip {
                tooltipText: `${Math.round(root.sliderValue * 100)}%`
                visible: mouseArea.pressed
                x: dragHandle.x + dragHandle.width / 2 - width / 2
                y: dragHandle.y - height - 5
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                preventStealing: true

                function calculateValue(mouseX: real): real {
                    return Math.max(0, Math.min(1, mouseX / sliderContainer.width));
                }

                onPressed: mouse => {
                    root.sliderValue = calculateValue(mouse.x);
                    root.valueChanged(root.sliderValue);
                }

                onPositionChanged: mouse => {
                    if (pressed) {
                        root.sliderValue = calculateValue(mouse.x);
                        root.valueChanged(root.sliderValue);
                    }
                }

                onWheel: wheel => {
                    const step = 0.05;
                    if (wheel.angleDelta.y > 0) {
                        root.sliderValue = Math.min(1, root.sliderValue + step);
                    } else {
                        root.sliderValue = Math.max(0, root.sliderValue - step);
                    }
                    root.valueChanged(root.sliderValue);
                }
            }
        }
    }
}
