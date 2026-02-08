import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config

Item {
    id: root

    required property ShellScreen screen

    // These properties are bound from shell.qml
    property bool barEnabled: true
    property string barPosition: "top"
    property bool barPinned: true
    property int barSize: 0
    property int barOuterMargin: 0
    property bool containBar: false

    property bool dockEnabled: true
    property string dockPosition: "bottom"
    property bool dockPinned: true
    property int dockHeight: 0

    property bool frameEnabled: false
    property int frameThickness: 6

    // Force update when any state that affects reservation changes
    onBarEnabledChanged: updateAllZones()
    onBarPositionChanged: updateAllZones()
    onBarPinnedChanged: updateAllZones()
    onBarSizeChanged: updateAllZones()
    onBarOuterMarginChanged: updateAllZones()
    onContainBarChanged: updateAllZones()

    onDockEnabledChanged: updateAllZones()
    onDockPositionChanged: updateAllZones()
    onDockPinnedChanged: updateAllZones()
    onDockHeightChanged: updateAllZones()

    onFrameEnabledChanged: updateAllZones()
    onFrameThicknessChanged: updateAllZones()

    Connections {
        target: Config
        function onBarReadyChanged() {
            root.updateAllZones();
        }
    }

    readonly property int actualFrameSize: frameEnabled ? frameThickness : 0

    function getExtraZone(side) {
        if (!Config.barReady)
            return 0;

        // Base zone is frame (static area)
        // This is the area that remains even if panels are hidden, IF frame is enabled.
        let zone = actualFrameSize;

        // Bar zone - only reserve if pinned (static)
        if (barEnabled && barPosition === side && barPinned) {
            zone += barSize + barOuterMargin;

            // Add extra thickness if containing bar (only if frame is actually enabled)
            if (containBar && frameEnabled) {
                // When containing the bar, we add another frame thickness unit for the inner side.
                zone += actualFrameSize;
            }
        }

        // Dock zone - only reserve if pinned (static)
        if (dockEnabled && dockPosition === side && dockPinned) {
            zone += dockHeight;
        }

        return zone;
    }

    function getExclusionMode(side) {
        return getExtraZone(side) > 0 ? ExclusionMode.Normal : ExclusionMode.Ignore;
    }

    // Use a timer to debounce updates and avoid rapid toggle desync
    Timer {
        id: updateTimer
        interval: 10
        repeat: false
        onTriggered: performUpdate()
    }

    function updateAllZones() {
        updateTimer.restart();
    }

    function performUpdate() {
        const newTop = getExtraZone("top");
        const newBottom = getExtraZone("bottom");
        const newLeft = getExtraZone("left");
        const newRight = getExtraZone("right");

        const newTopMode = getExclusionMode("top");
        const newBottomMode = getExclusionMode("bottom");
        const newLeftMode = getExclusionMode("left");
        const newRightMode = getExclusionMode("right");

        // Apply changes only if they differ from current state
        if (topWindow.exclusiveZone !== newTop)
            topWindow.exclusiveZone = newTop;
        if (bottomWindow.exclusiveZone !== newBottom)
            bottomWindow.exclusiveZone = newBottom;
        if (leftWindow.exclusiveZone !== newLeft)
            leftWindow.exclusiveZone = newLeft;
        if (rightWindow.exclusiveZone !== newRight)
            rightWindow.exclusiveZone = newRight;

        if (topWindow.exclusionMode !== newTopMode)
            topWindow.exclusionMode = newTopMode;
        if (bottomWindow.exclusionMode !== newBottomMode)
            bottomWindow.exclusionMode = newBottomMode;
        if (leftWindow.exclusionMode !== newLeftMode)
            leftWindow.exclusionMode = newLeftMode;
        if (rightWindow.exclusionMode !== newRightMode)
            rightWindow.exclusionMode = newRightMode;

        console.log(`ReservationWindows [${screen.name}]: Zones updated - T:${newTop} B:${newBottom} L:${newLeft} R:${newRight}`);
    }

    Item {
        id: noInputRegion
        width: 0
        height: 0
        visible: false
    }

    PanelWindow {
        id: topWindow
        screen: root.screen
        visible: true
        implicitHeight: 1
        color: "transparent"
        anchors {
            left: true
            right: true
            top: true
        }
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "ambxst:reservation:top"
        exclusionMode: root.getExclusionMode("top")
        exclusiveZone: root.getExtraZone("top")
        mask: Region {
            item: noInputRegion
        }
    }

    PanelWindow {
        id: bottomWindow
        screen: root.screen
        visible: true
        implicitHeight: 1
        color: "transparent"
        anchors {
            left: true
            right: true
            bottom: true
        }
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "ambxst:reservation:bottom"
        exclusionMode: root.getExclusionMode("bottom")
        exclusiveZone: root.getExtraZone("bottom")
        mask: Region {
            item: noInputRegion
        }
    }

    PanelWindow {
        id: leftWindow
        screen: root.screen
        visible: true
        implicitWidth: 1
        color: "transparent"
        anchors {
            top: true
            bottom: true
            left: true
        }
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "ambxst:reservation:left"
        exclusionMode: root.getExclusionMode("left")
        exclusiveZone: root.getExtraZone("left")
        mask: Region {
            item: noInputRegion
        }
    }

    PanelWindow {
        id: rightWindow
        screen: root.screen
        visible: true
        implicitWidth: 1
        color: "transparent"
        anchors {
            top: true
            bottom: true
            right: true
        }
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "ambxst:reservation:right"
        exclusionMode: root.getExclusionMode("right")
        exclusiveZone: root.getExtraZone("right")
        mask: Region {
            item: noInputRegion
        }
    }
}
