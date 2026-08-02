pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool toggled: false
    property bool initialized: false
    
    property string stateFile: Quickshell.statePath("states.json")

    property Process enableProcess: Process {
        running: false
        stdout: SplitParser {}
        onExited: (code) => {
            if (code === 0) {
                root.toggled = true
                root.saveState()
            }
        }
    }

    property Process disableProcess: Process {
        running: false
        stdout: SplitParser {}
        onExited: (code) => {
            if (code === 0) {
                root.toggled = false
                root.saveState()
            }
        }
    }
    
    // Persist gameMode via the daemon (locked RMW on states.json,
    // coordinated with StateService — no more clobbering writes).
    function saveState() {
        BackendService.call("config.stateSet", {key: "gameMode", value: root.toggled});
    }

    function toggle() {
        if (toggled) {
            disableProcess.command = ["axctl", "config", "reload"]
            disableProcess.running = true
        } else {
            enableProcess.command = ["axctl", "config", "apply", 
                "keyword animations:enabled 0; keyword decoration:shadow:enabled 0; keyword decoration:blur:enabled 0; keyword general:gaps_in 0; keyword general:gaps_out 0; keyword general:border_size 1; keyword decoration:rounding 0"]
            enableProcess.running = true
        }
    }

    function loadState() {
        BackendService.call("config.statesGet", {}, (result, error) => {
            if (error || !result) {
                root.initialized = true;
                return;
            }
            if (result.gameMode !== undefined) {
                root.toggled = result.gameMode;
                if (root.toggled) {
                    enableProcess.command = ["axctl", "config", "apply",
                        "keyword animations:enabled 0; keyword decoration:shadow:enabled 0; keyword decoration:blur:enabled 0; keyword general:gaps_in 0; keyword general:gaps_out 0; keyword general:border_size 1; keyword decoration:rounding 0"]
                    enableProcess.running = true
                }
            }
            root.initialized = true
        })
    }

    // Init on creation
    Timer {
        interval: 100
        running: true
        repeat: false
        onTriggered: {
            if (!root.initialized) {
                root.loadState()
            }
        }
    }
}
