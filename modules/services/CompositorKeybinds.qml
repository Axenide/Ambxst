import QtQuick
import Quickshell.Io
import qs.config
import qs.modules.globals
import "../../config/KeybindActions.js" as KeybindActions

QtObject {
    id: root

    property Process compositorProcess: Process {}

    property var previousNothinglessBinds: ({})
    property var previousCustomBinds: []
    property bool hasPreviousBinds: false

    property Timer applyTimer: Timer {
        interval: 100
        repeat: false
        onTriggered: applyKeybindsInternal()
    }

    function applyKeybinds() {
        applyTimer.restart();
    }

    // Helper function to check if an action is compatible with the current layout
    function isActionCompatibleWithLayout(action) {
        // If no layouts specified or empty array, action works in all layouts
        if (!action.layouts || action.layouts.length === 0)
            return true;

        // Check if current layout is in the allowed list
        const currentLayout = GlobalStates.compositorLayout;
        return action.layouts.indexOf(currentLayout) !== -1;
    }

    function cloneKeybind(keybind) {
        return {
            modifiers: keybind.modifiers ? keybind.modifiers.slice() : [],
            key: keybind.key || ""
        };
    }

    function storePreviousBinds() {
        if (!Config.keybindsLoader.loaded)
            return;

        const nothingless = Config.keybindsLoader.adapter.nothingless;

        // Store nothingless core keybinds
        previousNothinglessBinds = {
            nothingless: {
                launcher: cloneKeybind(nothingless.launcher),
                dashboard: cloneKeybind(nothingless.dashboard),
                assistant: cloneKeybind(nothingless.assistant),
                clipboard: cloneKeybind(nothingless.clipboard),
                emoji: cloneKeybind(nothingless.emoji),
                notes: cloneKeybind(nothingless.notes),
                tmux: cloneKeybind(nothingless.tmux),
                wallpapers: cloneKeybind(nothingless.wallpapers)
            },
            system: {
                overview: cloneKeybind(nothingless.system.overview),
                powermenu: cloneKeybind(nothingless.system.powermenu),
                config: cloneKeybind(nothingless.system.config),
                lockscreen: cloneKeybind(nothingless.system.lockscreen),
                tools: cloneKeybind(nothingless.system.tools),
                screenshot: cloneKeybind(nothingless.system.screenshot),
                screenrecord: cloneKeybind(nothingless.system.screenrecord),
                lens: cloneKeybind(nothingless.system.lens),
                reload: nothingless.system.reload ? cloneKeybind(nothingless.system.reload) : null,
                quit: nothingless.system.quit ? cloneKeybind(nothingless.system.quit) : null
            }
        };

        // Store custom keybinds
        const customBinds = Config.keybindsLoader.adapter.custom;
        previousCustomBinds = [];
        if (customBinds && customBinds.length > 0) {
            for (let i = 0; i < customBinds.length; i++) {
                const bind = customBinds[i];
                if (bind.keys) {
                    let keys = [];
                    for (let k = 0; k < bind.keys.length; k++) {
                        keys.push(cloneKeybind(bind.keys[k]));
                    }
                    previousCustomBinds.push({
                        keys: keys
                    });
                } else {
                    previousCustomBinds.push(cloneKeybind(bind));
                }
            }
        }

        hasPreviousBinds = true;
    }

    // Build an unbind target object (modifiers + key only).
    function makeUnbindTarget(keybind) {
        return {
            modifiers: keybind.modifiers || [],
            key: keybind.key || ""
        };
    }

    // Build a structured bind object from a core keybind (has all fields inline).
    function resolveBindAction(action, fallback) {
        const resolved = KeybindActions.resolveAction(action || fallback);
        if (!resolved) return null;
        return {
            dispatcher: resolved.dispatcher || "",
            argument: resolved.argument || "",
            flags: resolved.flags || ""
        };
    }

    function makeBindFromCore(keybind) {
        const resolved = resolveBindAction(keybind.action, keybind);
        if (!resolved) return null;
        return {
            modifiers: keybind.modifiers || [],
            key: keybind.key || "",
            dispatcher: resolved.dispatcher,
            argument: resolved.argument,
            flags: resolved.flags,
            enabled: true
        };
    }

    // Build a structured bind object from a key + action pair (custom keybinds).
    function makeBindFromKeyAction(keyObj, action) {
        const resolved = resolveBindAction(action, action);
        if (!resolved) return null;
        return {
            modifiers: keyObj.modifiers || [],
            key: keyObj.key || "",
            dispatcher: resolved.dispatcher,
            argument: resolved.argument,
            flags: resolved.flags,
            enabled: true
        };
    }

    function applyKeybindsInternal() {
        // Ensure adapter is loaded.
        if (!Config.keybindsLoader.loaded) {
            console.log("CompositorKeybinds: Esperando que se cargue el adapter...");
            return;
        }

        // Wait for layout to be ready.
        if (!GlobalStates.compositorLayoutReady) {
            console.log("CompositorKeybinds: Esperando que se detecte el layout de AxctlService...");
            return;
        }

        console.log("CompositorKeybinds: Aplicando keybindings (layout: " + GlobalStates.compositorLayout + ")...");

        // Build structured payload.
        let payload = { binds: [], unbinds: [] };

        // First, unbind previous keybinds if we have them stored
        if (hasPreviousBinds) {
            // Unbind previous nothingless core keybinds
            if (previousNothinglessBinds.nothingless) {
                payload.unbinds.push(makeUnbindTarget(previousNothinglessBinds.nothingless.launcher));
                payload.unbinds.push(makeUnbindTarget(previousNothinglessBinds.nothingless.dashboard));
                payload.unbinds.push(makeUnbindTarget(previousNothinglessBinds.nothingless.assistant));
                payload.unbinds.push(makeUnbindTarget(previousNothinglessBinds.nothingless.clipboard));
                payload.unbinds.push(makeUnbindTarget(previousNothinglessBinds.nothingless.emoji));
                payload.unbinds.push(makeUnbindTarget(previousNothinglessBinds.nothingless.notes));
                payload.unbinds.push(makeUnbindTarget(previousNothinglessBinds.nothingless.tmux));
                payload.unbinds.push(makeUnbindTarget(previousNothinglessBinds.nothingless.wallpapers));
            }

            // Unbind previous nothingless system keybinds
            if (previousNothinglessBinds.system) {
                payload.unbinds.push(makeUnbindTarget(previousNothinglessBinds.system.overview));
                payload.unbinds.push(makeUnbindTarget(previousNothinglessBinds.system.powermenu));
                payload.unbinds.push(makeUnbindTarget(previousNothinglessBinds.system.config));
                payload.unbinds.push(makeUnbindTarget(previousNothinglessBinds.system.lockscreen));
                payload.unbinds.push(makeUnbindTarget(previousNothinglessBinds.system.tools));
                payload.unbinds.push(makeUnbindTarget(previousNothinglessBinds.system.screenshot));
                payload.unbinds.push(makeUnbindTarget(previousNothinglessBinds.system.screenrecord));
                payload.unbinds.push(makeUnbindTarget(previousNothinglessBinds.system.lens));
                if (previousNothinglessBinds.system.reload) payload.unbinds.push(makeUnbindTarget(previousNothinglessBinds.system.reload));
                if (previousNothinglessBinds.system.quit) payload.unbinds.push(makeUnbindTarget(previousNothinglessBinds.system.quit));
            }

            // Unbind previous custom keybinds
            for (let i = 0; i < previousCustomBinds.length; i++) {
                const prev = previousCustomBinds[i];
                if (prev.keys) {
                    for (let k = 0; k < prev.keys.length; k++) {
                        payload.unbinds.push(makeUnbindTarget(prev.keys[k]));
                    }
                } else {
                    payload.unbinds.push(makeUnbindTarget(prev));
                }
            }
        }

        // Process core keybinds.
        const nothingless = Config.keybindsLoader.adapter.nothingless;

        // Unbind current core keybinds (ensures clean state before rebinding)
        payload.unbinds.push(makeUnbindTarget(nothingless.launcher));
        payload.unbinds.push(makeUnbindTarget(nothingless.dashboard));
        payload.unbinds.push(makeUnbindTarget(nothingless.assistant));
        payload.unbinds.push(makeUnbindTarget(nothingless.clipboard));
        payload.unbinds.push(makeUnbindTarget(nothingless.emoji));
        payload.unbinds.push(makeUnbindTarget(nothingless.notes));
        payload.unbinds.push(makeUnbindTarget(nothingless.tmux));
        payload.unbinds.push(makeUnbindTarget(nothingless.wallpapers));

        // Bind current core keybinds
        [nothingless.launcher, nothingless.dashboard, nothingless.assistant, nothingless.clipboard, nothingless.emoji, nothingless.notes, nothingless.tmux, nothingless.wallpapers].forEach(bind => {
            const resolved = makeBindFromCore(bind);
            if (resolved) payload.binds.push(resolved);
        });

        // System keybinds
        const system = nothingless.system;

        // Unbind current system keybinds
        payload.unbinds.push(makeUnbindTarget(system.overview));
        payload.unbinds.push(makeUnbindTarget(system.powermenu));
        payload.unbinds.push(makeUnbindTarget(system.config));
        payload.unbinds.push(makeUnbindTarget(system.lockscreen));
        payload.unbinds.push(makeUnbindTarget(system.tools));
        payload.unbinds.push(makeUnbindTarget(system.screenshot));
        payload.unbinds.push(makeUnbindTarget(system.screenrecord));
        payload.unbinds.push(makeUnbindTarget(system.lens));
        if (system.reload) payload.unbinds.push(makeUnbindTarget(system.reload));
        if (system.quit) payload.unbinds.push(makeUnbindTarget(system.quit));
        if (system["toggle-metrics"]) payload.unbinds.push(makeUnbindTarget(system["toggle-metrics"]));

        // Bind current system keybinds
        [system.overview, system.powermenu, system.config, system.lockscreen, system.tools, system.screenshot, system.screenrecord, system.lens, system.reload, system.quit, system["toggle-metrics"]].forEach(bind => {
            if (!bind) return;
            const resolved = makeBindFromCore(bind);
            if (resolved) payload.binds.push(resolved);
        });

        // Process custom keybinds (keys[] and actions[] format).
        const customBinds = Config.keybindsLoader.adapter.custom;
        if (customBinds && customBinds.length > 0) {
            for (let i = 0; i < customBinds.length; i++) {
                const bind = customBinds[i];

                // Check if bind has the new format
                if (bind.keys && bind.actions) {
                    // Unbind all keys first (always unbind regardless of layout)
                    for (let k = 0; k < bind.keys.length; k++) {
                        payload.unbinds.push(makeUnbindTarget(bind.keys[k]));
                    }

                    // Only create binds if enabled
                    if (bind.enabled !== false) {
                        // For each key, bind only compatible actions
                        for (let k = 0; k < bind.keys.length; k++) {
                            for (let a = 0; a < bind.actions.length; a++) {
                                const action = bind.actions[a];
                                // Check if this action is compatible with the current layout
                                if (isActionCompatibleWithLayout(action)) {
                                    const resolved = makeBindFromKeyAction(bind.keys[k], action);
                                    if (resolved) payload.binds.push(resolved);
                                }
                            }
                        }
                    }
                } else {
                    // Fallback for old format (shouldn't happen after normalization)
                    payload.unbinds.push(makeUnbindTarget(bind));
                    if (bind.enabled !== false) {
                        const resolved = makeBindFromCore(bind);
                        if (resolved) payload.binds.push(resolved);
                    }
                }
            }
        }

        storePreviousBinds();

        // Send structured payload via axctl keybinds-batch.
        console.log("CompositorKeybinds: Enviando keybinds-batch (" + payload.unbinds.length + " unbinds, " + payload.binds.length + " binds)");
        compositorProcess.command = ["axctl", "config", "keybinds-batch", JSON.stringify(payload)];
        compositorProcess.running = true;
    }

    property Connections configConnections: Connections {
        target: Config.keybindsLoader
        function onFileChanged() {
            applyKeybinds();
        }
        function onLoaded() {
            applyKeybinds();
        }
        function onAdapterUpdated() {
            applyKeybinds();
        }
    }

    // Re-apply keybinds when layout changes
    property Connections globalStatesConnections: Connections {
        target: GlobalStates
        function onCompositorLayoutChanged() {
            console.log("CompositorKeybinds: Layout changed to " + GlobalStates.compositorLayout + ", reapplying keybindings...");
            applyKeybinds();
        }
        function onCompositorLayoutReadyChanged() {
            if (GlobalStates.compositorLayoutReady) {
                applyKeybinds();
            }
        }
    }

    property Connections compositorConnections: Connections {
        target: AxctlService
        function onRawEvent(event) {
            if (event && event.name === "configreloaded") {
                console.log("CompositorKeybinds: Hyprland config reloaded, reapplying keybinds...");
                applyKeybindsInternal();  // Direct — no 100ms timer delay
            }
        }
    }

    Component.onCompleted: {
        // Apply immediately if loader is ready.
        if (Config.keybindsLoader.loaded) {
            applyKeybinds();
        }
    }
}
