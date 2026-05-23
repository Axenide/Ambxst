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

StyledRect {
    id: root

    variant: "pane"
    Layout.fillWidth: true
    Layout.preferredHeight: canvasColumn.implicitHeight + 16
    radius: Styling.radius(0)
    enableShadow: true

    property var monitors: []
    property bool hasChanges: false

    signal positionChanged(int monitorIndex, int newX, int newY)

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
                focused: (AxctlService.focusedMonitor && AxctlService.focusedMonitor.name === s.name)
            });
        }
        root.monitors = list;
    }

    Component.onCompleted: refreshMonitors()

    Connections {
        target: AxctlService
        function onMonitorsChanged() { root.refreshMonitors(); }
    }

    // ── Render list ──
    readonly property var renderList: {
        var list = [], mons = root.monitors;
        if (!mons || mons.length === 0) return list;
        var minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
        for (var i = 0; i < mons.length; i++) {
            var m = mons[i];
            var w = (m.width || 1920), h = (m.height || 1080);
            var x = (m.x || 0), y = (m.y || 0);
            if (x < minX) minX = x; if (y < minY) minY = y;
            if (x + w > maxX) maxX = x + w; if (y + h > maxY) maxY = y + h;
        }
        var spanW = Math.max(maxX - minX, 1), spanH = Math.max(maxY - minY, 1);
        for (var j = 0; j < mons.length; j++) {
            var mm = mons[j];
            list.push({
                name: mm.name, width: mm.width || 1920, height: mm.height || 1080,
                x: mm.x || 0, y: mm.y || 0, scale: mm.scale || 1.0,
                refreshRate: mm.refreshRate || 60, focused: mm.focused || false,
                normX: (mm.x || 0) - minX, normY: (mm.y || 0) - minY,
                normW: spanW, normH: spanH
            });
        }
        return list;
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
        // Refresh after a short delay for axctl to apply
        refreshTimer.start();
    }

    Timer { id: refreshTimer; interval: 500; onTriggered: root.refreshMonitors() }

    // ── Save monitor config directly to active Hyprland config ──
    function saveToConfig() {
        saveConfigProcess.running = true;
    }

    property Process saveConfigProcess: Process {
        command: [
            "bash", "-c",
            // Detect which config format is active
            'if [ -f "$HOME/.config/hypr/hyprland.lua" ]; then' +
            '  MODE="lua"; CFG="$HOME/.config/hypr/hyprland.lua";' +
            'elif [ -f "$HOME/.config/hypr/hyprland.conf" ]; then' +
            '  MODE="conf"; CFG="$HOME/.config/hypr/hyprland.conf";' +
            'elif [ -f "$HOME/.local/share/nothingless/hyprland.lua" ]; then' +
            '  MODE="lua"; CFG="$HOME/.local/share/nothingless/hyprland.lua";' +
            'elif [ -f "$HOME/.local/share/nothingless/hyprland.conf" ]; then' +
            '  MODE="conf"; CFG="$HOME/.local/share/nothingless/hyprland.conf";' +
            'else MODE="conf"; CFG="$HOME/.config/hypr/hyprland.conf"; fi;' +
            // Get current monitor data
            'MON_DATA=$(hyprctl monitors -j 2>/dev/null || echo "[]");' +
            'if [ "$MODE" = "conf" ]; then' +
            // .conf format: monitor=NAME,MODE,POS,SCALE
            '  MON_LINES=$(echo "$MON_DATA" | python3 -c "' +
            'import json,sys; mons=json.load(sys.stdin);' +
            'for m in mons:' +
            '  n=m.get(\"name\",\"\"); w=m.get(\"width\",0); h=m.get(\"height\",0);' +
            '  x=m.get(\"x\",0); y=m.get(\"y\",0); s=m.get(\"scale\",1);' +
            '  rr=m.get(\"refreshRate\",60); mode=f\"{w}x{h}@{(rr):.2f}Hz\";' +
            '  print(f\"monitor={n},{mode},{x}x{y},{s}\")' +
            '");' +
            '  if [ -f "$CFG" ]; then' +
            '    grep -v "^monitor=" "$CFG" > "${CFG}.tmp" 2>/dev/null;' +
            '    echo "$MON_LINES" >> "${CFG}.tmp"; mv "${CFG}.tmp" "$CFG";' +
            '  else echo "$MON_LINES" > "$CFG"; fi;' +
            '  echo "[OK] Updated $CFG ($MODE format)";' +
            'else' +
            // .lua format: hl.cmd("hyprctl dispatch monitor ...") for each monitor
            '  LUA_LINES=$(echo "$MON_DATA" | python3 -c "' +
            'import json,sys; mons=json.load(sys.stdin);' +
            'for m in mons:' +
            '  n=m.get(\"name\",\"\"); w=m.get(\"width\",0); h=m.get(\"height\",0);' +
            '  x=m.get(\"x\",0); y=m.get(\"y\",0); s=m.get(\"scale\",1);' +
            '  rr=m.get(\"refreshRate\",60); mode=f\"{w}x{h}@{(rr):.2f}Hz\";' +
            '  print(f\"hl.cmd(\\\"hyprctl dispatch monitor {n},{mode},{x}x{y},{s}\\\")\")' +
            '");' +
            '  if [ -f "$CFG" ]; then' +
            '    grep -v "hl.cmd.*dispatch monitor" "$CFG" > "${CFG}.tmp" 2>/dev/null;' +
            '    echo "-- Monitor configuration (generated by NothingLess)" >> "${CFG}.tmp";' +
            '    echo "$LUA_LINES" >> "${CFG}.tmp"; mv "${CFG}.tmp" "$CFG";' +
            '  else' +
            '    echo "-- Monitor configuration (generated by NothingLess)" > "$CFG";' +
            '    echo "$LUA_LINES" >> "$CFG";' +
            '  fi;' +
            '  echo "[OK] Updated $CFG ($MODE format)";' +
            'fi'
        ]
        stdout: SplitParser { onRead: data => { saveConfigProcess.buffer += data; } }
        running: false
        property string buffer: ""
        onExited: exitCode => {
            console.log("MonitorArrangementView: save output:", saveConfigProcess.buffer);
            saveConfigProcess.buffer = "";
            root.hasChanges = false;
        }
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

            // Auto-align button
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

            // Save config button
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

        // Canvas
        Item {
            id: canvasArea
            Layout.fillWidth: true
            Layout.preferredHeight: 180

            StyledRect {
                anchors.fill: parent
                variant: "internalbg"
                radius: Styling.radius(-2)

                // Grid
                Repeater {
                    model: 8
                    Rectangle {
                        x: index * canvasArea.width / 8; y: 0
                        width: 1; height: canvasArea.height
                        color: Qt.rgba(Colors.outlineVariant.r, Colors.outlineVariant.g, Colors.outlineVariant.b, 0.1)
                    }
                }
                Repeater {
                    model: 6
                    Rectangle {
                        x: 0; y: index * canvasArea.height / 6
                        width: canvasArea.width; height: 1
                        color: Qt.rgba(Colors.outlineVariant.r, Colors.outlineVariant.g, Colors.outlineVariant.b, 0.1)
                    }
                }

                // Monitor rectangles
                Repeater {
                    model: root.renderList

                    delegate: Item {
                        id: monItem
                        required property int index
                        required property var modelData

                        readonly property real pad: 24
                        readonly property real aw: Math.max(1, canvasArea.width - pad * 2)
                        readonly property real ah: Math.max(1, canvasArea.height - pad * 2)
                        readonly property real sw: Math.max(1, modelData.normW)
                        readonly property real sh: Math.max(1, modelData.normH)
                        readonly property real sc: Math.min(aw / sw, ah / sh)
                        readonly property real ox: pad + (aw - sw * sc) / 2
                        readonly property real oy: pad + (ah - sh * sc) / 2

                        x: ox + modelData.normX * sc
                        y: oy + modelData.normY * sc
                        width: Math.max(70, modelData.width * sc)
                        height: Math.max(44, modelData.height * sc)

                        // Body
                        StyledRect {
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
                            anchors.centerIn: parent; spacing: 0
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
                                text: modelData.width + "×" + modelData.height
                                font.family: Config.theme.font
                                font.pixelSize: Math.max(7, Math.min(10, Styling.fontSize(-4)))
                                color: Colors.outline
                                visible: parent.parent.width > 70
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Math.round(modelData.refreshRate) + " Hz"
                                font.family: Config.theme.font
                                font.pixelSize: Math.max(7, Math.min(10, Styling.fontSize(-4)))
                                color: Colors.outline
                                visible: parent.parent.width > 70
                            }
                        }

                        // Manual drag — snap to nearest edges on release
                        MouseArea {
                            id: dragArea
                            anchors.fill: parent
                            cursorShape: Qt.SizeAllCursor
                            hoverEnabled: true

                            property real pressX: 0
                            property real pressY: 0
                            property real startX: 0
                            property real startY: 0
                            property bool dragging: false

                            onPressed: mouse => {
                                monItem.z = 100
                                dragging = true
                                pressX = mouse.x
                                pressY = mouse.y
                                startX = monItem.x
                                startY = monItem.y
                            }

                            onPositionChanged: mouse => {
                                if (!dragging) return
                                // Free movement during drag
                                monItem.x = Math.max(0, Math.min(canvasArea.width - monItem.width, startX + mouse.x - pressX))
                                monItem.y = Math.max(0, Math.min(canvasArea.height - monItem.height, startY + mouse.y - pressY))
                            }

                            onReleased: {
                                dragging = false
                                monItem.z = 1

                                // Convert canvas position to real coordinates
                                var mnX = Infinity, mnY = Infinity
                                for (var k = 0; k < root.monitors.length; k++) {
                                    if (root.monitors[k].x < mnX) mnX = root.monitors[k].x
                                    if (root.monitors[k].y < mnY) mnY = root.monitors[k].y
                                }
                                if (mnX === Infinity) mnX = 0
                                if (mnY === Infinity) mnY = 0

                                var rx = Math.round((monItem.x - monItem.offX) / monItem.sc + mnX)
                                var ry = Math.round((monItem.y - monItem.offY) / monItem.sc + mnY)
                                var mw = modelData.width
                                var mh = modelData.height

                                // Snap to nearest edge of other monitors
                                var snapPx = 60  // snap threshold in real pixels
                                for (var k = 0; k < root.monitors.length; k++) {
                                    if (k === monItem.index) continue
                                    var o = root.monitors[k]
                                    if (!o) continue
                                    var ow = o.width || 1920, oh = o.height || 1080
                                    var ox = o.x || 0, oy = o.y || 0

                                    // Right edge of other → left edge of this
                                    if (Math.abs(rx - (ox + ow)) < snapPx) rx = ox + ow
                                    // Left edge of other → right edge of this
                                    if (Math.abs((rx + mw) - ox) < snapPx) rx = ox - mw
                                    // Bottom edge of other → top edge of this
                                    if (Math.abs(ry - (oy + oh)) < snapPx) ry = oy + oh
                                    // Top edge of other → bottom edge of this
                                    if (Math.abs((ry + mh) - oy) < snapPx) ry = oy - mh
                                    // Same X column
                                    if (Math.abs(rx - ox) < snapPx) rx = ox
                                    // Same Y row
                                    if (Math.abs(ry - oy) < snapPx) ry = oy
                                }

                                // Prevent overlap: if still overlapping after snap, push to nearest non-overlapping edge
                                for (var j = 0; j < root.monitors.length; j++) {
                                    if (j === monItem.index) continue
                                    var o2 = root.monitors[j]
                                    if (!o2) continue
                                    var o2x = o2.x || 0, o2y = o2.y || 0
                                    var o2w = o2.width || 1920, o2h = o2.height || 1080
                                    if (rx < o2x + o2w && rx + mw > o2x && ry < o2y + o2h && ry + mh > o2y) {
                                        // Push to nearest non-overlapping side
                                        var dL = rx + mw - o2x, dR = o2x + o2w - rx
                                        var dU = ry + mh - o2y, dD = o2y + o2h - ry
                                        var minD = Math.min(dL, dR, dU, dD)
                                        if (minD === dL) rx = o2x - mw
                                        else if (minD === dR) rx = o2x + o2w
                                        else if (minD === dU) ry = o2y - mh
                                        else ry = o2y + o2h
                                    }
                                }

                                rx = Math.round(rx / 10) * 10
                                ry = Math.round(ry / 10) * 10
                                root.hasChanges = true
                                root.positionChanged(monItem.index, rx, ry)
                                AxctlService.dispatch("monitor " + modelData.name + ",preferred," + rx + "x" + ry + ",auto")
                            }
                        }

                        // Hover glow
                        Rectangle {
                            anchors.fill: parent; anchors.margins: -3; radius: 8
                            color: "transparent"; border.width: 1.5
                            border.color: Qt.rgba(Styling.srItem("primary").r, Styling.srItem("primary").g, Styling.srItem("primary").b, 0.4)
                            visible: monItem.MouseArea && (monItem.MouseArea.containsMouse || monItem.MouseArea.pressed)
                            z: -1
                        }
                    }
                }
            }
        }

        // Hint
        Text {
            Layout.fillWidth: true
            text: root.renderList.length === 0
                ? "No monitors detected"
                : root.hasChanges ? "✓ Layout updated — drag monitors or click Auto-Arrange"
                                  : "🖱 Drag monitors to rearrange · Click Auto-Arrange to align"
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-4)
            color: Colors.outline
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
