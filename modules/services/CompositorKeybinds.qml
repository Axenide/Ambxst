import QtQuick
import Quickshell.Io
import qs.config
import qs.modules.globals
import "../../config/KeybindActions.js" as KeybindActions

QtObject {
    id: root

    property Process compositorProcess: Process {}

    property var previousAmbxstPlusBinds: ({})
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

        const ambxstPlus = Config.keybindsLoader.adapter.ambxstPlus;

        // Store ambxst+ core keybinds
        previousAmbxstPlusBinds = {
            ambxstPlus: {
                launcher: cloneKeybind(ambxstPlus.launcher),
                dashboard: cloneKeybind(ambxstPlus.dashboard),
                assistant: cloneKeybind(ambxstPlus.assistant),
                clipboard: cloneKeybind(ambxstPlus.clipboard),
                emoji: cloneKeybind(ambxstPlus.emoji),
                notes: cloneKeybind(ambxstPlus.notes),
                tmux: cloneKeybind(ambxstPlus.tmux),
                wallpapers: cloneKeybind(ambxstPlus.wallpapers)
            },
            system: {
                overview: cloneKeybind(ambxstPlus.system.overview),
                powermenu: cloneKeybind(ambxstPlus.system.powermenu),
                config: cloneKeybind(ambxstPlus.system.config),
                lockscreen: cloneKeybind(ambxstPlus.system.lockscreen),
                tools: cloneKeybind(ambxstPlus.system.tools),
                screenshot: cloneKeybind(ambxstPlus.system.screenshot),
                screenrecord: cloneKeybind(ambxstPlus.system.screenrecord),
                lens: cloneKeybind(ambxstPlus.system.lens),
                reload: ambxstPlus.system.reload ? cloneKeybind(ambxstPlus.system.reload) : null,
                quit: ambxstPlus.system.quit ? cloneKeybind(ambxstPlus.system.quit) : null
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

    function isModifierKeyName(key) {
        return key === "Super_L" || key === "Super_R"
            || key === "Control_L" || key === "Control_R"
            || key === "Alt_L" || key === "Alt_R"
            || key === "Shift_L" || key === "Shift_R"
            || key === "Meta" || key === "Hyper_L" || key === "Hyper_R";
    }

    function ensureReleaseFlag(flags, key) {
        if (!isModifierKeyName(key)) return flags;
        var f = String(flags || "");
        if (f.indexOf("r") === -1) f += "r";
        return f;
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
            flags: ensureReleaseFlag(resolved.flags, keybind.key),
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
            flags: ensureReleaseFlag(resolved.flags, keyObj.key),
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
            // Unbind previous ambxst+ core keybinds
            if (previousAmbxstPlusBinds.ambxstPlus) {
                payload.unbinds.push(makeUnbindTarget(previousAmbxstPlusBinds.ambxstPlus.launcher));
                payload.unbinds.push(makeUnbindTarget(previousAmbxstPlusBinds.ambxstPlus.dashboard));
                payload.unbinds.push(makeUnbindTarget(previousAmbxstPlusBinds.ambxstPlus.assistant));
                payload.unbinds.push(makeUnbindTarget(previousAmbxstPlusBinds.ambxstPlus.clipboard));
                payload.unbinds.push(makeUnbindTarget(previousAmbxstPlusBinds.ambxstPlus.emoji));
                payload.unbinds.push(makeUnbindTarget(previousAmbxstPlusBinds.ambxstPlus.notes));
                payload.unbinds.push(makeUnbindTarget(previousAmbxstPlusBinds.ambxstPlus.tmux));
                payload.unbinds.push(makeUnbindTarget(previousAmbxstPlusBinds.ambxstPlus.wallpapers));
            }

            // Unbind previous ambxst+ system keybinds
            if (previousAmbxstPlusBinds.system) {
                payload.unbinds.push(makeUnbindTarget(previousAmbxstPlusBinds.system.overview));
                payload.unbinds.push(makeUnbindTarget(previousAmbxstPlusBinds.system.powermenu));
                payload.unbinds.push(makeUnbindTarget(previousAmbxstPlusBinds.system.config));
                payload.unbinds.push(makeUnbindTarget(previousAmbxstPlusBinds.system.lockscreen));
                payload.unbinds.push(makeUnbindTarget(previousAmbxstPlusBinds.system.tools));
                payload.unbinds.push(makeUnbindTarget(previousAmbxstPlusBinds.system.screenshot));
                payload.unbinds.push(makeUnbindTarget(previousAmbxstPlusBinds.system.screenrecord));
                payload.unbinds.push(makeUnbindTarget(previousAmbxstPlusBinds.system.lens));
                if (previousAmbxstPlusBinds.system.reload) payload.unbinds.push(makeUnbindTarget(previousAmbxstPlusBinds.system.reload));
                if (previousAmbxstPlusBinds.system.quit) payload.unbinds.push(makeUnbindTarget(previousAmbxstPlusBinds.system.quit));
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
        const ambxstPlus = Config.keybindsLoader.adapter.ambxstPlus;

        // Unbind current core keybinds (ensures clean state before rebinding)
        payload.unbinds.push(makeUnbindTarget(ambxstPlus.launcher));
        payload.unbinds.push(makeUnbindTarget(ambxstPlus.dashboard));
        payload.unbinds.push(makeUnbindTarget(ambxstPlus.assistant));
        payload.unbinds.push(makeUnbindTarget(ambxstPlus.clipboard));
        payload.unbinds.push(makeUnbindTarget(ambxstPlus.emoji));
        payload.unbinds.push(makeUnbindTarget(ambxstPlus.notes));
        payload.unbinds.push(makeUnbindTarget(ambxstPlus.tmux));
        payload.unbinds.push(makeUnbindTarget(ambxstPlus.wallpapers));

        // Bind current core keybinds
        [ambxstPlus.launcher, ambxstPlus.dashboard, ambxstPlus.assistant, ambxstPlus.clipboard, ambxstPlus.emoji, ambxstPlus.notes, ambxstPlus.tmux, ambxstPlus.wallpapers].forEach(bind => {
            const resolved = makeBindFromCore(bind);
            if (resolved) payload.binds.push(resolved);
        });

        // System keybinds
        const system = ambxstPlus.system;

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

        // Bind current system keybinds
        [system.overview, system.powermenu, system.config, system.lockscreen, system.tools, system.screenshot, system.screenrecord, system.lens, system.reload, system.quit].forEach(bind => {
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

    // Hyprland config reloads wipe runtime-applied binds; the axctl daemon
    // regenerates config on toml changes and broadcasts Event.ConfigReloaded.
    property Connections compositorConnections: Connections {
        target: AxctlService
        function onRawEvent(event) {
            if (event.name === "configreloaded") {
                console.log("CompositorKeybinds: Detectado configreloaded, reaplicando keybindings...");
                applyKeybinds();
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
