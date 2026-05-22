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

            dynamicWorkspaceIds = occupiedIds;
            workspaceOccupied = Array.from({
                length: dynamicWorkspaceIds.length
            }, (_, i) => CompositorData.workspaceOccupationMap[dynamicWorkspaceIds[i]]);
        } else {
            workspaceOccupied = Array.from({
                length: Config.workspaces.shown
            }, (_, i) => {
                const wsId = workspaceGroup * Config.workspaces.shown + i + 1;
                return CompositorData.workspaceOccupationMap[wsId];
            });
        }
        updateOccupiedRanges();
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
        id: rowLayout
        visible: orientation === "horizontal"
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
                width: (modelData.end - modelData.start + 1) * workspaceButtonWidth
                height: workspaceButtonWidth

                radius: workspacesWidget.startRadius > 0 ? Math.max(workspacesWidget.startRadius - widgetPadding, 0) : 0

                opacity: Config.theme.srFocus.opacity

                x: modelData.start * workspaceButtonWidth
                y: 0

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Math.max(0, Config.animDuration - 100)
                        easing.type: Easing.OutQuad
                    }
                }
                Behavior on x {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Math.max(0, Config.animDuration - 100)
                        easing.type: Easing.OutQuad
                    }
                }
                Behavior on width {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Math.max(0, Config.animDuration - 100)
                        easing.type: Easing.OutQuad
                    }
                }
            }
        }
    }

    Item {
        id: columnLayout
        visible: orientation === "vertical"
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
                width: workspaceButtonWidth
                height: (modelData.end - modelData.start + 1) * workspaceButtonWidth

                radius: workspacesWidget.startRadius > 0 ? Math.max(workspacesWidget.startRadius - widgetPadding, 0) : 0

                opacity: Config.theme.srFocus.opacity

                x: 0
                y: modelData.start * workspaceButtonWidth

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Math.max(0, Config.animDuration - 100)
                        easing.type: Easing.OutQuad
                    }
                }
                Behavior on y {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Math.max(0, Config.animDuration - 100)
                        easing.type: Easing.OutQuad
                    }
                }
                Behavior on height {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Math.max(0, Config.animDuration - 100)
                        easing.type: Easing.OutQuad
                    }
                }
            }
        }
    }

    // Horizontal active workspace highlight
    StyledRect {
        id: activeHighlightH
        variant: "primary"
        visible: orientation === "horizontal"
        z: 2
        property real activeWorkspaceMargin: 4
        // Two animated indices to create a stretchy transition effect
        property real idx1: workspaceIndexInGroup
        property real idx2: workspaceIndexInGroup

        implicitWidth: Math.abs(idx1 - idx2) * workspaceButtonWidth + workspaceButtonWidth - activeWorkspaceMargin * 2
        implicitHeight: workspaceButtonWidth - activeWorkspaceMargin * 2

        radius: {
            const activeWorkspaceId = (monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : undefined) || 1;
            const currentWorkspaceHasWindows = CompositorData.workspaceOccupationMap[activeWorkspaceId];
            if (workspacesWidget.radius === 0)
                return 0;
            return currentWorkspaceHasWindows ? workspacesWidget.radius > 0 ? Math.max(workspacesWidget.radius - parent.widgetPadding - activeWorkspaceMargin, 0) : 0 : implicitHeight / 2;
        }

        anchors.verticalCenter: parent.verticalCenter

        x: Math.min(idx1, idx2) * workspaceButtonWidth + activeWorkspaceMargin + widgetPadding
        y: parent.height / 2 - implicitHeight / 2

        Behavior on activeWorkspaceMargin {

            enabled: Config.animDuration > 0

            NumberAnimation {
                duration: Config.animDuration / 2
                easing.type: Easing.OutQuad
            }
        }
        Behavior on idx1 {

            enabled: Config.animDuration > 0

            NumberAnimation {
                duration: Config.animDuration / 3
                easing.type: Easing.OutSine
            }
        }
        Behavior on idx2 {

            enabled: Config.animDuration > 0

            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutSine
            }
        }
    }

    // Vertical active workspace highlight
    StyledRect {
        id: activeHighlightV
        variant: "primary"
        visible: orientation === "vertical"
        z: 2
        property real activeWorkspaceMargin: 4
        // Two animated indices to create a stretchy transition effect
        property real idx1: workspaceIndexInGroup
        property real idx2: workspaceIndexInGroup

        implicitWidth: workspaceButtonWidth - activeWorkspaceMargin * 2
        implicitHeight: Math.abs(idx1 - idx2) * workspaceButtonWidth + workspaceButtonWidth - activeWorkspaceMargin * 2

        radius: {
            const activeWorkspaceId = (monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : undefined) || 1;
            const currentWorkspaceHasWindows = CompositorData.workspaceOccupationMap[activeWorkspaceId];
            if (workspacesWidget.radius === 0)
                return 0;
            return currentWorkspaceHasWindows ? workspacesWidget.radius > 0 ? Math.max(workspacesWidget.radius - parent.widgetPadding - activeWorkspaceMargin, 0) : 0 : implicitWidth / 2;
        }

        anchors.horizontalCenter: parent.horizontalCenter

        x: parent.width / 2 - implicitWidth / 2
        y: Math.min(idx1, idx2) * workspaceButtonWidth + activeWorkspaceMargin + widgetPadding

        Behavior on activeWorkspaceMargin {

            enabled: Config.animDuration > 0

            NumberAnimation {
                duration: Config.animDuration / 2
                easing.type: Easing.OutQuad
            }
        }
        Behavior on idx1 {

            enabled: Config.animDuration > 0

            NumberAnimation {
                duration: Config.animDuration / 3
                easing.type: Easing.OutSine
            }
        }
        Behavior on idx2 {

            enabled: Config.animDuration > 0

            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutSine
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

            Button {
                id: button
                property int workspaceValue: getWorkspaceId(index)
                Layout.fillHeight: true
                onPressed: AxctlService.dispatch(`workspace ${workspaceValue}`)
                width: workspaceButtonWidth

                background: Item {
                    id: workspaceButtonBackground
                    implicitWidth: workspaceButtonWidth
                    implicitHeight: workspaceButtonWidth
                    property var focusedWindow: {
                        const windowsInThisWorkspace = CompositorData.workspaceWindowsMap[button.workspaceValue] || [];
                        if (windowsInThisWorkspace.length === 0)
                            return null;
                        // Get the window with the lowest focusHistoryID (most recently focused)
                        return windowsInThisWorkspace.reduce((best, win) => {
                            const bestFocus = (best && best.focusHistoryID !== undefined ? best.focusHistoryID : Infinity);
                            const winFocus = (win && win.focusHistoryID !== undefined ? win.focusHistoryID : Infinity);
                            return winFocus < bestFocus ? win : best;
                        }, null);
                    }
                    readonly property var focusedDesktopEntry: focusedWindow ? DesktopEntries.heuristicLookup(focusedWindow.class) : null
                    property var mainAppIconSource: {
                        if (focusedDesktopEntry && focusedDesktopEntry.icon) {
                            return Quickshell.iconPath(focusedDesktopEntry.icon, "image-missing");
                        }
                        return Quickshell.iconPath(AppSearch.getCachedIcon(focusedWindow ? focusedWindow.class : undefined), "image-missing");
                    }

                    Text {
                        opacity: Config.workspaces.alwaysShowNumbers || ((Config.workspaces.showNumbers && (!Config.workspaces.showAppIcons || !workspaceButtonBackground.focusedWindow || Config.workspaces.alwaysShowNumbers)) || (Config.workspaces.alwaysShowNumbers && !Config.workspaces.showAppIcons)) ? 1 : 0
                        z: 3

                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.family: Config.theme.font
                        font.pixelSize: workspaceLabelFontSize(text)
                        text: `${button.workspaceValue}`
                        elide: Text.ElideRight
                        color: ((monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : undefined) == button.workspaceValue) ? Styling.srItem("primary") : (workspaceOccupied[index] ? Colors.overBackground : Colors.overSecondaryFixedVariant)

                        Behavior on opacity {
                            enabled: Config.animDuration > 0
                            NumberAnimation {
                                duration: 150
                                easing.type: Easing.OutQuad
                            }
                        }
                    }
                    Rectangle {
                        opacity: (Config.workspaces.showNumbers || Config.workspaces.alwaysShowNumbers || (Config.workspaces.showAppIcons && workspaceButtonBackground.focusedWindow)) ? 0 : (((monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : undefined) == button.workspaceValue) || workspaceOccupied[index] ? 1 : 0.5)
                        visible: opacity > 0
                        anchors.centerIn: parent
                        width: workspaceButtonWidth * 0.2
                        height: width
                        radius: width / 2
                        color: ((monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : undefined) == button.workspaceValue) ? Styling.srItem("primary") : Colors.overBackground

                        Behavior on opacity {
                            enabled: Config.animDuration > 0
                            NumberAnimation {
                                duration: 150
                                easing.type: Easing.OutQuad
                            }
                        }
                    }
                    Item {
                        anchors.centerIn: parent
                        width: workspaceButtonWidth
                        height: workspaceButtonWidth
                        opacity: !Config.workspaces.showAppIcons ? 0 : (workspaceButtonBackground.focusedWindow && !Config.workspaces.alwaysShowNumbers && Config.workspaces.showAppIcons) ? 1 : workspaceButtonBackground.focusedWindow ? workspaceIconOpacityShrinked : 0
                        visible: opacity > 0
                        IconImage {
                            id: mainAppIcon
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            anchors.bottomMargin: (!Config.workspaces.alwaysShowNumbers && Config.workspaces.showAppIcons) ? Math.round((workspaceButtonWidth - workspaceIconSize) / 2) : workspaceIconMarginShrinked
                            anchors.rightMargin: (!Config.workspaces.alwaysShowNumbers && Config.workspaces.showAppIcons) ? Math.round((workspaceButtonWidth - workspaceIconSize) / 2) : workspaceIconMarginShrinked

                            source: workspaceButtonBackground.mainAppIconSource
                            implicitSize: (!Config.workspaces.alwaysShowNumbers && Config.workspaces.showAppIcons) ? workspaceIconSize : workspaceIconSizeShrinked

                            Behavior on opacity {
                                enabled: Config.animDuration > 0
                                NumberAnimation {
                                    duration: 150
                                    easing.type: Easing.OutQuad
                                }
                            }
                            Behavior on anchors.bottomMargin {
                                enabled: Config.animDuration > 0
                                NumberAnimation {
                                    duration: 150
                                    easing.type: Easing.OutQuad
                                }
                            }
                            Behavior on anchors.rightMargin {
                                enabled: Config.animDuration > 0
                                NumberAnimation {
                                    duration: 150
                                    easing.type: Easing.OutQuad
                                }
                            }
                            Behavior on implicitSize {
                                enabled: Config.animDuration > 0
                                NumberAnimation {
                                    duration: 150
                                    easing.type: Easing.OutQuad
                                }
                            }
                        }

                        Tinted {
                            sourceItem: mainAppIcon
                            anchors.fill: mainAppIcon
                        }
                    }
                }
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

            Button {
                id: buttonVert
                property int workspaceValue: getWorkspaceId(index)
                Layout.fillWidth: true
                onPressed: AxctlService.dispatch(`workspace ${workspaceValue}`)
                height: workspaceButtonWidth

                background: Item {
                    id: workspaceButtonBackgroundVert
                    implicitWidth: workspaceButtonWidth
                    implicitHeight: workspaceButtonWidth
                    property var focusedWindow: {
                        const windowsInThisWorkspace = CompositorData.workspaceWindowsMap[buttonVert.workspaceValue] || [];
                        if (windowsInThisWorkspace.length === 0)
                            return null;
                        // Get the window with the lowest focusHistoryID (most recently focused)
                        return windowsInThisWorkspace.reduce((best, win) => {
                            const bestFocus = (best && best.focusHistoryID !== undefined ? best.focusHistoryID : Infinity);
                            const winFocus = (win && win.focusHistoryID !== undefined ? win.focusHistoryID : Infinity);
                            return winFocus < bestFocus ? win : best;
                        }, null);
                    }
                    readonly property var focusedDesktopEntry: focusedWindow ? DesktopEntries.heuristicLookup(focusedWindow.class) : null
                    property var mainAppIconSource: {
                        if (focusedDesktopEntry && focusedDesktopEntry.icon) {
                            return Quickshell.iconPath(focusedDesktopEntry.icon, "image-missing");
                        }
                        return Quickshell.iconPath(AppSearch.getCachedIcon(focusedWindow ? focusedWindow.class : undefined), "image-missing");
                    }

                    Text {
                        opacity: Config.workspaces.alwaysShowNumbers || ((Config.workspaces.showNumbers && (!Config.workspaces.showAppIcons || !workspaceButtonBackgroundVert.focusedWindow || Config.workspaces.alwaysShowNumbers)) || (Config.workspaces.alwaysShowNumbers && !Config.workspaces.showAppIcons)) ? 1 : 0
                        z: 3

                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.family: Config.theme.font
                        font.pixelSize: workspaceLabelFontSize(text)
                        text: `${buttonVert.workspaceValue}`
                        elide: Text.ElideRight
                        color: ((monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : undefined) == buttonVert.workspaceValue) ? Styling.srItem("primary") : (workspaceOccupied[index] ? Colors.overBackground : Colors.overSecondaryFixedVariant)

                        Behavior on opacity {
                            enabled: Config.animDuration > 0
                            NumberAnimation {
                                duration: 150
                                easing.type: Easing.OutQuad
                            }
                        }
                    }
                    Rectangle {
                        opacity: (Config.workspaces.showNumbers || Config.workspaces.alwaysShowNumbers || (Config.workspaces.showAppIcons && workspaceButtonBackgroundVert.focusedWindow)) ? 0 : (((monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : undefined) == buttonVert.workspaceValue) || workspaceOccupied[index] ? 1 : 0.5)
                        visible: opacity > 0
                        anchors.centerIn: parent
                        width: workspaceButtonWidth * 0.2
                        height: width
                        radius: width / 2
                        color: ((monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : undefined) == buttonVert.workspaceValue) ? Styling.srItem("primary") : Colors.overBackground

                        Behavior on opacity {
                            enabled: Config.animDuration > 0
                            NumberAnimation {
                                duration: 150
                                easing.type: Easing.OutQuad
                            }
                        }
                    }
                    Item {
                        anchors.centerIn: parent
                        width: workspaceButtonWidth
                        height: workspaceButtonWidth
                        opacity: !Config.workspaces.showAppIcons ? 0 : (workspaceButtonBackgroundVert.focusedWindow && !Config.workspaces.alwaysShowNumbers && Config.workspaces.showAppIcons) ? 1 : workspaceButtonBackgroundVert.focusedWindow ? workspaceIconOpacityShrinked : 0
                        visible: opacity > 0
                        IconImage {
                            id: mainAppIconVert
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            anchors.bottomMargin: (!Config.workspaces.alwaysShowNumbers && Config.workspaces.showAppIcons) ? Math.round((workspaceButtonWidth - workspaceIconSize) / 2) : workspaceIconMarginShrinked
                            anchors.rightMargin: (!Config.workspaces.alwaysShowNumbers && Config.workspaces.showAppIcons) ? Math.round((workspaceButtonWidth - workspaceIconSize) / 2) : workspaceIconMarginShrinked

                            source: workspaceButtonBackgroundVert.mainAppIconSource
                            implicitSize: (!Config.workspaces.alwaysShowNumbers && Config.workspaces.showAppIcons) ? workspaceIconSize : workspaceIconSizeShrinked

                            Behavior on opacity {
                                enabled: Config.animDuration > 0
                                NumberAnimation {
                                    duration: 150
                                    easing.type: Easing.OutQuad
                                }
                            }
                            Behavior on anchors.bottomMargin {
                                enabled: Config.animDuration > 0
                                NumberAnimation {
                                    duration: 150
                                    easing.type: Easing.OutQuad
                                }
                            }
                            Behavior on anchors.rightMargin {
                                enabled: Config.animDuration > 0
                                NumberAnimation {
                                    duration: 150
                                    easing.type: Easing.OutQuad
                                }
                            }
                            Behavior on implicitSize {
                                enabled: Config.animDuration > 0
                                NumberAnimation {
                                    duration: 150
                                    easing.type: Easing.OutQuad
                                }
                            }
                        }

                        Tinted {
                            sourceItem: mainAppIconVert
                            anchors.fill: mainAppIconVert
                        }
                    }
                }
            }
        }
    }
}
