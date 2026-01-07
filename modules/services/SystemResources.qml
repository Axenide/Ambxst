pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
pragma ComponentBehavior: Bound

/**
 * System resource monitoring service
 * Tracks CPU, GPU, RAM and disk usage percentages
 */
Singleton {
    id: root

    // CPU metrics
    property real cpuUsage: 0.0
    property var cpuPrevTotal: 0
    property var cpuPrevIdle: 0
    property string cpuModel: ""
    property int cpuTemp: -1  // CPU temperature in Celsius, -1 if unavailable

    // RAM metrics
    property real ramUsage: 0.0
    property real ramTotal: 0
    property real ramUsed: 0
    property real ramAvailable: 0

    // GPU metrics - supports multiple GPUs
    property var gpuUsages: []          // Array of usage percentages
    property var gpuVendors: []         // Array of vendor strings
    property var gpuNames: []           // Array of GPU names
    property int gpuCount: 0
    property bool gpuDetected: false
    
    // GPU temperature metrics - supports multiple GPUs
    property var gpuTemps: []            // Array of temperatures in Celsius, -1 if unavailable
    
    // Legacy single GPU properties (for backward compatibility)
    property real gpuUsage: gpuUsages.length > 0 ? gpuUsages[0] : 0.0
    property string gpuVendor: gpuVendors.length > 0 ? gpuVendors[0] : "unknown"
    property int gpuTemp: gpuTemps.length > 0 ? gpuTemps[0] : -1

    // Disk metrics - map of mountpoint to usage percentage
    property var diskUsage: ({})

    // Disk types - map of mountpoint to type ("ssd", "hdd", or "unknown")
    property var diskTypes: ({})

    // Validated disk list
    property var validDisks: []

    // Update interval in milliseconds
    property int updateInterval: 2000

    // History data for charts (max 50 points)
    property var cpuHistory: []
    property var ramHistory: []
    property var gpuHistories: []       // Array of arrays - one history per GPU
    property var cpuTempHistory: []     // CPU temperature history
    property var gpuTempHistories: []   // Array of arrays - one temp history per GPU
    property int maxHistoryPoints: 50
    
    // Total data points collected (continues incrementing forever)
    property int totalDataPoints: 0

    // Unified System Monitor Process
    property Process monitorProcess: Process {
        id: monitorProcess
        running: false
        // Arguments will be updated when validDisks changes
        command: ["python3", Quickshell.shellDir + "/scripts/system_monitor.py"]
        
        stdout: SplitParser {
            onRead: data => {
                try {
                    const stats = JSON.parse(data);
                    
                    // Update CPU
                    root.cpuUsage = stats.cpu.usage;
                    root.cpuTemp = stats.cpu.temp;
                    
                    // Update RAM
                    root.ramUsage = stats.ram.usage;
                    root.ramTotal = stats.ram.total;
                    root.ramUsed = stats.ram.used;
                    root.ramAvailable = stats.ram.available;
                    
                    // Update Disk
                    root.diskUsage = stats.disk.usage;
                    
                    // Update GPU
                    root.gpuDetected = stats.gpu.detected;
                    if (stats.gpu.detected) {
                        // Ensure arrays are initialized if count changes (unlikely but safe)
                        if (root.gpuCount !== stats.gpu.count) {
                            root.gpuCount = stats.gpu.count;
                            root.gpuVendors = Array(stats.gpu.count).fill(stats.gpu.vendor);
                        }
                        root.gpuUsages = stats.gpu.usages;
                        root.gpuTemps = stats.gpu.temps;
                    }
                    
                    // Update History
                    root.updateHistory();
                    
                } catch (e) {
                    console.warn("SystemResources: Failed to parse monitor data: " + e);
                }
            }
        }
    }

    Component.onCompleted: {
        detectGPU();
        cpuModelReader.running = true;
        
        // Validate disks immediately - if Config is ready, this will populate validDisks
        // and trigger onValidDisksChanged which starts the monitor
        validateDisks();
    }

    // Watch for config changes and revalidate disks
    Connections {
        target: Config.system
        function onDisksChanged() {
            root.validateDisks();
        }
    }

    // Validate disks when Config is ready
    property bool configReady: Config.initialLoadComplete
    onConfigReadyChanged: {
        if (configReady) {
            validateDisks();
        }
    }

    // Restart monitor when disks change (Unified handler)
    onValidDisksChanged: {
        // Run static detection for types
        if (validDisks.length > 0) {
            diskTypeDetector.running = true;
        }

        // Restart monitor process with new args
        if (monitorProcess.running) {
            monitorProcess.running = false;
        }
        
        let cmd = ["python3", Quickshell.shellDir + "/scripts/system_monitor.py"];
        for (let i = 0; i < validDisks.length; i++) {
            cmd.push(validDisks[i]);
        }
        
        monitorProcess.command = cmd;
        monitorProcess.running = true;
    }

    // Detect GPU vendor and availability
    function detectGPU() {
        // Try NVIDIA first
        gpuDetector.running = true;
    }

    // Validate configured disks and fall back to "/" if invalid
    function validateDisks() {
        const configuredDisks = Config.system.disks || ["/"];
        let newValidDisks = [];

        for (let i = 0; i < configuredDisks.length; i++) {
            const disk = configuredDisks[i];
            if (disk && typeof disk === 'string' && disk.trim() !== '') {
                newValidDisks.push(disk.trim());
            }
        }

        // Ensure at least "/" is present
        if (newValidDisks.length === 0) {
            newValidDisks = ["/"];
        }
        
        // Assign the new array to trigger onValidDisksChanged
        validDisks = newValidDisks;
    }

    // Update history arrays with current values
    function updateHistory() {
        // Increment total data points counter
        totalDataPoints++;
        
        // Add CPU history
        let newCpuHistory = cpuHistory.slice();
        newCpuHistory.push(cpuUsage / 100);
        if (newCpuHistory.length > maxHistoryPoints) {
            newCpuHistory.shift();
        }
        cpuHistory = newCpuHistory;

        // Add CPU temperature history
        let newCpuTempHistory = cpuTempHistory.slice();
        newCpuTempHistory.push(cpuTemp);
        if (newCpuTempHistory.length > maxHistoryPoints) {
            newCpuTempHistory.shift();
        }
        cpuTempHistory = newCpuTempHistory;

        // Add RAM history
        let newRamHistory = ramHistory.slice();
        newRamHistory.push(ramUsage / 100);
        if (newRamHistory.length > maxHistoryPoints) {
            newRamHistory.shift();
        }
        ramHistory = newRamHistory;

        // Add GPU histories if detected
        if (gpuDetected && gpuCount > 0) {
            let newGpuHistories = gpuHistories.slice();
            let newGpuTempHistories = gpuTempHistories.slice();
            
            // Initialize histories array if needed
            while (newGpuHistories.length < gpuCount) {
                newGpuHistories.push([]);
            }
            while (newGpuTempHistories.length < gpuCount) {
                newGpuTempHistories.push([]);
            }
            
            // Update each GPU's history
            for (let i = 0; i < gpuCount; i++) {
                let gpuHist = newGpuHistories[i].slice();
                gpuHist.push((gpuUsages[i] || 0) / 100);
                if (gpuHist.length > maxHistoryPoints) {
                    gpuHist.shift();
                }
                newGpuHistories[i] = gpuHist;

                let gpuTempHist = newGpuTempHistories[i].slice();
                gpuTempHist.push(gpuTemps[i] !== undefined ? gpuTemps[i] : -1);
                if (gpuTempHist.length > maxHistoryPoints) {
                    gpuTempHist.shift();
                }
                newGpuTempHistories[i] = gpuTempHist;
            }
            
            gpuHistories = newGpuHistories;
            gpuTempHistories = newGpuTempHistories;
        }
    }

    // CPU model detection
    Process {
        id: cpuModelReader
        running: false
        command: ["sh", "-c", "grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^[ \\t]*//'"]
        
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                let model = text.trim();
                if (model) {
                    // Clean up CPU name following fastfetch logic
                    model = model.replace(/ CPU$/i, '');
                    model = model.replace(/ FPU$/i, '');
                    model = model.replace(/ APU$/i, '');
                    model = model.replace(/ Processor$/i, '');
                    
                    model = model.replace(/ Dual-Core$/i, '');
                    model = model.replace(/ Quad-Core$/i, '');
                    model = model.replace(/ Six-Core$/i, '');
                    model = model.replace(/ Eight-Core$/i, '');
                    model = model.replace(/ Ten-Core$/i, '');
                    
                    model = model.replace(/ 2-Core$/i, '');
                    model = model.replace(/ 4-Core$/i, '');
                    model = model.replace(/ 6-Core$/i, '');
                    model = model.replace(/ 8-Core$/i, '');
                    model = model.replace(/ 10-Core$/i, '');
                    model = model.replace(/ 12-Core$/i, '');
                    model = model.replace(/ 14-Core$/i, '');
                    model = model.replace(/ 16-Core$/i, '');
                    
                    const radeonIndex1 = model.indexOf(' w/ Radeon');
                    if (radeonIndex1 !== -1) model = model.substring(0, radeonIndex1);
                    const radeonIndex2 = model.indexOf(' with Radeon');
                    if (radeonIndex2 !== -1) model = model.substring(0, radeonIndex2);
                    
                    const atIndex = model.indexOf('@');
                    if (atIndex !== -1) model = model.substring(0, atIndex);
                    
                    model = model.trim().replace(/\s+/g, ' ');
                    
                    root.cpuModel = model;
                }
            }
        }
    }

    // Disk type detection (SSD vs HDD)
    Process {
        id: diskTypeDetector
        running: false
        command: ["sh", "-c", "df -P " + root.validDisks.join(" ") + " 2>/dev/null | tail -n +2 | while read line; do dev=$(echo \"$line\" | awk '{print $1}'); mount=$(echo \"$line\" | awk '{print $6}'); base=$(echo \"$dev\" | sed 's|/dev/||' | sed 's/p\\?[0-9]*$//'); if [ -b \"/dev/$base\" ]; then rota=$(lsblk -d -n -o ROTA \"/dev/$base\" 2>/dev/null); echo \"$mount:$rota\"; fi; done"]
        
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const raw = text.trim();
                if (!raw) {
                    const newDiskTypes = {};
                    for (const mountpoint of root.validDisks) {
                        newDiskTypes[mountpoint] = "unknown";
                    }
                    root.diskTypes = newDiskTypes;
                    return;
                }
                
                const newDiskTypes = {};
                const lines = raw.split('\n');
                
                for (const line of lines) {
                    const parts = line.split(':');
                    if (parts.length === 2) {
                        const mountpoint = parts[0].trim();
                        const rota = parts[1].trim();
                        
                        if (rota === "0") {
                            newDiskTypes[mountpoint] = "ssd";
                        } else if (rota === "1") {
                            newDiskTypes[mountpoint] = "hdd";
                        } else {
                            newDiskTypes[mountpoint] = "unknown";
                        }
                    }
                }
                
                for (const mountpoint of root.validDisks) {
                    if (!(mountpoint in newDiskTypes)) {
                        newDiskTypes[mountpoint] = "unknown";
                    }
                }
                
                root.diskTypes = newDiskTypes;
            }
        }
    }
    
    // GPU vendor detection
    Process {
        id: gpuDetector
        running: false
        command: ["sh", "-c", "command -v nvidia-smi >/dev/null 2>&1 && echo nvidia || (command -v rocm-smi >/dev/null 2>&1 && echo amd || (command -v intel_gpu_top >/dev/null 2>&1 && echo intel || echo none))"]
        
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const vendor = text.trim();
                if (vendor === "nvidia" || vendor === "amd" || vendor === "intel") {
                    root.gpuVendors = [vendor];
                    root.gpuDetected = true;
                    
                    if (vendor === "nvidia") {
                        gpuEnumeratorNvidia.running = true;
                    } else if (vendor === "amd") {
                        gpuEnumeratorAMD.running = true;
                    } else if (vendor === "intel") {
                        gpuEnumeratorIntel.running = true;
                    }
                } else {
                    root.gpuVendors = [];
                    root.gpuNames = [];
                    root.gpuUsages = [];
                    root.gpuTemps = [];
                    root.gpuCount = 0;
                    root.gpuDetected = false;
                }
            }
        }
    }
    
    // NVIDIA GPU enumeration
    Process {
        id: gpuEnumeratorNvidia
        running: false
        command: ["nvidia-smi", "--query-gpu=name", "--format=csv,noheader"]
        
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const raw = text.trim();
                if (!raw) return;
                
                const lines = raw.split('\n').filter(line => line.trim());
                const count = lines.length;
                
                root.gpuCount = count;
                root.gpuNames = lines.map(name => name.trim());
                root.gpuUsages = Array(count).fill(0);
                root.gpuTemps = Array(count).fill(-1);
                root.gpuVendors = Array(count).fill("nvidia");
            }
        }
    }
    
    // AMD GPU enumeration
    Process {
        id: gpuEnumeratorAMD
        running: false
        command: ["sh", "-c", "ls -1 /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | wc -l"]
        
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const raw = text.trim();
                const count = parseInt(raw) || 0;
                
                if (count > 0) {
                    root.gpuCount = count;
                    root.gpuNames = Array.from({length: count}, (_, i) => `AMD GPU ${i}`);
                    root.gpuUsages = Array(count).fill(0);
                    root.gpuTemps = Array(count).fill(-1);
                    root.gpuVendors = Array(count).fill("amd");
                }
            }
        }
    }
    
    // Intel GPU enumeration
    Process {
        id: gpuEnumeratorIntel
        running: false
        command: ["sh", "-c", "intel_gpu_top -J -s 100 2>/dev/null | grep -o '\"Render/3D/[0-9]*\"' | wc -l || echo 1"]
        
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const raw = text.trim();
                const count = Math.max(1, parseInt(raw) || 1);
                
                root.gpuCount = count;
                root.gpuNames = Array.from({length: count}, (_, i) => `Intel GPU ${i}`);
                root.gpuUsages = Array(count).fill(0);
                root.gpuTemps = Array(count).fill(-1);  // Intel GPU temp not supported
                root.gpuVendors = Array(count).fill("intel");
            }
        }
    }
}
