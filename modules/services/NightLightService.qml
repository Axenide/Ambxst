pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool active: false
    property bool initialized: false
    
    property string stateFile: Quickshell.statePath("states.json")

    property Process hyprsunsetProcess: Process {
        command: ["hyprsunset", "-t", "4000"]
        running: false
        stdout: SplitParser {
            onRead: (data) => {
                // hyprsunset output cuando está corriendo
                if (data) {
                    root.active = true
                }
            }
        }
        onStarted: {
            root.active = true
            root.saveState()
        }
        onExited: (code) => {
            root.active = false
            root.saveState()
        }
    }
    
    property Process killProcess: Process {
        command: ["pkill", "hyprsunset"]
        running: false
        onExited: (code) => {
            root.active = false
            root.saveState()
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
                    states.nightLight = root.active
                    
                    // Write back
                    writeStateProcess.command = ["sh", "-c", 
                        `printf '%s' '${JSON.stringify(states)}' > "${root.stateFile}"`]
                    writeStateProcess.running = true
                } catch (e) {
                    console.warn("NightLightService: Failed to update state:", e)
                }
            }
        }
        onExited: (code) => {
            // If file doesn't exist, create new with our state
            if (code !== 0) {
                const states = { nightLight: root.active }
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
                        if (states.nightLight !== undefined) {
                            root.active = states.nightLight
                            root.syncState()
                        }
                    }
                } catch (e) {
                    console.warn("NightLightService: Failed to parse states:", e)
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
    
    property Process checkRunningProcess: Process {
        command: ["pgrep", "hyprsunset"]
        running: false
        onExited: (code) => {
            const isRunning = code === 0
            
            // If state says active but not running, start it
            if (root.active && !isRunning) {
                console.log("NightLightService: Starting hyprsunset (state was active but not running)")
                hyprsunsetProcess.running = true
            } 
            // If state says inactive but running, kill it
            else if (!root.active && isRunning) {
                console.log("NightLightService: Stopping hyprsunset (state was inactive but running)")
                killProcess.running = true
            }
        }
    }

    function toggle() {
        if (active) {
            killProcess.running = true
        } else {
            hyprsunsetProcess.running = true
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
    
    function syncState() {
        checkRunningProcess.running = true
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
