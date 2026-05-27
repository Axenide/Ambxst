pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/*!
    IpcPool.qml — IPC call coalescer / debouncer.

    Prevents multiple rapid hyprctl dispatches from overloading the compositor.
    Batches calls within a window and fires once.

    Usage:
        IpcPool.dispatch("workspace 3");
        IpcPool.dispatch("movewindow mon:DP-1");

    If called multiple times within 50ms, only the last call fires.
    Supports batch mode: IpcPool.dispatchBatch(["workspace 1", "focuswindow ..."]);
*/
Singleton {
    id: root

    property int debounceMs: 50

    property var _pendingCommands: []
    property Timer _flushTimer: Timer {
        id: flushTimer
        interval: root.debounceMs
        repeat: false
        onTriggered: root._flush()
    }

    function dispatch(command) {
        root._pendingCommands.push(command);
        if (!flushTimer.running) flushTimer.restart();
        if (root._pendingCommands.length >= 10) {
            flushTimer.stop();
            root._flush();
        }
    }

    function dispatchBatch(commands) {
        if (!commands || commands.length === 0) return;
        root._pendingCommands = root._pendingCommands.concat(commands);
        if (!flushTimer.running) flushTimer.restart();
    }

    function _flush() {
        if (root._pendingCommands.length === 0) return;

        // Deduplicate: keep last occurrence of each unique command
        const seen = {};
        const unique = [];
        for (let i = root._pendingCommands.length - 1; i >= 0; i--) {
            const cmd = root._pendingCommands[i];
            if (!seen[cmd]) {
                seen[cmd] = true;
                unique.unshift(cmd);
            }
        }

        root._pendingCommands = [];

        // Fire each command individually (hyprctl doesn't support batch natively)
        for (const cmd of unique) {
            const p = _processPool.getProcess();
            p.command = ["hyprctl", "dispatch", cmd];
            p.running = true;
        }
    }

    // Process pool — reuse Process objects to avoid allocation
    property QtObject _processPool: QtObject {
        id: processPool

        property var _pool: []
        property int _maxSize: 8

        function getProcess() {
            if (_pool.length > 0) {
                return _pool.pop();
            }
            const p = processComponent.createObject(root);
            p.onExited.connect(() => {
                if (processPool._pool.length < processPool._maxSize) {
                    processPool._pool.push(p);
                }
            });
            return p;
        }

        property Component processComponent: Component {
            Process {
                running: false
                command: []
            }
        }
    }
}
