pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * MonitorsWriter - Persists monitor configuration to Hyprland config files
 *
 * Follows the same approach as nwg-displays:
 *   - Writes ~/.config/hypr/monitors.conf  (Hyprland .conf format)
 *   - Writes ~/.config/hypr/monitors.lua    (Hyprland V2 Lua format)
 *   - Creates backups before overwriting
 *   - Applies changes live via hyprctl dispatch
 *
 * Delegates to scripts/monitors_writer.py for the heavy lifting.
 */
Singleton {
    id: root

    readonly property string scriptPath: Quickshell.thisFile.parent + "/../scripts/monitors_writer.py"
    readonly property string hyprConfigDir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/hypr"

    property bool isSyncing: false
    property var lastError: null

    signal syncFinished(bool success, string message)
    signal syncStarted()
    property Process reloadProcess: Process {
        command: ["hyprctl", "reload"]
        running: false
        onExited: exitCode => {
            console.log("MonitorsWriter: hyprctl reload " + (exitCode === 0 ? "OK" : "exit " + exitCode));
        }
    }

    /**
     * Build a snapshot of current monitor data from AxctlService + Quickshell.screens
     * Returns a JSON-serializable array of monitor objects.
     */
    function buildMonitorList() {
        var list = [];
        var screens = Quickshell.screens;
        if (!screens) return list;

        var axMons = AxctlService.monitors.values || [];

        for (var i = 0; i < screens.length; i++) {
            var s = screens[i];
            var axctl = null;
            for (var j = 0; j < axMons.length; j++) {
                if (axMons[j].name === s.name) { axctl = axMons[j]; break; }
            }

            list.push({
                name: s.name || ("Monitor-" + (i + 1)),
                width: axctl ? (axctl.width || s.width || 1920) : (s.width || 1920),
                height: axctl ? (axctl.height || s.height || 1080) : (s.height || 1080),
                x: s.x || 0,
                y: s.y || 0,
                scale: axctl ? (axctl.scale || 1.0) : 1.0,
                refreshRate: axctl ? (axctl.refreshRate || 60) : 60,
                transform: axctl ? (axctl.transform || 0) : 0,
                enabled: true,
                bitdepth: axctl ? (axctl.bitdepth || 10) : 10,
                vrr: axctl ? (axctl.vrr || 0) : 0,
                mirror: "",
                description: axctl ? (axctl.description || s.name || "") : (s.name || "")
            });
        }

        return list;
    }

    /**
     * Sync current monitor configuration to disk + apply live
     * Reads current monitor state from hyprctl (via the Python script)
     */
    function sync() {
        if (root.isSyncing) return;
        root.isSyncing = true;
        root.lastError = null;
        root.syncStarted();
        syncProcess.running = true;
    }

    /**
     * Sync with explicit monitor data array (used when positions change via drag)
     * @param {Array} monitorData - Array of monitor objects
     */
    function syncWithData(monitorData) {
        if (root.isSyncing || !monitorData || monitorData.length === 0) return;
        root.isSyncing = true;
        root.lastError = null;
        root.syncStarted();

        var jsonStr = JSON.stringify(monitorData);
        syncDataProcess.command = [
            "python3", root.scriptPath, "sync",
            "--data", jsonStr
        ];
        syncDataProcess.running = true;
    }

    /**
     * Apply monitor changes live without writing to disk
     * @param {string} dispatchCommand - hyprctl dispatch command (e.g. "monitor DP-3,3440x1440@159.96Hz,0x0,1.0")
     */
    function dispatchAndSync(dispatchCommand) {
        // Apply live
        AxctlService.dispatch(dispatchCommand);

        // Debounced sync to disk
        debounceTimer.restart();
    }

    Timer {
        id: debounceTimer
        interval: 2000  // 2 second debounce
        repeat: false
        onTriggered: root.sync()
    }

    // ── Processes ──

    property Process syncProcess: Process {
        command: ["python3", root.scriptPath, "sync"]
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        running: false
        onExited: exitCode => {
            root.isSyncing = false;
            if (exitCode === 0) {
                root.lastError = null;
                var output = (syncProcess.stdout ? syncProcess.stdout.text : "") +
                             (syncProcess.stderr ? syncProcess.stderr.text : "");
                console.log("MonitorsWriter: " + (output.trim() || "sync completed"));
                root.syncFinished(true, output.trim());
            
            // Refresh TOML config after monitor sync
            try {
                if (typeof CompositorTomlWriter !== "undefined") {
                    CompositorTomlWriter.writeTomlFile();
                }
            } catch (e) { /* CompositorTomlWriter may not be loaded yet */ }
} else {
                root.lastError = (syncProcess.stderr ? syncProcess.stderr.text : "exit code " + exitCode);
                console.error("MonitorsWriter: sync failed:", root.lastError);
                root.syncFinished(false, "Sync failed: " + root.lastError);
            }
        }
    }

    property Process syncDataProcess: Process {
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        running: false
        onExited: exitCode => {
            root.isSyncing = false;
            if (exitCode === 0) {
                root.lastError = null;
                var output = (syncDataProcess.stdout ? syncDataProcess.stdout.text : "") +
                             (syncDataProcess.stderr ? syncDataProcess.stderr.text : "");
                console.log("MonitorsWriter: sync with data: " + (output.trim() || "OK"));
                
            // Apply via hyprctl reload
            reloadProcess.running = true;

                root.syncFinished(true, output.trim());
            
            // Refresh TOML config after monitor sync
            try {
                if (typeof CompositorTomlWriter !== "undefined") {
                    CompositorTomlWriter.writeTomlFile();
                }
            } catch (e) { /* CompositorTomlWriter may not be loaded yet */ }
} else {
                root.lastError = (syncDataProcess.stderr ? syncDataProcess.stderr.text : "exit code " + exitCode);
                console.error("MonitorsWriter: sync with data failed:", root.lastError);
                root.syncFinished(false, "Failed: " + root.lastError);
            }
        }
    }
}
