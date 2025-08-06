pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root

    property var screens: ({})
    property var panels: ({})

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

    Component {
        id: screenPropertiesComponent
        QtObject {
            property string screenName
            property bool launcher: false
            property bool dashboard: false
            property bool overview: false
        }
    }

    function clearAll() {
        for (let screenName in screens) {
            let screenProps = screens[screenName];
            screenProps.launcher = false;
            screenProps.dashboard = false;
            screenProps.overview = false;
        }
    }
}