pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    property bool active: StateService.get("nightLight", false)

    // Auto light/dark mode when night light is active
    // Uses sunset altitude from wlsunset to determine day/night
    property bool autoThemeMode: StateService.get("autoThemeMode", false)
    property bool isNightTime: false
    
    property Process wlsunsetProcess: Process {
        command: ["wlsunset", "-t", "4499", "-T", "4500"]
        running: false
        stdout: SplitParser {
            onRead: (data) => {
                // wlsunset output cuando está corriendo
                if (data) {
                    root.active = true
                }
            }
        }
        onStarted: {
            root.active = true
        }
        onExited: (code) => {
            root.active = false
        }
    }
    
    property Process killProcess: Process {
        command: ["pkill", "wlsunset"]
        running: false
        onExited: (code) => {
            root.active = false
        }
    }
    
    property Process checkRunningProcess: Process {
        command: ["pgrep", "wlsunset"]
        running: false
        onExited: (code) => {
            const isRunning = code === 0
            
            // If state says active but not running, start it
            if (root.active && !isRunning) {
                console.log("NightLightService: Starting wlsunset (state was active but not running)")
                wlsunsetProcess.running = true
            } 
            // If state says inactive but running, kill it
            else if (!root.active && isRunning) {
                console.log("NightLightService: Stopping wlsunset (state was inactive but running)")
                killProcess.running = true
            }
        }
    }

    function toggle() {
        if (active) {
            killProcess.running = true
        } else {
            wlsunsetProcess.running = true
        }
    }
    
    function syncState() {
        checkRunningProcess.running = true
    }

    onActiveChanged: {
        if (StateService.initialized) {
            StateService.set("nightLight", active);
        }
        if (active && root.autoThemeMode) {
            // Start sunset time detection
            themeCheckTimer.restart();
        } else if (!active) {
            themeCheckTimer.stop();
        }
    }

    onAutoThemeModeChanged: {
        if (StateService.initialized) {
            StateService.set("autoThemeMode", autoThemeMode);
        }
        if (autoThemeMode && root.active) {
            themeCheckTimer.restart();
        } else if (!autoThemeMode) {
            themeCheckTimer.stop();
        }
    }

    /*! Toggle auto light/dark mode. When enabled, toggles Config.lightMode
        based on time of day (before 7AM or after 7PM = dark mode). */
    property Timer themeCheckTimer: Timer {
        id: themeCheckTimer
        interval: 60000 // Check every minute
        repeat: true
        running: false
        onTriggered: {
            if (!root.autoThemeMode || !root.active) return;
            const hour = new Date().getHours();
            const shouldBeDark = hour < 7 || hour >= 19;
            if (root.isNightTime !== shouldBeDark) {
                root.isNightTime = shouldBeDark;
                Config.lightMode = !shouldBeDark;
                console.log("AutoTheme:", shouldBeDark ? "dark mode" : "light mode");
            }
        }
    }

    Connections {
        target: StateService
        function onStateLoaded() {
            root.active = StateService.get("nightLight", false);
            root.syncState();
        }
    }

    // Auto-initialize on creation
    Timer {
        interval: 100
        running: true
        repeat: false
        onTriggered: {
            if (StateService.initialized) {
                root.active = StateService.get("nightLight", false);
                root.syncState();
            }
        }
    }
}
