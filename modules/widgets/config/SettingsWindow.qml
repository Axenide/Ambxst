import QtQuick
import Quickshell
import qs.modules.widgets.dashboard.controls
import qs.modules.components
import qs.modules.globals
import qs.modules.services
import qs.modules.theme
import qs.config

FloatingWindow {
    id: settingsWindow

    // Window properties
    implicitWidth: 900
    implicitHeight: 650
    title: "Ambxst[+] Settings"
    visible: GlobalStates.settingsWindowVisible

    // Center on screen (approximate, since FloatingWindow usually centers by default or relies on WM)
    // We can't easily force center without screen geometry, but WM usually handles it.

    color: "transparent"

    function screenByName(name) {
        if (!name) return null;

        for (let i = 0; i < Quickshell.screens.length; i++) {
            if (Quickshell.screens[i].name === name) {
                return Quickshell.screens[i];
            }
        }

        return null;
    }

    function preparePlacement() {
        const targetScreen = screenByName(GlobalStates.settingsTargetScreenName || AxctlService.focusedMonitor?.name || "");
        if (targetScreen) {
            settingsWindow.screen = targetScreen;
        }

        placementTimer.attempts = 0;
        placementTimer.restart();
    }

    function placeOnTargetWorkspace() {
        const targetWorkspace = GlobalStates.settingsTargetWorkspaceId || AxctlService.focusedMonitor?.activeWorkspace?.id || AxctlService.focusedWorkspace?.id || 0;
        if (!targetWorkspace) return false;

        const clients = AxctlService.clients.values || [];
        for (let i = 0; i < clients.length; i++) {
            const client = clients[i];
            if (client.title === settingsWindow.title) {
                if (client.workspace?.id !== targetWorkspace) {
                    // Move first, then focus on a later tick. Doing both in the
                    // same tick races: the silent move hasn't applied yet when we
                    // focus, so the view stays on the window's old workspace
                    // (e.g. jumping to workspace 1 on first open). Returning false
                    // keeps the placement timer running for the follow-up focus.
                    AxctlService.dispatch(`movetoworkspacesilent ${targetWorkspace}, address:${client.address}`);
                    return false;
                }
                // The window is on the target workspace. Only pull focus over with
                // focuswindow (which warps the cursor to the window centre) if we
                // aren't already viewing that workspace — i.e. after a silent
                // cross-workspace move. When it opened on the current workspace it
                // already has focus, so skip focuswindow to avoid warping the
                // cursor on every settings open (unlike any normal app).
                const activeWs = AxctlService.focusedMonitor?.activeWorkspace?.id;
                if (activeWs !== targetWorkspace) {
                    AxctlService.dispatch(`focuswindow address:${client.address}`);
                }
                return true;
            }
        }

        return false;
    }

    Timer {
        id: placementTimer
        interval: 100
        repeat: true
        property int attempts: 0
        onTriggered: {
            attempts++;
            if (!settingsWindow.visible || settingsWindow.placeOnTargetWorkspace() || attempts >= 20) {
                stop();
            }
        }
    }

    // Use a StyledRect for the background and styling
    StyledRect {
        anchors.fill: parent
        variant: "bg"
        radius: 0

        // Settings Tab Content
        // Loaded asynchronously: opening Settings must never block the (concurrent)
        // notch close animation on the main thread. The heavy SettingsTab plus its
        // panel search-indexer are incubated on a later tick, after the notch has
        // already closed, keeping the shell feeling native and lag-free.
        Loader {
            id: settingsTabLoader
            anchors.fill: parent
            anchors.margins: 16
            asynchronous: true
            active: settingsWindow.visible
            source: "../dashboard/controls/SettingsTab.qml"

            opacity: status === Loader.Ready ? 1 : 0
            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration
                    easing.type: Styling.animEasing
                }
            }
        }
    }

    // Close on visibility change from outside
    onVisibleChanged: {
        if (visible) {
            preparePlacement();
        }

        if (!visible && GlobalStates.settingsWindowVisible) {
            GlobalStates.settingsWindowVisible = false;
        }
    }

    // Sync visibility from GlobalStates
    Connections {
        target: GlobalStates
        function onSettingsWindowVisibleChanged() {
            if (GlobalStates.settingsWindowVisible) {
                settingsWindow.preparePlacement();
            }
            settingsWindow.visible = GlobalStates.settingsWindowVisible;
        }
    }
}
