pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool inhibit: false
    property bool initialized: false
    
    property string stateFile: Quickshell.statePath("states.json")
    
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
                    states.caffeine = root.inhibit
                    
                    // Write back
                    writeStateProcess.command = ["sh", "-c", 
                        `printf '%s' '${JSON.stringify(states)}' > "${root.stateFile}"`]
                    writeStateProcess.running = true
                } catch (e) {
                    console.warn("CaffeineService: Failed to update state:", e)
                }
            }
        }
        onExited: (code) => {
            // If file doesn't exist, create new with our state
            if (code !== 0) {
                const states = { caffeine: root.inhibit }
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
                        if (states.caffeine !== undefined) {
                            root.inhibit = states.caffeine
                        }
                    }
                } catch (e) {
                    console.warn("CaffeineService: Failed to parse states:", e)
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

    function toggleInhibit() {
        inhibit = !inhibit
        saveState()
        
        // TODO: Implementar funcionalidad real aquí
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
