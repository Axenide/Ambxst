import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.modules.globals
import qs.modules.theme
import qs.modules.components
import qs.modules.bar.workspaces
import qs.modules.services
import qs.config

Item {
    id: overviewRoot

    // Direct hyprctl for workspace switching
    Process {
        id: wsSwitchProcess
    }

    // Fetch all workspace states via hyprctl -j (includes empty/off-screen)
    property var workspaceStates: []
    Process {
        id: wsStateProcess
        command: ["hyprctl", "workspaces", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var raw = JSON.parse(text);
                    if (Array.isArray(raw))
                        overviewRoot.workspaceStates = raw;
                } catch (e) {}
            }
        }
    }
    // Refresh workspace states when overview opens + periodically
    Timer {
        id: wsStateTimer
        interval: 800
        running: GlobalStates.overviewOpen
        repeat: true
        onTriggered: { if (!wsStateProcess.running) wsStateProcess.running = true; }
    }

    // Config
    readonly property real scale: Config.overview.scale
    readonly property int rows: Config.overview.rows
    readonly property int columns: Config.overview.columns
    readonly property int workspacesShown: rows * columns
    readonly property real workspaceSpacing: Config.overview.workspaceSpacing
    readonly property real workspacePadding: 8
    readonly property color activeBorderColor: Styling.srItem("overprimary")

    property var currentScreen: null
    readonly property var monitor: currentScreen ? AxctlService.monitorFor(currentScreen) : AxctlService.focusedMonitor
    readonly property var windowList: CompositorData.windowList
    readonly property var allMonitors: CompositorData.monitors
    readonly property int monitorId: monitor?.id ?? -1
    readonly property var monitorData: allMonitors.find(m => m.id === monitorId) ?? null
    readonly property string barPosition: Config.bar.position
    readonly property var barPanel: monitor ? Visibilities.getBarPanelForScreen(monitor.name) : null
    readonly property bool isBarPinned: barPanel ? barPanel.pinned : (Config.bar.pinnedOnStartup ?? true)
    readonly property int barReserved: isBarPinned ? (Config.showBackground ? 44 : 40) : 0

    // Workspace cell size (based on current screen's monitor)
    readonly property real wsCellW: {
        if (!monitorData) return 200;
        var ro = (monitorData.transform % 2 === 1);
        var ms = monitorData.scale || 1.0;
        var w = ro ? (monitor?.height || 1920) : (monitor?.width || 1920);
        var sw = (w / ms) * scale;
        if (barPosition === "left" || barPosition === "right") sw -= barReserved * scale;
        return Math.max(0, Math.round(sw));
    }
    readonly property real wsCellH: {
        if (!monitorData) return 150;
        var ro = (monitorData.transform % 2 === 1);
        var ms = monitorData.scale || 1.0;
        var h = ro ? (monitor?.width || 1080) : (monitor?.height || 1080);
        var sh = (h / ms) * scale;
        if (barPosition === "top" || barPosition === "bottom") sh -= barReserved * scale;
        return Math.max(0, Math.round(sh));
    }

    // Drag state
    property int draggingFromWorkspace: -1
    property int draggingTargetWorkspace: -1

    // Search
    property string searchQuery: ""
    property var matchingWindows: []
    property int selectedMatchIndex: 0
    function resetSearch() { searchQuery = ""; matchingWindows = []; selectedMatchIndex = 0; }
    onSearchQueryChanged: updateMatchingWindows()
    onWindowListChanged: {
        updateMatchingWindows();
        Qt.callLater(_updateFilteredWindows);
    }
    onAllMonitorsChanged: Qt.callLater(_updateFilteredWindows)

    // Force refresh after user actions (drag, click)
    function refreshOverview() {
        if (typeof CompositorData !== "undefined" && CompositorData.refreshFromHyprctl)
            CompositorData.refreshFromHyprctl();
        Qt.callLater(_updateFilteredWindows);
    }

    // Poll for position/size updates while overview is visible.
    // windowList may be mutated in-place by axctl; this ensures
    // the cache key detects moves/resizes even without a full list change.
    Timer {
        id: positionPollTimer
        interval: 400
        running: GlobalStates.overviewOpen
        repeat: true
        onTriggered: overviewRoot._updateFilteredWindows()
    }

    // Stable cache for filtered windows to avoid destroying/recreating delegates
    // every time axctl pushes a minor update (focus change, etc.)
    property var _filteredWindowsCache: []
    property string _filteredWindowsCacheKey: ""

    Component.onCompleted: {
        _updateFilteredWindows();
        wsStateProcess.running = true;
    }

    function _updateFilteredWindows() {
        var list = overviewRoot.windowList;
        var keyParts = [];
        var result = [];
        for (var i = 0; i < list.length; i++) {
            var w = list[i];
            if (!w || !w.workspace || !w.workspace.id || w.workspace.id <= 0 || w.workspace.id > workspacesShown)
                continue;
            // Include position and size in key so windows reposition/resize reactively
            keyParts.push(w.address + ":" + w.workspace.id
                + ":@" + (w.at?.[0] ?? 0) + "," + (w.at?.[1] ?? 0)
                + ":" + (w.size?.[0] ?? 0) + "x" + (w.size?.[1] ?? 0));
            var winMon = overviewRoot.allMonitors.find(function(m) { return m.id === w.monitor; });
            result.push({
                windowData: w,
                winMonData: winMon
            });
        }
        var newKey = keyParts.join('|');
        if (newKey !== _filteredWindowsCacheKey) {
            _filteredWindowsCacheKey = newKey;
            // Compute fill dimensions so windows tile without overlapping
            _filteredWindowsCache = _computeFillSizes(result);
        }
    }

    // For each window, calculate how far it can extend right/down before
    // hitting a neighbor, so cards fill their region without overlapping.
    // Must use the same coordinate system as OverviewWindow (bar-adjusted,
    // rotation-aware) to stay in sync with the delegate calculations.
    function _computeFillSizes(items) {
        var i, j, a, b;
        var bp = overviewRoot.barPosition;
        var br = overviewRoot.barReserved;
        for (i = 0; i < items.length; i++) {
            a = items[i];
            var wd = a.windowData;
            var wsId = wd.workspace?.id ?? 0;
            var md = a.winMonData;
            // Same rotation-aware effective dimensions as OverviewWindow
            var ro = md && (md.transform % 2 === 1);
            var monW = md ? (ro ? (md.height || 1080) : (md.width || 1920)) : 1920;
            var monH = md ? (ro ? (md.width || 1920) : (md.height || 1080)) : 1080;
            monW = monW > 0 ? monW : 1920;
            monH = monH > 0 ? monH : 1080;

            // Window position relative to monitor, same as OverviewWindow.relX/relY
            var ax = (wd.at?.[0] ?? 0) - (md?.x ?? 0);
            var ay = (wd.at?.[1] ?? 0) - (md?.y ?? 0);
            if (bp === "left") ax -= br;
            if (bp === "top") ay -= br;
            // Clamp to monitor bounds
            ax = Math.max(0, ax);
            ay = Math.max(0, ay);
            var aw = wd.size?.[0] ?? monW;
            var ah = wd.size?.[1] ?? monH;
            // Effective monitor area (bar-adjusted)
            var effW = monW - (bp === "left" || bp === "right" ? br : 0);
            var effH = monH - (bp === "top" || bp === "bottom" ? br : 0);

            // Default: fill to effective monitor edge
            var rightLimit = effW;
            var bottomLimit = effH;

            for (j = 0; j < items.length; j++) {
                if (i === j) continue;
                b = items[j];
                if ((b.windowData.workspace?.id ?? 0) !== wsId) continue;
                if ((b.winMonData?.id ?? -1) !== (md?.id ?? -1)) continue;

                var bx = (b.windowData.at?.[0] ?? 0) - (b.winMonData?.x ?? 0);
                var by = (b.windowData.at?.[1] ?? 0) - (b.winMonData?.y ?? 0);
                if (bp === "left") bx -= br;
                if (bp === "top") by -= br;
                var bw = b.windowData.size?.[0] ?? monW;
                var bh = b.windowData.size?.[1] ?? monH;

                // b is to the right AND shares vertical space → tightens right limit
                // Skip if b is fully contained inside a (e.g., floating window over maximized)
                var bContainedInA = (bx >= ax && by >= ay && bx + bw <= ax + aw && by + bh <= ay + ah);
                if (!bContainedInA && bx > ax && by < ay + ah && by + bh > ay)
                    rightLimit = Math.min(rightLimit, bx);
                // b is below AND shares horizontal space → tightens bottom limit
                if (!bContainedInA && by > ay && bx < ax + aw && bx + bw > ax)
                    bottomLimit = Math.min(bottomLimit, by);
            }

            // Fill ratios: extend to neighbor, but never smaller than own size
            var relW = aw > 200 ? Math.max(0.05, Math.min(1, aw / effW)) : 0.85;
            var relH = ah > 200 ? Math.max(0.05, Math.min(1, ah / effH)) : 0.85;
            a.fillW = effW > 0 ? Math.max(relW, Math.min(1, (rightLimit - ax) / effW)) : 0.85;
            a.fillH = effH > 0 ? Math.max(relH, Math.min(1, (bottomLimit - ay) / effH)) : 0.85;
        }
        return items;
    }

    function fuzzyMatch(q, t) {
        if (q.length === 0) return true;
        if (t.length === 0) return false;
        var qi = 0;
        for (var i = 0; i < t.length && qi < q.length; i++) { if (t[i] === q[qi]) qi++; }
        return qi === q.length;
    }
    function fuzzyScore(q, t) {
        if (q.length === 0) return 0;
        if (t.length === 0) return -1;
        if (t.includes(q)) return 1000 + (100 - t.length);
        var qi = 0, cons = 0, maxc = 0, score = 0;
        for (var i = 0; i < t.length && qi < q.length; i++) {
            if (t[i] === q[qi]) { qi++; cons++; maxc = Math.max(maxc, cons);
                if (i === 0 || t[i-1] === ' ' || t[i-1] === '-' || t[i-1] === '_') score += 10; }
            else cons = 0;
        }
        if (qi !== q.length) return -1;
        return score + maxc * 5;
    }
    function updateMatchingWindows() {
        if (searchQuery.length === 0) { matchingWindows = []; selectedMatchIndex = 0; return; }
        var q = searchQuery.toLowerCase();
        var m = windowList.filter(function(w) {
            if (!w) return false;
            return fuzzyMatch(q, (w.title || "").toLowerCase()) || fuzzyMatch(q, (w.class || "").toLowerCase());
        }).map(function(w) {
            return { window: w, score: Math.max(fuzzyScore(q, (w.title || "").toLowerCase()), fuzzyScore(q, (w.class || "").toLowerCase())) };
        }).sort(function(a,b) { return b.score - a.score; }).map(function(i) { return i.window; });
        matchingWindows = m; selectedMatchIndex = m.length > 0 ? 0 : -1;
    }
    function isWindowMatched(addr) { return searchQuery.length > 0 && matchingWindows.some(function(w) { return w?.address === addr; }); }
    function isWindowSelected(addr) { return matchingWindows.length > 0 && selectedMatchIndex >= 0 && matchingWindows[selectedMatchIndex]?.address === addr; }

    // ── Build filtered windows list (ALL monitors, workspaces 1..workspacesShown) ──
    // Each window carries its OWN monitor data for correct positioning.
    // toplevel is resolved lazily inside the delegate to keep this array stable.
    readonly property var filteredWindows: _filteredWindowsCache

    implicitWidth: bg.implicitWidth
    implicitHeight: bg.implicitHeight

    Item {
        id: bg
        anchors.centerIn: parent

        ColumnLayout {
            id: mainGrid
            anchors.centerIn: parent
            spacing: workspaceSpacing

            Repeater {
                model: overviewRoot.rows
                delegate: RowLayout {
                    spacing: workspaceSpacing
                    Repeater {
                        model: overviewRoot.columns
                        Rectangle {
                            id: cell
                            property int wsNum: rowIndex * overviewRoot.columns + index + 1
                            readonly property bool isDropTarget: overviewRoot.draggingTargetWorkspace === wsNum

                            implicitWidth: overviewRoot.wsCellW + workspacePadding
                            implicitHeight: overviewRoot.wsCellH + workspacePadding
                            color: "transparent"; radius: Styling.radius(2)
                            border.width: 2; border.color: isDropTarget ? Colors.outline : "transparent"
                            clip: true

                            TintedWallpaper {
                                anchors.fill: parent; radius: Styling.radius(2)
                                tintEnabled: GlobalStates.wallpaperManager ? GlobalStates.wallpaperManager.tintEnabled : false
                                property string lfp: GlobalStates.wallpaperManager ? GlobalStates.wallpaperManager.getLockscreenFramePath(GlobalStates.wallpaperManager.currentWallpaper) : ""
                                source: lfp ? "file://" + lfp : ""
                            }
                            Text {
                                anchors.centerIn: parent
                                text: String(wsNum)
                                font.family: Config.theme.font
                                font.pixelSize: Math.max(20, Math.round(wsCellH * 0.12))
                                font.bold: true; color: Colors.onSurface; opacity: 0.3; z: 5
                            }
                            MouseArea {
                                anchors.fill: parent; acceptedButtons: Qt.LeftButton
                                onClicked: {
                                    wsSwitchProcess.command = ["hyprctl", "dispatch", "workspace", String(wsNum)];
                                    wsSwitchProcess.running = true;
                                }
                                onDoubleClicked: {
                                    Visibilities.setActiveModule("");
                                    wsSwitchProcess.command = ["hyprctl", "dispatch", "workspace", String(wsNum)];
                                    wsSwitchProcess.running = true;
                                }
                            }
                            DropArea {
                                anchors.fill: parent
                                onEntered: overviewRoot.draggingTargetWorkspace = wsNum
                                onExited: { if (overviewRoot.draggingTargetWorkspace === wsNum) overviewRoot.draggingTargetWorkspace = -1; }
                            }
                        }
                    }
                }
            }
        }

        // Window overlay
        Item {
            id: winLayer
            anchors.centerIn: parent
            implicitWidth: mainGrid.implicitWidth
            implicitHeight: mainGrid.implicitHeight

            // Workspace-click fallback for empty cells.
            // First child = behind Repeater items. Only catches clicks
            // that miss all window delegates.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                onClicked: mouse => {
                    var cw = overviewRoot.wsCellW + workspacePadding + workspaceSpacing;
                    var ch = overviewRoot.wsCellH + workspacePadding + workspaceSpacing;
                    var col = Math.floor((mouse.x - workspacePadding / 2) / cw);
                    var row = Math.floor((mouse.y - workspacePadding / 2) / ch);
                    if (col >= 0 && col < overviewRoot.columns && row >= 0 && row < overviewRoot.rows) {
                        wsSwitchProcess.command = ["hyprctl", "dispatch", "workspace",
                            String(row * overviewRoot.columns + col + 1)];
                        wsSwitchProcess.running = true;
                        Qt.callLater(overviewRoot.refreshOverview);
                    }
                }
            }

            Repeater {
                model: overviewRoot.filteredWindows

                delegate: OverviewWindow {
                    id: win
                    required property var modelData
                    windowData: modelData.windowData
                    toplevel: {
                        var w = modelData.windowData;
                        if (!w) return null;
                        var cls = w.class || "";
                        if (!cls) return null;
                        var cands = ToplevelManager.toplevels.values.filter(function(t) { return t.appId === cls; });
                        if (cands.length === 0) return null;
                        var titleMatch = cands.find(function(t) { return t.title === (w.title || ""); });
                        if (titleMatch) return titleMatch;
                        var wt = (w.title || "").toLowerCase();
                        var partial = cands.find(function(t) { var tt = (t.title || "").toLowerCase(); return wt.includes(tt) || tt.includes(wt); });
                        if (partial) return partial;
                        return null;
                    }
                    availableWorkspaceWidth: overviewRoot.wsCellW
                    availableWorkspaceHeight: overviewRoot.wsCellH
                    monitorData: modelData.winMonData || overviewRoot.monitorData
                    barPosition: overviewRoot.barPosition
                    barReserved: overviewRoot.barReserved

                    overviewRootRef: overviewRoot
                    isSearchMatch: overviewRoot.isWindowMatched(windowData?.address)
                    isSearchSelected: overviewRoot.isWindowSelected(windowData?.address)

                    // Grid cell offset based on workspace ID
                    property int wCol: (windowData?.workspace.id - 1) % overviewRoot.columns
                    property int wRow: Math.floor((windowData?.workspace.id - 1) % overviewRoot.workspacesShown / overviewRoot.columns)
                    xOffset: Math.round((overviewRoot.wsCellW + workspacePadding + workspaceSpacing) * wCol + workspacePadding / 2)
                    yOffset: Math.round((overviewRoot.wsCellH + workspacePadding + workspaceSpacing) * wRow + workspacePadding / 2)

                    onDragStarted: overviewRoot.draggingFromWorkspace = windowData?.workspace.id || -1
                    onDragFinished: function(targetWs) {
                        overviewRoot.draggingFromWorkspace = -1;
                        if (targetWs > 0 && targetWs !== windowData?.workspace.id) {
                            AxctlService.dispatch("movetoworkspacesilent " + targetWs + ",address:" + (windowData?.address || ""));
                            Qt.callLater(function() { CompositorData.refreshFromHyprctl(); });
                        }
                    }
                    onWindowClicked: {
                        Visibilities.setActiveModule("", true);
                        Qt.callLater(function() { AxctlService.dispatch("focuswindow address:" + windowData.address); });
                    }
                    onWindowClosed: { AxctlService.dispatch("closewindow address:" + windowData.address); }
                }
            }
        }
    }
}
