pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.globals
import qs.config

QtObject {
    id: root

    property bool available: false
    property bool enrolled: false
    property bool scanning: false
    property string status: "idle"
    property var enrolledFingers: []
    property string currentFinger: ""
    property int retryCount: 0
    property int maxRetries: 3
    property bool deviceMonitoring: false
    property string lastError: ""

    signal authSuccess()
    signal authFailed(string error)
    signal authProgress(string message)
    signal deviceLost()
    signal deviceRestored()
    signal retryAttempt(int attempt, int maxRetries)

    readonly property string scriptPath: Qt.resolvedUrl("../../scripts/fprintd_auth.py").toString().replace("file://", "")

    function update() {
        if (!Config.initialLoadComplete)
            return;
        checkAvailability();
    }

    function checkAvailability() {
        available = false;
        enrolled = false;
        enrolledFingers = [];

        var proc = createProcess(["python3", scriptPath, "check"]);
        var collector = createCollector(proc);

        proc.onExited.connect(function() {
            try {
                var data = JSON.parse(collector.text.trim());
                var wasAvailable = available;
                available = data.available || false;
                enrolled = data.enrolled || false;
                enrolledFingers = data.fingers || [];

                if (!wasAvailable && available) {
                    deviceRestored();
                    startDeviceMonitoring();
                } else if (wasAvailable && !available && deviceMonitoring) {
                    deviceLost();
                    stopDeviceMonitoring();
                } else if (available && !deviceMonitoring) {
                    startDeviceMonitoring();
                }
            } catch (e) {
                available = false;
                enrolled = false;
                enrolledFingers = [];
                lastError = "Failed to check fprintd: " + e;
            }
        });
    }

    function startVerification() {
        if (!available || !enrolled) {
            authFailed("Fingerprint not available or no fingers enrolled");
            return;
        }

        retryCount = 0;
        scanning = true;
        status = "scanning";
        authProgress("Place your finger on the sensor");

        startVerifyProcess();
    }

    function startVerifyProcess() {
        var proc = createProcess(["python3", scriptPath, "verify"]);
        var collector = createCollector(proc);

        proc.onExited.connect(function() {
            if (!scanning)
                return;

            scanning = false;
            var lines = collector.text.trim().split("\n");
            var lastLine = lines[lines.length - 1];

            try {
                var data = JSON.parse(lastLine);
                if (data.success) {
                    status = "success";
                    retryCount = 0;
                    authSuccess();
                } else {
                    status = "failed";
                    lastError = data.error || "Fingerprint verification failed";

                    if (retryCount < maxRetries) {
                        retryCount++;
                        retryAttempt(retryCount, maxRetries);
                        authProgress("Retry " + retryCount + " of " + maxRetries + ": " + lastError + ". Try again.");
                        scanning = true;
                        status = "scanning";
                        Qt.callLater(function() {
                            startVerifyProcess();
                        });
                    } else {
                        authFailed(lastError + " (retried " + maxRetries + " times)");
                    }
                }
            } catch (e) {
                status = "error";
                lastError = "Failed to parse fingerprint response: " + e;

                if (retryCount < maxRetries) {
                    retryCount++;
                    retryAttempt(retryCount, maxRetries);
                    authProgress("Retry " + retryCount + " of " + maxRetries + ".");
                    scanning = true;
                    status = "scanning";
                    Qt.callLater(function() {
                        startVerifyProcess();
                    });
                } else {
                    authFailed(lastError);
                }
            }
        });
    }

    function stopVerification() {
        scanning = false;
        status = "stopped";
        retryCount = 0;
    }

    function enrollFinger(finger) {
        if (!available) {
            authFailed("Fingerprint device not available");
            return;
        }

        status = "enrolling";
        authProgress("Place your finger on the sensor to enroll");

        var proc = createProcess(["python3", scriptPath, "enroll", finger]);
        var collector = createCollector(proc);

        proc.onExited.connect(function() {
            var lines = collector.text.trim().split("\n");
            var lastLine = lines[lines.length - 1];

            try {
                var data = JSON.parse(lastLine);
                if (data.success) {
                    status = "enroll_complete";
                    authSuccess();
                } else {
                    status = "enroll_failed";
                    lastError = data.error || "Enrollment failed";
                    authFailed(lastError);
                }
            } catch (e) {
                status = "error";
                lastError = "Failed to parse enrollment response: " + e;
                authFailed(lastError);
            }
        });
    }

    function deleteFinger(finger) {
        if (!available)
            return;

        var proc = createProcess(["python3", scriptPath, "delete", finger]);
        proc.running = true;

        proc.onExited.connect(function() {
            listFingers();
        });
    }

    function listFingers() {
        var proc = createProcess(["python3", scriptPath, "list"]);
        var collector = createCollector(proc);

        proc.onExited.connect(function() {
            try {
                var data = JSON.parse(collector.text.trim());
                enrolledFingers = data.fingers || [];
                enrolled = enrolledFingers.length > 0;
            } catch (e) {
                enrolledFingers = [];
                enrolled = false;
            }
        });
    }

    function startDeviceMonitoring() {
        if (deviceMonitoring)
            return;

        deviceMonitoring = true;

        deviceMonitorTimer.running = true;
    }

    function stopDeviceMonitoring() {
        deviceMonitoring = false;
        deviceMonitorTimer.running = false;
    }

    function createProcess(command) {
        var proc = Qt.createQmlObject('import Quickshell.Io; Process {}', root);
        proc.command = command;
        return proc;
    }

    function createCollector(proc) {
        var collector = Qt.createQmlObject('import Quickshell.Io; StdioCollector {}', proc);
        collector.waitForEnd = true;
        return collector;
    }

    Timer {
        id: deviceMonitorTimer
        interval: 5000
        repeat: true
        running: false

        onTriggered: {
            if (!available)
                return;

            var proc = createProcess(["python3", scriptPath, "check"]);
            var collector = createCollector(proc);

            proc.onExited.connect(function() {
                try {
                    var data = JSON.parse(collector.text.trim());
                    if (!data.available && available) {
                        available = false;
                        enrolled = false;
                        deviceLost();
                        stopDeviceMonitoring();
                    }
                } catch (e) {
                    if (available) {
                        available = false;
                        enrolled = false;
                        deviceLost();
                        stopDeviceMonitoring();
                    }
                }
            });
        }
    }

    Component.onCompleted: {
        Qt.callLater(function() {
            update();
        });
    }
}
