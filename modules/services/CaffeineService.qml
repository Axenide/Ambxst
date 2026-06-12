import QtQuick
import Quickshell

pragma Singleton

Singleton {
    id: root

    property alias inhibit: idleInhibitor.enabled

    function toggleInhibit() {
        inhibit = !inhibit;
    }

    IdleInhibitor {
        id: idleInhibitor

        onEnabledChanged: {
            if (StateService.initialized) {
                StateService.set("caffeine", enabled);
            }
        }
    }

    Connections {
        target: StateService
        function onStateLoaded() {
            root.inhibit = StateService.get("caffeine", false);
        }
    }

    Timer {
        interval: 500
        running: true
        repeat: false
        onTriggered: {
            if (StateService.initialized) {
                root.inhibit = StateService.get("caffeine", false);
            }
        }
    }
}