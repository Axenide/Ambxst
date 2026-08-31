import QtQuick
import Quickshell

pragma Singleton

Singleton {
    id: root

    property bool active: false
    property int temp: 4500
    property int subHandle: -1

    function toggle() {
        BackendService.call("nightlight.toggle", {});
    }

    function setEnabled(value) {
        BackendService.call("nightlight.set", {enabled: value});
    }

    function setTemperature(value) {
        BackendService.call("nightlight.set", {temp: value});
    }

    function applyState(data) {
        if (!data) return;
        if (data.active !== undefined)
            root.active = data.active === true;
        if (data.temp !== undefined && data.temp > 0)
            root.temp = data.temp;
    }

    Component.onCompleted: {
        BackendService.call("nightlight.get", {}, (result, error) => {
            if (error || !result) return;
            Qt.callLater(() => root.applyState(result));
        });
        root.subHandle = BackendService.addSubscription(["nightlight"], (service, data) => {
            if (service !== "nightlight.state" || !data) return;
            Qt.callLater(() => root.applyState(data));
        });
    }
}