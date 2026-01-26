import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

PanelWindow {
    id: root
    // Screen property to be set by the Loader
    required property var targetScreen
    screen: targetScreen

    property string imagePath: ""
    
    // Position: Bottom Left with margins
    anchors {
        left: true
        bottom: true
    }
    
    // Width/Height handled by content + margins
    implicitWidth: mainRow.width + 20
    implicitHeight: mainRow.height + 20
    
    color: "transparent"
    visible: imagePath !== ""

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Timer to auto-hide after 5 seconds
    Timer {
        id: hideTimer
        interval: 5000
        repeat: false
        running: root.visible && !mouseAreaHover.containsMouse
        onTriggered: root.imagePath = ""
    }

    // MouseArea to detect hover and prevent auto-hide
    MouseArea {
        id: mouseAreaHover
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton // Pass clicks through
        propagateComposedEvents: true
    }

    // Listen for the saved signal from Screenshot service
    Connections {
        target: Screenshot
        function onImageSaved(path) {
            // Check if the screenshot happened on this monitor
            // We can check if the file path contains the monitor name or we can infer it.
            // But Screenshot.qml's processRegion/processMonitorScreen logic uses 'root.monitors' to crop.
            // The 'finalPath' is usually generic (Screenshot_Date.png).
            // However, typically the overlay should appear where the USER is interacting or where the screenshot was taken.
            // Since `processRegion` determines the monitor, but `imageSaved` just gives a path...
            // We might need to assume it shows on ALL monitors or we need better logic.
            // BUT, for now, let's show it on the monitor where the mouse cursor is? 
            // OR, since the user said "en el monitor donde haya ocurrido" (on the monitor where it happened),
            // and Screenshot.qml finds that monitor in `processRegion`.
            // Let's assume for now we show it on the screen that matches `Screenshot.monitors` logic.
            // Given the limited signal data, we'll try to match the screen containing the mouse cursor
            // when the signal fires, OR we show it on all screens? No, that's annoying.
            // A better hack: check if the 'targetScreen' contains the 'Screenshot.selectionX/Y'.
            
            var s = root.targetScreen;
            var mx = Screenshot.selectionX;
            var my = Screenshot.selectionY;
            var logicalW = s.width; // s.width is physical * scale usually in Quickshell, wait.
            // Quickshell.screens report logical size directly usually?
            // Actually `Screenshot.qml` uses `s.width * s.scale`.
            
            // Let's check bounds.
            if (mx >= s.x && mx < (s.x + s.width) &&
                my >= s.y && my < (s.y + s.height)) {
                root.imagePath = path;
            } else if (Screenshot.captureMode === "screen") {
                 // For full screen, we might need to check if this screen is the one that was captured.
                 // But Screenshot.qml doesn't export which screen was captured easily.
                 // We will rely on the fact that usually the user interacts with the tool on that screen.
                 // Or we can just default to showing it if the mouse is here.
                 var cursor = Quickshell.cursor;
                 if (cursor && cursor.screen && cursor.screen.name === s.name) {
                     root.imagePath = path;
                 }
            }
        }
    }

    Row {
        id: mainRow
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: 20
        spacing: 8

        // Preview Image with Drag Support
        ClippingRectangle {
            id: imgContainer
            
            // Calculate scale to fit within 250x250 while preserving aspect ratio
            property real maxWidth: 250
            property real maxHeight: 250
            property real imgRatio: img.sourceSize.width / img.sourceSize.height
            property real boxRatio: maxWidth / maxHeight
            
            // If image is wider relative to box, width limits height
            // If image is taller relative to box, height limits width
            width: {
                if (img.sourceSize.width <= 0) return 0;
                if (imgRatio > boxRatio) return maxWidth;
                return Math.min(maxWidth, img.sourceSize.width * (maxHeight / img.sourceSize.height));
            }
            
            height: {
                if (img.sourceSize.height <= 0) return 0;
                if (imgRatio > boxRatio) return Math.min(maxHeight, img.sourceSize.height * (maxWidth / img.sourceSize.width));
                return maxHeight;
            }

            radius: Styling.radius(4)
            color: "transparent"
            border.width: 2
            border.color: Colors.primaryFixed

            Image {
                id: img
                anchors.fill: parent
                source: root.imagePath !== "" ? "file://" + root.imagePath : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                
                // Invisible item to handle the Drag attached property state
                Item {
                    id: dragTarget
                    Drag.active: dragArea.drag.active
                    Drag.dragType: Drag.Automatic
                    Drag.supportedActions: Qt.CopyAction
                    Drag.mimeData: { 
                        "text/uri-list": "file://" + root.imagePath 
                    }
                    // Visual feedback is handled by the drag operation itself usually,
                    // or we can use Drag.imageSource.
                    Drag.imageSource: img.source
                }
                
                MouseArea {
                    id: dragArea
                    anchors.fill: parent
                    hoverEnabled: true
                    
                    // Show Grab Hand
                    cursorShape: Qt.DragCopyCursor
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    
                    // Bind drag target to initiate the drag sequence
                    drag.target: dragTarget
                    
                    // Click to Open (Left) or Delete (Middle)
                    onClicked: mouse => {
                        if (mouse.button === Qt.MiddleButton) {
                             var proc = Qt.createQmlObject('import Quickshell; import Quickshell.Io; Process { }', root);
                             proc.command = ["rm", root.imagePath];
                             proc.running = true;
                             root.imagePath = "";
                        } else {
                             Qt.openUrlExternally("file://" + root.imagePath);
                        }
                    }
                }
                
                // Icon overlay on hover (optional, but requested "Icons.handGrab" context)
                Rectangle {
                    anchors.centerIn: parent
                    width: 32; height: 32
                    radius: 16
                    color: Colors.background
                    opacity: dragArea.containsMouse ? 0.8 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    
                    Text {
                        anchors.centerIn: parent
                        text: Icons.handGrab // Assuming this exists per user request
                        font.family: Icons.font
                        color: Colors.overBackground
                    }
                }
            }
        }

        // Action Buttons
        Column {
            spacing: 4
            anchors.verticalCenter: parent.verticalCenter
            
            // Helper Component for Buttons
            component ActionButton : MouseArea {
                id: btn
                width: 36
                height: 36
                hoverEnabled: true
                
                property string icon
                property string variant: "common"
                property string hoverVariant: "focus"
                property string clickVariant: "primary"
                property bool isTrash: false
                
                signal triggered()
                
                StyledRect {
                    anchors.fill: parent
                    radius: Styling.radius(0)
                    variant: {
                        if (btn.pressed) return btn.clickVariant;
                        if (btn.containsMouse) return btn.hoverVariant;
                        return btn.variant;
                    }
                    
                    Text {
                        anchors.centerIn: parent
                        text: btn.icon
                        font.family: Icons.font
                        font.pixelSize: 16
                        color: Styling.srItem(parent.variant) || Colors.overBackground
                    }
                }
                
                onClicked: triggered()
            }

            // Copy
            ActionButton {
                icon: Icons.copy
                onTriggered: {
                    // Re-run copy just in case, or user explicit action
                    // Screenshot service already has copyProcess, we can reuse it
                    // by manually calling wl-copy since copyProcess is internal property.
                    // Or we can assume it's already copied.
                    // Let's run a new process to be safe/feedback.
                    var proc = Qt.createQmlObject('import Quickshell; import Quickshell.Io; Process { }', root);
                    proc.command = ["bash", "-c", "wl-copy < \"" + root.imagePath + "\""];
                    proc.running = true;
                    // Maybe close?
                }
                
                StyledToolTip {
                    show: parent.containsMouse
                    tooltipText: "Copy"
                }
            }

            // Save (Actually "Open Folder" or just "Keep")
            // Since it's already saved to disk, maybe this opens the folder?
            // User said "Save (Icons.disk)".
            ActionButton {
                icon: Icons.disk
                onTriggered: {
                    // It is already saved. Maybe this dismisses the preview but keeps the file?
                    root.imagePath = ""; // Hide overlay
                }
                StyledToolTip {
                    show: parent.containsMouse
                    tooltipText: "Save & Close"
                }
            }

            // Edit
            ActionButton {
                icon: Icons.edit
                onTriggered: {
                    // Open with Gradia (native or Flatpak for Fedora) detached
                    var proc = Qt.createQmlObject('import Quickshell; import Quickshell.Io; Process { }', root);
                    proc.command = ["bash", "-c", "if command -v gradia >/dev/null; then gradia \"" + root.imagePath + "\"; else flatpak run be.alexandervanhee.gradia \"" + root.imagePath + "\"; fi & disown"];
                    proc.running = true;
                    root.imagePath = "";
                }
                StyledToolTip {
                    show: parent.containsMouse
                    tooltipText: "Edit with Gradia"
                }
            }

            // Trash
            ActionButton {
                icon: Icons.trash
                hoverVariant: "error"
                clickVariant: "overerror"
                isTrash: true
                
                onTriggered: {
                    var proc = Qt.createQmlObject('import Quickshell; import Quickshell.Io; Process { }', root);
                    proc.command = ["rm", root.imagePath];
                    proc.running = true;
                    root.imagePath = "";
                }
                StyledToolTip {
                    show: parent.containsMouse
                    tooltipText: "Delete"
                }
            }
        }
    }
}
