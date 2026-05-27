pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.modules.theme
import qs.modules.components

/*!
    RegionPicker.qml — Screen region selection overlay.

    Shows a fullscreen semi-transparent overlay where the user can drag
    to select a rectangular region. On selection, captures the region
    via grim and copies to clipboard or saves to file.

    Usage:
        RegionPicker {
            id: picker
            onRegionSelected: (x, y, w, h) => {
                console.log("Selected:", x, y, w, h);
            }
        }

        // Open:
        picker.open()
*/
PanelWindow {
    id: root

    anchors.fill: parent
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "ambxst:regionpicker"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.margin.top: 0

    // ============================================
    // PUBLIC API
    // ============================================

    signal regionSelected(int x, int y, int width, int height)
    signal cancelled()

    /*! If true, captures the region with grim on selection. */
    property bool captureOnSelect: true

    /*! If true, copies the captured image to clipboard. */
    property bool copyToClipboard: true

    /*! Path to save the screenshot (empty = use temp file). */
    property string savePath: ""

    /*! Show crosshair cursor. */
    property bool showCrosshair: true

    // ============================================
    // INTERNAL
    // ============================================

    visible: false

    function open() {
        root.visible = true;
        root.forceActiveFocus();
        selection.active = false;
        selection.ready = false;
        selection.originX = 0;
        selection.originY = 0;
        selection.currentX = 0;
        selection.currentY = 0;
    }

    function close() {
        root.visible = false;
    }

    QtObject {
        id: selection
        property bool active: false
        property bool ready: false
        property int originX: 0
        property int originY: 0
        property int currentX: 0
        property int currentY: 0

        property int selX: Math.min(originX, currentX)
        property int selY: Math.min(originY, currentY)
        property int selW: Math.abs(currentX - originX)
        property int selH: Math.abs(currentY - originY)
    }

    // Semi-transparent backdrop
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.4)

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: root.showCrosshair ? Qt.CrossCursor : Qt.ArrowCursor

            onPressed: mouse => {
                if (mouse.button === Qt.RightButton) {
                    root.cancelled();
                    root.close();
                    return;
                }
                selection.active = true;
                selection.ready = false;
                selection.originX = mouse.x;
                selection.originY = mouse.y;
                selection.currentX = mouse.x;
                selection.currentY = mouse.y;
            }

            onPositionChanged: mouse => {
                if (!selection.active) return;
                selection.currentX = mouse.x;
                selection.currentY = mouse.y;
            }

            onReleased: mouse => {
                if (!selection.active) return;
                selection.active = false;

                // Minimum selection size
                if (selection.selW < 5 || selection.selH < 5) {
                    root.cancelled();
                    root.close();
                    return;
                }

                selection.ready = true;
                root.regionSelected(selection.selX, selection.selY, selection.selW, selection.selH);

                if (root.captureOnSelect) {
                    root.captureRegion(selection.selX, selection.selY, selection.selW, selection.selH);
                }
            }
        }
    }

    // Selection rectangle overlay
    Rectangle {
        x: selection.selX
        y: selection.selY
        width: selection.selW
        height: selection.selH
        color: "transparent"
        border.color: Colors.primary
        border.width: 2
        visible: selection.active || selection.ready

        // Size label
        Rectangle {
            anchors.bottom: parent.top
            anchors.left: parent.left
            anchors.bottomMargin: 2
            height: 22
            width: sizeLabel.width + 12
            radius: 4
            color: Qt.rgba(0, 0, 0, 0.7)
            visible: selection.active

            Text {
                id: sizeLabel
                anchors.centerIn: parent
                text: selection.selW + " × " + selection.selH
                font.family: "monospace"
                font.pixelSize: 11
                color: "white"
            }
        }
    }

    // Crosshair lines
    Shape {
        visible: selection.active
        anchors.fill: parent

        ShapePath {
            strokeColor: Qt.rgba(1, 1, 1, 0.5)
            strokeWidth: 1
            fillColor: "transparent"
            startX: 0
            startY: {
                const cy = selection.originY;
                const ty = Math.min(selection.originY, selection.currentY);
                return cy === ty ? cy + selection.selH : cy;
            }
            PathLine { x: root.width; y: selection.originY + (selection.currentY - selection.originY > 0 ? selection.selH : 0) }
        }

        ShapePath {
            strokeColor: Qt.rgba(1, 1, 1, 0.5)
            strokeWidth: 1
            fillColor: "transparent"
            startX: selection.originX + (selection.currentX - selection.originX > 0 ? selection.selW : 0)
            startY: 0
            PathLine { x: selection.originX + (selection.currentX - selection.originX > 0 ? selection.selW : 0); y: root.height }
        }
    }

    // Info text (shown before selection)
    Text {
        anchors.centerIn: parent
        text: "Click and drag to select a region\nRight-click to cancel"
        font.family: Config.theme.font
        font.pixelSize: 16
        color: "white"
        horizontalAlignment: Text.AlignHCenter
        opacity: selection.active ? 0 : 1
        visible: root.visible

        Behavior on opacity {
            enabled: Anim.animationsEnabled
            NumberAnimation { duration: Anim.standardSmall }
        }
    }

    // ============================================
    // CAPTURE
    // ============================================

    property Process _captureProcess: Process {
        id: captureProcess
        running: false

        stdout: SplitParser {
            onRead: (data) => {
                console.log("Region capture output:", data);
            }
        }

        onExited: (code) => {
            if (code === 0) {
                console.log("Region captured successfully");
                if (root.copyToClipboard) {
                    copyProcess.running = true;
                }
            } else {
                console.error("Region capture failed with code:", code);
            }
            root.close();
        }
    }

    property Process copyProcess: Process {
        id: copyProcess
        command: []
        running: false
    }

    function captureRegion(x, y, w, h) {
        const path = root.savePath || "/tmp/ambxst-region-" + Date.now() + ".png";
        const geom = x + "," + y + " " + w + "x" + h;
        captureProcess.command = ["grim", "-g", geom, path];

        if (root.copyToClipboard) {
            copyProcess.command = ["sh", "-c", "grim -g '" + geom + "' - | wl-copy"];
        }

        captureProcess.running = true;
    }

    // Handle keyboard: Escape to cancel
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            root.cancelled();
            root.close();
        }
    }
}
