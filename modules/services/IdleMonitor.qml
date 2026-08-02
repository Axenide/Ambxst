import QtQuick
import Quickshell.Io
import qs.modules.services

Item {
    id: root

    property bool enabled: true
    property real timeout: 0
    property bool respectInhibitors: true
    property bool isIdle: false

    property var _monitorId: 0
    property bool _initialized: false
    property bool _creating: false

    // Bounded retry for the startup race where the axctl daemon socket isn't
    // ready yet when the monitor is first created.
    property int _initRetries: 0
    readonly property int _maxInitRetries: 10

    Timer {
        id: _initRetryTimer
        interval: 1000
        repeat: false
        onTriggered: root._initMonitor()
    }

    function _scheduleInitRetry() {
        if (!_initialized && !_creating && enabled && timeout > 0 && _initRetries < _maxInitRetries) {
            _initRetries++;
            _initRetryTimer.restart();
        }
    }

    // One-shot axctl RPC with array arguments (no shell wrapper). The created
    // process destroys itself on exit; onDone(code, text) receives the result.
    Component {
        id: axctlProcComp
        Process {
            property var cmd: []
            property var onDone: null
            command: cmd
            running: true
            stdout: StdioCollector {}
            onExited: (code) => {
                if (onDone) onDone(code, stdout.text || "");
                destroy();
            }
        }
    }

    function _runAxctl(args, onDone) {
        axctlProcComp.createObject(root, { cmd: ["axctl"].concat(args), onDone: onDone });
    }

    function _initMonitor() {
        if (_initialized || _creating || !enabled || timeout <= 0) return;

        _creating = true;
        var timeoutMs = Math.round(timeout * 1000);
        _runAxctl(["system", "idle-monitor-create", String(timeoutMs), respectInhibitors ? "1" : "0", "1"], (code, text) => {
            _creating = false;
            if (code === 0 && text) {
                try {
                    var json = JSON.parse(text.trim());
                    _monitorId = json.id;
                    _initialized = true;
                    _initRetries = 0;
                    if (!root.enabled) {
                        // Disabled while the create was in flight — tear the
                        // monitor back down so it doesn't leak daemon-side.
                        var staleId = json.id;
                        _monitorId = 0;
                        _initialized = false;
                        _runAxctl(["system", "idle-monitor-destroy", String(staleId)]);
                        return;
                    }
                    // The create response carries the current state, so the
                    // monitor is accurate from the very first tick.
                    if (json.is_idle !== undefined && json.is_idle !== root.isIdle) {
                        root.isIdle = json.is_idle;
                    }
                } catch (e) {
                    console.warn("Idle monitor not ready, retrying:", text.trim());
                    _scheduleInitRetry();
                }
            } else {
                console.warn("Failed to create idle monitor (code=" + code + "), retrying");
                _scheduleInitRetry();
            }
        });
    }

    function _destroyMonitor() {
        if (_monitorId <= 0) return;
        var id = _monitorId;
        _monitorId = 0;
        _initialized = false;
        _runAxctl(["system", "idle-monitor-destroy", String(id)]);
    }

    function _updateMonitor() {
        if (!enabled || timeout <= 0 || _monitorId === 0) {
            _destroyMonitor();
            return;
        }

        var timeoutMs = Math.round(timeout * 1000);
        _runAxctl(["system", "idle-monitor-update", String(_monitorId), String(timeoutMs), respectInhibitors ? "1" : "0", "1"]);
    }

    // Re-read the current state after the subscribe stream (re)connects, so a
    // transition that happened while the stream was down is not missed.
    function _syncState() {
        if (!_initialized || _monitorId === 0) return;
        _runAxctl(["system", "idle-monitor-get", String(_monitorId)], (code, text) => {
            if (code !== 0 || !text) return;
            try {
                var json = JSON.parse(text.trim());
                if (json.is_idle !== undefined && json.is_idle !== root.isIdle) {
                    root.isIdle = json.is_idle;
                }
            } catch (e) {}
        });
    }

    // Primary state source: the daemon broadcasts every monitor transition to
    // the subscribe stream AxctlService already maintains (with auto-reconnect),
    // so state below is fully event-driven instead of a per-second
    // idle-monitor-get poll.
    Connections {
        target: AxctlService
        function onRawEvent(event) {
            if (!root._initialized || !event || event.name !== "idlemonitorchanged") return;
            var data = event.data;
            if (data && data.id === root._monitorId && data.is_idle !== undefined) {
                root.isIdle = data.is_idle;
            }
        }
        function onSubscribed() {
            root._syncState();
        }
    }

    function _checkMediaInhibitor() {
        if (!root.respectInhibitors) return;
        _runAxctl(["system", "media-inhibit-check"], (code, text) => {
            if (code !== 0 || !text) return;
            try {
                var json = JSON.parse(text.trim());
                if (json.count > 0) {
                    root.isIdle = false;
                }
            } catch (e) {}
        });
    }

    Timer {
        id: mediaCheckTimer
        interval: 5000
        // Media inhibitors only matter to un-idle the session, so there is no
        // need to poll axctl while the session is already active.
        running: root.enabled && root.respectInhibitors && root.isIdle
        repeat: true
        onTriggered: root._checkMediaInhibitor()
    }

    onEnabledChanged: {
        if (!enabled) {
            _destroyMonitor();
            isIdle = false;
        } else if (timeout > 0) {
            _initMonitor();
        }
    }

    onTimeoutChanged: {
        if (timeout > 0 && enabled) {
            if (_initialized) {
                _updateMonitor();
            } else {
                _initMonitor();
            }
        } else {
            _destroyMonitor();
        }
    }

    onRespectInhibitorsChanged: {
        if (_initialized) {
            _updateMonitor();
        }
    }

    Component.onDestruction: {
        _destroyMonitor();
    }

    // Wait until the axctl daemon is ready before creating the monitor, so we
    // don't hit the "socket not ready" error on startup. The bounded retry above
    // remains as a fallback for any other transient failure.
    Connections {
        target: AxctlService
        function onReadyChanged() {
            if (AxctlService.ready && root.enabled && root.timeout > 0 && !root._initialized)
                root._initMonitor();
        }
    }

    Component.onCompleted: {
        if (AxctlService.ready && enabled && timeout > 0) {
            _initMonitor();
        }
    }
}
