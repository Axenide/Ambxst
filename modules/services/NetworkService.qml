pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.globals

Singleton {
    id: root

    property bool wifi: true
    property bool ethernet: false

    property bool wifiEnabled: false
    property bool wifiScanning: false
    property var lastScanTime: 0
    property bool wifiConnecting: isUpdating && wifiStatus === "connecting"
    property bool isUpdating: false
    property bool wasEnabledBeforeSleep: false

    property var suspendConnections: Connections {
        target: SuspendManager
        function onPreparingForSleep() {
            root.wasEnabledBeforeSleep = root.wifiEnabled;
        }
        function onWakingUp() {
            if (root.wasEnabledBeforeSleep) {
                root.enableWifi(true);
            }
        }
    }

    property WifiAccessPoint wifiConnectTarget: null
    readonly property list<WifiAccessPoint> wifiNetworks: []
    property WifiAccessPoint active: null

    function updateActive() {
        for (let i = 0; i < wifiNetworks.length; i++) {
            if (wifiNetworks[i].active) {
                active = wifiNetworks[i];
                return;
            }
        }
        active = null;
    }

    property string wifiStatus: "disconnected"

    property string networkName: ""
    property int networkStrength: 0

    property list<var> friendlyWifiNetworks: []

    function updateFriendlyList() {
        friendlyWifiNetworks = [...wifiNetworks].sort((a, b) => {
            if (a.active && !b.active)
                return -1;
            if (!a.active && b.active)
                return 1;
            return b.strength - a.strength;
        });
        updateActive();
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

    function enableWifi(enabled = true): void {
        isUpdating = true;
        const cmd = enabled ? "on" : "off";
        runAsync(["nmcli", "radio", "wifi", cmd]).then(() => {
            update();
            isUpdating = false;
        }).catch(e => {
            isUpdating = false;
        });
    }

    function toggleWifi(): void {
        enableWifi(!wifiEnabled);
    }

    function rescanWifi(): void {
        const now = Date.now();
        if (now - lastScanTime < 10000) { // 10s throttle
            getNetworks.running = true;
            return;
        }
        
        lastScanTime = now;
        wifiScanning = true;
        runAsync(["nmcli", "dev", "wifi", "list", "--rescan", "yes"]).then(() => {
            update();
            getNetworks.running = true;
            wifiScanning = false;
        }).catch(e => {
            wifiScanning = false;
        });
    }

    function connectToWifiNetwork(accessPoint: WifiAccessPoint): void {
        accessPoint.askingPassword = false;
        root.wifiConnectTarget = accessPoint;
        isUpdating = true;
        runAsync(["nmcli", "dev", "wifi", "connect", accessPoint.ssid]).then(() => {
            getNetworks.running = true;
            root.wifiConnectTarget = null;
            isUpdating = false;
        }).catch(e => {
            if (e.includes("Secrets were required")) {
                accessPoint.askingPassword = true;
            }
            root.wifiConnectTarget = null;
            isUpdating = false;
        });
    }

    function disconnectWifiNetwork(): void {
        if (active) {
            isUpdating = true;
            runAsync(["nmcli", "connection", "down", active.ssid]).then(() => {
                getNetworks.running = true;
                isUpdating = false;
            }).catch(e => {
                isUpdating = false;
            });
        }
    }

    function changePassword(network: WifiAccessPoint, password: string): void {
        network.askingPassword = false;
        isUpdating = true;
        runAsync(["nmcli", "connection", "modify", network.ssid, "wifi-sec.psk", password]).then(() => {
            connectToWifiNetwork(network);
        }).then(() => {
            isUpdating = false;
        }).catch(e => {
            isUpdating = false;
        });
    }

    function openPublicWifiPortal() {
        Quickshell.execDetached(["xdg-open", "https://nmcheck.gnome.org/"]);
    }

    // WiFi icon by strength
    function wifiIconForStrength(strength: int): string {
        if (strength > 80) return Icons.wifiHigh;
        if (strength > 55) return Icons.wifiMedium;
        if (strength > 30) return Icons.wifiLow;
        if (strength > 0) return Icons.wifiNone;
        return Icons.wifiOff;
    }

    // Update status
    Timer {
        id: updateDebouncer
        interval: 200
        repeat: false
        onTriggered: root.performUpdate()
    }

    function update() {
        updateDebouncer.restart();
    }

    function performUpdate() {
        if (isUpdating) return;
        
        // Skip/delay updates if UI closed
        // nmcli monitor is event-based; safe to run.
        // Optimization: Only update signal strength when UI open
        const uiOpen = GlobalStates.dashboardOpen || GlobalStates.launcherOpen || GlobalStates.overviewOpen;
        
        isUpdating = true;
        startStatusUpdate(uiOpen);
    }

    // Combined status query. The old code spawned up to FOUR separate nmcli
    // processes per monitor event (nmcli is a Python CLI — each spawn is
    // ~30-100ms), with no in-flight guard so bursts of events overlapped
    // process runs. Everything now runs in a single shell invocation, with a
    // pending-flag so bursts coalesce instead of overlapping.
    property bool _statusUpdatePending: false

    function startStatusUpdate(includeStrength) {
        if (updateStatusProcess.running) {
            root._statusUpdatePending = true;
            return;
        }
        updateStatusProcess.buffer = "";
        const strengthQuery = (includeStrength === undefined ? (GlobalStates.dashboardOpen || GlobalStates.launcherOpen || GlobalStates.overviewOpen) : includeStrength)
            ? "; echo '==='; nmcli -f IN-USE,SIGNAL,SSID device wifi | awk '/^\\*/{if (NR!=1) {print $2}}'"
            : "";
        updateStatusProcess.command = [
            "sh", "-c",
            "nmcli -t -f TYPE,STATE d status; nmcli -t -f CONNECTIVITY g; echo '==='; nmcli radio wifi; echo '==='; nmcli -t -f NAME c show --active | head -1" + strengthQuery
        ];
        updateStatusProcess.running = true;
    }

    // Restart the event monitor if it exits (dbus drop, nmcli crash, missing
    // tool) so network/Wi-Fi state stays live instead of freezing at defaults.
    property Timer subscriberRestartTimer: Timer {
        interval: 2000
        repeat: false
        onTriggered: {
            if (!SuspendManager.isSuspending)
                subscriber.running = true;
        }
    }

    Process {
        id: subscriber
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: root.update()
        }
        onExited: (code) => {
            if (!SuspendManager.isSuspending)
                subscriberRestartTimer.restart();
        }
    }

    Process {
        id: updateStatusProcess
        property string buffer: ""
        running: false
        environment: ({
            LANG: "C.UTF-8",
            LC_ALL: "C.UTF-8"
        })
        stdout: SplitParser {
            onRead: data => {
                updateStatusProcess.buffer += data + "\n";
            }
        }
        onExited: (exitCode, exitStatus) => {
            root._parseStatus(updateStatusProcess.buffer);
            updateStatusProcess.buffer = "";
            root.isUpdating = false;
            // Converge on the latest state if events arrived while running.
            if (root._statusUpdatePending) {
                root._statusUpdatePending = false;
                root.startStatusUpdate();
            }
        }
    }

    function _parseStatus(buffer) {
        // Sections separated by '===':
        //   0: device status lines, last line = connectivity (full/limited/…)
        //   1: wifi radio state (enabled/disabled)
        //   2: active connection name (first line)
        //   3: signal strength (first line, only when the UI is open)
        const sections = buffer.trim().split("===");

        const statusLines = (sections[0] || "").trim().split("\n");
        const connectivity = statusLines.pop() || "";
        let hasEthernet = false;
        let hasWifi = false;
        let wifiStatus = "disconnected";
        statusLines.forEach(line => {
            if (line.includes("ethernet") && line.includes("connected"))
                hasEthernet = true;
            else if (line.includes("wifi:")) {
                if (line.includes("disconnected")) {
                    wifiStatus = "disconnected";
                } else if (line.includes("connected")) {
                    hasWifi = true;
                    wifiStatus = "connected";
                    if (connectivity === "limited") {
                        hasWifi = false;
                        wifiStatus = "limited";
                    }
                } else if (line.includes("connecting")) {
                    wifiStatus = "connecting";
                } else if (line.includes("unavailable")) {
                    wifiStatus = "disabled";
                }
            }
        });
        root.wifiStatus = wifiStatus;
        root.ethernet = hasEthernet;
        root.wifi = hasWifi;

        const radio = ((sections[1] || "").trim().split("\n")[0] || "").trim();
        root.wifiEnabled = radio === "enabled";

        // Unconditional so the name clears when the connection drops instead of
        // showing a stale network after disconnecting.
        root.networkName = ((sections[2] || "").trim().split("\n")[0] || "").trim();

        const strengthSection = (sections[3] || "").trim();
        if (strengthSection)
            root.networkStrength = parseInt(strengthSection.split("\n")[0]) || 0;
    }

    Process {
        id: getNetworks
        running: false
        command: ["nmcli", "-g", "ACTIVE,SIGNAL,FREQ,SSID,BSSID,SECURITY", "d", "w"]
        environment: ({
            LANG: "C.UTF-8",
            LC_ALL: "C.UTF-8"
        })
        property string buffer: ""
        stdout: SplitParser {
            onRead: data => {
                getNetworks.buffer += data + "\n";
            }
        }
        onExited: (exitCode, exitStatus) => {
            const text = getNetworks.buffer;
            getNetworks.buffer = "";
            
            Qt.callLater(() => {
                if (text.length === 0) {
                    root.updateFriendlyList();
                    return;
                }

                const PLACEHOLDER = "STRINGWHICHHOPEFULLYWONTBEUSED";
                const rep = /\\:/g;
                const rep2 = new RegExp(PLACEHOLDER, "g");

                const lines = text.trim().split("\n");
                const networkMap = new Map();

                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i].replace(rep, PLACEHOLDER);
                    const net = line.split(":");
                    if (net.length < 6) continue;

                    const ssid = net[3] || "";
                    if (!ssid) continue;

                    const network = {
                        active: net[0] === "yes",
                        strength: parseInt(net[1]) || 0,
                        frequency: parseInt(net[2]) || 0,
                        ssid: ssid,
                        bssid: (net[4] || "").replace(rep2, ":"),
                        security: net[5] || ""
                    };

                    const existing = networkMap.get(ssid);
                    if (!existing || (network.active && !existing.active) || (!network.active && !existing.active && network.strength > existing.strength)) {
                        networkMap.set(ssid, network);
                    }
                }

                const wifiNetworksData = Array.from(networkMap.values());
                const rNetworks = root.wifiNetworks;

                // Index existing networks once (O(n)) so both sync passes below
                // are O(1) lookups instead of O(n²) scans per rebuild.
                const existingMap = new Map();
                for (let i = 0; i < rNetworks.length; i++) {
                    const rn = rNetworks[i];
                    existingMap.set(rn.frequency + "|" + rn.ssid + "|" + rn.bssid, { index: i, network: rn });
                }

                // 1. Remove gone networks
                for (let i = rNetworks.length - 1; i >= 0; i--) {
                    const rn = rNetworks[i];
                    const key = rn.frequency + "|" + rn.ssid + "|" + rn.bssid;
                    const found = wifiNetworksData.some(n => n.frequency + "|" + n.ssid + "|" + n.bssid === key);
                    if (!found) {
                        rNetworks.splice(i, 1);
                        rn.destroy();
                    }
                }

                // 2. Add/update networks
                for (let i = 0; i < wifiNetworksData.length; i++) {
                    const data = wifiNetworksData[i];
                    const key = data.frequency + "|" + data.ssid + "|" + data.bssid;
                    const existing = existingMap.get(key);
                    if (existing) {
                        existing.network.lastIpcObject = data;
                    } else {
                        rNetworks.push(apComp.createObject(root, {
                            lastIpcObject: data
                        }));
                    }
                }

                root.updateFriendlyList();
            });
        }
    }

    Component {
        id: apComp
        WifiAccessPoint {}
    }

    Component.onCompleted: {
        update();
    }
}
