import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.modules.globals
import qs.modules.theme
import qs.modules.components
import qs.modules.bar.workspaces
import qs.modules.services
import qs.config

Item {
    id: overviewRoot

    // ── Direct hyprctl query for fresh window data ──
    property Process _hyprctlClients: Process {
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var raw = JSON.parse(text);
                    if (raw && raw.length > 0 && typeof CompositorData !== "undefined")
                        CompositorData.windowList = raw;
                } catch (e) {}
            }
        }
    }
    function refreshFromHyprctl() { _hyprctlClients.running = true; }

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
    property int _refreshToken: 0
    function forceRefresh() { _refreshToken++; }
    function refreshWithHyprctl() {
        refreshFromHyprctl();
        forceRefresh();
    }
    Component.onCompleted: refreshWithHyprctl()

    // Search
    property string searchQuery: ""
    property var matchingWindows: []
    property int selectedMatchIndex: 0
    function resetSearch() { searchQuery = ""; matchingWindows = []; selectedMatchIndex = 0; }
    onSearchQueryChanged: updateMatchingWindows()
    onWindowListChanged: updateMatchingWindows()

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
    // Each window carries its OWN monitor data for correct positioning
    readonly property var filteredWindows: {
        var _ = overviewRoot._refreshToken;
        var toplevels = ToplevelManager.toplevels.values;
        var result = [];
        var list = overviewRoot.windowList;
        for (var i = 0; i < list.length; i++) {
            var w = list[i];
            if (!w || !w.workspace || !w.workspace.id || w.workspace.id <= 0 || w.workspace.id > workspacesShown)
                continue;
            var winMon = overviewRoot.allMonitors.find(function(m) { return m.id === w.monitor; });
            result.push({
                windowData: w,
                winMonData: winMon,
                toplevel: (function() {
                    var cls = w.class || "";
                    if (!cls) return null;
                    var cands = toplevels.filter(function(t) { return t.appId === cls; });
                    if (cands.length <= 1) return cands[0] || null;
                    return cands.find(function(t) { return t.title === (w.title || ""); }) || cands[0];
                })()
            });
        }
        return result;
    }

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
                                onClicked: AxctlService.dispatch("workspace " + wsNum)
                                onDoubleClicked: { Visibilities.setActiveModule(""); AxctlService.dispatch("workspace " + wsNum); }
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

            Repeater {
                model: overviewRoot.filteredWindows

                delegate: OverviewWindow {
                    id: win
                    required property var modelData
                    windowData: modelData.windowData
                    toplevel: modelData.toplevel
                    scale: overviewRoot.scale
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
                            Qt.callLater(function() { overviewRoot.refreshFromHyprctl(); });
                            overviewRoot.forceRefresh();
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
