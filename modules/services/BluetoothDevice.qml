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

    signal infoUpdated()

    readonly property string helperPath: BluetoothService.helperPath

    function connect() {
        connecting = true;
        let p;
        if (!trusted) {
            p = BluetoothService.runAsync(["python3", helperPath, "trust", address]).then(() => {
                return BluetoothService.runAsync(["python3", helperPath, "connect", address]);
            });
        } else {
            p = BluetoothService.connectDevice(address);
        }
        return p.catch(e => {
            console.warn("BluetoothDevice: connect failed for " + address + ":", e);
        }).finally(() => {
            connecting = false;
            updateInfo();
        });
    }

    function updateInfo() {
        return BluetoothService.runAsync(["python3", helperPath, "info", address]).then(text => {
            Qt.callLater(() => {
                try {
                    var info = JSON.parse(text);
                    root.name = info.name || info.alias || root.name;
                    root.paired = info.paired || false;
                    root.connected = info.connected || false;
                    root.trusted = info.trusted || false;
                    root.icon = info.icon || "bluetooth";
                    if (root.connected) root.connecting = false;
                    root.infoUpdated();
                } catch (e) {
                    console.warn("BluetoothDevice: info parse failed for " + address);
                }
            });
        }).catch(e => {
            console.warn("BluetoothDevice: info failed for " + address + ":", e);
        });
    }

    function disconnect() { BluetoothService.disconnectDevice(address); }
    function pair() { BluetoothService.pairDevice(address); }
    function trust() { BluetoothService.trustDevice(address); }
    function forget() { BluetoothService.removeDevice(address); }
}
