import QtQuick
import Quickshell

pragma Singleton

Singleton {
    id: root

    property bool toggled: false
    property bool initialized: false
    property int subHandle: -1

    function toggle() {
        BackendService.call("gamemode.toggle", {});
    }

    function setEnabled(value) {
        BackendService.call("gamemode.set", {enabled: value});
    }

    Component.onCompleted: {
        BackendService.call("gamemode.get", {}, (result, error) => {
            if (error || !result) {
                root.initialized = true;
                return;
            }
            root.toggled = result.enabled === true;
            root.initialized = true;
        });
        root.subHandle = BackendService.addSubscription(["gamemode"], (service, data) => {
            if (service !== "gamemode.state" || !data) return;
            Qt.callLater(() => {
                root.toggled = data.enabled === true;
            });
        });
    }
}