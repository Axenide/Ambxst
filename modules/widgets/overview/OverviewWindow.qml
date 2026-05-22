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

        let base = (windowData?.at?.[0] || 0) - (monitorData?.x || 0);
        if (barPosition === "left")
            base -= barReserved;
        return Math.round(Math.max(base * scale, 0) + xOffset);
    }
    readonly property real initY: {
        if (useOverridePosition && overrideY >= 0)
            return overrideY;
        let base = (windowData?.at?.[1] || 0) - (monitorData?.y || 0);
        if (barPosition === "top")
            base -= barReserved;
        return Math.round(Math.max(base * scale, 0) + yOffset);
    }
    readonly property real targetWindowWidth: Math.round((windowData?.size[0] || 100) * scale)
    readonly property real targetWindowHeight: Math.round((windowData?.size[1] || 100) * scale)
    readonly property bool compactMode: targetWindowHeight < 60 || targetWindowWidth < 60
    readonly property string iconPath: AppSearch.guessIcon(windowData?.class || "")
    readonly property int calculatedRadius: Styling.radius(-2)

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

    // Watch for windowData changes to reset override when real data updates
    onWindowDataChanged: {
        if (useOverridePosition) {
            resetOverrideTimer.restart();
        }
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
    }

    // Background rectangle with rounded corners
    Rectangle {
        id: previewBackground
        anchors.fill: parent
        radius: root.calculatedRadius
        color: pressed ? Colors.surfaceBright : hovered ? Colors.surface : Colors.background
        border.color: root.isSearchSelected ? Colors.tertiary : root.isSearchMatch ? Styling.srItem("overprimary") : Styling.srItem("overprimary")
        border.width: root.isSearchSelected ? 3 : root.isSearchMatch ? 2 : (hovered ? 2 : 0)
        visible: !windowPreview.hasContent || !Config.performance.windowPreview

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
            // Only focus window on hover if it's in the current workspace
            if (root.windowData) {
                // Get current active workspace from AxctlService
                let currentWorkspace = AxctlService.focusedMonitor?.activeWorkspace?.id;
                let windowWorkspace = root.windowData?.workspace?.id;

                // Only focus if the window is in the current workspace
                if (currentWorkspace && windowWorkspace && currentWorkspace === windowWorkspace) {
                    AxctlService.dispatch(`focuswindow address:${windowData.address}`);
                }
            }
        }
        onExited: root.hovered = false

        onPressed: mouse => {
            root.pressed = true;
            root.Drag.active = true;
            root.Drag.source = root;
            root.dragStarted();
        }

        onReleased: mouse => {
            const overviewRoot = parent.parent.parent.parent;
            let targetWorkspace = overviewRoot.draggingTargetWorkspace;

            root.pressed = false;
            root.Drag.active = false;

            if (mouse.button === Qt.LeftButton) {
                // If targetWorkspace is -1, calculate it from current position
                if (targetWorkspace === -1) {
                    // Calculate which workspace we're over based on position
                    const workspaceColIndex = Math.floor((root.x - root.xOffset + root.availableWorkspaceWidth / 2) / (root.availableWorkspaceWidth + overviewRoot.workspacePadding + overviewRoot.workspaceSpacing));
                    const workspaceRowIndex = Math.floor((root.y - root.yOffset + root.availableWorkspaceHeight / 2) / (root.availableWorkspaceHeight + overviewRoot.workspacePadding + overviewRoot.workspaceSpacing));
                    
                    if (workspaceColIndex >= 0 && workspaceColIndex < overviewRoot.columns && 
                        workspaceRowIndex >= 0 && workspaceRowIndex < overviewRoot.rows) {
                        targetWorkspace = overviewRoot.workspaceGroup * overviewRoot.workspacesShown + 
                                        workspaceRowIndex * overviewRoot.columns + workspaceColIndex + 1;
                    } else {
                        // Out of bounds, default to current workspace
                        targetWorkspace = windowData?.workspace.id;
                    }
                }

                root.dragFinished(targetWorkspace);
                overviewRoot.draggingTargetWorkspace = -1;

                // Check if moving to different workspace
                if (targetWorkspace !== -1 && targetWorkspace !== windowData?.workspace.id) {
                    // Moving to different workspace
                    if (windowData?.floating && (root.x !== root.initX || root.y !== root.initY)) {
                        // Calculate position in the target workspace
                        // Get target workspace offset
                        const targetColIndex = (targetWorkspace - 1) % overviewRoot.columns;
                        const targetRowIndex = Math.floor((targetWorkspace - 1) % overviewRoot.workspacesShown / overviewRoot.columns);
                        const targetXOffset = Math.round((overviewRoot.workspaceImplicitWidth + overviewRoot.workspacePadding + overviewRoot.workspaceSpacing) * targetColIndex + overviewRoot.workspacePadding / 2);
                        const targetYOffset = Math.round((overviewRoot.workspaceImplicitHeight + overviewRoot.workspacePadding + overviewRoot.workspaceSpacing) * targetRowIndex + overviewRoot.workspacePadding / 2);
                        
                        // Calculate relative position in target workspace
                        const relativeX = root.x - targetXOffset;
                        const relativeY = root.y - targetYOffset;
                        
                        // Convert to percentage
                        const percentageX = Math.round((relativeX / root.availableWorkspaceWidth) * 100);
                        const percentageY = Math.round((relativeY / root.availableWorkspaceHeight) * 100);
                        
                        // Move to workspace and set position
                        AxctlService.dispatch(`movetoworkspacesilent ${targetWorkspace}, address:${windowData?.address}`);
                        AxctlService.dispatch(`movewindowpixel exact ${percentageX}% ${percentageY}%, address:${windowData?.address}`);
                        
                        // Force immediate window data update
                        CompositorData.updateWindowList();
                    } else {
                        // Just move workspace without repositioning
                        AxctlService.dispatch(`movetoworkspacesilent ${targetWorkspace}, address:${windowData?.address}`);
                        
                        // Force immediate window data update
                        CompositorData.updateWindowList();
                    }
                    
                    // Reset position in overview
                    root.x = root.initX;
                    root.y = root.initY;
                } else if (windowData?.floating && (root.x !== root.initX || root.y !== root.initY)) {
                    // Dropped on same workspace and floating - reposition
                    const relativeX = root.x - root.xOffset;
                    const relativeY = root.y - root.yOffset;
                    
                    const percentageX = Math.round((relativeX / root.availableWorkspaceWidth) * 100);
                    const percentageY = Math.round((relativeY / root.availableWorkspaceHeight) * 100);
                    
                    const draggedX = root.x;
                    const draggedY = root.y;
                    
                    AxctlService.dispatch(`movewindowpixel exact ${percentageX}% ${percentageY}%, address:${windowData?.address}`);
                    
                    // Force immediate window data update
                    CompositorData.updateWindowList();
                    
                    // Set override position for immediate visual update
                    root.overrideX = draggedX;
                    root.overrideY = draggedY;
                    root.useOverridePosition = true;
                    
                    root.x = draggedX;
                    root.y = draggedY;
                    
                    resetOverrideTimer.restart();
                } else {
                    // Reset position for non-floating or non-moved windows
                    root.x = root.initX;
                    root.y = root.initY;
                }
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
