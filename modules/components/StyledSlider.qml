pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.config
import qs.modules.theme
import qs.modules.components

/**
 * Simplified slider inspired by CompactPlayer position control.
 * Supports both horizontal and vertical orientations.
 */

Item {
    id: root

    Layout.fillHeight: orientation === "v"
    Layout.fillWidth: orientation === "h"
    implicitHeight: orientation === "h" ? 4 : 100
    implicitWidth: orientation === "v" ? 4 : 100

    signal iconClicked

    property string orientation: "h" // "h" for horizontal, "v" for vertical
    property string icon: ""
    property real value: 0
    property bool isDragging: false
    property real dragPosition: 0.0
    property int dragSeparation: 4
    property real progressRatio: isDragging ? dragPosition : value
    property string tooltipText: `${Math.round(value * 100)}%`
    property color progressColor: Colors.primary
    property color backgroundColor: Colors.surfaceBright
    property bool wavy: false
    property real wavyAmplitude: 0.8
    property real wavyFrequency: 8
    property real heightMultiplier: 8
    property bool resizeAnim: true
    property bool scroll: true
    property bool tooltip: true
    property bool updateOnRelease: false
    property string iconPos: "start"

    Behavior on wavyAmplitude {
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutQuart
        }
    }

    Behavior on wavyFrequency {
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutQuart
        }
    }

    Behavior on heightMultiplier {
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutQuart
        }
    }

    // Horizontal Layout
    RowLayout {
        id: horizontalLayout
        visible: root.orientation === "h"
        anchors.fill: parent
        anchors.leftMargin: root.iconPos === "start" && root.icon !== "" ? iconText.width + spacing : 0
        anchors.rightMargin: root.iconPos === "end" && root.icon !== "" ? iconText.width + spacing : 0
        spacing: 4

        Item {
            id: hSliderItem
            Layout.fillWidth: true
            Layout.preferredHeight: 4
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                anchors.right: parent.right
                width: (1 - root.progressRatio) * parent.width - root.dragSeparation
                height: parent.height
                radius: height / 2
                color: root.backgroundColor
                z: 0

                Behavior on width {
                    enabled: root.resizeAnim
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                }
            }

            WavyLine {
                id: hWavyFill
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                frequency: root.wavyFrequency
                color: root.progressColor
                amplitudeMultiplier: root.wavyAmplitude
                height: parent.height * heightMultiplier
                width: Math.max(0, parent.width * root.progressRatio - root.dragSeparation)
                lineWidth: parent.height
                fullLength: parent.width
                visible: root.wavy
                opacity: 1.0
                z: 1

                Behavior on width {
                    enabled: root.resizeAnim
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                }

                FrameAnimation {
                    running: hWavyFill.visible && hWavyFill.opacity > 0
                    onTriggered: hWavyFill.requestPaint()
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, parent.width * root.progressRatio - root.dragSeparation)
                height: parent.height
                radius: height / 2
                color: root.progressColor
                visible: !root.wavy
                z: 1

                Behavior on width {
                    enabled: root.resizeAnim
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                }
            }

            Rectangle {
                id: hDragHandle
                anchors.verticalCenter: parent.verticalCenter
                x: parent.width * root.progressRatio - 2
                width: root.isDragging ? 2 : 4
                height: root.isDragging ? 20 : 16
                radius: width / 2
                color: Colors.overBackground
                z: 2

                Behavior on x {
                    enabled: root.resizeAnim
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                }

                Behavior on width {
                    enabled: root.resizeAnim
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                }

                Behavior on height {
                    enabled: root.resizeAnim
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                }
            }

            StyledToolTip {
                tooltipText: root.tooltipText
                visible: root.isDragging && root.tooltip
                x: hDragHandle.x + hDragHandle.width / 2 - width / 2
                y: hDragHandle.y - height - 5
            }
        }
    }

    // Vertical Layout
    ColumnLayout {
        id: verticalLayout
        visible: root.orientation === "v"
        anchors.fill: parent
        anchors.topMargin: root.iconPos === "start" && root.icon !== "" ? iconText.height + spacing : 0
        anchors.bottomMargin: root.iconPos === "end" && root.icon !== "" ? iconText.height + spacing : 0
        spacing: 4

        Item {
            id: vSliderItem
            Layout.fillHeight: true
            Layout.preferredWidth: 4
            Layout.alignment: Qt.AlignHCenter

            Rectangle {
                anchors.top: parent.top
                height: (1 - root.progressRatio) * parent.height - root.dragSeparation
                width: parent.width
                radius: width / 2
                color: root.backgroundColor
                z: 0

                Behavior on height {
                    enabled: root.resizeAnim
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                }
            }

            Item {
                id: wavyContainer
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width * heightMultiplier
                height: Math.max(0, parent.height * root.progressRatio - root.dragSeparation)
                
                WavyLine {
                    id: vWavyFill
                    anchors.centerIn: parent
                    rotation: -90
                    frequency: root.wavyFrequency
                    color: root.progressColor
                    amplitudeMultiplier: root.wavyAmplitude
                    height: parent.width
                    width: parent.height
                    lineWidth: parent.width / heightMultiplier
                    fullLength: parent.height
                    visible: root.wavy
                    opacity: 1.0
                    z: 1

                    FrameAnimation {
                        running: vWavyFill.visible && vWavyFill.opacity > 0
                        onTriggered: vWavyFill.requestPaint()
                    }
                }

                Behavior on height {
                    enabled: root.resizeAnim
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                height: Math.max(0, parent.height * root.progressRatio - root.dragSeparation)
                width: parent.width
                radius: width / 2
                color: root.progressColor
                visible: !root.wavy
                z: 1

                Behavior on height {
                    enabled: root.resizeAnim
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                }
            }

            Rectangle {
                id: vDragHandle
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * (1 - root.progressRatio) - 2
                height: root.isDragging ? 2 : 4
                width: root.isDragging ? 20 : 16
                radius: height / 2
                color: Colors.overBackground
                z: 2

                Behavior on y {
                    enabled: root.resizeAnim
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                }

                Behavior on width {
                    enabled: root.resizeAnim
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                }

                Behavior on height {
                    enabled: root.resizeAnim
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                }
            }

            StyledToolTip {
                tooltipText: root.tooltipText
                visible: root.isDragging && root.tooltip
                x: vDragHandle.x + vDragHandle.width + 5
                y: vDragHandle.y + vDragHandle.height / 2 - height / 2
            }
        }
    }

    Text {
        id: iconText
        visible: root.icon !== ""
        text: root.icon
        font.family: Icons.font
        font.pixelSize: 20
         color: Colors.overBackground
         x: root.orientation === "h" ? (root.iconPos === "start" ? 0 : parent.width - width) : (parent.width - width) / 2
         y: root.orientation === "v" ? (root.iconPos === "start" ? 0 : parent.height - height) : (parent.height - height) / 2
 
         MouseArea {
             anchors.fill: parent
             hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            z: 4
            onEntered: iconText.color = Colors.primary
            onExited: iconText.color = Colors.overBackground
            onClicked: root.iconClicked()
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        z: 3
        
        property var activeLayout: root.orientation === "h" ? horizontalLayout : verticalLayout
        property real layoutStart: root.orientation === "h" ? activeLayout.x : activeLayout.y
         property real layoutSize: root.orientation === "h" ? activeLayout.width : activeLayout.height
         
         function isInIconArea(mouseX: real, mouseY: real): bool {
            if (root.orientation === "h") {
                return (root.iconPos === "start" && mouseX < iconText.width + horizontalLayout.spacing) ||
                       (root.iconPos === "end" && mouseX > parent.width - iconText.width - horizontalLayout.spacing)
            } else {
                return (root.iconPos === "start" && mouseY < iconText.height + verticalLayout.spacing) ||
                       (root.iconPos === "end" && mouseY > parent.height - iconText.height - verticalLayout.spacing)
            }
        }
        
         function calculatePosition(mouseX: real, mouseY: real): real {
            const mousePos = root.orientation === "h" ? mouseX : mouseY
            const relativePos = mousePos - layoutStart
            let ratio = Math.max(0, Math.min(1, relativePos / layoutSize))
            if (root.orientation === "v") {
                ratio = 1 - ratio // Invert for vertical
            }
            return ratio
        }
        
         onClicked: mouse => {
            if (isInIconArea(mouse.x, mouse.y)) {
                mouse.accepted = false
                return
            }
            const mousePos = root.orientation === "h" ? mouse.x : mouse.y
            if (mousePos >= layoutStart && mousePos <= layoutStart + layoutSize) {
                root.value = calculatePosition(mouse.x, mouse.y)
            } else {
                mouse.accepted = false
            }
        }
        
         onPressed: mouse => {
            if (isInIconArea(mouse.x, mouse.y)) {
                mouse.accepted = false
                return
            }
            const mousePos = root.orientation === "h" ? mouse.x : mouse.y
            if (mousePos >= layoutStart && mousePos <= layoutStart + layoutSize) {
                root.isDragging = true
                root.dragPosition = calculatePosition(mouse.x, mouse.y)
            } else {
                mouse.accepted = false
            }
        }
        
         onReleased: mouse => {
            if (root.isDragging) {
                root.value = root.dragPosition
                root.isDragging = false
            } else {
                mouse.accepted = false
            }
        }
        
         onPositionChanged: mouse => {
            if (isInIconArea(mouse.x, mouse.y)) {
                mouse.accepted = false
                return
            }
            if (root.isDragging) {
                root.dragPosition = calculatePosition(mouse.x, mouse.y)
                if (!root.updateOnRelease) {
                    root.value = root.dragPosition
                }
            } else {
                mouse.accepted = false
            }
        }
        
        onWheel: wheel => {
            if (root.scroll) {
                if (wheel.angleDelta.y > 0) {
                    root.value = Math.min(1, root.value + 0.1)
                } else {
                    root.value = Math.max(0, root.value - 0.1)
                }
            }
        }
    }

    onValueChanged: {
        // Override in usage
    }
}
