pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root
    property bool sidebarLeftOpen: false
    property bool sidebarRightOpen: false
    property bool overviewOpen: false
    property bool launcherOpen: false
    property bool dashboardOpen: false
    property bool workspaceShowNumbers: false
    property bool superReleaseMightTrigger: true
    property int roundness: 16
    onSuperReleaseMightTriggerChanged: {
        workspaceShowNumbersTimer.stop();
    }

    Timer {
        id: workspaceShowNumbersTimer
        interval: 300 // ConfigOptions.bar.workspaces.showNumberDelay
        repeat: false
        onTriggered: {
            workspaceShowNumbers = true;
        }
    }

    GlobalShortcut {
        name: "workspaceNumber"
        description: qsTr("Hold to show workspace numbers, release to show icons")

        onPressed: {
            workspaceShowNumbersTimer.start();
        }
        onReleased: {
            workspaceShowNumbersTimer.stop();
            workspaceShowNumbers = false;
        }
    }

    GlobalShortcut {
        name: "toggleDashboard"
        description: qsTr("Toggle dashboard")

        onPressed: {
            dashboardOpen = !dashboardOpen;
        }
    }
}
