pragma Singleton

import QtQuick
import QtQml
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.modules.services

Singleton {
    id: root

    // General Idle Settings
    property string lockCmd: Config.system.idle.general.lock_cmd ?? "ambxst lock"
    property string beforeSleepCmd: Config.system.idle.general.before_sleep_cmd ?? "loginctl lock-session"
    property string afterSleepCmd: Config.system.idle.general.after_sleep_cmd ?? "ambxst screen on"

    // Login Lock Daemon
    // Helper script that listens to Lock signal and executes lockCmd from config
    Process {
        id: loginLockProc
        running: true
        command: ["bash", Qt.resolvedUrl("../../scripts/loginlock.sh").toString().replace("file://", "")]
        onExited: exitCode => {
            if (exitCode !== 0) {
                console.warn("loginlock.sh exited with code " + exitCode + ". Restarting...");
                loginLockRestartTimer.start();
            }
        }
    }

    Timer {
        id: loginLockRestartTimer
        interval: 1000
        repeat: false
        onTriggered: loginLockProc.running = true
    }

    // Sleep Monitor Daemon
    // Helper script that listens to PrepareForSleep signal and executes sleep commands from config
    Process {
        id: sleepMonitorProc
        running: true
        command: ["bash", Qt.resolvedUrl("../../scripts/sleep_monitor.sh").toString().replace("file://", "")]
        onExited: exitCode => {
            if (exitCode !== 0) {
                console.warn("sleep_monitor.sh exited with code " + exitCode + ". Restarting...");
                sleepMonitorRestartTimer.start();
            }
        }
    }

    Timer {
        id: sleepMonitorRestartTimer
        interval: 1000
        repeat: false
        onTriggered: sleepMonitorProc.running = true
    }

    // Master Idle Logic
    property int elapsedIdleTime: 0
    property var triggeredListeners: [] // Keeps track of indices that have fired
    property bool resumeCooldown: false // Prevent immediate resume after listener triggers
    property bool pendingReset: false // Track if reset was requested during cooldown

    // Master Monitor: Detects "absence of activity" almost immediately
    IdleMonitor {
        id: masterMonitor
        timeout: 1 // 1 second threshold to consider the session "idle"
        respectInhibitors: true

        onIsIdleChanged: {
            if (isIdle) {
                idleTimer.start();
            } else {
                idleTimer.stop();
                // If in cooldown, defer the reset
                if (root.resumeCooldown) {
                    root.pendingReset = true;
                } else {
                    root.resetIdleState();
                }
            }
        }
    }
    
    // Cooldown timer - prevents resume for a short period after listener triggers
    Timer {
        id: cooldownTimer
        interval: 1500 // 1.5 seconds - enough for lockscreen to fully load
        repeat: false
        onTriggered: {
            root.resumeCooldown = false;
            // Execute pending reset if activity happened during cooldown and user is still active
            if (root.pendingReset && !masterMonitor.isIdle) {
                root.pendingReset = false;
                root.resetIdleState();
            }
        }
    }

    Timer {
        id: idleTimer
        interval: 1000 // 1 second tick
        repeat: true
        onTriggered: {
            root.elapsedIdleTime += 1;
            root.checkListeners();
        }
    }

    function checkListeners() {
        // Skip idle actions if media is playing (YouTube, Spotify, etc.)
        if (MprisController.isPlaying) {
            root.elapsedIdleTime = 0; // Reset timer while media plays
            return;
        }
        
        let listeners = Config.system.idle.listeners;
        for (let i = 0; i < listeners.length; i++) {
            let listener = listeners[i];
            let tVal = listener.timeout || 60;

            // If time matches and hasn't been triggered yet
            if (root.elapsedIdleTime >= tVal && !root.triggeredListeners.includes(i)) {
                if (listener.onTimeout) {
                    console.log("Idle timer " + tVal + "s reached: " + listener.onTimeout);
                    executionProc.command = ["sh", "-c", listener.onTimeout];
                    executionProc.running = true;
                    
                    // Activate cooldown to prevent immediate resume from listener-caused activity
                    root.resumeCooldown = true;
                    cooldownTimer.restart();
                }
                root.triggeredListeners.push(i);
            }
        }
    }

    function resetIdleState() {
        let listeners = Config.system.idle.listeners;

        // Execute resume commands for all triggered listeners
        // We iterate backwards to undo latest states first (optional preference)
        for (let i = root.triggeredListeners.length - 1; i >= 0; i--) {
            let idx = root.triggeredListeners[i];
            let listener = listeners[idx];

            if (listener && listener.onResume) {
                console.log("Idle resuming (undoing " + (listener.timeout || 0) + "s): " + listener.onResume);
                executionProc.command = ["sh", "-c", listener.onResume];
                executionProc.running = true;
            }
        }

        // Reset counters
        root.elapsedIdleTime = 0;
        root.triggeredListeners = [];
    }

    // Shared process for command execution to avoid garbage collection issues
    Process {
        id: executionProc
    }
}
