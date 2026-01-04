import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

PanelWindow {
    id: screenshotPopup
    
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // Visible only when explicitly opened
    visible: state !== "idle"
    exclusionMode: ExclusionMode.Ignore

    property string state: "idle" // idle, loading, active, processing
    property string currentMode: "region" // region, window, screen
    property var activeWindows: []
    
    // Get monitor info for coordinate conversion
    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property real monitorScale: monitor?.scale ?? 1.0
    readonly property string monitorName: monitor?.name ?? ""
    readonly property int monitorX: monitor?.x ?? 0
    readonly property int monitorY: monitor?.y ?? 0

    property var modes: [
        { name: "region", icon: Icons.regionScreenshot, tooltip: "Region" }, 
        { name: "window", icon: Icons.windowScreenshot, tooltip: "Window" }, 
        { name: "screen", icon: Icons.fullScreenshot, tooltip: "Screen" }
    ]

    function open() {
        // Reset to default state
        if (modeGrid) modeGrid.currentIndex = 0
        screenshotPopup.currentMode = "region"
        
        screenshotPopup.state = "loading"
        // Pass monitor name to capture only this output
        Screenshot.freezeScreen(monitorName)
    }

    function close() {
        screenshotPopup.state = "idle"
    }
    
    function executeCapture() {
        if (screenshotPopup.currentMode === "screen") {
            Screenshot.processFullscreen()
            screenshotPopup.close()
        } else if (screenshotPopup.currentMode === "region") {
            // Check if rect exists
            if (selectionRect.width > 0) {
                // Scale coordinates from logical to physical pixels
                var scaledX = Math.round(selectionRect.x * monitorScale)
                var scaledY = Math.round(selectionRect.y * monitorScale)
                var scaledW = Math.round(selectionRect.width * monitorScale)
                var scaledH = Math.round(selectionRect.height * monitorScale)
                Screenshot.processRegion(scaledX, scaledY, scaledW, scaledH)
                screenshotPopup.close()
            }
        } else if (screenshotPopup.currentMode === "window") {
            // If enter pressed in window mode, maybe capture the one under cursor?
        }
    }

    // Connect to global Screenshot singleton signals
    Connections {
        target: Screenshot
        function onScreenshotCaptured(path) {
            previewImage.source = ""
            previewImage.source = "file://" + path
            screenshotPopup.state = "active"
            // Reset selection
            selectionRect.width = 0
            selectionRect.height = 0
            // Fetch windows if we are in window mode, or pre-fetch
            Screenshot.fetchWindows()
            
            // Force focus on the overlay window content
            modeGrid.forceActiveFocus()
        }
        function onWindowListReady(windows) {
            screenshotPopup.activeWindows = windows
        }
        function onErrorOccurred(msg) {
            console.warn("Screenshot Error:", msg)
            screenshotPopup.close()
        }
    }

    // Mask to capture input on the entire window when open
    mask: Region {
        item: screenshotPopup.visible ? fullMask : emptyMask
    }

    Item {
        id: fullMask
        anchors.fill: parent
    }

    Item {
        id: emptyMask
        width: 0
        height: 0
    }

    // Focus grabber
    HyprlandFocusGrab {
        id: focusGrab
        windows: [screenshotPopup]
        active: screenshotPopup.visible
    }

    // Main Content
    FocusScope {
        id: mainFocusScope
        anchors.fill: parent
        focus: true
        
        Keys.onEscapePressed: screenshotPopup.close()
        
        // 1. The "Frozen" Image
        Image {
            id: previewImage
            anchors.fill: parent
            fillMode: Image.Stretch
            visible: screenshotPopup.state === "active"
        }

        // 2. Dimmer (Dark overlay)
        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: screenshotPopup.state === "active" ? 0.4 : 0
            visible: screenshotPopup.state === "active" && screenshotPopup.currentMode !== "screen"
        }
        
        // 3. Window Selection Highlights
        Item {
            anchors.fill: parent
            visible: screenshotPopup.state === "active" && screenshotPopup.currentMode === "window"
            
            Repeater {
                model: screenshotPopup.activeWindows
                delegate: Rectangle {
                    // Window coordinates from Hyprland are global (include monitor offset)
                    // Subtract monitor offset and divide by scale to get QML local coordinates
                    readonly property real winX: (modelData.at[0] - screenshotPopup.monitorX) / screenshotPopup.monitorScale
                    readonly property real winY: (modelData.at[1] - screenshotPopup.monitorY) / screenshotPopup.monitorScale
                    readonly property real winW: modelData.size[0] / screenshotPopup.monitorScale
                    readonly property real winH: modelData.size[1] / screenshotPopup.monitorScale
                    
                    x: winX
                    y: winY
                    width: winW
                    height: winH
                    color: "transparent"
                    border.color: hoverHandler.hovered ? Styling.styledRectItem("overprimary") : "transparent"
                    border.width: 2
                    
                    Rectangle {
                        anchors.fill: parent
                        color: Styling.styledRectItem("overprimary")
                        opacity: hoverHandler.hovered ? 0.2 : 0
                    }

                    HoverHandler {
                        id: hoverHandler
                    }
                    
                    TapHandler {
                        onTapped: {
                            // For crop, use coordinates relative to the captured image (this monitor only)
                            // Subtract monitor offset from global Hyprland coordinates
                            var localX = modelData.at[0] - screenshotPopup.monitorX
                            var localY = modelData.at[1] - screenshotPopup.monitorY
                            Screenshot.processRegion(localX, localY, modelData.size[0], modelData.size[1])
                            screenshotPopup.close()
                        }
                    }
                }
            }
        }

        // 4. Region Selection (Drag) and Screen Capture (Click)
        MouseArea {
            id: regionArea
            anchors.fill: parent
            enabled: screenshotPopup.state === "active" && (screenshotPopup.currentMode === "region" || screenshotPopup.currentMode === "screen")
            hoverEnabled: true
            cursorShape: screenshotPopup.currentMode === "region" ? Qt.CrossCursor : Qt.ArrowCursor

            property point startPoint: Qt.point(0, 0)
            property bool selecting: false

            onPressed: mouse => {
                if (screenshotPopup.currentMode === "screen") {
                    // Immediate capture for screen mode
                    return
                }
                
                startPoint = Qt.point(mouse.x, mouse.y)
                selectionRect.x = mouse.x
                selectionRect.y = mouse.y
                selectionRect.width = 0
                selectionRect.height = 0
                selecting = true
            }

            onClicked: {
                if (screenshotPopup.currentMode === "screen") {
                    Screenshot.processFullscreen()
                    screenshotPopup.close()
                }
            }

            onPositionChanged: mouse => {
                if (!selecting) return
                
                var x = Math.min(startPoint.x, mouse.x)
                var y = Math.min(startPoint.y, mouse.y)
                var w = Math.abs(startPoint.x - mouse.x)
                var h = Math.abs(startPoint.y - mouse.y)
                
                selectionRect.x = x
                selectionRect.y = y
                selectionRect.width = w
                selectionRect.height = h
            }

            onReleased: {
                if (!selecting) return // for screen mode click
                
                selecting = false
                // Auto capture on release? Or wait for confirm? 
                // Usually region drag ends in capture.
                if (selectionRect.width > 5 && selectionRect.height > 5) {
                    // Scale coordinates from logical to physical pixels
                    var scaledX = Math.round(selectionRect.x * screenshotPopup.monitorScale)
                    var scaledY = Math.round(selectionRect.y * screenshotPopup.monitorScale)
                    var scaledW = Math.round(selectionRect.width * screenshotPopup.monitorScale)
                    var scaledH = Math.round(selectionRect.height * screenshotPopup.monitorScale)
                    Screenshot.processRegion(scaledX, scaledY, scaledW, scaledH)
                    screenshotPopup.close()
                }
            }
        }
        
        // Visual Selection Rect
        Rectangle {
            id: selectionRect
            visible: screenshotPopup.state === "active" && screenshotPopup.currentMode === "region"
            color: "transparent"
            border.color: Styling.styledRectItem("overprimary")
            border.width: 2
            
            Rectangle {
                anchors.fill: parent
                color: Styling.styledRectItem("overprimary")
                opacity: 0.2
            }
        }

        // 5. Controls UI (Bottom Bar)
        Rectangle {
            id: controlsBar
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 50
            
            // Padding of 16px around the content
            width: modeGrid.width + 32
            height: modeGrid.height + 32
            
            radius: Styling.radius(20)
            color: Colors.background
            border.color: Colors.surface
            border.width: 1
            visible: screenshotPopup.state === "active"
            
            // Catch-all MouseArea
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                preventStealing: true
            }
            
            ActionGrid {
                id: modeGrid
                anchors.centerIn: parent
                actions: screenshotPopup.modes
                buttonSize: 48
                iconSize: 24
                spacing: 10
                
                onCurrentIndexChanged: {
                    screenshotPopup.currentMode = screenshotPopup.modes[currentIndex].name
                }
                
                onActionTriggered: {
                    screenshotPopup.executeCapture()
                }
            }
        }
    }
}
