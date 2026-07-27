pragma Singleton

import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    readonly property var settings: Config.system && Config.system.batteryNotifications ? Config.system.batteryNotifications : null
    readonly property bool enabled: settings && settings.enabled !== undefined ? settings.enabled : true
    readonly property int lowThreshold: settings && settings.lowThreshold !== undefined ? settings.lowThreshold : 20
    readonly property int criticalThreshold: settings && settings.criticalThreshold !== undefined ? settings.criticalThreshold : 10

    property bool lowNotified: false
    property bool criticalNotified: false

    function resetNotificationState() {
        lowNotified = false;
        criticalNotified = false;
    }

    function sendNotification(summary, body, urgency) {
        notificationProcess.running = false;
        notificationProcess.command = [
            "notify-send",

            "-u", urgency,
            "-i", "battery-caution",
            summary,
            body
        ];
        notificationProcess.running = true;
        warningSound.play();
    }

    function checkBatteryState() {
        if (!enabled || !Battery.available || SuspendManager.isSuspending) {
            return;
        }

        if (Battery.isPluggedIn || Battery.isCharging) {
            resetNotificationState();
            return;
        }

        const low = Math.max(lowThreshold, criticalThreshold);
        const critical = Math.min(lowThreshold, criticalThreshold);
        const percentage = Math.round(Battery.percentage);
        const timeRemaining = Battery.timeToEmpty !== "" ? ` About ${Battery.timeToEmpty} remaining.` : "";

        if (percentage > low) {
            resetNotificationState();
            return;
        }

        if (percentage <= critical) {
            if (!criticalNotified) {
                sendNotification(
                    `Battery critical (${percentage}%)`,
                    `Plug in your charger now.${timeRemaining}`,
                    "critical"
                );
                criticalNotified = true;
            }
            lowNotified = true;
            return;
        }

        if (!lowNotified) {
            sendNotification(
                `Battery low (${percentage}%)`,
                `Battery is getting low.${timeRemaining}`,
                "normal"
            );
            lowNotified = true;
        }
    }

    Process {
        id: notificationProcess
        running: false
        command: []
    }

    SoundEffect {
        id: warningSound
        source: Quickshell.shellDir + "/assets/sound/polite-warning-tone.wav"
        volume: 1.0
    }

    Connections {
        target: Battery
        function onPercentageChanged() {
            root.checkBatteryState();
        }
        function onIsPluggedInChanged() {
            root.checkBatteryState();
        }
        function onIsChargingChanged() {
            root.checkBatteryState();
        }
        function onAvailableChanged() {
            root.checkBatteryState();
        }
    }

    Connections {
        target: root.settings
        ignoreUnknownSignals: true
        function onEnabledChanged() {
            if (!root.enabled) {
                root.resetNotificationState();
            } else {
                root.checkBatteryState();
            }
        }
        function onLowThresholdChanged() {
            root.resetNotificationState();
            root.checkBatteryState();
        }
        function onCriticalThresholdChanged() {
            root.resetNotificationState();
            root.checkBatteryState();
        }
    }

    Connections {
        target: SuspendManager
        function onWakingUp() {
            wakeCheckTimer.restart();
        }
    }

    Timer {
        id: startupCheckTimer
        interval: 5000
        running: true
        repeat: false
        onTriggered: root.checkBatteryState()
    }

    Timer {
        id: wakeCheckTimer
        interval: 3000
        repeat: false
        onTriggered: root.checkBatteryState()
    }

    Timer {
        id: pollTimer
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.checkBatteryState()
    }
}
