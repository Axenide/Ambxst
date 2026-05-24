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
    property var dragState: null

    signal positionChanged(int monitorIndex, int newX, int newY)
    signal monitorSelected(int monitorIndex)

    // ── Reactively build monitor list from Quickshell.screens ──
    function refreshMonitors() {
        var list = [];
        var screens = Quickshell.screens;
        if (!screens) return;
        var axMons = AxctlService.monitors.values || [];
        for (var i = 0; i < screens.length; i++) {
            var s = screens[i];
            var axctl = null;
            for (var j = 0; j < axMons.length; j++) {
                if (axMons[j].name === s.name) { axctl = axMons[j]; break; }
            }
            list.push({
                name: s.name || ("Monitor " + (i + 1)),
                width: axctl ? (axctl.width || 0) : (s.width || 1920),
                height: axctl ? (axctl.height || 0) : (s.height || 1080),
                x: s.x || 0,
                y: s.y || 0,
                scale: axctl ? (axctl.scale || 1.0) : 1.0,
                refreshRate: axctl ? (axctl.refreshRate || 60) : 60,
                transform: axctl ? (axctl.transform || 0) : 0,
                focused: (AxctlService.focusedMonitor && AxctlService.focusedMonitor.name === s.name)
            });
        }
        root.monitors = list;
    }

    Component.onCompleted: refreshMonitors()

    onPositionChanged: syncDebounceTimer.restart()

    Timer {
        id: syncDebounceTimer
        interval: 1500
        repeat: false
        onTriggered: root.saveToConfig()
    }

    Connections {
        target: AxctlService
        function onMonitorsChanged() { root.refreshMonitors(); }
    }

    // ── View transform ──
    // Computes bounds of all monitors in real coordinates
    readonly property var viewBounds: {
        var mons = root.monitors;
        if (!mons || mons.length === 0) return { minX: 0, minY: 0, maxX: 1, maxY: 1, spanW: 1, spanH: 1 };

        var minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
        for (var i = 0; i < mons.length; i++) {
            var m = mons[i];
            var w = m.width || 1920, h = m.height || 1080;
            var x = m.x || 0, y = m.y || 0;
            if (x < minX) minX = x;
            if (y < minY) minY = y;
            if (x + w > maxX) maxX = x + w;
            if (y + h > maxY) maxY = y + h;
        }

        // Add padding around the bounds
        var pad = 100; // extra 100px around all sides in real coords
        minX -= pad;
        minY -= pad;
        maxX += pad;
        maxY += pad;

        return {
            minX: minX,
            minY: minY,
            maxX: maxX,
            maxY: maxY,
            spanW: Math.max(maxX - minX, 1),
            spanH: Math.max(maxY - minY, 1)
        };
    }

    // Canvas scale factor: maps real coords to canvas pixels
    readonly property real viewScale: {
        var bounds = root.viewBounds;
        var cw = canvasArea.width - 20;  // 10px margin each side
        var ch = canvasArea.height - 20;
        if (cw <= 0 || ch <= 0) return 1.0;
        return Math.min(cw / bounds.spanW, ch / bounds.spanH);
    }

    // Convert real coordinate to canvas x
    function realToCanvasX(realX) {
        return (realX - root.viewBounds.minX) * root.viewScale + 10;
    }

    // Convert real coordinate to canvas y
    function realToCanvasY(realY) {
        return (realY - root.viewBounds.minY) * root.viewScale + 10;
    }

    // Convert canvas x to real coordinate
    function canvasToRealX(canvasX) {
        return Math.round((canvasX - 10) / root.viewScale + root.viewBounds.minX);
    }

    // Convert canvas y to real coordinate
    function canvasToRealY(canvasY) {
        return Math.round((canvasY - 10) / root.viewScale + root.viewBounds.minY);
    }

    // ── Auto-align: arrange monitors left-to-right ──
    function autoAlignMonitors() {
        var mons = root.monitors;
        if (!mons || mons.length === 0) return;
        var currentX = 0;
        for (var i = 0; i < mons.length; i++) {
            var m = mons[i];
            AxctlService.dispatch("monitor " + m.name + ",preferred," + currentX + "x0,auto");
            currentX += m.width;
        }
        root.hasChanges = true;
        refreshTimer.start();
    }

    Timer { id: refreshTimer; interval: 500; onTriggered: root.refreshMonitors() }

    // ── Save monitor config to Hyprland monitors.conf + monitors.lua ──
    function saveToConfig() {
        var data = [];
        var mons = root.monitors;
        if (!mons || mons.length === 0) return;
        for (var i = 0; i < mons.length; i++) {
            var m = mons[i];
            data.push({
                name: m.name,
                width: m.width,
                height: m.height,
                x: m.x,
                y: m.y,
                scale: m.scale,
                refreshRate: m.refreshRate,
                transform: m.transform || 0,
                enabled: true,
                bitdepth: 10
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
                flat: true
                hoverEnabled: true
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
                flat: true
                hoverEnabled: true
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

        // Canvas — uses Flickable for pan/scroll with real coords
        Flickable {
            id: flickArea
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(300, Math.max(180, root.monitors.length * 100))
            clip: true
            contentWidth: canvasContents.width
            contentHeight: canvasContents.height

            // Show scrollbars only when needed
            ScrollBar.horizontal: ScrollBar {
                policy: flickArea.contentWidth > flickArea.width ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                opacity: 0.5
            }
            ScrollBar.vertical: ScrollBar {
                policy: flickArea.contentHeight > flickArea.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                opacity: 0.5
            }

            StyledRect {
                id: canvasBg
                width: Math.max(flickArea.width, canvasContents.width)
                height: Math.max(flickArea.height, canvasContents.height)
                variant: "internalbg"
                radius: Styling.radius(-2)

                // Inner content with real coordinates
                Item {
                    id: canvasContents
                    // Content size = bounds of all monitors in canvas space + margins
                    width: root.viewBounds.spanW * root.viewScale + 20
                    height: root.viewBounds.spanH * root.viewScale + 20

                    // Grid lines at regular intervals (in real space)
                    Repeater {
                        model: Math.ceil(root.viewBounds.spanW / 400) + 1
                        Rectangle {
                            x: root.realToCanvasX(root.viewBounds.minX + index * 400)
                            y: 0
                            width: 1
                            height: canvasContents.height
                            color: Qt.rgba(Colors.outlineVariant.r, Colors.outlineVariant.g, Colors.outlineVariant.b, 0.08)
                            visible: x >= 0 && x <= canvasContents.width
                        }
                    }
                    Repeater {
                        model: Math.ceil(root.viewBounds.spanH / 400) + 1
                        Rectangle {
                            x: 0
                            y: root.realToCanvasY(root.viewBounds.minY + index * 400)
                            width: canvasContents.width
                            height: 1
                            color: Qt.rgba(Colors.outlineVariant.r, Colors.outlineVariant.g, Colors.outlineVariant.b, 0.08)
                            visible: y >= 0 && y <= canvasContents.height
                        }
                    }

                    // Origin marker (0,0)
                    Rectangle {
                        x: root.realToCanvasX(0) - 3
                        y: root.realToCanvasY(0) - 3
                        width: 6
                        height: 6
                        radius: 3
                        color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.3)
                    }

                    // Snap indicators (shows snap lines during drag)
                    property var snapLinesH: []
                    property var snapLinesV: []

                    Repeater {
                        model: canvasContents.snapLinesH
                        Rectangle {
                            x: modelData - 1
                            y: 0
                            width: 2
                            height: canvasContents.height
                            color: Qt.rgba(Styling.srItem("primary").r, Styling.srItem("primary").g, Styling.srItem("primary").b, 0.4)
                            visible: true
                        }
                    }

                    Repeater {
                        model: canvasContents.snapLinesV
                        Rectangle {
                            x: 0
                            y: modelData - 1
                            width: canvasContents.width
                            height: 2
                            color: Qt.rgba(Styling.srItem("primary").r, Styling.srItem("primary").g, Styling.srItem("primary").b, 0.4)
                            visible: true
                        }
                    }

                    // Monitor rectangles — positioned at REAL coordinates
                    Repeater {
                        model: root.monitors

                        delegate: Item {
                            id: monItem
                            required property int index
                            required property var modelData

                            // Position in canvas space = real coords transformed
                            // During drag, use dragState offset for live preview
                            x: {
                                if (root.dragState && root.dragState.index === index) {
                                    return root.realToCanvasX(modelData.x + root.dragState.offsetX);
                                }
                                return root.realToCanvasX(modelData.x);
                            }
                            y: {
                                if (root.dragState && root.dragState.index === index) {
                                    return root.realToCanvasY(modelData.y + root.dragState.offsetY);
                                }
                                return root.realToCanvasY(modelData.y);
                            }
                            width: Math.max(60, modelData.width * root.viewScale)
                            height: Math.max(40, modelData.height * root.viewScale)

                            // Body
                            StyledRect {
                                id: monBody
                                anchors.fill: parent
                                variant: modelData.focused ? "primary" : "internalbg"
                                radius: 6
                                border.width: modelData.focused ? 1.5 : 1
                                border.color: modelData.focused
                                    ? Styling.srItem("primary")
                                    : Colors.outlineVariant
                                opacity: modelData.focused ? 0.9 : 0.85
                            }

                            // Inner preview
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: parent.width > 70 ? 6 : 3
                                radius: 3
                                color: modelData.focused
                                    ? Qt.rgba(Styling.srItem("primary").r, Styling.srItem("primary").g, Styling.srItem("primary").b, 0.06)
                                    : Qt.rgba(Colors.overBackground.r, Colors.overBackground.g, Colors.overBackground.b, 0.03)
                            }

                            // Label
                            Column {
                                anchors.centerIn: parent; spacing: 2
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.name
                                    font.family: Config.theme.font
                                    font.pixelSize: Math.max(8, Math.min(12, Styling.fontSize(-3)))
                                    font.bold: true
                                    color: modelData.focused ? Styling.srItem("primary") : Colors.overBackground
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: {
                                        if (root.dragState && root.dragState.index === index) {
                                            return root.dragState.newX + "," + root.dragState.newY;
                                        }
                                        return modelData.x + "," + modelData.y;
                                    }
                                    font.family: Config.theme.font
                                    font.pixelSize: Math.max(7, Math.min(10, Styling.fontSize(-4)))
                                    color: Colors.outline
                                    visible: parent.parent.width > 70
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.width + "×" + modelData.height
                                    font.family: Config.theme.font
                                    font.pixelSize: Math.max(7, Math.min(10, Styling.fontSize(-4)))
                                    color: Colors.outline
                                    visible: parent.parent.width > 70
                                }
                            }

                            // Drag handle
                            MouseArea {
                                id: dragArea
                                anchors.fill: parent
                                cursorShape: Qt.SizeAllCursor
                                hoverEnabled: true

                                property real dragStartRealX: 0
                                property real dragStartRealY: 0
                                property real mouseStartCanvasX: 0
                                property real mouseStartCanvasY: 0
                                property bool dragging: false

                                onPressed: mouse => {
                                    monItem.z = 100
                                    dragging = true
                                    mouseStartCanvasX = mouse.x + monItem.x
                                    mouseStartCanvasY = mouse.y + monItem.y
                                    dragStartRealX = modelData.x
                                    dragStartRealY = modelData.y
                                    root.monitorSelected(index)
                                }

                                onPositionChanged: mouse => {
                                    if (!dragging) return

                                    // Current mouse position in canvas space
                                    var mcX = mouse.x + monItem.x
                                    var mcY = mouse.y + monItem.y

                                    // Delta in canvas pixels
                                    var dCanvasX = mcX - mouseStartCanvasX
                                    var dCanvasY = mcY - mouseStartCanvasY

                                    // Delta in real pixels
                                    var dRealX = dCanvasX / root.viewScale
                                    var dRealY = dCanvasY / root.viewScale

                                    // New position
                                    var newX = Math.round((dragStartRealX + dRealX) / 10) * 10
                                    var newY = Math.round((dragStartRealY + dRealY) / 10) * 10

                                    // Snap to edges of other monitors
                                    var mw = modelData.width
                                    var mh = modelData.height
                                    var snapPx = 50  // snap threshold in real pixels

                                    for (var k = 0; k < root.monitors.length; k++) {
                                        if (k === index) continue
                                        var o = root.monitors[k]
                                        if (!o) continue
                                        var ow = o.width || 1920, oh = o.height || 1080
                                        var ox = o.x || 0, oy = o.y || 0

                                        // Right edge of other → left edge of this
                                        if (Math.abs(newX - (ox + ow)) < snapPx) newX = ox + ow
                                        // Left edge of other → right edge of this
                                        if (Math.abs((newX + mw) - ox) < snapPx) newX = ox - mw
                                        // Bottom edge of other → top edge of this
                                        if (Math.abs(newY - (oy + oh)) < snapPx) newY = oy + oh
                                        // Top edge of other → bottom edge of this
                                        if (Math.abs((newY + mh) - oy) < snapPx) newY = oy - mh
                                        // Same X column
                                        if (Math.abs(newX - ox) < snapPx) newX = ox
                                        // Same Y row
                                        if (Math.abs(newY - oy) < snapPx) newY = oy
                                    }

                                    // Live preview: track drag state so the delegate can use it
                                    root.dragState = {
                                        index: index,
                                        offsetX: newX - modelData.x,
                                        offsetY: newY - modelData.y,
                                        newX: newX,
                                        newY: newY
                                    }
                                }

                                onReleased: {
                                    if (!dragging) return
                                    dragging = false
                                    monItem.z = 1

                                    var mon = root.monitors[index]
                                    if (!mon) return

                                    var rx = mon.x
                                    var ry = mon.y

                                    // Snap check on release (stronger snap)
                                    var mw = modelData.width
                                    var mh = modelData.height
                                    var snapPx = 80

                                    for (var k = 0; k < root.monitors.length; k++) {
                                        if (k === index) continue
                                        var o = root.monitors[k]
                                        if (!o) continue
                                        var ow = o.width || 1920, oh = o.height || 1080
                                        var ox = o.x || 0, oy = o.y || 0

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
                                        var o2x = o2.x || 0, o2y = o2.y || 0
                                        var o2w = o2.width || 1920, o2h = o2.height || 1080
                                        if (rx < o2x + o2w && rx + mw > o2x && ry < o2y + o2h && ry + mh > o2y) {
                                            var dL = rx + mw - o2x, dR = o2x + o2w - rx
                                            var dU = ry + mh - o2y, dD = o2y + o2h - ry
                                            var minD = Math.min(dL, dR, dU, dD)
                                            if (minD === dL) rx = o2x - mw
                                            else if (minD === dR) rx = o2x + o2w
                                            else if (minD === dU) ry = o2y - mh
                                            else ry = o2y + o2h
                                        }
                                    }

                                    // Final snap to round numbers
                                    rx = Math.round(rx / 10) * 10
                                    ry = Math.round(ry / 10) * 10

                                    // Update monitor position in the model (new array to trigger Repeater update)
                                    var newMons = [];
                                    for (var mi = 0; mi < root.monitors.length; mi++) {
                                        if (mi === index) {
                                            newMons.push({
                                                name: modelData.name,
                                                width: modelData.width,
                                                height: modelData.height,
                                                x: rx,
                                                y: ry,
                                                scale: modelData.scale,
                                                refreshRate: modelData.refreshRate,
                                                transform: modelData.transform || 0,
                                                focused: modelData.focused
                                            });
                                        } else {
                                            newMons.push(root.monitors[mi]);
                                        }
                                    }
                                    root.monitors = newMons;
                                    root.dragState = null

                                    root.hasChanges = true
                                    root.positionChanged(index, rx, ry)
                                    AxctlService.dispatch("monitor " + modelData.name + ",preferred," + rx + "x" + ry + ",auto")
                                }
                            }

                            // Hover glow
                            Rectangle {
                                anchors.fill: parent; anchors.margins: -3; radius: 8
                                color: "transparent"; border.width: 1.5
                                border.color: Qt.rgba(Styling.srItem("primary").r, Styling.srItem("primary").g, Styling.srItem("primary").b, 0.4)
                                visible: dragArea.containsMouse || dragArea.pressed
                                z: -1
                            }
                        }
                    }
                }
            }
        }

        // Info bar with real coordinates
        RowLayout {
            Layout.fillWidth: true
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
                    return root.hasChanges
                        ? "✓ " + parts.join(" · ")
                        : "🖱 " + parts.join(" · ");
                }
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-4)
                color: Colors.outline
                elide: Text.ElideRight
            }

            Text {
                text: "1:" + root.viewScale.toFixed(2)
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-5)
                color: Colors.outlineVariant
                visible: root.monitors.length > 0
            }
        }
    }
}
