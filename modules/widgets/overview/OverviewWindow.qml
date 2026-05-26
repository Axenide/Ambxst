pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
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
    // Monitor effective dimensions (accounting for rotation)
    readonly property real monitorEffectiveW: {
        if (!monitorData) return 1920;
        var ro = (monitorData.transform % 2 === 1);
        var mw = ro ? (monitorData.height || 1080) : (monitorData.width || 1920);
        return mw > 0 ? mw : 1920;
    }
    readonly property real monitorEffectiveH: {
        if (!monitorData) return 1080;
        var ro = (monitorData.transform % 2 === 1);
        var mh = ro ? (monitorData.width || 1920) : (monitorData.height || 1080);
        return mh > 0 ? mh : 1080;
    }

    // ── Pure proportion-based coordinates (0.0..1.0) ──
    // Window position and size as ratios of monitor, mapped to cell.
    // A small 2% gutter is subtracted so adjacent cards don't touch.
    readonly property real gutter: 0.02
    readonly property real effectiveCellW: availableWorkspaceWidth * (1 - gutter)
    readonly property real effectiveCellH: availableWorkspaceHeight * (1 - gutter)

    readonly property real relX: {
        var mx = monitorData?.x ?? 0;
        var base = (windowData?.at?.[0] ?? 0) - mx;
        if (barPosition === "left") base -= barReserved;
        return Math.max(0, Math.min(1, monitorEffectiveW > 0 ? base / monitorEffectiveW : 0));
    }
    readonly property real relY: {
        var my = monitorData?.y ?? 0;
        var base = (windowData?.at?.[1] ?? 0) - my;
        if (barPosition === "top") base -= barReserved;
        return Math.max(0, Math.min(1, monitorEffectiveH > 0 ? base / monitorEffectiveH : 0));
    }
    readonly property real relW: {
        var w = windowData?.size?.[0] ?? 0;
        return w > 200 && monitorEffectiveW > 0
            ? Math.max(0.05, Math.min(1, w / monitorEffectiveW))
            : 0.85;
    }
    readonly property real relH: {
        var h = windowData?.size?.[1] ?? 0;
        return h > 200 && monitorEffectiveH > 0
            ? Math.max(0.05, Math.min(1, h / monitorEffectiveH))
            : 0.85;
    }
    // Fill dimensions: if Overview.qml computed neighbor-aware sizes, use them.
    // Otherwise fall back to the window's own proportional size.
    readonly property real fillW: (modelData && modelData.fillW !== undefined) ? modelData.fillW : relW
    readonly property real fillH: (modelData && modelData.fillH !== undefined) ? modelData.fillH : relH

    function clampToCell(val, size, cellSize) {
        if (size >= cellSize) return 0;
        return Math.max(0, Math.min(val, cellSize - size));
    }

    readonly property real initX: {
        if (useOverridePosition && overrideX >= 0) return overrideX;
        var pos = Math.round(relX * effectiveCellW + availableWorkspaceWidth * gutter / 2);
        return Math.round(clampToCell(pos, targetWindowWidth, availableWorkspaceWidth) + xOffset);
    }
    readonly property real initY: {
        if (useOverridePosition && overrideY >= 0) return overrideY;
        var pos = Math.round(relY * effectiveCellH + availableWorkspaceHeight * gutter / 2);
        return Math.round(clampToCell(pos, targetWindowHeight, availableWorkspaceHeight) + yOffset);
    }

    readonly property real targetWindowWidth: Math.max(24, Math.round(fillW * effectiveCellW))
    readonly property real targetWindowHeight: Math.max(24, Math.round(fillH * effectiveCellH))
    readonly property bool compactMode: targetWindowHeight < 60 || targetWindowWidth < 60
    readonly property string iconPath: AppSearch.guessIcon(windowData?.class || "")
    readonly property int calculatedRadius: Styling.radius(-2)

    // Drag tracking
    property bool _isDragging: false
    // Entry animation: starts scaled down and fades in
    property bool _entered: false
    // Close animation: scales down and fades out before dispatching close
    property bool _closing: false
    Component.onCompleted: _entered = true

    signal dragStarted
    signal dragFinished(int targetWorkspace)
    signal windowClicked
    signal windowClosed

    x: initX
    y: initY
    width: targetWindowWidth
    height: targetWindowHeight
    z: atInitPosition ? 1 : 99999

    // Hover scale transform — slight enlargement on hover
    readonly property real hoverScale: !_isDragging && hovered && !_closing ? 1.03 : 1.0
    scale: _closing ? 0.3 : (_entered ? hoverScale : 0.85)

    Behavior on scale {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: _closing ? Config.animDuration * 0.4 : Config.animDuration * 0.6
            easing.type: _closing ? Easing.InBack : Easing.OutBack
        }
    }

    // Entry / close opacity
    opacity: _closing ? 0.0 : (_entered ? 1.0 : 0.0)
    Behavior on opacity {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: _closing ? Config.animDuration * 0.3 : Config.animDuration * 0.4
            easing.type: Easing.OutQuart
        }
    }

    // ═══════════════════════════════════════════════════
    // VISUAL: Clean dark card, no white background.
    // ScreencopyView is the primary visual; fallback is a
    // dark semi-transparent surface with the app icon.
    // ═══════════════════════════════════════════════════

    clip: true

    // Timer to reset override position
    Timer {
        id: resetOverrideTimer
        interval: 200
        onTriggered: { root.useOverridePosition = false; }
    }

    // Retry ScreencopyView capture periodically
    Timer {
        id: retryPreviewTimer
        interval: 600
        running: GlobalStates.overviewOpen && Config.performance.windowPreview
        repeat: true
        onTriggered: {
            if (!windowPreview.hasContent && root.toplevel) {
                windowPreview.captureSource = null;
                Qt.callLater(function() {
                    windowPreview.captureSource = Config.performance.windowPreview && GlobalStates.overviewOpen ? root.toplevel : null;
                });
            }
        }
    }

    onWindowDataChanged: {
        if (useOverridePosition)
            resetOverrideTimer.restart();
    }

    Behavior on x {
        enabled: Config.animDuration > 0 && !root.useOverridePosition
        NumberAnimation { duration: Config.animDuration; easing.type: Easing.OutQuart }
    }
    Behavior on y {
        enabled: Config.animDuration > 0 && !root.useOverridePosition
        NumberAnimation { duration: Config.animDuration; easing.type: Easing.OutQuart }
    }
    Behavior on width {
        enabled: Config.animDuration > 0
        NumberAnimation { duration: Config.animDuration; easing.type: Easing.OutQuart }
    }
    Behavior on height {
        enabled: Config.animDuration > 0
        NumberAnimation { duration: Config.animDuration; easing.type: Easing.OutQuart }
    }

    // ── Live window preview: render at source size, Scale to fill card ──
    ClippingRectangle {
        id: clipRect
        anchors.fill: parent
        radius: root.calculatedRadius
        antialiasing: true
        color: "transparent"
        border.color: "transparent"
        border.width: 0

        ScreencopyView {
            id: windowPreview
            // Size from hyprctl window data — always known, never zero
            width: Math.max(1, windowData?.size?.[0] || 640)
            height: Math.max(1, windowData?.size?.[1] || 480)
            captureSource: Config.performance.windowPreview && GlobalStates.overviewOpen ? root.toplevel : null
            live: GlobalStates.overviewOpen
            visible: Config.performance.windowPreview

            // Scale from source pixel size to card dimensions
            transform: Scale {
                origin.x: 0; origin.y: 0
                xScale: clipRect.width / windowPreview.width
                yScale: clipRect.height / windowPreview.height
            }
        }
    }

    // ── Dark fallback card (when no live preview) ──
    Rectangle {
        id: fallbackCard
        anchors.fill: parent
        radius: root.calculatedRadius
        color: Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 0.35)
        visible: !windowPreview.hasContent || !Config.performance.windowPreview

        // Subtle inner glow from border
        border.color: root.isSearchSelected ? Colors.tertiary
            : root.isSearchMatch ? Styling.srItem("overprimary")
            : hovered ? Qt.rgba(Colors.onSurface.r, Colors.onSurface.g, Colors.onSurface.b, 0.25)
            : Qt.rgba(Colors.onSurface.r, Colors.onSurface.g, Colors.onSurface.b, 0.10)
        border.width: root.isSearchSelected ? 2 : root.isSearchMatch ? 2 : 1

        Behavior on border.color {
            enabled: Config.animDuration > 0
            ColorAnimation { duration: Config.animDuration / 2 }
        }

        Behavior on color {
            enabled: Config.animDuration > 0
            ColorAnimation { duration: Config.animDuration / 2 }
        }
    }

    // ── App icon centered on fallback ──
    Image {
        mipmap: true
        id: windowIcon
        readonly property real iconSize: Math.round(Math.min(root.targetWindowWidth, root.targetWindowHeight) * (root.compactMode ? 0.55 : 0.30))
        anchors.centerIn: parent
        width: iconSize
        height: iconSize
        source: Quickshell.iconPath(root.iconPath, "image-missing")
        sourceSize: Qt.size(iconSize, iconSize)
        asynchronous: true
        visible: !windowPreview.hasContent || !Config.performance.windowPreview
        opacity: 0.7
        z: 2
    }

    // ── Hover / selection border overlay ──
    Rectangle {
        id: borderOverlay
        anchors.fill: parent
        radius: root.calculatedRadius
        color: "transparent"
        border.color: root.isSearchSelected ? Colors.tertiary
            : root.isSearchMatch ? Styling.srItem("overprimary")
            : hovered ? Styling.srItem("overprimary")
            : "transparent"
        border.width: root.isSearchSelected ? 3 : root.isSearchMatch ? 2 : (hovered ? 2 : 0)
        z: 3

        Behavior on border.color {
            enabled: Config.animDuration > 0
            ColorAnimation { duration: Config.animDuration / 2 }
        }

        Behavior on border.width {
            enabled: Config.animDuration > 0
            NumberAnimation { duration: Config.animDuration / 2 }
        }
    }

    // ── Hover tint overlay ──
    Rectangle {
        anchors.fill: parent
        radius: root.calculatedRadius
        color: pressed ? Qt.rgba(1, 1, 1, 0.10) : hovered ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
        z: 1
        Behavior on color {
            enabled: Config.animDuration > 0
            ColorAnimation { duration: Config.animDuration / 2 }
        }
    }

    // ── Small app icon (corner, when preview is showing) ──
    Image {
        mipmap: true
        visible: windowPreview.hasContent && !root.compactMode && Config.performance.windowPreview
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 3
        width: 14
        height: 14
        source: Quickshell.iconPath(root.iconPath, "image-missing")
        sourceSize: Qt.size(14, 14)
        asynchronous: true
        opacity: 0.6
        z: 4
    }

    // ── XWayland indicator ──
    Rectangle {
        visible: root.windowData?.xwayland || false
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 2
        width: 5
        height: 5
        radius: 3
        color: Colors.error
        z: 4
    }

    // ── Search match glow ──
    Rectangle {
        visible: root.isSearchSelected && !root._isDragging
        anchors.fill: parent
        anchors.margins: -3
        radius: root.calculatedRadius + 3
        color: "transparent"
        border.color: Colors.tertiary
        border.width: 2
        opacity: 0.5
        z: -1
    }

    Drag.active: root._isDragging
    Drag.hotSpot.x: width / 2
    Drag.hotSpot.y: height / 2

    // Direct hyprctl for workspace switching
    Process {
        id: wsProcess
    }

    // Hold timer: quick release = click (switch ws), timer fires = drag
    Timer {
        id: holdTimer
        interval: 180
        onTriggered: {
            if (root.pressed && !root._isDragging) {
                root._isDragging = true;
                root.dragStarted();
            }
        }
    }

    // Track which button initiated the interaction
    property int _interactButton: Qt.NoButton

    MouseArea {
        id: dragArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        drag.target: parent

        onEntered: { root.hovered = true; }
        onExited: root.hovered = false

        onPressed: mouse => {
            root.pressed = true;
            root._interactButton = mouse.button;
            if (mouse.button === Qt.LeftButton) {
                holdTimer.start();
            } else if (mouse.button === Qt.RightButton) {
                root._isDragging = true;
                root.dragStarted();
            }
        }

        onPositionChanged: {
            // Qt Drag handles movement automatically via drag.target
        }

        onReleased: mouse => {
            root.pressed = false;
            root.Drag.active = false;

            var ov = root.overviewRootRef;
            var targetWs = -1;

            if (ov && ov.columns && ov.rows) {
                var mx = root.x + mouse.x;
                var my = root.y + mouse.y;
                var cw = root.availableWorkspaceWidth + ov.workspacePadding + ov.workspaceSpacing;
                var ch = root.availableWorkspaceHeight + ov.workspacePadding + ov.workspaceSpacing;
                var colIdx = Math.floor((mx - ov.workspacePadding / 2) / cw);
                var rowIdx = Math.floor((my - ov.workspacePadding / 2) / ch);
                if (colIdx >= 0 && colIdx < ov.columns && rowIdx >= 0 && rowIdx < ov.rows)
                    targetWs = rowIdx * ov.columns + colIdx + 1;
            }
            if (targetWs <= 0 && ov) targetWs = ov.draggingTargetWorkspace;
            if (targetWs <= 0) targetWs = windowData?.workspace?.id || -1;

            if (mouse.button === Qt.LeftButton && root._isDragging) {
                // Drag finished — move this window to target workspace
                root._isDragging = false;
                if (ov) ov.draggingTargetWorkspace = -1;
                root.dragFinished(targetWs);
            } else if (mouse.button === Qt.RightButton && root._isDragging) {
                // Right drag finished — move ALL windows from source to target
                root._isDragging = false;
                if (ov) ov.draggingTargetWorkspace = -1;
                var srcWs = windowData?.workspace?.id || -1;
                if (targetWs > 0 && targetWs !== srcWs) {
                    var allWindows = ov.filteredWindows || [];
                    for (var i = 0; i < allWindows.length; i++) {
                        var w = allWindows[i];
                        if (w && w.windowData && w.windowData.workspace && w.windowData.workspace.id === srcWs && w.windowData.address) {
                            AxctlService.dispatch("movetoworkspacesilent " + targetWs + ",address:" + w.windowData.address);
                        }
                    }
                }
                // Refresh overview after mass move
                if (ov && ov.refreshOverview) Qt.callLater(ov.refreshOverview);
            }

            root.x = Qt.binding(function() { return root.initX; });
            root.y = Qt.binding(function() { return root.initY; });
            root._interactButton = Qt.NoButton;
        }

        onCanceled: {
            root.pressed = false;
            root._isDragging = false;
            root.Drag.active = false;
            holdTimer.stop();
            root.x = Qt.binding(function() { return root.initX; });
            root.y = Qt.binding(function() { return root.initY; });
            root._interactButton = Qt.NoButton;
        }

        onClicked: mouse => {
            if (!root.windowData) return;

            if (mouse.button === Qt.LeftButton && !root._isDragging) {
                holdTimer.stop();
                // Click → switch to this window's workspace
                var wsId = windowData?.workspace?.id;
                if (wsId && wsId > 0) {
                    wsProcess.command = ["hyprctl", "dispatch", "workspace", String(wsId)];
                    wsProcess.running = true;
                    var ov = root.overviewRootRef;
                    if (ov && ov.refreshOverview) Qt.callLater(ov.refreshOverview);
                }
            } else if (mouse.button === Qt.MiddleButton) {
                root._closing = true;
                Qt.callLater(function() { root.windowClosed(); });
            }
        }
    }

    // Tooltip
    Rectangle {
        visible: dragArea.containsMouse && !root._isDragging && root.windowData
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
