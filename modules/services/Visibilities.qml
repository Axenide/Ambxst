pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.modules.services

Singleton {
    id: root

    property var screens: ({})
    property var panels: ({})
    property var bars: ({})
    property var barPanels: ({})
    property var notches: ({})
    property var notchPanels: ({})
    property var docks: ({})
    property var dockPanels: ({})
    property string currentActiveModule: ""
    property string lastFocusedScreen: ""
    property var contextMenu: null
    property bool playerMenuOpen: false
    readonly property var moduleNames: ["launcher", "dashboard", "overview", "powermenu", "tools", "presets"]

    function setContextMenu(menu) {
        contextMenu = menu;
    }

    // Pure getter — never creates state. Callers that need to write (or that
    // require a non-null object) must use ensureForScreen().
    function getForScreen(screenName) {
        return screens[screenName] || null;
    }

    // State-creating variant for writers: returns (creating if needed) the
    // per-screen visibility state object.
    function ensureForScreen(screenName) {
        if (!screens[screenName]) {
            screens[screenName] = screenPropertiesComponent.createObject(root, {
                screenName: screenName
            });
        }
        return screens[screenName];
    }

    function getForActive() {
        if (!AxctlService.focusedMonitor) {
            return null;
        }
        return screens[AxctlService.focusedMonitor.name] || null;
    }

    // Destroy per-screen state when its screen is unplugged, so stale entries
    // can't keep popups/loaders alive or leak forever.
    function pruneStaleScreens() {
        const current = {};
        const qsScreens = Quickshell.screens;
        for (let i = 0; i < qsScreens.length; i++) {
            current[qsScreens[i].name] = true;
        }
        for (const name in screens) {
            if (!current[name]) {
                screens[name].destroy();
                screens = _updateMap(screens, name, null);
            }
        }
    }

    Connections {
        target: Quickshell
        ignoreUnknownSignals: true
        function onScreensChanged() {
            root.pruneStaleScreens();
        }
    }

    // Helper to clone map and trigger update
    function _updateMap(map, key, value) {
        var newMap = {};
        for (var k in map) {
            newMap[k] = map[k];
        }
        if (value === null) {
            delete newMap[key];
        } else {
            newMap[key] = value;
        }
        return newMap;
    }

    function registerPanel(screenName, panel) {
        panels = _updateMap(panels, screenName, panel);
    }

    function unregisterPanel(screenName) {
        panels = _updateMap(panels, screenName, null);
    }

    function registerBar(screenName, barContainer) {
        bars = _updateMap(bars, screenName, barContainer);
    }

    function unregisterBar(screenName) {
        bars = _updateMap(bars, screenName, null);
    }

    function getBarForScreen(screenName) {
        return bars[screenName] || null;
    }

    function registerBarPanel(screenName, barPanel) {
        barPanels = _updateMap(barPanels, screenName, barPanel);
    }

    function unregisterBarPanel(screenName) {
        barPanels = _updateMap(barPanels, screenName, null);
    }

    function getBarPanelForScreen(screenName) {
        return barPanels[screenName] || null;
    }

    function registerNotch(screenName, notchContainer) {
        notches = _updateMap(notches, screenName, notchContainer);
    }

    function unregisterNotch(screenName) {
        notches = _updateMap(notches, screenName, null);
    }

    function getNotchForScreen(screenName) {
        return notches[screenName] || null;
    }

    function registerNotchPanel(screenName, notchPanel) {
        notchPanels = _updateMap(notchPanels, screenName, notchPanel);
    }

    function unregisterNotchPanel(screenName) {
        notchPanels = _updateMap(notchPanels, screenName, null);
    }

    function getNotchPanelForScreen(screenName) {
        return notchPanels[screenName] || null;
    }

    function registerDock(screenName, dockContainer) {
        docks = _updateMap(docks, screenName, dockContainer);
    }

    function unregisterDock(screenName) {
        docks = _updateMap(docks, screenName, null);
    }

    function getDockForScreen(screenName) {
        return docks[screenName] || null;
    }

    function registerDockPanel(screenName, dockPanel) {
        dockPanels = _updateMap(dockPanels, screenName, dockPanel);
    }

    function unregisterDockPanel(screenName) {
        dockPanels = _updateMap(dockPanels, screenName, null);
    }

    function getDockPanelForScreen(screenName) {
        return dockPanels[screenName] || null;
    }

    function setActiveModule(moduleName) {
        const focusedMonitor = AxctlService.focusedMonitor;
        if (!focusedMonitor)
            return;

        const focusedScreenName = focusedMonitor.name;

        // Save the currently focused app's address BEFORE clearing modules,
        // because clearAll will trigger screenNotchOpen → false → keyboardFocus → None,
        // and the compositor may not automatically restore focus when we're done.
        if (moduleName) {
            AxctlService.saveFocus();
        }

        clearAll();

        if (moduleName) {
            currentActiveModule = moduleName;
            applyActiveModuleToScreen(focusedScreenName);
        } else {
            currentActiveModule = "";
        }

        lastFocusedScreen = focusedScreenName;

        // After all modules have been closed and the shell has released exclusive
        // keyboard focus, explicitly tell the compositor to refocus the saved client.
        // This ensures the previously active application regains focus immediately
        // without requiring the user to click back into it.
        if (!moduleName) {
            AxctlService.restoreFocus();
        }
    }

    function moveActiveModuleToFocusedScreen() {
        const focusedMonitor = AxctlService.focusedMonitor;
        if (!focusedMonitor || !currentActiveModule)
            return;

        const newFocusedScreen = focusedMonitor.name;
        if (newFocusedScreen === lastFocusedScreen)
            return;

        clearAll();
        applyActiveModuleToScreen(newFocusedScreen);
        lastFocusedScreen = newFocusedScreen;
    }

    Component {
        id: screenPropertiesComponent
        QtObject {
            property string screenName
            property bool launcher: false
            property bool dashboard: false
            property bool overview: false
            property bool powermenu: false
            property bool tools: false
            property bool presets: false
        }
    }

    function clearAll() {
        for (const screenName in screens) {
            const screenProps = screens[screenName];
            for (let i = 0; i < moduleNames.length; i++) {
                screenProps[moduleNames[i]] = false;
            }
        }
    }

    function applyActiveModuleToScreen(screenName) {
        if (!currentActiveModule)
            return;

        const screenProps = ensureForScreen(screenName);
        if (moduleNames.indexOf(currentActiveModule) !== -1) {
            screenProps[currentActiveModule] = true;
        }
    }

    // Monitor focus changes
    Connections {
        target: AxctlService
        function onFocusedMonitorChanged() {
            moveActiveModuleToFocusedScreen();
        }
    }
}
