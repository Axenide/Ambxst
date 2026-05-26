pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import qs.modules.globals
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config

Item {
    id: root

    property var windowData
    property var toplevel
    property var monitorData: null
    property real scale
    property real availableWorkspaceWidth
    property real availableWorkspaceHeight
    property real xOffset: 0
    property real yOffset: 0

    property bool hovered: false
    property bool pressed: false
    property bool atInitPosition: (initX == x && initY == y)

    property string barPosition: "top"
    property int barReserved: 0

    // Reference to overview root (for drag state)
    property Item overviewRootRef: null

    // Search highlighting
    property bool isSearchMatch: false
    property bool isSearchSelected: false

    // Override position tracking for immediate visual update
    property real overrideX: -1
    property real overrideY: -1
    property bool useOverridePosition: false

    // Cache calculated values
    readonly property real initX: {
        if (useOverridePosition && overrideX >= 0)
            return overrideX;
        // hyprctl clients -j returns ABSOLUTE coordinates
        var mx = (monitorData && monitorData.x !== undefined) ? monitorData.x : 0;
        var base = (windowData?.at?.[0] || 0) - mx;
        if (barPosition === "left")
            base -= barReserved;
        return Math.round(Math.max(base * scale, 0) + xOffset);
    }
    readonly property real initY: {
        if (useOverridePosition && overrideY >= 0)
            return overrideY;
        // hyprctl clients -j returns ABSOLUTE coordinates
        var my = (monitorData && monitorData.y !== undefined) ? monitorData.y : 0;
        var base = (windowData?.at?.[1] || 0) - my;
        if (barPosition === "top")
            base -= barReserved;
        return Math.round(Math.max(base * scale, 0) + yOffset);
    }
    // Use real window size when available (>200px), otherwise fill 85% of workspace cell
    readonly property real targetWindowWidth: Math.round(Math.min(
        (windowData?.size[0] > 200 ? windowData.size[0] : Math.round(availableWorkspaceWidth * 0.85 / scale)) * scale,
        availableWorkspaceWidth))
    readonly property real targetWindowHeight: Math.round(Math.min(
        (windowData?.size[1] > 200 ? windowData.size[1] : Math.round(availableWorkspaceHeight * 0.85 / scale)) * scale,
        availableWorkspaceHeight))
    readonly property bool compactMode: targetWindowHeight < 60 || targetWindowWidth < 60
    readonly property string iconPath: AppSearch.guessIcon(windowData?.class || "")
    readonly property int calculatedRadius: Styling.radius(-2)

    // Drag tracking
    property bool _isDragging: false

    signal dragStarted
    signal dragFinished(int targetWorkspace)
    signal windowClicked
    signal windowClosed

    x: initX
    y: initY
    width: targetWindowWidth
    height: targetWindowHeight
    z: atInitPosition ? 1 : 99999

    Drag.active: false
    Drag.hotSpot.x: width / 2
    Drag.hotSpot.y: height / 2

    clip: true

    // Timer to reset override position after a delay (waiting for AxctlService update)
    Timer {
        id: resetOverrideTimer
        interval: 200
        onTriggered: {
            root.useOverridePosition = false;
        }
    }

    // Watch for windowData changes: reset override and sync position
    onWindowDataChanged: {
        if (useOverridePosition)
            resetOverrideTimer.restart();
        // Re-apply position after data refresh (drag.target broke the binding)
        x = initX;
        y = initY;
    }

    Behavior on x {
        enabled: Config.animDuration > 0 && !root.useOverridePosition
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutQuart
        }
    }
    Behavior on y {
        enabled: Config.animDuration > 0 && !root.useOverridePosition
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutQuart
        }
    }
    Behavior on width {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutQuart
        }
    }
    Behavior on height {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutQuart
        }
    }

    ClippingRectangle {
        anchors.fill: parent
        radius: root.calculatedRadius
        antialiasing: true
        border.color: Colors.background
        border.width: 0

        ScreencopyView {
            id: windowPreview
            anchors.fill: parent
            captureSource: Config.performance.windowPreview && GlobalStates.overviewOpen ? root.toplevel : null
            live: GlobalStates.overviewOpen
            visible: Config.performance.windowPreview
        }

        // Retry capture periodically when preview has no content
        Timer {
            id: retryPreviewTimer
            interval: 600
            running: GlobalStates.overviewOpen && Config.performance.windowPreview
            repeat: true
            onTriggered: {
                if (!windowPreview.hasContent && root.toplevel) {
                    // Toggle capture source to force retry
                    windowPreview.captureSource = null;
                    Qt.callLater(function() {
                        windowPreview.captureSource = Config.performance.windowPreview && GlobalStates.overviewOpen ? root.toplevel : null;
                    });
                }
            }
        }
    }

    // Background rectangle with rounded corners
    Rectangle {
        id: previewBackground
        anchors.fill: parent
        radius: root.calculatedRadius
        color: pressed ? Colors.surfaceBright : hovered ? Colors.surface : Colors.surfaceContainer
        border.color: root.isSearchSelected ? Colors.tertiary : root.isSearchMatch ? Styling.srItem("overprimary") : Colors.outlineVariant
        border.width: root.isSearchSelected ? 3 : root.isSearchMatch ? 2 : (hovered ? 2 : 1)
        visible: !windowPreview.hasContent || !Config.performance.windowPreview
        opacity: !windowPreview.hasContent ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        Behavior on color {
            enabled: Config.animDuration > 0
            ColorAnimation {
                duration: Config.animDuration / 2
            }
        }

        Behavior on border.width {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration / 2
            }
        }
    }

    // Overlay content when preview is not available
    Image {
        mipmap: true
        id: windowIcon
        readonly property real iconSize: Math.round(Math.min(root.targetWindowWidth, root.targetWindowHeight) * (root.compactMode ? 0.6 : 0.35))
        anchors.centerIn: parent
        width: iconSize
        height: iconSize
        source: Quickshell.iconPath(root.iconPath, "image-missing")
        sourceSize: Qt.size(iconSize, iconSize)
        asynchronous: true
        visible: !windowPreview.hasContent || !Config.performance.windowPreview
        z: 10
    }

    // Overlay border and effects when preview is available
    Rectangle {
        id: previewOverlay
        anchors.fill: parent
        radius: root.calculatedRadius
        color: pressed ? Qt.rgba(Colors.surfaceContainerHighest.r, Colors.surfaceContainerHighest.g, Colors.surfaceContainerHighest.b, 0.5) : hovered ? Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 0.2) : "transparent"
        border.color: root.isSearchSelected ? Colors.tertiary : root.isSearchMatch ? Styling.srItem("overprimary") : Styling.srItem("overprimary")
        border.width: root.isSearchSelected ? 3 : root.isSearchMatch ? 2 : (hovered ? 2 : 0)
        visible: windowPreview.hasContent && Config.performance.windowPreview
        z: 5

        Behavior on border.width {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration / 2
            }
        }
    }

    // Search match glow effect
    Rectangle {
        visible: root.isSearchSelected && !root.Drag.active
        anchors.fill: parent
        anchors.margins: -4
        radius: root.calculatedRadius + 4
        color: "transparent"
        border.color: Colors.tertiary
        border.width: 2
        opacity: 0.6
        z: -1
    }

    // Overlay icon when preview is available (smaller, in corner)
    Image {
        mipmap: true
        visible: windowPreview.hasContent && !root.compactMode && Config.performance.windowPreview
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 4
        width: 16
        height: 16
        source: Quickshell.iconPath(root.iconPath, "image-missing")
        sourceSize: Qt.size(16, 16)
        asynchronous: true
        opacity: 0.8
        z: 10
    }

    // XWayland indicator
    Rectangle {
        visible: root.windowData?.xwayland || false
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 2
        width: 6
        height: 6
        radius: 3
        color: Colors.error
        z: 10
    }

    MouseArea {
        id: dragArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        drag.target: parent

        onEntered: {
            root.hovered = true;
        }
        onExited: root.hovered = false

        onPressed: mouse => {
            root.pressed = true;
            root._isDragging = false;
            root.Drag.active = true;
            root.Drag.source = root;
            root.dragStarted();
        }

        onPositionChanged: {
            if (!root._isDragging && root.Drag.active)
                root._isDragging = true;
        }

        onReleased: mouse => {
            root.pressed = false;
            root.Drag.active = false;

            if (mouse.button === Qt.LeftButton && root._isDragging) {
                // Calculate target workspace from MOUSE position (more accurate than window pos)
                // Mouse in winLayer coordinates = window.pos + mouse.offset
                var ov = root.overviewRootRef;
                var targetWs = -1;

                if (ov && ov.columns && ov.rows) {
                    // Mouse position in winLayer coordinates (winLayer == grid coords)
                    var mx = root.x + mouse.x;
                    var my = root.y + mouse.y;
                    // Cell dimensions (grid spacing + cell size + padding)
                    var cw = root.availableWorkspaceWidth + ov.workspacePadding + ov.workspaceSpacing;
                    var ch = root.availableWorkspaceHeight + ov.workspacePadding + ov.workspaceSpacing;
                    // Cell index from mouse position (cells start at padding/2)
                    var colIdx = Math.floor((mx - ov.workspacePadding / 2) / cw);
                    var rowIdx = Math.floor((my - ov.workspacePadding / 2) / ch);

                    if (colIdx >= 0 && colIdx < ov.columns && rowIdx >= 0 && rowIdx < ov.rows)
                        targetWs = rowIdx * ov.columns + colIdx + 1;
                }

                // If grid calculation failed, try DropArea state
                if (targetWs <= 0 && ov)
                    targetWs = ov.draggingTargetWorkspace;

                // If still nothing, stay on current workspace
                if (targetWs <= 0)
                    targetWs = windowData?.workspace?.id || -1;

                // Signal the delegate handles the move + refresh
                root.dragFinished(targetWs);
                if (ov) ov.draggingTargetWorkspace = -1;

                // Don't dispatch here — the delegate's onDragFinished handles it
                // Just reset visual position (will be updated when data refreshes)
                root.x = root.initX;
                root.y = root.initY;
            }
        }

        onClicked: mouse => {
            if (!root.windowData)
                return;

            if (mouse.button === Qt.LeftButton) {
                // Single click just focuses the window without closing overview
                AxctlService.dispatch(`focuswindow address:${windowData.address}`);
            } else if (mouse.button === Qt.MiddleButton) {
                root.windowClosed();
            }
        }

        onDoubleClicked: mouse => {
            if (!root.windowData)
                return;

            if (mouse.button === Qt.LeftButton) {
                // Double click closes overview and focuses window
                root.windowClicked();
            }
        }
    }

    // Tooltip
    Rectangle {
        visible: dragArea.containsMouse && !root.Drag.active && root.windowData
        anchors.bottom: parent.top
        anchors.bottomMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter
        width: tooltipText.implicitWidth + 16
        height: tooltipText.implicitHeight + 8
        color: Colors.inverseSurface
        radius: Styling.radius(0) / 2
        opacity: 0.9
        z: 1000

        Text {
            id: tooltipText
            anchors.centerIn: parent
            text: `${root.windowData?.title || ""}\n[${root.windowData?.class || ""}]${root.windowData?.xwayland ? " [XWayland]" : ""}`
            font.family: Config.theme.font
            font.pixelSize: 10
            color: Colors.inverseOnSurface
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
