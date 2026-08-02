import QtQuick
import Quickshell
import Quickshell.Io

pragma Singleton

// BackendService bridges QML to the ambxst Go daemon over a Unix socket.
// Protocol: line-delimited JSON-RPC (see backend/pkg/ipc).
// - reqSocket: shared request/response socket, id -> callback map.
// - Subscriptions: one dedicated Socket per consumer group; each sends
//   {"id":1,"method":"subscribe","params":{"services":[...]}} on connect
//   and streams {"id":1,"result":{"service":"x","data":...}} lines.
//
// Usage:
//   const handle = BackendService.addSubscription(["systemmonitor"], (service, data) => {...});
//   BackendService.setSubscriptionActive(handle, false); // pause polling
//   BackendService.removeSubscription(handle);
Singleton {
    id: root

    readonly property string socketPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ambxst.sock"

    property bool connected: false

    readonly property var daemonCandidates: [
        Quickshell.shellDir + "/backend/ambxst",
        Quickshell.shellDir + "/backend/bin/ambxst",
        "ambxst"
    ]

    // ---- request machinery ----
    property var pending: ({})
    property int nextId: 1

    // ---- subscriptions: keyed by integer handle ----
    property var subscriptions: ({})
    property int nextSubId: 1

    // ---- lifecycle ----
    property bool daemonStarted: false
    property int daemonCandidateIdx: 0

    // Spawn the daemon on first use if the socket is missing.
    property Process daemonProcess: Process {
        id: daemonProcess
        running: false
        onExited: (code) => {
            console.warn("BackendService: daemon exited with code", code);
            root.daemonStarted = false;
            root.daemonCandidateIdx++;
            if (root.daemonCandidateIdx >= root.daemonCandidates.length) {
                root.daemonCandidateIdx = 0; // wrap: retry from start later
            }
            connectRetry.running = true;
        }
    }

    Timer {
        id: daemonProbe
        interval: 500
        running: false
        repeat: true
        onTriggered: root.tryConnect()
    }

    Timer {
        id: connectRetry
        interval: 1500
        running: false
        repeat: true
        onTriggered: {
            if (!root.daemonStarted) root.spawnDaemon();
            root.tryConnect();
        }
    }

    function resolveDaemonBinary() {
        const candidates = root.daemonCandidates;
        if (root.daemonCandidateIdx < candidates.length) {
            return candidates[root.daemonCandidateIdx];
        }
        return "ambxst";
    }

    function spawnDaemon() {
        if (root.daemonStarted) return;
        root.daemonStarted = true;
        daemonProcess.command = [root.resolveDaemonBinary(), "daemon"];
        daemonProcess.running = true;
    }

    // Connection errors are the probe: if daemon absent, spawn + retry.
    function tryConnect() {
        if (root.socketAvailable) return;
        if (!root.daemonStarted) root.spawnDaemon();
        reqSocket.connected = true;
        const keys = Object.keys(root.subscriptions);
        for (let i = 0; i < keys.length; i++) {
            const sub = root.subscriptions[keys[i]];
            if (sub && sub.active && sub.ok) sub.socket.connected = true;
        }
    }

    property bool socketAvailable: false
    onSocketAvailableChanged: {
        if (socketAvailable) {
            daemonProbe.running = false;
            connectRetry.running = false;
        } else {
            daemonProbe.running = true;
        }
    }

    // Adds a subscription. Returns an integer handle.
    function addSubscription(services, callback) {
        const key = root.nextSubId++;
        const obj = subSocketFactory.createObject(root, {services: services, callback: callback});
        root.subscriptions[key] = {socket: obj, active: true, ok: true};
        if (root.socketAvailable) Qt.callLater(() => { if (root.subscriptions[key] && root.subscriptions[key].ok) obj.connected = true; });
        return key;
    }

    function setSubscriptionActive(key, active) {
        const sub = root.subscriptions[key];
        if (!sub || !sub.ok) return;
        sub.active = active;
        if (active) {
            if (!root.socketAvailable) {
                daemonProbe.running = true;
                return;
            }
            sub.socket.connected = true;
        } else {
            sub.socket.connected = false;
        }
    }

    function removeSubscription(key) {
        const sub = root.subscriptions[key];
        if (!sub || !sub.ok) return;
        sub.ok = false;
        sub.socket.connected = false;
        sub.socket.destroy();
        delete root.subscriptions[key];
    }

    function call(method, params, callback) {
        if (!params) params = {};
        const id = root.nextId++;
        root.pending[id] = callback;
        reqSocket.write(JSON.stringify({id, method, params}) + "\n");
        reqSocket.flush();
    }

    function notify(method, params) {
        if (!params) params = {};
        reqSocket.write(JSON.stringify({id: root.nextId++, method, params}) + "\n");
        reqSocket.flush();
    }

    Component.onCompleted: {
        if (root.socketAvailable) root.tryConnect();
        daemonProbe.running = true;
    }

    // Per-consumer subscription socket. Sends the subscribe request on every
    // connect and forwards matching ServiceEvents to the registered callback.
    Component {
        id: subSocketFactory
        Socket {
            id: sub
            property var services: []
            property var callback: null

            path: root.socketPath
            connected: false

            parser: SplitParser {
                onRead: (data) => {
                    if (!data) return;
                    try {
                        const msg = JSON.parse(data);
                        const ev = msg.result;
                        if (ev && ev.service && sub.callback) {
                            sub.callback(ev.service, ev.data);
                        }
                    } catch (e) {
                        console.warn("BackendService: failed to parse event:", e);
                    }
                }
            }

            onConnectionStateChanged: {
                if (sub.connected) {
                    sub.write(JSON.stringify({id: 1, method: "subscribe", params: {services: sub.services}}) + "\n");
                    sub.flush();
                }
            }

            onError: (error) => {
                console.warn("BackendService: subscription socket error", error);
                root.onSocketDown();
            }
        }
    }

    // Shared request/response socket.
    Socket {
        id: reqSocket
        path: root.socketPath
        connected: false

        parser: SplitParser {
            onRead: (data) => {
                if (!data) return;
                try {
                    const msg = JSON.parse(data);
                    if (typeof msg.id === "number" && msg.id !== 0) {
                        const cb = root.pending[msg.id];
                        delete root.pending[msg.id];
                        if (cb) cb(msg.result, msg.error);
                    }
                } catch (e) {
                    console.warn("BackendService: failed to parse response:", e);
                }
            }
        }

        onError: (error) => {
            console.warn("BackendService: request socket error", error);
            root.onSocketDown();
        }

        onConnectionStateChanged: {
            root.socketAvailable = reqSocket.connected;
            if (!reqSocket.connected) root.onSocketDown();
        }
    }

    function onSocketDown() {
        socketAvailable = false;
        connectRetry.running = true;
        if (daemonProbe.running === false) daemonProbe.running = true;
    }
}
