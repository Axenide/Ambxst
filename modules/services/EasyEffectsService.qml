pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // EasyEffects availability
    property bool available: false
    
    // Bypass: false = active, true = bypassed
    property bool bypassed: false
    
    // Available presets
    property var outputPresets: []
    property var inputPresets: []
    
    // Currently active presets
    property string activeOutputPreset: ""
    property string activeInputPreset: ""

    // True when the EasyEffects D-Bus service is actually registered. Every
    // `easyeffects` CLI invocation is a gapplication call that auto-activates
    // the GTK app if it's not running, so state queries are gated on this
    // (checked with a NameHasOwner busctl call, which never activates it).
    property bool isRunning: false

    // Toggle bypass state
    function toggleBypass() {
        if (!root.isRunning) {
            console.warn("EasyEffectsService: not running, ignoring bypass toggle");
            return;
        }
        bypassToggleProcess.command = ["easyeffects", "-b", bypassed ? "2" : "1"];
        bypassToggleProcess.running = true;
    }
    
    function setBypass(enable: bool) {
        if (!root.isRunning) {
            console.warn("EasyEffectsService: not running, ignoring bypass change");
            return;
        }
        bypassToggleProcess.command = ["easyeffects", "-b", enable ? "1" : "2"];
        bypassToggleProcess.running = true;
    }

    // Load preset (optimistic) — one process per load so rapid preset switching
    // can't clobber an in-flight load's preset name.
    Component {
        id: presetLoadComp
        Process {
            property string presetName: ""
            command: ["easyeffects", "-l", presetName]
            running: true
            onExited: {
                // Delay for preset application
                refreshDelayTimer.restart();
                destroy();
            }
        }
    }

    function loadOutputPreset(name: string) {
        root.activeOutputPreset = name;  // Optimistic
        presetLoadComp.createObject(root, { presetName: name });
    }

    function loadInputPreset(name: string) {
        root.activeInputPreset = name;  // Optimistic
        presetLoadComp.createObject(root, { presetName: name });
    }

    // Compatibility legacy function
    function loadPreset(name: string) {
        presetLoadComp.createObject(root, { presetName: name });
    }

    // Refresh all data
    function refresh() {
        root._refreshPresets = true;
        checkAvailableProcess.running = true;
    }

    // Open EasyEffects app
    function openApp() {
        Quickshell.execDetached(["easyeffects"]);
    }

    property bool _initialized: false

    function initialize() {
        if (_initialized) return;
        _initialized = true;
        checkAvailableProcess.running = true;
    }

    // Check EasyEffects availability
    Process {
        id: checkAvailableProcess
        command: ["which", "easyeffects"]
        running: false
        onExited: (exitCode, exitStatus) => {
            root.available = (exitCode === 0);
            if (root.available) {
                // Don't query state directly — that would auto-launch the app.
                // Gate everything behind the D-Bus registration check.
                runningCheckProcess.running = true;
            }
        }
    }

    // D-Bus registration check (NameHasOwner never activates the service).
    // State queries run only when it confirms the app is actually running.
    property bool _wasRunning: false
    property bool _refreshPresets: false

    Process {
        id: runningCheckProcess
        command: ["busctl", "--user", "--no-pager", "call", "org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "NameHasOwner", "s", "com.github.wwmm.easyeffects"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                root.isRunning = data.trim().toLowerCase().includes("true");
            }
        }
        onExited: (code) => {
            const wasRunning = root._wasRunning;
            root._wasRunning = root.isRunning;
            if (code === 0 && root.isRunning) {
                bypassStateProcess.running = true;
                activePresetsProcess.running = true;
                if (!wasRunning || root._refreshPresets) {
                    root._refreshPresets = false;
                    presetsProcess.running = true;
                }
            }
        }
    }

    // Get bypass state
    Process {
        id: bypassStateProcess
        command: ["easyeffects", "-b", "3"]
        running: false
        environment: ({ LANG: "C.UTF-8", LC_ALL: "C.UTF-8" })
        stdout: SplitParser {
            onRead: data => {
                const val = data.trim();
                root.bypassed = (val === "1");
            }
        }
    }

    // Toggle bypass
    Process {
        id: bypassToggleProcess
        running: false
        onExited: {
            bypassStateProcess.running = true;
        }
    }

    // Refresh delay after preset load
    property var refreshDelayTimer: Timer {
        id: refreshDelayTimer
        interval: 100
        repeat: false
        onTriggered: {
            activePresetsProcess.running = true;
            bypassStateProcess.running = true;
        }
    }

    // List presets
    Process {
        id: presetsProcess
        command: ["easyeffects", "-p"]
        running: false
        property string buffer: ""
        environment: ({ LANG: "C.UTF-8", LC_ALL: "C.UTF-8" })
        stdout: SplitParser {
            onRead: data => {
                presetsProcess.buffer += data + "\n";
            }
        }
        onExited: {
            const text = presetsProcess.buffer;
            presetsProcess.buffer = "";
            
            const lines = text.split("\n");
            let isOutput = false;
            let isInput = false;
            let outputList = [];
            let inputList = [];
            
            for (const line of lines) {
                const trimmed = line.trim();
                if (trimmed.toLowerCase().includes("output")) {
                    isOutput = true;
                    isInput = false;
                    // Check if presets follow colon
                    const parts = trimmed.split(":");
                    if (parts.length > 1 && parts[1].trim()) {
                        outputList = parts[1].trim().split(",").map(p => p.trim()).filter(p => p);
                    }
                } else if (trimmed.toLowerCase().includes("input")) {
                    isInput = true;
                    isOutput = false;
                    const parts = trimmed.split(":");
                    if (parts.length > 1 && parts[1].trim()) {
                        inputList = parts[1].trim().split(",").map(p => p.trim()).filter(p => p);
                    }
                } else if (trimmed && !trimmed.includes(":")) {
                    // Preset name on its own line
                    if (isOutput) outputList.push(trimmed);
                    else if (isInput) inputList.push(trimmed);
                }
            }
            
            root.outputPresets = outputList;
            root.inputPresets = inputList;
        }
    }

    // Get active presets
    Process {
        id: activePresetsProcess
        command: ["easyeffects", "-a"]
        running: false
        property string buffer: ""
        environment: ({ LANG: "C.UTF-8", LC_ALL: "C.UTF-8" })
        stdout: SplitParser {
            onRead: data => {
                activePresetsProcess.buffer += data + "\n";
            }
        }
        onExited: {
            const text = activePresetsProcess.buffer;
            activePresetsProcess.buffer = "";
            
            const lines = text.split("\n");
            for (const line of lines) {
                const trimmed = line.trim().toLowerCase();
                if (trimmed.includes("output")) {
                    const parts = line.split(":");
                    if (parts.length > 1) {
                        root.activeOutputPreset = parts[1].trim();
                    }
                } else if (trimmed.includes("input")) {
                    const parts = line.split(":");
                    if (parts.length > 1) {
                        root.activeInputPreset = parts[1].trim();
                    }
                }
            }
        }
    }

    // Periodically check state — but only query bypass/active presets if the
    // D-Bus service is registered, so the poll can never auto-launch the GTK
    // app (every `easyeffects` invocation is a gapplication activation).
    property var pollTimer: Timer {
        interval: 5000
        running: root.available && !SuspendManager.isSuspending
        repeat: true
        onTriggered: {
            runningCheckProcess.running = true;
        }
    }
}
