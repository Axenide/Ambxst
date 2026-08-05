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

    // Restore caffeine state reactively once StateService is ready.
    // initializedChanged fires exactly once (right after the Go daemon IPC
    // resolves); Component.onCompleted covers the case where the signal
    // was already emitted before our Connections block was bound.
    property bool _restored: false
    Connections {
        target: StateService
        function onInitializedChanged() {
            root._restoreFromState();
        }
    }
    Component.onCompleted: root._restoreFromState()

    function _restoreFromState() {
        if (StateService.initialized && !root._restored) {
            root._restored = true;
            root.inhibit = StateService.get("caffeine", false);
        }
    }
}
