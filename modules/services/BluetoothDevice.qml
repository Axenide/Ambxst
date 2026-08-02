import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property string address: ""
    property string name: "Unknown"
    property string icon: "bluetooth"
    property bool paired: false
    property bool connected: false
    property bool trusted: false
    property int battery: -1
    property bool batteryAvailable: battery >= 0
    property bool connecting: false
    property bool pairing: false
    property string lastError: ""

    signal infoUpdated()

    property Timer errorTimer: Timer {
        interval: 5000
        repeat: false
        onTriggered: root.lastError = ""
    }

    function friendlyError(e) {
        const text = String(e || "");
        const lower = text.toLowerCase();
        if (lower.includes("authenticationfailed") || lower.includes("authenticationrejected") ||
            lower.includes("authenticationcanceled") || lower.includes("pinorkeymissing") ||
            lower.includes("pin or key"))
            return "Pairing failed \u2014 check the device and retry";
        if (lower.includes("no resolvable address") || lower.includes("host is down") || lower.includes("timed out"))
            return "Device unreachable \u2014 is it powered on?";
        if (lower.includes("no adapter") || lower.includes("not available"))
            return "Bluetooth adapter unavailable";
        if (lower.includes("failed"))
            return "Failed \u2014 try again";
        return text || "Operation failed";
    }

    function handleError(e) {
        const msg = root.friendlyError(e);
        if (root.lastError !== msg) {
            root.lastError = msg;
            errorTimer.restart();
            BluetoothService.notifyError(root.name, msg);
        }
        return msg;
    }

    // Pair + trust the device. Fails are surfaced via lastError/notification.
    function pair() {
        pairing = true;
        lastError = "";
        return BluetoothService.pairDevice(address).catch(e => {
            if (String(e).toLowerCase().includes("already")) return;
            pairing = false;
            root.handleError(e);
            throw e;
        }).then(() => {
            pairing = false;
            return BluetoothService.trustDevice(address).catch(() => {});
        });
    }

    // Connect (pairs first if needed, auto-trust)
    function connect() {
        connecting = true;
        lastError = "";
        let p;
        if (paired) {
            p = BluetoothService.trustDevice(address).catch(() => {})
                .then(() => BluetoothService.connectDevice(address));
        } else {
            p = pair().then(() => BluetoothService.connectDevice(address));
        }

        return p.catch(e => {
            root.handleError(e);
        }).finally(() => {
            connecting = false;
            BluetoothService.queueInfoUpdate(root);
        });
    }

    function setTrust(trusted: bool) {
        if (trusted) {
            BluetoothService.trustDevice(address).catch(e => {
                root.handleError(e);
            });
        } else {
            BluetoothService.runAsync(["bluetoothctl", "untrust", address]).catch(e => {
                root.handleError(e);
            });
        }
    }

    function updateInfo() {
        return BluetoothService.runAsync(["bluetoothctl", "info", address]).then(text => {
            Qt.callLater(() => {
                root.battery = -1;
                const lines = text.split("\n");
                for (const line of lines) {
                    const trimmed = line.trim();
                    if (trimmed.startsWith("Paired:")) {
                        root.paired = trimmed.includes("yes");
                    } else if (trimmed.startsWith("Connected:")) {
                        root.connected = trimmed.includes("yes");
                        if (root.connected) root.connecting = false;
                    } else if (trimmed.startsWith("Trusted:")) {
                        root.trusted = trimmed.includes("yes");
                    } else if (trimmed.startsWith("Icon:")) {
                        root.icon = trimmed.split(":")[1]?.trim() || "bluetooth";
                    } else if (trimmed.startsWith("Battery Percentage:")) {
                        const match = trimmed.match(/\((\d+)\)/);
                        if (match) {
                            root.battery = parseInt(match[1]) || -1;
                        }
                    }
                }
                root.infoUpdated();
            });
        }).catch(e => {
            console.error(`Failed to get info for ${address}: ${e}`);
        });
    }

    function disconnect() {
        BluetoothService.disconnectDevice(address).catch(e => {
            root.handleError(e);
        });
    }

    function forget() {
        BluetoothService.removeDevice(address).catch(() => {});
    }
}
