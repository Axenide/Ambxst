import QtQuick
import QtQuick.Controls
import QtMultimedia
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.modules.theme
import qs.modules.components
import qs.modules.globals
import qs.config

PanelWindow {
    id: root

    // Start position
    property int xPos: 200
    property int yPos: 200
    property bool isSquare: true

    anchors {
        top: true
        left: true
    }

    margins {
        left: xPos
        top: yPos
    }

    implicitWidth: isSquare ? 300 : 480
    implicitHeight: 300
    
    color: "transparent"
    
    WlrLayershell.layer: WlrLayer.Overlay
    visible: GlobalStates.mirrorWindowVisible

    // Content Background
    Rectangle {
        id: background
        anchors.fill: parent
        color: "black"
        radius: Styling.radius(12)
        clip: true
        border.color: Styling.primary
        border.width: 1

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
            // If square, crop to fill the square. If full, fit inside (or fill if aspect matches)
            fillMode: root.isSquare ? VideoOutput.PreserveAspectCrop : VideoOutput.PreserveAspectFit
        }
        
        // Drag Handler
        MouseArea {
            id: dragArea
            anchors.fill: parent
            hoverEnabled: true
            
            property point startPoint: Qt.point(0,0)
            
            onPressed: (mouse) => {
                startPoint = Qt.point(mouse.x, mouse.y)
            }
            
            onPositionChanged: (mouse) => {
                if (pressed) {
                    var dx = mouse.x - startPoint.x
                    var dy = mouse.y - startPoint.y
                    root.xPos += dx
                    root.yPos += dy
                }
            }

            // Controls Overlay
            Row {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: 20
                spacing: 16
                
                // Show only on hover or when buttons are pressed (to prevent flickering when moving between buttons)
                opacity: (dragArea.containsMouse || controlHover.containsMouse) ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 200 } }

                HoverHandler {
                    id: controlHover
                }

                // Toggle Ratio Button
                Rectangle {
                    width: 40
                    height: 40
                    radius: 20
                    color: Styling.surface
                    border.color: Styling.surfaceVariant
                    border.width: 1
                    
                    Text {
                        anchors.centerIn: parent
                        text: root.isSquare ? Icons.arrowsOutCardinal : Icons.aperture
                        font.family: Icons.font
                        color: Styling.text
                        font.pixelSize: 20
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.isSquare = !root.isSquare
                    }
                }

                // Close Button
                Rectangle {
                    width: 40
                    height: 40
                    radius: 20
                    color: Colors.red
                    
                    Text {
                        anchors.centerIn: parent
                        text: Icons.cancel
                        font.family: Icons.font
                        color: "white" // Always white on red
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
    }
}
