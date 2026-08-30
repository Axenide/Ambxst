pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    property var focusedMonitor: null
    property var focusedWorkspace: null
    property var focusedClient: null

    property int focusHistoryCounter: 0

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

    function dispatch(command) {
        if (!command) return;

        const spaceIdx = command.indexOf(' ');
        const action = spaceIdx !== -1 ? command.substring(0, spaceIdx).trim() : command.trim();
        const rawArgs = spaceIdx !== -1 ? command.substring(spaceIdx + 1).trim() : "";

        const getAddr = (str) => {
            const m = str.match(/address:([^\s,]+)/);
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
            const subParts = rawArgs.split(',');
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

        BackendService.notify("compositor.dispatch", {args: cmdArgs.filter(x => x !== "" && x !== undefined)});
    }

    function monitorFor(screen) {
        if (!screen) return null;
        const screenName = screen.name || screen;
        const values = root.monitors.values || [];
        for (let i = 0; i < values.length; i++) {
            if (values[i].name === screenName) return values[i];
        }
        return null;
    }

    function applyState(state) {
        if (!state) return;

        if (state.windows) {
            const existingClients = root.clients.values || [];
            const mappedClients = state.windows.map(win => {
                const existing = existingClients.find(c => c.address === win.id);
                const prevFocus = existing && existing.focusHistoryID !== undefined ? existing.focusHistoryID : 999999;
                const newFocus = win.is_focused ? (existing && existing.is_focused ? prevFocus : --root.focusHistoryCounter) : prevFocus;
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
                    size: [win.metadata ? (win.metadata.width || 0) : 0, win.metadata ? (win.metadata.height || 0) : 0],
                    xwayland: (win.metadata ? win.metadata.xwayland : false) || false,
                    is_focused: win.is_focused || false,
                    focusHistoryID: newFocus
                };
            });
            root.clients.values = mappedClients;
            const focused = mappedClients.find(w => w.address === (root.focusedClient ? root.focusedClient.address : undefined)) || mappedClients.find(w => w.is_focused) || null;
            if (focused !== root.focusedClient) {
                root.focusedClient = focused;
            }
        }

        if (state.workspaces) {
            const mappedWorkspaces = state.workspaces.map(ws => ({
                id: parseInt(ws.id) || 0,
                name: ws.name,
                monitor: ws.monitor_id,
                active: ws.is_active,
                windows: 0
            }));
            root.workspaces.values = mappedWorkspaces;
            const focused = mappedWorkspaces.find(ws => ws.active) || null;
            if (focused !== root.focusedWorkspace) {
                root.focusedWorkspace = focused;
            }
        }

        if (state.monitors) {
            const mappedMonitors = state.monitors.map(mon => ({
                id: parseInt(mon.id) || 0,
                name: mon.name,
                focused: mon.is_focused,
                width: mon.width,
                height: mon.height,
                refreshRate: mon.refresh_rate,
                scale: mon.scale,
                x: parseInt(mon.metadata ? mon.metadata.x : 0) || 0,
                y: parseInt(mon.metadata ? mon.metadata.y : 0) || 0,
                transform: parseInt(mon.metadata ? mon.metadata.transform : 0) || 0,
                activeWorkspace: { id: parseInt(mon.metadata ? mon.metadata.active_workspace : 0) || 0, name: mon.metadata ? mon.metadata.active_workspace : "" }
            }));
            root.monitors.values = mappedMonitors;
            const focused = mappedMonitors.find(mon => mon.focused) || null;
            if (focused !== root.focusedMonitor) {
                root.focusedMonitor = focused;
            }
        }
    }

    // Subscribe to the compositor service owned by the Go daemon. State
    // events arrive as raw {windows, workspaces, monitors} payloads; the
    // subscription auto-reconnects via BackendService when the daemon
    // restarts (e.g. after `ambxst reload`). An explicit state call also
    // runs first so the initial snapshot is captured even if the daemon
    // emitted events before the subscription was wired up.
    property var compositorSub: null

    Component.onCompleted: {
        if (typeof BackendService.call === "function") {
            BackendService.call("compositor.state", {}, (result, error) => {
                if (result && !error) applyState(result);
            });
        }
        compositorSub = BackendService.addSubscription(["compositor"], (service, data) => {
            if (service !== "compositor.state" || !data) return;
            applyState(data);
            const ev = {
                service: "compositor",
                method: "state",
                data: data
            };
            root.rawEvent(ev);
        });
    }

    Component.onDestruction: {
        if (compositorSub !== null) {
            BackendService.removeSubscription(compositorSub);
        }
    }
}
