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

Flickable {
    id: root
    contentHeight: content.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    signal applyChanges(var data)

    // Local State
    property bool cpuUsage: true
    property bool cpuTemp: true
    property bool cpuPower: false
    property bool ram: true
    property bool gpuUsage: true
    property bool gpuTemp: true
    property bool gpuPower: true
    property bool fps: true
    property bool disk: true
    property string colorCpu: "#5EADFF"
    property string colorGpu: "#B0B0B0"
    property string colorFps: "#64FFDA"
    property string colorRam: "#F59E0B"
    property string colorDisk: "#C084FC"
    
    property bool saved: false
    property bool raplOK: false
    property bool raplBusy: false

    Component.onCompleted: loadFromState()

    function loadFromState() {
        cpuUsage  = StateService.get("metricCpuUsage", true)
        cpuTemp   = StateService.get("metricCpuTemp", true)
        cpuPower  = StateService.get("metricCpuPower", false)
        ram       = StateService.get("metricRam", true)
        gpuUsage  = StateService.get("metricGpuUsage", true)
        gpuTemp   = StateService.get("metricGpuTemp", true)
        gpuPower  = StateService.get("metricGpuPower", true)
        fps       = StateService.get("metricFps", true)
        disk      = StateService.get("metricDisk", true)
        colorCpu  = StateService.get("metricColorCpu", "#5EADFF")
        colorGpu  = StateService.get("metricColorGpu", "#B0B0B0")
        colorFps  = StateService.get("metricColorFps", "#64FFDA")
        colorRam  = StateService.get("metricColorRam", "#F59E0B")
        colorDisk = StateService.get("metricColorDisk", "#C084FC")
        checkRapl()
        saveToSystem()
    }

    function saveToSystem() {
        SystemResources.cpuUsageEnabled  = cpuUsage
        SystemResources.cpuTempEnabled   = cpuTemp
        SystemResources.cpuPowerEnabled  = cpuPower
        SystemResources.ramEnabled       = ram
        SystemResources.gpuUsageEnabled  = gpuUsage
        SystemResources.gpuTempEnabled   = gpuTemp
        SystemResources.gpuPowerEnabled  = gpuPower
        SystemResources.fpsEnabled       = fps
        SystemResources.diskEnabled      = disk
        SystemResources.metricColorCpu   = colorCpu
        SystemResources.metricColorGpu   = colorGpu
        SystemResources.metricColorFps   = colorFps
        SystemResources.metricColorRam   = colorRam
        SystemResources.metricColorDisk  = colorDisk

        StateService.set("metricCpuUsage", cpuUsage)
        StateService.set("metricCpuTemp", cpuTemp)
        StateService.set("metricCpuPower", cpuPower)
        StateService.set("metricRam", ram)
        StateService.set("metricGpuUsage", gpuUsage)
        StateService.set("metricGpuTemp", gpuTemp)
        StateService.set("metricGpuPower", gpuPower)
        StateService.set("metricFps", fps)
        StateService.set("metricDisk", disk)
        StateService.set("metricColorCpu", colorCpu)
        StateService.set("metricColorGpu", colorGpu)
        StateService.set("metricColorFps", colorFps)
        StateService.set("metricColorRam", colorRam)
        StateService.set("metricColorDisk", colorDisk)

        SystemResources.notchVersion++
        SystemResources.saveMetricsConfig()
        saved = true
        saveTimer.restart()
    }

    Timer { id: saveTimer; interval: 2000; onTriggered: saved = false }

    function checkRapl() {
        const p = Qt.createQmlObject('import Quickshell.Io; Process { running:true; command:["test","-r","/sys/class/powercap/intel-rapl:0/energy_uj"]; onExited:destroy() }', root)
        if (p) p.exited.connect(function(){ raplOK = (p.exitCode === 0); p.destroy() })
    }

    function installRapl() {
        raplBusy = true
        var d = Quickshell.shellDir
        var p = Qt.createQmlObject('import Quickshell.Io; Process { running:true; command:["pkexec","sh","-c","cp ' + d + '/config/99-rapl-permissions.rules /etc/udev/rules.d/ \u0026\u0026 udevadm control --reload-rules \u0026\u0026 udevadm trigger"]; onExited:destroy() }', root)
        if (p) p.exited.connect(function(){ raplBusy=false; if(p.exitCode===0) checkRapl(); p.destroy() })
        else raplBusy=false
    }

    function useThemeColors() {
        colorCpu = String(Styling.srItem("overprimary") || "#5EADFF")
        colorGpu = String(Colors.cyan || "#84d5c4")
        colorFps = String(Colors.green || "#6BCB77")
        colorRam = String(Colors.yellow || Colors.lightYellow || "#F59E0B")
        colorDisk = String(Colors.magenta || "#C084FC")
        saveToSystem()
    }

    function useWallColors() {
        colorCpu = String(Colors.red || Colors.error || "#FF6B6B")
        colorGpu = String(Colors.cyan || "#5EADFF")
        colorFps = String(Colors.yellow || Colors.lightYellow || "#FFD93D")
        colorRam = String(Colors.green || "#6BCB77")
        colorDisk = String(Colors.magenta || "#C084FC")
        saveToSystem()
    }

    ColumnLayout {
        id: content
        width: parent.width
        spacing: 8

        Text {
            Layout.fillWidth: true
            text: "Metrics Setup"
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            font.weight: Font.Medium
            color: Colors.overBackground
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Colors.outline }

        // ── CPU ──
        ConfigToggleRow { icon: Icons.cpu; label: "CPU Usage %"; on: root.cpuUsage; onToggled: { root.cpuUsage = v } }
        ConfigToggleRow { icon: Icons.temperature; label: "CPU Temperature"; on: root.cpuTemp; onToggled: { root.cpuTemp = v } }
        ConfigToggleRow { icon: Icons.lightning; label: "CPU Power (RAPL)"; on: root.cpuPower; onToggled: { root.cpuPower = v; if(v && !root.raplOK) root.installRapl() } }
        RowLayout {
            Layout.leftMargin: 28; visible: root.cpuPower; spacing: 4
            Text { visible: !root.raplOK; text: "\u26A0"; font.pixelSize: 10; color: Colors.yellow }
            Text { text: root.raplOK ? "\u2713 RAPL ready" : root.raplBusy ? "Requesting..." : "Needs permission"; font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-4); color: root.raplOK ? Colors.green : Colors.yellow }
        }
        ConfigColorPick { label: "CPU Color"; color: root.colorCpu; visible: root.cpuUsage || root.cpuTemp || root.cpuPower; onPicked: { root.colorCpu = hex } }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Colors.outline + "44" }

        // ── GPU ──
        ConfigToggleRow { icon: Icons.gpu; label: "GPU Usage %"; on: root.gpuUsage; onToggled: { root.gpuUsage = v } }
        ConfigToggleRow { icon: Icons.temperature; label: "GPU Temperature"; on: root.gpuTemp; onToggled: { root.gpuTemp = v } }
        ConfigToggleRow { icon: Icons.lightning; label: "GPU Power"; on: root.gpuPower; onToggled: { root.gpuPower = v } }
        ConfigColorPick { label: "GPU Color"; color: root.colorGpu; visible: root.gpuUsage || root.gpuTemp || root.gpuPower; onPicked: { root.colorGpu = hex } }



        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Colors.outline + "44" }

        // ── RAM ──
        ConfigToggleRow { icon: Icons.ram; label: "RAM Usage %"; on: root.ram; onToggled: { root.ram = v } }
        ConfigColorPick { label: "RAM Color"; color: root.colorRam; visible: root.ram; onPicked: { root.colorRam = hex } }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Colors.outline + "44" }

        // ── DISK ──
        ConfigToggleRow { icon: Icons.disk; label: "Disk Usage %"; on: root.disk; onToggled: { root.disk = v } }
        ConfigColorPick { label: "Disk Color"; color: root.colorDisk; visible: root.disk; onPicked: { root.colorDisk = hex } }

        // ── FPS ──
        ConfigToggleRow { icon: Icons.recordScreen; label: "FPS (Built-in)"; on: root.fps; onToggled: { root.fps = v } }
        ConfigColorPick { label: "FPS Color"; color: root.colorFps; visible: root.fps; onPicked: { root.colorFps = hex } }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Colors.outline + "44" }

        // ── Quick Palettes ──
        Text { text: "Quick Palettes"; font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-2); font.weight: Font.Medium; color: Colors.overBackground }
        RowLayout {
            Layout.fillWidth: true; spacing: 4
            StyledRect { Layout.preferredHeight: 22; Layout.fillWidth: true; radius: Styling.radius(-4); variant: themeMa.containsMouse ? "focus" : "pane"
                Text { anchors.centerIn: parent; text: "Theme"; font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-4); color: Styling.srItem("overprimary") }
                MouseArea { id: themeMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true; onClicked: root.useThemeColors() } }
            StyledRect { Layout.preferredHeight: 22; Layout.fillWidth: true; radius: Styling.radius(-4); variant: wallMa.containsMouse ? "focus" : "pane"
                Text { anchors.centerIn: parent; text: "Wallpaper"; font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-4); color: Colors.overBackground }
                MouseArea { id: wallMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true; onClicked: root.useWallColors() } }
            StyledRect { Layout.preferredHeight: 22; Layout.fillWidth: true; radius: Styling.radius(-4); variant: resetMa.containsMouse ? "focus" : "pane"
                Text { anchors.centerIn: parent; text: "Reset"; font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-4); color: Colors.overSurfaceVariant }
                MouseArea { id: resetMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true; onClicked: { root.colorCpu="#5EADFF"; root.colorGpu="#B0B0B0"; root.colorFps="#64FFDA"; root.colorRam="#F59E0B"; root.colorDisk="#C084FC"; root.saveToSystem() } } }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Colors.outline + "44" }

        // ── SAVE BUTTON ──
        StyledRect {
            Layout.fillWidth: true; Layout.preferredHeight: 36; radius: Styling.radius(0)
            variant: saveMa.containsMouse ? "focus" : root.saved ? "primary" : "pane"
            Text {
                anchors.centerIn: parent
                text: root.saved ? "\u2713 Saved!" : "Save & Apply"
                font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-1); font.weight: Font.Bold
                color: root.saved ? Colors.green : Styling.srItem("overprimary")
            }
            MouseArea {
                id: saveMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                onClicked: root.saveToSystem()
            }
        }
    }
}
