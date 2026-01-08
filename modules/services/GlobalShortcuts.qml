import QtQuick
import Quickshell.Hyprland._GlobalShortcuts
import qs.modules.globals
import qs.modules.services
import qs.config

Item {
    id: root

    readonly property string appId: "ambxst"
    readonly property int mediaSeekStepMs: 5000

    function toggleSimpleModule(moduleName) {
        if (Visibilities.currentActiveModule === moduleName) {
            Visibilities.setActiveModule("");
        } else {
            Visibilities.setActiveModule(moduleName);
        }
    }

    function toggleDashboardTab(tabIndex) {
        const isActive = Visibilities.currentActiveModule === "dashboard";
        
        // Special handling for widgets tab (launcher)
        if (tabIndex === 0) {
            if (isActive && GlobalStates.dashboardCurrentTab === 0 && GlobalStates.launcherSearchText === "") {
                // Only toggle off if we're already in launcher without prefix
                Visibilities.setActiveModule("");
                return;
            }
            
            // Otherwise, always go to launcher (clear any prefix and ensure tab 0)
            GlobalStates.dashboardCurrentTab = 0;
            GlobalStates.launcherSearchText = "";
            GlobalStates.launcherSelectedIndex = -1;
            if (!isActive) {
                Visibilities.setActiveModule("dashboard");
            }
            return;
        }
        
        // For other tabs, normal toggle behavior
        if (isActive && GlobalStates.dashboardCurrentTab === tabIndex) {
            Visibilities.setActiveModule("");
            return;
        }

        GlobalStates.dashboardCurrentTab = tabIndex;
        if (!isActive) {
            Visibilities.setActiveModule("dashboard");
        }
    }

    function toggleDashboardWithPrefix(prefix) {
        const isActive = Visibilities.currentActiveModule === "dashboard";
        
        // Check if dashboard is already open with this prefix
        if (isActive && GlobalStates.dashboardCurrentTab === 0 && GlobalStates.launcherSearchText === prefix) {
            // Toggle off - close dashboard
            Visibilities.setActiveModule("");
            GlobalStates.clearLauncherState();
            return;
        }

        // Always go to widgets tab first
        GlobalStates.dashboardCurrentTab = 0;
        
        if (!isActive) {
            // Open dashboard first, then set prefix after a brief delay
            Visibilities.setActiveModule("dashboard");
            Qt.callLater(() => {
                GlobalStates.launcherSearchText = prefix;
            });
        } else {
            // Dashboard already open, just set the prefix
            GlobalStates.launcherSearchText = prefix;
        }
    }

    function seekActivePlayer(offset) {
        const player = MprisController.activePlayer;
        if (!player || !player.canSeek) {
            return;
        }

        const maxLength = typeof player.length === "number" && !isNaN(player.length)
                ? player.length
                : Number.MAX_SAFE_INTEGER;
        const clamped = Math.max(0, Math.min(maxLength, player.position + offset));
        player.position = clamped;
    }

    GlobalShortcut {
        appid: root.appId
        name: "overview"
        description: "Toggle window overview"

        onPressed: toggleSimpleModule("overview")
    }

    GlobalShortcut {
        appid: root.appId
        name: "powermenu"
        description: "Toggle power menu"

        onPressed: toggleSimpleModule("powermenu")
    }

    GlobalShortcut {
        appid: root.appId
        name: "tools"
        description: "Toggle tools menu"

        onPressed: toggleSimpleModule("tools")
    }

    GlobalShortcut {
        appid: root.appId
        name: "screenshot"
        description: "Open screenshot tool"

        onPressed: GlobalStates.screenshotToolVisible = true
    }

    // Dashboard tab shortcuts
    GlobalShortcut {
        appid: root.appId
        name: "dashboard-widgets"
        description: "Open dashboard widgets tab (includes app launcher)"

        onPressed: toggleDashboardTab(0)
    }

    GlobalShortcut {
        appid: root.appId
        name: "dashboard-clipboard"
        description: "Open dashboard clipboard (via prefix)"

        onPressed: toggleDashboardWithPrefix(Config.prefix.clipboard + " ")
    }

    GlobalShortcut {
        appid: root.appId
        name: "dashboard-emoji"
        description: "Open dashboard emoji picker (via prefix)"

        onPressed: toggleDashboardWithPrefix(Config.prefix.emoji + " ")
    }

    GlobalShortcut {
        appid: root.appId
        name: "dashboard-tmux"
        description: "Open dashboard tmux sessions (via prefix)"

        onPressed: toggleDashboardWithPrefix(Config.prefix.tmux + " ")
    }

    GlobalShortcut {
        appid: root.appId
        name: "dashboard-kanban"
        description: "Open dashboard kanban tab"

        onPressed: toggleDashboardTab(2)
    }

    GlobalShortcut {
        appid: root.appId
        name: "dashboard-wallpapers"
        description: "Open dashboard wallpapers tab"

        onPressed: toggleDashboardTab(1)
    }

    GlobalShortcut {
        appid: root.appId
        name: "dashboard-notes"
        description: "Open dashboard notes (via prefix)"

        onPressed: toggleDashboardWithPrefix(Config.prefix.notes + " ")
    }

    GlobalShortcut {
        appid: root.appId
        name: "dashboard-assistant"
        description: "Open dashboard assistant tab"

        onPressed: toggleDashboardTab(3)
    }

    GlobalShortcut {
        appid: root.appId
        name: "dashboard-controls"
        description: "Open dashboard controls tab"

        onPressed: toggleDashboardTab(4)
    }

    // Media player shortcuts
    GlobalShortcut {
        appid: root.appId
        name: "media-seek-backward"
        description: "Seek backward in media player"

        onPressed: seekActivePlayer(-mediaSeekStepMs)
    }

    GlobalShortcut {
        appid: root.appId
        name: "media-seek-forward"
        description: "Seek forward in media player"

        onPressed: seekActivePlayer(mediaSeekStepMs)
    }

    GlobalShortcut {
        appid: root.appId
        name: "media-play-pause"
        description: "Toggle play/pause in media player"

        onPressed: {
            if (MprisController.canTogglePlaying) {
                MprisController.togglePlaying();
            }
        }
    }
}
