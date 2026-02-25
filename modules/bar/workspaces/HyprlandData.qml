pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Singleton {
    id: root
    property var windowList: []
    property var addresses: []
    property var windowByAddress: ({})
    property var monitors: []
    property var workspaceOccupationMap: ({})
    property var workspaceWindowsMap: ({})

    // Debounce timer to batch rapid Hyprland events
    Timer {
        id: updateDebounce
        interval: 100
        onTriggered: {
            getClients.running = true
            getMonitors.running = true
        }
    }

    function updateWindowList() {
        updateDebounce.restart()
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
        target: Hyprland

        function onRawEvent(event) {
            // Only request full update for critical events
            let ignoreList = [
                "activewindow", "focusedmon", "monitoradded", 
                "createworkspace", "destroyworkspace", "moveworkspace", 
                "activespecial", "movewindow", "windowtitle",
                "workspace"
            ]
            if (ignoreList.includes(event.name)) return
            updateWindowList()
        }
    }

    Process {
        id: getClients
        command: ["bash", "-c", "hyprctl clients -j | jq -c"]
        stdout: SplitParser {
            onRead: (data) => {
                root.windowList = JSON.parse(data)
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
    }
    Process {
        id: getMonitors
        command: ["bash", "-c", "hyprctl monitors -j | jq -c"]
        stdout: SplitParser {
            onRead: (data) => {
                root.monitors = JSON.parse(data)
            }
        }
    }
}