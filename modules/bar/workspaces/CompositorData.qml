pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.modules.services

Singleton {
    id: root
    property var windowList: []
    property var addresses: []
    property var windowByAddress: ({})
    property var monitors: []
    property var workspaceOccupationMap: ({})
    property var workspaceWindowsMap: ({})

    // Apply a fresh clients array to all derived state.
    function _applyClients(clients) {
        root.windowList = clients
        let tempWinByAddress = {}
        for (var i = 0; i < clients.length; ++i) {
            var win = clients[i]
            if (win && win.address) tempWinByAddress[win.address] = win
        }
        root.windowByAddress = tempWinByAddress
        root.addresses = clients.map((win) => win && win.address)
        updateMaps()
    }

    // Debounce so a burst of axctl events doesn't trigger many hyprctl forks.
    Timer {
        id: hyprctlDebounce
        interval: 60
        onTriggered: hyprctlClientsProcess.running = true
    }

    // Force-refresh windowList by querying hyprctl directly. Necessary because
    // axctl's cached state lags behind Hyprland on geometry changes — a
    // dispatch like movetoworkspacesilent that triggers re-tiling does not
    // get the resulting resizes reflected in the daemon's state until
    // something else (e.g. Event.WorkspaceChanged) forces a refresh. So
    // chips in the overview keep showing the pre-move sizes even though
    // Hyprland has already re-laid-out the windows. We bypass axctl's stale
    // cache by polling hyprctl on every axctl event (debounced).
    function updateWindowList() {
        hyprctlDebounce.restart()
    }

    Process {
        id: hyprctlClientsProcess
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    const raw = (text || "").trim()
                    if (!raw) return
                    const clients = JSON.parse(raw)
                    if (!Array.isArray(clients)) return
                    // hyprctl already produces records with the fields consumers
                    // expect (address, class, title, workspace.id, monitor, at,
                    // size, floating, xwayland) — same shape AxctlService produces,
                    // just sourced directly from Hyprland's live state.
                    const mapped = clients.map(c => ({
                        address: c.address,
                        class: c.class,
                        title: c.title,
                        workspace: { id: (c.workspace && c.workspace.id) || 0, name: (c.workspace && c.workspace.name) || "" },
                        monitor: c.monitor || 0,
                        floating: !!c.floating,
                        fullscreen: !!c.fullscreen,
                        hidden: !!c.hidden,
                        mapped: c.mapped !== false,
                        at: c.at || [0, 0],
                        size: c.size || [100, 100],
                        xwayland: !!c.xwayland,
                        is_focused: c.focusHistoryID === 0,
                        focusHistoryID: c.focusHistoryID
                    }))
                    root._applyClients(mapped)
                } catch (e) {
                    console.warn("[CompositorData] hyprctl parse failed:", e)
                }
            }
        }
    }

    function updateMaps() {
        let occupationMap = {}
        let windowsMap = {}
        for (var i = 0; i < root.windowList.length; ++i) {
            var win = root.windowList[i]
            let wsId = win.workspace.id
            occupationMap[wsId] = true
            if (!windowsMap[wsId]) {
                windowsMap[wsId] = []
            }
            windowsMap[wsId].push(win)
        }
        root.workspaceOccupationMap = occupationMap
        root.workspaceWindowsMap = windowsMap
    }

    Component.onCompleted: {
        updateWindowList()
    }

    Connections {
        target: AxctlService.clients

        // Use axctl events as a "something changed" signal — but treat the
        // inline state as untrustworthy for sizes/positions (see comment on
        // updateWindowList). Re-fetch from hyprctl for the authoritative
        // geometry.
        function onValuesChanged() {
            root.updateWindowList()
        }
    }

    Connections {
        target: AxctlService.monitors

        function onValuesChanged() {
            root.monitors = AxctlService.monitors.values
        }
    }
}
