pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    property bool toggled: false

    readonly property string enableKeywords: "keyword animations:enabled 0; keyword decoration:shadow:enabled 0; keyword decoration:blur:enabled 0; keyword general:gaps_in 0; keyword general:gaps_out 0; keyword general:border_size 1; keyword decoration:rounding 0"

    // Game mode kills shell animations: Config.animDuration is a plain
    // property now (decoupled from this service's toggled state) and is
    // written here when the mode changes.
    function applyAnimDuration() {
        Config.animDuration = root.toggled ? 0 : Config.theme.animDuration;
    }

    property Process enableProcess: Process {
        running: false
        stdout: SplitParser {}
        onExited: (code) => {
            if (code === 0) {
                root.toggled = true
                root.saveState()
                root.applyAnimDuration()
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
                root.applyAnimDuration()
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

    property bool _initialized: false

    function loadState() {
        // Guard: both onStateLoaded and the startup fallback timer can fire
        // (onStateLoaded after a reload + timer if the signal already passed);
        // double-loading spawned duplicate `axctl config apply` processes.
        if (root._initialized)
            return;
        root._initialized = true;
        root.toggled = StateService.get("gameMode", false)
        root.applyAnimDuration()
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
