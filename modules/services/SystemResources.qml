pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.modules.globals
pragma ComponentBehavior: Bound

/**
 * System resource monitoring service
 * Optimised to be lightweight and avoid waking up dGPUs.
 */
Singleton {
    id: root

    // ── Toggles (set by MetricsConfigPanel) ──
    property bool cpuUsageEnabled: true
    property bool cpuTempEnabled: true
    property bool cpuPowerEnabled: false
    property bool ramEnabled: true
    property bool gpuUsageEnabled: true
    property bool gpuTempEnabled: true
    property bool gpuPowerEnabled: false
    property bool diskEnabled: true
    property bool fpsEnabled: true

    // ── Metric colours (set by MetricsConfigPanel) ──
    property color metricColorCpu: "#ffffff"
    property color metricColorGpu: "#ffffff"
    property color metricColorFps: "#ffffff"
    property color metricColorRam: "#ffffff"
    property color metricColorDisk: "#ffffff"

    // ── CPU metrics ──
    property real cpuUsage: 0.0
    property string cpuModel: ""
    property int cpuTemp: -1
    property real cpuPower: 0.0

    // ── RAM metrics ──
    property real ramUsage: 0.0
    property real ramTotal: 0
    property real ramUsed: 0
    property real ramAvailable: 0

    // ── GPU metrics ──
    property var gpuUsages: []
    property var gpuVendors: []
    property var gpuNames: []
    property int gpuCount: 0
    property bool gpuDetected: false
    property var gpuTemps: []
    property real gpuPower: 0.0

    // Legacy single‑GPU convenience
    property real gpuUsage: gpuUsages.length > 0 ? gpuUsages[0] : 0.0
    property string gpuVendor: gpuVendors.length > 0 ? gpuVendors[0] : "unknown"
    property int gpuTemp: gpuTemps.length > 0 ? gpuTemps[0] : -1

    // ── Disk ──
    property var diskUsage: ({})
    property var diskTypes: ({})
    property var validDisks: []

    // ── FPS ──
    property real fps: 0.0

    // ── Version bump (triggers rebuildNotchMetrics) ──
    property int notchVersion: 0

    // ── Convenience ──
    property bool metricsAvailable: true

    // ── Config persistence ──
    property string metricsConfigPath: Quickshell.env("HOME") + "/.config/nothingless/config/metrics.json"

    function saveMetricsConfig() {
        var config = JSON.stringify({
            cpuUsageEnabled: cpuUsageEnabled,
            cpuTempEnabled: cpuTempEnabled,
            cpuPowerEnabled: cpuPowerEnabled,
            ramEnabled: ramEnabled,
            gpuUsageEnabled: gpuUsageEnabled,
            gpuTempEnabled: gpuTempEnabled,
            gpuPowerEnabled: gpuPowerEnabled,
            fpsEnabled: fpsEnabled,
            diskEnabled: diskEnabled,
            metricColorCpu: metricColorCpu,
            metricColorGpu: metricColorGpu,
            metricColorFps: metricColorFps,
            metricColorRam: metricColorRam,
            metricColorDisk: metricColorDisk
        });
        var cmd = "mkdir -p $(dirname " + metricsConfigPath + ") && echo '" + config + "' > " + metricsConfigPath;
        saveProcess.command = ["sh", "-c", cmd];
        saveProcess.running = true;
    }

    function loadMetricsConfig() {
        loadProcess.command = ["cat", metricsConfigPath];
        loadProcess.running = true;
    }

    // ── Fast FPS watcher (tail -f /dev/shm/nothingless_fps) ──
    property Process fpsWatcher: Process {
        id: fpsWatcher
        running: root.notchMetricsActive || (GlobalStates.dashboardOpen && GlobalStates.dashboardCurrentTab === 2)
        command: ["bash", "-c", "tail -n0 -F /dev/shm/nothingless_fps 2>/dev/null || sleep 10"]
        stdout: SplitParser {
            onRead: data => {
                var trimmed = data.trim();
                if (trimmed.startsWith("fps=")) {
                    var val = parseFloat(trimmed.split("=", 2)[1]);
                    if (!isNaN(val) && val > 0) root.fps = val;
                }
            }
        }
    }

    property Process saveProcess: Process {
        running: false
    }

    property Process loadProcess: Process {
        running: false
        stdout: SplitParser {
            onRead: data => {
                try {
                    var cfg = JSON.parse(data);
                    if (cfg.cpuUsageEnabled !== undefined) root.cpuUsageEnabled = cfg.cpuUsageEnabled;
                    if (cfg.cpuTempEnabled !== undefined) root.cpuTempEnabled = cfg.cpuTempEnabled;
                    if (cfg.cpuPowerEnabled !== undefined) root.cpuPowerEnabled = cfg.cpuPowerEnabled;
                    if (cfg.ramEnabled !== undefined) root.ramEnabled = cfg.ramEnabled;
                    if (cfg.gpuUsageEnabled !== undefined) root.gpuUsageEnabled = cfg.gpuUsageEnabled;
                    if (cfg.gpuTempEnabled !== undefined) root.gpuTempEnabled = cfg.gpuTempEnabled;
                    if (cfg.gpuPowerEnabled !== undefined) root.gpuPowerEnabled = cfg.gpuPowerEnabled;
                    if (cfg.fpsEnabled !== undefined) root.fpsEnabled = cfg.fpsEnabled;
                    if (cfg.diskEnabled !== undefined) root.diskEnabled = cfg.diskEnabled;
                    if (cfg.metricColorCpu) root.metricColorCpu = cfg.metricColorCpu;
                    if (cfg.metricColorGpu) root.metricColorGpu = cfg.metricColorGpu;
                    if (cfg.metricColorFps) root.metricColorFps = cfg.metricColorFps;
                    if (cfg.metricColorRam) root.metricColorRam = cfg.metricColorRam;
                    if (cfg.metricColorDisk) root.metricColorDisk = cfg.metricColorDisk;
                } catch (e) {
                    console.warn("Failed to load metrics config:", e);
                }
            }
        }
    }

    // ── History ──
    property var cpuHistory: []
    property var ramHistory: []
    property var gpuHistories: []
    property var cpuTempHistory: []
    property var gpuTempHistories: []
    property var fpsHistory: []
    property int maxHistoryPoints: 50
    property int totalDataPoints: 0

    // ── Update interval ──
    property int updateInterval: 2000

    // ════════════════════════════════════════════════════════════════
    // Monitor process — runs when the dashboard metrics tab is open
    // OR when the notch metrics overlay is active.
    // ════════════════════════════════════════════════════════════════
    property bool notchMetricsActive: Config.notch && Config.notch.showMetrics === true

    property Process monitorProcess: Process {
        id: monitorProcess

        // Run when either dashboard metrics tab OR notch metrics mode is active
        running: (GlobalStates.dashboardOpen && GlobalStates.dashboardCurrentTab === 2) || root.notchMetricsActive

        command: {
            let cmd = ["python3", Quickshell.shellDir + "/scripts/system_monitor.py", root.updateInterval.toString()];
            return cmd.concat(root.validDisks);
        }

        stdout: SplitParser {
            onRead: data => {
                try {
                    const stats = JSON.parse(data);

                    // ── Static info (received once) ──
                    if (stats.static) {
                        root.cpuModel = stats.static.cpu_model || root.cpuModel;
                        root.gpuNames = stats.static.gpu_names || [];
                        root.gpuVendors = stats.static.gpu_vendors || [];
                        root.gpuCount = stats.static.gpu_count || 0;
                        root.gpuDetected = root.gpuCount > 0;
                        root.diskTypes = stats.static.disk_types || {};
                        return;
                    }

                    // ── CPU ──
                    if (stats.cpu) {
                        root.cpuUsage = stats.cpu.usage;
                        root.cpuTemp = stats.cpu.temp;
                        // power is sent by the script when available
                        if (stats.cpu.power !== undefined) root.cpuPower = stats.cpu.power;
                    }

                    // ── RAM ──
                    if (stats.ram) {
                        root.ramUsage = stats.ram.usage;
                        root.ramTotal = stats.ram.total;
                        root.ramUsed = stats.ram.used;
                        root.ramAvailable = stats.ram.available;
                    }

                    // ── Disk ──
                    if (stats.disk) root.diskUsage = stats.disk.usage;

                    // ── GPU ──
                    if (stats.gpu) {
                        root.gpuUsages = stats.gpu.usages;
                        root.gpuTemps = stats.gpu.temps;
                        if (stats.gpu.power !== undefined) root.gpuPower = stats.gpu.power;
                    }

                    // ── FPS (via MangoHud or generic) ──
                    if (stats.fps !== undefined) root.fps = stats.fps;

                    root.updateHistory();
                } catch (e) {
                    console.warn("SystemResources: parse error: " + e);
                }
            }
        }
    }

    // ── Lifecycle ──
    Component.onCompleted: {
        validateDisks();
        loadMetricsConfig();
    }

    Connections {
        target: Config.system
        function onDisksChanged() { root.validateDisks(); }
    }

    property bool configReady: Config.initialLoadComplete
    onConfigReadyChanged: if (configReady) validateDisks()

    onValidDisksChanged: if (monitorProcess.running) restartMonitor()
    onUpdateIntervalChanged: if (monitorProcess.running) restartMonitor()
    onNotchMetricsActiveChanged: if (!monitorProcess.running && notchMetricsActive) restartMonitor()

    function restartMonitor() {
        monitorProcess.running = false;
        Qt.callLater(() => { monitorProcess.running = true; });
    }

    function validateDisks() {
        const configuredDisks = Config.system.disks || ["/"];
        let newValidDisks = [];
        for (let i = 0; i < configuredDisks.length; i++) {
            const disk = configuredDisks[i];
            if (disk && typeof disk === 'string' && disk.trim() !== '') {
                newValidDisks.push(disk.trim());
            }
        }
        if (newValidDisks.length === 0) newValidDisks = ["/"];
        validDisks = newValidDisks;
    }

    function updateHistory() {
        totalDataPoints++;

        const pushHistory = (arr, val) => {
            let next = arr.slice();
            next.push(val);
            if (next.length > maxHistoryPoints) next.shift();
            return next;
        };

        cpuHistory = pushHistory(cpuHistory, cpuUsage / 100);
        cpuTempHistory = pushHistory(cpuTempHistory, cpuTemp);
        ramHistory = pushHistory(ramHistory, ramUsage / 100);

        if (gpuDetected && gpuCount > 0) {
            let newGpuHistories = gpuHistories.slice();
            let newGpuTempHistories = gpuTempHistories.slice();

            while (newGpuHistories.length < gpuCount) newGpuHistories.push([]);
            while (newGpuTempHistories.length < gpuCount) newGpuTempHistories.push([]);

            for (let i = 0; i < gpuCount; i++) {
                newGpuHistories[i] = pushHistory(newGpuHistories[i], (gpuUsages[i] || 0) / 100);
                newGpuTempHistories[i] = pushHistory(newGpuTempHistories[i], (gpuTemps[i] ?? -1));
            }

            gpuHistories = newGpuHistories;
            gpuTempHistories = newGpuTempHistories;
        }

        // FPS history
        fpsHistory = pushHistory(fpsHistory, fps);
    }
}
