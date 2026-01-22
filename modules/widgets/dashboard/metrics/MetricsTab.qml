pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.globals
import qs.config

Rectangle {
    id: root
    color: "transparent"
    implicitWidth: 400
    implicitHeight: 400

    property string hostname: ""
    property string osName: ""
    property string osIcon: ""
    property var linuxLogos: null
    property real chartZoom: 1.0

    // Adjust history points based on zoom and repaint chart
    onChartZoomChanged: {
        // Store enough history to support zoom out
        // Always store maximum (250 points) to allow smooth zooming
        SystemResources.maxHistoryPoints = 250;

        // Repaint chart when zoom changes
        chartCanvas.requestPaint();
    }

    // Function to get OS icon based on name
    function getOsIcon(osName) {
        if (!osName || !linuxLogos) {
            return "";
        }

        // Try exact match first
        if (linuxLogos[osName]) {
            return linuxLogos[osName];
        }

        // Try partial match
        for (const distro in linuxLogos) {
            if (osName.toLowerCase().includes(distro.toLowerCase())) {
                return linuxLogos[distro];
            }
        }

        // Default to generic Linux icon
        return linuxLogos["Linux"] || "";
    }

    // Update OS icon when logos are loaded
    onLinuxLogosChanged: {
        if (linuxLogos && osName) {
            const icon = getOsIcon(osName);
            osIcon = icon || "";
        }
    }

    // Load refresh interval from state
    Component.onCompleted: {
        // Always store maximum (250 points) to allow smooth zooming
        SystemResources.maxHistoryPoints = 250;

        const savedInterval = StateService.get("metricsRefreshInterval", 2000);
        SystemResources.updateInterval = Math.max(100, savedInterval);
        const savedZoom = StateService.get("metricsChartZoom", 1.0);
        // Limit zoom range: 0.2 (show all available) to 3.0 (zoom in)
        chartZoom = Math.max(0.2, Math.min(3.0, savedZoom));

        hostnameReader.running = true;
        osReader.running = true;
        linuxLogosReader.running = true;
    }

    // Load Linux logos JSON
    Process {
        id: linuxLogosReader
        running: false
        command: ["cat", Qt.resolvedUrl("../../../../assets/linux-logos.json").toString().replace("file://", "")]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    if (!text || text.trim().length === 0) {
                        console.warn("linux-logos.json is empty");
                        return;
                    }
                    root.linuxLogos = JSON.parse(text);
                    console.log("Loaded", Object.keys(root.linuxLogos).length, "Linux logos");
                } catch (e) {
                    console.warn("Failed to parse linux-logos.json:", e);
                    console.warn("Text received:", text.substring(0, 100));
                }
            }
        }
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

    // Get OS name
    Process {
        id: osReader
        running: false
        command: ["sh", "-c", "grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '\"'"]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const os = text.trim();
                if (os) {
                    root.osName = os;
                    // Only set icon if logos are already loaded
                    if (root.linuxLogos) {
                        const icon = getOsIcon(os);
                        root.osIcon = icon || "";
                    }
                }
            }
        }
    }

    // Update chart when becoming visible
    onVisibleChanged: {
        if (visible) chartCanvas.requestPaint();
    }

    // Watch for history changes to repaint chart
    Connections {
        target: SystemResources
        function onCpuHistoryChanged() {
            if (root.visible) chartCanvas.requestPaint();
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
                spacing: 2

                // User info section - Avatar left, info right
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    spacing: 16

                    // User avatar
                    StyledRect {
                        id: avatarContainer
                        Layout.preferredWidth: 96
                        Layout.preferredHeight: 96
                        radius: Config.roundness > 0 ? (height / 2) * (Config.roundness / 16) : 0
                        variant: "primary"

                        Image {
                            id: userAvatar
                            anchors.fill: parent
                            anchors.margins: 2
                            source: `file://${Quickshell.env("HOME")}/.face.icon?${GlobalStates.avatarCacheBuster}`
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
                            font.pixelSize: 48
                            color: Colors.overSurfaceVariant
                            visible: userAvatar.status !== Image.Ready
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: GlobalStates.pickUserAvatar()

                            Rectangle {
                                anchors.fill: parent
                                color: Colors.overSurface
                                opacity: parent.containsMouse ? 0.1 : 0
                                radius: avatarContainer.radius

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 150
                                    }
                                }
                            }
                        }
                    }

                    // User info column
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        // Username
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: Icons.user
                                font.family: Icons.font
                                font.pixelSize: Config.theme.fontSize + 2
                                color: Styling.srItem("overprimary")
                            }

                            Text {
                                Layout.fillWidth: true
                                text: {
                                    const user = Quickshell.env("USER") || "user";
                                    return user.charAt(0).toUpperCase() + user.slice(1);
                                }
                                font.family: Config.theme.font
                                font.pixelSize: Config.theme.fontSize
                                font.weight: Font.Medium
                                color: Colors.overBackground
                                elide: Text.ElideRight
                            }
                        }

                        // Hostname
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: Icons.at
                                font.family: Icons.font
                                font.pixelSize: Config.theme.fontSize + 2
                                color: Styling.srItem("overprimary")
                            }

                            Text {
                                Layout.fillWidth: true
                                text: {
                                    if (!root.hostname)
                                        return "Hostname";
                                    const host = root.hostname.toLowerCase();
                                    return host.charAt(0).toUpperCase() + host.slice(1);
                                }
                                font.family: Config.theme.font
                                font.pixelSize: Config.theme.fontSize
                                font.weight: Font.Medium
                                color: Colors.overBackground
                                elide: Text.ElideRight
                            }
                        }

                        // OS
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: root.osIcon || (root.linuxLogos ? (root.linuxLogos["Linux"] || "") : "")
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: Config.theme.fontSize + 2
                                color: Styling.srItem("overprimary")
                            }

                            Text {
                                Layout.fillWidth: true
                                text: root.osName || "Linux"
                                font.family: Config.theme.font
                                font.pixelSize: Config.theme.fontSize
                                font.weight: Font.Medium
                                color: Colors.overBackground
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                // System separator
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    spacing: 8

                    Separator {
                        Layout.preferredHeight: 2
                        Layout.fillWidth: true
                    }

                    Text {
                        text: "System"
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-2)
                        color: Colors.overBackground
                    }

                    Separator {
                        Layout.preferredHeight: 2
                        Layout.fillWidth: true
                    }
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
                        Column {
                            width: parent.width
                            spacing: 4

                            ResourceItem {
                                width: parent.width
                                icon: Icons.cpu
                                label: "CPU"
                                value: SystemResources.cpuUsage / 100
                                barColor: Colors.red
                            }

                            RowLayout {
                                width: parent.width
                                spacing: 4

                                Text {
                                    text: SystemResources.cpuModel || "CPU"
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-2)
                                    color: Colors.overBackground
                                    elide: Text.ElideMiddle
                                }

                                Separator {
                                    Layout.preferredHeight: 2
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: `${Math.round(SystemResources.cpuUsage)}%`
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-2)
                                    font.weight: Font.Medium
                                    color: Colors.overBackground
                                }

                                Text {
                                    visible: SystemResources.cpuTemp >= 0
                                    text: Icons.temperature
                                    font.family: Icons.font
                                    font.pixelSize: Styling.fontSize(-2)
                                    color: Colors.red
                                }

                                Text {
                                    visible: SystemResources.cpuTemp >= 0
                                    text: `${SystemResources.cpuTemp}°`
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-2)
                                    font.weight: Font.Medium
                                    color: Colors.overBackground
                                }
                            }
                        }

                        // RAM
                        Column {
                            width: parent.width
                            spacing: 4

                            ResourceItem {
                                width: parent.width
                                icon: Icons.ram
                                label: "RAM"
                                value: SystemResources.ramUsage / 100
                                barColor: Colors.cyan
                            }

                            RowLayout {
                                width: parent.width
                                spacing: 4

                                Text {
                                    text: {
                                        const usedGB = (SystemResources.ramUsed / 1024 / 1024).toFixed(1);
                                        const totalGB = (SystemResources.ramTotal / 1024 / 1024).toFixed(1);
                                        return `${usedGB} GB / ${totalGB} GB`;
                                    }
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-2)
                                    color: Colors.overBackground
                                    elide: Text.ElideMiddle
                                }

                                Separator {
                                    Layout.preferredHeight: 2
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: `${Math.round(SystemResources.ramUsage)}%`
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-2)
                                    font.weight: Font.Medium
                                    color: Colors.overBackground
                                }
                            }
                        }

                        // GPUs (if detected) - show one bar per GPU
                        Repeater {
                            id: gpuRepeater
                            model: SystemResources.gpuDetected ? SystemResources.gpuCount : 0

                            Column {
                                required property int index
                                width: parent.width
                                spacing: 4

                                ResourceItem {
                                    width: parent.width
                                    icon: Icons.gpu
                                    label: {
                                        const name = SystemResources.gpuNames[index] || "";
                                        const vendor = SystemResources.gpuVendors[index] || "";

                                        // If we have a descriptive name, use it
                                        if (name && name !== `${vendor.toUpperCase()} GPU ${index}`) {
                                            return name;
                                        }
                                        // Otherwise show GPU index if multiple, or just "GPU" if single
                                        return SystemResources.gpuCount > 1 ? `GPU ${index}` : "GPU";
                                    }
                                    value: (SystemResources.gpuUsages[index] || 0) / 100
                                    barColor: {
                                        // Color based on vendor
                                        const vendor = SystemResources.gpuVendors[index] || "";
                                        switch (vendor.toLowerCase()) {
                                        case "nvidia":
                                            return Colors.green;
                                        case "amd":
                                            return Colors.red;
                                        case "intel":
                                            return Colors.blue;
                                        default:
                                            return Colors.magenta;
                                        }
                                    }
                                }

                                RowLayout {
                                    width: parent.width
                                    spacing: 4

                                    Text {
                                        text: {
                                            const name = SystemResources.gpuNames[index] || "";
                                            return name || "GPU";
                                        }
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-2)
                                        color: Colors.overBackground
                                        elide: Text.ElideMiddle
                                    }

                                    Separator {
                                        Layout.preferredHeight: 2
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: `${Math.round(SystemResources.gpuUsages[index] || 0)}%`
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-2)
                                        font.weight: Font.Medium
                                        color: Colors.overBackground
                                    }

                                    Text {
                                        visible: (SystemResources.gpuTemps[index] ?? -1) >= 0
                                        text: Icons.temperature
                                        font.family: Icons.font
                                        font.pixelSize: Styling.fontSize(-2)
                                        color: {
                                            const vendor = SystemResources.gpuVendors[index] || "";
                                            switch (vendor.toLowerCase()) {
                                            case "nvidia":
                                                return Colors.green;
                                            case "amd":
                                                return Colors.red;
                                            case "intel":
                                                return Colors.blue;
                                            default:
                                                return Colors.magenta;
                                            }
                                        }
                                    }

                                    Text {
                                        visible: (SystemResources.gpuTemps[index] ?? -1) >= 0
                                        text: `${SystemResources.gpuTemps[index]}°`
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-2)
                                        font.weight: Font.Medium
                                        color: Colors.overBackground
                                    }
                                }
                            }
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
                                    icon: {
                                        const diskType = SystemResources.diskTypes[modelData] || "unknown";
                                        switch (diskType) {
                                        case "ssd":
                                            return Icons.ssd;
                                        case "hdd":
                                            return Icons.hdd;
                                        default:
                                            return Icons.disk;
                                        }
                                    }
                                    label: modelData
                                    value: SystemResources.diskUsage[modelData] ? SystemResources.diskUsage[modelData] / 100 : 0
                                    barColor: Colors.yellow
                                }

                                RowLayout {
                                    width: parent.width
                                    spacing: 4

                                    Text {
                                        text: modelData
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-2)
                                        color: Colors.overBackground
                                        elide: Text.ElideMiddle
                                    }

                                    Separator {
                                        Layout.preferredHeight: 2
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: `${Math.round((SystemResources.diskUsage[modelData] || 0))}%`
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-2)
                                        font.weight: Font.Medium
                                        color: Colors.overBackground
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

                            // === COORDINATE SYSTEM SETUP ===
                            // Apply zoom to visible points
                            const basePoints = 50;
                            const zoomedMaxPoints = Math.max(10, Math.floor(basePoints / root.chartZoom));

                            // Core spacing: each data point gets this many pixels
                            const pointSpacing = w / (zoomedMaxPoints - 1);

                            // Calculate offset to align graph to the right
                            const actualPoints = Math.min(zoomedMaxPoints, SystemResources.cpuHistory.length);
                            const graphOffset = w - ((actualPoints - 1) * pointSpacing);

                            // === GRID RENDERING ===
                            // Grid now uses the SAME coordinate system as the data
                            ctx.strokeStyle = Colors.surface;
                            ctx.lineWidth = 1;

                            // Horizontal grid lines (percentage-based, fixed at 8 divisions)
                            for (let i = 1; i < 8; i++) {
                                const y = h * (i / 8);
                                ctx.beginPath();
                                ctx.moveTo(0, y);
                                ctx.lineTo(w, y);
                                ctx.stroke();
                            }

                            // Vertical grid lines every 10 points
                            ctx.strokeStyle = Colors.surface;
                            ctx.lineWidth = 2;

                            // Use the absolute data point counter for infinite scrolling
                            const totalDataPoints = SystemResources.totalDataPoints;

                            // Calculate where the visible window starts in absolute terms
                            const windowStartIndex = totalDataPoints - actualPoints;

                            // Find the first grid line (multiple of 10) that should appear
                            const firstGridLine = Math.floor(windowStartIndex / 10) * 10;

                            // Draw vertical lines every 10 data points
                            // Continue until we pass the right edge of the canvas
                            for (let absoluteIndex = firstGridLine; absoluteIndex <= totalDataPoints + 10; absoluteIndex += 10) {
                                // Convert absolute index to position within visible window
                                const visibleIndex = absoluteIndex - windowStartIndex;

                                // Only draw if within visible range
                                if (visibleIndex >= 0 && visibleIndex < actualPoints) {
                                    const x = graphOffset + (visibleIndex * pointSpacing);
                                    ctx.beginPath();
                                    ctx.moveTo(x, 0);
                                    ctx.lineTo(x, h);
                                    ctx.stroke();
                                }
                            }

                            // === DATA RENDERING ===
                            // Helper function to draw a line chart with gradient fill
                            function drawLine(history, color) {
                                if (history.length < 2)
                                    return;

                                // Get most recent data points based on zoom level
                                const visiblePoints = Math.min(zoomedMaxPoints, history.length);
                                const recentHistory = history.slice(-visiblePoints);

                                // Use same offset as grid for perfect alignment
                                const dataOffset = graphOffset;

                                // Create gradient from top to bottom
                                const gradient = ctx.createLinearGradient(0, 0, 0, h);
                                gradient.addColorStop(0, Qt.rgba(color.r, color.g, color.b, 0.4));
                                gradient.addColorStop(0.5, Qt.rgba(color.r, color.g, color.b, 0.2));
                                gradient.addColorStop(1, Qt.rgba(color.r, color.g, color.b, 0.0));

                                // Draw filled area
                                ctx.fillStyle = gradient;
                                ctx.beginPath();

                                // Start from bottom at first point position
                                const firstX = dataOffset;
                                ctx.moveTo(firstX, h);

                                // Draw line to first data point
                                const firstY = h - (recentHistory[0] * h);
                                ctx.lineTo(firstX, firstY);

                                // Draw through all data points
                                for (let i = 1; i < recentHistory.length; i++) {
                                    const x = dataOffset + (i * pointSpacing);
                                    const y = h - (recentHistory[i] * h);
                                    ctx.lineTo(x, y);
                                }

                                // Close path along bottom
                                const lastX = dataOffset + ((recentHistory.length - 1) * pointSpacing);
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
                                    const x = dataOffset + (i * pointSpacing);
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

                            // Draw RAM line (cyan)
                            drawLine(SystemResources.ramHistory, Colors.cyan);

                            // Draw GPU lines (color based on vendor)
                            if (SystemResources.gpuDetected && SystemResources.gpuCount > 0) {
                                for (let i = 0; i < SystemResources.gpuCount; i++) {
                                    if (SystemResources.gpuHistories[i] && SystemResources.gpuHistories[i].length > 0) {
                                        // Get vendor-specific color
                                        const vendor = SystemResources.gpuVendors[i] || "";
                                        let color;
                                        switch (vendor.toLowerCase()) {
                                        case "nvidia":
                                            color = Colors.green;
                                            break;
                                        case "amd":
                                            color = Colors.red;
                                            break;
                                        case "intel":
                                            color = Colors.blue;
                                            break;
                                        default:
                                            color = Colors.magenta;
                                            break;
                                        }
                                        drawLine(SystemResources.gpuHistories[i], color);
                                    }
                                }
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

                        // Zoom out icon
                        Rectangle {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            color: "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: Icons.glassMinus
                                font.family: Icons.font
                                font.pixelSize: 18
                                color: Colors.overBackground
                            }
                        }

                        // Zoom slider
                        StyledSlider {
                            Layout.fillWidth: true
                            Layout.preferredHeight: parent.height
                            vertical: false
                            value: (root.chartZoom - 0.2) / 2.8  // Map 0.2-3.0 to 0-1
                            progressColor: Styling.srItem("overprimary")
                            backgroundColor: Colors.surface
                            tooltipText: root.chartZoom ? `${root.chartZoom.toFixed(1)}×` : "1.0×"
                            thickness: 3
                            handleSpacing: 2
                            wavy: false
                            icon: ""
                            iconPos: "start"
                            stepSize: 0.1
                            snapMode: "always"
                            onValueChanged: {
                                const newZoom = 0.2 + (value * 2.8);  // Map 0-1 to 0.2-3.0
                                root.chartZoom = newZoom;
                                StateService.set("metricsChartZoom", newZoom);
                            }
                        }

                        // Zoom in icon
                        Rectangle {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            color: "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: Icons.glassPlus
                                font.family: Icons.font
                                font.pixelSize: 18
                                color: Colors.overBackground
                            }
                        }

                        // Separator
                        Separator {
                            Layout.fillHeight: true
                            Layout.preferredWidth: 2
                            Layout.topMargin: 4
                            Layout.bottomMargin: 4
                            vert: true
                        }

                        // Decrease interval button
                        StyledRect {
                            id: decreaseIntervalBtn
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            radius: Styling.radius(-4)
                            variant: decreaseIntervalMa.containsMouse ? "focus" : "pane"

                            Text {
                                anchors.centerIn: parent
                                text: Icons.minus
                                font.family: Icons.font
                                font.pixelSize: 18
                                color: Colors.overBackground
                            }

                            MouseArea {
                                id: decreaseIntervalMa
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
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
                            id: increaseIntervalBtn
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            radius: Styling.radius(-4)
                            variant: increaseIntervalMa.containsMouse ? "focus" : "pane"

                            Text {
                                anchors.centerIn: parent
                                text: Icons.plus
                                font.family: Icons.font
                                font.pixelSize: 18
                                color: Colors.overBackground
                            }

                            MouseArea {
                                id: increaseIntervalMa
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
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
