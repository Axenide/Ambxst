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

    function updateWindowList() {
        // No-op: state is now pushed inline via axctl subscribe events
    }

    // Monitor-scoped fullscreen check. Only windows on the given monitor's
    // active workspace count, so fullscreen state never propagates to
    // other screens.
    function monitorHasFullscreen(mon) {
        if (!mon || !mon.activeWorkspace)
            return false;
        const wsId = mon.activeWorkspace.id;
        const wins = root.windowList;
        for (let i = 0; i < wins.length; i++) {
            if (wins[i].monitor === mon.id && wins[i].fullscreen && wins[i].workspace.id === wsId)
                return true;
        }
        return false;
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

        function onValuesChanged() {
            root.windowList = AxctlService.clients.values
            let tempWinByAddress = {}
            for (var i = 0; i < root.windowList.length; ++i) {
                var win = root.windowList[i]
                tempWinByAddress[win.address] = win
            }
            root.windowByAddress = tempWinByAddress
            root.addresses = root.windowList.map((win) => win.address)
            updateMaps()
        }
    }

    Connections {
        target: AxctlService.monitors

        function onValuesChanged() {
            root.monitors = AxctlService.monitors.values
        }
    }
}
