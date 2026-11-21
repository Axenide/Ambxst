pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Transport for Hermes' TUI gateway JSON-RPC over the shared gateway's
// WebSocket. Everything above this file (Ai.qml, the sidebar) only sees
// requests, events and pending prompts, so the transport stays replaceable.
Singleton {
    id: root

    // idle | attaching | connecting | ready | error
    property string status: "idle"
    property string lastError: ""
    readonly property bool connected: status === "ready"

    // "unknown" while the resolver runs, true/false once it answers. A missing
    // binary must never start attach or look like a gateway failure.
    property var installed: "unknown"
    property string resolvedPath: ""

    property string _detectedCommand: ""
    property bool _detectQueued: false

    // Sanitized runtime.describe result, never the attach payload.
    property var runtimeInfo: null

    // Server->client requests waiting for an answer. They live here, not in a
    // delegate, so closing the sidebar keeps them answerable.
    property var prompts: []

    property bool _wanted: false
    property var _socket: null
    property int _nextId: 1
    property var _pending: ({})
    property int _reconnectAttempt: 0
    property bool _handshaking: false
    property bool _socketUnavailable: false

    // The four requests this client answers; everything else gets -32601.
    readonly property var _supportedMethods: ["approval", "sudo", "secret", "clarify"]

    // Named gatewayEvent: a plain `event` signal collides with QObject::event.
    signal gatewayEvent(string type, string sessionId, var payload)
    signal ready()

    function packageHint() {
        return "Install qt6-websockets (Arch), qt6-qtwebsockets (Fedora) or qt6.qtwebsockets (Nix), then restart the shell.";
    }

    // The absolute path every later call uses, so nothing depends on the
    // PATH Quickshell inherited from the compositor.
    function command() {
        if (resolvedPath !== "")
            return resolvedPath;
        let configured = (Config.ai.hermesCommand || "").trim();
        return configured !== "" ? configured : "hermes";
    }

    // The compositor often starts Quickshell with a minimal PATH, so resolve
    // through a login shell. The command travels as $1, never as shell text.
    function detectInstalled(force) {
        let configured = (Config.ai.hermesCommand || "").trim();
        if (configured === "")
            configured = "hermes";

        if (!force && installed !== "unknown" && configured === _detectedCommand)
            return;

        if (detectProcess.running) {
            _detectQueued = true;
            return;
        }

        installed = "unknown";
        _detectedCommand = configured;
        _detectQueued = false;
        detectProcess.command = ["/usr/bin/env", "bash", "-lc", "if [ -x \"$1\" ]; then printf '%s\\n' \"$1\"; exit 0; fi; " + "found=\"$(command -v -- \"$1\" 2>/dev/null)\" || found=\"\"; " + "if [ -n \"$found\" ]; then printf '%s\\n' \"$found\"; exit 0; fi; " + "if [ -x \"$HOME/.local/bin/$1\" ]; then printf '%s\\n' \"$HOME/.local/bin/$1\"; exit 0; fi; " + "exit 1", "bash", configured];
        detectProcess.running = true;
    }

    function ensureStarted() {
        if (installed === false)
            return;

        _wanted = true;
        if (status === "ready" || status === "attaching" || status === "connecting")
            return;
        if (_socketUnavailable) {
            status = "error";
            return;
        }
        _connect(false, false);
    }

    function stop() {
        _wanted = false;
        _socketUnavailable = false;
        _handshaking = false;
        _reconnectAttempt = 0;
        reconnectTimer.stop();
        attachTimer.stop();

        if (attachProcess.running)
            attachProcess.running = false;

        if (_socket) {
            _socket.close();
            _socket.destroy();
            _socket = null;
        }

        _rejectPending("Hermes gateway disconnected.");
        _pending = ({});
        _clearPrompts();
        runtimeInfo = null;
        status = "idle";
        lastError = "";
    }

    // ============================================
    // CONNECTION
    // ============================================

    function _makeSocket() {
        if (_socket)
            return _socket;

        let component = Qt.createComponent(Qt.resolvedUrl("HermesSocket.qml"));
        if (!component || component.status !== Component.Ready) {
            _socketUnavailable = true;
            status = "error";
            lastError = "The Hermes backend needs the QtWebSockets QML module. " + packageHint();
            return null;
        }

        _socket = component.createObject(root);
        if (!_socket) {
            _socketUnavailable = true;
            status = "error";
            lastError = "The Hermes backend needs the QtWebSockets QML module. " + packageHint();
            return null;
        }

        _socket.opened.connect(_onSocketOpened);
        _socket.closed.connect(_onSocketClosed);
        _socket.frame.connect(_onFrame);
        return _socket;
    }

    function _connect(start, recover) {
        if (!_wanted)
            return;
        if (!_makeSocket())
            return;

        status = "attaching";
        lastError = "";

        let flags = [];
        if (start)
            flags.push("--start");
        else if (recover)
            flags.push("--recover");

        attachTimer.restart();
        attachProcess.recovering = recover;
        attachProcess.command = ["/usr/bin/env", command(), "gateway", "attach", "--json"].concat(flags);
        attachProcess.running = true;
    }

    function _onSocketOpened() {
        status = "connecting";
    }

    function _onSocketClosed() {
        if (_socket) {
            let closing = _socket;
            _socket = null;
            closing.destroy();
        }

        _handshaking = false;
        _rejectPending("Hermes gateway connection closed.");
        _pending = ({});
        _clearPrompts();
        runtimeInfo = null;

        if (!_wanted) {
            status = "idle";
            return;
        }

        // Keep the attach error that caused the close instead of replacing it.
        if (status !== "error" || lastError === "") {
            status = "error";
            lastError = "Hermes gateway connection closed.";
        }
        _scheduleReconnect();
    }

    function _scheduleReconnect() {
        if (!_wanted || _socketUnavailable)
            return;

        _reconnectAttempt++;
        let delay = Math.min(30000, 1000 * Math.pow(2, Math.min(_reconnectAttempt, 5)));
        reconnectTimer.interval = delay;
        reconnectTimer.start();
    }

    function _fail(message) {
        status = "error";
        lastError = message;
        // The socket's closed handler owns destroying it and scheduling the retry.
        if (_socket)
            _socket.close();
    }

    // QML's JS engine has no setTimeout, so request deadlines use real timers.
    Component {
        id: requestTimeoutComponent

        Timer {
            repeat: false
        }
    }

    Timer {
        id: reconnectTimer
        repeat: false
        onTriggered: root._connect(false, true)
    }

    // attach has to answer too, or the first message waits forever.
    Timer {
        id: attachTimer
        repeat: false
        interval: 30000
        onTriggered: {
            if (attachProcess.running)
                attachProcess.running = false;
            root._fail("Hermes gateway did not answer the attach request in time.");
        }
    }

    // Exit 0 with a path on stdout means found; 1 means not installed. A failed
    // spawn leaves the state unknown, which the UI renders as "still checking".
    Process {
        id: detectProcess

        stdout: StdioCollector {
            id: detectOut
        }

        stderr: StdioCollector {
            id: detectErr
        }

        onExited: exitCode => {
            let found = detectOut.text.trim();
            if (exitCode === 0 && found !== "") {
                root.resolvedPath = found;
                root.installed = true;
            } else {
                root.resolvedPath = "";
                root.installed = false;
            }

            if (root._detectQueued)
                Qt.callLater(() => root.detectInstalled(true));
        }
    }

    Process {
        id: attachProcess
        property bool recovering: false

        stdout: StdioCollector {
            id: attachOut
        }

        stderr: StdioCollector {
            id: attachErr
        }

        // Only ever reads url/protocols from the payload; the ticket inside
        // `protocols` (and the payload's own ticket field) stays in memory.
        onExited: exitCode => {
            attachTimer.stop();

            if (!root._wanted)
                return;

            if (exitCode !== 0) {
                // A gateway that is not running yet needs --start; a dropped
                // connection needs --recover. Either way, try --start once.
                if (attachProcess.command.indexOf("--start") === -1) {
                    root._connect(true, false);
                    return;
                }

                let detail = attachErr.text.trim();
                if (detail === "")
                    detail = attachOut.text.trim();
                if (detail.length > 300)
                    detail = detail.substring(0, 300);

                root._fail("Could not reach the Hermes gateway." + (detail !== "" ? " " + detail : " Run `" + root.command() + " gateway status` to check it."));
                return;
            }

            let parsed;
            try {
                parsed = JSON.parse(attachOut.text);
            } catch (e) {
                root._fail("Hermes gateway attach returned unreadable output.");
                return;
            }

            let url = parsed.url || "";
            let protocols = parsed.protocols || [];
            if (url === "" || protocols.length === 0) {
                root._fail("Hermes gateway attach did not return a WebSocket endpoint.");
                return;
            }

            let socket = root._makeSocket();
            if (!socket)
                return;

            // The ticket is single-use and expires within seconds.
            status = "connecting";
            socket.dial(url, protocols);
        }
    }

    // ============================================
    // FRAMES
    // ============================================

    function _send(frame) {
        if (_socket)
            _socket.send(JSON.stringify(frame));
    }

    function _onFrame(text) {
        let frame;
        try {
            frame = JSON.parse(text);
        } catch (e) {
            return;
        }

        if (frame.method === "event") {
            _onEvent(frame.params || {});
            return;
        }

        if (frame.id !== undefined && frame.method !== undefined) {
            _onServerRequest(frame.id, frame.method, frame.params || {});
            return;
        }

        if (frame.id !== undefined && (frame.result !== undefined || frame.error !== undefined)) {
            let key = String(frame.id);
            let entry = _pending[key];
            if (!entry)
                return;
            delete _pending[key];
            if (entry.timer) {
                entry.timer.stop();
                entry.timer.destroy();
            }
            if (typeof entry.callback === "function")
                entry.callback(frame.error || null, frame.result === undefined ? null : frame.result);
        }
    }

    function _onEvent(params) {
        let type = params.type || "";
        let payload = params.payload || {};

        if (type === "gateway.ready") {
            _handshake();
            return;
        }

        if (type === "request.cancel") {
            // Withdraws exactly one prompt; others stay answerable.
            _dropPrompt(payload.id);
            return;
        }

        gatewayEvent(type, params.session_id || "", payload);
    }

    function _handshake() {
        if (_handshaking)
            return;

        _handshaking = true;

        request("runtime.describe", {}, (err, result) => {
            _handshaking = false;

            if (err) {
                _fail("Hermes gateway refused runtime.describe: " + (err.message || "unknown error"));
                return;
            }

            let descriptor = (result && result.session_create) ? result.session_create : {};
            runtimeInfo = {
                "instanceId": result ? (result.instance_id || "") : "",
                "profileId": result ? (result.profile_id || "") : "",
                "capabilities": (result && result.capabilities) ? result.capabilities : [],
                "sources": descriptor.sources ? descriptor.sources : [],
                "parameters": descriptor.parameters ? descriptor.parameters : []
            };

            // Required once per connection, or every server request is
            // withdrawn before it reaches the user.
            request("client.capabilities", {
                "server_requests": true
            }, () => {
                status = "ready";
                lastError = "";
                _reconnectAttempt = 0;
                ready();
            });
        });
    }

    // ============================================
    // REQUESTS
    // ============================================

    // timeouts cover acknowledgements only; streamed replies arrive as events.
    function request(method, params, callback, timeoutMs) {
        // Handshake requests go out while still connecting, before status is "ready".
        if (!_socket || (status !== "ready" && status !== "connecting")) {
            if (typeof callback === "function")
                callback({
                    "code": -32000,
                    "message": "Hermes gateway is not connected."
                }, null);
            return -1;
        }

        let id = _nextId++;
        let key = String(id);
        let limit = timeoutMs > 0 ? timeoutMs : 30000;
        let entry = {
            "callback": typeof callback === "function" ? callback : null,
            "method": method,
            "timer": null
        };

        // Without this a lost acknowledgement leaves the UI spinning forever.
        let timer = requestTimeoutComponent.createObject(root);
        if (timer) {
            timer.interval = limit;
            timer.triggered.connect(function () {
                let pending = _pending[key];
                if (!pending)
                    return;
                delete _pending[key];
                timer.destroy();
                if (typeof pending.callback === "function")
                    pending.callback({
                        "code": -32001,
                        "message": "Hermes did not answer " + method + " in time."
                    }, null);
            });
            timer.start();
        }
        entry.timer = timer;

        _pending[key] = entry;
        _send({
            "jsonrpc": "2.0",
            "id": id,
            "method": method,
            "params": params || {}
        });
        return id;
    }

    function _rejectPending(message) {
        for (let key in _pending) {
            let entry = _pending[key];
            if (!entry)
                continue;
            if (entry.timer) {
                entry.timer.stop();
                entry.timer.destroy();
            }
            if (typeof entry.callback === "function")
                entry.callback({
                    "code": -32000,
                    "message": message
                }, null);
        }
    }

    // ============================================
    // SERVER -> CLIENT REQUESTS
    // ============================================

    function _onServerRequest(id, method, params) {
        if (_supportedMethods.indexOf(method) === -1) {
            // Answer fast so the agent does not wait out its deadline.
            respondError(id, -32601, "not supported by ambxst: " + method);
            return;
        }

        let list = prompts.slice();
        list.push({
            "id": id,
            "method": method,
            "sessionId": params.session_id || "",
            "params": params
        });
        prompts = list;
    }

    function findPrompt(id) {
        for (let i = 0; i < prompts.length; i++) {
            if (String(prompts[i].id) === String(id))
                return prompts[i];
        }
        return null;
    }

    function respond(id, result) {
        _send({
            "jsonrpc": "2.0",
            "id": id,
            "result": result === undefined ? {} : result
        });
        _dropPrompt(id);
    }

    function respondError(id, code, message) {
        _send({
            "jsonrpc": "2.0",
            "id": id,
            "error": {
                "code": code,
                "message": message
            }
        });
        _dropPrompt(id);
    }

    function _dropPrompt(id) {
        let list = [];
        for (let i = 0; i < prompts.length; i++) {
            if (String(prompts[i].id) !== String(id))
                list.push(prompts[i]);
        }
        if (list.length !== prompts.length)
            prompts = list;
    }

    function _clearPrompts() {
        if (prompts.length === 0)
            return;
        prompts = [];
    }
}
