pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config

Singleton {
    id: root

    // Check if an app is pinned
    function isPinned(appId) {
        const pinnedApps = Config.pinnedApps?.apps || [];
        return pinnedApps.some(id => id.toLowerCase() === appId.toLowerCase());
    }

    // Toggle pin status of an app
    function togglePin(appId) {
        let pinnedApps = Config.pinnedApps?.apps || [];
        const normalizedAppId = appId.toLowerCase();
        
        if (isPinned(appId)) {
            // Remove from pinned
            Config.pinnedApps.apps = pinnedApps.filter(id => id.toLowerCase() !== normalizedAppId);
        } else {
            // Add to pinned
            Config.pinnedApps.apps = pinnedApps.concat([appId]);
        }
    }

    // Get desktop entry for an app
    function getDesktopEntry(appId) {
        if (!appId) return null;
        return DesktopEntries.heuristicLookup(appId) || null;
    }

    // Launch an app by its ID
    function launchApp(appId) {
        const entry = getDesktopEntry(appId);
        if (entry) {
            entry.execute();
        }
    }

    // Internal storage for app entries - prevents memory leaks
    property var _appCache: ({})
    property var _previousKeys: []

    // Main list of apps combining pinned and running apps
    property list<var> apps: []

    // Debounce timer to prevent rapid recalculations
    Timer {
        id: updateTimer
        interval: 100
        repeat: false
        onTriggered: root._updateApps()
    }

    // Trigger update when toplevels change
    Connections {
        target: ToplevelManager.toplevels
        function onObjectInsertedPost() {
            updateTimer.restart();
        }
        function onObjectRemovedPost() {
            updateTimer.restart();
        }
    }

    // Also update on config changes
    Connections {
        target: Config.pinnedApps ?? null
        function onAppsChanged() {
            updateTimer.restart();
        }
    }

    Connections {
        target: Config.dock ?? null
        function onIgnoredAppRegexesChanged() {
            updateTimer.restart();
        }
    }

    // Initial update
    Component.onCompleted: {
        _updateApps();
    }

    function _updateApps() {
        var map = new Map();

        // Get config values
        const pinnedApps = Config.pinnedApps?.apps ?? [];
        const ignoredRegexStrings = Config.dock?.ignoredAppRegexes ?? [];
        const ignoredRegexes = ignoredRegexStrings.map(pattern => new RegExp(pattern, "i"));

        // Add pinned apps first
        for (const appId of pinnedApps) {
            const key = appId.toLowerCase();
            if (!map.has(key)) {
                map.set(key, {
                    appId: appId,
                    pinned: true,
                    toplevels: []
                });
            }
        }

        // Collect running apps that are not pinned
        var unpinnedRunningApps = [];
        const toplevels = ToplevelManager.toplevels.values;
        for (let i = 0; i < toplevels.length; i++) {
            const toplevel = toplevels[i];
            // Skip ignored apps
            if (ignoredRegexes.some(re => re.test(toplevel.appId))) continue;
            
            const key = toplevel.appId.toLowerCase();
            
            // Check if this app is already in map (pinned)
            if (map.has(key)) {
                // Add toplevel to existing pinned app
                map.get(key).toplevels.push(toplevel);
            } else {
                // Track as unpinned running app
                const existing = unpinnedRunningApps.find(app => app.key === key);
                if (!existing) {
                    unpinnedRunningApps.push({
                        key: key,
                        appId: toplevel.appId,
                        toplevels: [toplevel]
                    });
                } else {
                    existing.toplevels.push(toplevel);
                }
            }
        }

        // Add separator only if there are pinned apps AND unpinned running apps
        if (pinnedApps.length > 0 && unpinnedRunningApps.length > 0) {
            map.set("SEPARATOR", { 
                appId: "SEPARATOR", 
                pinned: false, 
                toplevels: [] 
            });
        }

        // Add unpinned running apps to map
        for (const app of unpinnedRunningApps) {
            map.set(app.key, {
                appId: app.appId,
                pinned: false,
                toplevels: app.toplevels
            });
        }

        // Build new keys list
        var newKeys = Array.from(map.keys());

        // Destroy entries that are no longer needed
        for (const oldKey of _previousKeys) {
            if (!map.has(oldKey) && _appCache[oldKey]) {
                _appCache[oldKey].destroy();
                delete _appCache[oldKey];
            }
        }

        // Create or update entries
        var values = [];
        for (const [key, value] of map) {
            if (_appCache[key]) {
                // Update existing entry
                _appCache[key].toplevels = value.toplevels;
                _appCache[key].pinned = value.pinned;
                values.push(_appCache[key]);
            } else {
                // Create new entry
                const entry = appEntryComp.createObject(root, { 
                    appId: value.appId, 
                    toplevels: value.toplevels, 
                    pinned: value.pinned 
                });
                _appCache[key] = entry;
                values.push(entry);
            }
        }

        _previousKeys = newKeys;
        apps = values;
    }

    // Component for TaskbarAppEntry
    component TaskbarAppEntry: QtObject {
        required property string appId
        property var toplevels: []
        property int toplevelCount: toplevels.length
        property bool pinned
    }
    
    Component {
        id: appEntryComp
        TaskbarAppEntry {}
    }
}
