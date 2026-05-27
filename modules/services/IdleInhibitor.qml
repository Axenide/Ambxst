import QtQuick
import Quickshell.Io

Item {
    id: inhibitor

    property bool enabled: false
    property var _inhibitorId: 0

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
                    _inhibitorId = json.id;
                } catch (e) {
                    console.error("Failed to parse inhibitor response:", _createStdout.text);
                }
            } else {
                console.error("Failed to create inhibitor: code=", code, "output:", _createStdout.text);
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
            _inhibitorId = 0;
        }
    }

    property var _toggleProcess: Process {
        id: _toggleProcess
        command: ["sh", "-c", ""]
        running: false
        stdout: StdioCollector {
            id: _toggleStdout
        }
        onExited: (code) => {
            // Toggle complete
        }
    }

    function _createInhibitor() {
        var en = enabled ? 1 : 0;
        var cmd = "axctl system idle-inhibitor-create " + en;
        _createProcess.command = ["sh", "-c", cmd];
        _createProcess.running = true;
    }

    function _destroyInhibitor() {
        if (_inhibitorId > 0) {
            var cmd = "axctl system idle-inhibitor-destroy " + _inhibitorId;
            _destroyProcess.command = ["sh", "-c", cmd];
            _destroyProcess.running = true;
        }
    }

    function _toggleInhibitor(enable) {
        if (_inhibitorId > 0) {
            var cmd = "axctl system idle-inhibitor-set " + _inhibitorId + " " + (enable ? 1 : 0);
            _toggleProcess.command = ["sh", "-c", cmd];
            _toggleProcess.running = true;
        }
    }

    onEnabledChanged: {
        if (_inhibitorId === 0) {
            _createInhibitor();
        } else {
            _toggleInhibitor(enabled);
        }
    }

    Component.onDestruction: {
        _destroyInhibitor();
    }

    Component.onCompleted: {
        if (enabled) {
            _createInhibitor();
        }
    }
}