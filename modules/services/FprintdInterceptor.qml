pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.globals
import qs.config
import qs.modules.lockscreen

QtObject {
    id: root

    property bool active: false
    property bool monitoring: false
    property string currentApp: ""
    property string currentWindow: ""
    property int requestCount: 0
    property bool authInProgress: false

    signal authRequested(string app, string window)
    signal authCompleted(bool success)
    signal monitorError(string error)

    function update() {
        if (!Config.initialLoadComplete)
            return;
        checkFprintdRunning();
    }

    function checkFprintdRunning() {
        var proc = Qt.createQmlObject('import Quickshell.Io; Process {}', root);
        proc.command = ["busctl", "list", "--no-pager"];
        proc.running = true;

        var collector = Qt.createQmlObject('import Quickshell.Io; StdioCollector {}', proc);
        collector.waitForEnd = true;

        proc.onExited.connect(function() {
            active = collector.text.indexOf("net.reactivated.Fprint") !== -1;
        });
    }

    property var dbusMonitorProc: null
    property var authConnections: null

    function initProcesses() {
        if (dbusMonitorProc)
            return;
        dbusMonitorProc = Qt.createQmlObject('import Quickshell.Io; Process { command: ["dbus-monitor", "--session", "interface=\'net.reactivated.Fprint.Device\'", "type=method_call"]; stdout: StdioCollector { id: dc; waitForEnd: false; onStreamFinished: { root.handleDbusOutput(text, dc) } } }', root);
        dbusMonitorProc.running = false;
        dbusMonitorProc.onExited.connect(function() {
            if (root.monitoring)
                dbusMonitorProc.running = true;
        });
        authConnections = Qt.createQmlObject('import QtQuick; Connections {}', root);
        authConnections.target = FingerprintService;
        authConnections.onAuthSuccess.connect(root.handleAuthSuccess);
        authConnections.onAuthFailed.connect(root.handleAuthFailed);
    }

    function handleDbusOutput(data, collector) {
        if (data.indexOf("VerifyStart") !== -1) {
            requestCount++;
            authInProgress = true;
            currentApp = root.detectCallingApp();
            currentWindow = root.detectCallingWindow();
            root.authRequested(currentApp, currentWindow);
            root.showFingerprintPopup(currentApp, currentWindow);
        }
        if (data.indexOf("VerifyStop") !== -1) {
            authInProgress = false;
            root.hideFingerprintPopup();
        }
    }

    function handleAuthSuccess() {
        if (root.authInProgress) {
            root.authInProgress = false;
            root.authCompleted(true);
            root.hideFingerprintPopup();
        }
    }

    function handleAuthFailed() {
        if (root.authInProgress) {
            root.authInProgress = false;
            root.authCompleted(false);
            root.hideFingerprintPopup();
        }
    }

    function startMonitoring() {
        if (monitoring)
            return;

        if (!dbusMonitorProc)
            initProcesses();

        monitoring = true;
        requestCount = 0;
        authInProgress = false;

        dbusMonitorProc.running = true;
    }

    function stopMonitoring() {
        monitoring = false;
        authInProgress = false;
        if (dbusMonitorProc && dbusMonitorProc.running) {
            dbusMonitorProc.kill();
        }
    }

    function detectCallingApp() {
        var proc = Qt.createQmlObject('import Quickshell.Io; Process {}', root);
        proc.command = ["bash", "-c", "ps -eo pid,comm --no-headers | tail -5 | head -1 | awk '{print $2}'"];
        proc.running = true;

        var collector = Qt.createQmlObject('import Quickshell.Io; StdioCollector {}', proc);
        collector.waitForEnd = true;

        var result = "unknown";
        proc.onExited.connect(function() {
            result = collector.text.trim() || "unknown";
        });

        return result;
    }

    function detectCallingWindow() {
        var proc = Qt.createQmlObject('import Quickshell.Io; Process {}', root);
        proc.command = ["bash", "-c", "xdotool getwindowfocus getwindowname 2>/dev/null || echo 'unknown'"];
        proc.running = true;

        var collector = Qt.createQmlObject('import Quickshell.Io; StdioCollector {}', proc);
        collector.waitForEnd = true;

        var result = "unknown";
        proc.onExited.connect(function() {
            result = collector.text.trim() || "unknown";
        });

        return result;
    }

    function showFingerprintPopup(app, window) {
        if (typeof FingerprintPopup !== "undefined") {
            FingerprintPopup.title = "Fingerprint Authentication";
            FingerprintPopup.message = "App: " + app + "\nPlace your finger on the sensor";
            FingerprintPopup.open();
            FingerprintPopup.startScanning();
        }
    }

    function hideFingerprintPopup() {
        if (typeof FingerprintPopup !== "undefined") {
            FingerprintPopup.close();
        }
    }

    Component.onCompleted: {
        Qt.callLater(function() {
            update();
        });
    }
}
