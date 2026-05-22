.pragma library

function clone(obj) {
    return JSON.parse(JSON.stringify(obj || {}));
}

function formatOffset(value) {
    if (value === undefined || value === null || value === "") {
        return "0";
    }
    const raw = String(value).trim();
    if (raw.startsWith("+") || raw.startsWith("-")) {
        return raw;
    }
    const num = parseInt(raw, 10);
    if (isNaN(num)) {
        return raw;
    }
    return num >= 0 ? "+" + num : String(num);
}

function directionToLetter(direction) {
    const dir = String(direction || "").toLowerCase();
    if (dir === "up" || dir === "u") return "u";
    if (dir === "down" || dir === "d") return "d";
    if (dir === "left" || dir === "l") return "l";
    if (dir === "right" || dir === "r") return "r";
    return "";
}

var ACTION_CATALOG = [
    { id: "ambxst.launcher", label: "Open Launcher", category: "Ambxst", dispatcher: "exec", argument: "ambxst run launcher", flags: "r" },
    { id: "ambxst.dashboard", label: "Open Dashboard", category: "Ambxst", dispatcher: "exec", argument: "ambxst run dashboard" },
    { id: "ambxst.assistant", label: "Open Assistant", category: "Ambxst", dispatcher: "exec", argument: "ambxst run assistant" },
    { id: "ambxst.clipboard", label: "Open Clipboard", category: "Ambxst", dispatcher: "exec", argument: "ambxst run clipboard" },
    { id: "ambxst.emoji", label: "Open Emoji", category: "Ambxst", dispatcher: "exec", argument: "ambxst run emoji" },
    { id: "ambxst.notes", label: "Open Notes", category: "Ambxst", dispatcher: "exec", argument: "ambxst run notes" },
    { id: "ambxst.tmux", label: "Open Tmux", category: "Ambxst", dispatcher: "exec", argument: "ambxst run tmux" },
    { id: "ambxst.wallpapers", label: "Open Wallpapers", category: "Ambxst", dispatcher: "exec", argument: "ambxst run wallpapers" },
    { id: "ambxst.config", label: "Open Settings", category: "Ambxst", dispatcher: "exec", argument: "ambxst run config" },
    { id: "ambxst.overview", label: "Open Overview", category: "Ambxst", dispatcher: "exec", argument: "ambxst run overview" },
    { id: "ambxst.powermenu", label: "Open Power Menu", category: "Ambxst", dispatcher: "exec", argument: "ambxst run powermenu" },
    { id: "ambxst.tools", label: "Open Tools", category: "Ambxst", dispatcher: "exec", argument: "ambxst run tools" },
    { id: "ambxst.screenshot", label: "Take Screenshot", category: "Ambxst", dispatcher: "exec", argument: "ambxst run screenshot" },
    { id: "ambxst.screenrecord", label: "Screen Record", category: "Ambxst", dispatcher: "exec", argument: "ambxst run screenrecord" },
    { id: "ambxst.lens", label: "Open Lens", category: "Ambxst", dispatcher: "exec", argument: "ambxst run lens" },
    { id: "ambxst.reload", label: "Reload Ambxst", category: "Ambxst", dispatcher: "exec", argument: "ambxst reload" },
    { id: "ambxst.quit", label: "Quit Ambxst", category: "Ambxst", dispatcher: "exec", argument: "ambxst quit" },

    { id: "window.close", label: "Close Window", category: "Window", dispatcher: "killactive", argument: "" },
    { id: "window.focus", label: "Focus Window", category: "Window", dispatcher: "movefocus", args: [{ key: "direction", label: "Direction", placeholder: "up/down/left/right", defaultValue: "up" }], argumentBuilder: function (args) {
        return directionToLetter(args.direction);
    } },
    { id: "window.move", label: "Move Window", category: "Window", dispatcher: "movewindow", args: [{ key: "direction", label: "Direction", placeholder: "up/down/left/right", defaultValue: "left" }], argumentBuilder: function (args) {
        return directionToLetter(args.direction);
    } },
    { id: "window.drag", label: "Drag Window", category: "Window", dispatcher: "movewindow", argument: "", flags: "m" },
    { id: "window.resize-drag", label: "Resize Window (Drag)", category: "Window", dispatcher: "resizewindow", argument: "", flags: "m" },
    { id: "window.resize", label: "Resize Window", category: "Window", dispatcher: "resizeactive", args: [{ key: "delta", label: "Delta", placeholder: "50 0", defaultValue: "50 0" }], argumentBuilder: function (args) {
        return String(args.delta || "").trim();
    } },

    { id: "workspace.switch", label: "Switch Workspace", category: "Workspace", dispatcher: "workspace", args: [{ key: "index", label: "Workspace", placeholder: "1", defaultValue: "1" }], argumentBuilder: function (args) {
        return String(args.index || "").trim();
    } },
    { id: "workspace.switch-relative", label: "Switch Workspace (Relative)", category: "Workspace", dispatcher: "workspace", args: [{ key: "offset", label: "Offset", placeholder: "+1 / -1", defaultValue: "+1" }], argumentBuilder: function (args) {
        return formatOffset(args.offset);
    } },
    { id: "workspace.switch-occupied", label: "Switch Occupied Workspace", category: "Workspace", dispatcher: "workspace", args: [{ key: "offset", label: "Offset", placeholder: "+1 / -1", defaultValue: "+1" }], argumentBuilder: function (args) {
        const offset = formatOffset(args.offset);
        return "e" + offset;
    } },
    { id: "workspace.move-window", label: "Move Window to Workspace", category: "Workspace", dispatcher: "movetoworkspace", args: [{ key: "index", label: "Workspace", placeholder: "1", defaultValue: "1" }], argumentBuilder: function (args) {
        return String(args.index || "").trim();
    } },
    { id: "workspace.move-window-silent", label: "Move Window to Workspace (Silent)", category: "Workspace", dispatcher: "movetoworkspacesilent", args: [{ key: "index", label: "Workspace", placeholder: "1", defaultValue: "1" }], argumentBuilder: function (args) {
        return String(args.index || "").trim();
    } },
    { id: "workspace.toggle-special", label: "Toggle Special Workspace", category: "Workspace", dispatcher: "togglespecialworkspace", argument: "" },
    { id: "workspace.move-window-special", label: "Move Window to Special Workspace", category: "Workspace", dispatcher: "movetoworkspace", argument: "special" },
    { id: "workspace.move-window-special-silent", label: "Move Window to Special Workspace (Silent)", category: "Workspace", dispatcher: "movetoworkspacesilent", argument: "special" },

    { id: "scrolling.focus", label: "Focus", category: "Window", dispatcher: "movefocus", args: [{ key: "direction", label: "Direction", placeholder: "up/down/left/right", defaultValue: "up" }], argumentBuilder: function (args) {
        return directionToLetter(args.direction);
    } },
    { id: "scrolling.move-window", label: "Move Window", category: "Window", dispatcher: "movewindow", args: [{ key: "direction", label: "Direction", placeholder: "up/down/left/right", defaultValue: "left" }], argumentBuilder: function (args) {
        return directionToLetter(args.direction);
    } },
    { id: "scrolling.resize-column", label: "Resize Column", category: "Scrolling Layout", dispatcher: "layoutmsg", args: [{ key: "delta", label: "Delta", placeholder: "+0.1 / -0.1", defaultValue: "+0.1" }], argumentBuilder: function (args) {
        return "colresize " + String(args.delta || "").trim();
    } },
    { id: "scrolling.promote", label: "Promote Column", category: "Scrolling Layout", dispatcher: "layoutmsg", argument: "promote" },
    { id: "scrolling.toggle-fit", label: "Toggle Fit", category: "Scrolling Layout", dispatcher: "layoutmsg", argument: "togglefit" },
    { id: "scrolling.toggle-full-column", label: "Toggle Full Column", category: "Scrolling Layout", dispatcher: "layoutmsg", argument: "colresize +conf" },
    { id: "scrolling.swap-column", label: "Swap Column", category: "Scrolling Layout", dispatcher: "layoutmsg", args: [{ key: "direction", label: "Direction", placeholder: "left/right", defaultValue: "left" }], argumentBuilder: function (args) {
        return "swapcol " + directionToLetter(args.direction);
    } },
    { id: "scrolling.move-column-workspace", label: "Move Column to Workspace", category: "Scrolling Layout", dispatcher: "layoutmsg", args: [{ key: "index", label: "Workspace", placeholder: "1", defaultValue: "1" }], argumentBuilder: function (args) {
        return "movecoltoworkspace " + String(args.index || "").trim();
    } },

    { id: "media.play-pause", label: "Play/Pause", category: "Media", dispatcher: "exec", argument: "playerctl play-pause" },
    { id: "media.play-pause-locked", label: "Play/Pause (Locked)", category: "Media", dispatcher: "exec", argument: "playerctl play-pause", flags: "l" },
    { id: "media.prev", label: "Previous Track", category: "Media", dispatcher: "exec", argument: "playerctl previous" },
    { id: "media.next", label: "Next Track", category: "Media", dispatcher: "exec", argument: "playerctl next" },
    { id: "media.stop-locked", label: "Stop Playback (Locked)", category: "Media", dispatcher: "exec", argument: "playerctl stop", flags: "l" },

    { id: "audio.volume-up", label: "Volume Up", category: "Audio", dispatcher: "exec", argument: "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 10%+", flags: "le" },
    { id: "audio.volume-down", label: "Volume Down", category: "Audio", dispatcher: "exec", argument: "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 10%-", flags: "le" },
    { id: "audio.mute-toggle", label: "Mute Audio", category: "Audio", dispatcher: "exec", argument: "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle", flags: "le" },

    { id: "brightness.up", label: "Brightness Up", category: "Brightness", dispatcher: "exec", argument: "ambxst brightness +5", flags: "le" },
    { id: "brightness.down", label: "Brightness Down", category: "Brightness", dispatcher: "exec", argument: "ambxst brightness -5", flags: "le" },

    { id: "system.calculator", label: "Calculator", category: "System", dispatcher: "exec", argument: "notify-send \"Soon\"" },
    { id: "system.lock", label: "Lock Session", category: "System", dispatcher: "exec", argument: "loginctl lock-session" },
    { id: "system.lock-locked", label: "Lock Session (Locked)", category: "System", dispatcher: "exec", argument: "loginctl lock-session", flags: "l" },
    { id: "system.dpms-off", label: "Display Off", category: "System", dispatcher: "exec", argument: "axctl monitor set-dpms 0 0", flags: "l" },
    { id: "system.dpms-on", label: "Display On", category: "System", dispatcher: "exec", argument: "axctl monitor set-dpms 0 1", flags: "l" },

    { id: "command.run", label: "Run Command", category: "Custom", dispatcher: "exec", args: [{ key: "command", label: "Command", placeholder: "command to run", defaultValue: "" }], argumentBuilder: function (args) {
        return String(args.command || "").trim();
    } },

    { id: "legacy.dispatcher", label: "Legacy Dispatcher", category: "Advanced", dispatcher: "", args: [
        { key: "dispatcher", label: "Dispatcher", placeholder: "dispatcher", defaultValue: "" },
        { key: "argument", label: "Argument", placeholder: "argument", defaultValue: "" },
        { key: "flags", label: "Flags", placeholder: "flags", defaultValue: "" }
    ], hidden: true }
];

