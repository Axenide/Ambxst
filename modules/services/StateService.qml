pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Centralized state management service
 * Handles persistent state storage for all services.
 * Writes are owned by the Go daemon (config.stateSet under lock), which
 * eliminates the race with GameModeService writing the same states.json.
 */
Singleton {
    id: root

    property string stateFile: Quickshell.statePath("states.json")
    property var state: ({})
    property bool initialized: false

    signal stateLoaded()

    /**
     * Get a value from state
     * @param key - The state key
     * @param defaultValue - Default value if key doesn't exist
     * @return The stored value or defaultValue
     */
    function get(key, defaultValue) {
        if (key === undefined || key === null) return defaultValue;
        if (root.state[key] !== undefined) {
            return root.state[key];
        }
        return defaultValue;
    }

    /**
     * Set a value in state and persist it via the daemon (locked RMW).
     * @param key - The state key
     * @param value - The value to store
     */
    function set(key, value) {
        if (!root.initialized) {
            console.warn("StateService: Attempted to set state before initialization");
            return;
        }
        root.state[key] = value;
        BackendService.call("config.stateSet", {key: key, value: value});
    }

    /**
     * Save current in-memory state to disk (whole-document merge).
     */
    function save() {
        if (!root.initialized) return;
        BackendService.call("config.statesSet", {data: root.state});
    }

    /**
     * Load state from disk via the daemon.
     */
    function load() {
        BackendService.call("config.statesGet", {}, (result, error) => {
            if (error) {
                console.warn("StateService: Failed to load state:", error);
                root.state = {};
            } else if (result && typeof result === "object") {
                root.state = result;
            } else {
                root.state = {};
            }
            if (!root.initialized) {
                root.initialized = true;
                root.stateLoaded();
            }
        });
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
