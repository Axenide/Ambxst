import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
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
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(bar.screen)
    readonly property Toplevel activeWindow: ToplevelManager.activeToplevel

    readonly property int workspaceGroup: Math.floor((monitor?.activeWorkspace?.id - 1 || 0) / Config.workspaces.shown)
    property list<bool> workspaceOccupied: []
    property list<int> dynamicWorkspaceIds: []
    property int effectiveWorkspaceCount: Config.workspaces.dynamic ? dynamicWorkspaceIds.length : Config.workspaces.shown
    property int widgetPadding: 4
    property int baseSize: 36
    property int workspaceButtonSize: baseSize - widgetPadding * 2
    property int workspaceButtonWidth: workspaceButtonSize
    property real workspaceIconSize: Math.round(workspaceButtonWidth * 0.6)
    property real workspaceIconSizeShrinked: Math.round(workspaceButtonWidth * 0.5)
    property real workspaceIconOpacityShrinked: 1
    property real workspaceIconMarginShrinked: -4
    property int workspaceIndexInGroup: Config.workspaces.dynamic ? dynamicWorkspaceIds.indexOf(monitor?.activeWorkspace?.id || 1) : (monitor?.activeWorkspace?.id - 1 || 0) % Config.workspaces.shown
    property var occupiedRanges: []
    property list<string> specialWorkspaceNames: []
    property var specialEntries: []
    property list<bool> specialOccupied: []
    property var specialOccupiedRanges: []
    property int specialActiveIndex: -1
    property bool specialWorkspaceActive: false
    property string specialWorkspaceName: ""

    function updateWorkspaceOccupied() {
        if (Config.workspaces.dynamic) {
            // Get occupied workspace IDs, sorted and limited by 'shown'
            const occupiedIds = Hyprland.workspaces.values.filter(ws => HyprlandData.windowList.some(w => w.workspace.id === ws.id)).map(ws => ws.id).sort((a, b) => a - b).slice(0, Config.workspaces.shown);

            // Always include active workspace, even if empty
            const activeId = monitor?.activeWorkspace?.id || 1;
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
            }, (_, i) => HyprlandData.windowList.some(w => w.workspace.id === dynamicWorkspaceIds[i]));
        } else {
            workspaceOccupied = Array.from({
                length: Config.workspaces.shown
            }, (_, i) => {
                const wsId = workspaceGroup * Config.workspaces.shown + i + 1;
                return HyprlandData.windowList.some(w => w.workspace.id === wsId);
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

    function updateSpecialWorkspaces() {
        const activeSpecial = detectSpecialFromData() || specialWorkspaceName || "";
        const names = specialWorkspaceNames.slice();

        if (activeSpecial && names.indexOf(activeSpecial) === -1) {
            names.push(activeSpecial);
        }

        names.sort();
        const defaultIndex = names.indexOf("special");
        if (defaultIndex > 0) {
            names.splice(defaultIndex, 1);
            names.unshift("special");
        }
        specialWorkspaceNames = names;
        specialActiveIndex = activeSpecial.startsWith("special:") ? names.indexOf(activeSpecial) : -1;
        specialWorkspaceActive = activeSpecial.length > 0;
        specialEntries = buildSpecialEntries(names);
        specialOccupied = specialEntries.map(entry => (entry?.windows || []).length > 0);
        updateSpecialOccupiedRanges();
    }

    function buildSpecialEntries(names) {
        const map = {};
        for (let i = 0; i < names.length; i++) {
            map[names[i]] = [];
        }
        const windows = HyprlandData.windowList || [];
        for (let i = 0; i < windows.length; i++) {
            const wsName = windows[i]?.workspace?.name || "";
            if (!String(wsName).startsWith("special:"))
                continue;
            if (!map[wsName]) {
                map[wsName] = [];
            }
            map[wsName].push(windows[i]);
        }
        return names.map(name => ({
            name: name,
            windows: map[name] || []
        }));
    }

    function updateSpecialOccupiedRanges() {
        const ranges = [];
        let rangeStart = -1;

        for (let i = 0; i < specialOccupied.length; i++) {
            const isOccupied = specialOccupied[i];

            if (isOccupied) {
                if (rangeStart === -1)
                    rangeStart = i;
            } else if (rangeStart !== -1) {
                ranges.push({ start: rangeStart, end: i - 1 });
                rangeStart = -1;
            }
        }

        if (rangeStart !== -1) {
            ranges.push({ start: rangeStart, end: specialOccupied.length - 1 });
        }

        specialOccupiedRanges = ranges;
    }

    function detectSpecialFromData() {
        const monitors = HyprlandData.monitors || [];
        for (let i = 0; i < monitors.length; i++) {
            const ws = monitors[i]?.specialWorkspace || {};
            if (ws && ws.name) {
                return ws.name;
            }
        }
        return "";
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
        interval: 50
        repeat: false
        onTriggered: workspacesWidget.updateWorkspaceOccupied()
    }

    Process {
        id: specialMonitorProcess
        running: false
        command: ["/run/current-system/sw/bin/hyprctl", "-j", "monitors"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text || "[]");
                    const targetName = monitor?.name || "";
                    let specialName = "";
                    for (let i = 0; i < data.length; i++) {
                        const mon = data[i];
                        const ws = mon.specialWorkspace || {};
                        const name = ws?.name || "";
                        if (!name)
                            continue;
                        if (targetName && mon.name === targetName) {
                            specialName = name;
                            break;
                        }
                        if (!specialName) {
                            specialName = name;
                        }
                    }
                    specialWorkspaceName = specialName || "";
                    updateSpecialWorkspaces();
                } catch (e) {
                    console.warn("Workspaces: failed to parse hyprctl monitors", e);
                }
            }
        }
    }

    Timer {
        id: specialMonitorTimer
        interval: 500
        repeat: true
        running: true
        onTriggered: {
            if (!specialMonitorProcess.running) {
                specialMonitorProcess.running = true;
            }
        }
    }

    Process {
        id: specialWorkspacesProcess
        running: false
        command: ["/run/current-system/sw/bin/hyprctl", "-j", "workspaces"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text || "[]");
                    const names = [];
                    for (let i = 0; i < data.length; i++) {
                        const ws = data[i];
                        const name = ws?.name || "";
                        if (String(name).startsWith("special:") && names.indexOf(name) === -1) {
                            names.push(name);
                        }
                    }
                    specialWorkspaceNames = names;
                    updateSpecialWorkspaces();
                } catch (e) {
                    console.warn("Workspaces: failed to parse hyprctl workspaces", e);
                }
            }
        }
    }

    Timer {
        id: specialWorkspacesTimer
        interval: 500
        repeat: true
        running: true
        onTriggered: {
            if (!specialWorkspacesProcess.running) {
                specialWorkspacesProcess.running = true;
            }
        }
    }

    // Initial update
    Component.onCompleted: {
        updateTimer.restart();
        updateSpecialWorkspaces();
    }

    Connections {
        target: Hyprland.workspaces
        function onValuesChanged() {
            updateTimer.restart();
            updateSpecialWorkspaces();
        }
    }

    Connections {
        target: monitor
        function onActiveWorkspaceChanged() {
            updateTimer.restart();
            updateSpecialWorkspaces();
        }
    }

    Connections {
        target: activeWindow
        function onActivatedChanged() {
            updateTimer.restart();
        }
    }

    Connections {
        target: HyprlandData
        function onWindowListChanged() {
            updateTimer.restart();
            updateSpecialWorkspaces();
        }
    }

    onWorkspaceGroupChanged: {
        updateTimer.restart();
        updateSpecialWorkspaces();
    }

    implicitWidth: orientation === "vertical" ? baseSize : workspaceButtonSize * effectiveWorkspaceCount + widgetPadding * 2
    implicitHeight: orientation === "vertical" ? workspaceButtonSize * effectiveWorkspaceCount + widgetPadding * 2 : baseSize

    StyledRect {
        id: bgRect
        variant: "bg"
        anchors.fill: parent
        enableShadow: Config.showBackground
    }

    WheelHandler {
        onWheel: event => {
            if (specialWorkspaceActive && specialWorkspaceNames.length > 0) {
                const count = specialWorkspaceNames.length;
                const current = specialActiveIndex >= 0 ? specialActiveIndex : 0;
                const dir = event.angleDelta.y < 0 ? 1 : -1;
                const nextIndex = (current + dir + count) % count;
                const nextName = specialWorkspaceNames[nextIndex] || "";
                const shortName = nextName.startsWith("special:") ? nextName.slice(8) : nextName;
                if (shortName.length > 0)
                    Hyprland.dispatch(`togglespecialworkspace ${shortName}`);
            } else {
                if (event.angleDelta.y < 0)
                    Hyprland.dispatch(`workspace r+1`);
                else if (event.angleDelta.y > 0)
                    Hyprland.dispatch(`workspace r-1`);
            }
        }
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.BackButton
        onPressed: event => {
            if (event.button === Qt.BackButton) {
                Hyprland.dispatch(`togglespecialworkspace`);
            }
        }
    }

    Item {
        id: rowLayout
        visible: orientation === "horizontal"
        z: 1
        enabled: !specialWorkspaceActive

        anchors.fill: parent
        anchors.margins: Math.max(1, Math.round(widgetPadding / 2))

        scale: specialWorkspaceActive ? 0.85 : 1
        opacity: specialWorkspaceActive ? 0.6 : 1

        Behavior on scale {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutQuart
            }
        }
        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutQuart
            }
        }

        Repeater {
            model: occupiedRanges

            StyledRect {
                variant: "focus"
                required property int index
                required property var modelData
                z: 1
                width: (modelData.end - modelData.start + 1) * workspaceButtonWidth
                height: workspaceButtonWidth

                radius: Styling.radius(0) > 0 ? Math.max(Styling.radius(0) - widgetPadding, 0) : 0

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
        id: specialRowLayout
        visible: orientation === "horizontal" && specialWorkspaceActive
        z: 5
        opacity: specialWorkspaceActive ? 1 : 0
        anchors.fill: parent
        anchors.margins: Math.max(1, Math.round(widgetPadding / 2))

        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutQuart
            }
        }

        StyledRect {
            id: specialActiveIndicator
            variant: "primary"
            visible: specialActiveIndex >= 0
            z: 1
            width: workspaceButtonWidth * 0.5
            height: workspaceButtonWidth * 0.12
            radius: height / 2

            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.max(1, Math.round(workspaceButtonWidth * 0.08))
            x: specialActiveIndex * workspaceButtonWidth + (workspaceButtonWidth - width) / 2

            Behavior on x {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Math.max(0, Config.animDuration - 50)
                    easing.type: Easing.OutQuad
                }
            }
        }

        Repeater {
            model: specialOccupiedRanges

            StyledRect {
                variant: "focus"
                required property int index
                required property var modelData
                z: 0
                width: (modelData.end - modelData.start + 1) * workspaceButtonWidth
                height: workspaceButtonWidth

                radius: Styling.radius(0) > 0 ? Math.max(Styling.radius(0) - widgetPadding, 0) : 0
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

        RowLayout {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Repeater {
                model: specialWorkspaceNames.length

                Button {
                    id: specialButton
                    required property int index
                    property string workspaceName: specialWorkspaceNames[index] || ""
                    property string workspaceShort: workspaceName.startsWith("special:") ? workspaceName.slice(8) : workspaceName
                    property var focusedWindow: {
                        const windowsInThisWorkspace = specialEntries[index]?.windows || [];
                        if (windowsInThisWorkspace.length === 0)
                            return null;
                        return windowsInThisWorkspace.reduce((best, win) => {
                            const bestFocus = best?.focusHistoryID ?? Infinity;
                            const winFocus = win?.focusHistoryID ?? Infinity;
                            return winFocus < bestFocus ? win : best;
                        }, null);
                    }
                    property var mainAppIconSource: Quickshell.iconPath(AppSearch.getCachedIcon(focusedWindow?.class), "image-missing")
                    Layout.fillHeight: true
                    width: workspaceButtonWidth

                    onPressed: {
                        if (specialActiveIndex === index) {
                            Hyprland.dispatch(`togglespecialworkspace ${workspaceShort}`);
                        } else {
                            Hyprland.dispatch(`togglespecialworkspace ${workspaceShort}`);
                        }
                    }

                    background: Item {
                        implicitWidth: workspaceButtonWidth
                        implicitHeight: workspaceButtonWidth

                        Text {
                            opacity: Config.workspaces.alwaysShowNumbers || Config.workspaces.showNumbers ? 1 : 0
                            z: 3

                            anchors.centerIn: parent
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.family: Config.theme.font
                            font.pixelSize: workspaceLabelFontSize(text)
                            text: workspaceShort.length > 0 ? workspaceShort : `${index + 1}`
                            elide: Text.ElideRight
                            color: specialActiveIndex === index ? Styling.srItem("primary") : (specialEntries[index]?.windows?.length > 0 ? Colors.overBackground : Colors.overSecondaryFixedVariant)

                            Behavior on opacity {
                                enabled: Config.animDuration > 0
                                NumberAnimation {
                                    duration: 150
                                    easing.type: Easing.OutQuad
                                }
                            }
                        }

                        Rectangle {
                            opacity: (Config.workspaces.showNumbers || Config.workspaces.alwaysShowNumbers || (Config.workspaces.showAppIcons && focusedWindow)) ? 0 : ((specialActiveIndex === index) || (specialEntries[index]?.windows?.length > 0) ? 1 : 0.5)
                            visible: opacity > 0
                            anchors.centerIn: parent
                            width: workspaceButtonWidth * 0.2
                            height: width
                            radius: width / 2
                            color: specialActiveIndex === index ? Styling.srItem("primary") : Colors.overBackground

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
                            opacity: !Config.workspaces.showAppIcons ? 0 : (focusedWindow && !Config.workspaces.alwaysShowNumbers && Config.workspaces.showAppIcons) ? 1 : focusedWindow ? workspaceIconOpacityShrinked : 0
                            visible: opacity > 0
                            IconImage {
                                id: specialAppIcon
                                anchors.bottom: parent.bottom
                                anchors.right: parent.right
                                anchors.bottomMargin: (!Config.workspaces.alwaysShowNumbers && Config.workspaces.showAppIcons) ? Math.round((workspaceButtonWidth - workspaceIconSize) / 2) : workspaceIconMarginShrinked
                                anchors.rightMargin: (!Config.workspaces.alwaysShowNumbers && Config.workspaces.showAppIcons) ? Math.round((workspaceButtonWidth - workspaceIconSize) / 2) : workspaceIconMarginShrinked
                                source: mainAppIconSource
                                implicitSize: (!Config.workspaces.alwaysShowNumbers && Config.workspaces.showAppIcons) ? workspaceIconSize : workspaceIconSizeShrinked
                                visible: !Config.tintIcons

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
                                sourceItem: specialAppIcon
                                anchors.fill: specialAppIcon
                            }
                        }
                    }
                }
            }
        }
    }

    Item {
        id: columnLayout
        visible: orientation === "vertical"
        z: 1
        enabled: !specialWorkspaceActive

        anchors.fill: parent
        anchors.margins: widgetPadding

        scale: specialWorkspaceActive ? 0.85 : 1
        opacity: specialWorkspaceActive ? 0.6 : 1

        Behavior on scale {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutQuart
            }
        }
        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutQuart
            }
        }

        Repeater {
            model: occupiedRanges

            StyledRect {
                variant: "focus"
                required property int index
                required property var modelData
                z: 1
                width: workspaceButtonWidth
                height: (modelData.end - modelData.start + 1) * workspaceButtonWidth

                radius: Styling.radius(0) > 0 ? Math.max(Styling.radius(0) - widgetPadding, 0) : 0

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
            const currentWorkspaceHasWindows = Hyprland.workspaces.values.some(ws => ws.id === (monitor?.activeWorkspace?.id || 1) && HyprlandData.windowList.some(w => w.workspace.id === ws.id));
            if (Config.roundness === 0)
                return 0;
            return currentWorkspaceHasWindows ? Config.roundness > 0 ? Math.max(Config.roundness - parent.widgetPadding - activeWorkspaceMargin, 0) : 0 : implicitHeight / 2;
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
            const currentWorkspaceHasWindows = Hyprland.workspaces.values.some(ws => ws.id === (monitor?.activeWorkspace?.id || 1) && HyprlandData.windowList.some(w => w.workspace.id === ws.id));
            if (Config.roundness === 0)
                return 0;
            return currentWorkspaceHasWindows ? Config.roundness > 0 ? Math.max(Config.roundness - parent.widgetPadding - activeWorkspaceMargin, 0) : 0 : implicitWidth / 2;
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

    Item {
        id: specialColumnLayout
        visible: orientation === "vertical" && specialWorkspaceActive
        z: 5
        opacity: specialWorkspaceActive ? 1 : 0
        anchors.fill: parent
        anchors.margins: widgetPadding

        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutQuart
            }
        }

        StyledRect {
            id: specialActiveIndicatorVert
            variant: "primary"
            visible: specialActiveIndex >= 0
            z: 1
            width: workspaceButtonWidth * 0.12
            height: workspaceButtonWidth * 0.5
            radius: width / 2

            anchors.right: parent.right
            anchors.rightMargin: Math.max(1, Math.round(workspaceButtonWidth * 0.08))
            y: specialActiveIndex * workspaceButtonWidth + (workspaceButtonWidth - height) / 2

            Behavior on y {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Math.max(0, Config.animDuration - 50)
                    easing.type: Easing.OutQuad
                }
            }
        }

        Repeater {
            model: specialOccupiedRanges

            StyledRect {
                variant: "focus"
                required property int index
                required property var modelData
                z: 0
                width: workspaceButtonWidth
                height: (modelData.end - modelData.start + 1) * workspaceButtonWidth

                radius: Styling.radius(0) > 0 ? Math.max(Styling.radius(0) - widgetPadding, 0) : 0
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

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Repeater {
                model: specialWorkspaceNames.length

                Button {
                    id: specialButtonVert
                    required property int index
                    property string workspaceName: specialWorkspaceNames[index] || ""
                    property string workspaceShort: workspaceName.startsWith("special:") ? workspaceName.slice(8) : workspaceName
                    property var focusedWindow: {
                        const windowsInThisWorkspace = specialEntries[index]?.windows || [];
                        if (windowsInThisWorkspace.length === 0)
                            return null;
                        return windowsInThisWorkspace.reduce((best, win) => {
                            const bestFocus = best?.focusHistoryID ?? Infinity;
                            const winFocus = win?.focusHistoryID ?? Infinity;
                            return winFocus < bestFocus ? win : best;
                        }, null);
                    }
                    property var mainAppIconSource: Quickshell.iconPath(AppSearch.getCachedIcon(focusedWindow?.class), "image-missing")
                    Layout.fillWidth: true
                    height: workspaceButtonWidth

                    onPressed: {
                        if (specialActiveIndex === index) {
                            Hyprland.dispatch(`togglespecialworkspace ${workspaceShort}`);
                        } else {
                            Hyprland.dispatch(`togglespecialworkspace ${workspaceShort}`);
                        }
                    }

                    background: Item {
                        implicitWidth: workspaceButtonWidth
                        implicitHeight: workspaceButtonWidth

                        Text {
                            opacity: Config.workspaces.alwaysShowNumbers || Config.workspaces.showNumbers ? 1 : 0
                            z: 3

                            anchors.centerIn: parent
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.family: Config.theme.font
                            font.pixelSize: workspaceLabelFontSize(text)
                            text: workspaceShort.length > 0 ? workspaceShort : `${index + 1}`
                            elide: Text.ElideRight
                            color: specialActiveIndex === index ? Styling.srItem("primary") : (specialEntries[index]?.windows?.length > 0 ? Colors.overBackground : Colors.overSecondaryFixedVariant)

                            Behavior on opacity {
                                enabled: Config.animDuration > 0
                                NumberAnimation {
                                    duration: 150
                                    easing.type: Easing.OutQuad
                                }
                            }
                        }

                        Rectangle {
                            opacity: (Config.workspaces.showNumbers || Config.workspaces.alwaysShowNumbers || (Config.workspaces.showAppIcons && focusedWindow)) ? 0 : ((specialActiveIndex === index) || (specialEntries[index]?.windows?.length > 0) ? 1 : 0.5)
                            visible: opacity > 0
                            anchors.centerIn: parent
                            width: workspaceButtonWidth * 0.2
                            height: width
                            radius: width / 2
                            color: specialActiveIndex === index ? Styling.srItem("primary") : Colors.overBackground

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
                            opacity: !Config.workspaces.showAppIcons ? 0 : (focusedWindow && !Config.workspaces.alwaysShowNumbers && Config.workspaces.showAppIcons) ? 1 : focusedWindow ? workspaceIconOpacityShrinked : 0
                            visible: opacity > 0
                            IconImage {
                                id: specialAppIconVert
                                anchors.bottom: parent.bottom
                                anchors.right: parent.right
                                anchors.bottomMargin: (!Config.workspaces.alwaysShowNumbers && Config.workspaces.showAppIcons) ? Math.round((workspaceButtonWidth - workspaceIconSize) / 2) : workspaceIconMarginShrinked
                                anchors.rightMargin: (!Config.workspaces.alwaysShowNumbers && Config.workspaces.showAppIcons) ? Math.round((workspaceButtonWidth - workspaceIconSize) / 2) : workspaceIconMarginShrinked
                                source: mainAppIconSource
                                implicitSize: (!Config.workspaces.alwaysShowNumbers && Config.workspaces.showAppIcons) ? workspaceIconSize : workspaceIconSizeShrinked
                                visible: !Config.tintIcons

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
                                sourceItem: specialAppIconVert
                                anchors.fill: specialAppIconVert
                            }
                        }
                    }
                }
            }
        }
    }

    RowLayout {
        id: rowLayoutNumbers
        visible: orientation === "horizontal"
        z: 3
        enabled: !specialWorkspaceActive

        spacing: 0
        anchors.fill: parent
        anchors.margins: widgetPadding
        implicitHeight: workspaceButtonWidth

        scale: specialWorkspaceActive ? 0.85 : 1
        opacity: specialWorkspaceActive ? 0.6 : 1

        Behavior on scale {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutQuart
            }
        }
        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutQuart
            }
        }

        Repeater {
            model: effectiveWorkspaceCount

            Button {
                id: button
                property int workspaceValue: getWorkspaceId(index)
                Layout.fillHeight: true
                onPressed: Hyprland.dispatch(`workspace ${workspaceValue}`)
                width: workspaceButtonWidth

                background: Item {
                    id: workspaceButtonBackground
                    implicitWidth: workspaceButtonWidth
                    implicitHeight: workspaceButtonWidth
                    property var focusedWindow: {
                        const windowsInThisWorkspace = HyprlandData.windowList.filter(w => w.workspace.id == button.workspaceValue);
                        if (windowsInThisWorkspace.length === 0)
                            return null;
                        // Get the window with the lowest focusHistoryID (most recently focused)
                        return windowsInThisWorkspace.reduce((best, win) => {
                            const bestFocus = best?.focusHistoryID ?? Infinity;
                            const winFocus = win?.focusHistoryID ?? Infinity;
                            return winFocus < bestFocus ? win : best;
                        }, null);
                    }
                    property var mainAppIconSource: Quickshell.iconPath(AppSearch.getCachedIcon(focusedWindow?.class), "image-missing")

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
                        color: (monitor?.activeWorkspace?.id == button.workspaceValue) ? Styling.srItem("primary") : (workspaceOccupied[index] ? Colors.overBackground : Colors.overSecondaryFixedVariant)

                        Behavior on opacity {
                            enabled: Config.animDuration > 0
                            NumberAnimation {
                                duration: 150
                                easing.type: Easing.OutQuad
                            }
                        }
                    }
                    Rectangle {
                        opacity: (Config.workspaces.showNumbers || Config.workspaces.alwaysShowNumbers || workspaceOccupied[index] || (Config.workspaces.showAppIcons && workspaceButtonBackground.focusedWindow)) ? 0 : ((monitor?.activeWorkspace?.id == button.workspaceValue) ? 1 : 0.5)
                        visible: opacity > 0
                        anchors.centerIn: parent
                        width: workspaceButtonWidth * 0.2
                        height: width
                        radius: width / 2
                        color: (monitor?.activeWorkspace?.id == button.workspaceValue) ? Styling.srItem("primary") : Colors.overBackground

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
                            visible: !Config.tintIcons

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
        enabled: !specialWorkspaceActive

        spacing: 0
        anchors.fill: parent
        anchors.margins: widgetPadding
        implicitWidth: workspaceButtonWidth

        scale: specialWorkspaceActive ? 0.85 : 1
        opacity: specialWorkspaceActive ? 0.6 : 1

        Behavior on scale {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutQuart
            }
        }
        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutQuart
            }
        }

        Repeater {
            model: effectiveWorkspaceCount

            Button {
                id: buttonVert
                property int workspaceValue: getWorkspaceId(index)
                Layout.fillWidth: true
                onPressed: Hyprland.dispatch(`workspace ${workspaceValue}`)
                height: workspaceButtonWidth

                background: Item {
                    id: workspaceButtonBackgroundVert
                    implicitWidth: workspaceButtonWidth
                    implicitHeight: workspaceButtonWidth
                    property var focusedWindow: {
                        const windowsInThisWorkspace = HyprlandData.windowList.filter(w => w.workspace.id == buttonVert.workspaceValue);
                        if (windowsInThisWorkspace.length === 0)
                            return null;
                        // Get the window with the lowest focusHistoryID (most recently focused)
                        return windowsInThisWorkspace.reduce((best, win) => {
                            const bestFocus = best?.focusHistoryID ?? Infinity;
                            const winFocus = win?.focusHistoryID ?? Infinity;
                            return winFocus < bestFocus ? win : best;
                        }, null);
                    }
                    property var mainAppIconSource: Quickshell.iconPath(AppSearch.getCachedIcon(focusedWindow?.class), "image-missing")

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
                        color: (monitor?.activeWorkspace?.id == buttonVert.workspaceValue) ? Styling.srItem("primary") : (workspaceOccupied[index] ? Colors.overBackground : Colors.overSecondaryFixedVariant)

                        Behavior on opacity {
                            enabled: Config.animDuration > 0
                            NumberAnimation {
                                duration: 150
                                easing.type: Easing.OutQuad
                            }
                        }
                    }
                    Rectangle {
                        opacity: (Config.workspaces.showNumbers || Config.workspaces.alwaysShowNumbers || workspaceOccupied[index] || (Config.workspaces.showAppIcons && workspaceButtonBackgroundVert.focusedWindow)) ? 0 : ((monitor?.activeWorkspace?.id == buttonVert.workspaceValue) ? 1 : 0.5)
                        visible: opacity > 0
                        anchors.centerIn: parent
                        width: workspaceButtonWidth * 0.2
                        height: width
                        radius: width / 2
                        color: (monitor?.activeWorkspace?.id == buttonVert.workspaceValue) ? Styling.srItem("primary") : Colors.overBackground

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
                            visible: !Config.tintIcons

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