var ACTION_INDEX = {};
for (var i = 0; i < ACTION_CATALOG.length; i++) {
    ACTION_INDEX[ACTION_CATALOG[i].id] = ACTION_CATALOG[i];
}

function getActionById(id) {
    return ACTION_INDEX[id] || null;
}

function getActionOptions() {
    return ACTION_CATALOG.filter(a => !a.hidden).map(a => ({
        id: a.id,
        label: a.label,
        category: a.category
    }));
}

function getActionFields(actionId) {
    const action = getActionById(actionId);
    if (!action || !action.args) return [];
    return action.args.map(field => ({
        key: field.key,
        label: field.label,
        placeholder: field.placeholder || "",
        defaultValue: field.defaultValue !== undefined ? field.defaultValue : ""
    }));
}

function defaultArgs(actionId) {
    const fields = getActionFields(actionId);
    let args = {};
    for (var i = 0; i < fields.length; i++) {
        args[fields[i].key] = fields[i].defaultValue;
    }
    return args;
}

function resolveAction(action) {
    if (!action) return null;
    if (action.dispatcher) {
        return {
            dispatcher: action.dispatcher || "",
            argument: action.argument || "",
            flags: action.flags || ""
        };
    }
    const entry = getActionById(action.id);
    if (!entry) return null;

    let argument = entry.argument || "";
    if (entry.argumentBuilder) {
        argument = entry.argumentBuilder(action.args || {});
    }
    if (entry.id === "legacy.dispatcher") {
        return {
            dispatcher: (action.args && action.args.dispatcher) || "",
            argument: (action.args && action.args.argument) || "",
            flags: (action.args && action.args.flags) || ""
        };
    }

    return {
        dispatcher: entry.dispatcher || "",
        argument: argument || "",
        flags: entry.flags || ""
    };
}

