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
