pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.globals

Singleton {
    id: root

    property bool enabled: false
    property bool discovering: false
    property bool connected: false
    property int connectedDevices: 0
    
    readonly property list<BluetoothDevice> devices: []
    
    // Cached sorted device list - only updates when devices change
    property list<var> friendlyDeviceList: []
    
    // Queue for batching updateInfo calls
    property var pendingInfoUpdates: []
    property bool isProcessingInfoQueue: false
    property bool isUpdating: false
    property bool wasEnabledBeforeSleep: false

    property var suspendConnections: Connections {
        target: SuspendManager
        function onPreparingForSleep() {
            root.wasEnabledBeforeSleep = root.enabled;
            if (discovering) {
                root.stopDiscovery();
            }
            scanTimer.stop();
            infoQueueTimer.stop();
        }
        function onWakingUp() {
            // Re-sync status after wake
            wakeSyncTimer.restart();

            // Restore state if it was enabled
            if (root.wasEnabledBeforeSleep) {
                root.setEnabled(true);
            }
        }
    }

    property var wakeSyncTimer: Timer {
        id: wakeSyncTimer
        interval: 3000
        repeat: false
        onTriggered: {
            root.updateStatus();
            if (root.enabled) {
                root.updateDevices();
            }
        }
    }

    function updateFriendlyList() {
        friendlyDeviceList = [...devices].sort((a, b) => {
            // Connected devices first
            if (a.connected && !b.connected) return -1;
            if (!a.connected && b.connected) return 1;
            // Then paired devices
            if (a.paired && !b.paired) return -1;
            if (!a.paired && b.paired) return 1;
            // Then by name
            return (a.name || "").localeCompare(b.name || "");
        });
    }

    // Batch process info updates with delay between each
    function queueInfoUpdate(device: BluetoothDevice) {
        if (pendingInfoUpdates.indexOf(device) === -1) {
            pendingInfoUpdates.push(device);
        }
        if (!isProcessingInfoQueue) {
            processNextInfoUpdate();
        }
    }

    function processNextInfoUpdate() {
        if (pendingInfoUpdates.length === 0) {
            isProcessingInfoQueue = false;
            updateFriendlyList();
            return;
        }
        
        isProcessingInfoQueue = true;
        const device = pendingInfoUpdates.shift();
        if (device) {
            device.updateInfo();
        }
        // Process next after a small delay
        infoQueueTimer.restart();
    }

    Timer {
        id: infoQueueTimer
        interval: 50  // 50ms between each info request
        running: false
        repeat: false
        onTriggered: {
            if (!SuspendManager.isSuspending) {
                root.processNextInfoUpdate();
            }
        }
    }

    Component {
        id: asyncProcessComp
        Process {
            id: internalProc
            property var resolve
            property var reject
            property string buffer: ""
            property string errorBuffer: ""
            
            stdout: SplitParser {
                onRead: data => internalProc.buffer += data + "\n"
            }
            
            stderr: SplitParser {
                onRead: data => internalProc.errorBuffer += data + "\n"
            }
            
            onExited: (exitCode, exitStatus) => {
                if (exitCode === 0) resolve(buffer.trim());
                else reject(errorBuffer.trim() || `Process exited with code ${exitCode}`);
                destroy();
            }
        }
    }

    function runAsync(command, environment = {}) {
        return new Promise((resolve, reject) => {
            const proc = asyncProcessComp.createObject(root, {
                command: command,
                environment: environment,
                resolve: resolve,
                reject: reject
            });
            proc.running = true;
        });
    }

    // Helper script path — uses project's scripts directory
    readonly property string helperPath: Quickshell.shellDir + "/scripts/bluetooth_helper.py"

    // Control functions
    function setEnabled(value: bool): void {
        if (SuspendManager.isSuspending) return;
        isUpdating = true;
        runAsync(["python3", root.helperPath, "power", value ? "on" : "off"]).then(() => {
            updateStatus();
            if (value) updateDevices();
            isUpdating = false;
        }).catch(e => {
            isUpdating = false;
        });
    }

    function toggle(): void {
        setEnabled(!enabled);
    }

    function startDiscovery(): void {
        if (enabled && !SuspendManager.isSuspending) {
            discovering = true;
            // Use interactive scan that captures [NEW] Device events
            scanProcess.running = true;
            scanTimer.restart();
        }
    }

    function stopDiscovery(): void {
        discovering = false;
        if (scanProcess.running) {
            scanProcess.running = false;
        }
        scanTimer.stop();
        runAsync(["python3", root.helperPath, "scan", "off"]).then(() => {
            Qt.callLater(() => root.updateDevices());
        }).catch(e => {});
    }

    // Dedicated scan process with interactive bluetoothctl
    property Process scanProcess: Process {
        command: ["python3", root.helperPath, "scan", "find", "12"]
        running: false
        property string buffer: ""
        stdout: SplitParser {
            onRead: data => { scanProcess.buffer += data; }
        }
        onExited: exitCode => {
            root.discovering = false;
            var text = scanProcess.buffer.trim();
            scanProcess.buffer = "";
            if (exitCode === 0 && text) {
                // Parse discovered devices from scan
                try {
                    var devices = JSON.parse(text);
                    if (Array.isArray(devices) && devices.length > 0) {
                        // Merge into existing device list
                        const rDevices = root.devices;
                        for (var i = 0; i < devices.length; i++) {
                            var d = devices[i];
                            var existingArr = Array.from(rDevices);
                            var existing = existingArr.find(function(ex) { return ex.address === d.address; });
                            if (existing) {
                                existing.name = d.name || existing.name;
                                existing.connected = d.connected || false;
                            } else {
                                var newDev = deviceComp.createObject(root, {
                                    address: d.address,
                                    name: d.name || d.alias || "Unknown",
                                    paired: d.paired || false,
                                    connected: d.connected || false,
                                    trusted: d.trusted || false,
                                    icon: d.icon || "bluetooth"
                                });
                                rDevices.push(newDev);
                            }
                        }
                        root.updateFriendlyList();
                    }
                } catch (e) {
                    console.warn("BluetoothService: scan parse failed:", e);
                }
            }
        }
    }

    function connectDevice(address: string): void {
        isUpdating = true;
        runAsync(["python3", root.helperPath, "connect", address]).then(() => {
            updateDevices();
            isUpdating = false;
        }).catch(e => {
            isUpdating = false;
        });
    }

    function disconnectDevice(address: string): void {
        isUpdating = true;
        runAsync(["python3", root.helperPath, "disconnect", address]).then(() => {
            updateDevices();
            isUpdating = false;
        }).catch(e => {
            isUpdating = false;
        });
    }

    function pairDevice(address: string): void {
        isUpdating = true;
        runAsync(["python3", root.helperPath, "pair", address]).then(() => {
            updateDevices();
            isUpdating = false;
        }).catch(e => {
            isUpdating = false;
        });
    }

    function trustDevice(address: string): void {
        runAsync(["python3", root.helperPath, "trust", address]).catch(e => {});
    }

    function removeDevice(address: string): void {
        isUpdating = true;
        runAsync(["python3", root.helperPath, "remove", address]).then(() => {
            updateDevices();
            isUpdating = false;
        }).catch(e => {
            isUpdating = false;
        });
    }

    Timer {
        id: updateDebouncer
        interval: 200
        repeat: false
        onTriggered: root.performUpdate()
    }

    function updateStatus() {
        updateDebouncer.restart();
    }

    function performUpdate() {
        if (isUpdating) return;
        isUpdating = true;
        checkPowerProcess.running = true;
    }

    // Timers
    Timer {
        id: updateTimer
        interval: 5000
        // Only poll when interface is visible
        running: root.enabled && !SuspendManager.isSuspending && (GlobalStates.dashboardOpen || GlobalStates.launcherOpen || GlobalStates.overviewOpen)
        repeat: true
        onTriggered: root.updateDevices()
    }

    Timer {
        id: scanTimer
        interval: 15000
        running: false
        repeat: false
        onTriggered: root.stopDiscovery()
    }

    // Processes
    Process {
        id: checkPowerProcess
        command: ["python3", root.helperPath, "power", "status"]
        running: false
        property string buffer: ""
        stdout: SplitParser {
            onRead: data => { checkPowerProcess.buffer += data; }
        }
        onExited: exitCode => {
            var text = checkPowerProcess.buffer.trim();
            checkPowerProcess.buffer = "";
            if (exitCode === 0 && text) {
                try {
                    var result = JSON.parse(text);
                    root.enabled = result.powered === true;
                } catch (e) {
                    console.warn("BluetoothService: power parse failed:", e);
                    root.enabled = false;
                }
            } else {
                root.enabled = false;
            }
            if (root.enabled) {
                checkConnectedProcess.running = true;
            } else {
                root.connected = false;
                root.connectedDevices = 0;
                root.discovering = false;
                root.isUpdating = false;
            }
        }
    }

    Process {
        id: checkConnectedProcess
        command: ["python3", root.helperPath, "devices"]
        running: false
        property string buffer: ""
        stdout: SplitParser {
            onRead: data => { checkConnectedProcess.buffer += data; }
        }
        onExited: exitCode => {
            root.isUpdating = false;
            var text = checkConnectedProcess.buffer.trim();
            checkConnectedProcess.buffer = "";
            if (exitCode !== 0 || !text) return;
            try {
                var devices = JSON.parse(text);
                var connected = 0;
                for (var i = 0; i < devices.length; i++) {
                    if (devices[i].connected) connected++;
                }
                root.connectedDevices = connected;
                root.connected = connected > 0;
            } catch (e) {
                console.warn("BluetoothService: connected parse failed:", e);
            }
        }
    }

    function updateDevices() {
        getDevicesProcess.running = true;
    }

    Process {
        id: getDevicesProcess
        command: ["python3", root.helperPath, "devices"]
        running: false
        property string buffer: ""
        stdout: SplitParser {
            onRead: data => { getDevicesProcess.buffer += data; }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.updateFriendlyList();
                return;
            }
            Qt.callLater(() => {
                var deviceDataList = [];
                try {
                    var jsonText = getDevicesProcess.buffer.trim();
                    getDevicesProcess.buffer = "";
                    if (jsonText) {
                        deviceDataList = JSON.parse(jsonText);
                        if (!Array.isArray(deviceDataList)) deviceDataList = [];
                    }
                } catch (e) {
                    console.warn("BluetoothService: devices parse failed:", e);
                    getDevicesProcess.buffer = "";
                }

                const rDevices = root.devices;
                
                // Remove gone devices
                for (let i = rDevices.length - 1; i >= 0; i--) {
                    const rd = rDevices[i];
                    if (!deviceDataList.some(function(d) { return d.address === rd.address; })) {
                        rDevices.splice(i, 1);
                        rd.destroy();
                    }
                }
                
                // Add or update devices (with full info from JSON)
                for (let i = 0; i < deviceDataList.length; i++) {
                    const data = deviceDataList[i];
                    const existingArr = Array.from(rDevices);
                    const existing = existingArr.find(function(d) { return d.address === data.address; });
                    if (existing) {
                        existing.name = data.name || data.alias || existing.name;
                        existing.paired = data.paired || false;
                        existing.connected = data.connected || false;
                        existing.trusted = data.trusted || false;
                        existing.battery = data.battery || -1;
                    } else {
                        const newDevice = deviceComp.createObject(root, {
                            address: data.address,
                            name: data.name || data.alias || "Unknown",
                            paired: data.paired || false,
                            connected: data.connected || false,
                            trusted: data.trusted || false,
                            icon: data.icon || "bluetooth",
                            battery: data.battery || -1
                        });
                        rDevices.push(newDevice);
                    }
                }
                
                root.updateFriendlyList();
            });
        }
    }

    Component {
        id: deviceComp
        BluetoothDevice {}
    }

    property bool _initialized: false

    function initialize() {
        if (_initialized) return;
        _initialized = true;
        updateStatus();
    }
}
