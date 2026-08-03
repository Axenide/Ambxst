pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    property var focusedMonitor: null
    property var focusedWorkspace: null
    property var focusedClient: null

    // Becomes true once the axctl daemon socket is up and the subscribe stream
    // has delivered its first state. Services that query axctl at startup should
    // gate on this instead of racing the daemon (which spawns socket errors).
    property bool ready: false

    property int focusHistoryCounter: 0

    // Saved focus address — set before a shell overlay (notch/launcher/dashboard)
    // captures exclusive keyboard focus, and dispatched to the compositor to
    // restore focus when the overlay closes.
    property string savedFocusAddress: ""

    // Captures the address of the window that is focused *right now* so it can be
    // restored later. If no window is currently focused (e.g. the active
    // workspace is empty), nothing is saved so closing the overlay leaves the
    // user where they are instead of pulling focus to a stale window.
    function saveFocus() {
        let clients = root.clients.values || [];
        let current = clients.find(c => c.is_focused);
        root.savedFocusAddress = (current && current.address) ? current.address : "";
    }

    // Re-focus the saved window after an overlay closes. Deferred (see below).
    function restoreFocus() {
        if (root.savedFocusAddress)
            restoreFocusTimer.restart();
    }

    // The refocus is deferred for two reasons:
    //  1. The shell overlay only drops its exclusive keyboard grab a frame or two
    //     after the module closes; dispatching focuswindow before that happens is
    //     ignored by the compositor, leaving the app unfocused until the user
    //     clicks it (and breaking things like emoji paste that type into it).
    //  2. We only refocus if the saved window is still on the *current* active
    //     workspace, so a stale saved address can never yank the user to another
    //     workspace (e.g. opening settings jumping back to workspace 1).
    property Timer restoreFocusTimer: Timer {
        interval: 60
        repeat: false
        onTriggered: {
            const addr = root.savedFocusAddress;
            root.savedFocusAddress = "";
            if (!addr)
                return;
            const clients = root.clients.values || [];
            const win = clients.find(c => c.address === addr);
            const fmon = root.focusedMonitor;
            const activeWs = fmon && fmon.activeWorkspace ? fmon.activeWorkspace.id : -1;
            if (win && win.workspace && win.workspace.id === activeWs) {
                // Re-focus the app, but without warping the cursor to its centre.
                // Hyprland's focuswindow dispatcher warps by default, so we
                // briefly disable cursor:no_warps, focus, then re-enable it. The
                // chain (set-off -> focus -> set-on) runs each step on the
                // previous process's exit so warp is guaranteed off before the
                // focus and always restored afterwards. Using direct axctl/hyprctl
                // processes (not a bash -c wrapper) keeps the call environment
                // identical to the rest of the shell, so the focus actually lands.
                let setOff = Qt.createQmlObject('import Quickshell.Io; Process {}', root);
                setOff.command = ["hyprctl", "keyword", "cursor:no_warps", "1"];
                setOff.onExited.connect(() => {
                    setOff.destroy();
                    let focus = Qt.createQmlObject('import Quickshell.Io; Process {}', root);
                    focus.command = ["axctl", "window", "focus", addr];
                    focus.onExited.connect(() => {
                        let setOn = Qt.createQmlObject('import Quickshell.Io; Process {}', root);
                        setOn.command = ["hyprctl", "keyword", "cursor:no_warps", "0"];
                        setOn.onExited.connect(() => setOn.destroy());
                        setOn.running = true;
                        focus.destroy();
                    });
                    focus.running = true;
                });
                setOff.running = true;
            }
        }
    }

    function clearSavedFocus() {
        restoreFocusTimer.stop();
        root.savedFocusAddress = "";
    }

    property QtObject clients: QtObject {
        property var values: []
    }

    property QtObject monitors: QtObject {
        property var values: []
    }

    property QtObject workspaces: QtObject {
        property var values: []
    }

    signal rawEvent(var event)

    // Fired every time the subscribe stream (re)connects — the daemon always
    // sends a State.Dump as the first event of a connection. Consumers use
    // this to re-sync state that may have changed while the stream was down.
    signal subscribed()

    // Config path for axctl daemon
    property string configPath: (Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")) + "/ambxst+/axctl.toml"

    function dispatch(command) {
        if (!command) return;

        let spaceIdx = command.indexOf(' ');
        let action = spaceIdx !== -1 ? command.substring(0, spaceIdx).trim() : command.trim();
        let rawArgs = spaceIdx !== -1 ? command.substring(spaceIdx + 1).trim() : "";

        let getAddr = (str) => {
            let m = str.match(/address:([^\s,]+)/);
            return m ? m[1] : str.trim();
        };

        let cmdArgs = [];

        if (action === "workspace") {
            cmdArgs = ["workspace", "switch", rawArgs];
        } else if (action === "closewindow") {
            cmdArgs = ["window", "close", getAddr(rawArgs)];
        } else if (action === "focuswindow") {
            cmdArgs = ["window", "focus", getAddr(rawArgs)];
        } else if (action === "movetoworkspacesilent") {
            let subParts = rawArgs.split(',');
            cmdArgs = ["window", "move-to-workspace-silent", subParts[0].trim()];
            if (subParts.length > 1) {
                cmdArgs.push(getAddr(subParts[1]));
            }
        } else if (action === "focusmonitor") {
            cmdArgs = ["monitor", "focus", rawArgs];
        } else if (action === "togglespecialworkspace") {
            cmdArgs = ["workspace", "toggle-special"];
            if (rawArgs) cmdArgs.push(rawArgs);
        } else {
            cmdArgs = ["system", "execute", command];
        }

        let finalCommand = ["axctl"].concat(cmdArgs.filter(x => x !== "" && x !== undefined));

        let proc = Qt.createQmlObject('import Quickshell.Io; Process {}', root);
        proc.command = finalCommand;
        proc.onExited.connect(() => proc.destroy());
        proc.running = true;
    }

    function monitorFor(screen) {
        if (!screen) return null;
        let screenName = screen.name || screen;
        let values = root.monitors.values || [];
        for (let i = 0; i < values.length; i++) {
            if (values[i].name === screenName) return values[i];
        }
        return null;
    }

    // Fingerprint of the last applied state. Every axctl event carries the full
    // state, and most events (title changes, geometry, focus moves) touch only a
    // handful of fields — but the old code unconditionally rebuilt and reassigned
    // all three arrays, firing change notifications to every consumer (bar, dock,
    // workspaces, taskbar, notch) even when nothing actually changed. This cheap
    // string compare lets us skip the whole mapping pass when the state is
    // bit-identical.
    property string _stateFingerprint: ""

    // Debounce guard for workspace-following. When the compositor focuses a
    // window on a workspace that isn't active (a link click activating the
    // browser on another workspace, a file opening in an app already running
    // elsewhere, …), we dispatch a workspace switch. If that dispatch is
    // ignored or fails, every subsequent state event would re-trigger the same
    // switch, so identical follow targets are throttled to once per window.
    property string _lastFollowKey: ""
    property int _lastFollowTime: 0

    // Mirrors KDE/GNOME behaviour: when a window is activated on a workspace
    // that isn't the active one of its monitor, follow it there. Hyprland only
    // does this reliably when the app performed a proper xdg-activation request
    // with misc:focus_on_activate enabled; some apps (or configs) skip that, so
    // the compositor ends up with a focused window on a non-active workspace —
    // which is exactly the state this watches for. Called after every state
    // application; at steady state the focused window is always on the active
    // workspace of its monitor, so the mismatch is transient by construction.
    function followActivatedWorkspace() {
        if (!root.ready || !root.focusedClient)
            return;
        if (!(Config.compositor?.switchToActivatedWorkspace ?? true))
            return;

        const client = root.focusedClient;
        const wsId = client.workspace?.id ?? 0;
        if (wsId <= 0) // special (scratchpad) workspaces report id 0 — never follow
            return;
        const mon = (root.monitors.values || []).find(m => m.id === client.monitor);
        if (!mon || !mon.activeWorkspace)
            return;
        if (mon.activeWorkspace.id === wsId)
            return;

        const now = Date.now();
        const key = client.address + "|" + wsId;
        if (root._lastFollowKey === key && now - root._lastFollowTime < 750)
            return;
        root._lastFollowKey = key;
        root._lastFollowTime = now;

        // axctl's workspace switch acts on the focused monitor, so a window on
        // another screen needs that monitor focused first.
        if (root.focusedMonitor && mon.id !== root.focusedMonitor.id)
            root.dispatch("focusmonitor " + mon.id);
        root.dispatch("workspace " + wsId);
    }

    function applyState(state) {
        if (!state) return;

        // Only the three tracked collections matter for change detection; the
        // event object may carry extra metadata that changes per event.
        const fingerprint = JSON.stringify([state.windows, state.workspaces, state.monitors]);
        if (fingerprint === root._stateFingerprint)
            return;
        root._stateFingerprint = fingerprint;

        // --- Windows ---
        if (state.windows) {
            let existingClients = root.clients.values || [];
            // Index existing clients by address once (O(n)) so the per-window
            // lookup below is O(1) instead of O(n²) on every compositor event.
            let existingMap = {};
            for (let i = 0; i < existingClients.length; i++) {
                existingMap[existingClients[i].address] = existingClients[i];
            }
            let mappedClients = state.windows.map(win => {
                let existing = existingMap[win.id];
                let prevFocus = existing && existing.focusHistoryID !== undefined ? existing.focusHistoryID : 999999;
                let newFocus = win.is_focused ? (existing && existing.is_focused ? prevFocus : --root.focusHistoryCounter) : prevFocus;
                return {
                    address: win.id,
                    class: win.app_id,
                    title: win.title,
                    workspace: { id: parseInt(win.workspace_id) || 0, name: win.workspace_id },
                    monitor: parseInt(win.metadata ? win.metadata.monitor_id : 0) || 0,
                    floating: win.is_floating,
                    fullscreen: win.is_fullscreen,
                    hidden: win.is_hidden,
                    mapped: true,
                    at: [win.metadata ? (win.metadata.x || 0) : 0, win.metadata ? (win.metadata.y || 0) : 0],
                    size: [win.metadata ? (win.metadata.width || 100) : 100, win.metadata ? (win.metadata.height || 100) : 100],
                    xwayland: (win.metadata ? win.metadata.xwayland : false) || false,
                    is_focused: win.is_focused || false,
                    focusHistoryID: newFocus
                };
            });
            root.clients.values = mappedClients;
            // Prefer the window the compositor actually reports as focused. Only
            // fall back to the previously tracked client when nothing is focused
            // (e.g. a shell overlay is holding exclusive keyboard focus), so the
            // last real focus is preserved for restoreFocus().
            let focused = mappedClients.find(w => w.is_focused) || mappedClients.find(w => w.address === (root.focusedClient ? root.focusedClient.address : undefined)) || null;
            if (focused !== root.focusedClient) {
                root.focusedClient = focused;
            }
        }

        // --- Workspaces ---
        if (state.workspaces) {
            let mappedWorkspaces = state.workspaces.map(ws => ({
                id: parseInt(ws.id) || 0,
                name: ws.name,
                monitor: ws.monitor_id,
                active: ws.is_active,
                windows: 0
            }));
            root.workspaces.values = mappedWorkspaces;
            let focused = mappedWorkspaces.find(ws => ws.active) || null;
            if (focused !== root.focusedWorkspace) {
                root.focusedWorkspace = focused;
            }
        }

        // --- Monitors ---
        if (state.monitors) {
            let mappedMonitors = state.monitors.map(mon => ({
                id: parseInt(mon.id) || 0,
                name: mon.name,
                focused: mon.is_focused,
                width: mon.width,
                height: mon.height,
                refreshRate: mon.refresh_rate,
                scale: mon.scale,
                activeWorkspace: { id: parseInt(mon.metadata ? mon.metadata.active_workspace : 0) || 0, name: mon.metadata ? mon.metadata.active_workspace : "" }
            }));
            root.monitors.values = mappedMonitors;
            let focused = mappedMonitors.find(m => m.focused) || null;
            if (focused !== root.focusedMonitor) {
                root.focusedMonitor = focused;
            }
        }

        root.followActivatedWorkspace();
    }

    property Process ensureConfigDir: Process {
        command: ["mkdir", "-p", (Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")) + "/ambxst+"]
        running: true
    }

    property Process axctlProcess: Process {
        command: ["axctl", "-c", root.configPath, "daemon"]
        running: true
        stdout: SplitParser {
            onRead: (data) => {
                // Daemon logs can be printed here if needed
            }
        }
        onExited: (code) => {
            console.warn("axctl daemon exited with code:", code)
        }
    }

    // Brief delay to let daemon start before subscribing
    Timer {
        id: subscribeDelay
        interval: 500
        running: true
        onTriggered: axctlSubscribe.running = true
    }

    // Auto-reconnect on unexpected subscribe exit
    Timer {
        id: reconnectTimer
        interval: 1000
        onTriggered: axctlSubscribe.running = true
    }

    property Process axctlSubscribe: Process {
        command: ["axctl", "subscribe"]
        running: false
        stdout: SplitParser {
            onRead: (data) => {
                if (!data) return;
                try {
                    let parsedJson = JSON.parse(data);

                    // Apply inline state immediately (every event carries full state)
                    if (parsedJson.state) {
                        root.applyState(parsedJson.state);
                        if (!root.ready)
                            root.ready = true;
                    }

                    // Emit raw event for consumers
                    parsedJson.name = parsedJson.method ? parsedJson.method.split('.').pop().toLowerCase() : "";
                    parsedJson.data = parsedJson.params;
                    root.rawEvent(parsedJson);

                    if (parsedJson.method === "State.Dump") {
                        root.subscribed();
                    }
                } catch (e) {
                    console.error("AxctlService subscribe JSON parse error:", e);
                }
            }
        }
        onExited: (code) => {
            console.warn("axctl subscribe exited:", code);
            reconnectTimer.restart();
        }
    }

    Component.onDestruction: {
        reconnectTimer.running = false
        axctlProcess.running = false
        axctlSubscribe.running = false
    }
}
