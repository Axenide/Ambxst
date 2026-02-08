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
        if (now - lastScanTime < 10000) { // 10 seconds throttle
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
        runAsync(["bash", "-c", `nmcli connection modify "${network.ssid}" wifi-sec.psk "$PASSWORD"`], { "PASSWORD": password }).then(() => {
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

    // Helper function for wifi icon based on strength
    function wifiIconForStrength(strength: int): string {
        if (strength > 80) return Icons.wifiHigh;
        if (strength > 55) return Icons.wifiMedium;
        if (strength > 30) return Icons.wifiLow;
        if (strength > 0) return Icons.wifiNone;
        return Icons.wifiOff;
    }

    // Status update
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
        
        // If UI is closed, we can skip heavy updates or delay them
        // But for now, let's just run them. The nmcli monitor is event based so it shouldn't spam too much.
        // Optimization: Only update signal strength if UI is open
        const uiOpen = GlobalStates.dashboardOpen || GlobalStates.launcherOpen || GlobalStates.overviewOpen;
        
        isUpdating = true;
        updateConnectionType.startCheck();
        wifiStatusProcess.running = true;
        updateNetworkName.running = true;
        
        if (uiOpen) {
            updateNetworkStrength.running = true;
        }
    }

    Process {
        id: subscriber
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: root.update()
        }
    }

    Process {
        id: updateConnectionType
        property string buffer: ""
        command: ["sh", "-c", "nmcli -t -f TYPE,STATE d status && nmcli -t -f CONNECTIVITY g"]
        running: true
        function startCheck() {
            buffer = "";
            updateConnectionType.running = true;
        }
        stdout: SplitParser {
            onRead: data => {
                updateConnectionType.buffer += data + "\n";
            }
        }
        onExited: (exitCode, exitStatus) => {
            const lines = updateConnectionType.buffer.trim().split('\n');
            const connectivity = lines.pop();
            let hasEthernet = false;
            let hasWifi = false;
            let wifiStatus = "disconnected";
            lines.forEach(line => {
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
            root.isUpdating = false;
        }
    }

    Process {
        id: updateNetworkName
        command: ["sh", "-c", "nmcli -t -f NAME c show --active | head -1"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                root.networkName = data;
            }
        }
    }

    Process {
        id: updateNetworkStrength
        running: true
        command: ["sh", "-c", "nmcli -f IN-USE,SIGNAL,SSID device wifi | awk '/^\\*/{if (NR!=1) {print $2}}'"]
        stdout: SplitParser {
            onRead: data => {
                root.networkStrength = parseInt(data) || 0;
            }
        }
    }

    Process {
        id: wifiStatusProcess
        command: ["nmcli", "radio", "wifi"]
        running: false
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        stdout: SplitParser {
            onRead: data => {
                root.wifiEnabled = data.trim() === "enabled";
            }
        }
    }

    Process {
        id: getNetworks
        running: true
        command: ["nmcli", "-g", "ACTIVE,SIGNAL,FREQ,SSID,BSSID,SECURITY", "d", "w"]
        environment: ({
            LANG: "C",
            LC_ALL: "C"
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

                // Sync current list with new data
                // 1. Remove gone networks
                for (let i = rNetworks.length - 1; i >= 0; i--) {
                    const rn = rNetworks[i];
                    const found = wifiNetworksData.find(n => n.frequency === rn.frequency && n.ssid === rn.ssid && n.bssid === rn.bssid);
                    if (!found) {
                        rNetworks.splice(i, 1);
                        rn.destroy();
                    }
                }

                // 2. Update existing or add new
                for (let i = 0; i < wifiNetworksData.length; i++) {
                    const data = wifiNetworksData[i];
                    const existing = rNetworks.find(n => n.frequency === data.frequency && n.ssid === data.ssid && n.bssid === data.bssid);
                    if (existing) {
                        existing.lastIpcObject = data;
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
        wifiStatusProcess.running = true;
    }
}
