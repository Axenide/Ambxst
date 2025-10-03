pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.modules.bar.workspaces
import qs.modules.services

Singleton {
    id: root

    property var screens: ({})
    property var panels: ({})
    property var bars: ({})  // Registry for bar containers
    property string currentActiveModule: ""
    property string lastFocusedScreen: ""
    property bool contextMenuOpen: false

    function getForScreen(screenName) {
        if (!screens[screenName]) {
            screens[screenName] = screenPropertiesComponent.createObject(root, {
                screenName: screenName
            });
        }
        return screens[screenName];
    }

    function getForActive() {
        if (!Hyprland.focusedMonitor) {
            return null;
        }
        return getForScreen(Hyprland.focusedMonitor.name);
    }

    function registerPanel(screenName, panel) {
        panels[screenName] = panel;
    }

    function unregisterPanel(screenName) {
        delete panels[screenName];
    }

    function registerBar(screenName, barContainer) {
        bars[screenName] = barContainer;
    }

    function unregisterBar(screenName) {
        delete bars[screenName];
    }

    function getBarForScreen(screenName) {
        return bars[screenName] || null;
    }

    function setContextMenuOpen(isOpen) {
        contextMenuOpen = isOpen;
    }

    function setActiveModule(moduleName, skipFocusRestore) {
        if (!Hyprland.focusedMonitor) return;
        
        let focusedScreenName = Hyprland.focusedMonitor.name;
        
        let wasOpen = currentActiveModule !== "";
        
        clearAll();
        
        if (moduleName && moduleName !== "") {
            let focusedScreen = getForScreen(focusedScreenName);
            if (moduleName === "launcher") {
                focusedScreen.launcher = true;
            } else if (moduleName === "dashboard") {
                focusedScreen.dashboard = true;
                Notifications.hideAllPopups();
            } else if (moduleName === "overview") {
                focusedScreen.overview = true;
            } else if (moduleName === "powermenu") {
                focusedScreen.powermenu = true;
            }
            currentActiveModule = moduleName;
        } else {
            currentActiveModule = "";
            
            if (wasOpen && !skipFocusRestore) {
                Qt.callLater(() => {
                    if (Hyprland.focusedMonitor) {
                        let currentWorkspace = Hyprland.focusedMonitor.activeWorkspace?.id;
                        if (currentWorkspace) {
                            let windowInWorkspace = HyprlandData.windowList.find(win => 
                                win?.workspace?.id === currentWorkspace && 
                                Hyprland.focusedMonitor?.id === win.monitor
                            );
                            
                            if (windowInWorkspace) {
                                Hyprland.dispatch(`focuswindow address:${windowInWorkspace.address}`);
                            }
                        }
                    }
                });
            }
        }
        
        lastFocusedScreen = focusedScreenName;
    }

    function moveActiveModuleToFocusedScreen() {
        if (!Hyprland.focusedMonitor || !currentActiveModule) return;
        
        let newFocusedScreen = Hyprland.focusedMonitor.name;
        
        // Don't do anything if we're already on the same screen
        if (newFocusedScreen === lastFocusedScreen) return;
        
        // Clear all screens
        clearAll();
        
        // Set the active module on the newly focused screen
        let focusedScreen = getForScreen(newFocusedScreen);
        if (currentActiveModule === "launcher") {
            focusedScreen.launcher = true;
        } else if (currentActiveModule === "dashboard") {
            focusedScreen.dashboard = true;
        } else if (currentActiveModule === "overview") {
            focusedScreen.overview = true;
        } else if (currentActiveModule === "powermenu") {
            focusedScreen.powermenu = true;
        }
        
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
        }
    }

    function clearAll() {
        for (let screenName in screens) {
            let screenProps = screens[screenName];
            screenProps.launcher = false;
            screenProps.dashboard = false;
            screenProps.overview = false;
            screenProps.powermenu = false;
        }
    }

    // Monitor focus changes
    Connections {
        target: Hyprland
        function onFocusedMonitorChanged() {
            moveActiveModuleToFocusedScreen();
        }
    }
}