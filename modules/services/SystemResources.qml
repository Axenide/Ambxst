pragma Singleton
import QtQuick
import Quickshell
import qs.config
import qs.modules.globals
pragma ComponentBehavior: Bound

/**
 * System resource monitoring service
 * Optimized to be lightweight and avoid waking up dGPUs.
 * Backed by the Go daemon `systemmonitor` subscription.
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

    // Update interval
    property int updateInterval: 2000

    property int subscriptionHandle: -1

    // Subscription only lives while the dashboard Metrics tab is open,
    // preserving the original resource-saving behaviour (no dGPU polling).
    readonly property bool monitoringActive: GlobalStates.dashboardOpen && GlobalStates.dashboardCurrentTab === 2 && root.validDisks.length > 0

    onMonitoringActiveChanged: {
        if (monitoringActive) activateMonitor();
        else deactivateMonitor();
    }

    onValidDisksChanged: {
        if (monitoringActive) {
            deactivateMonitor();
            Qt.callLater(() => activateMonitor());
        }
    }

    onUpdateIntervalChanged: if (monitoringActive) updateConfigure()

    Component.onCompleted: {
        validateDisks();
        root.subscriptionHandle = BackendService.addSubscription(["systemmonitor"], (service, data) => root.handleEvent(service, data));
        if (monitoringActive) activateMonitor();
    }

    function activateMonitor() {
        if (root.subscriptionHandle < 0) return;
        root.updateConfigure();
        BackendService.setSubscriptionActive(root.subscriptionHandle, true);
    }

    function deactivateMonitor() {
        if (root.subscriptionHandle < 0) return;
        BackendService.setSubscriptionActive(root.subscriptionHandle, false);
    }

    function updateConfigure() {
        BackendService.call("systemmonitor.configure", {
            interval_ms: Math.max(100, root.updateInterval),
            disks: root.validDisks.length > 0 ? root.validDisks : ["/"]
        });
    }

    function handleEvent(service, data) {
        if (service !== "systemmonitor" && service !== "systemmonitor.static") return;
        try {
            if (service === "systemmonitor.static") {
                root.cpuModel = data.cpu_model || root.cpuModel;
                root.gpuNames = data.gpu_names || [];
                root.gpuVendors = data.gpu_vendors || [];
                root.gpuCount = data.gpu_count || 0;
                root.gpuDetected = root.gpuCount > 0;
                root.diskTypes = data.disk_types || {};
                return;
            }

            if (data.cpu) {
                root.cpuUsage = data.cpu.usage;
                root.cpuTemp = data.cpu.temp;
            }

            if (data.ram) {
                root.ramUsage = data.ram.usage;
                root.ramTotal = data.ram.total;
                root.ramUsed = data.ram.used;
                root.ramAvailable = data.ram.available;
            }

            if (data.disk) root.diskUsage = data.disk.usage;

            if (data.gpu) {
                root.gpuUsages = data.gpu.usages;
                root.gpuTemps = data.gpu.temps;
            }

            root.updateHistory();
        } catch (e) {
            console.warn("SystemResources: Failed to parse monitor data: " + e);
        }
    }

    Connections {
        target: Config.system
        function onDisksChanged() { root.validateDisks(); }
    }

    property bool configReady: Config.initialLoadComplete
    onConfigReadyChanged: if (configReady) validateDisks()

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
