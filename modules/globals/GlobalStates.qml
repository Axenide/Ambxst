pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.modules.services

Singleton {
    id: root

    property var wallpaperManager: null

    // Persistent launcher state across monitors
    property string launcherSearchText: ""
    property int launcherSelectedIndex: -1

    function clearLauncherState() {
        launcherSearchText = "";
        launcherSelectedIndex = -1;
    }

    function getNotchOpen(screenName) {
        let visibilities = Visibilities.getForScreen(screenName);
        return visibilities.launcher || visibilities.dashboard || visibilities.overview;
    }

    function getActiveLauncher() {
        let active = Visibilities.getForActive();
        return active ? active.launcher : false;
    }

    function getActiveDashboard() {
        let active = Visibilities.getForActive();
        return active ? active.dashboard : false;
    }

    function getActiveOverview() {
        let active = Visibilities.getForActive();
        return active ? active.overview : false;
    }

    function getActiveNotchOpen() {
        let active = Visibilities.getForActive();
        return active ? (active.launcher || active.dashboard || active.overview) : false;
    }

    // Legacy properties for backward compatibility - use active screen
    readonly property bool notchOpen: getActiveNotchOpen()
    readonly property bool overviewOpen: getActiveOverview()
    readonly property bool launcherOpen: getActiveLauncher()
    readonly property bool dashboardOpen: getActiveDashboard()
}
