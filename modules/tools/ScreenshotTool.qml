import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

Variants {
    id: screenshotVariants
    model: Quickshell.screens

    delegate: PanelWindow {
        id: screenshotPopup
        
        property var modelData
        screen: modelData
        property string capturePath: ""
        property var windows: []
        
        anchors { top: true; bottom: true; left: true; right: true }
        
        color: "transparent" 
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        
        visible: Screenshot.state !== "idle"
        exclusionMode: ExclusionMode.Ignore

        readonly property real dpr: (previewImage.status === Image.Ready && previewImage.sourceSize.width > 0)
                                    ? previewImage.sourceSize.width / width
                                    : screen.devicePixelRatio

        onVisibleChanged: {
            if (visible && Screenshot.state === "loading") {
                capturePath = Screenshot.generateCapturePath(screen.name)
                freezeProcess.command = ["grim", "-o", screen.name, capturePath]
                freezeProcess.running = true
            }
        }

        Process {
            id: freezeProcess
            onExited: exitCode => {
                if (exitCode === 0) {
                    previewImage.source = "file://" + capturePath
                    Screenshot.state = "active"
                    Screenshot.fetchWindows()
                } else {
                    Screenshot.stopCapture()
                }
            }
        }

        Connections {
            target: Screenshot
            function onScreenshotCaptured(path) {
                if (path.indexOf(screen.name) !== -1) {
                    previewImage.source = "file://" + path
                    Screenshot.state = "active"
                    // Window list is fetched when mode changes or needed
                }
            }
            function onWindowListReady(list) {
                screenshotPopup.windows = list
            }
        }        
        FocusScope {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: Screenshot.stopCapture()
            
            Image {
                id: previewImage
                anchors.fill: parent
                fillMode: Image.Stretch 
                visible: Screenshot.state === "active"
                cache: false
            }

            Rectangle {
                anchors.fill: parent
                color: "black"
                opacity: (Screenshot.currentMode !== "screen") ? 0.4 : 0
                visible: Screenshot.state === "active"
            }

            MouseArea {
                id: regionArea
                anchors.fill: parent
                enabled: Screenshot.state === "active" && (Screenshot.currentMode === "region" || Screenshot.currentMode === "screen")
                
                property point startPoint: Qt.point(0, 0)
                property bool selecting: false

                onPressed: mouse => {
                    if (Screenshot.currentMode === "screen" || Screenshot.currentMode === "window") return
                    startPoint = Qt.point(mouse.x, mouse.y)
                    selectionRect.x = mouse.x; selectionRect.y = mouse.y
                    selectionRect.width = 0; selectionRect.height = 0
                    selecting = true
                }

                onPositionChanged: mouse => {
                    if (!selecting) return
                    selectionRect.x = Math.min(startPoint.x, mouse.x)
                    selectionRect.y = Math.min(startPoint.y, mouse.y)
                    selectionRect.width = Math.abs(startPoint.x - mouse.x)
                    selectionRect.height = Math.abs(startPoint.y - mouse.y)
                }

                onReleased: {
                    if (selecting) {
                        selecting = false
                        if (selectionRect.width > 2) {
                            Screenshot.processRegion(
                                Math.round(selectionRect.x * dpr), 
                                Math.round(selectionRect.y * dpr), 
                                Math.round(selectionRect.width * dpr), 
                                Math.round(selectionRect.height * dpr),
                                capturePath
                            )
                        }
                    }
                }
                onClicked: if (Screenshot.currentMode === "screen") Screenshot.processFullscreen(capturePath)
            }

            // Window Selection Overlay
            Repeater {
                model: Screenshot.currentMode === "window" ? windows : []
                delegate: Rectangle {
                    // Calculate relative position: Window Global X - Screen Global X
                    property int relX: modelData.at[0] - screen.x
                    property int relY: modelData.at[1] - screen.y
                    property int w: modelData.size[0]
                    property int h: modelData.size[1]

                    // Use geometry only if it overlaps/is on this screen (simplistic check: width > 0)
                    // We just draw it. If it's off-screen, it won't be seen or clickable effectively.
                    x: relX
                    y: relY
                    width: w
                    height: h
                    
                    color: "transparent"
                    border.color: hoverHandler.hovered ? Styling.styledRectItem("overprimary") : "white"
                    border.width: hoverHandler.hovered ? 4 : 2
                    opacity: 0.5
                    
                    HoverHandler { id: hoverHandler }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Screenshot.processRegion(
                                Math.round(parent.relX * dpr), 
                                Math.round(parent.relY * dpr), 
                                Math.round(parent.w * dpr), 
                                Math.round(parent.h * dpr), 
                                capturePath
                            )
                        }
                    }
                }
            }
            
            Rectangle {
                id: selectionRect
                visible: Screenshot.state === "active" && Screenshot.currentMode === "region" && width > 0
                color: "transparent"
                border.color: Styling.styledRectItem("overprimary")
                border.width: 2
            }

            Rectangle {
                id: controlsBar
                anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: 50
                width: modeGrid.width + 32; height: modeGrid.height + 32
                radius: Styling.radius(20); color: Colors.background
                visible: Screenshot.state === "active"
                
                ActionGrid {
                    id: modeGrid
                    anchors.centerIn: parent
                    actions: [
                        { name: "region", tooltip: "Select Region", icon: Icons.regionScreenshot }, 
                        { name: "window", tooltip: "Select Window", icon: Icons.windowScreenshot }, 
                        { name: "screen", tooltip: "Fullscreen", icon: Icons.fullScreenshot }
                    ]
                    onCurrentIndexChanged: {
                        Screenshot.currentMode = actions[currentIndex].name
                        if (Screenshot.currentMode === "window") {
                            Screenshot.fetchWindows()
                        }
                    }
                }
            }
        }
    }
}
