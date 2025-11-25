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
                    // Update only our state
                    states.gameMode = root.toggled
                    
                    // Write back
                    writeStateProcess.command = ["sh", "-c", 
                        `printf '%s' '${JSON.stringify(states)}' > "${root.stateFile}"`]
                    writeStateProcess.running = true
                } catch (e) {
                    console.warn("GameModeService: Failed to update state:", e)
                }
            }
        }
        onExited: (code) => {
            // If file doesn't exist, create new with our state
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
                            
                            // If state says it should be enabled, apply it
                            if (root.toggled) {
                                enableProcess.command = ["hyprctl", "--batch", 
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
            // If file doesn't exist, just mark as initialized
            if (code !== 0) {
                root.initialized = true
            }
        }
    }

    function toggle() {
        if (toggled) {
            disableProcess.command = ["hyprctl", "reload"]
            disableProcess.running = true
        } else {
            enableProcess.command = ["hyprctl", "--batch", 
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

    // Auto-initialize on creation
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
