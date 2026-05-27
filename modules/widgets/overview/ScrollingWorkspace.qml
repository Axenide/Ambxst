import QtQuick

// pragma ComponentBehavior: Bound

import QtQuick.Controls
import QtQuick.Effects
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

    required property int workspaceId
    required property real workspaceWidth
    required property real workspaceHeight
    required property real workspacePadding
    property real scale_: 0  // legacy, no longer used (uniformScale is computed from monitor+viewport)
    required property int monitorId
    required property var monitorData
    required property string barPosition
    required property int barReserved
    required property var windowList
    required property bool isActive
    required property color activeBorderColor
    property string focusedWindowAddress: ""
    property string searchQuery: ""
    property int draggingFromWorkspace: -1
    property int draggingTargetWorkspace: -1
    property Item dragOverlay: null
    property Item overviewRoot: null

    // Callbacks for search matching (set by parent)
    property var checkWindowMatched: function (addr) {
        return false;
    }
    property var checkWindowSelected: function (addr) {
        return false;
    }

    implicitWidth: workspaceWidth
    implicitHeight: workspaceHeight

    // The viewport (monitor area) is the center third of the workspace
    readonly property real viewportWidth: workspaceWidth / 3
    readonly property real viewportOffset: viewportWidth  // Offset to center third

    // Filter windows for this workspace and monitor.
    // Defensive: if workspace or monitor metadata is missing, still show the window.
    readonly property var workspaceWindows: {
        return windowList.filter(win => {
            if (!win) return false;
            const wsOk = win.workspace?.id === workspaceId || win.workspace?.id === undefined;
            const monOk = monitorId < 0 || win.monitor === undefined || win.monitor === monitorId;
            return wsOk && monOk;
        });
    }

    // Monitor effective dimensions for bounds calculation
    readonly property real monitorEffW: {
        const md = root.monitorData;
        if (!md) return 1920;
        const ro = (md.transform % 2 === 1);
        const mw = ro ? (md.height || 1080) : (md.width || 1920);
        return mw > 0 ? mw : 1920;
    }
    readonly property real monitorEffH: {
        const md = root.monitorData;
        if (!md) return 1080;
        const ro = (md.transform % 2 === 1);
        const mh = ro ? (md.width || 1920) : (md.height || 1080);
        return mh > 0 ? mh : 1080;
    }

    // ── Pure proportion-based content bounds ──
    readonly property var contentBounds: {
        if (workspaceWindows.length === 0) {
            return { minX: 0, maxX: 0, hasOverflow: false };
        }

        const gutter = 0.02;
        const evpw = root.viewportWidth * (1 - gutter);
        let minX = Infinity, maxX = -Infinity;

        for (const win of workspaceWindows) {
            const mx = (monitorData && monitorData.x !== undefined ? monitorData.x : 0) || 0;
            let baseX = ((win && win.at && win.at[0] !== undefined ? win.at[0] : 0) || 0) - mx;
            if (barPosition === "left") baseX -= barReserved;
            const relX = Math.max(0, Math.min(1, baseX / root.monitorEffW));
            const wSize = (win && win.size && win.size[0] !== undefined ? win.size[0] : 0) || 0;
            const relW = wSize > 200 ? Math.max(0.05, Math.min(1, wSize / root.monitorEffW)) : 0.85;
            const scaledX = relX * evpw + root.viewportWidth * gutter / 2 + root.viewportOffset;
            const winWidth = relW * evpw;

            minX = Math.min(minX, scaledX);
            maxX = Math.max(maxX, scaledX + winWidth);
        }

        const hasOverflow = minX < -viewportWidth || maxX > (viewportWidth * 2);

        return {
            minX,
            maxX,
            hasOverflow
        };
    }

    // Calculate scroll limits based on content
    // We want to allow scrolling so that all content can be brought into view
    readonly property real maxHorizontalScroll: {
        if (!contentBounds.hasOverflow)
            return 0;
        // If content extends to the right (maxX > viewportWidth), we need negative scroll to see it
        // maxX - viewportWidth is how much we need to scroll left (negative offset)
        return Math.max(0, -contentBounds.minX);
    }
    readonly property real minHorizontalScroll: {
        if (!contentBounds.hasOverflow)
            return 0;
        // If content extends to the left (minX < 0), we need positive scroll to see it
        return Math.min(0, viewportWidth - contentBounds.maxX);
    }

    // Horizontal scroll state
    property real horizontalScrollOffset: 0
    property bool isScrollDragging: false  // Track if any right-click drag is active
    property bool isWheelScrolling: false  // Track if wheel is being used

    // Timer to reset wheel scrolling state after a brief pause
    Timer {
        id: wheelScrollTimer
        interval: 150
        onTriggered: root.isWheelScrolling = false
    }

    // Reset scroll when windows change (added, removed, or moved)
    onWorkspaceWindowsChanged: resetScroll()
    onContentBoundsChanged: {
        // If no overflow, ensure we're at center (0)
        if (!contentBounds.hasOverflow && horizontalScrollOffset !== 0) {
            horizontalScrollOffset = 0;
        }
    }

    function resetScroll() {
        horizontalScrollOffset = 0;
    }

    Behavior on horizontalScrollOffset {
        enabled: Anim.animationsEnabled && !root.isScrollDragging && !root.isWheelScrolling
        NumberAnimation {
            duration: Anim.spatialFast
            easing.type: Anim.easing("spatial").type
            easing.bezierCurve: Anim.easing("spatial").bezierCurve
        }
    }

    function clampHorizontalScroll(value) {
        if (!contentBounds.hasOverflow)
            return 0;
        return Math.max(minHorizontalScroll, Math.min(maxHorizontalScroll, value));
    }

    // Main workspace container
    Item {
        id: workspaceContainer
        anchors.fill: parent

        // Background layer (clipped)
        Item {
            id: backgroundLayer
            anchors.fill: parent
            clip: true

            // Wallpaper background
            TintedWallpaper {
                id: workspaceWallpaper
                anchors.fill: parent
                radius: Styling.radius(1)
                tintEnabled: GlobalStates.wallpaperManager ? GlobalStates.wallpaperManager.tintEnabled : false

                property string lockscreenFramePath: {
                    if (!GlobalStates.wallpaperManager)
                        return "";
                    return GlobalStates.wallpaperManager.getLockscreenFramePath(GlobalStates.wallpaperManager.currentWallpaper);
                }
                source: lockscreenFramePath ? "file://" + lockscreenFramePath : ""
            }

            // Semi-transparent overlay
            Rectangle {
                anchors.fill: parent
                radius: Styling.radius(1)
                color: Colors.background
                opacity: 0.3
            }

            // Workspace number label
            Text {
                anchors.centerIn: parent
                text: String(root.workspaceId)
                font.family: Config.theme.font
                font.pixelSize: Math.max(24, Math.round(workspaceHeight * 0.15))
                font.bold: true
                color: Colors.onSurface
                opacity: 0.5
                z: 5
            }
        }

        // Border indicator for drag target
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            radius: Styling.radius(1)
            border.width: root.draggingTargetWorkspace === root.workspaceId && root.draggingFromWorkspace !== root.workspaceId ? 2 : 0
            border.color: Colors.outline
            z: 100
        }

        // Windows container
        Item {
            id: windowsContainer
            anchors.fill: parent
            anchors.margins: root.workspacePadding
            clip: true

            // Horizontal scroll handler - right-click drag
            MouseArea {
                id: scrollArea
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                propagateComposedEvents: true

                property real dragStartX: 0
                property real scrollStartOffset: 0

                onPressed: mouse => {
                    if (mouse.button === Qt.RightButton && root.contentBounds.hasOverflow) {
                        dragStartX = mouse.x;
                        scrollStartOffset = root.horizontalScrollOffset;
                        root.isScrollDragging = true;
                        mouse.accepted = true;
                    } else {
                        mouse.accepted = false;
                    }
                }

                onPositionChanged: mouse => {
                    if (root.isScrollDragging && (mouse.buttons & Qt.RightButton)) {
                        const delta = mouse.x - dragStartX;
                        root.horizontalScrollOffset = root.clampHorizontalScroll(scrollStartOffset + delta);
                    }
                }

                onReleased: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        root.isScrollDragging = false;
                    }
                }

                onCanceled: {
                    root.isScrollDragging = false;
                }

                // Pass through clicks that we don't handle
                onClicked: mouse => mouse.accepted = false
            }

            // Wheel handler for Shift+scroll (horizontal scrolling)
            WheelHandler {
                id: wheelHandler
                acceptedModifiers: Qt.ShiftModifier
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    if (!root.contentBounds.hasOverflow)
                        return;
                    // Mark as wheel scrolling to disable animation
                    root.isWheelScrolling = true;
                    wheelScrollTimer.restart();
                    // Use vertical scroll delta for horizontal movement
                    const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                    root.horizontalScrollOffset = root.clampHorizontalScroll(root.horizontalScrollOffset + delta);
                    event.accepted = true;
                }
            }

            // Double-click on empty space to switch workspace
            TapHandler {
                acceptedButtons: Qt.LeftButton
                onDoubleTapped: {
                    if (root.overviewRoot && root.overviewRoot.wsProcess) {
                        root.overviewRoot.wsProcess.command = ["hyprctl", "dispatch", "workspace", String(root.workspaceId)];
                        root.overviewRoot.wsProcess.running = true;
                    }
                    Visibilities.setActiveModule("", true);
                }
            }

            Repeater {
                model: root.workspaceWindows

                delegate: Item {
                    id: windowDelegate
                    required property var modelData

                    readonly property var windowData: modelData
                    readonly property var toplevel: {
                        const toplevels = ToplevelManager.toplevels.values;
                        const cls = windowData.class || "";
                        if (!cls) return null;
                        const candidates = toplevels.filter(t => t.appId === cls);
                        if (candidates.length === 0) return null;
                        // Try exact title match first
                        const titleMatch = candidates.find(t => t.title === (windowData.title || ""));
                        if (titleMatch) return titleMatch;
                        // Try partial title match
                        const wt = (windowData.title || "").toLowerCase();
                        const partial = candidates.find(t => { const tt = (t.title || "").toLowerCase(); return wt.includes(tt) || tt.includes(wt); });
                        if (partial) return partial;
                        // Return null to avoid same-class windows sharing a toplevel
                        return null;
                    }

                    // Override position tracking for immediate visual update
                    property real overrideBaseX: -1
                    property real overrideBaseY: -1
                    property bool useOverridePosition: false

                    readonly property real viewportWidth: root.viewportWidth
                    readonly property real viewportHeight: root.workspaceHeight - root.workspacePadding * 2

                    // ── Pure proportion-based coordinates (0.0..1.0) ──
                    readonly property real gutter: 0.02
                    readonly property real effectiveVpW: viewportWidth * (1 - gutter)
                    readonly property real effectiveVpH: viewportHeight * (1 - gutter)

                    readonly property real relX: {
                        const mx = monitorData?.x ?? 0;
                        let base = (windowData?.at?.[0] ?? 0) - mx;
                        if (barPosition === "left") base -= barReserved;
                        return Math.max(0, Math.min(1, root.monitorEffW > 0 ? base / root.monitorEffW : 0));
                    }
                    readonly property real relY: {
                        const my = monitorData?.y ?? 0;
                        let base = (windowData?.at?.[1] ?? 0) - my;
                        if (barPosition === "top") base -= barReserved;
                        return Math.max(0, Math.min(1, root.monitorEffH > 0 ? base / root.monitorEffH : 0));
                    }
                    readonly property real relW: {
                        var w = windowData?.size?.[0] ?? 0;
                        return w > 200 && root.monitorEffW > 0
                            ? Math.max(0.05, Math.min(1, w / root.monitorEffW))
                            : 0.85;
                    }
                    readonly property real relH: {
                        var h = windowData?.size?.[1] ?? 0;
                        return h > 200 && root.monitorEffH > 0
                            ? Math.max(0.05, Math.min(1, h / root.monitorEffH))
                            : 0.85;
                    }
                    // Fill dimensions: extend to neighbor without overlapping.
                    // Must match the same coordinate system as relX/relY
                    // (bar-adjusted, rotation-aware) for consistency.
                    readonly property real fillW: {
                        var neighbors = root.workspaceWindows;
                        if (!neighbors || neighbors.length <= 1) return relW;
                        var mx = monitorData?.x ?? 0;
                        var my = monitorData?.y ?? 0;
                        var ax = (windowData?.at?.[0] ?? 0) - mx;
                        var ay = (windowData?.at?.[1] ?? 0) - my;
                        if (barPosition === "left") ax -= barReserved;
                        if (barPosition === "top") ay -= barReserved;
                        var aw = windowData?.size?.[0] ?? root.monitorEffW;
                        var ah = windowData?.size?.[1] ?? root.monitorEffH;
                        var limit = root.monitorEffW - (barPosition === "left" || barPosition === "right" ? barReserved : 0);
                        for (var n = 0; n < neighbors.length; n++) {
                            var nb = neighbors[n];
                            if (!nb || nb.address === (windowData?.address ?? "")) continue;
                            var bx = (nb.at?.[0] ?? 0) - mx;
                            var by = (nb.at?.[1] ?? 0) - my;
                            if (barPosition === "left") bx -= barReserved;
                            if (barPosition === "top") by -= barReserved;
                            var bw = nb.size?.[0] ?? root.monitorEffW;
                            var bh = nb.size?.[1] ?? root.monitorEffH;
                            var nbContained = (bx >= ax && by >= ay && bx + bw <= ax + aw && by + bh <= ay + ah);
                            if (!nbContained && bx > ax && by < ay + ah && by + bh > ay)
                                limit = Math.min(limit, bx);
                        }
                        var effW = root.monitorEffW - (barPosition === "left" || barPosition === "right" ? barReserved : 0);
                        var neighborW = effW > 0 ? (limit - ax) / effW : 1;
                        return Math.max(relW, Math.max(0.05, Math.min(1, neighborW)));
                    }
                    readonly property real fillH: {
                        var neighbors = root.workspaceWindows;
                        if (!neighbors || neighbors.length <= 1) return relH;
                        var mx = monitorData?.x ?? 0;
                        var my = monitorData?.y ?? 0;
                        var ax = (windowData?.at?.[0] ?? 0) - mx;
                        var ay = (windowData?.at?.[1] ?? 0) - my;
                        if (barPosition === "left") ax -= barReserved;
                        if (barPosition === "top") ay -= barReserved;
                        var aw = windowData?.size?.[0] ?? root.monitorEffW;
                        var ah = windowData?.size?.[1] ?? root.monitorEffH;
                        var limit = root.monitorEffH - (barPosition === "top" || barPosition === "bottom" ? barReserved : 0);
                        for (var n = 0; n < neighbors.length; n++) {
                            var nb = neighbors[n];
                            if (!nb || nb.address === (windowData?.address ?? "")) continue;
                            var bx = (nb.at?.[0] ?? 0) - mx;
                            var by = (nb.at?.[1] ?? 0) - my;
                            if (barPosition === "left") bx -= barReserved;
                            if (barPosition === "top") by -= barReserved;
                            var bw = nb.size?.[0] ?? root.monitorEffW;
                            var bh = nb.size?.[1] ?? root.monitorEffH;
                            var nbContained = (bx >= ax && by >= ay && bx + bw <= ax + aw && by + bh <= ay + ah);
                            if (!nbContained && by > ay && bx < ax + aw && bx + bw > ax)
                                limit = Math.min(limit, by);
                        }
                        var effH = root.monitorEffH - (barPosition === "top" || barPosition === "bottom" ? barReserved : 0);
                        var neighborH = effH > 0 ? (limit - ay) / effH : 1;
                        return Math.max(relH, Math.max(0.05, Math.min(1, neighborH)));
                    }

                    readonly property real baseX: {
                        if (useOverridePosition && overrideBaseX >= 0) return overrideBaseX;
                        return Math.round(relX * effectiveVpW + viewportWidth * gutter / 2 + root.viewportOffset + root.horizontalScrollOffset);
                    }
                    readonly property real baseY: {
                        if (useOverridePosition && overrideBaseY >= 0) return overrideBaseY;
                        return Math.round(relY * effectiveVpH + viewportHeight * gutter / 2);
                    }

                    readonly property real targetWidth: Math.max(24, Math.round(fillW * effectiveVpW))
                    readonly property real targetHeight: Math.max(24, Math.round(fillH * effectiveVpH))
                    readonly property bool compactMode: targetHeight < 60 || targetWidth < 60
                    readonly property string iconPath: AppSearch.guessIcon((windowData && windowData.class !== undefined ? windowData.class : "") || "")
                    readonly property int calculatedRadius: Styling.radius(-2)
                    readonly property bool isMatched: root.checkWindowMatched((windowData && windowData.address !== undefined ? windowData.address : undefined))
                    readonly property bool isSelected: root.checkWindowSelected((windowData && windowData.address !== undefined ? windowData.address : undefined))

                    x: baseX
                    y: baseY
                    width: targetWidth
                    height: targetHeight
                    z: dragging ? 1000 : 1

                    property bool hovered: false
                    property bool dragging: false
                    property real initX: baseX
                    property real initY: baseY
                    property Item originalParent: null
                    property point pressPos: Qt.point(0, 0)
                    readonly property real dragThreshold: 5

                    // Entry / hover / close animations
                    property bool _entered: false
                    property bool _closing: false
                    Component.onCompleted: _entered = true

                    readonly property real hoverScale: !dragging && hovered && !_closing ? 1.03 : 1.0
                    scale: _closing ? 0.3 : (_entered ? hoverScale : 0.85)

                    Behavior on scale {
                        enabled: Anim.animationsEnabled
                        NumberAnimation {
                            property var _ease: _closing ? Anim.easing("emphasized", "exit") : Anim.easing("emphasized")
                            duration: _closing ? Anim.standardSmall : Anim.standardNormal
                            easing.type: _ease.type
                            easing.bezierCurve: _ease.bezierCurve
                        }
                    }

                    opacity: _closing ? 0.0 : (_entered ? 1.0 : 0.0)
                    Behavior on opacity {
                        enabled: Anim.animationsEnabled
                        NumberAnimation {
                            duration: _closing ? Anim.standardSmall : Anim.standardNormal
                            easing.type: Anim.easing("standard").type
                            easing.bezierCurve: Anim.easing("standard").bezierCurve
                        }
                    }

                    // Timer to reset override position after AxctlService update
                    Timer {
                        id: resetOverrideTimer
                        interval: 200
                        onTriggered: {
                            windowDelegate.useOverridePosition = false;
                        }
                    }

                    // Watch for windowData changes
                    onWindowDataChanged: {
                        if (useOverridePosition) {
                            resetOverrideTimer.restart();
                        }
                    }

                    // ═══════════════════════════════════════════════════
                    // VISUAL: Clean dark card, no white background
                    // ═══════════════════════════════════════════════════

                    // ── Live window preview: render at source size, Scale to fill card ──
                    ClippingRectangle {
                        id: swClipRect
                        anchors.fill: parent
                        radius: windowDelegate.calculatedRadius
                        antialiasing: true
                        color: "transparent"
                        border.color: "transparent"
                        border.width: 0

                        ScreencopyView {
                            id: windowPreview
                            width: Math.max(1, (windowData && windowData.size && windowData.size[0] !== undefined ? windowData.size[0] : 0) || 640)
                            height: Math.max(1, (windowData && windowData.size && windowData.size[1] !== undefined ? windowData.size[1] : 0) || 480)
                            captureSource: Config.performance.windowPreview && GlobalStates.overviewOpen ? windowDelegate.toplevel : null
                            live: GlobalStates.overviewOpen
                            visible: Config.performance.windowPreview

                            transform: Scale {
                                origin.x: 0; origin.y: 0
                                xScale: swClipRect.width / windowPreview.width
                                yScale: swClipRect.height / windowPreview.height
                            }
                        }
                    }

                    // ── Dark fallback card ──
                    Rectangle {
                        id: fallbackCard
                        anchors.fill: parent
                        radius: windowDelegate.calculatedRadius
                        color: Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 0.35)
                        visible: !windowPreview.hasContent || !Config.performance.windowPreview
                        border.color: windowDelegate.isSelected ? Colors.tertiary
                            : windowDelegate.isMatched ? Styling.srItem("overprimary")
                            : windowDelegate.hovered ? Qt.rgba(Colors.onSurface.r, Colors.onSurface.g, Colors.onSurface.b, 0.25)
                            : Qt.rgba(Colors.onSurface.r, Colors.onSurface.g, Colors.onSurface.b, 0.10)
                        border.width: windowDelegate.isSelected ? 2 : windowDelegate.isMatched ? 2 : 1
                        Behavior on border.color {
                            enabled: Anim.animationsEnabled
                            ColorAnimation { duration: Anim.standardSmall }
                        }
                    }

                    // ── App icon ──
                    Image {
                        mipmap: true
                        id: windowIcon
                        readonly property real iconSize: Math.round(Math.min(windowDelegate.targetWidth, windowDelegate.targetHeight) * (windowDelegate.compactMode ? 0.55 : 0.30))
                        anchors.centerIn: parent
                        width: iconSize
                        height: iconSize
                        source: Quickshell.iconPath(windowDelegate.iconPath, "image-missing")
                        sourceSize: Qt.size(iconSize, iconSize)
                        asynchronous: true
                        visible: !windowPreview.hasContent || !Config.performance.windowPreview
                        opacity: 0.7
                        z: 2
                    }

                    // ── Hover / selection border ──
                    Rectangle {
                        id: borderOverlay
                        anchors.fill: parent
                        radius: windowDelegate.calculatedRadius
                        color: "transparent"
                        border.color: windowDelegate.isSelected ? Colors.tertiary
                            : windowDelegate.isMatched ? Styling.srItem("overprimary")
                            : windowDelegate.hovered ? Styling.srItem("overprimary")
                            : "transparent"
                        border.width: windowDelegate.isSelected ? 3 : windowDelegate.isMatched ? 2 : (windowDelegate.hovered ? 2 : 0)
                        z: 3
                        Behavior on border.color {
                            enabled: Anim.animationsEnabled
                            ColorAnimation { duration: Anim.standardSmall }
                        }
                        Behavior on border.width {
                            enabled: Anim.animationsEnabled
                            NumberAnimation {
                                duration: Anim.standardSmall
                                easing.type: Anim.easing("standard").type
                                easing.bezierCurve: Anim.easing("standard").bezierCurve
                            }
                        }
                    }

                    // ── Hover tint ──
                    Rectangle {
                        anchors.fill: parent
                        radius: windowDelegate.calculatedRadius
                        color: windowDelegate.dragging ? Qt.rgba(1, 1, 1, 0.10) : windowDelegate.hovered ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
                        z: 1
                        Behavior on color {
                            enabled: Anim.animationsEnabled
                            ColorAnimation { duration: Anim.standardSmall }
                        }
                    }

                    // ── Corner icon (when preview active) ──
                    Image {
                        mipmap: true
                        visible: windowPreview.hasContent && !windowDelegate.compactMode && Config.performance.windowPreview
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        anchors.margins: 3
                        width: 14
                        height: 14
                        source: Quickshell.iconPath(windowDelegate.iconPath, "image-missing")
                        sourceSize: Qt.size(14, 14)
                        asynchronous: true
                        opacity: 0.6
                        z: 4
                    }

                    // ── XWayland indicator ──
                    Rectangle {
                        visible: (windowDelegate.windowData && windowDelegate.windowData.xwayland !== undefined ? windowDelegate.windowData.xwayland : false) || false
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 2
                        width: 5
                        height: 5
                        radius: 3
                        color: Colors.error
                        z: 4
                    }

                    // ═══════════════════════════════════════════════════════
                    // RIGHT-CLICK DRAG TO MOVE WINDOW BETWEEN WORKSPACES
                    // Left clicks pass through to workspace cells below.
                    // ═══════════════════════════════════════════════════════
                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.RightButton

                        onEntered: windowDelegate.hovered = true
                        onExited: windowDelegate.hovered = false

                        onPressed: mouse => {
                            if (mouse.button !== Qt.RightButton) return;
                            windowDelegate.pressPos = Qt.point(mouse.x, mouse.y);
                            windowDelegate.initX = windowDelegate.x;
                            windowDelegate.initY = windowDelegate.y;
                        }

                        onPositionChanged: mouse => {
                            if (!(mouse.buttons & Qt.RightButton))
                                return;

                            if (!windowDelegate.dragging) {
                                const dx = mouse.x - windowDelegate.pressPos.x;
                                const dy = mouse.y - windowDelegate.pressPos.y;
                                const distance = Math.sqrt(dx * dx + dy * dy);
                                if (distance > windowDelegate.dragThreshold) {
                                    windowDelegate.dragging = true;
                                    root.draggingFromWorkspace = root.workspaceId;
                                    // Reparent to drag overlay
                                    if (root.dragOverlay) {
                                        windowDelegate.originalParent = windowDelegate.parent;
                                        const globalPos = windowDelegate.mapToItem(root.dragOverlay, 0, 0);
                                        windowDelegate.parent = root.dragOverlay;
                                        windowDelegate.x = globalPos.x;
                                        windowDelegate.y = globalPos.y;
                                    }
                                } else {
                                    return;
                                }
                            }

                            // Update target workspace while dragging
                            if (root.overviewRoot && root.overviewRoot.getWorkspaceAtY) {
                                const globalPos = dragArea.mapToItem(null, mouse.x, mouse.y);
                                const targetWs = root.overviewRoot.getWorkspaceAtY(globalPos.y);
                                root.draggingTargetWorkspace = (targetWs !== -1 && targetWs !== root.workspaceId) ? targetWs : -1;
                            }
                        }

                        onReleased: mouse => {
                            if (mouse.button !== Qt.RightButton) return;

                            if (windowDelegate.dragging) {
                                windowDelegate.dragging = false;
                                const targetWs = root.draggingTargetWorkspace !== -1 ? root.draggingTargetWorkspace : root.workspaceId;

                                if (targetWs !== root.workspaceId && windowDelegate.windowData) {
                                    AxctlService.dispatch(`movetoworkspacesilent ${targetWs}, address:${windowDelegate.windowData.address || ""}`);
                                    Qt.callLater(function() { CompositorData.refreshFromHyprctl(); });
                                }

                                // Restore original parent and re-bind position.
                                // Setting x/y directly breaks the baseX/baseY bindings;
                                // Qt.binding restores them so the thumbnail follows window data.
                                if (windowDelegate.originalParent) {
                                    windowDelegate.parent = windowDelegate.originalParent;
                                    windowDelegate.originalParent = null;
                                }
                                windowDelegate.x = Qt.binding(function() { return windowDelegate.baseX; });
                                windowDelegate.y = Qt.binding(function() { return windowDelegate.baseY; });

                                root.draggingFromWorkspace = -1;
                                root.draggingTargetWorkspace = -1;
                            }
                        }
                    }

                    // Tooltip
                    Rectangle {
                        visible: dragArea.containsMouse && !windowDelegate.dragging && windowDelegate.windowData
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
                            text: `${(windowDelegate.windowData && windowDelegate.windowData.title !== undefined ? windowDelegate.windowData.title : "") || ""}\n[${(windowDelegate.windowData && windowDelegate.windowData.class !== undefined ? windowDelegate.windowData.class : "") || ""}]${(windowDelegate.windowData && windowDelegate.windowData.xwayland !== undefined ? windowDelegate.windowData.xwayland : false) ? " [XWayland]" : ""}`
                            font.family: Config.theme.font
                            font.pixelSize: 10
                            color: Colors.inverseOnSurface
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }
        }
    }
}
