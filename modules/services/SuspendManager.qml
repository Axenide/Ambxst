pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * SuspendManager - Central coordinator for system suspend and wake events.
 * Provides signals for other services to pause/resume heavy operations.
 */
Singleton {
    id: root

    // Current system power state
    property bool isSuspending: false
    
    // Delayed wake state for non-essential components
    property bool wakeReady: true

    property var wakeReadyTimer: Timer {
        id: wakeReadyTimer
        interval: 3000 // 3s delay for stability
        repeat: false
        onTriggered: root.wakeReady = true
    }

    // Signals for other services to connect to
    signal preparingForSleep()
    signal wakingUp()

    // Triggered when we receive the PrepareForSleep(true) signal
    function onPrepareForSleep() {
        console.log("SuspendManager: Preparing for sleep...");
        root.isSuspending = true;
        root.wakeReady = false;
        root.preparingForSleep();
    }

    // Triggered when we receive the PrepareForSleep(false) signal
    function onWakingUp() {
        console.log("SuspendManager: Waking up...");
        root.isSuspending = false;
        root.wakingUp();
        
        // Delay non-essential component activation
        wakeReadyTimer.restart();
    }

    // IPC handler for manual testing or external triggers
    property IpcHandler ipc: IpcHandler {
        target: "suspend"

        function prepare() {
            root.onPrepareForSleep();
        }

        function wake() {
            root.onWakingUp();
        }
    }
}
