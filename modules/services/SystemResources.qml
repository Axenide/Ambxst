pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.modules.globals
pragma ComponentBehavior: Bound

/**
 * System resource monitoring service
 * Optimized to be lightweight and avoid waking up dGPUs.
 */
Singleton {
    id: root

    // CPU metrics
    property real cpuUsage: 0.0
    property string cpuModel: ""
    property int cpuTemp: -1

    // RAM metrics
    property real ramUsage: 0.0
    property real ramTotal: 0
    property real ramUsed: 0
    property real ramAvailable: 0

    // GPU metrics
    property var gpuUsages: []
    property var gpuVendors: []
    property var gpuNames: []
    property int gpuCount: 0
    property bool gpuDetected: false
    property var gpuTemps: []
    
    // Legacy single GPU properties
    property real gpuUsage: gpuUsages.length > 0 ? gpuUsages[0] : 0.0
    property string gpuVendor: gpuVendors.length > 0 ? gpuVendors[0] : "unknown"
    property int gpuTemp: gpuTemps.length > 0 ? gpuTemps[0] : -1

    // Disk metrics
    property var diskUsage: ({})
    property var diskTypes: ({})
    property var validDisks: []

    // History data
    property var cpuHistory: []
    property var ramHistory: []
    property var gpuHistories: []
    property var cpuTempHistory: []
    property var gpuTempHistories: []
    property int maxHistoryPoints: 50
    property int totalDataPoints: 0

    // Update interval (passed to python or managed by restart if needed)
    property int updateInterval: 2000

    // The unified monitor process
    // Only runs when the dashboard is open to save resources.
    // GPU polling is internally optimized in the script to avoid waking up dGPUs.
    property Process monitorProcess: Process {
        id: monitorProcess
        running: GlobalStates.dashboardOpen && GlobalStates.dashboardCurrentTab === 2 && root.validDisks.length > 0
        
        command: {
            let cmd = ["python3", Quickshell.shellDir + "/scripts/system_monitor.py", root.updateInterval.toString()];
            return cmd.concat(root.validDisks);
        }
        
        stdout: SplitParser {
            onRead: data => {
                try {
                    const stats = JSON.parse(data);
                    
                    // Handle static info (received once at start)
                    if (stats.static) {
                        root.cpuModel = stats.static.cpu_model || root.cpuModel;
                        root.gpuNames = stats.static.gpu_names || [];
                        root.gpuVendors = stats.static.gpu_vendors || [];
                        root.gpuCount = stats.static.gpu_count || 0;
                        root.gpuDetected = root.gpuCount > 0;
                        root.diskTypes = stats.static.disk_types || {};
                        return;
                    }

                    // Update metrics
                    if (stats.cpu) {
                        root.cpuUsage = stats.cpu.usage;
                        root.cpuTemp = stats.cpu.temp;
                    }
                    
                    if (stats.ram) {
                        root.ramUsage = stats.ram.usage;
                        root.ramTotal = stats.ram.total;
                        root.ramUsed = stats.ram.used;
                        root.ramAvailable = stats.ram.available;
                    }
                    
                    if (stats.disk) root.diskUsage = stats.disk.usage;
                    
                    if (stats.gpu) {
                        root.gpuUsages = stats.gpu.usages;
                        root.gpuTemps = stats.gpu.temps;
                    }
                    
                    root.updateHistory();
                } catch (e) {
                    console.warn("SystemResources: Failed to parse monitor data: " + e);
                }
            }
        }
    }

    Component.onCompleted: validateDisks()

    Connections {
        target: Config.system
        function onDisksChanged() { root.validateDisks(); }
    }

    property bool configReady: Config.initialLoadComplete
    onConfigReadyChanged: if (configReady) validateDisks()

    onValidDisksChanged: if (monitorProcess.running) restartMonitor()
    onUpdateIntervalChanged: if (monitorProcess.running) restartMonitor()

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
        
        // Helper to update history arrays
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
    }
}
