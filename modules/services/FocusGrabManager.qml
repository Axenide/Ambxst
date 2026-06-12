pragma Singleton
import QtQuick
import Quickshell

// Compositor-agnostic focus grab coordinator.
// Tracks active focus grabs and provides a backdrop-click clearing mechanism.
// When any grab is active, consumers (e.g., UnifiedShellPanel) can expand their
// input mask to full-screen and show a backdrop MouseArea that calls clearTopGrab().
Singleton {
    id: root

    // Whether any focus grab is currently active
    property int _activeCount: 0
    readonly property bool hasActiveGrab: _activeCount > 0

    // Internal storage: grabId -> callback
    property var _grabs: ({})
    // Ordered list for stack behavior (last-in-first-cleared)
    property var _grabOrder: []

    function requestGrab(grabId, clearCallback) {
        if (_grabs[grabId] === undefined) {
            _grabOrder = [..._grabOrder, grabId];
            _activeCount++;
        }
        let updated = {};
        Object.keys(_grabs).forEach(k => { updated[k] = _grabs[k]; });
        updated[grabId] = clearCallback;
        _grabs = updated;
    }

    function releaseGrab(grabId) {
        if (_grabs[grabId] !== undefined) {
            let updated = {};
            Object.keys(_grabs).forEach(k => {
                if (k !== grabId) updated[k] = _grabs[k];
            });
            _grabs = updated;
            _grabOrder = _grabOrder.filter(id => id !== grabId);
            _activeCount = Math.max(0, _activeCount - 1);
        }
    }

    // Clear the most recent (top) grab — typically called by a backdrop MouseArea
    function clearTopGrab() {
        if (_grabOrder.length === 0) return;
        const topId = _grabOrder[_grabOrder.length - 1];
        const callback = _grabs[topId];
        releaseGrab(topId);
        if (callback) {
            Qt.callLater(callback);
        }
    }
}
