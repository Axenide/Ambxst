pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.modules.services

Singleton {
    id: root

    // Check pin status
    function isPinned(appId) {
        const pinnedApps = Config.pinnedApps?.apps || [];
        return pinnedApps.some(id => id.toLowerCase() === appId.toLowerCase());
    }

    // Toggle pin
    function togglePin(appId) {
        let pinnedApps = Config.pinnedApps?.apps || [];
        const normalizedAppId = appId.toLowerCase();
        
        if (isPinned(appId)) {
            // Unpin
            Config.pinnedApps.apps = pinnedApps.filter(id => id.toLowerCase() !== normalizedAppId);
        } else {
            // Pin
            Config.pinnedApps.apps = pinnedApps.concat([appId]);
        }

        // Persist changes
        Config.savePinnedApps();
    }

    // Get entry
    function getDesktopEntry(appId) {
        if (!appId) return null;
        return DesktopEntries.heuristicLookup(appId) || null;
    }

    // Launch
    function launchApp(appId) {
        const entry = getDesktopEntry(appId);
        if (entry) {
            AppSearch.launchApp(entry);
        }
    }

    // Cache entries
    property var _appCache: ({})
    property var _previousKeys: []

    // Cached ignored-app regexes (keyed by the source string list)
    property var _ignoredRegexKey: null
    property var _ignoredRegexCache: null

    // Combined app list
    property list<var> apps: []

    // Debounce update
    Timer {
        id: updateTimer
        interval: 100
        repeat: false
        onTriggered: root._updateApps()
    }

    // Update on toplevel change
    Connections {
        target: ToplevelManager.toplevels
        function onObjectInsertedPost() {
            updateTimer.restart();
        }
        function onObjectRemovedPost() {
            updateTimer.restart();
        }
    }

    // Update on config change
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

    // Init
    Component.onCompleted: {
        _updateApps();
    }

    function _updateApps() {
        var map = new Map();

        // Get config
        const pinnedApps = Config.pinnedApps?.apps ?? [];
        const ignoredRegexStrings = Config.dock?.ignoredAppRegexes ?? [];

        // Cache compiled regexes keyed on the config array; recompiling on every
        // rebuild (up to 10x/sec during window churn) is pure waste.
        let ignoredRegexes = root._ignoredRegexCache;
        if (!ignoredRegexes || root._ignoredRegexKey !== ignoredRegexStrings) {
            ignoredRegexes = ignoredRegexStrings.map(pattern => new RegExp(pattern, "i"));
            root._ignoredRegexKey = ignoredRegexStrings;
            root._ignoredRegexCache = ignoredRegexes;
        }

        // Add pinned
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

        // Collect unpinned
        var unpinnedRunningApps = new Map();
        const toplevels = ToplevelManager.toplevels.values;
        for (let i = 0; i < toplevels.length; i++) {
            const toplevel = toplevels[i];
            // Skip ignored
            if (ignoredRegexes.some(re => re.test(toplevel.appId))) continue;
            
            const key = toplevel.appId.toLowerCase();
            
            // Check if pinned
            if (map.has(key)) {
                // Add to pinned app
                map.get(key).toplevels.push(toplevel);
            } else {
                // Track unpinned (Map lookup is O(1), not O(n) like the old
                // linear scan over the array of unique apps)
                const existing = unpinnedRunningApps.get(key);
                if (!existing) {
                    unpinnedRunningApps.set(key, {
                        key: key,
                        appId: toplevel.appId,
                        toplevels: [toplevel]
                    });
                } else {
                    existing.toplevels.push(toplevel);
                }
            }
        }

        // Add separator if needed
        if (pinnedApps.length > 0 && unpinnedRunningApps.length > 0) {
            map.set("SEPARATOR", { 
                appId: "SEPARATOR", 
                pinned: false, 
                toplevels: [] 
            });
        }

        // Add unpinned to map
        for (const [appKey, app] of unpinnedRunningApps) {
            map.set(appKey, {
                appId: app.appId,
                pinned: false,
                toplevels: app.toplevels
            });
        }

        // New keys list
        var newKeys = Array.from(map.keys());

        // Cleanup entries
        for (const oldKey of _previousKeys) {
            if (!map.has(oldKey) && _appCache[oldKey]) {
                _appCache[oldKey].destroy();
                delete _appCache[oldKey];
            }
        }

        // Sync entries
        var values = [];
        for (const [key, value] of map) {
            if (_appCache[key]) {
                // Update entry — only assign when content actually changed, so
                // consumers don't get spurious change notifications on every
                // rebuild (rebuilds run up to 10x/sec during window churn).
                if (!_arraysEqual(_appCache[key].toplevels, value.toplevels)) {
                    _appCache[key].toplevels = value.toplevels;
                }
                if (_appCache[key].pinned !== value.pinned) {
                    _appCache[key].pinned = value.pinned;
                }
                values.push(_appCache[key]);
            } else {
                // Create entry
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

        // Reassign `apps` only when the entry list itself changed (add/remove/
        // reorder); per-entry updates propagate via their own change signals.
        // This avoids a full model re-evaluation cascade on every rebuild.
        let listChanged = root.apps.length !== values.length;
        if (!listChanged) {
            for (let i = 0; i < root.apps.length; i++) {
                if (root.apps[i] !== values[i]) {
                    listChanged = true;
                    break;
                }
            }
        }
        if (listChanged)
            root.apps = values;
    }

    function _arraysEqual(a, b) {
        if (a === b) return true;
        if (!a || !b || a.length !== b.length) return false;
        for (let i = 0; i < a.length; i++) {
            if (a[i] !== b[i]) return false;
        }
        return true;
    }

    // App entry component
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
