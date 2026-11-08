pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    property var focusedMonitor: null
    property var focusedWorkspace: null
    property var focusedClient: null

    // Compositor-level overview state (niri's native overview). Sourced
    // from `overview_open` in the compositor state dump; stays false on
    // compositors that don't emit overview events.
    property bool overviewOpen: false

    // Compositor backend name ("hyprland"/"niri"/"mango"), from
    // `axctl system get-compositor`. Empty until the daemon + axctl
    // daemon are up; probed with retries below.
    property string compositorName: ""

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

    function workspaceName(value) {
        const name = String(value ?? "");
        if (name.startsWith("special:")) return name;
        const separator = name.lastIndexOf(":");
        return separator >= 0 ? name.slice(separator + 1) : name;
    }

    function workspaceRef(value) {
        const identity = String(value ?? "");
        const name = root.workspaceName(identity);
        const numericId = Number(name);
        return {
            id: Number.isFinite(numericId) ? numericId : (parseInt(name) || 0),
            name: name,
            identity: identity
        };
    }

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
        } else if (action === "overview") {
            cmdArgs = ["overview", "toggle"];
        } else if (action === "fullscreen") {
            const state = rawArgs.trim().startsWith("1") ? "1" : "0";
            cmdArgs = ["window", "fullscreen", state];
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

        if (state.overview_open !== undefined && state.overview_open !== null) {
            root.overviewOpen = state.overview_open;
        }

        if (state.windows) {
            const existingClients = root.clients.values || [];
            const workspaceStates = state.workspaces || [];
            const mappedClients = state.windows.map(win => {
                const metadata = win.metadata || {};
                const rawWorkspaceId = String(win.workspace_id || "");
                const workspaceState = workspaceStates.find(ws =>
                    String(ws.id ?? "") === rawWorkspaceId || String(ws.name ?? "") === rawWorkspaceId
                );
                const workspaceName = root.workspaceName(workspaceState ? (workspaceState.name || workspaceState.id) : rawWorkspaceId);
                const parsedWorkspaceId = Number(workspaceName);
                const workspaceId = Number.isFinite(parsedWorkspaceId) ? parsedWorkspaceId : (parseInt(workspaceName) || 0);
                const monitorId = String(metadata.monitor_id ?? metadata.monitor ?? "");
                const existing = existingClients.find(c => c.address === win.id);
                const prevFocus = existing && existing.focusHistoryID !== undefined ? existing.focusHistoryID : 999999;
                const newFocus = win.is_focused ? (existing && existing.is_focused ? prevFocus : --root.focusHistoryCounter) : prevFocus;
                return {
                    address: win.id,
                    class: win.app_id,
                    title: win.title,
                    workspace: { id: workspaceId, name: workspaceName, identity: rawWorkspaceId },
                    monitor: monitorId,
                    floating: win.is_floating,
                    fullscreen: win.is_fullscreen,
                    hidden: win.is_hidden,
                    visible: metadata.is_visible === undefined ? undefined : Boolean(metadata.is_visible),
                    mapped: true,
                    at: [metadata.x || 0, metadata.y || 0],
                    size: [metadata.width || 0, metadata.height || 0],
                    xwayland: metadata.xwayland || false,
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
            const mappedWorkspaces = state.workspaces.map(ws => {
                const metadata = ws.metadata || {};
                const identity = String(ws.id ?? ws.name ?? "");
                const name = root.workspaceName(String(ws.name || ws.id || ""));
                const parsedIndex = Number(metadata.index ?? name);
                const id = Number.isFinite(parsedIndex) ? parsedIndex : (parseInt(name) || 0);
                return {
                    id: id,
                    name: name || String(id),
                    identity: identity,
                    monitor: String(ws.monitor_id ?? metadata.monitor_id ?? ""),
                    active: ws.is_active,
                    layout: String(metadata.layout ?? ""),
                    windows: 0
                };
            });
            root.workspaces.values = mappedWorkspaces;
            const focusedMonitorState = (state.monitors || []).find(mon => mon.is_focused);
            const focusedMonitorId = focusedMonitorState ? String(focusedMonitorState.id ?? focusedMonitorState.name ?? "") : "";
            const focusedMonitorName = focusedMonitorState ? String(focusedMonitorState.name ?? "") : "";
            const focused = mappedWorkspaces.find(ws => ws.active && (!focusedMonitorId || ws.monitor === focusedMonitorId || ws.monitor === focusedMonitorName))
                || mappedWorkspaces.find(ws => ws.active)
                || null;
            if (focused !== root.focusedWorkspace) {
                root.focusedWorkspace = focused;
            }
        }

        if (state.monitors) {
            const mappedWorkspaces = root.workspaces.values || [];
            const mappedMonitors = state.monitors.map(mon => {
                const metadata = mon.metadata || {};
                const id = String(mon.id ?? mon.name ?? "");
                const name = String(mon.name ?? id);
                const workspaceOnMonitor = ws => ws.monitor === id || ws.monitor === name;
                const findWorkspace = value => {
                    const identity = String(value ?? "");
                    if (!identity) return null;
                    const name = root.workspaceName(identity);
                    return mappedWorkspaces.find(ws =>
                        workspaceOnMonitor(ws) && (ws.identity === identity || ws.name === identity || ws.name === name || String(ws.id) === identity)
                    );
                };
                const activeWorkspace = findWorkspace(metadata.active_workspace)
                    || mappedWorkspaces.find(ws => workspaceOnMonitor(ws) && ws.active)
                    || (metadata.active_workspace !== undefined && metadata.active_workspace !== null && String(metadata.active_workspace) !== ""
                        ? root.workspaceRef(metadata.active_workspace)
                        : null);
                const visibleWorkspace = findWorkspace(metadata.visible_workspace)
                    || (metadata.visible_workspace !== undefined && metadata.visible_workspace !== null && String(metadata.visible_workspace) !== ""
                        ? root.workspaceRef(metadata.visible_workspace)
                        : activeWorkspace);
                return {
                    id: id,
                    name: name,
                    focused: mon.is_focused,
                    width: mon.width,
                    height: mon.height,
                    refreshRate: mon.refresh_rate,
                    scale: mon.scale,
                    x: metadata.x || 0,
                    y: metadata.y || 0,
                    activeWorkspace: activeWorkspace
                        ? { id: activeWorkspace.id, name: activeWorkspace.name, identity: activeWorkspace.identity }
                        : { id: 0, name: "", identity: "" },
                    visibleWorkspace: visibleWorkspace
                        ? { id: visibleWorkspace.id, name: visibleWorkspace.name, identity: visibleWorkspace.identity }
                        : { id: 0, name: "", identity: "" }
                };
            });
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

    Timer {
        id: compositorNameProbe
        interval: 1000
        repeat: true
        property int attempts: 0

        onTriggered: {
            attempts++;
            if (attempts > 30) {
                running = false;
                return;
            }
            root.probeCompositorName();
        }
    }

    onCompositorNameChanged: {
        if (compositorName !== "") {
            compositorNameProbe.running = false;
        }
    }

    function probeCompositorName() {
        BackendService.call("compositor.dispatch", {args: ["system", "get-compositor"]}, (result, error) => {
            if (error || !result || result.error || result.exit_code !== 0) return;
            const name = (result.stdout || "").trim().toLowerCase();
            if (!name) return;
            Qt.callLater(() => {
                root.compositorName = name;
                compositorNameProbe.running = false;
            });
        });
    }

    Component.onCompleted: {
        if (typeof BackendService.call === "function") {
            BackendService.call("compositor.state", {}, (result, error) => {
                if (result && !error) applyState(result);
            });
        }
        // Fire the first probe immediately; the timer only handles retries.
        probeCompositorName();
        compositorNameProbe.running = true;
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
