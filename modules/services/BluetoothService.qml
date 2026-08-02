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
        let count = 0;
        const devs = root.devices;
        for (let i = 0; i < devs.length; i++) {
            if (devs[i].connected) count++;
        }
        root.connectedDevices = count;
        root.connected = count > 0;
        friendlyDeviceList = [...devs].sort((a, b) => {
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

    function deviceByAddress(address: string) {
        const target = address.toUpperCase();
        const devs = root.devices;
        for (let i = 0; i < devs.length; i++) {
            if (devs[i].address.toUpperCase() === target) return devs[i];
        }
        return null;
    }

    function ensureDevice(address: string, name: string) {
        const existing = root.deviceByAddress(address);
        if (existing) {
            if (name && name !== "Unknown" && existing.name !== name) {
                existing.name = name;
            }
            return existing;
        }
        const newDevice = deviceComp.createObject(root, {
            address: address,
            name: name || "Unknown"
        });
        root.devices.push(newDevice);
        root.updateFriendlyList();
        root.queueInfoUpdate(newDevice);
        return newDevice;
    }

    function removeDeviceByAddress(address: string): void {
        const target = address.toUpperCase();
        for (let i = root.devices.length - 1; i >= 0; i--) {
            const d = root.devices[i];
            if (d.address.toUpperCase() === target) {
                root.devices.splice(i, 1);
                d.destroy();
            }
        }
        root.updateFriendlyList();
    }

    // Real-time event feed from `bluetoothctl --monitor` (bluetoothd D-Bus signals)
    function handleMonitorLine(line: string): void {
        // Strip ANSI colors/cursor codes, CRs and prompt artifacts from bluetoothctl's TTY-style output
        const clean = line.replace(/\x1b\[[0-9;]*[A-Za-z]|\r/g, "");
        const m = clean.match(/\[(NEW|CHG|DEL)\] (Device|Controller) ([0-9A-Fa-f:]{17})(?:\s+(.*))?/);
        if (!m) return;
        const event = m[1];
        const kind = m[2];
        const address = m[3].toUpperCase();
        // Trailing prompt fragments (e.g. "[WH-1000XM6]> ") get appended to event lines
        const rest = (m[4] || "").replace(/\[[^\]]*\]>\s*$/, "").trim();

        if (kind === "Controller") {
            if (event !== "CHG") return;
            if (rest.includes("Powered:")) {
                const powered = rest.includes("Powered: yes");
                root.enabled = powered;
                if (!powered) {
                    root.discovering = false;
                    for (let i = 0; i < root.devices.length; i++) {
                        root.devices[i].connected = false;
                        root.devices[i].connecting = false;
                    }
                    root.updateFriendlyList();
                }
            } else if (rest.includes("Discovering:")) {
                root.discovering = rest.includes("Discovering: yes");
            }
            return;
        }

        if (event === "DEL") {
            root.removeDeviceByAddress(address);
            return;
        }

        if (event === "NEW") {
            root.ensureDevice(address, rest || "Unknown");
            return;
        }

        // CHG for a device
        const dev = root.deviceByAddress(address);
        const pm = rest.match(/^(Name|Icon|Connected|Paired|Trusted)\s*:\s*(.+)$/);
        if (pm) {
            const prop = pm[1];
            const value = pm[2].trim();
            if (!dev) {
                root.ensureDevice(address, prop === "Name" ? value : "Unknown");
                return;
            }
            switch (prop) {
                case "Name":
                    if (value !== "Unknown") dev.name = value;
                    break;
                case "Icon":
                    dev.icon = value;
                    break;
                case "Connected":
                    dev.connected = value === "yes";
                    if (dev.connected) dev.connecting = false;
                    break;
                case "Paired":
                    dev.paired = value === "yes";
                    break;
                case "Trusted":
                    dev.trusted = value === "yes";
                    break;
            }
            root.updateFriendlyList();
            return;
        }

        const bm = rest.match(/^Battery Percentage\s*:\s*\((\d+)\)/);
        if (bm && dev) {
            dev.battery = parseInt(bm[1]) || -1;
        }
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
                // bluetoothctl writes errors to stdout, not stderr
                else reject(errorBuffer.trim() || buffer.trim() || `Process exited with code ${exitCode}`);
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

    // Control functions
    function notifyError(deviceName: string, message: string): void {
        Notifications.notifyInternal({
            "appName": "Bluetooth",
            "summary": (deviceName ? deviceName + " \u2014 " : "") + message,
            "replaceKey": "bluetooth-error",
            "expireTimeout": 6000,
            "historyPriority": 1
        });
    }

    function setEnabled(value: bool): void {
        if (SuspendManager.isSuspending) return;
        isUpdating = true;
        runAsync(["bluetoothctl", "power", value ? "on" : "off"]).then(() => {
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
            runAsync(["bluetoothctl", "scan", "on"]).then(() => {
                scanTimer.restart();
            }).catch(e => {
                discovering = false;
            });
        }
    }

    function stopDiscovery(): void {
        discovering = false;
        runAsync(["bluetoothctl", "scan", "off"]).then(() => {
            scanTimer.stop();
        }).catch(e => {});
    }

    function connectDevice(address: string) {
        isUpdating = true;
        const finish = () => {
            updateDevices();
            isUpdating = false;
        };
        return runAsync(["bluetoothctl", "connect", address]).then(
            () => finish(),
            e => {
                // bluetoothctl can exit non-zero while the device actually connects
                // (e.g. spurious br-connection-create-socket on reconnect). Verify
                // the real link state before surfacing a failure.
                return runAsync(["bluetoothctl", "info", address])
                    .then(info => {
                        const connected = info.split("\n")
                            .filter(l => /^Connected:/.test(l.trim()))
                            .some(l => l.trim() === "Connected: yes");
                        if (connected) return finish();
                        throw e;
                    })
                    .then(() => finish(), () => {
                        finish();
                        throw e;
                    });
            }
        );
    }

    function disconnectDevice(address: string) {
        isUpdating = true;
        return runAsync(["bluetoothctl", "disconnect", address]).then(() => {
            updateDevices();
            isUpdating = false;
        }).catch(e => {
            updateDevices();
            isUpdating = false;
            throw e;
        });
    }

    function pairDevice(address: string) {
        isUpdating = true;
        return runAsync(["bluetoothctl", "pair", address]).then(() => {
            updateDevices();
            isUpdating = false;
        }).catch(e => {
            updateDevices();
            isUpdating = false;
            throw e;
        });
    }

    function trustDevice(address: string) {
        return runAsync(["bluetoothctl", "trust", address]);
    }

    function removeDevice(address: string) {
        isUpdating = true;
        return runAsync(["bluetoothctl", "remove", address]).then(() => {
            updateDevices();
            isUpdating = false;
        }).catch(e => {
            updateDevices();
            isUpdating = false;
            throw e;
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
        interval: 30000
        // Fallback resync only when interface is visible — real-time events come from the monitor
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
        command: ["bash", "-c", "bluetoothctl show | grep 'Powered:' | awk '{print $2}'"]
        running: false
        stdout: SplitParser {
            onRead: (data) => {
                const output = data ? data.trim() : "";
                root.enabled = output === "yes";

                if (root.enabled) {
                    root.updateDevices();
                } else {
                    for (let i = 0; i < root.devices.length; i++) {
                        root.devices[i].connected = false;
                        root.devices[i].connecting = false;
                    }
                    root.updateFriendlyList();
                    root.discovering = false;
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.isUpdating = false;
        }
    }

    property bool devicesSyncPending: false

    function updateDevices() {
        if (getDevicesProcess.running) {
            devicesSyncPending = true;
            return;
        }
        getDevicesProcess.running = true;
    }

    Process {
        id: getDevicesProcess
        command: ["bash", "-c", "bluetoothctl devices"]
        running: false
        property string buffer: ""
        environment: ({
            LANG: "C.UTF-8",
            LC_ALL: "C.UTF-8"
        })
        stdout: SplitParser {
            onRead: data => {
                getDevicesProcess.buffer += data + "\n";
            }
        }
        onExited: (exitCode, exitStatus) => {
            const text = getDevicesProcess.buffer;
            getDevicesProcess.buffer = "";
            const wasPending = root.devicesSyncPending;
            root.devicesSyncPending = false;

            Qt.callLater(() => {
                const deviceLines = text.trim().split("\n").filter(l => l.startsWith("Device "));
                const addresses = [];
                for (let i = 0; i < deviceLines.length; i++) {
                    const parts = deviceLines[i].split(" ");
                    if (parts.length < 2) continue;
                    const address = parts[1];
                    addresses.push(address);
                    const name = parts.slice(2).join(" ") || "Unknown";
                    const existing = root.deviceByAddress(address);
                    if (existing) {
                        if (existing.name !== name) {
                            existing.name = name;
                        }
                        root.queueInfoUpdate(existing);
                    } else {
                        root.ensureDevice(address, name);
                    }
                }

                // Remove devices bluetoothd no longer knows about
                for (let i = root.devices.length - 1; i >= 0; i--) {
                    const d = root.devices[i];
                    if (!addresses.includes(d.address)) {
                        root.devices.splice(i, 1);
                        d.destroy();
                    }
                }

                root.updateFriendlyList();

                if (wasPending) {
                    root.updateDevices();
                }
            });
        }
    }

    // Long-lived `bluetoothctl --monitor` process — real-time device/state events.
    // Restart with bounded exponential backoff (1s doubling up to the cap) and a
    // stability reset, so a broken monitor (bluetoothd down, missing tool) can't
    // spawn a process every 2 seconds forever.
    property int _monitorRestartDelay: 1000
    readonly property int _maxMonitorRestartDelay: 30000

    Timer {
        id: monitorRestartTimer
        interval: root._monitorRestartDelay
        repeat: false
        onTriggered: {
            if (!monitorProcess.running) {
                monitorProcess.running = true;
            }
        }
    }

    // Resets the backoff after a stable run, so an occasional hiccup restarts
    // quickly instead of staying throttled at the max delay forever.
    Timer {
        id: monitorStabilityTimer
        interval: 60000
        repeat: false
        onTriggered: {
            root._monitorRestartDelay = 1000;
        }
    }

    Process {
        id: monitorProcess
        command: ["bluetoothctl", "--monitor"]
        running: false
        environment: ({
            LANG: "C.UTF-8",
            LC_ALL: "C.UTF-8"
        })
        // Without stdinEnabled the child's stdin is closed (EOF), so the
        // interactive monitor exits right after startup and only a device
        // snapshot is ever seen — which is what the old fixed 2s restart loop
        // was papering over. Keeping the pipe open makes bluetoothctl block on
        // stdin and stream events continuously.
        stdinEnabled: true
        stdout: SplitParser {
            onRead: data => {
                const line = data ? data.trim() : "";
                if (line) root.handleMonitorLine(line);
            }
        }
        onRunningChanged: {
            if (running) monitorStabilityTimer.restart();
        }
        onExited: (exitCode, exitStatus) => {
            root._monitorRestartDelay = Math.min(root._monitorRestartDelay * 2, root._maxMonitorRestartDelay);
            console.warn("BluetoothService: monitor exited with code", exitCode, "- restarting in", root._monitorRestartDelay, "ms");
            monitorRestartTimer.restart();
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
        if (!monitorProcess.running) {
            monitorProcess.running = true;
        }
    }

    Component.onCompleted: root.initialize()
}
