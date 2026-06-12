import QtQuick
import QtQuick.Controls
import QtMultimedia
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.components
import qs.modules.globals
import qs.config

PanelWindow {
    id: root

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    visible: GlobalStates.mirrorWindowVisible

    property int xPos: Screen.width - root.currentWidth - 20
    property int yPos: (Screen.height / 2) - (root.currentHeight / 2)
    property bool isSquare: true
    property bool isFlipped: true

    property int currentWidth: isSquare ? 300 : 480
    property int currentHeight: 300

    Item {
        id: fullRegion
        anchors.fill: parent
        visible: false
    }

    readonly property bool isInteracting: dragArea.pressed || resizeBR.pressed || resizeBL.pressed || resizeTR.pressed || resizeTL.pressed

    mask: Region {
        item: isInteracting ? fullRegion : container
    }

    ClippingRectangle {
        id: container
        x: xPos
        y: yPos
        width: currentWidth
        height: currentHeight
        color: camera.cameraStatus === Camera.ActiveStatus ? "transparent" : "black"
        radius: Styling.radius(8)

        CaptureSession {
            id: captureSession
            camera: Camera {
                id: camera
                active: root.visible
            }
            videoOutput: videoOutput
        }

        VideoOutput {
            id: videoOutput
            anchors.fill: parent
            fillMode: VideoOutput.PreserveAspectCrop

            transform: Scale {
                origin.x: videoOutput.width / 2
                xScale: root.isFlipped ? -1 : 1
            }
        }

        MouseArea {
            id: dragArea
            anchors.fill: parent
            hoverEnabled: true

            property point globalStartPoint: Qt.point(0, 0)
            property int startXPos: 0
            property int startYPos: 0

            onPressed: mouse => {
                globalStartPoint = mapToItem(null, mouse.x, mouse.y);
                startXPos = root.xPos;
                startYPos = root.yPos;
            }

            onPositionChanged: mouse => {
                if (pressed) {
                    var p = mapToItem(null, mouse.x, mouse.y);
                    var dx = p.x - globalStartPoint.x;
                    var dy = p.y - globalStartPoint.y;
                    root.xPos = startXPos + dx;
                    root.yPos = startYPos + dy;
                }
            }

            // Controls Overlay
            Row {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: 20
                spacing: 16
                z: 3

                // Show only on hover or when buttons are pressed
                opacity: (dragArea.containsMouse || controlHover.containsMouse) ? 1.0 : 0.0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 200
                    }
                }

                HoverHandler {
                    id: controlHover
                }

                // Toggle Ratio Button
                Rectangle {
                    width: 40
                    height: 40
                    radius: 20
                    color: Colors.surface

                    Text {
                        anchors.centerIn: parent
                        text: root.isSquare ? Icons.arrowsOut : Icons.crop
                        font.family: Icons.font
                        color: Colors.overBackground
                        font.pixelSize: 20
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.isSquare = !root.isSquare;
                            // Reset size logic
                            if (root.isSquare) {
                                root.currentHeight = 300;
                                root.currentWidth = 300;
                            } else {
                                root.currentHeight = 300;
                                root.currentWidth = 480; // Reset to default wide
                            }
                        }
                    }
                }

                // Flip Button
                Rectangle {
                    width: 40
                    height: 40
                    radius: 20
                    color: Colors.surface

                    Text {
                        anchors.centerIn: parent
                        text: Icons.flipX
                        font.family: Icons.font
                        color: Colors.overBackground
                        font.pixelSize: 20
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.isFlipped = !root.isFlipped
                    }
                }

                // Close Button
                StyledRect {
                    width: 40
                    height: 40
                    radius: 20
                    variant: "error"

                    Text {
                        anchors.centerIn: parent
                        text: Icons.cancel
                        font.family: Icons.font
                        color: Styling.srItem("error")
                        font.pixelSize: 20
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: GlobalStates.mirrorWindowVisible = false
                    }
                }
            }
        }

        // --- Resize Handles Instances ---

        ResizeHandle {
            id: resizeBR
            mode: 0
            anchors.bottom: parent.bottom
            anchors.right: parent.right
        }

        ResizeHandle {
            id: resizeBL
            mode: 1
            anchors.bottom: parent.bottom
            anchors.left: parent.left
        }

        ResizeHandle {
            id: resizeTR
            mode: 2
            anchors.top: parent.top
            anchors.right: parent.right
        }

        ResizeHandle {
            id: resizeTL
            mode: 3
            anchors.top: parent.top
            anchors.left: parent.left
        }
    }

    // --- Resize Handle Component Definition ---
    component ResizeHandle: MouseArea {
        property int mode: 0 // 0:BR, 1:BL, 2:TR, 3:TL
        width: 20
        height: 20
        hoverEnabled: true
        preventStealing: true
        cursorShape: (mode == 0 || mode == 3) ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor
        z: 4

        property point startPoint: Qt.point(0, 0)
        property int startW: 0
        property int startH: 0
        property int startX: 0
        property int startY: 0

        onPressed: mouse => {
            startPoint = mapToItem(null, mouse.x, mouse.y);
            startW = root.currentWidth;
            startH = root.currentHeight;
            startX = root.xPos;
            startY = root.yPos;
            mouse.accepted = true;
        }

        onPositionChanged: mouse => {
            if (pressed) {
                var p = mapToItem(null, mouse.x, mouse.y);
                var dx = p.x - startPoint.x;
                var dy = p.y - startPoint.y;

                var newW = startW;
                var newH = startH;
                var newX = startX;
                var newY = startY;

                // Bottom-Right
                if (mode === 0) {
                    newW = Math.max(150, startW + dx);
                    if (root.isSquare) {
                        newH = newW;
                    } else {
                        if (startH > 0)
                            newH = newW / (startW / startH);
                    }
                } else
                // Bottom-Left
                if (mode === 1) {
                    newW = Math.max(150, startW - dx);
                    if (root.isSquare) {
                        newH = newW;
                    } else {
                        if (startH > 0)
                            newH = newW / (startW / startH);
                    }
                    newX = startX + (startW - newW);
                } else
                // Top-Right
                if (mode === 2) {
                    newW = Math.max(150, startW + dx);
                    if (root.isSquare) {
                        newH = newW;
                    } else {
                        if (startH > 0)
                            newH = newW / (startW / startH);
                    }
                    newY = startY + (startH - newH);
                } else
                // Top-Left
                if (mode === 3) {
                    newW = Math.max(150, startW - dx);
                    if (root.isSquare) {
                        newH = newW;
                    } else {
                        if (startH > 0)
                            newH = newW / (startW / startH);
                    }
                    newX = startX + (startW - newW);
                    newY = startY + (startH - newH);
                }

                root.currentWidth = newW;
                root.currentHeight = newH;
                root.xPos = newX;
                root.yPos = newY;
            }
        }

        Text {
            anchors.centerIn: parent
            text: mode == 0 || mode == 3 ? Icons.caretDoubleDown : Icons.caretDoubleUp
            rotation: mode == 0 ? -45 : mode == 1 ? 45 : mode == 2 ? -135 : 135
            font.family: Icons.font
            color: Styling.srItem("overprimary")
            font.pixelSize: 12
            opacity: (dragArea.containsMouse || parent.containsMouse) ? 0.8 : 0
        }
    }
}
