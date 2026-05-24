pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.globals
import qs.config

// ─────────────────────────────────────────────────────────────
// MonitorCard — Per-monitor settings with polished visuals
// Primary source: Quickshell.screens (always available)
// Enriched with: AxctlService data + hyprctl monitors -j
// ─────────────────────────────────────────────────────────────
StyledRect {
    id: root

    required property int monitorIndex
    required property var screen

    property var axctlData: null
    property var detailedInfo: null
    property var availableModes: []
    property var validScales: []
    property int currentModeIndex: 0
    property bool isFetchingModes: false
    property string displayName: ""
    property int displayWidth: 0
    property int displayHeight: 0
    property int displayX: 0
    property int displayY: 0
    property real displayScale: 1.0
    property real displayRefreshRate: 60
    property bool isCollapsed: false

    variant: "pane"
    Layout.fillWidth: true
    Layout.preferredHeight: cardLayout.implicitHeight + 20
    radius: Styling.radius(0)
    enableShadow: true

    Component.onCompleted: {
        refreshBasicData();
        updateAxctlMatch();
        fetchDetailedInfo();
    }

    function refreshBasicData() {
        if (!root.screen) return;
        root.displayName = root.screen.name || ("Monitor " + (root.monitorIndex + 1));
        root.displayWidth = root.screen.width || 0;
        root.displayHeight = root.screen.height || 0;
        root.displayX = root.screen.x || 0;
        root.displayY = root.screen.y || 0;
    }

    function updateAxctlMatch() {
        if (!root.screen || !root.screen.name) return;
        var monitors = AxctlService.monitors.values;
        if (!monitors || monitors.length === 0) return;
        for (var i = 0; i < monitors.length; i++) {
            if (monitors[i].name === root.screen.name) {
                root.axctlData = monitors[i];
                root.displayRefreshRate = monitors[i].refreshRate || 60;
                root.displayScale = monitors[i].scale || 1.0;
                return;
            }
        }
    }

    function fetchDetailedInfo() {
        if (isFetchingModes || !root.displayName) return;
        isFetchingModes = true;
        modeFetcherHyprctl.running = true;
    }

    property Process modeFetcherHyprctl: Process {
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {}
        running: false
        onExited: exitCode => {
            if (exitCode === 0) {
                try {
                    parseMonitorList(JSON.parse(modeFetcherHyprctl.stdout.text));
                    return;
                } catch (e) { console.warn("MonitorCard: hyprctl parse failed:", e); }
            }
            modeFetcherAxctl.running = true;
        }
    }

    property Process modeFetcherAxctl: Process {
        command: ["axctl", "monitor", "list"]
        stdout: StdioCollector {}
        running: false
        onExited: exitCode => {
            root.isFetchingModes = false;
            if (exitCode === 0) {
                try { parseMonitorList(JSON.parse(modeFetcherAxctl.stdout.text)); }
                catch (e) { console.warn("MonitorCard: axctl parse failed:", e); setFallbackModes(); }
            } else { setFallbackModes(); }
        }
    }

    function parseMonitorList(allMonitors) {
        root.isFetchingModes = false;
        if (!allMonitors || !Array.isArray(allMonitors)) { setFallbackModes(); return; }
        var found = null;
        for (var i = 0; i < allMonitors.length; i++) {
            if (allMonitors[i].name === root.displayName) { found = allMonitors[i]; break; }
        }
        if (!found) { setFallbackModes(); return; }
        root.detailedInfo = found;
        if (found.width) root.displayWidth = found.width;
        if (found.height) root.displayHeight = found.height;
        if (found.x !== undefined) root.displayX = found.x;
        if (found.y !== undefined) root.displayY = found.y;
        root.displayScale = found.scale || root.displayScale;
        root.displayRefreshRate = found.refreshRate || found.refresh_rate || root.displayRefreshRate;
        var modes = found.availableModes || found.available_modes || [];
        if (modes.length === 0 && found.width && found.height) {
            modes = [found.width + "x" + found.height + "@" + root.displayRefreshRate.toFixed(2) + "Hz"];
        }
        root.availableModes = modes;
        root.currentModeIndex = 0;
        for (var j = 0; j < modes.length; j++) {
            var modeStr = (modes[j] + "").replace("Hz", "").replace("hz", "").trim();
            if (modeStr.indexOf(found.width + "x" + found.height) === 0) {
                root.currentModeIndex = j;
                if (modeStr.indexOf(Math.round(root.displayRefreshRate).toString()) !== -1) break;
            }
        }
        root.validScales = computeScales(root.displayWidth, root.displayHeight);
    }

    function setFallbackModes() {
        root.isFetchingModes = false;
        if (root.displayWidth > 0 && root.displayHeight > 0) {
            root.availableModes = [root.displayWidth + "x" + root.displayHeight + "@" + root.displayRefreshRate.toFixed(2) + "Hz"];
            root.currentModeIndex = 0;
            root.validScales = computeScales(root.displayWidth, root.displayHeight);
        }
    }

    function computeScales(w, h) {
        var scales = [];
        if (w <= 0 || h <= 0) { return [1.0, 1.25, 1.5, 1.75, 2.0]; }
        var base = Math.max(1.0, Math.min(w / 640, h / 480));
        for (var step = 0; step <= 120; step++) {
            var s = base + step / 120.0;
            if (s > 10.0) break;
            scales.push(s);
        }
        if (scales.length === 0) scales = [1.0];
        return scales;
    }

    function findScaleIndex(targetScale) {
        if (!root.validScales || root.validScales.length === 0) return 0;
        var bestIdx = 0, bestDiff = Infinity;
        for (var i = 0; i < root.validScales.length; i++) {
            var diff = Math.abs(root.validScales[i] - targetScale);
            if (diff < bestDiff) { bestDiff = diff; bestIdx = i; }
        }
        return bestIdx;
    }

    function applyMonitorSetting(key, value) {
        var monName = root.displayName;
        if (!monName) return;
        GlobalStates.markCompositorChanged();
        var cmd = "";
        if (key === "resolution") cmd = "monitor " + monName + "," + value + ",auto,auto";
        else if (key === "position") cmd = "monitor " + monName + ",preferred," + value.x + "x" + value.y + ",auto";
        else if (key === "scale") cmd = "monitor " + monName + ",preferred,auto," + value;
        else if (key === "transform") cmd = "monitor " + monName + ",preferred,auto,auto,transform," + value;
        else if (key === "vrr") cmd = "monitor " + monName + ",preferred,auto,auto,vrr," + value;
        else if (key === "disabled") cmd = "monitor " + monName + "," + (value ? "disable" : "preferred,auto,auto");
        if (cmd) {
            AxctlService.dispatch(cmd);
            // Persist to disk (debounced)
            monitorSyncDebounce.restart();
        }
    }

    // ──────────────────────────────────────────
    // UI — Clean, modern design
    // ──────────────────────────────────────────
    ColumnLayout {
        id: cardLayout
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // ── Header row ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                width: 10; height: 10; radius: 5
                color: (AxctlService.focusedMonitor && AxctlService.focusedMonitor.name === root.displayName)
                    ? Styling.srItem("primary") : Colors.outline
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    text: root.displayName
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(1)
                    font.bold: true
                    color: Colors.overBackground
                }

                Text {
                    text: {
                        var p = [];
                        if (root.detailedInfo && root.detailedInfo.make) p.push(root.detailedInfo.make);
                        if (root.detailedInfo && root.detailedInfo.model) p.push(root.detailedInfo.model);
                        if (root.displayWidth > 0) p.push(root.displayWidth + "×" + root.displayHeight + " @ " + Math.round(root.displayRefreshRate) + "Hz");
                        return p.join("  ·  ");
                    }
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-2)
                    color: Colors.outline
                    elide: Text.ElideRight
                }
            }

            Button {
                flat: true
                Layout.preferredWidth: 32; Layout.preferredHeight: 32
                Layout.alignment: Qt.AlignVCenter

                contentItem: Text {
                    text: root.isCollapsed ? Icons.caretDown : Icons.caretUp
                    font.family: Icons.font; font.pixelSize: 16
                    color: Colors.outline
                    anchors.centerIn: parent
                }

                background: StyledRect {
                    variant: "common"
                    radius: Styling.radius(-6)
                }
                onClicked: root.isCollapsed = !root.isCollapsed
            }
        }

        // ── Quick info chips (always visible) ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            StyledRect {
                variant: "internalbg"
                Layout.preferredHeight: 22
                radius: Styling.radius(-6)
                implicitWidth: posChipRow.implicitWidth + 12
                RowLayout {
                    id: posChipRow; anchors.centerIn: parent; spacing: 3
                    Text { text: Icons.arrowsOutCardinal; font.family: Icons.font; font.pixelSize: 10; color: Colors.outline }
                    Text { text: root.displayX + ", " + root.displayY; font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-3); color: Colors.outline }
                }
            }

            StyledRect {
                variant: "internalbg"
                Layout.preferredHeight: 22
                radius: Styling.radius(-6)
                implicitWidth: scaleChipRow.implicitWidth + 12
                RowLayout {
                    id: scaleChipRow; anchors.centerIn: parent; spacing: 3
                    Text { text: Icons.arrowsOut; font.family: Icons.font; font.pixelSize: 10; color: Colors.outline }
                    Text { text: root.displayScale.toFixed(2) + "x"; font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-3); color: Colors.outline }
                }
            }

            StyledRect {
                variant: "internalbg"
                Layout.preferredHeight: 22
                radius: Styling.radius(-6)
                implicitWidth: rrChipRow.implicitWidth + 12
                RowLayout {
                    id: rrChipRow; anchors.centerIn: parent; spacing: 3
                    Text { text: Icons.arrowCounterClockwise; font.family: Icons.font; font.pixelSize: 10; color: Colors.outline }
                    Text { text: Math.round(root.displayRefreshRate) + "Hz"; font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-3); color: Colors.outline }
                }
            }

            Item { Layout.fillWidth: true }

            Switch {
                id: enabledSwitch; checked: true; Layout.alignment: Qt.AlignVCenter
                onToggled: root.applyMonitorSetting("disabled", !checked)
                indicator: Rectangle {
                    implicitWidth: 36; implicitHeight: 20; radius: 10
                    color: enabledSwitch.checked ? Styling.srItem("primary") : Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.3)
                    border.color: enabledSwitch.checked ? Styling.srItem("primary") : Colors.outline; border.width: 1
                    Rectangle {
                        x: enabledSwitch.checked ? parent.width - width - 3 : 3
                        y: (parent.height - height) / 2
                        width: 14; height: 14; radius: 7
                        color: enabledSwitch.checked ? "#ffffff" : Colors.outline
                        Behavior on x { enabled: Config.animDuration > 0; NumberAnimation { duration: Config.animDuration / 2; easing.type: Easing.OutCubic } }
                    }
                    Behavior on color { enabled: Config.animDuration > 0; ColorAnimation { duration: Config.animDuration / 2 } }
                }
            }
        }

        // ── Expandable settings ──
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: root.isCollapsed ? 0 : settingsColumn.implicitHeight
            clip: true
            visible: !root.isCollapsed
            Behavior on Layout.preferredHeight {
                enabled: Config.animDuration > 0
                NumberAnimation { duration: Config.animDuration / 2; easing.type: Easing.OutCubic }
            }

            ColumnLayout {
                id: settingsColumn; width: parent.width; spacing: 6

                SettingsRow {
                    icon: Icons.layout; label: "Resolution"; Layout.fillWidth: true
                    ComboBox {
                        id: modeCombo
                        model: root.availableModes.length > 0 ? root.availableModes.map(function(m) { return (m+"").replace("Hz"," Hz"); }) : [root.displayWidth + "×" + root.displayHeight + " " + Math.round(root.displayRefreshRate) + " Hz"]
                        currentIndex: root.currentModeIndex; Layout.preferredWidth: 190
                        background: Rectangle {
                            color: modeCombo.hovered ? Colors.surfaceContainerHigh : Colors.surfaceContainer
                            radius: Styling.radius(-2)
                            border.color: Colors.outlineVariant; border.width: 1
                        }
                        contentItem: Text { text: modeCombo.displayText; font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-1); color: Colors.overBackground; verticalAlignment: Text.AlignVCenter; leftPadding: 10; elide: Text.ElideRight }
                        indicator: Text { text: Icons.caretDown; font.family: Icons.font; font.pixelSize: 14; color: Colors.overBackground; anchors.verticalCenter: parent.verticalCenter; anchors.right: parent.right; anchors.rightMargin: 8 }
                        onActivated: { if (root.availableModes.length > 0 && index < root.availableModes.length) root.applyMonitorSetting("resolution", root.availableModes[index]); }
                    }
                }

                SettingsRow {
                    icon: Icons.arrowsOut; label: "Scale"; Layout.fillWidth: true
                    RowLayout {
                        spacing: 4
                        TextField {
                            id: scaleInput
                            text: root.displayScale.toFixed(2)
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            color: Colors.overBackground
                            Layout.preferredWidth: 70
                            horizontalAlignment: Text.AlignRight
                            validator: DoubleValidator { bottom: 0.25; top: 10.0; decimals: 2 }
                            background: Rectangle {
                                color: scaleInput.hovered ? Colors.surfaceContainerHigh : Colors.surfaceContainer
                                radius: Styling.radius(-2)
                                border.color: Colors.outlineVariant; border.width: 1
                            }
                            onEditingFinished: {
                                var val = parseFloat(text);
                                if (!isNaN(val) && val >= 0.25 && val <= 10.0) {
                                    root.applyMonitorSetting("scale", val);
                                } else {
                                    text = root.displayScale.toFixed(2);
                                }
                            }
                        }
                        Text {
                            text: "×"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            color: Colors.outline
                        }
                    }
                }

                SettingsRow {
                    icon: Icons.arrowsOutCardinal; label: "Position"; Layout.fillWidth: true
                    RowLayout {
                        spacing: 4
                        Text { text: "X"; font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-2); color: Colors.outline }
                        SpinBox {
                            id: posX; from: -10000; to: 10000; stepSize: 10; value: root.displayX; editable: true; Layout.preferredWidth: 80
                            background: Rectangle { color: Colors.surfaceContainer; border.color: Colors.outlineVariant; border.width: 1; radius: Styling.radius(-2) }
                            contentItem: TextInput { text: posX.value; font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-1); color: Colors.overBackground; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            onValueModified: root.applyMonitorSetting("position", { x: posX.value, y: posY.value })
                        }
                        Text { text: "Y"; font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-2); color: Colors.outline }
                        SpinBox {
                            id: posY; from: -10000; to: 10000; stepSize: 10; value: root.displayY; editable: true; Layout.preferredWidth: 80
                            background: Rectangle { color: Colors.surfaceContainer; border.color: Colors.outlineVariant; border.width: 1; radius: Styling.radius(-2) }
                            contentItem: TextInput { text: posY.value; font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-1); color: Colors.overBackground; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            onValueModified: root.applyMonitorSetting("position", { x: posX.value, y: posY.value })
                        }
                    }
                }

                SettingsRow {
                    icon: Icons.arrowCounterClockwise; label: "Rotation"; Layout.fillWidth: true
                    ComboBox {
                        id: transformCombo
                        model: ["0° Normal", "90°", "180°", "270°", "90° Flip", "270° Flip"]
                        currentIndex: root.detailedInfo ? Math.min(root.detailedInfo.transform || 0, 5) : 0; Layout.preferredWidth: 140
                        background: Rectangle {
                            color: transformCombo.hovered ? Colors.surfaceContainerHigh : Colors.surfaceContainer
                            radius: Styling.radius(-2)
                            border.color: Colors.outlineVariant; border.width: 1
                        }
                        contentItem: Text { text: transformCombo.displayText; font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-1); color: Colors.overBackground; verticalAlignment: Text.AlignVCenter; leftPadding: 10 }
                        indicator: Text { text: Icons.caretDown; font.family: Icons.font; font.pixelSize: 14; color: Colors.overBackground; anchors.verticalCenter: parent.verticalCenter; anchors.right: parent.right; anchors.rightMargin: 8 }
                        onActivated: root.applyMonitorSetting("transform", index)
                    }
                }

                SettingsRow {
                    icon: Icons.waveform; label: "VRR"; Layout.fillWidth: true
                    ComboBox {
                        id: vrrCombo
                        model: ["Global Default", "Disabled", "Enabled", "Fullscreen", "Fullscreen+Gaming"]
                        currentIndex: 0; Layout.preferredWidth: 160
                        background: Rectangle {
                            color: vrrCombo.hovered ? Colors.surfaceContainerHigh : Colors.surfaceContainer
                            radius: Styling.radius(-2)
                            border.color: Colors.outlineVariant; border.width: 1
                        }
                        contentItem: Text { text: vrrCombo.displayText; font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-1); color: Colors.overBackground; verticalAlignment: Text.AlignVCenter; leftPadding: 10 }
                        indicator: Text { text: Icons.caretDown; font.family: Icons.font; font.pixelSize: 14; color: Colors.overBackground; anchors.verticalCenter: parent.verticalCenter; anchors.right: parent.right; anchors.rightMargin: 8 }
                        onActivated: { var v = [null, "0", "1", "2", "3"]; root.applyMonitorSetting("vrr", v[index]); }
                    }
                }
            }
        }
    }

    // ── Inline: SettingsRow component ──
    component SettingsRow: RowLayout {
        property string icon: ""; property string label: ""
        spacing: 8
        Text { text: icon; font.family: Icons.font; font.pixelSize: 14; color: Colors.outline; Layout.preferredWidth: 18 }
        Text { text: label; font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-1); color: Colors.overBackground; Layout.preferredWidth: 80 }
    }

    // Debounced monitor config sync (after settings change)
    Timer {
        id: monitorSyncDebounce
        interval: 2500
        repeat: false
        onTriggered: MonitorsWriter.sync()
    }

    // ── Connections ──
    Connections {
        target: AxctlService
        function onMonitorsChanged() {
            root.updateAxctlMatch();
            // Sync to disk after Axctl reports the change
            monitorSyncDebounce.restart();
        }
    }

    onDetailedInfoChanged: {
        if (detailedInfo) {
            if (detailedInfo.x !== undefined) posX.value = detailedInfo.x;
            if (detailedInfo.y !== undefined) posY.value = detailedInfo.y;
            if (detailedInfo.transform !== undefined) transformCombo.currentIndex = Math.min(detailedInfo.transform, 5);
        }
    }
}
