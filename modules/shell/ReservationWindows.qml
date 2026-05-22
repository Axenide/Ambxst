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

    readonly property int actualFrameSize: frameEnabled ? frameThickness : 0

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
        implicitHeight: Math.max(1, exclusiveZone)
        color: "transparent"
        anchors {
            left: true
            right: true
            top: true
        }
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "ambxst:reservation:top"
        
        exclusiveZone: {
            if (!Config.barReady) return 0;
            let zone = actualFrameSize;
            if (barEnabled && barPosition === "top" && barPinned) {
                zone += barSize + barOuterMargin;
                if (containBar && frameEnabled) zone += actualFrameSize;
            }
            if (dockEnabled && dockPosition === "top" && dockPinned) zone += dockHeight;
            return zone;
        }
        exclusionMode: exclusiveZone > 0 ? ExclusionMode.Normal : ExclusionMode.Ignore

        mask: Region {
            item: noInputRegion
        }
    }

    PanelWindow {
        id: bottomWindow
        screen: root.screen
        visible: true
        implicitHeight: Math.max(1, exclusiveZone)
        color: "transparent"
        anchors {
            left: true
            right: true
            bottom: true
        }
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "ambxst:reservation:bottom"

        exclusiveZone: {
            if (!Config.barReady) return 0;
            let zone = actualFrameSize;
            if (barEnabled && barPosition === "bottom" && barPinned) {
                zone += barSize + barOuterMargin;
                if (containBar && frameEnabled) zone += actualFrameSize;
            }
            if (dockEnabled && dockPosition === "bottom" && dockPinned) zone += dockHeight;
            return zone;
        }
        exclusionMode: exclusiveZone > 0 ? ExclusionMode.Normal : ExclusionMode.Ignore

        mask: Region {
            item: noInputRegion
        }
    }

    PanelWindow {
        id: leftWindow
        screen: root.screen
        visible: true
        implicitWidth: Math.max(1, exclusiveZone)
        color: "transparent"
        anchors {
            top: true
            bottom: true
            left: true
        }
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "ambxst:reservation:left"

        exclusiveZone: {
            if (!Config.barReady) return 0;
            let zone = actualFrameSize;
            if (barEnabled && barPosition === "left" && barPinned) {
                zone += barSize + barOuterMargin;
                if (containBar && frameEnabled) zone += actualFrameSize;
            }
            if (dockEnabled && dockPosition === "left" && dockPinned) zone += dockHeight;
            return zone;
        }
        exclusionMode: exclusiveZone > 0 ? ExclusionMode.Normal : ExclusionMode.Ignore

        mask: Region {
            item: noInputRegion
        }
    }

    PanelWindow {
        id: rightWindow
        screen: root.screen
        visible: true
        implicitWidth: Math.max(1, exclusiveZone)
        color: "transparent"
        anchors {
            top: true
            bottom: true
            right: true
        }
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "ambxst:reservation:right"

        exclusiveZone: {
            if (!Config.barReady) return 0;
            let zone = actualFrameSize;
            if (barEnabled && barPosition === "right" && barPinned) {
                zone += barSize + barOuterMargin;
                if (containBar && frameEnabled) zone += actualFrameSize;
            }
            if (dockEnabled && dockPosition === "right" && dockPinned) zone += dockHeight;
            return zone;
        }
        exclusionMode: exclusiveZone > 0 ? ExclusionMode.Normal : ExclusionMode.Ignore

        mask: Region {
            item: noInputRegion
        }
    }
}
