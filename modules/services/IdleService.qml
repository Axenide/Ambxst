pragma Singleton

import QtQuick
import QtQml
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    // General Idle Settings
    property string lockCmd: Config.system.idle.general.lock_cmd ?? "ambxst+ lock"
    property string beforeSleepCmd: Config.system.idle.general.before_sleep_cmd ?? "loginctl lock-session"
    property string afterSleepCmd: Config.system.idle.general.after_sleep_cmd ?? "ambxst+ screen on"

    // Login Lock Daemon
    // Helper script that listens to Lock signal and reports LOCK events;
    // IdleService owns execution of the configured lock command.
    property var loginLockProc: Process {
        id: loginLockProc
        running: true
        command: ["bash", Qt.resolvedUrl("../../scripts/loginlock.sh").toString().replace("file://", "")]

        stdout: SplitParser {
            onRead: data => {
                if (data.trim() === "LOCK") {
                    root.executeCommand(root.lockCmd);
                }
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                console.warn("loginlock.sh exited with code " + exitCode + ". Restarting...");
                loginLockRestartTimer.start();
            }
        }
    }

    property var loginLockRestartTimer: Timer {
        id: loginLockRestartTimer
        interval: 1000
        repeat: false
        onTriggered: loginLockProc.running = true
    }

    // Sleep Monitor Daemon
    // Helper script that listens to PrepareForSleep signal and emits SUSPEND/WAKE
    // events; IdleService owns execution of the configured sleep commands.
    property var sleepMonitorProc: Process {
        id: sleepMonitorProc
        running: true
        command: ["bash", Qt.resolvedUrl("../../scripts/sleep_monitor.sh").toString().replace("file://", "")]
        
        stdout: SplitParser {
            onRead: data => {
                const signal = data.trim();
                if (signal === "SUSPEND") {
                    root.lockBeforeSleep();
                    SuspendManager.onPrepareForSleep();
                } else if (signal === "WAKE") {
                    root.executeCommand(root.afterSleepCmd);
                    SuspendManager.onWakingUp();
                }
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                console.warn("sleep_monitor.sh exited with code " + exitCode + ". Restarting...");
                sleepMonitorRestartTimer.start();
            }
        }
    }

    property var sleepMonitorRestartTimer: Timer {
        id: sleepMonitorRestartTimer
        interval: 1000
        repeat: false
        onTriggered: sleepMonitorProc.running = true
    }

    // Master Idle Logic
    property int elapsedIdleTime: 0
    property var triggeredListeners: [] // Keeps track of indices that have fired

    // Master Monitor: Detects "absence of activity" almost immediately
    property var masterMonitor: IdleMonitor {
        id: masterMonitor
        timeout: 1 // 1 second threshold to consider the session "idle"
        respectInhibitors: true

        onIsIdleChanged: {
            if (isIdle) {
                idleTimer.start();
            } else {
                idleTimer.stop();
                root.resetIdleState();
            }
        }
    }

    property var idleTimer: Timer {
        id: idleTimer
        interval: 1000 // 1 second tick
        repeat: true
        onTriggered: {
            root.elapsedIdleTime += 1;
            root.checkListeners();
        }
    }

    // Compiled once, instantiated per trigger with the configured command.
    // No template-string QML; destroys itself on exit (long-running commands
    // keep the Process alive until they actually exit).
    Component {
        id: commandProcessComp
        Process {
            property string cmd: ""
            command: ["sh", "-c", cmd]
            running: true
            onExited: destroy()
        }
    }

    function executeCommand(cmd) {
        if (!cmd) return;
        commandProcessComp.createObject(root, { cmd: cmd });
    }

    function shouldUseInternalSleepLock() {
        const cmd = (root.beforeSleepCmd || "").trim();
        return cmd === "loginctl lock-session"
            || cmd === "loginctl lock-sessions"
            || cmd === "ambxst+ lock";
    }

    function lockBeforeSleep() {
        if (root.shouldUseInternalSleepLock()) {
            LockscreenService.lock();
        } else {
            root.executeCommand(root.beforeSleepCmd);
        }
    }

    function checkListeners() {
        let listeners = Config.system.idle.listeners;
        for (let i = 0; i < listeners.length; i++) {
            let listener = listeners[i];
            let tVal = listener.timeout || 60;

            // If time matches and hasn't been triggered yet
            if (root.elapsedIdleTime >= tVal && !root.triggeredListeners.includes(i)) {
                if (listener.onTimeout) {
                    console.log("Idle timer " + tVal + "s reached: " + listener.onTimeout);
                    root.executeCommand(listener.onTimeout);
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
                root.executeCommand(listener.onResume);
            }
        }

        // Reset counters
        root.elapsedIdleTime = 0;
        root.triggeredListeners = [];
    }
}
