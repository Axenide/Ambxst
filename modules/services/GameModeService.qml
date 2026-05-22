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
    
    property Process writeStateProcess: Process {
        running: false
        stdout: SplitParser {}
    }
    
    property Process readCurrentStateProcess: Process {
        running: false
        stdout: SplitParser {
            onRead: (data) => {
                try {
                    const content = data ? data.trim() : ""
                    let states = {}
                    if (content) {
                        states = JSON.parse(content)
                    }
                    // Update state
                    states.gameMode = root.toggled
                    
                    // Persist
                    writeStateProcess.command = ["sh", "-c", 
                        `printf '%s' '${JSON.stringify(states)}' > "${root.stateFile}"`]
                    writeStateProcess.running = true
                } catch (e) {
                    console.warn("GameModeService: Failed to update state:", e)
                }
            }
        }
        onExited: (code) => {
            // Create if missing
            if (code !== 0) {
                const states = { gameMode: root.toggled }
                writeStateProcess.command = ["sh", "-c", 
                    `printf '%s' '${JSON.stringify(states)}' > "${root.stateFile}"`]
                writeStateProcess.running = true
            }
        }
    }
    
    property Process readStateProcess: Process {
        running: false
        stdout: SplitParser {
            onRead: (data) => {
                try {
                    const content = data ? data.trim() : ""
                    if (content) {
                        const states = JSON.parse(content)
                        if (states.gameMode !== undefined) {
                            root.toggled = states.gameMode
                            
                            // Apply if enabled
                            if (root.toggled) {
                                enableProcess.command = ["axctl", "config", "apply", 
                                    "keyword animations:enabled 0; keyword decoration:shadow:enabled 0; keyword decoration:blur:enabled 0; keyword general:gaps_in 0; keyword general:gaps_out 0; keyword general:border_size 1; keyword decoration:rounding 0"]
                                enableProcess.running = true
                            }
                        }
                    }
                } catch (e) {
                    console.warn("GameModeService: Failed to parse states:", e)
                }
                root.initialized = true
            }
        }
        onExited: (code) => {
            // Mark initialized if missing
            if (code !== 0) {
                root.initialized = true
            }
        }
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

    function saveState() {
        readCurrentStateProcess.command = ["cat", stateFile]
        readCurrentStateProcess.running = true
    }

    function loadState() {
        readStateProcess.command = ["cat", stateFile]
        readStateProcess.running = true
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
