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

    property var _createProcess: Process {
        id: _createProcess
        command: ["sh", "-c", ""]
        running: false
        stdout: StdioCollector {
            id: _createStdout
        }
        onExited: (code) => {
            if (code === 0 && _createStdout.text) {
                try {
                    var json = JSON.parse(_createStdout.text.trim());
                    _monitorId = json.id;
                    _initialized = true;
                    _startPolling();
                } catch (e) {
                    console.error("Failed to parse idle monitor response:", _createStdout.text, e);
                }
            } else {
                console.error("Failed to create idle monitor: code=", code, "output:", _createStdout.text);
            }
        }
    }

    property var _getProcess: Process {
        id: _getProcess
        command: ["sh", "-c", ""]
        running: false
        stdout: StdioCollector {
            id: _getStdout
        }
        onExited: (code) => {
            if (code === 0 && _getStdout.text) {
                try {
                    var json = JSON.parse(_getStdout.text.trim());
                    if (json.is_idle !== undefined && json.is_idle !== root.isIdle) {
                        root.isIdle = json.is_idle;
                    }
                } catch (e) {
                }
            }
        }
    }

    property var _updateProcess: Process {
        id: _updateProcess
        command: ["sh", "-c", ""]
        running: false
        stdout: StdioCollector {
            id: _updateStdout
        }
        onExited: (code) => {
            if (code === 0) {
                root._checkIdle();
            }
        }
    }

    property var _destroyProcess: Process {
        id: _destroyProcess
        command: ["sh", "-c", ""]
        running: false
        stdout: StdioCollector {
            id: _destroyStdout
        }
        onExited: (code) => {
            _monitorId = 0;
            _initialized = false;
        }
    }

    function _initMonitor() {
        if (_initialized || !enabled || timeout <= 0) return;

        var timeoutMs = Math.round(timeout * 1000);
        var respect = respectInhibitors ? 1 : 0;
        var en = enabled ? 1 : 0;

        var cmd = "axctl system idle-monitor-create " + timeoutMs + " " + respect + " " + en;
        _createProcess.command = ["sh", "-c", cmd];
        _createProcess.running = true;
    }

    function _destroyMonitor() {
        if (_monitorId > 0) {
            var cmd = "axctl system idle-monitor-destroy " + _monitorId;
            _destroyProcess.command = ["sh", "-c", cmd];
            _destroyProcess.running = true;
        }
    }

    function _startPolling() {
        pollTimer.running = true;
    }

    function _stopPolling() {
        pollTimer.running = false;
    }

    function _checkIdle() {
        if (!_initialized || _monitorId === 0) return;

        var cmd = "axctl system idle-monitor-get " + _monitorId;
        _getProcess.command = ["sh", "-c", cmd];
        _getProcess.running = true;
    }

    function _checkMediaInhibitor() {
        if (!root.respectInhibitors) return;

        var cmd = "axctl system media-inhibit-check";
        _mediaCheckProcess.command = ["sh", "-c", cmd];
        _mediaCheckProcess.running = true;
    }

    property var _mediaCheckProcess: Process {
        id: _mediaCheckProcess
        command: ["sh", "-c", ""]
        running: false
        stdout: StdioCollector {
            id: _mediaCheckStdout
        }
        onExited: (code) => {
            if (code === 0 && _mediaCheckStdout.text) {
                try {
                    var json = JSON.parse(_mediaCheckStdout.text.trim());
                    if (json.count > 0) {
                        root.isIdle = false;
                    }
                } catch (e) {}
            }
        }
    }

    Timer {
        id: mediaCheckTimer
        interval: 5000
        running: true
        repeat: true
        onTriggered: root._checkMediaInhibitor()
    }

    function _updateMonitor() {
        if (!enabled || timeout <= 0 || _monitorId === 0) {
            _stopPolling();
            return;
        }

        var timeoutMs = Math.round(timeout * 1000);
        var respect = respectInhibitors ? 1 : 0;
        var en = enabled ? 1 : 0;

        var cmd = "axctl system idle-monitor-update " + _monitorId + " " + timeoutMs + " " + respect + " " + en;
        _updateProcess.command = ["sh", "-c", cmd];
        _updateProcess.running = true;
    }

    Timer {
        id: pollTimer
        interval: 1000
        running: false
        repeat: true
        onTriggered: root._checkIdle()
    }

    onEnabledChanged: {
        if (!enabled) {
            _destroyMonitor();
            _stopPolling();
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

    Component.onCompleted: {
        if (enabled && timeout > 0) {
            _initMonitor();
        }
    }
}