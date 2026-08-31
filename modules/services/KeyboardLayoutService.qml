pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Singleton {
    id: root

    // Current active layout short name (e.g. "us", "ru")
    property string currentLayout: ""
    // Current active keymap display name (e.g. "English (US)", "Russian")
    property string currentKeymap: ""
    // Available layouts parsed from hyprctl
    property var availableLayouts: []
    // Current layout index
    property int currentIndex: 0
    // Main keyboard name
    property string mainKeyboard: ""

    // Dynamic map of layout code → display name, built as layouts are activated
    property var keymapNames: ({})
    property int initAttempts: 0

    // Short display code for the bar button
    readonly property string displayCode: {
        if (!currentLayout) return "??";
        return currentLayout.toUpperCase().substring(0, 2);
    }

    function switchLayout() {
        if (!mainKeyboard) return;
        switchProcess.command = ["hyprctl", "switchxkblayout", mainKeyboard, "next"];
        switchProcess.running = true;
    }

    function setLayout(index) {
        if (!mainKeyboard) return;
        switchProcess.command = ["hyprctl", "switchxkblayout", mainKeyboard, String(index)];
        switchProcess.running = true;
    }

    function getDisplayName(code) {
        if (root.keymapNames[code])
            return root.keymapNames[code];
        return code.toUpperCase();
    }

    // Parse devices JSON and apply state
    function applyDevicesState(jsonStr) {
        try {
            const devices = JSON.parse(jsonStr);
            const keyboards = devices.keyboards || [];

            let kb = null;
            if (root.mainKeyboard)
                kb = keyboards.find(k => k.name === root.mainKeyboard);
            if (!kb) kb = keyboards.find(k => k.main === true);
            if (!kb) kb = keyboards.find(k => k.layout && k.layout.length > 0);
            if (!kb) return;

            root.mainKeyboard = kb.name;
            root.availableLayouts = kb.layout.split(",").map(l => l.trim());
            root.currentIndex = kb.active_layout_index || 0;
            root.currentLayout = root.availableLayouts[root.currentIndex] || "";
            root.currentKeymap = kb.active_keymap || "";

            // Override with Hyprland's active keymap name (more accurate)
            if (root.currentLayout && root.currentKeymap && root.keymapNames[root.currentLayout] !== root.currentKeymap) {
                let updated = Object.assign({}, root.keymapNames);
                updated[root.currentLayout] = root.currentKeymap;
                root.keymapNames = updated;
            }
        } catch (e) {
            console.error("KeyboardLayoutService: parse error:", e);
        }
    }

    // Load XKB layout display names from system database
    Process {
        id: xkbNamesProcess
        command: ["sh", "-c", "awk '/^! layout$/,/^! /{if(/^  [a-z]/ && !/^! /)print}' /usr/share/X11/xkb/rules/evdev.lst"]
        running: true
        property string buffer: ""

        stdout: SplitParser {
            splitMarker: ""
            onRead: (data) => {
                xkbNamesProcess.buffer += data;
            }
        }

        onExited: (code) => {
            if (code === 0) {
                let names = {};
                const lines = xkbNamesProcess.buffer.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const match = lines[i].match(/^\s+(\S+)\s+(.+)$/);
                    if (match && !names[match[1]]) {
                        names[match[1]] = match[2].trim();
                    }
                }
                root.keymapNames = names;
            }
        }
    }

    // Fetch initial state
    Process {
        id: initProcess
        command: ["hyprctl", "devices", "-j"]
        running: true
        property string buffer: ""

        stdout: SplitParser {
            splitMarker: ""
            onRead: (data) => {
                initProcess.buffer += data;
            }
        }

        onExited: (code) => {
            if (code === 0 && initProcess.buffer !== "") {
                root.applyDevicesState(initProcess.buffer);
                root.initAttempts = 0;
            } else if (root.initAttempts < 15) {
                // Hyprland IPC is not up yet. Back off and retry rather than
                // leaving the indicator stuck for the rest of the session.
                root.initAttempts++;
                initRetry.restart();
            }
        }
    }

    Timer {
        id: initRetry
        interval: Math.min(1000 * root.initAttempts, 10000)
        onTriggered: {
            initProcess.buffer = "";
            initProcess.running = true;
        }
    }

    // Quickshell owns the Hyprland event socket: it resolves the path, connects
    // and reconnects. The previous implementation used an external socket
    // client against a path built once from HYPRLAND_INSTANCE_SIGNATURE. When
    // quickshell started before Hyprland exported that variable, the malformed
    // path was retried forever.
    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name !== "activelayout")
                return;

            // data is "keyboard_name,layout_name"
            const commaIdx = event.data.lastIndexOf(",");
            if (commaIdx === -1)
                return;

            root.currentKeymap = event.data.substring(commaIdx + 1).trim();

            // Re-query devices for the authoritative active index.
            refreshProcess.buffer = "";
            refreshProcess.running = true;
        }
    }

    // Refresh process to update state after layout switch
    Process {
        id: refreshProcess
        command: ["hyprctl", "devices", "-j"]
        property string buffer: ""

        stdout: SplitParser {
            splitMarker: ""
            onRead: (data) => {
                refreshProcess.buffer += data;
            }
        }

        onStarted: {
            refreshProcess.buffer = "";
        }

        onExited: (code) => {
            if (code === 0) root.applyDevicesState(refreshProcess.buffer);
        }
    }

    // Poll for XKB-level layout changes (grp:alt_shift_toggle doesn't emit socket events)
    Timer {
        id: pollTimer
        interval: 500
        running: true
        repeat: true
        onTriggered: {
            if (!refreshProcess.running) {
                refreshProcess.buffer = "";
                refreshProcess.running = true;
            }
        }
    }

    // Switch process
    Process {
        id: switchProcess
        // Layout update comes via socket event + poll
    }

    Component.onDestruction: {
        pollTimer.running = false;
    }
}
