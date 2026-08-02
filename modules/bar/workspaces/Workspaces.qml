import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.globals
import qs.config

Item {
    id: workspacesWidget
    required property var bar
    required property string orientation
    readonly property var monitor: AxctlService.monitorFor(bar.screen)
    readonly property Toplevel activeWindow: ToplevelManager.activeToplevel

    readonly property int workspaceGroup: Math.floor(((monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : undefined) - 1 || 0) / Config.workspaces.shown)
    property var workspaceOccupied: []
    property var dynamicWorkspaceIds: []
    property int effectiveWorkspaceCount: Config.workspaces.dynamic ? dynamicWorkspaceIds.length : Config.workspaces.shown
    property int widgetPadding: 4
    property real radius: Styling.radius(0)
    property real startRadius: radius
    property real endRadius: radius
    
    property int baseSize: 36
    property int workspaceButtonSize: baseSize - widgetPadding * 2
    property int workspaceButtonWidth: workspaceButtonSize
    property real workspaceIconSize: Math.round(workspaceButtonWidth * 0.6)
    property real workspaceIconSizeShrinked: Math.round(workspaceButtonWidth * 0.5)
    property real workspaceIconOpacityShrinked: 1
    property real workspaceIconMarginShrinked: -4
    property int workspaceIndexInGroup: Config.workspaces.dynamic ? dynamicWorkspaceIds.indexOf((monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : undefined) || 1) : ((monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : undefined) - 1 || 0) % Config.workspaces.shown
    property var occupiedRanges: []

    function updateWorkspaceOccupied() {
        if (Config.workspaces.dynamic) {
            // Get occupied workspace IDs using the precomputed occupation map, sorted and limited by 'shown'
            const occupiedIds = AxctlService.workspaces.values.filter(ws => CompositorData.workspaceOccupationMap[ws.id]).map(ws => ws.id).sort((a, b) => a - b).slice(0, Config.workspaces.shown);

            // Always include active workspace, even if empty
            const activeId = (monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : undefined) || 1;
            if (!occupiedIds.includes(activeId)) {
                occupiedIds.push(activeId);
                occupiedIds.sort((a, b) => a - b);
                if (occupiedIds.length > Config.workspaces.shown) {
                    occupiedIds.pop();
                }
            }

            // Short-circuit: this recomputes up to 10x/sec from compositor
            // events; don't churn the Repeaters/Behaviors when nothing changed.
            if (!_sameArray(dynamicWorkspaceIds, occupiedIds))
                dynamicWorkspaceIds = occupiedIds;
            const occupied = Array.from({
                length: dynamicWorkspaceIds.length
            }, (_, i) => CompositorData.workspaceOccupationMap[dynamicWorkspaceIds[i]]);
            if (!_sameArray(workspaceOccupied, occupied))
                workspaceOccupied = occupied;
        } else {
            const occupied = Array.from({
                length: Config.workspaces.shown
            }, (_, i) => {
                const wsId = workspaceGroup * Config.workspaces.shown + i + 1;
                return CompositorData.workspaceOccupationMap[wsId];
            });
            if (!_sameArray(workspaceOccupied, occupied))
                workspaceOccupied = occupied;
        }
        updateOccupiedRanges();
    }

    function _sameArray(a, b) {
        if (a === b) return true;
        if (!a || !b || a.length !== b.length) return false;
        for (let i = 0; i < a.length; i++) {
            if (a[i] !== b[i]) return false;
        }
        return true;
    }

    function updateOccupiedRanges() {
        const ranges = [];
        let rangeStart = -1;

        for (let i = 0; i < effectiveWorkspaceCount; i++) {
            const isOccupied = workspaceOccupied[i];

            if (isOccupied) {
                if (rangeStart === -1) {
                    rangeStart = i;
                }
            } else {
                if (rangeStart !== -1) {
                    ranges.push({
                        start: rangeStart,
                        end: i - 1
                    });
                    rangeStart = -1;
                }
            }
        }

        if (rangeStart !== -1) {
            ranges.push({
                start: rangeStart,
                end: effectiveWorkspaceCount - 1
            });
        }

        // Avoid churning the range-highlight Repeater (6 Behaviors per item)
        // when the computed ranges didn't actually change.
        if (!_sameArray(occupiedRanges, ranges))
            occupiedRanges = ranges;
    }

    function workspaceLabelFontSize(value) {
        const label = String(value);
        const shrink = label.length > 1 && label !== "10" ? (label.length - 1) * 2 : 0;
        return Math.round(Math.max(1, Config.theme.fontSize - shrink));
    }

    function getWorkspaceId(index) {
        if (Config.workspaces.dynamic) {
            return dynamicWorkspaceIds[index] || 1;
        }
        return workspaceGroup * Config.workspaces.shown + index + 1;
    }

    Timer {
        id: updateTimer
        interval: 100
        repeat: false
        onTriggered: workspacesWidget.updateWorkspaceOccupied()
    }

    // Initial update
    Component.onCompleted: updateTimer.restart()

    Connections {
        target: AxctlService.workspaces
        function onValuesChanged() {
            updateTimer.restart();
        }
    }

    Connections {
        target: activeWindow
        function onActivatedChanged() {
            updateTimer.restart();
        }
    }

    Connections {
        target: CompositorData
        function onWindowListChanged() {
            updateTimer.restart();
        }
    }

    onWorkspaceGroupChanged: {
        updateTimer.restart();
    }

    implicitWidth: orientation === "vertical" ? baseSize : workspaceButtonSize * effectiveWorkspaceCount + widgetPadding * 2
    implicitHeight: orientation === "vertical" ? workspaceButtonSize * effectiveWorkspaceCount + widgetPadding * 2 : baseSize

    readonly property bool effectiveContainBar: Config.bar.containBar && ((Config.bar.frameEnabled !== undefined ? Config.bar.frameEnabled : false))

    StyledRect {
        id: bgRect
        variant: "bg"
        anchors.fill: parent
        enableShadow: Config.showBackground && (!effectiveContainBar || Config.bar.keepBarShadow)
        
        topLeftRadius: orientation === "vertical" ? workspacesWidget.startRadius : workspacesWidget.startRadius
        topRightRadius: orientation === "vertical" ? workspacesWidget.startRadius : workspacesWidget.endRadius
        bottomLeftRadius: orientation === "vertical" ? workspacesWidget.endRadius : workspacesWidget.startRadius
        bottomRightRadius: orientation === "vertical" ? workspacesWidget.endRadius : workspacesWidget.endRadius
    }

    WheelHandler {
        onWheel: event => {
            if (event.angleDelta.y < 0)
                AxctlService.dispatch(`workspace r+1`);
            else if (event.angleDelta.y > 0)
                AxctlService.dispatch(`workspace r-1`);
        }
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.BackButton
        onPressed: event => {
            if (event.button === Qt.BackButton) {
                AxctlService.dispatch(`togglespecialworkspace`);
            }
        }
    }

    Item {
        id: rangesLayer
        z: 1

        anchors.fill: parent
        anchors.margins: widgetPadding

        Repeater {
            model: occupiedRanges

            StyledRect {
                variant: "focus"
                required property int index
                required property var modelData
                z: 1
                width: workspacesWidget.orientation === "vertical" ? workspaceButtonWidth : (modelData.end - modelData.start + 1) * workspaceButtonWidth
                height: workspacesWidget.orientation === "vertical" ? (modelData.end - modelData.start + 1) * workspaceButtonWidth : workspaceButtonWidth

                radius: workspacesWidget.startRadius > 0 ? Math.max(workspacesWidget.startRadius - widgetPadding, 0) : 0

                opacity: Config.theme.srFocus.opacity

                x: workspacesWidget.orientation === "vertical" ? 0 : modelData.start * workspaceButtonWidth
                y: workspacesWidget.orientation === "vertical" ? modelData.start * workspaceButtonWidth : 0

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Math.max(0, Config.animDuration - 100)
                        easing.type: Styling.animEasing
                    }
                }
                Behavior on x {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Math.max(0, Config.animDuration - 100)
                        easing.type: Styling.animEasing
                    }
                }
                Behavior on y {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Math.max(0, Config.animDuration - 100)
                        easing.type: Styling.animEasing
                    }
                }
                Behavior on width {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Math.max(0, Config.animDuration - 100)
                        easing.type: Styling.animEasing
                    }
                }
                Behavior on height {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Math.max(0, Config.animDuration - 100)
                        easing.type: Styling.animEasing
                    }
                }
            }
        }
    }

    // Active workspace highlight (stretchy transition via two animated indices)
    StyledRect {
        id: activeHighlight
        variant: "primary"
        z: 2
        property real activeWorkspaceMargin: 4
        // Two animated indices to create a stretchy transition effect
        property real idx1: workspaceIndexInGroup
        property real idx2: workspaceIndexInGroup

        implicitWidth: orientation === "vertical" ? workspaceButtonWidth - activeWorkspaceMargin * 2 : Math.abs(idx1 - idx2) * workspaceButtonWidth + workspaceButtonWidth - activeWorkspaceMargin * 2
        implicitHeight: orientation === "vertical" ? Math.abs(idx1 - idx2) * workspaceButtonWidth + workspaceButtonWidth - activeWorkspaceMargin * 2 : workspaceButtonWidth - activeWorkspaceMargin * 2

        radius: {
            const activeWorkspaceId = (monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : undefined) || 1;
            const currentWorkspaceHasWindows = CompositorData.workspaceOccupationMap[activeWorkspaceId];
            if (workspacesWidget.radius === 0)
                return 0;
            return currentWorkspaceHasWindows ? workspacesWidget.radius > 0 ? Math.max(workspacesWidget.radius - widgetPadding - activeWorkspaceMargin, 0) : 0 : Math.min(implicitWidth, implicitHeight) / 2;
        }

        anchors.verticalCenter: orientation === "horizontal" ? parent.verticalCenter : undefined
        anchors.horizontalCenter: orientation === "vertical" ? parent.horizontalCenter : undefined

        x: orientation === "vertical" ? parent.width / 2 - implicitWidth / 2 : Math.min(idx1, idx2) * workspaceButtonWidth + activeWorkspaceMargin + widgetPadding
        y: orientation === "vertical" ? Math.min(idx1, idx2) * workspaceButtonWidth + activeWorkspaceMargin + widgetPadding : parent.height / 2 - implicitHeight / 2

        Behavior on activeWorkspaceMargin {

            enabled: Config.animDuration > 0

            NumberAnimation {
                duration: Config.animDuration / 2
                easing.type: Styling.animEasing
            }
        }
        Behavior on idx1 {

            enabled: Config.animDuration > 0

            NumberAnimation {
                duration: Config.animDuration / 3
                easing.type: Styling.animEasing
            }
        }
        Behavior on idx2 {

            enabled: Config.animDuration > 0

            NumberAnimation {
                duration: Config.animDuration
                easing.type: Styling.animEasing
            }
        }
    }

    RowLayout {
        id: rowLayoutNumbers
        visible: orientation === "horizontal"
        z: 3

        spacing: 0
        anchors.fill: parent
        anchors.margins: widgetPadding
        implicitHeight: workspaceButtonWidth

        Repeater {
            model: effectiveWorkspaceCount

            WorkspaceButton {
                workspaceValue: getWorkspaceId(index)
                occupied: workspaceOccupied[index]
                active: (monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : undefined) == getWorkspaceId(index)
                buttonWidth: workspaceButtonWidth
                iconSize: workspaceIconSize
                iconSizeShrinked: workspaceIconSizeShrinked
                iconOpacityShrinked: workspaceIconOpacityShrinked
                iconMarginShrinked: workspaceIconMarginShrinked
                labelFontSize: workspaceLabelFontSize
                Layout.fillHeight: true
                width: workspaceButtonWidth
                onClicked: AxctlService.dispatch(`workspace ${workspaceValue}`)
            }
        }
    }

    ColumnLayout {
        id: columnLayoutNumbers
        visible: orientation === "vertical"
        z: 3

        spacing: 0
        anchors.fill: parent
        anchors.margins: widgetPadding
        implicitWidth: workspaceButtonWidth

        Repeater {
            model: effectiveWorkspaceCount

            WorkspaceButton {
                workspaceValue: getWorkspaceId(index)
                occupied: workspaceOccupied[index]
                active: (monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : undefined) == getWorkspaceId(index)
                buttonWidth: workspaceButtonWidth
                iconSize: workspaceIconSize
                iconSizeShrinked: workspaceIconSizeShrinked
                iconOpacityShrinked: workspaceIconOpacityShrinked
                iconMarginShrinked: workspaceIconMarginShrinked
                labelFontSize: workspaceLabelFontSize
                Layout.fillWidth: true
                height: workspaceButtonWidth
                onClicked: AxctlService.dispatch(`workspace ${workspaceValue}`)
            }
        }
    }
}
