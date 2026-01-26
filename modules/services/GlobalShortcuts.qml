import QtQuick
import Quickshell.Hyprland._GlobalShortcuts
import qs.modules.globals
import qs.modules.services
import qs.config

import Quickshell.Io

Item {
    id: root

    readonly property string appId: "ambxst"
    readonly property string ipcPipe: "/tmp/ambxst_ipc.pipe"

    // High-performance Pipe Listener (Daemon mode)
    // Creates a named pipe and listens for commands continuously
    Process {
        id: pipeListener
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

    property var pendingAppConfig: null
    property string pendingCurrentSpecial: ""

    Process {
        id: appClientsProcess
        command: ["hyprctl", "-j", "clients"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                root.handleAppClients(text);
            }
        }
    }

    Process {
        id: appMonitorsProcess
        command: ["hyprctl", "-j", "monitors"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                root.handleAppMonitors(text);
            }
        }
    }

    Process {
        id: appDispatchProcess
    }

    Process {
        id: specialToggleMonitorsProcess
        command: ["hyprctl", "-j", "monitors"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                root.handleSpecialToggleMonitors(text);
            }
        }
    }

    Process {
        id: specialToggleDispatchProcess
    }

    function run(command) {
        console.log("IPC run command received:", command);
        switch (command) {
            // Dashboard
            case "dashboard-widgets": toggleDashboardTab(0); break;
            case "dashboard-wallpapers": toggleDashboardTab(1); break;
            case "dashboard-kanban": toggleDashboardTab(2); break;
            case "dashboard-assistant": toggleDashboardTab(3); break;
            case "dashboard-controls": toggleDashboardTab(4); break;
            case "dashboard-clipboard": toggleDashboardWithPrefix(Config.prefix.clipboard + " "); break;
            case "dashboard-emoji": toggleDashboardWithPrefix(Config.prefix.emoji + " "); break;
            case "dashboard-tmux": toggleDashboardWithPrefix(Config.prefix.tmux + " "); break;
            case "dashboard-notes": toggleDashboardWithPrefix(Config.prefix.notes + " "); break;
            
            // System
            case "overview": toggleSimpleModule("overview"); break;
            case "powermenu": toggleSimpleModule("powermenu"); break;
            case "tools": toggleSimpleModule("tools"); break;
            case "config": GlobalStates.settingsVisible = !GlobalStates.settingsVisible; break;
            case "screenshot": GlobalStates.screenshotToolVisible = true; break;
            case "screenrecord": GlobalStates.screenRecordToolVisible = true; break;
            case "lens": 
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

            // Apps
            case "app-music": runAppShortcut("music"); break;
            case "app-communication": runAppShortcut("communication"); break;
            case "app-browser": runAppShortcut("browser"); break;
            case "app-files": runAppShortcut("files"); break;
            case "app-terminal": runAppShortcut("terminal"); break;

            case "special-toggle": toggleSpecialWorkspace(); break;
                
            default: console.warn("Unknown IPC command:", command);
        }
    }

    IpcHandler {
        target: "ambxst"

        function run(command: string) {
            root.run(command);
        }
    }

    function normalizeWorkspaceName(workspace) {
        if (!workspace)
            return "";
        if (workspace.startsWith("special:"))
            return workspace;
        return "special:" + workspace;
    }

    function specialWorkspaceName(workspace) {
        if (!workspace)
            return "";
        if (workspace.startsWith("special:"))
            return workspace.slice("special:".length);
        return workspace;
    }

    function runAppShortcut(appKey) {
        const appConfig = Config.apps && Config.apps[appKey] ? Config.apps[appKey] : null;
        if (!appConfig) {
            console.warn("App shortcut config missing:", appKey);
            return;
        }
        if (appClientsProcess.running || appMonitorsProcess.running) {
            return;
        }
        pendingAppConfig = appConfig;
        appMonitorsProcess.running = true;
    }

    function handleAppMonitors(rawText) {
        let currentSpecial = "";
        try {
            const data = JSON.parse(rawText || "[]");
            if (data.length > 0) {
                const mon = data[0];
                const special = mon && mon.specialWorkspace ? mon.specialWorkspace : null;
                if (special && special.name) {
                    currentSpecial = special.name;
                }
            }
        } catch (e) {
            console.warn("Failed to parse Hyprland monitors:", e);
        }

        pendingCurrentSpecial = currentSpecial || "";
        appClientsProcess.running = true;
    }

    function handleAppClients(rawText) {
        const appConfig = pendingAppConfig;
        pendingAppConfig = null;
        if (!appConfig)
            return;

        let clients = [];
        try {
            clients = JSON.parse(rawText) || [];
        } catch (e) {
            console.warn("Failed to parse Hyprland clients:", e);
            return;
        }

        const matchValue = (appConfig.windowClass || "").toLowerCase();
        const targetWorkspace = normalizeWorkspaceName(appConfig.workspace);
        const currentSpecial = pendingCurrentSpecial;
        pendingCurrentSpecial = "";
        let matchedClient = null;

        if (matchValue.length > 0) {
            for (let i = 0; i < clients.length; i++) {
                const client = clients[i];
                const className = ((client && (client.class || client.initialClass)) || "").toLowerCase();
                if (className && className.indexOf(matchValue) !== -1) {
                    matchedClient = client;
                    break;
                }
            }
        }

        if (matchedClient && matchedClient.address) {
            const commands = [];
            const specialName = specialWorkspaceName(targetWorkspace);
            const clientWorkspace = matchedClient.workspace && matchedClient.workspace.name
                ? String(matchedClient.workspace.name)
                : "";

            if (targetWorkspace) {
                commands.push(`movetoworkspacesilent ${targetWorkspace}, address:${matchedClient.address}`);

                if (specialName.length > 0) {
                    if (currentSpecial && currentSpecial !== targetWorkspace) {
                        commands.push(`togglespecialworkspace ${currentSpecial.slice(8)}`);
                    }
                    commands.push(`togglespecialworkspace ${specialName}`);
                } else {
                    commands.push(`workspace ${targetWorkspace}`);
                }
            }

            if (!(clientWorkspace.startsWith("special:") && clientWorkspace === targetWorkspace)) {
                commands.push(`focuswindow address:${matchedClient.address}`);
            }

            runHyprBatch(commands);
            return;
        }

        if (!appConfig.command || appConfig.command.trim().length === 0) {
            console.warn("App command missing for shortcut:", appConfig.label || "app");
            return;
        }

        const launchCommands = [];
        if (targetWorkspace) {
            if (currentSpecial && currentSpecial !== targetWorkspace) {
                launchCommands.push(`togglespecialworkspace ${currentSpecial.slice(8)}`);
            }
            launchCommands.push(`workspace ${targetWorkspace}`);
            launchCommands.push(`exec [workspace ${targetWorkspace}] ${appConfig.command}`);
        } else {
            launchCommands.push(`exec ${appConfig.command}`);
        }
        runHyprBatch(launchCommands);
    }

    function runHyprBatch(commands) {
        if (!commands || commands.length === 0)
            return;
        const batch = commands.map(cmd => "dispatch " + cmd).join("; ");
        appDispatchProcess.command = ["hyprctl", "--batch", batch];
        appDispatchProcess.running = true;
    }

    function toggleSpecialWorkspace() {
        if (specialToggleMonitorsProcess.running) {
            return;
        }
        specialToggleMonitorsProcess.running = true;
    }

    function handleSpecialToggleMonitors(rawText) {
        let currentSpecial = "";
        try {
            const data = JSON.parse(rawText || "[]");
            if (data.length > 0) {
                const mon = data[0];
                const special = mon && mon.specialWorkspace ? mon.specialWorkspace : null;
                if (special && special.name) {
                    currentSpecial = special.name;
                }
            }
        } catch (e) {
            console.warn("Failed to parse Hyprland monitors for special toggle:", e);
        }

        const specialName = currentSpecial && currentSpecial.startsWith("special:")
            ? currentSpecial.slice(8)
            : "special";
        specialToggleDispatchProcess.command = ["hyprctl", "dispatch", "togglespecialworkspace", specialName];
        specialToggleDispatchProcess.running = true;
    }

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

    GlobalShortcut {
        appid: root.appId
        name: "screenrecord"
        description: "Open screen record tool"

        onPressed: GlobalStates.screenRecordToolVisible = true
    }

    GlobalShortcut {
        appid: root.appId
        name: "lens"
        description: "Open Google Lens (screenshot)"

        onPressed: {
            Screenshot.captureMode = "lens";
            GlobalStates.screenshotToolVisible = true;
        }
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
