import QtQuick
import Quickshell

pragma Singleton

Singleton {
    id: root

    property bool inhibit: false
    property int subHandle: -1

    function toggle() {
        root.setInhibit(!root.inhibit);
    }

    function setInhibit(value) {
        BackendService.call("caffeine.set", {inhibit: value});
    }

    Component.onCompleted: {
        BackendService.call("caffeine.get", {}, (result, error) => {
            if (error || !result) return;
            Qt.callLater(() => { root.inhibit = result.inhibit === true; });
        });
        root.subHandle = BackendService.addSubscription(["caffeine"], (service, data) => {
            if (service !== "caffeine.state" || !data) return;
            Qt.callLater(() => { root.inhibit = data.inhibit === true; });
        });
    }
}