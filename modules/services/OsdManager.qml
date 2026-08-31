pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

/**
 * Tracks which on-screen-display (OSD) instance is currently visible on
 * each screen so volume, brightness and microphone indicators do not
 * stack on top of each other.
 */
Singleton {
    id: root

    property var _active: ({})

    function showOsd(target, screen) {
        const key = _key(screen);
        const current = _active[key];
        if (current && current !== target) {
            current.visible = false;
        }
        _active[key] = target;
        target.visible = true;
    }

    function hideOsd(target, screen) {
        const key = _key(screen);
        if (_active[key] === target) {
            _active[key] = null;
            target.visible = false;
        }
    }

    function _key(screen) {
        return (screen && screen.name) ? screen.name : "_default";
    }
}