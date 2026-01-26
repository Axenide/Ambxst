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
    id: screenrecordPopup
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    visible: state !== "idle"
    exclusionMode: ExclusionMode.Ignore

    property string state: "idle" // idle, loading, active, processing
    property string currentMode: "region" // region, window, screen, portal
    property var activeWindows: []

    property bool recordAudioOutput: false
    property bool recordAudioInput: false

    function getModes() {
        return [
            {
                name: "audio",
                icon: recordAudioOutput ? Icons.speakerHigh : Icons.speakerSlash,
                tooltip: "Toggle Audio Output",
                type: "toggle",
                variant: recordAudioOutput ? "primary" : "focus"
            },
            {
                name: "mic",
                icon: recordAudioInput ? Icons.mic : Icons.micSlash,
                tooltip: "Toggle Microphone",
                type: "toggle",
                variant: recordAudioInput ? "primary" : "focus"
            },
            {
                type: "separator"
            },
            {
                name: "region",
                icon: Icons.regionScreenshot,
                tooltip: ScreenRecorder.canRecordDirectly ? "Region" : "Region (Unavailable on NixOS without config)",
                enabled: ScreenRecorder.canRecordDirectly
            },
            {
                name: "window",
                icon: Icons.windowScreenshot,
                tooltip: ScreenRecorder.canRecordDirectly ? "Window" : "Window (Unavailable on NixOS without config)",
                enabled: ScreenRecorder.canRecordDirectly
            },
            {
                name: "screen",
                icon: Icons.fullScreenshot,
                tooltip: ScreenRecorder.canRecordDirectly ? "Screen" : "Screen (Unavailable on NixOS without config)",
                enabled: ScreenRecorder.canRecordDirectly
            },
            {
                name: "portal",
                icon: Icons.aperture,
                tooltip: "Portal"
            }
        ];
    }

    function open() {
        if (modeGrid)
            modeGrid.currentIndex = ScreenRecorder.canRecordDirectly ? 3 : 6; // Default to region (3) or portal (6)
        screenrecordPopup.currentMode = ScreenRecorder.canRecordDirectly ? "region" : "portal";
        screenrecordPopup.recordAudioOutput = false;
        screenrecordPopup.recordAudioInput = false;
        
        // Fetch windows for window mode
        Screenshot.fetchWindows();
        
        // Go directly to active state (no freeze needed)
        screenrecordPopup.state = "active";
        
        // Force focus
        if (modeGrid)
            modeGrid.forceActiveFocus();
    }

    function close() {
        screenrecordPopup.state = "idle";
    }

    function executeCapture() {
        if (screenrecordPopup.currentMode === "screen") {
            ScreenRecorder.startRecording(screenrecordPopup.recordAudioOutput, screenrecordPopup.recordAudioInput, "screen", "");
            screenrecordPopup.close();
        } else if (screenrecordPopup.currentMode === "region") {
            if (selectionRect.width > 0) {
                var w = Math.round(selectionRect.width);
                var h = Math.round(selectionRect.height);
                var x = Math.round(selectionRect.x);
                var y = Math.round(selectionRect.y);
                var regionStr = w + "x" + h + "+" + x + "+" + y;
                ScreenRecorder.startRecording(screenrecordPopup.recordAudioOutput, screenrecordPopup.recordAudioInput, "region", regionStr);
                screenrecordPopup.close();
            }
        } else if (screenrecordPopup.currentMode === "window") {
            // In window mode, capture handled by click
        } else if (screenrecordPopup.currentMode === "portal") {
            ScreenRecorder.startRecording(screenrecordPopup.recordAudioOutput, screenrecordPopup.recordAudioInput, "portal", "");
            screenrecordPopup.close();
        }
    }

    Connections {
        target: Screenshot
        function onWindowListReady(windows) {
            screenrecordPopup.activeWindows = windows;
        }
    }

    mask: Region {
        item: screenrecordPopup.visible ? fullMask : emptyMask
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

    HyprlandFocusGrab {
        id: focusGrab
        windows: [screenrecordPopup]
        active: screenrecordPopup.visible
    }

    FocusScope {
        id: mainFocusScope
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: screenrecordPopup.close()

        // Dimmer overlay (semi-transparent)
        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: screenrecordPopup.state === "active" ? 0.4 : 0
            visible: screenrecordPopup.state === "active" && screenrecordPopup.currentMode !== "screen" && screenrecordPopup.currentMode !== "portal"
        }

        Item {
            anchors.fill: parent
            visible: screenrecordPopup.state === "active" && screenrecordPopup.currentMode === "window"

            Repeater {
                model: screenrecordPopup.activeWindows
                delegate: Rectangle {
                    x: modelData.at[0]
                    y: modelData.at[1]
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
                            var w = Math.round(parent.width);
                            var h = Math.round(parent.height);
                            var x = Math.round(parent.x);
                            var y = Math.round(parent.y);
                            var regionStr = w + "x" + h + "+" + x + "+" + y;
                            ScreenRecorder.startRecording(screenrecordPopup.recordAudioOutput, screenrecordPopup.recordAudioInput, "region", regionStr);
                            screenrecordPopup.close();
                        }
                    }
                }
            }
        }

        MouseArea {
            id: regionArea
            anchors.fill: parent
            enabled: screenrecordPopup.state === "active" && (screenrecordPopup.currentMode === "region" || screenrecordPopup.currentMode === "screen" || screenrecordPopup.currentMode === "portal")
            hoverEnabled: true
            cursorShape: screenrecordPopup.currentMode === "region" ? Qt.CrossCursor : Qt.ArrowCursor

            property point startPoint: Qt.point(0, 0)
            property bool selecting: false

            onPressed: mouse => {
                if (screenrecordPopup.currentMode === "screen" || screenrecordPopup.currentMode === "portal") {
                    return;
                }

                startPoint = Qt.point(mouse.x, mouse.y);
                selectionRect.x = mouse.x;
                selectionRect.y = mouse.y;
                selectionRect.width = 0;
                selectionRect.height = 0;
                selecting = true;
            }

            onClicked: {
                if (screenrecordPopup.currentMode === "screen") {
                    ScreenRecorder.startRecording(screenrecordPopup.recordAudioOutput, screenrecordPopup.recordAudioInput, "screen", "");
                    screenrecordPopup.close();
                } else if (screenrecordPopup.currentMode === "portal") {
                    ScreenRecorder.startRecording(screenrecordPopup.recordAudioOutput, screenrecordPopup.recordAudioInput, "portal", "");
                    screenrecordPopup.close();
                }
            }

            onPositionChanged: mouse => {
                if (!selecting)
                    return;
                var x = Math.min(startPoint.x, mouse.x);
                var y = Math.min(startPoint.y, mouse.y);
                var w = Math.abs(startPoint.x - mouse.x);
                var h = Math.abs(startPoint.y - mouse.y);

                selectionRect.x = x;
                selectionRect.y = y;
                selectionRect.width = w;
                selectionRect.height = h;
            }

            onReleased: {
                if (!selecting)
                    return;
                selecting = false;
                if (selectionRect.width > 5 && selectionRect.height > 5) {
                    var w = Math.round(selectionRect.width);
                    var h = Math.round(selectionRect.height);
                    var x = Math.round(selectionRect.x);
                    var y = Math.round(selectionRect.y);
                    var regionStr = w + "x" + h + "+" + x + "+" + y;
                    ScreenRecorder.startRecording(screenrecordPopup.recordAudioOutput, screenrecordPopup.recordAudioInput, "region", regionStr);
                    screenrecordPopup.close();
                }
            }
        }

        Rectangle {
            id: selectionRect
            visible: screenrecordPopup.state === "active" && screenrecordPopup.currentMode === "region"
            color: "transparent"
            border.color: Styling.srItem("overprimary")
            border.width: 2

            Rectangle {
                anchors.fill: parent
                color: Styling.srItem("overprimary")
                opacity: 0.2
            }
        }

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
            visible: screenrecordPopup.state === "active"

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                preventStealing: true
            }

            ActionGrid {
                id: modeGrid
                anchors.centerIn: parent
                actions: screenrecordPopup.getModes()
                buttonSize: 48
                iconSize: 24
                spacing: 10

                onCurrentIndexChanged: {
                    // Skip toggles and separator
                    if (currentIndex > 2) {
                        var captureIndex = currentIndex - 3;
                        var captureOptions = ["region", "window", "screen", "portal"];
                        if (captureIndex >= 0 && captureIndex < captureOptions.length) {
                            screenrecordPopup.currentMode = captureOptions[captureIndex];
                        }
                    }
                }

                onActionTriggered: action => {
                    if (action.tooltip === "Toggle Audio Output") {
                        screenrecordPopup.recordAudioOutput = !screenrecordPopup.recordAudioOutput;
                    } else if (action.tooltip === "Toggle Microphone") {
                        screenrecordPopup.recordAudioInput = !screenrecordPopup.recordAudioInput;
                    } else {
                        screenrecordPopup.executeCapture();
                    }
                }
            }
        }
    }
}