function describeAction(action) {
    if (!action) return "";
    const entry = getActionById(action.id);
    if (!entry) return "";
    if (entry.id === "legacy.dispatcher") {
        const dispatcher = action.args && action.args.dispatcher ? action.args.dispatcher : "";
        const argument = action.args && action.args.argument ? action.args.argument : "";
        return dispatcher + (argument ? " " + argument : "");
    }
    const fields = getActionFields(action.id);
    if (fields.length === 0) {
        return entry.label;
    }
    const args = action.args || {};
    const details = fields.map(f => args[f.key]).filter(v => v !== undefined && v !== "").join(" ");
    return details ? entry.label + " · " + details : entry.label;
}

function ensureAction(action) {
    if (!action) return null;
    if (action.id) {
        const fixed = clone(action);
        if (!fixed.args) {
            fixed.args = defaultArgs(fixed.id);
        }
        return fixed;
    }
    if (action.dispatcher) {
        return actionFromLegacy(action.dispatcher, action.argument || "", action.flags || "");
    }
    return null;
}

function actionFromLegacy(dispatcher, argument, flags) {
    const arg = String(argument || "").trim();
    if (dispatcher === "killactive") return { id: "window.close", args: {} };
    if (dispatcher === "workspace") {
        if (arg.startsWith("e")) {
            return { id: "workspace.switch-occupied", args: { offset: arg.substring(1) } };
        }
        if (arg.startsWith("+") || arg.startsWith("-")) {
            return { id: "workspace.switch-relative", args: { offset: arg } };
        }
        return { id: "workspace.switch", args: { index: arg } };
    }
    if (dispatcher === "movetoworkspace") {
        if (arg === "special") return { id: "workspace.move-window-special", args: {} };
        return { id: "workspace.move-window", args: { index: arg } };
    }
    if (dispatcher === "movetoworkspacesilent") {
        if (arg === "special") return { id: "workspace.move-window-special-silent", args: {} };
        return { id: "workspace.move-window-silent", args: { index: arg } };
    }
    if (dispatcher === "togglespecialworkspace") return { id: "workspace.toggle-special", args: {} };
    if (dispatcher === "movewindow" && flags === "m") return { id: "window.drag", args: {} };
    if (dispatcher === "resizewindow" && flags === "m") return { id: "window.resize-drag", args: {} };
    if (dispatcher === "movewindow") return { id: "window.move", args: { direction: arg } };
    if (dispatcher === "movefocus") return { id: "window.focus", args: { direction: arg } };
    if (dispatcher === "resizeactive") return { id: "window.resize", args: { delta: arg } };
    if (dispatcher === "layoutmsg") {
        if (arg.startsWith("focus ")) return { id: "scrolling.focus", args: { direction: arg.split(" ")[1] } };
        if (arg.startsWith("movewindowto ")) return { id: "scrolling.move-window", args: { direction: arg.split(" ")[1] } };
        if (arg.startsWith("colresize ")) {
            const delta = arg.split(" ")[1] || "";
            if (delta === "+conf") return { id: "scrolling.toggle-full-column", args: {} };
            return { id: "scrolling.resize-column", args: { delta: delta } };
        }
        if (arg === "promote") return { id: "scrolling.promote", args: {} };
        if (arg === "togglefit") return { id: "scrolling.toggle-fit", args: {} };
        if (arg.startsWith("swapcol ")) return { id: "scrolling.swap-column", args: { direction: arg.split(" ")[1] } };
        if (arg.startsWith("movecoltoworkspace ")) return { id: "scrolling.move-column-workspace", args: { index: arg.split(" ")[1] } };
    }
    if (dispatcher === "exec") {
        if (arg === "playerctl play-pause" && flags === "l") return { id: "media.play-pause-locked", args: {} };
        if (arg === "playerctl play-pause") return { id: "media.play-pause", args: {} };
        if (arg === "playerctl previous") return { id: "media.prev", args: {} };
        if (arg === "playerctl next") return { id: "media.next", args: {} };
        if (arg === "playerctl stop" && flags === "l") return { id: "media.stop-locked", args: {} };
        if (arg.indexOf("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 10%+") === 0) return { id: "audio.volume-up", args: {} };
        if (arg.indexOf("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 10%-") === 0) return { id: "audio.volume-down", args: {} };
        if (arg.indexOf("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle") === 0) return { id: "audio.mute-toggle", args: {} };
        if (arg.indexOf("ambxst brightness +5") === 0) return { id: "brightness.up", args: {} };
        if (arg.indexOf("ambxst brightness -5") === 0) return { id: "brightness.down", args: {} };
        if (arg === "notify-send \"Soon\"") return { id: "system.calculator", args: {} };
        if (arg === "loginctl lock-session" && flags === "l") return { id: "system.lock-locked", args: {} };
        if (arg === "loginctl lock-session") return { id: "system.lock", args: {} };
        if (arg === "axctl monitor set-dpms 0 0") return { id: "system.dpms-off", args: {} };
        if (arg === "axctl monitor set-dpms 0 1") return { id: "system.dpms-on", args: {} };
        return { id: "command.run", args: { command: arg } };
    }

    return {
        id: "legacy.dispatcher",
        args: {
            dispatcher: dispatcher || "",
            argument: arg,
            flags: flags || ""
        }
    };
}

