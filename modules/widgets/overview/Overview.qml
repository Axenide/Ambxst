import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Wayland
import qs.modules.globals
import qs.modules.theme
import qs.modules.components
import qs.modules.bar.workspaces
import qs.modules.services
import qs.config

Item {
    id: overviewRoot
    anchors.fill: parent

    Process { id: wsSwitchProcess }

    // ── Window data from hyprctl ──
    property var rawWindows: []
    property var rawMonitors: []

    Process {
        id: clientProcess
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var raw = JSON.parse(text);
                    if (Array.isArray(raw)) overviewRoot.rawWindows = raw;
                } catch (e) {}
            }
        }
    }

    Process {
        id: monProcess
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var raw = JSON.parse(text);
                    if (Array.isArray(raw)) overviewRoot.rawMonitors = raw;
                } catch (e) {}
            }
        }
    }

    // When rawWindows updates, tell the mapper to find unmatched windows
    onRawWindowsChanged: {
        if (GlobalStates.overviewOpen && WlrToplevelMapper) {
            WlrToplevelMapper.updateUnmatched(rawWindows);
            WlrToplevelMapper.captureAllUnmatched();
        }
    }

    Timer {
        id: refreshTimer
        interval: 600
        running: GlobalStates.overviewOpen
        repeat: true
        onTriggered: {
            if (!clientProcess.running) clientProcess.running = true;
            if (!monProcess.running) monProcess.running = true;
        }
    }

    // Timer to wait for axctl to process the move before refreshing window data
    Timer {
        id: delayedRefreshTimer
        interval: 200
        onTriggered: {
            if (!clientProcess.running) clientProcess.running = true;
            if (!monProcess.running) monProcess.running = true;
        }
    }

    // ── Config ──
    readonly property int rows: Config.overview.rows
    readonly property int columns: Config.overview.columns
    readonly property int workspacesShown: rows * columns
    readonly property real workspaceSpacing: Config.overview.workspaceSpacing
    readonly property real workspacePadding: 8
    readonly property color activeBorderColor: Styling.srItem("overprimary")
    property var currentScreen: null

    // Monitor lookup by ID
    readonly property var monMap: {
        var m = {};
        var list = overviewRoot.rawMonitors;
        for (var i = 0; i < list.length; i++) m[list[i].id] = list[i];
        return m;
    }

    // ── Cell size — 16:9 ──
    readonly property real _spacingW: (columns - 1) * workspaceSpacing + workspacePadding * 2
    readonly property real _spacingH: (rows - 1) * workspaceSpacing + workspacePadding * 2
    readonly property real _cellWfromW: Math.max(80, Math.round((width - _spacingW) / columns))
    readonly property real _cellHfromW: Math.max(60, Math.round(_cellWfromW * 9 / 16))
    readonly property real _cellHfromH: Math.max(60, Math.round((height - _spacingH) / rows))
    readonly property real _cellWfromH: Math.max(80, Math.round(_cellHfromH * 16 / 9))
    readonly property bool _useWbase: (rows * _cellHfromW + _spacingH) <= height
    readonly property real wsCellW: _useWbase ? _cellWfromW : _cellWfromH
    readonly property real wsCellH: _useWbase ? _cellHfromW : _cellHfromH
    readonly property real gridTotalW: columns * wsCellW + _spacingW
    readonly property real gridTotalH: rows * wsCellH + _spacingH

    // ── Windows grouped by workspace ──
    readonly property var windowsByWs: {
        var map = {};
        var list = overviewRoot.rawWindows;
        for (var i = 0; i < list.length; i++) {
            var w = list[i];
            var wsId = w.workspace && w.workspace.id ? w.workspace.id : 0;
            if (wsId < 1 || wsId > workspacesShown) continue;
            if (!map[wsId]) map[wsId] = [];
            map[wsId].push(w);
        }
        return map;
    }

    function winsForWs(wsNum) { return overviewRoot.windowsByWs[String(wsNum)] || []; }

    function iconForClass(cls) { return AppSearch.guessIcon(cls || ""); }

    function colorForClass(cls) {
        var c = (cls || "").toLowerCase();
        var hash = 0;
        for (var i = 0; i < c.length; i++) hash = ((hash << 5) - hash) + c.charCodeAt(i);
        var hue = ((hash % 360) + 360) % 360;
        return Qt.hsla(hue / 360, 0.5, 0.4, 1.0);
    }

    // ── Refresh when overview opens ──
    property int _refreshCount: 0

    Timer {
        id: openRefreshTimer
        interval: 200
        running: GlobalStates.overviewOpen && _refreshCount < 8
        repeat: true
        onTriggered: {
            if (!clientProcess.running) clientProcess.running = true;
            if (!monProcess.running) monProcess.running = true;
            _refreshCount++;
        }
    }

    Connections {
        target: GlobalStates
        function onOverviewOpenChanged() {
            if (GlobalStates.overviewOpen) {
                _refreshCount = 0;
                if (!clientProcess.running) clientProcess.running = true;
                if (!monProcess.running) monProcess.running = true;
                // Trigger grim fallback on next data refresh
                Qt.callLater(function() {
                    if (WlrToplevelMapper && rawWindows.length > 0) {
                        WlrToplevelMapper.updateUnmatched(rawWindows);
                        WlrToplevelMapper.captureAllUnmatched();
                    }
                });
            } else {
                // Reset drag state on close
                overviewRoot.isDragging = false;
                overviewRoot.dragToWorkspace = -1;
                overviewRoot.dragFromWorkspace = -1;
                overviewRoot.dragWindowAddr = "";
            }
        }
    }

    // ── Drag state ──
    property int dragFromWorkspace: -1
    property int dragToWorkspace: -1
    property string dragWindowAddr: ""
    property bool isDragging: false
    property real dragGhostX: 0
    property real dragGhostY: 0
    property real dragGhostW: 120
    property real dragGhostH: 80
    property string dragGhostCls: ""
    property string dragGhostTitle: ""
    property string dragGhostAddr: ""

    Component.onCompleted: {
        if (!clientProcess.running) clientProcess.running = true;
        if (!monProcess.running) monProcess.running = true;
    }

    // ── Grid layout ──
    Item {
        id: gridContainer
        anchors.centerIn: parent
        width: gridTotalW
        height: gridTotalH

        Repeater {
            model: workspacesShown

            Rectangle {
                id: cell
                required property int index
                readonly property int wsNum: index + 1
                readonly property int col: index % columns
                readonly property int row: Math.floor(index / columns)
                readonly property var cellWindows: overviewRoot.winsForWs(wsNum)
                readonly property int staggerDelay: (row * columns + col) * 40
                // findCardAt walks children directly, no need for windowCards

                x: col * (wsCellW + workspaceSpacing) + workspacePadding
                y: row * (wsCellH + workspaceSpacing) + workspacePadding
                width: wsCellW
                height: wsCellH
                color: Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 0.12)
                radius: Styling.radius(2)
                clip: !overviewRoot.isDragging
                // Cell z: drag target > hovered > normal
                z: overviewRoot.dragToWorkspace === wsNum ? 99999 : (dragTracker._hoveredWs === wsNum ? 99998 : 0)

                // Staggered entrance
                opacity: 0; scale: 0.85
                Component.onCompleted: { opacity = 1; scale = 1; }
                Behavior on opacity {
                    enabled: Anim.animationsEnabled
                    SequentialAnimation {
                        PauseAnimation { duration: cell.staggerDelay }
                        NumberAnimation {
                            duration: Anim.emphasizedNormal
                            easing.type: Anim.easing("decelerate").type
                            easing.bezierCurve: Anim.easing("decelerate").bezierCurve
                        }
                    }
                }
                Behavior on scale {
                    enabled: Anim.animationsEnabled
                    SequentialAnimation {
                        PauseAnimation { duration: cell.staggerDelay }
                        NumberAnimation {
                            duration: Anim.emphasizedNormal
                            easing.type: Anim.springSnappy().type
                            easing.bezierCurve: Anim.springSnappy().bezierCurve
                        }
                    }
                }

                // ── Wallpaper background (no ScreencopyView - QJSValue limitation) ──
                TintedWallpaper {
                    anchors.fill: parent; radius: Styling.radius(2)
                    tintEnabled: GlobalStates.wallpaperManager ? GlobalStates.wallpaperManager.tintEnabled : false
                    property string lfp: GlobalStates.wallpaperManager ? GlobalStates.wallpaperManager.getLockscreenFramePath(GlobalStates.wallpaperManager.currentWallpaper) : ""
                    source: lfp ? "file://" + lfp : ""
                    visible: true
                }

                // ── Window cards: positioned by % of monitor ──
                Repeater {
                    model: cellWindows

                    Item {
                        required property var modelData
                        readonly property var win: modelData
                        readonly property var mon: overviewRoot.monMap[String(win.monitor)]

                        // Window position & size as fraction of its monitor
                        // Note: hyprctl reports at[] in logical coords but size[]
                        // in physical coords when scale != 1.0. We multiply
                        // size by scale to normalize to logical coordinates.
                        readonly property real _monScale: mon ? (mon.scale || 1.0) : 1.0
                        readonly property real monW: mon ? (mon.width || 1920) : 1920
                        readonly property real monH: mon ? (mon.height || 1080) : 1080
                        readonly property real relX: monW > 0 ? ((win.at?.[0] || 0) - (mon?.x || 0)) / monW : 0
                        readonly property real relY: monH > 0 ? ((win.at?.[1] || 0) - (mon?.y || 0)) / monH : 0
                        readonly property real relW: monW > 0 ? Math.max(0.05, Math.min(1, ((win.size?.[0] || 100) * _monScale) / monW)) : 0.85
                        readonly property real relH: monH > 0 ? Math.max(0.05, Math.min(1, ((win.size?.[1] || 100) * _monScale) / monH)) : 0.85

                        // Fill to neighbor: expand until hitting another window edge
                        readonly property real fillW: {
                            var base = relW;
                            var r = 1.0; // stretch to right edge of monitor
                            var others = cellWindows;
                            for (var i = 0; i < others.length; i++) {
                                if (others[i].address === win.address) continue;
                                var ox = ((others[i].at?.[0] || 0) - (mon?.x || 0)) / monW;
                                var oy = ((others[i].at?.[1] || 0) - (mon?.y || 0)) / monH;
                                var ow = Math.max(0.05, ((others[i].size?.[0] || 100) * _monScale) / monW);
                                var oh = Math.max(0.05, ((others[i].size?.[1] || 100) * _monScale) / monH);
                                if (ox > relX && oy < relY + relH && oy + oh > relY)
                                    r = Math.min(r, ox);
                            }
                            return Math.max(base, r - relX);
                        }
                        readonly property real fillH: {
                            var base = relH;
                            var b = 1.0; // stretch to bottom edge of monitor
                            var others = cellWindows;
                            for (var i = 0; i < others.length; i++) {
                                if (others[i].address === win.address) continue;
                                var ox = ((others[i].at?.[0] || 0) - (mon?.x || 0)) / monW;
                                var oy = ((others[i].at?.[1] || 0) - (mon?.y || 0)) / monH;
                                var ow = Math.max(0.05, ((others[i].size?.[0] || 100) * _monScale) / monW);
                                var oh = Math.max(0.05, ((others[i].size?.[1] || 100) * _monScale) / monH);
                                if (oy > relY && ox < relX + relW && ox + ow > relX)
                                    b = Math.min(b, oy);
                            }
                            return Math.max(base, b - relY);
                        }

                        readonly property real cardX: Math.round(relX * wsCellW)
                        readonly property real cardY: Math.round(relY * wsCellH)
                        readonly property real cardW: Math.max(12, Math.round(fillW * wsCellW))
                        readonly property real cardH: Math.max(12, Math.round(fillH * wsCellH))

                        readonly property string cls: win.class || ""
                        readonly property string addr: win.address || ""
                        readonly property string title: win.title || cls

                        // Expose card info for the root dragTracker
                        property bool _isCard: true
                        property var _cardData: ({ wsNum: wsNum, addr: addr, cls: cls, title: title, cardW: cardW, cardH: cardH, cardX: cardX, cardY: cardY, cellX: cell.x, cellY: cell.y })
                        // No Component.onCompleted - findCardAt walks children directly

                        // Drag: card se queda en su sitio, overlay replica la sigue
                        property bool _dragActive: false
                        x: cardX; y: cardY; z: 1; width: cardW; height: cardH
                        scale: _dragActive ? 1.04 : 1.0
                        visible: !(overviewRoot.isDragging && addr === overviewRoot.dragWindowAddr)

                        Behavior on scale {
                            enabled: Anim.animationsEnabled
                            SpringAnimation { spring: 4.0; damping: 0.35; mass: 0.3 }
                        }

                        // ── Live per-window preview via WlrToplevelMapper ──
                        readonly property var toplevel: WlrToplevelMapper ? WlrToplevelMapper.find(cls, title) : null

                        // Card background
                        Rectangle {
                            anchors.fill: parent
                            radius: Styling.radius(-2)
                            color: Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 0.45)
                            border.color: Qt.rgba(Colors.onSurface.r, Colors.onSurface.g, Colors.onSurface.b, 0.15)
                            border.width: 1

                            // Accent strip
                            Rectangle {
                                anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                                height: Math.max(2, Math.round(parent.height * 0.04))
                                color: overviewRoot.colorForClass(cls); radius: parent.radius
                            }

                            // Gradient overlay for depth
                            Rectangle {
                                anchors.fill: parent; radius: parent.radius
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.03) }
                                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.12) }
                                }
                            }
                        }

                        // ── Live window preview (when Toplevel available) ──
                        Loader {
                            anchors.fill: parent
                            active: Config.performance.windowPreview && toplevel != null
                            visible: status === Loader.Ready
                            asynchronous: true

                            sourceComponent: ClippingRectangle {
                                anchors.fill: parent
                                radius: Styling.radius(-2)
                                antialiasing: true
                                color: "transparent"

                                ScreencopyView {
                                    id: winPreview
                                    width: Math.max(1, win.size?.[0] || 640)
                                    height: Math.max(1, win.size?.[1] || 480)
                                    captureSource: toplevel
                                    live: GlobalStates.overviewOpen

                                    transform: Scale {
                                        origin.x: 0; origin.y: 0
                                        xScale: parent.width / winPreview.width
                                        yScale: parent.height / winPreview.height
                                    }
                                }

                                // Dim overlay so text is readable
                                Rectangle {
                                    anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.15)
                                }
                            }
                        }

                        // ── App icon (shown when no live preview) ──
                        Image {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: Math.round(-parent.height * 0.02)
                            width: Math.round(Math.min(parent.width, parent.height) * 0.30)
                            height: width
                            source: Quickshell.iconPath(overviewRoot.iconForClass(cls), "image-missing")
                            sourceSize: Qt.size(width, height)
                            asynchronous: true
                            opacity: 0.6
                            visible: !Config.performance.windowPreview || toplevel == null
                        }

                        // ── Window title ──
                        Text {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: Math.max(1, Math.round(parent.height * 0.02))
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.leftMargin: Math.max(1, Math.round(parent.width * 0.02))
                            anchors.rightMargin: Math.max(1, Math.round(parent.width * 0.02))
                            text: title
                            font.family: Config.theme.font
                            font.pixelSize: Math.max(5, Math.round(parent.height * 0.07))
                            color: Colors.onSurface
                            opacity: 0.5
                            elide: Text.ElideRight; maximumLineCount: 1
                            horizontalAlignment: Text.AlignHCenter
                            visible: parent.height > 35
                        }

                        // ── Dim original during drag ──
                        Rectangle {
                            anchors.fill: parent
                            radius: Styling.radius(-2)
                            color: overviewRoot.isDragging && overviewRoot.dragWindowAddr === addr
                                ? Qt.rgba(0, 0, 0, 0.4) : "transparent"
                            z: 5
                            Behavior on color {
                                enabled: Anim.animationsEnabled
                                ColorAnimation { duration: 120 }
                            }
                        }
                    }
                }

                // ── Drop target highlight ──
                Rectangle {
                    anchors.fill: parent
                    radius: Styling.radius(2)
                    color: "transparent"
                    border.color: overviewRoot.dragToWorkspace === wsNum ? Colors.primary : "transparent"
                    border.width: overviewRoot.dragToWorkspace === wsNum ? 3 : 0
                    opacity: overviewRoot.dragToWorkspace === wsNum ? 0.7 : 0
                    z: 10
                    Behavior on opacity {
                        enabled: Anim.animationsEnabled
                        NumberAnimation { duration: 100 }
                    }
                    Behavior on border.width {
                        enabled: Anim.animationsEnabled
                        NumberAnimation { duration: 100 }
                    }
                }

                // ── Workspace number ──
                Text {
                    anchors.right: parent.right; anchors.bottom: parent.bottom
                    anchors.margins: 4
                    text: String(wsNum)
                    font.family: Config.theme.font
                    font.pixelSize: Math.max(10, Math.round(wsCellH * 0.08))
                    font.bold: true; color: Colors.onSurface; opacity: 0.2; z: 5
                }

            }
        }

    }

    // ── Drag overlay: replica visual de la card que sigue al mouse ──
    // Se renderiza a nivel root (z:100001) entre cells (0) y dragTracker (100002)
    Item {
        id: dragOverlay
        visible: overviewRoot.isDragging && overviewRoot.dragGhostAddr.length > 0
        z: 100001
        x: overviewRoot.dragGhostX
        y: overviewRoot.dragGhostY
        width: overviewRoot.dragGhostW
        height: overviewRoot.dragGhostH
        clip: true

        // Live preview via WlrToplevelMapper
        readonly property var _toplevel: Config.performance.windowPreview && overviewRoot.dragGhostCls
            ? (WlrToplevelMapper ? WlrToplevelMapper.find(overviewRoot.dragGhostCls, overviewRoot.dragGhostTitle) : null) : null

        // Live ScreencopyView
        Loader {
            anchors.fill: parent
            active: dragOverlay._toplevel != null
            visible: status === Loader.Ready
            asynchronous: true

            sourceComponent: ClippingRectangle {
                anchors.fill: parent
                radius: Styling.radius(-2)
                antialiasing: true; color: "transparent"

                ScreencopyView {
                    id: ovPreview
                    width: Math.max(1, overviewRoot.dragGhostW * 1.2)
                    height: Math.max(1, overviewRoot.dragGhostH * 1.2)
                    captureSource: dragOverlay._toplevel
                    live: true
                    transform: Scale {
                        origin.x: 0; origin.y: 0
                        xScale: parent.width / ovPreview.width
                        yScale: parent.height / ovPreview.height
                    }
                }
                // Dim overlay so text is readable
                Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.15) }
            }
        }

        // Grim screenshot fallback
        Image {
            anchors.fill: parent
            source: Config.performance.windowPreview && dragOverlay._toplevel == null && overviewRoot.dragGhostAddr
                ? WlrToplevelMapper.screenshotPath(overviewRoot.dragGhostAddr) : ""
            sourceSize: Qt.size(parent.width, parent.height)
            asynchronous: true; fillMode: Image.PreserveAspectCrop
            visible: status === Image.Ready && dragOverlay._toplevel == null
            opacity: 0.5
        }

        // Card background (always visible)
        Rectangle {
            anchors.fill: parent
            radius: Styling.radius(-2)
            color: Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 0.5)
            border.color: Styling.srItem("overprimary"); border.width: 2
            z: 0

            Rectangle {
                anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                height: Math.max(2, Math.round(parent.height * 0.04))
                color: overviewRoot.colorForClass(overviewRoot.dragGhostCls)
                radius: parent.radius
            }

            Image {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: Math.round(-parent.height * 0.02)
                width: Math.round(Math.min(parent.width, parent.height) * 0.30); height: width
                source: Quickshell.iconPath(overviewRoot.iconForClass(overviewRoot.dragGhostCls), "image-missing")
                sourceSize: Qt.size(width, height)
                asynchronous: true; opacity: 0.7
            }

            Text {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Math.max(1, Math.round(parent.height * 0.02))
                anchors.left: parent.left; anchors.right: parent.right
                anchors.leftMargin: 2; anchors.rightMargin: 2
                text: overviewRoot.dragGhostTitle
                font.family: Config.theme.font
                font.pixelSize: Math.max(5, Math.round(parent.height * 0.07))
                color: Colors.onSurface; opacity: 0.6
                elide: Text.ElideRight; maximumLineCount: 1
                horizontalAlignment: Text.AlignHCenter
                visible: parent.height > 35
            }
        }
    }

    // ── SINGLE MouseArea: handles ALL interactions ──
    // Finds cards via childAt + _isCard property walk.
    // No mouse event conflicts because this is the only MouseArea.
    MouseArea {
        id: dragTracker
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        hoverEnabled: true
        z: 100002
        cursorShape: overviewRoot.isDragging ? Qt.ClosedHandCursor : Qt.ArrowCursor

        // Find card at mouse position by walking cell children directly
        function findCardAt(mx, my) {
            var gx = mx - gridContainer.x;
            var gy = my - gridContainer.y;

            for (var ws = 1; ws <= overviewRoot.workspacesShown; ws++) {
                var cellEl = gridContainer.children.find(function(c) {
                    return c.wsNum === ws;
                });
                if (!cellEl) continue;

                var cx = gx - cellEl.x;
                var cy = gy - cellEl.y;

                // Walk cell's visual children looking for _isCard
                var kids = cellEl.children;
                for (var ki = 0; ki < kids.length; ki++) {
                    var card = kids[ki];
                    if (!card._isCard) continue;
                    if (cx >= card.x && cx <= card.x + card.width &&
                        cy >= card.y && cy <= card.y + card.height) {
                        return card;
                    }
                }
            }
            return null;
        }

        // ── Hover + Press state ──
        property var _pendingCard: null
        property var _pendingData: null
        property bool _holding: false
        property bool _dragging: false
        // Updated on every mouse move: workspace number under cursor
        property int _hoveredWs: -1

        // Helper: find workspace number from root-level coordinates
        function wsAt(mx, my) {
            var gx = mx - gridContainer.x;
            var gy = my - gridContainer.y;
            var cw = overviewRoot.wsCellW + overviewRoot.workspaceSpacing;
            var ch = overviewRoot.wsCellH + overviewRoot.workspaceSpacing;
            var col = Math.floor((gx - overviewRoot.workspacePadding) / cw);
            var row = Math.floor((gy - overviewRoot.workspacePadding) / ch);
            if (col >= 0 && col < overviewRoot.columns && row >= 0 && row < overviewRoot.rows) {
                return row * overviewRoot.columns + col + 1;
            }
            return -1;
        }

        // Track drag type: 'single' (left) or 'batch' (right)
        property string _dragType: ""

        onPressed: mouse => {
            var card = findCardAt(mouse.x, mouse.y);

            if (card) {
                dragTracker._pendingCard = card;
                dragTracker._pendingData = card._cardData;
                dragTracker._holding = true;
                dragTracker._startX = mouse.x;
                dragTracker._startY = mouse.y;

                if (mouse.button === Qt.RightButton) {
                    // Right click: start BATCH drag immediately (move all windows)
                    dragTracker._dragging = true;
                    dragTracker._dragType = "batch";
                    var d = card._cardData;
                    card._dragActive = true;
                    overviewRoot.isDragging = true;
                    overviewRoot.dragFromWorkspace = d.wsNum;
                    overviewRoot.dragWindowAddr = d.addr;
                    overviewRoot.dragGhostCls = d.cls;
                    overviewRoot.dragGhostTitle = "Mover todas las ventanas";
                    overviewRoot.dragGhostAddr = d.addr;
                    overviewRoot.dragGhostW = 140;
                    overviewRoot.dragGhostH = 60;
                    overviewRoot.dragGhostX = mouse.x - 70;
                    overviewRoot.dragGhostY = mouse.y - 30;
                } else {
                    // Left click: normal drag (starts on movement)
                    dragTracker._dragType = "single";
                }
            } else {
                dragTracker._holding = false;
                dragTracker._pendingCard = null;
                dragTracker._pendingData = null;
            }
        }
        // Cancel hold on significant movement
        property real _startX: 0
        property real _startY: 0

        onPositionChanged: mouse => {
            // Track which workspace cell the mouse is over
            dragTracker._hoveredWs = dragTracker.wsAt(mouse.x, mouse.y);

            if (dragTracker._dragging) {
                // Overlay replica follows mouse at root level (floats above all cells)
                overviewRoot.dragGhostX = mouse.x - overviewRoot.dragGhostW / 2;
                overviewRoot.dragGhostY = mouse.y - overviewRoot.dragGhostH / 2;

                // Target cell
                var gx = mouse.x - gridContainer.x;
                var gy = mouse.y - gridContainer.y;
                var cw = overviewRoot.wsCellW + overviewRoot.workspaceSpacing;
                var ch = overviewRoot.wsCellH + overviewRoot.workspaceSpacing;
                var col = Math.floor((gx - overviewRoot.workspacePadding) / cw);
                var row = Math.floor((gy - overviewRoot.workspacePadding) / ch);
                if (col >= 0 && col < overviewRoot.columns && row >= 0 && row < overviewRoot.rows) {
                    var target = row * overviewRoot.columns + col + 1;
                    if (target !== overviewRoot.dragToWorkspace) {
                        overviewRoot.dragToWorkspace = target;
                    }
                } else {
                    overviewRoot.dragToWorkspace = -1;
                }
            } else if (dragTracker._holding && !dragTracker._dragging) {
                var dx = mouse.x - dragTracker._startX;
                var dy = mouse.y - dragTracker._startY;
                if (Math.sqrt(dx*dx + dy*dy) > 12) {
                    // Movement detected → start drag instantly
                    dragTracker._dragging = true;
                    var d = dragTracker._pendingData;
                    var card = dragTracker._pendingCard;
                    if (d && card) {
                        card._dragActive = true;
                        // Overlay muestra la card en el mouse (flota sobre todos los cells)
                        overviewRoot.isDragging = true;
                        overviewRoot.dragFromWorkspace = d.wsNum;
                        overviewRoot.dragWindowAddr = d.addr;
                        overviewRoot.dragGhostCls = d.cls;
                        overviewRoot.dragGhostTitle = d.title;
                        overviewRoot.dragGhostAddr = d.addr;
                        overviewRoot.dragGhostW = d.cardW;
                        overviewRoot.dragGhostH = d.cardH;
                        overviewRoot.dragGhostX = mouse.x - d.cardW / 2;
                        overviewRoot.dragGhostY = mouse.y - d.cardH / 2;
                    }
                }
            }
        }

        onReleased: mouse => {
            if (dragTracker._dragging) {
                var targetWs = overviewRoot.dragToWorkspace;
                var origWs = overviewRoot.dragFromWorkspace;
                var dragAddr = overviewRoot.dragWindowAddr;
                var card = dragTracker._pendingCard;
                if (card) { card._dragActive = false; }

                dragTracker._dragging = false;
                dragTracker._holding = false;
                dragTracker._pendingCard = null;
                dragTracker._pendingData = null;
                overviewRoot.isDragging = false;
                overviewRoot.dragToWorkspace = -1;
                overviewRoot.dragFromWorkspace = -1;
                overviewRoot.dragWindowAddr = "";

                if (targetWs > 0 && targetWs !== origWs && dragAddr) {
                    if (dragTracker._dragType === "batch") {
                        // Batch move: move ALL windows from source to target
                        var allWins = overviewRoot.winsForWs(origWs);
                        for (var bi = 0; bi < allWins.length; bi++) {
                            if (allWins[bi].address) {
                                AxctlService.dispatch("movetoworkspacesilent " + targetWs + ",address:" + allWins[bi].address);
                            }
                        }
                    } else {
                        // Single move
                        AxctlService.dispatch("movetoworkspacesilent " + targetWs + ",address:" + dragAddr);
                    }
                }

                // Wait 200ms for axctl to process the move before refreshing
                delayedRefreshTimer.restart();

            } else if (dragTracker._holding && mouse.button === Qt.LeftButton) {
                // Quick release → click: focus window
                var d = dragTracker._pendingData;
                if (d && d.addr) {
                    Visibilities.setActiveModule("", true);
                    Qt.callLater(function() {
                        AxctlService.dispatch("focuswindow address:" + d.addr);
                        wsSwitchProcess.command = ["hyprctl", "dispatch", "workspace", String(d.wsNum)];
                        wsSwitchProcess.running = true;
                    });
                }

            } else if (mouse.button === Qt.MiddleButton) {
                var card = findCardAt(mouse.x, mouse.y);
                if (card && card._cardData && card._cardData.addr) {
                    AxctlService.dispatch("closewindow address:" + card._cardData.addr);
                }

            } else if (mouse.button === Qt.LeftButton && !dragTracker._holding) {
                var ws = dragTracker.wsAt(mouse.x, mouse.y);
                if (ws > 0) {
                    wsSwitchProcess.command = ["hyprctl", "dispatch", "workspace", String(ws)];
                    wsSwitchProcess.running = true;
                }
            }

            dragTracker._holding = false;
            dragTracker._pendingCard = null;
            dragTracker._pendingData = null;
        }
    }



}