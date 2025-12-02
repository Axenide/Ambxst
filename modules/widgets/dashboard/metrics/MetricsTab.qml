pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

Rectangle {
    id: root
    color: "transparent"
    implicitWidth: 400
    implicitHeight: 400

    property string hostname: ""
    property real chartZoom: 1.0

    // Adjust history points based on zoom and repaint chart
    onChartZoomChanged: {
        // Store enough history to support zoom out
        // Always store maximum (250 points) to allow smooth zooming
        SystemResources.maxHistoryPoints = 250;
        
        // Repaint chart when zoom changes
        chartCanvas.requestPaint();
    }

    // Load refresh interval from state
    Component.onCompleted: {
        const savedInterval = StateService.get("metricsRefreshInterval", 2000);
        SystemResources.updateInterval = Math.max(100, savedInterval);
        const savedZoom = StateService.get("metricsChartZoom", 1.0);
        // Limit zoom range: 0.2 (show all available) to 3.0 (zoom in)
        chartZoom = Math.max(0.2, Math.min(3.0, savedZoom));
        hostnameReader.running = true;
    }

    // Get hostname
    Process {
        id: hostnameReader
        running: false
        command: ["hostname"]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const host = text.trim();
                if (host) {
                    root.hostname = host.charAt(0).toUpperCase() + host.slice(1);
                }
            }
        }
    }

    // Watch for history changes to repaint chart
    Connections {
        target: SystemResources
        function onCpuHistoryChanged() {
            chartCanvas.requestPaint();
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 8

        // Left panel - Resources
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 250
            color: "transparent"
            radius: Styling.radius(4)

            ColumnLayout {
                anchors.fill: parent
                spacing: 8

                // User avatar
                Rectangle {
                    id: avatarContainer
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 8
                    width: 140
                    height: 140
                    radius: Config.roundness > 0 ? (height / 2) * (Config.roundness / 16) : 0
                    color: "transparent"

                    Image {
                        id: userAvatar
                        anchors.fill: parent
                        source: `file://${Quickshell.env("HOME")}/.face.icon`
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        asynchronous: true
                        visible: status === Image.Ready

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskThresholdMin: 0.5
                            maskSpreadAtMin: 1.0
                            maskSource: ShaderEffectSource {
                                sourceItem: Rectangle {
                                    width: userAvatar.width
                                    height: userAvatar.height
                                    radius: Config.roundness > 0 ? (height / 2) * (Config.roundness / 16) : 0
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: Icons.user
                        font.family: Icons.font
                        font.pixelSize: 64
                        color: Colors.overSurfaceVariant
                        visible: userAvatar.status !== Image.Ready
                    }
                }

                // Username@Hostname
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.bottomMargin: 8
                    text: {
                        const user = Quickshell.env("USER") || "user";
                        return root.hostname ? `${user}@${root.hostname.toLowerCase()}` : user;
                    }
                    font.family: Config.theme.font
                    font.pixelSize: Config.theme.fontSize
                    font.weight: Font.Bold
                    color: Colors.overBackground
                    visible: text !== ""
                }

                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    contentHeight: resourcesColumn.height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: resourcesColumn
                        width: parent.width
                        spacing: 12

                        // CPU
                        ResourceItem {
                            width: parent.width
                            icon: Icons.cpu
                            label: "CPU"
                            value: SystemResources.cpuUsage / 100
                            barColor: Colors.red
                        }

                        // RAM
                        ResourceItem {
                            width: parent.width
                            icon: Icons.ram
                            label: "RAM"
                            value: SystemResources.ramUsage / 100
                            barColor: Colors.blue
                        }

                        // GPU (if detected)
                        ResourceItem {
                            width: parent.width
                            visible: SystemResources.gpuDetected
                            icon: Icons.gpu
                            label: "GPU"
                            value: SystemResources.gpuUsage / 100
                            barColor: Colors.green
                        }

                        // Separator before disks
                        Separator {
                            width: parent.width
                            height: 2
                            gradient: null
                            color: Colors.surface
                        }

                        // Disks
                        Repeater {
                            id: diskRepeater
                            model: SystemResources.validDisks

                            Column {
                                required property string modelData
                                width: parent.width
                                spacing: 4

                                ResourceItem {
                                    width: parent.width
                                    icon: Icons.disk
                                    label: modelData
                                    value: SystemResources.diskUsage[modelData] ? SystemResources.diskUsage[modelData] / 100 : 0
                                    barColor: Colors.yellow
                                }

                                RowLayout {
                                    width: parent.width
                                    spacing: 8

                                    Text {
                                        text: modelData
                                        font.family: Config.theme.font
                                        font.pixelSize: Config.theme.fontSize - 2
                                        color: Colors.surfaceBright
                                        elide: Text.ElideMiddle
                                    }

                                    Separator {
                                        Layout.preferredHeight: 2
                                        Layout.fillWidth: true
                                        gradient: null
                                        color: Colors.surface
                                    }

                                    Text {
                                        text: `${Math.round((SystemResources.diskUsage[modelData] || 0))}%`
                                        font.family: Config.theme.font
                                        font.pixelSize: Math.max(8, Config.theme.fontSize - 2)
                                        font.weight: Font.Medium
                                        color: Colors.surfaceBright
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Right panel - Chart
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            StyledRect {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Styling.radius(4)
                variant: "pane"

                StyledRect {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: Styling.radius(0)
                    variant: "internalbg"

                    // Chart area
                    Canvas {
                        id: chartCanvas
                        anchors.fill: parent

                        onPaint: {
                            const ctx = getContext("2d");
                            const w = width;
                            const h = height;

                            // Clear canvas
                            ctx.clearRect(0, 0, w, h);

                            if (SystemResources.cpuHistory.length < 2)
                                return;

                            // Apply zoom to visible points
                            // Zoom is proportional across the entire range
                            // zoom 0.2 = 250 points (50 / 0.2)
                            // zoom 0.5 = 100 points (50 / 0.5)
                            // zoom 1.0 = 50 points
                            // zoom 2.0 = 25 points (50 / 2.0)
                            // zoom 3.0 = ~17 points (50 / 3.0)
                            const basePoints = 50;
                            const zoomedMaxPoints = Math.max(10, Math.floor(basePoints / root.chartZoom));

                            // Draw background grid (solid lines) - adjust to zoom
                            ctx.strokeStyle = Colors.surface;
                            ctx.lineWidth = 1;

                            // Horizontal grid lines (8 lines)
                            for (let i = 1; i < 8; i++) {
                                const y = h * (i / 8);
                                ctx.beginPath();
                                ctx.moveTo(0, y);
                                ctx.lineTo(w, y);
                                ctx.stroke();
                            }

                            // Vertical grid lines - adjust density based on zoom
                            // More zoom (fewer points) = fewer lines
                            // Less zoom (more points) = more lines
                            const baseVerticalLines = 10;
                            const verticalLines = Math.max(5, Math.floor(baseVerticalLines / root.chartZoom));
                            for (let i = 1; i < verticalLines; i++) {
                                const x = w * (i / verticalLines);
                                ctx.beginPath();
                                ctx.moveTo(x, 0);
                                ctx.lineTo(x, h);
                                ctx.stroke();
                            }

                            // Helper function to draw a line chart with gradient fill
                            function drawLine(history, color) {
                                if (history.length < 2)
                                    return;

                                // Get most recent data points based on zoom level
                                const visiblePoints = Math.min(zoomedMaxPoints, history.length);
                                const recentHistory = history.slice(-visiblePoints);
                                
                                // Calculate spacing to always fill the width with visible points
                                const pointSpacing = w / (zoomedMaxPoints - 1);
                                
                                // Calculate offset to align to the right
                                // If we have fewer points than zoomedMaxPoints, start from the right
                                const offset = w - ((recentHistory.length - 1) * pointSpacing);

                                // Create gradient from top to bottom
                                const gradient = ctx.createLinearGradient(0, 0, 0, h);
                                
                                // Parse the color to create gradient stops
                                // Gradient fades from the color with alpha to transparent at bottom
                                const colorStr = color.toString();
                                gradient.addColorStop(0, Qt.rgba(color.r, color.g, color.b, 0.4));
                                gradient.addColorStop(0.5, Qt.rgba(color.r, color.g, color.b, 0.2));
                                gradient.addColorStop(1, Qt.rgba(color.r, color.g, color.b, 0.0));

                                // Draw filled area
                                ctx.fillStyle = gradient;
                                ctx.beginPath();

                                // Start from bottom at first point position
                                const firstX = offset;
                                ctx.moveTo(firstX, h);

                                // Draw line to first data point
                                const firstY = h - (recentHistory[0] * h);
                                ctx.lineTo(firstX, firstY);

                                // Draw through all data points
                                for (let i = 1; i < recentHistory.length; i++) {
                                    const x = offset + (i * pointSpacing);
                                    const y = h - (recentHistory[i] * h);
                                    ctx.lineTo(x, y);
                                }

                                // Close path along bottom
                                const lastX = offset + ((recentHistory.length - 1) * pointSpacing);
                                ctx.lineTo(lastX, h);
                                ctx.closePath();
                                ctx.fill();

                                // Draw the line on top
                                ctx.strokeStyle = color;
                                ctx.lineWidth = 2;
                                ctx.lineCap = "round";
                                ctx.lineJoin = "round";
                                ctx.beginPath();

                                for (let i = 0; i < recentHistory.length; i++) {
                                    const x = offset + (i * pointSpacing);
                                    const y = h - (recentHistory[i] * h);

                                    if (i === 0) {
                                        ctx.moveTo(x, y);
                                    } else {
                                        ctx.lineTo(x, y);
                                    }
                                }

                                ctx.stroke();
                            }

                            // Draw CPU line (red)
                            drawLine(SystemResources.cpuHistory, Colors.red);

                            // Draw RAM line (blue)
                            drawLine(SystemResources.ramHistory, Colors.blue);

                            // Draw GPU line (green) if available
                            if (SystemResources.gpuDetected && SystemResources.gpuHistory.length > 0) {
                                drawLine(SystemResources.gpuHistory, Colors.green);
                            }
                        }
                    }
                }
            }

            // Controls panel
            StyledRect {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                radius: Styling.radius(4)
                variant: "pane"

                StyledRect {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: Styling.radius(0)
                    variant: "internalbg"

                    // Controls at right
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 8

                        // Zoom label
                        Text {
                            Layout.leftMargin: 4
                            text: "Zoom"
                            font.family: Config.theme.font
                            font.pixelSize: Config.theme.fontSize - 1
                            color: Colors.surfaceBright
                        }

                        // Zoom slider
                        StyledSlider {
                            Layout.fillWidth: true
                            Layout.preferredHeight: parent.height
                            vertical: false
                            value: (root.chartZoom - 0.2) / 2.8  // Map 0.2-3.0 to 0-1
                            progressColor: Colors.primary
                            backgroundColor: Colors.surface
                            tooltipText: root.chartZoom ? `${root.chartZoom.toFixed(1)}×` : "1.0×"
                            thickness: 3
                            handleSpacing: 2
                            wavy: false
                            icon: ""
                            iconPos: "start"
                            onValueChanged: {
                                const newZoom = 0.2 + (value * 2.8);  // Map 0-1 to 0.2-3.0
                                root.chartZoom = newZoom;
                                StateService.set("metricsChartZoom", newZoom);
                            }
                        }

                        // Spacer
                        Item {
                            Layout.preferredWidth: 8
                        }

                        // Decrease interval button
                        StyledRect {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            radius: Styling.radius(-4)
                            variant: "pane"

                            Text {
                                anchors.centerIn: parent
                                text: Icons.minus
                                font.family: Icons.font
                                font.pixelSize: 18
                                color: Colors.overBackground
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const newInterval = Math.max(100, SystemResources.updateInterval - 100);
                                    SystemResources.updateInterval = newInterval;
                                    StateService.set("metricsRefreshInterval", newInterval);
                                }
                            }

                            Behavior on color {
                                enabled: Config.animDuration > 0
                                ColorAnimation {
                                    duration: Config.animDuration
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        // Interval display
                        Text {
                            text: `${SystemResources.updateInterval}ms`
                            font.family: Config.theme.font
                            font.pixelSize: Config.theme.fontSize
                            font.weight: Font.Bold
                            color: Colors.overBackground
                        }

                        // Increase interval button
                        StyledRect {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            radius: Styling.radius(-4)
                            variant: "pane"

                            Text {
                                anchors.centerIn: parent
                                text: Icons.plus
                                font.family: Icons.font
                                font.pixelSize: 18
                                color: Colors.overBackground
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const newInterval = SystemResources.updateInterval + 100;
                                    SystemResources.updateInterval = newInterval;
                                    StateService.set("metricsRefreshInterval", newInterval);
                                }
                            }

                            Behavior on color {
                                enabled: Config.animDuration > 0
                                ColorAnimation {
                                    duration: Config.animDuration
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
