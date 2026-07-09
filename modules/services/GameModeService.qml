pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool toggled: false

    readonly property string enableKeywords: "keyword animations:enabled 0; keyword decoration:shadow:enabled 0; keyword decoration:blur:enabled 0; keyword general:gaps_in 0; keyword general:gaps_out 0; keyword general:border_size 1; keyword decoration:rounding 0"

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

    function toggle() {
        if (toggled) {
            disableProcess.command = ["axctl", "config", "reload"]
            disableProcess.running = true
        } else {
            enableProcess.command = ["axctl", "config", "apply", enableKeywords]
            enableProcess.running = true
        }
    }

    function saveState() {
        if (StateService.initialized)
            StateService.set("gameMode", root.toggled)
    }

    function loadState() {
        root.toggled = StateService.get("gameMode", false)
        if (root.toggled) {
            enableProcess.command = ["axctl", "config", "apply", enableKeywords]
            enableProcess.running = true
        }
    }

    Connections {
        target: StateService
        function onStateLoaded() {
            root.loadState()
        }
    }

    Timer {
        interval: 100
        running: true
        repeat: false
        onTriggered: {
            if (StateService.initialized)
                root.loadState()
        }
    }
}
