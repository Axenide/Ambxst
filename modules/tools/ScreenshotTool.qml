import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.globals
import qs.config

PanelWindow {
    id: screenshotPopup
    // Screen property to be set by the Loader
    required property var targetScreen
    screen: targetScreen

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: screenshotPopup.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Visible only when explicitly opened
    visible: state !== "idle"
    exclusionMode: ExclusionMode.Ignore

    property string state: "idle" // idle, loading, active, processing
    
    Component.onCompleted: {
        // Auto-open if created while the tool is supposed to be visible
        if (GlobalStates.screenshotToolVisible) {
            open();
        }
    }
    
    // Bind to GlobalStates for synchronization
    property string currentMode: GlobalStates.screenshotCaptureMode
    
    onCurrentModeChanged: {
        if (GlobalStates.screenshotCaptureMode !== currentMode) {
            GlobalStates.screenshotCaptureMode = currentMode
        }
        
        // Update grid index to match mode
        var idx = -1;
        for (var i = 0; i < modes.length; i++) {
            if (modes[i].name === currentMode) {
                idx = i;
                break;
            }
        }
        
        if (idx !== -1 && modeGrid && modeGrid.currentIndex !== idx) {
             modeGrid.currentIndex = idx
        }
    }
    
    // Listen for global changes - MUST be outside any property binding loop
    Connections {
        target: GlobalStates
        function onScreenshotCaptureModeChanged() {
            if (screenshotPopup.currentMode !== GlobalStates.screenshotCaptureMode) {
                screenshotPopup.currentMode = GlobalStates.screenshotCaptureMode
            }
        }
    }

    property var activeWindows: []

    property var modes: [
        {
            name: "region",
            icon: Icons.regionScreenshot,
            tooltip: "Region"
        },
        {
            name: "window",
            icon: Icons.windowScreenshot,
            tooltip: "Window"
        },
        {
            name: "screen",
            icon: Icons.fullScreenshot,
            tooltip: "Screen"
        }
    ]

    function open() {
        if (modeGrid)
            modeGrid.currentIndex = 0;
        GlobalStates.screenshotCaptureMode = "region";

        screenshotPopup.state = "loading";
        
        // Trigger freeze (Service will batch it for all monitors)
        Screenshot.freezeScreen();
    }

    function close() {
        screenshotPopup.state = "idle";
        GlobalStates.screenshotToolVisible = false;
    }

    function executeCapture() {
        if (screenshotPopup.currentMode === "screen") {
            // Fullscreen capture for THIS monitor
            Screenshot.processMonitorScreen(screenshotPopup.targetScreen.name);
            close();
        } else if (screenshotPopup.currentMode === "region") {
            if (Screenshot.selectionW > 0) {
                Screenshot.processRegion(Screenshot.selectionX, Screenshot.selectionY, Screenshot.selectionW, Screenshot.selectionH);
                close();
            }
        } else if (screenshotPopup.currentMode === "window") {
            // Window mode capture handled by tap
        }
    }

    Connections {
        target: Screenshot
        // New signal for per-monitor readiness
        function onMonitorScreenshotReady(monitorName, path) {
            if (monitorName === screenshotPopup.targetScreen.name) {
                previewImage.source = "";
                previewImage.source = "file://" + path;
                screenshotPopup.state = "active";
                
                // Reset selection
                Screenshot.selectionW = 0;
                Screenshot.selectionH = 0;
                
                // Fetch windows if needed (idempotent call)
                // Screenshot.fetchWindows();
                
                modeGrid.forceActiveFocus();
            }
        }
        function onWindowListReady(windows) {
            screenshotPopup.activeWindows = windows;
        }
        function onErrorOccurred(msg) {
            console.warn("Screenshot Error:", msg);
            close();
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

        Keys.onEscapePressed: close()

        // 1. The "Frozen" Image
        Item {
            anchors.fill: parent
            clip: true
            
            Image {
                id: previewImage
                // Now we display a monitor-specific image which exactly matches our bounds
                fillMode: Image.Stretch
                anchors.fill: parent
                
                visible: screenshotPopup.state === "active"
            }
        }

        // 2. Dimmer
        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: screenshotPopup.state === "active" ? 0.4 : 0
            visible: screenshotPopup.state === "active" && screenshotPopup.currentMode !== "screen"
        }

        // 3. Window Selection
        Item {
            anchors.fill: parent
            visible: screenshotPopup.state === "active" && screenshotPopup.currentMode === "window"

            Repeater {
                model: screenshotPopup.activeWindows
                delegate: Rectangle {
                    // Window coords are global logical.
                    // Map to local.
                    x: modelData.at[0] - screenshotPopup.screen.x
                    y: modelData.at[1] - screenshotPopup.screen.y
                    width: modelData.size[0]
                    height: modelData.size[1]
                    
                    color: "transparent"
                    border.color: hoverHandler.hovered ? Styling.srItem("overprimary") : "transparent"
                    border.width: 2

                    Rectangle {
                        anchors.fill: parent
                        color: Styling.srItem("overprimary")
                        opacity: hoverHandler.hovered ? 0.2 : 0
                    }

                    HoverHandler {
                        id: hoverHandler
                    }

                    TapHandler {
                        onTapped: {
                            // Pass global coords
                            Screenshot.processRegion(modelData.at[0], modelData.at[1], modelData.size[0], modelData.size[1]);
                            close();
                        }
                    }
                }
            }
        }

        // 4. Region Selection
        MouseArea {
            id: regionArea
            anchors.fill: parent
            enabled: screenshotPopup.state === "active" && (screenshotPopup.currentMode === "region" || screenshotPopup.currentMode === "screen")
            hoverEnabled: true
            cursorShape: screenshotPopup.currentMode === "region" ? Qt.CrossCursor : Qt.ArrowCursor

            property point startPointGlobal: Qt.point(0, 0)
            property bool selecting: false

            onPressed: mouse => {
                if (screenshotPopup.currentMode === "screen") return;

                // Calculate global coordinates
                var globalX = mouse.x + screenshotPopup.screen.x;
                var globalY = mouse.y + screenshotPopup.screen.y;

                startPointGlobal = Qt.point(globalX, globalY);
                
                Screenshot.selectionX = globalX;
                Screenshot.selectionY = globalY;
                Screenshot.selectionW = 0;
                Screenshot.selectionH = 0;
                selecting = true;
            }

            onClicked: {
                if (screenshotPopup.currentMode === "screen") {
                    Screenshot.processMonitorScreen(screenshotPopup.targetScreen.name);
                    close();
                }
            }

            onPositionChanged: mouse => {
                if (!selecting) return;
                
                var currentGlobalX = mouse.x + screenshotPopup.screen.x;
                var currentGlobalY = mouse.y + screenshotPopup.screen.y;

                var x = Math.min(startPointGlobal.x, currentGlobalX);
                var y = Math.min(startPointGlobal.y, currentGlobalY);
                var w = Math.abs(startPointGlobal.x - currentGlobalX);
                var h = Math.abs(startPointGlobal.y - currentGlobalY);

                Screenshot.selectionX = x;
                Screenshot.selectionY = y;
                Screenshot.selectionW = w;
                Screenshot.selectionH = h;
            }

            onReleased: {
                if (!selecting) return;
                selecting = false;
                
                if (Screenshot.selectionW > 5 && Screenshot.selectionH > 5) {
                    Screenshot.processRegion(Screenshot.selectionX, Screenshot.selectionY, Screenshot.selectionW, Screenshot.selectionH);
                    close();
                }
            }
        }

        // Visual Selection Rect (Synced)
        Rectangle {
            id: selectionRect
            visible: screenshotPopup.state === "active" && screenshotPopup.currentMode === "region"
            
            // Map global selection to local
            x: Screenshot.selectionX - screenshotPopup.screen.x
            y: Screenshot.selectionY - screenshotPopup.screen.y
            width: Screenshot.selectionW
            height: Screenshot.selectionH
            
            color: "transparent"
            border.color: Styling.srItem("overprimary")
            border.width: 2

            Rectangle {
                anchors.fill: parent
                color: Styling.srItem("overprimary")
                opacity: 0.2
            }
        }

        // 5. Controls UI
        Rectangle {
            id: controlsBar
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 50
            width: modeGrid.width + 32
            height: modeGrid.height + 32
            radius: Styling.radius(20)
            color: Colors.background
            border.color: Colors.surface
            border.width: 1
            visible: screenshotPopup.state === "active"

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                // preventStealing: true 
            }

            ActionGrid {
                id: modeGrid
                anchors.centerIn: parent
                actions: screenshotPopup.modes
                buttonSize: 48
                iconSize: 24
                spacing: 10

                onCurrentIndexChanged: {
                    // Update local property, which triggers GlobalStates update
                    screenshotPopup.currentMode = screenshotPopup.modes[currentIndex].name;
                }

                onActionTriggered: {
                    screenshotPopup.executeCapture();
                }
            }
        }
    }
}
