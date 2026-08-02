import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
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
    // Snapshot of the path for an in-flight drag so hide/clear cannot empty MIME mid-drag
    property string dragMimePath: ""
    readonly property bool dragInProgress: dragArea.drag.active || dragTarget.Drag.active

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

    function fileUri(path) {
        if (!path || path === "")
            return "";
        const parts = String(path).split("/");
        let out = "file://";
        let first = true;
        if (String(path).charAt(0) === "/")
            out += "/";
        for (let i = 0; i < parts.length; i++) {
            if (parts[i] === "") continue;
            if (!first) out += "/";
            out += encodeURIComponent(parts[i]);
            first = false;
        }
        return out;
    }

    function clearPreview() {
        if (root.dragInProgress)
            return;
        root.imagePath = "";
        root.dragMimePath = "";
    }

    property Process copyOverlayProcess: Process {
        id: copyOverlayProcess
        command: ["bash", "-c", "cat \"" + root.imagePath + "\" | wl-copy --type image/png"]
        onExited: exitCode => {
            if (exitCode !== 0)
                console.warn("Overlay Copy Failed (Exit code: " + exitCode + ")");
        }
    }

    // Timer to auto-hide after 5 seconds — paused while hovering or dragging out
    Timer {
        id: hideTimer
        interval: 5000
        repeat: false
        running: root.visible && !mouseAreaHover.containsMouse && !root.dragInProgress
        onTriggered: root.clearPreview()
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
            var s = root.targetScreen;
            var mx = Screenshot.selectionX;
            var my = Screenshot.selectionY;

            if (mx >= s.x && mx < (s.x + s.width) && my >= s.y && my < (s.y + s.height)) {
                root.imagePath = path;
            } else if (Screenshot.captureMode === "screen") {
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

            width: {
                if (img.sourceSize.width <= 0)
                    return 0;
                if (imgRatio > boxRatio)
                    return maxWidth;
                return Math.min(maxWidth, img.sourceSize.width * (maxHeight / img.sourceSize.height));
            }

            height: {
                if (img.sourceSize.height <= 0)
                    return 0;
                if (imgRatio > boxRatio)
                    return Math.min(maxHeight, img.sourceSize.height * (maxWidth / img.sourceSize.width));
                return maxHeight;
            }

            radius: Styling.radius(4)
            color: "transparent"
            border.width: 2
            border.color: Colors.primaryFixed

            Image {
                mipmap: true
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
                    // Snapshot path — never rebind to a cleared imagePath mid-drag
                    Drag.mimeData: root.dragMimePath !== "" ? {
                        "text/uri-list": root.fileUri(root.dragMimePath) + "\r\n",
                        "text/plain": root.fileUri(root.dragMimePath)
                    } : {}

                    Drag.onDragFinished: {
                        root.dragMimePath = "";
                        // Restart auto-hide once the external drop completes
                        hideTimer.restart();
                    }
                }

                MouseArea {
                    id: dragArea
                    anchors.fill: parent
                    hoverEnabled: true

                    cursorShape: Qt.DragCopyCursor
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton

                    drag.target: dragTarget
                    drag.threshold: 8

                    onPressed: mouse => {
                        if (mouse.button === Qt.LeftButton && root.imagePath !== "")
                            root.dragMimePath = root.imagePath;
                    }

                    // Click to Open (Left) or Delete (Middle)
                    onClicked: mouse => {
                        if (root.dragInProgress)
                            return;
                        if (mouse.button === Qt.MiddleButton) {
                            var proc = Qt.createQmlObject('import Quickshell; import Quickshell.Io; Process { }', root);
                            proc.command = ["rm", root.imagePath];
                            proc.onExited.connect(() => proc.destroy());
                            proc.running = true;
                            root.imagePath = "";
                            root.dragMimePath = "";
                        } else {
                            Qt.openUrlExternally("file://" + root.imagePath);
                        }
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 32
                    height: 32
                    radius: 16
                    color: Colors.background
                    opacity: dragArea.containsMouse && !root.dragInProgress ? 0.8 : 0
                    visible: opacity > 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 200
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: Icons.handGrab
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

            // Copy
            ActionButton {
                icon: Icons.copy
                onTriggered: {
                    copyOverlayProcess.running = true;
                }

                StyledToolTip {
                    show: parent.containsMouse
                    tooltipText: "Copy"
                }
            }

            ActionButton {
                icon: Icons.disk
                onTriggered: {
                    root.clearPreview();
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
                    if (root.dragInProgress)
                        return;
                    var path = root.imagePath;
                    var proc = Qt.createQmlObject('import Quickshell; import Quickshell.Io; Process { }', root);
                    proc.command = ["bash", "-c", "if command -v gradia >/dev/null; then gradia \"" + path + "\"; else flatpak run be.alexandervanhee.gradia \"" + path + "\"; fi & disown"];
                    proc.running = true;
                    root.imagePath = "";
                    root.dragMimePath = "";
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
                    if (root.dragInProgress)
                        return;
                    var proc = Qt.createQmlObject('import Quickshell; import Quickshell.Io; Process { }', root);
                    proc.command = ["rm", root.imagePath];
                    proc.onExited.connect(() => proc.destroy());
                    proc.running = true;
                    root.imagePath = "";
                    root.dragMimePath = "";
                }
                StyledToolTip {
                    show: parent.containsMouse
                    tooltipText: "Delete"
                }
            }
        }
    }

    // Helper Component for Buttons
    component ActionButton: MouseArea {
        id: btn
        width: 36
        height: 36
        hoverEnabled: true

        property string icon
        property string variant: "common"
        property string hoverVariant: "focus"
        property string clickVariant: "primary"
        property bool isTrash: false

        signal triggered

        StyledRect {
            anchors.fill: parent
            radius: Styling.radius(0)
            variant: {
                if (btn.pressed)
                    return btn.clickVariant;
                if (btn.containsMouse)
                    return btn.hoverVariant;
                return btn.variant;
            }

            Text {
                anchors.centerIn: parent
                text: btn.icon
                font.family: Icons.font
                font.pixelSize: Styling.fontSize(2)
                color: Styling.srItem(parent.variant) || Colors.overBackground
            }
        }

        onClicked: triggered()
    }
}
