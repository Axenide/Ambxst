pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Hyprland._GlobalShortcuts
import qs.modules.globals
import qs.modules.services
import qs.config

import Quickshell.Io

QtObject {
    id: root

    readonly property string appId: "ambxst"
    readonly property string ipcPipe: "/tmp/ambxst_ipc.pipe"

    // High-performance Pipe Listener (Daemon mode)
    property Process pipeListener: Process {
        command: ["bash", "-c", "rm -f " + root.ipcPipe + "; mkfifo " + root.ipcPipe + "; tail -f " + root.ipcPipe]
        running: true
        
        stdout: SplitParser {
            onRead: data => {
                const cmd = data.trim();
                if (cmd !== "") {
                    root.run(cmd);
                }
            }
        }
    }

    function run(command) {
        console.log("IPC run command received:", command);
        switch (command) {
            // Launcher (Standalone Notch Module)
            case "launcher": toggleLauncher(); break;
            case "clipboard": toggleLauncherWithPrefix(1, Config.prefix.clipboard + " "); break;
            case "emoji": toggleLauncherWithPrefix(2, Config.prefix.emoji + " "); break;
            case "tmux": toggleLauncherWithPrefix(3, Config.prefix.tmux + " "); break;
            case "notes": toggleLauncherWithPrefix(4, Config.prefix.notes + " "); break;
            case "calculator": toggleLauncherWithPrefix(5, Config.prefix.calculator + " "); break;

            // Dashboard
            case "dashboard": toggleDashboardTab(0); break;
            case "wallpapers": toggleDashboardTab(1); break;
            case "assistant": toggleDashboardTab(3); break;
            case "dashboard-widgets": toggleDashboardTab(0); break;
            case "dashboard-wallpapers": toggleDashboardTab(1); break;
            case "dashboard-kanban": toggleDashboardTab(2); break;
            case "dashboard-assistant": toggleDashboardTab(3); break;
            case "dashboard-controls": toggleSettings(); break;

            // System
            case "overview": toggleSimpleModule("overview"); break;
            case "powermenu": toggleSimpleModule("powermenu"); break;
            case "tools": toggleSimpleModule("tools"); break;
            case "config": toggleSettings(); break;
            case "screenshot": Screenshot.initialize(); GlobalStates.screenshotToolVisible = true; break;
            case "screenrecord": ScreenRecorder.initialize(); GlobalStates.screenRecordToolVisible = true; break;
            case "lens": 
                Screenshot.initialize();
                Screenshot.captureMode = "lens";
                GlobalStates.screenshotToolVisible = true;
                break;
            case "lockscreen": GlobalStates.lockscreenVisible = true; break;
            
            // Media
            case "media-seek-backward": seekActivePlayer(-mediaSeekStepMs); break;
            case "media-seek-forward": seekActivePlayer(mediaSeekStepMs); break;
            case "media-play-pause": 
                if (MprisController.canTogglePlaying) MprisController.togglePlaying();
                break;
            case "media-next": MprisController.next(); break;
            case "media-prev": MprisController.previous(); break;
                
            default: console.warn("Unknown IPC command:", command);
        }
    }

    property IpcHandler ipcHandler: IpcHandler {
        target: "ambxst"

        function run(command: string) {
            root.run(command);
        }
    }

    function toggleSettings() {
        GlobalStates.settingsWindowVisible = !GlobalStates.settingsWindowVisible;
        if (GlobalStates.settingsWindowVisible) {
            Visibilities.setActiveModule("");
        }
    }

    function toggleSimpleModule(moduleName) {
        if (Visibilities.currentActiveModule === moduleName) {
            Visibilities.setActiveModule("");
        } else {
            Visibilities.setActiveModule(moduleName);
        }
    }

    function toggleLauncher() {
        const isActive = Visibilities.currentActiveModule === "launcher";
        if (isActive && GlobalStates.widgetsTabCurrentIndex === 0 && GlobalStates.launcherSearchText === "") {
            Visibilities.setActiveModule("");
        } else {
            GlobalStates.widgetsTabCurrentIndex = 0;
            GlobalStates.launcherSearchText = "";
            GlobalStates.launcherSelectedIndex = -1;
            if (!isActive) {
                Visibilities.setActiveModule("launcher");
            }
        }
    }

    function toggleLauncherWithPrefix(tabIndex, prefix) {
        const isActive = Visibilities.currentActiveModule === "launcher";
        const currentTab = GlobalStates.widgetsTabCurrentIndex;
        const currentText = GlobalStates.launcherSearchText;

        if (isActive && currentTab === tabIndex && (currentText === prefix || currentText === "")) {
            Visibilities.setActiveModule("");
            GlobalStates.clearLauncherState();
            return;
        }

        GlobalStates.widgetsTabCurrentIndex = tabIndex;
        GlobalStates.launcherSearchText = prefix;
        
        if (!isActive) {
            Visibilities.setActiveModule("launcher");
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
        
        if (isActive && GlobalStates.dashboardCurrentTab === 0 && GlobalStates.launcherSearchText === prefix) {
            Visibilities.setActiveModule("");
            GlobalStates.clearLauncherState();
            return;
        }

        GlobalStates.dashboardCurrentTab = 0;
        
        if (!isActive) {
            Visibilities.setActiveModule("dashboard");
            Qt.callLater(() => {
                GlobalStates.launcherSearchText = prefix;
            });
        } else {
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

    property GlobalShortcut shortcutOverview: GlobalShortcut {
        appid: root.appId
        name: "overview"
        description: "Toggle window overview"
        onPressed: toggleSimpleModule("overview")
    }

    property GlobalShortcut shortcutPowermenu: GlobalShortcut {
        appid: root.appId
        name: "powermenu"
        description: "Toggle power menu"
        onPressed: toggleSimpleModule("powermenu")
    }

    property GlobalShortcut shortcutTools: GlobalShortcut {
        appid: root.appId
        name: "tools"
        description: "Toggle tools menu"
        onPressed: toggleSimpleModule("tools")
    }

    property GlobalShortcut shortcutScreenshot: GlobalShortcut {
        appid: root.appId
        name: "screenshot"
        description: "Open screenshot tool"
        onPressed: GlobalStates.screenshotToolVisible = true
    }

    property GlobalShortcut shortcutScreenrecord: GlobalShortcut {
        appid: root.appId
        name: "screenrecord"
        description: "Open screen record tool"
        onPressed: GlobalStates.screenRecordToolVisible = true
    }

    property GlobalShortcut shortcutLens: GlobalShortcut {
        appid: root.appId
        name: "lens"
        description: "Open Google Lens (screenshot)"
        onPressed: {
            Screenshot.captureMode = "lens";
            GlobalStates.screenshotToolVisible = true;
        }
    }

    // Launcher standalone shortcuts
    property GlobalShortcut shortcutLauncher: GlobalShortcut {
        appid: root.appId
        name: "launcher"
        description: "Open standalone launcher"
        onPressed: toggleLauncher()
    }

    property GlobalShortcut shortcutClipboard: GlobalShortcut {
        appid: root.appId
        name: "clipboard"
        description: "Open launcher clipboard"
        onPressed: toggleLauncherWithPrefix(1, Config.prefix.clipboard + " ")
    }

    property GlobalShortcut shortcutEmoji: GlobalShortcut {
        appid: root.appId
        name: "emoji"
        description: "Open launcher emoji picker"
        onPressed: toggleLauncherWithPrefix(2, Config.prefix.emoji + " ")
    }

    property GlobalShortcut shortcutTmux: GlobalShortcut {
        appid: root.appId
        name: "tmux"
        description: "Open launcher tmux sessions"
        onPressed: toggleLauncherWithPrefix(3, Config.prefix.tmux + " ")
    }

    property GlobalShortcut shortcutNotes: GlobalShortcut {
        appid: root.appId
        name: "notes"
        description: "Open launcher notes"
        onPressed: toggleLauncherWithPrefix(4, Config.prefix.notes + " ")
    }

    property GlobalShortcut shortcutCalculator: GlobalShortcut {
        appid: root.appId
        name: "calculator"
        description: "Open launcher calculator"
        onPressed: toggleLauncherWithPrefix(5, Config.prefix.calculator + " ")
    }

    // Dashboard shortcuts
    property GlobalShortcut shortcutDashboard: GlobalShortcut {
        appid: root.appId
        name: "dashboard"
        description: "Open dashboard widgets tab"
        onPressed: toggleDashboardTab(0)
    }

    property GlobalShortcut shortcutWallpapers: GlobalShortcut {
        appid: root.appId
        name: "wallpapers"
        description: "Open dashboard wallpapers tab"
        onPressed: toggleDashboardTab(1)
    }

    property GlobalShortcut shortcutAssistant: GlobalShortcut {
        appid: root.appId
        name: "assistant"
        description: "Open dashboard assistant tab"
        onPressed: toggleDashboardTab(3)
    }

    property GlobalShortcut shortcutDashboardControls: GlobalShortcut {
        appid: root.appId
        name: "dashboard-controls"
        description: "Open dashboard controls tab"
        onPressed: toggleSettings()
    }

    // Media player shortcuts
    property GlobalShortcut shortcutMediaSeekBackward: GlobalShortcut {
        appid: root.appId
        name: "media-seek-backward"
        description: "Seek backward in media player"
        onPressed: seekActivePlayer(-mediaSeekStepMs)
    }

    property GlobalShortcut shortcutMediaSeekForward: GlobalShortcut {
        appid: root.appId
        name: "media-seek-forward"
        description: "Seek forward in media player"
        onPressed: seekActivePlayer(mediaSeekStepMs)
    }

    property GlobalShortcut shortcutMediaPlayPause: GlobalShortcut {
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