function normalizeCustomBinds(binds) {
    let changed = false;
    let normalized = [];

    for (var i = 0; i < binds.length; i++) {
        const bind = binds[i] || {};

        if (bind.keys === undefined || bind.actions === undefined) {
            changed = true;
            normalized.push({
                name: bind.name || "",
                keys: [
                    {
                        modifiers: bind.modifiers || [],
                        key: bind.key || ""
                    }
                ],
                actions: [
                    Object.assign({ layouts: [] }, actionFromLegacy(bind.dispatcher || "", bind.argument || "", bind.flags || ""))
                ],
                enabled: bind.enabled !== false
            });
            continue;
        }

        let actions = [];
        let actionChanged = false;
        for (var a = 0; a < bind.actions.length; a++) {
            let action = bind.actions[a] || {};
            if (action.dispatcher) {
                actionChanged = true;
                const mapped = actionFromLegacy(action.dispatcher || "", action.argument || "", action.flags || "");
                mapped.layouts = action.layouts || [];
                actions.push(mapped);
            } else if (!action.id) {
                actionChanged = true;
                actions.push(Object.assign({ layouts: action.layouts || [] }, actionFromLegacy("", "", "")));
            } else {
                const fixed = ensureAction(action);
                fixed.layouts = action.layouts || [];
                actions.push(fixed);
            }
        }

        if (actionChanged) changed = true;
        normalized.push({
            name: bind.name || "",
            keys: bind.keys || [],
            actions: actions,
            enabled: bind.enabled !== false
        });
    }

    return { changed: changed, binds: normalized };
}

function migrateLegacyCustomBinds(binds) {
    return normalizeCustomBinds(binds).binds;
}
