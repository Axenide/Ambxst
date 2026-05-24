pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

/**
 * MonitorArrangementView — nwg-displays style canvas
 *
 * Renders monitors at their REAL coordinates, scaled to fit the canvas.
 * Drag & drop updates actual x,y positions. Snap-to-edge à la nwg-displays.
 */
StyledRect {
    id: root

    variant: "pane"
    Layout.fillWidth: true
    Layout.preferredHeight: canvasColumn.implicitHeight + 16
    radius: Styling.radius(0)
    enableShadow: true

    property var monitors: []
    property bool hasChanges: false
    property var dragIdx: -1
    property var dragNewX: 0
    property var dragNewY: 0

    signal positionChanged(int monitorIndex, int newX, int newY)
    signal monitorSelected(int monitorIndex)

    // ── Reactively build monitor list from Quickshell.screens + AxctlService ──
    function refreshMonitors() {
        var list = [];
        var screens = Quickshell.screens;
        if (!screens || screens.length === 0) return;

        var axMons = AxctlService.monitors.values || [];

        for (var i = 0; i < screens.length; i++) {
            var s = screens[i];
            var axctl = null;
            for (var j = 0; j < axMons.length; j++) {
                if (axMons[j].name === s.name) { axctl = axMons[j]; break; }
            }

            // Prefer AxctlService for position/geometry (real compositor state),
            // fall back to Quickshell.screen properties
            var w = axctl ? (axctl.width || s.width || 1920) : (s.width || 1920);
            var h = axctl ? (axctl.height || s.height || 1080) : (s.height || 1080);
            var x = axctl ? (axctl.x || s.x || 0) : (s.x || 0);
            var y = axctl ? (axctl.y || s.y || 0) : (s.y || 0);
            var sc = axctl ? (axctl.scale || 1.0) : 1.0;
            var rr = axctl ? (axctl.refreshRate || 60) : 60;
            var tf = axctl ? (axctl.transform || 0) : 0;

            list.push({
                name: s.name || ("Monitor-" + (i + 1)),
                width: w, height: h,
                x: x, y: y,
                scale: sc,
                refreshRate: rr,
                transform: tf,
                focused: (AxctlService.focusedMonitor && AxctlService.focusedMonitor.name === s.name)
            });
        }
        root.monitors = list;
    }

    Component.onCompleted: {
        refreshMonitors();
        recalcBounds();
    }

    onPositionChanged: syncDebounceTimer.restart()

    Timer {
        id: syncDebounceTimer
        interval: 1500
        repeat: false
        onTriggered: root.saveToConfig()
    }

    Connections {
        target: AxctlService
        function onMonitorsChanged() {
            root.refreshMonitors();
            root.recalcBounds();
        }
    }

    // Recalculate bounds whenever the monitors array changes
    onMonitorsChanged: {
        root.recalcBounds();
    }

    // ── View transform ──
    // Bounds of all monitors in real coordinates.
    property var viewBounds_: ({ minX: -100, minY: -100, maxX: 100, maxY: 100, spanW: 200, spanH: 200 })

    function recalcBounds() {
        var mons = root.monitors;
        if (!mons || mons.length === 0) return;

        var minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
        for (var i = 0; i < mons.length; i++) {
            var m = mons[i];
            // Use logical dimensions (physical / scale) so the canvas fits correctly
            var scale = m.scale || 1.0;
            var w = (m.width || 1920) / scale;
            var h = (m.height || 1080) / scale;
            var x = m.x || 0, y = m.y || 0;
            if (x < minX) minX = x;
            if (y < minY) minY = y;
            if (x + w > maxX) maxX = x + w;
            if (y + h > maxY) maxY = y + h;
        }

        // If all overlaps (all at 0,0), space them out for visibility
        var margin = 100;
        if (minX === maxX && minY === maxY && mons.length > 1) {
            // Use sequential layout for preview
            var cx = 0;
            for (var i = 0; i < mons.length; i++) {
                mons[i]._previewX = cx;
                mons[i]._previewY = 0;
                cx += (mons[i].width || 1920) + 20;
            }
            minX = 0;
            minY = 0;
            maxX = cx;
            maxY = 1080;
        }

        root.viewBounds_ = {
            minX: minX - margin,
            minY: minY - margin,
            maxX: maxX + margin,
            maxY: maxY + margin,
            spanW: Math.max((maxX + margin) - (minX - margin), 1),
            spanH: Math.max((maxY + margin) - (minY - margin), 1)
        };
    }


    // Canvas scale factor
    property real viewScale: 0.1

    function recalcScale() {
        var cw = canvasArea.width;
        var ch = canvasArea.height;
        if (cw <= 0 || ch <= 0) return;
        var vb = root.viewBounds_;
        root.viewScale = Math.min(
            (cw - 20) / vb.spanW,
            (ch - 20) / vb.spanH
        );
    }

    function realToCanvasX(realX) {
        return (realX - root.viewBounds_.minX) * root.viewScale + 10;
    }

    function realToCanvasY(realY) {
        return (realY - root.viewBounds_.minY) * root.viewScale + 10;
    }

    function canvasToRealX(cvX) {
        return Math.round((cvX - 10) / root.viewScale + root.viewBounds_.minX);
    }

    function canvasToRealY(cvY) {
        return Math.round((cvY - 10) / root.viewScale + root.viewBounds_.minY);
    }

    // ── Auto-align left-to-right ──
    function autoAlignMonitors() {
        var mons = root.monitors;
        if (!mons || mons.length === 0) return;
        var currentX = 0;
        for (var i = 0; i < mons.length; i++) {
            var m = mons[i];
            // dispatch happens via MonitorsWriter.sync()
            currentX += m.width;
        }
        recalcScale();
        refreshTimer.start();
    }

    Timer {
        id: refreshTimer
        interval: 600
        onTriggered: {
            root.refreshMonitors();
            root.recalcBounds();
        }
    }

    // ── Persist to disk ──
    function saveToConfig() {
        var data = [];
        var mons = root.monitors;
        if (!mons || mons.length === 0) return;
        for (var i = 0; i < mons.length; i++) {
            var m = mons[i];
            data.push({
                name: m.name, width: m.width, height: m.height,
                x: m.x, y: m.y, scale: m.scale,
                refreshRate: m.refreshRate, transform: m.transform || 0,
                enabled: true, bitdepth: 10
            });
        }
        MonitorsWriter.syncWithData(data);
        root.hasChanges = false;
    }

    // ── Layout ──
    ColumnLayout {
        id: canvasColumn
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        // Header row
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: Icons.layout + "  Monitor Layout"
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(0)
                font.bold: true
                color: Colors.overBackground
                Layout.fillWidth: true
            }

            Button {
                id: alignBtn
                flat: true; hoverEnabled: true
                Layout.preferredHeight: 28
                implicitWidth: alignLabel.implicitWidth + 20

                background: StyledRect {
                    variant: alignBtn.hovered ? "focus" : "common"
                    radius: Styling.radius(-4)
                }
                contentItem: Text {
                    id: alignLabel
                    text: Icons.arrowsOutCardinal + " Auto-Arrange"
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-2)
                    color: Colors.overBackground
                    anchors.centerIn: parent
                }
                onClicked: root.autoAlignMonitors()
            }

            Button {
                id: saveBtn
                flat: true; hoverEnabled: true
                Layout.preferredHeight: 28
                implicitWidth: saveLabel.implicitWidth + 20

                background: StyledRect {
                    variant: saveBtn.hovered ? "primary" : "common"
                    radius: Styling.radius(-4)
                }
                contentItem: Text {
                    id: saveLabel
                    text: Icons.disk + " Save to Config"
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-2)
                    color: saveBtn.hovered ? Styling.srItem("primary") : Colors.overBackground
                    anchors.centerIn: parent
                }
                onClicked: root.saveToConfig()
            }
        }

        // Canvas
        Item {
            id: canvasArea
            Layout.fillWidth: true
            Layout.preferredHeight: 220
            clip: true
            onWidthChanged: recalcScale()
            onHeightChanged: recalcScale()

            // Background
            StyledRect {
                anchors.fill: parent
                variant: "internalbg"
                radius: Styling.radius(-2)
            }

            // Scroll container — shifts content so both monitors are visible
            Item {
                id: scrollBox
                width: Math.max(parent.width, root.viewBounds_.spanW * root.viewScale + 20)
                height: Math.max(parent.height, root.viewBounds_.spanH * root.viewScale + 20)

                // Subtle grid at 500px intervals
                Repeater {
                    model: Math.floor(root.viewBounds_.spanW / 500) + 2
                    Rectangle {
                        x: root.realToCanvasX(root.viewBounds_.minX + index * 500)
                        y: 0; width: 1; height: scrollBox.height
                        color: Qt.rgba(Colors.outlineVariant.r, Colors.outlineVariant.g, Colors.outlineVariant.b, 0.06)
                    }
                }
                Repeater {
                    model: Math.floor(root.viewBounds_.spanH / 500) + 2
                    Rectangle {
                        x: 0
                        y: root.realToCanvasY(root.viewBounds_.minY + index * 500)
                        width: scrollBox.width; height: 1
                        color: Qt.rgba(Colors.outlineVariant.r, Colors.outlineVariant.g, Colors.outlineVariant.b, 0.06)
                    }
                }

                // Origin marker (0,0)
                StyledRect {
                    x: root.realToCanvasX(0) - 5
                    y: root.realToCanvasY(0) - 5
                    width: 10; height: 10
                    radius: Styling.radius(-10)
                    variant: "primary"
                    opacity: 0.6
                }
                // Origin axes
                Rectangle { x: root.realToCanvasX(0) - 1; y: 0; width: 2; height: scrollBox.height; color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.04); }
                Rectangle { x: 0; y: root.realToCanvasY(0) - 1; width: scrollBox.width; height: 2; color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.04); }

                // Monitor items
                Repeater {
                    model: root.monitors

                    delegate: Item {
                        id: monItem
                        required property int index
                        required property var modelData

                        // Compute position: use drag preview when dragging, real coords otherwise
                        readonly property real realX: root.dragIdx === index ? root.dragNewX : modelData.x
                        readonly property real realY: root.dragIdx === index ? root.dragNewY : modelData.y

                        x: root.realToCanvasX(realX)
                        y: root.realToCanvasY(realY)
                        // Show at logical size (physical / scale) like nwg-displays
                        readonly property real logicalW: modelData.width / (modelData.scale || 1.0)
                        readonly property real logicalH: modelData.height / (modelData.scale || 1.0)
                        width: Math.max(50, logicalW * root.viewScale)
                        height: Math.max(35, logicalH * root.viewScale)

                        // Body
                        StyledRect {
                            anchors.fill: parent
                            variant: modelData.focused ? "primary" : "common"
                            radius: Styling.radius(-2)
                            enableShadow: true
                            border.width: modelData.focused ? 1.5 : 1
                            border.color: modelData.focused
                                ? Styling.srItem("primary")
                                : Colors.outlineVariant
                        }

                        // Label
                        Column {
                            anchors.centerIn: parent; spacing: 1
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.name
                                font.family: Config.theme.font
                                font.pixelSize: Math.max(8, Math.min(11, Styling.fontSize(-3)))
                                font.bold: true
                                color: modelData.focused ? Styling.srItem("primary") : Colors.overBackground
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: realX + "," + realY
                                font.family: Config.theme.font
                                font.pixelSize: Math.max(7, Math.min(10, Styling.fontSize(-4)))
                                color: Colors.outline
                            }                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.width + "×" + modelData.height
                                font.family: Config.theme.font
                                font.pixelSize: Math.max(7, Math.min(10, Styling.fontSize(-4)))
                                color: Colors.outline
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "@" + modelData.scale.toFixed(2) + "x  (" + Math.round(logicalW) + "×" + Math.round(logicalH) + " logical)"
                                font.pixelSize: Math.max(7, Math.min(10, Styling.fontSize(-4)))
                                color: Colors.outlineVariant
                            }
                        }

                        // Drag
                        MouseArea {
                            id: dragArea
                            anchors.fill: parent
                            cursorShape: Qt.SizeAllCursor
                            hoverEnabled: true

                            property real pressCX: 0
                            property real pressCY: 0
                            property real startRealX: 0
                            property real startRealY: 0
                            property bool dragging: false

                            onPressed: mouse => {
                                monItem.z = 100
                                dragging = true
                                pressCX = mouse.x + monItem.x
                                pressCY = mouse.y + monItem.y
                                startRealX = modelData.x
                                startRealY = modelData.y
                                root.dragIdx = index
                                root.dragNewX = modelData.x
                                root.dragNewY = modelData.y
                                root.monitorSelected(index)
                            }

                            onPositionChanged: mouse => {
                                if (!dragging) return

                                // Canvas-space delta
                                var dCX = (mouse.x + monItem.x) - pressCX
                                var dCY = (mouse.y + monItem.y) - pressCY

                                // Real-space delta
                                var dRX = dCX / root.viewScale
                                var dRY = dCY / root.viewScale

                                var newX = Math.round((startRealX + dRX) / 10) * 10
                                var newY = Math.round((startRealY + dRY) / 10) * 10

                                // Snap to other monitors
                                var mw = logicalW
                                var mh = logicalH
                                var snapPx = 50

                                for (var k = 0; k < root.monitors.length; k++) {
                                    if (k === index) continue
                                    var o = root.monitors[k]
                                    if (!o) continue
                                    var ox = o.x, oy = o.y
                                    var ow = (o.width || 1920) / (o.scale || 1.0)
                                    var oh = (o.height || 1080) / (o.scale || 1.0)

                                    if (Math.abs(newX - (ox + ow)) < snapPx) newX = ox + ow
                                    if (Math.abs((newX + mw) - ox) < snapPx) newX = ox - mw
                                    if (Math.abs(newY - (oy + oh)) < snapPx) newY = oy + oh
                                    if (Math.abs((newY + mh) - oy) < snapPx) newY = oy - mh
                                    if (Math.abs(newX - ox) < snapPx) newX = ox
                                    if (Math.abs(newY - oy) < snapPx) newY = oy
                                }

                                root.dragNewX = newX
                                root.dragNewY = newY
                            }

                            onReleased: {
                                if (!dragging) return
                                dragging = false
                                monItem.z = 1

                                var rx = root.dragNewX
                                var ry = root.dragNewY
                                var mw = logicalW
                                var mh = logicalH

                                // Stronger snap on release
                                var snapPx = 80
                                for (var k = 0; k < root.monitors.length; k++) {
                                    if (k === index) continue
                                    var o = root.monitors[k]
                                    if (!o) continue
                                    var ox = o.x, oy = o.y
                                    var ow = (o.width || 1920) / (o.scale || 1.0)
                                    var oh = (o.height || 1080) / (o.scale || 1.0)

                                    if (Math.abs(rx - (ox + ow)) < snapPx) rx = ox + ow
                                    if (Math.abs((rx + mw) - ox) < snapPx) rx = ox - mw
                                    if (Math.abs(ry - (oy + oh)) < snapPx) ry = oy + oh
                                    if (Math.abs((ry + mh) - oy) < snapPx) ry = oy - mh
                                    if (Math.abs(rx - ox) < snapPx) rx = ox
                                    if (Math.abs(ry - oy) < snapPx) ry = oy
                                }

                                // Prevent overlap
                                for (var j = 0; j < root.monitors.length; j++) {
                                    if (j === index) continue
                                    var o2 = root.monitors[j]
                                    if (!o2) continue
                                    var o2w = (o2.width || 1920) / (o2.scale || 1.0)
                                    var o2h = (o2.height || 1080) / (o2.scale || 1.0)
                                    if (rx < o2.x + o2w && rx + mw > o2.x && ry < o2.y + o2h && ry + mh > o2.y) {
                                        var dL = rx + mw - o2.x, dR = o2.x + o2w - rx
                                        var dU = ry + mh - o2.y, dD = o2.y + o2h - ry
                                        var minD = Math.min(dL, dR, dU, dD)
                                        if (minD === dL) rx = o2.x - mw
                                        else if (minD === dR) rx = o2.x + o2w
                                        else if (minD === dU) ry = o2.y - mh
                                        else ry = o2.y + o2h
                                    }
                                }

                                rx = Math.round(rx / 10) * 10
                                ry = Math.round(ry / 10) * 10

                                // Update model with new array (forces Repeater refresh)
                                var newMons = [];
                                for (var mi = 0; mi < root.monitors.length; mi++) {
                                    var src = root.monitors[mi];
                                    newMons.push(mi === index ? {
                                        name: src.name, width: src.width, height: src.height,
                                        x: rx, y: ry, scale: src.scale,
                                        refreshRate: src.refreshRate, transform: src.transform || 0,
                                        focused: src.focused
                                    } : src);
                                }
                                root.monitors = newMons;
                                root.dragIdx = -1
                                root.hasChanges = true
                                root.positionChanged(index, rx, ry)
                                AxctlService.dispatch("monitor " + modelData.name + ",preferred," + rx + "x" + ry + ",auto")
                            }
                        }

                        // Hover glow
                        StyledRect {
                            anchors.fill: parent; anchors.margins: -3
                            variant: "common"
                            radius: Styling.radius(-1)
                            opacity: dragArea.containsMouse ? 0.3 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                            z: -1
                        }
                    }
                }
            }
        }

        // Info bar — clean status line
        StyledRect {
            Layout.fillWidth: true
            Layout.preferredHeight: 24
            variant: "internalbg"
            radius: Styling.radius(-4)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10; anchors.rightMargin: 10
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: {
                        if (root.monitors.length === 0) return "No monitors detected";
                        var parts = [];
                        for (var i = 0; i < root.monitors.length; i++) {
                            var m = root.monitors[i];
                            parts.push(m.name + " @ " + m.x + "," + m.y);
                        }
                        return (root.hasChanges ? Icons.shieldCheck + "  " : Icons.handGrab + "  ") + parts.join("  ·  ");
                    }
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-3)
                    color: Colors.outline
                    elide: Text.ElideRight
                }

                Text {
                    text: Icons.glassPlus + " 1:" + root.viewScale.toFixed(2)
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-4)
                    color: Colors.outlineVariant
                }
            }
        }
    }
}
