import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.modules.globals
import qs.modules.theme
import qs.modules.bar.workspaces
import qs.modules.services
import qs.modules.components
import qs.config

Item {
    id: scrollingOverviewRoot

    // Config values
    readonly property real scale: Config.overview.scale
    readonly property int totalWorkspaces: Config.overview.rows * Config.overview.columns
    readonly property int visibleWorkspaces: 3  // Show 3 workspaces at a time in viewport
    readonly property real workspaceSpacing: Config.overview.workspaceSpacing
    readonly property real workspacePadding: 4
    readonly property color activeBorderColor: Colors.primary

    // Monitor info
    property var currentScreen: null
    readonly property var monitor: currentScreen ? Hyprland.monitorFor(currentScreen) : Hyprland.focusedMonitor
    readonly property int monitorId: monitor?.id ?? -1
    readonly property var monitors: HyprlandData.monitors
    readonly property var monitorData: monitors.find(m => m.id === monitorId) ?? null

    readonly property string barPosition: Config.bar.position
    readonly property int barReserved: Config.showBackground ? 44 : 40

    // Window data
    readonly property var windowList: HyprlandData.windowList
    
    // Focused window address for centering
    readonly property string focusedWindowAddress: Hyprland.focusedClient?.address ?? ""

    // Search functionality
    property string searchQuery: ""
    property var matchingWindows: []
    property int selectedMatchIndex: 0

    function resetSearch() {
        searchQuery = "";
        matchingWindows = [];
        selectedMatchIndex = 0;
    }

    onSearchQueryChanged: updateMatchingWindows()
    onWindowListChanged: updateMatchingWindows()

    function fuzzyMatch(query, target) {
        if (query.length === 0) return true;
        if (target.length === 0) return false;
        let queryIndex = 0;
        for (let i = 0; i < target.length && queryIndex < query.length; i++) {
            if (target[i] === query[queryIndex]) {
                queryIndex++;
            }
        }
        return queryIndex === query.length;
    }

    function fuzzyScore(query, target) {
        if (query.length === 0) return 0;
        if (target.length === 0) return -1;
        if (target.includes(query)) return 1000 + (100 - target.length);
        let queryIndex = 0;
        let consecutiveMatches = 0;
        let maxConsecutive = 0;
        let score = 0;
        for (let i = 0; i < target.length && queryIndex < query.length; i++) {
            if (target[i] === query[queryIndex]) {
                queryIndex++;
                consecutiveMatches++;
                maxConsecutive = Math.max(maxConsecutive, consecutiveMatches);
                if (i === 0 || target[i-1] === ' ' || target[i-1] === '-' || target[i-1] === '_') {
                    score += 10;
                }
            } else {
                consecutiveMatches = 0;
            }
        }
        if (queryIndex !== query.length) return -1;
        return score + maxConsecutive * 5;
    }

    function updateMatchingWindows() {
        if (searchQuery.length === 0) {
            matchingWindows = [];
            selectedMatchIndex = 0;
            return;
        }
        const query = searchQuery.toLowerCase();
        const matches = windowList
            .filter(win => {
                if (!win) return false;
                const title = (win.title || "").toLowerCase();
                const windowClass = (win.class || "").toLowerCase();
                return fuzzyMatch(query, title) || fuzzyMatch(query, windowClass);
            })
            .map(win => ({
                window: win,
                score: Math.max(
                    fuzzyScore(query, (win.title || "").toLowerCase()),
                    fuzzyScore(query, (win.class || "").toLowerCase())
                )
            }))
            .sort((a, b) => b.score - a.score)
            .map(item => item.window);
        matchingWindows = matches;
        selectedMatchIndex = matches.length > 0 ? 0 : -1;
    }

    function navigateToSelectedWindow() {
        if (matchingWindows.length === 0 || selectedMatchIndex < 0) return;
        const win = matchingWindows[selectedMatchIndex];
        if (!win) return;
        Visibilities.setActiveModule("", true);
        Qt.callLater(() => {
            Hyprland.dispatch(`focuswindow address:${win.address}`);
        });
    }

    function selectNextMatch() {
        if (matchingWindows.length === 0) return;
        selectedMatchIndex = (selectedMatchIndex + 1) % matchingWindows.length;
    }

    function selectPrevMatch() {
        if (matchingWindows.length === 0) return;
        selectedMatchIndex = (selectedMatchIndex - 1 + matchingWindows.length) % matchingWindows.length;
    }

    function isWindowMatched(windowAddress) {
        if (searchQuery.length === 0) return false;
        return matchingWindows.some(win => win?.address === windowAddress);
    }

    function isWindowSelected(windowAddress) {
        if (matchingWindows.length === 0 || selectedMatchIndex < 0) return false;
        return matchingWindows[selectedMatchIndex]?.address === windowAddress;
    }

    // Calculate workspace dimensions
    // Triple the width for scrolling mode to take advantage of horizontal space
    readonly property real workspaceWidth: {
        if (!monitorData) return 800;
        const isRotated = (monitorData.transform % 2 === 1);
        const monitorScale = monitorData.scale || 1.0;
        const width = isRotated ? (monitor?.height || 1920) : (monitor?.width || 1920);
        let scaledWidth = (width / monitorScale) * scale;
        if (barPosition === "left" || barPosition === "right") {
            scaledWidth -= barReserved * scale;
        }
        return Math.max(0, Math.round(scaledWidth * 3));  // Triple width
    }

    readonly property real workspaceHeight: {
        if (!monitorData) return 150;
        const isRotated = (monitorData.transform % 2 === 1);
        const monitorScale = monitorData.scale || 1.0;
        const height = isRotated ? (monitor?.width || 1080) : (monitor?.height || 1080);
        let scaledHeight = (height / monitorScale) * scale;
        if (barPosition === "top" || barPosition === "bottom") {
            scaledHeight -= barReserved * scale;
        }
        return Math.max(0, Math.round(scaledHeight + workspacePadding * 2));
    }

    // Dragging state
    property int draggingFromWorkspace: -1
    property int draggingTargetWorkspace: -1

    // Calculate which workspace is at a given Y position (relative to flickable content)
    function getWorkspaceAtY(globalY) {
        // Convert global Y to content Y (accounting for flickable position and margins)
        const flickableGlobalY = workspaceFlickable.mapToItem(null, 0, 0).y;
        const contentY = globalY - flickableGlobalY + workspaceFlickable.contentY;
        
        // Calculate workspace index
        const wsIndex = Math.floor(contentY / workspaceRowHeight);
        if (wsIndex >= 0 && wsIndex < totalWorkspaces) {
            return wsIndex + 1;  // Workspace IDs are 1-based
        }
        return -1;
    }

    // Size for the overview
    implicitWidth: workspaceWidth + workspacePadding * 2
    implicitHeight: workspaceHeight * 3 + workspaceSpacing * 3

    // Expose flickable for external scrollbar
    property alias flickable: workspaceFlickable
    readonly property bool needsScrollbar: workspaceFlickable.contentHeight > workspaceFlickable.height

    // Track if user is manually scrolling (set externally by scrollbar)
    property bool isManualScrolling: false

    // Calculate target scroll position to center active workspace
    readonly property int activeWorkspaceId: monitor?.activeWorkspace?.id || 1
    readonly property real workspaceRowHeight: workspaceHeight + workspaceSpacing

    // Scroll to center active workspace when it changes
    onActiveWorkspaceIdChanged: workspaceFlickable.scrollToActiveWorkspace()

    // Vertical flickable containing all workspaces
    Flickable {
        id: workspaceFlickable
        anchors.fill: parent
        anchors.margins: workspacePadding
        contentWidth: width
        contentHeight: workspaceColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        Behavior on contentY {
            enabled: Config.animDuration > 0 && !scrollingOverviewRoot.isManualScrolling
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutQuart
            }
        }

        Component.onCompleted: scrollToActiveWorkspace()

        function scrollToActiveWorkspace() {
            const targetY = (scrollingOverviewRoot.activeWorkspaceId - 1) * scrollingOverviewRoot.workspaceRowHeight;
            const centeredY = targetY - (height - workspaceHeight) / 2;
            contentY = Math.max(0, Math.min(centeredY, contentHeight - height));
        }

        // Content item containing workspaces and indicator
        Item {
            id: contentItem
            width: parent.width
            height: workspaceColumn.implicitHeight

            Column {
                id: workspaceColumn
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: workspaceSpacing

                Repeater {
                    model: totalWorkspaces
                    delegate: ScrollingWorkspace {
                        id: scrollingWorkspace
                        required property int index
                        workspaceId: index + 1
                        workspaceWidth: scrollingOverviewRoot.workspaceWidth
                        workspaceHeight: scrollingOverviewRoot.workspaceHeight
                        workspacePadding: scrollingOverviewRoot.workspacePadding
                        scale_: scrollingOverviewRoot.scale
                        monitorId: scrollingOverviewRoot.monitorId
                        monitorData: scrollingOverviewRoot.monitorData
                        barPosition: scrollingOverviewRoot.barPosition
                        barReserved: scrollingOverviewRoot.barReserved
                        windowList: scrollingOverviewRoot.windowList
                        isActive: (scrollingOverviewRoot.monitor?.activeWorkspace?.id || 0) === workspaceId
                        activeBorderColor: scrollingOverviewRoot.activeBorderColor
                        focusedWindowAddress: scrollingOverviewRoot.focusedWindowAddress

                        // Search integration
                        searchQuery: scrollingOverviewRoot.searchQuery
                        checkWindowMatched: scrollingOverviewRoot.isWindowMatched
                        checkWindowSelected: scrollingOverviewRoot.isWindowSelected

                        // Dragging - use bidirectional binding
                        draggingFromWorkspace: scrollingOverviewRoot.draggingFromWorkspace
                        onDraggingFromWorkspaceChanged: {
                            if (draggingFromWorkspace !== scrollingOverviewRoot.draggingFromWorkspace) {
                                scrollingOverviewRoot.draggingFromWorkspace = draggingFromWorkspace;
                            }
                        }
                        draggingTargetWorkspace: scrollingOverviewRoot.draggingTargetWorkspace
                        onDraggingTargetWorkspaceChanged: {
                            if (draggingTargetWorkspace !== scrollingOverviewRoot.draggingTargetWorkspace) {
                                scrollingOverviewRoot.draggingTargetWorkspace = draggingTargetWorkspace;
                            }
                        }

                        // Provide drag overlay reference
                        dragOverlay: dragOverlayItem
                        overviewRoot: scrollingOverviewRoot

                        width: scrollingOverviewRoot.workspaceWidth
                        height: scrollingOverviewRoot.workspaceHeight
                    }
                }
            }

            // Floating active workspace indicator (inside content, moves with scroll)
            Rectangle {
                id: focusedWorkspaceIndicator
                readonly property int activeWorkspaceId: scrollingOverviewRoot.monitor?.activeWorkspace?.id || 1
                
                x: 0
                y: (activeWorkspaceId - 1) * (workspaceHeight + workspaceSpacing)
                width: workspaceWidth
                height: workspaceHeight
                color: "transparent"
                radius: Styling.radius(1)
                border.width: 2
                border.color: scrollingOverviewRoot.activeBorderColor
                z: 10

                Behavior on y {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                }
            }
        }
    }

    // Drag overlay - windows being dragged are reparented here to escape clipping
    Item {
        id: dragOverlayItem
        anchors.fill: parent
        z: 1000
    }
}
