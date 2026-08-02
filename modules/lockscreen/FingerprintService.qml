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
    // Per-scan progress during enrollment: stage = successful scans so far.
    signal enrollProgress(int stage, string message)
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
        proc.running = true;

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
        var buffer = "";
        proc.stdout = createParser(proc);
        proc.running = true;
        proc.stdout.onRead.connect(function(data) {
            if (!data)
                return;
            buffer += data + "\n";
            // The script emits a scanning line immediately, then one JSON
            // result line at the end — stream both as they arrive.
            var line = data.trim();
            if (!line)
                return;
            try {
                var obj = JSON.parse(line);
                if (obj.status === "scanning") {
                    authProgress(obj.message || "Place your finger on the sensor");
                } else if (obj.status === "hint") {
                    authProgress(obj.message || "Try again");
                }
            } catch (e) {
                // Partial JSON — wait for the rest.
            }
        });

        proc.onExited.connect(function() {
            if (!scanning)
                return;

            scanning = false;
            var lines = buffer.trim().split("\n");
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
        currentFinger = finger;
        authProgress("Place your finger on the sensor to enroll");

        var proc = createProcess(["python3", scriptPath, "enroll", finger]);
        var buffer = "";
        proc.stdout = createParser(proc);
        proc.running = true;
        proc.stdout.onRead.connect(function(data) {
            if (!data)
                return;
            buffer += data + "\n";
            var line = data.trim();
            if (!line)
                return;
            try {
                var obj = JSON.parse(line);
                if (obj.status === "scanning" || obj.status === "enrolling") {
                    root.enrollProgress(obj.stage || 0, obj.message || "Place your finger on the sensor");
                } else if (obj.status === "hint") {
                    root.enrollProgress(obj.stage || 0, obj.message || "Try again");
                }
            } catch (e) {
                // Partial JSON — wait for the rest.
            }
        });

        proc.onExited.connect(function() {
            var lines = buffer.trim().split("\n");
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
        proc.running = true;

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

    function createProcess(command) {
        var proc = Qt.createQmlObject('import Quickshell.Io; Process {}', root);
        proc.command = command;
        return proc;
    }

    // NOTE: Quickshell only reads process output when the parser is explicitly
    // assigned to Process.stdout — the old code created the collector as a
    // child object without assigning it, so stdout was never read and every
    // verify/enroll/check silently failed. Both helpers below assign explicitly.
    function createCollector(proc) {
        var collector = Qt.createQmlObject('import Quickshell.Io; StdioCollector {}', proc);
        collector.waitForEnd = true;
        proc.stdout = collector;
        return collector;
    }

    function createParser(proc) {
        var parser = Qt.createQmlObject('import Quickshell.Io; SplitParser {}', proc);
        proc.stdout = parser;
        return parser;
    }

    // Event-driven device monitoring: a long-lived dbus-monitor on the fprint
    // D-Bus interface fires checkAvailability() on real events (device added/
    // removed, fingers enrolled/deleted) instead of spawning a python process
    // every 5 seconds. A 30s fallback poll keeps state honest if a signal is
    // ever missed (e.g. the fprintd service dies silently).
    property var deviceMonitorProcess: null
    property var deviceMonitorFallbackTimer: null

    function initDeviceMonitor() {
        if (deviceMonitorProcess)
            return;

        deviceMonitorProcess = Qt.createQmlObject('import Quickshell.Io; Process {}', root);
        deviceMonitorProcess.command = ["dbus-monitor", "--session", "type='signal',interface='net.reactivated.Fprint'"];
        deviceMonitorProcess.stdout = createParser(deviceMonitorProcess);
        deviceMonitorProcess.stdout.onRead.connect(function(data) {
            if (!data)
                return;
            if (root.available)
                root.checkAvailability();
        });
        deviceMonitorProcess.onExited.connect(function() {
            deviceMonitorProcess.destroy();
            deviceMonitorProcess = null;
        });

        deviceMonitorFallbackTimer = Qt.createQmlObject('import QtQuick; Timer { interval: 30000; repeat: true; running: false }', root);
        deviceMonitorFallbackTimer.onTriggered.connect(function() {
            root.checkAvailability();
        });
    }

    function startDeviceMonitoring() {
        if (deviceMonitoring)
            return;

        initDeviceMonitor();

        deviceMonitoring = true;
        if (deviceMonitorProcess)
            deviceMonitorProcess.running = true;
        if (deviceMonitorFallbackTimer)
            deviceMonitorFallbackTimer.running = true;
    }

    function stopDeviceMonitoring() {
        deviceMonitoring = false;
        if (deviceMonitorProcess)
            deviceMonitorProcess.running = false;
        if (deviceMonitorFallbackTimer)
            deviceMonitorFallbackTimer.running = false;
    }

    Component.onCompleted: {
        Qt.callLater(function() {
            update();
        });
    }
}
