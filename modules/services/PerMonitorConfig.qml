pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

/*!
    PerMonitorConfig.qml — Per-monitor configuration overrides.

    Reads ~/.config/ambxst/config/monitors.json for monitor-specific
    overrides of global config values. Currently supports:
    - bar.position
    - notch.position
    - dock.position

    Example monitors.json:
    {
      "DP-1": {
        "bar": { "position": "bottom" },
        "notch": { "position": "bottom" }
      },
      "HDMI-A-1": {
        "bar": { "position": "left" }
      }
    }
*/
Singleton {
    id: root

    property string configPath: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ambxst/config/monitors.json"

    // Internal cache of the parsed JSON
    property var _data: ({})
    property bool _ready: false

    FileView {
        id: loader
        path: root.configPath
        watchChanges: true
        onLoaded: {
            root._parse(loader.text());
        }
        onFileChanged: {
            loader.reload();
        }
    }

    Component.onCompleted: {
        // Delay init so FileView has a chance to load
        Qt.callLater(() => {
            if (!root._ready) {
                root._parse(loader.text());
            }
        });
    }

    function _parse(text) {
        if (!text || text.trim().length === 0) {
            root._data = {};
            root._ready = true;
            return;
        }
        try {
            root._data = JSON.parse(text);
            root._ready = true;
        } catch (e) {
            console.warn("PerMonitorConfig: Failed to parse monitors.json:", e);
            root._data = {};
            root._ready = true;
        }
    }

    /*! Resolve a per-monitor override.
        @param screenName  Monitor name (e.g. "DP-1")
        @param domain      Config domain (e.g. "bar", "notch", "dock")
        @param key         Property key (e.g. "position")
        @param defaultValue Fallback value if no override exists
        @return The override value, or defaultValue if none exists.
    */
    function resolve(screenName, domain, key, defaultValue) {
        if (!root._ready || !screenName) return defaultValue;
        const monitor = root._data[screenName];
        if (!monitor) return defaultValue;
        const dom = monitor[domain];
        if (!dom) return defaultValue;
        const val = dom[key];
        return val !== undefined ? val : defaultValue;
    }
}
