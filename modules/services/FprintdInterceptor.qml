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

    function startMonitoring() {
        if (monitoring)
            return;

        monitoring = true;
        requestCount = 0;
        authInProgress = false;

        dbusMonitorProc.running = true;
    }

    function stopMonitoring() {
        monitoring = false;
        authInProgress = false;
        if (dbusMonitorProc.running) {
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

    Process {
        id: dbusMonitorProc
        command: ["dbus-monitor", "--session", "interface='net.reactivated.Fprint.Device'", "type=method_call"]
        running: false

        stdout: StdioCollector {
            id: dbusCollector
            waitForEnd: false

            onStreamFinished: {
                var data = text;
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
        }

        onExited: {
            if (monitoring) {
                dbusMonitorProc.running = true;
            }
        }
    }

    Connections {
        target: FingerprintService

        onAuthSuccess: {
            if (authInProgress) {
                authInProgress = false;
                authCompleted(true);
                hideFingerprintPopup();
            }
        }

        onAuthFailed: {
            if (authInProgress) {
                authInProgress = false;
                authCompleted(false);
                hideFingerprintPopup();
            }
        }
    }

    Component.onCompleted: {
        Qt.callLater(function() {
            update();
        });
    }
}
