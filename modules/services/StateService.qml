pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Centralized state management service
 * Handles persistent state storage for all services
 */
Singleton {
    id: root

    property string stateFile: Quickshell.statePath("states.json")
    property var state: ({})
    property bool initialized: false

    signal stateLoaded()

    property Process writeProcess: Process {
        running: false
        stdout: SplitParser {}
    }

    property Process readProcess: Process {
        running: false
        stdout: SplitParser {
            onRead: data => {
                try {
                    const content = data ? data.trim() : "";
                    if (content) {
                        root.state = JSON.parse(content);
                    } else {
                        root.state = {};
                    }
                } catch (e) {
                    console.warn("StateService: Failed to parse state file:", e);
                    root.state = {};
                }
                root.initialized = true;
                root.stateLoaded();
            }
        }
        onExited: code => {
            if (code !== 0) {
                // File doesn't exist yet
                root.state = {};
                root.initialized = true;
                root.stateLoaded();
            }
        }
    }

    /**
     * Get a value from state
     * @param key - The state key
     * @param defaultValue - Default value if key doesn't exist
     * @return The stored value or defaultValue
     */
    function get(key, defaultValue) {
        if (root.state[key] !== undefined) {
            return root.state[key];
        }
        return defaultValue;
    }

    /**
     * Set a value in state and persist it
     * @param key - The state key
     * @param value - The value to store
     */
    function set(key, value) {
        if (!root.initialized) {
            console.warn("StateService: Attempted to set state before initialization");
            return;
        }

        root.state[key] = value;
        save();
    }

    /**
     * Save current state to disk
     */
    function save() {
        if (!root.initialized) {
            return;
        }

        try {
            const json = JSON.stringify(root.state);
            writeProcess.command = ["sh", "-c", `printf '%s' '${json}' > "${root.stateFile}"`];
            writeProcess.running = true;
        } catch (e) {
            console.warn("StateService: Failed to save state:", e);
        }
    }

    /**
     * Load state from disk
     */
    function load() {
        readProcess.command = ["cat", stateFile];
        readProcess.running = true;
    }

    /**
     * Clear all state
     */
    function clear() {
        root.state = {};
        save();
    }

    // Auto-load on creation
    Timer {
        interval: 50
        running: true
        repeat: false
        onTriggered: {
            if (!root.initialized) {
                root.load();
            }
        }
    }
}
