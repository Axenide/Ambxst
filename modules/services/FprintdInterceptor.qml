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

    // Compiled once; each single-shot system query is one self-destroying
    // instance. No Qt.createQmlObject, no leaked Process/StdioCollector.
    Component {
        id: singleShotProc
        Process {
            property string cmdLine: ""
            property var onDone: null
            command: ["sh", "-c", cmdLine]
            stdout: StdioCollector {
                waitForEnd: true
            }
            running: true
            onExited: (exitCode, exitStatus) => {
                if (onDone) onDone(exitCode, stdout.text);
                destroy();
            }
        }
    }

    // Long-lived dbus-monitor for fprintd VerifyStart/VerifyStop calls
    Component {
        id: dbusMonitorComp
        Process {
            command: ["dbus-monitor", "--session", "interface='net.reactivated.Fprint.Device'", "type=method_call"]
            stdout: SplitParser {
                onRead: root.handleDbusLine(data)
            }
            onExited: (exitCode, exitStatus) => {
                if (root.monitoring)
                    monitorRestartTimer.restart();
            }
        }
    }

    property Timer monitorRestartTimer: Timer {
        interval: 1000
        repeat: false
        onTriggered: root.startMonitorProcess()
    }

    property var dbusMonitorProc: null

    property var authConnections: Connections {
        target: FingerprintService
        function onAuthSuccess() { root.handleAuthSuccess(); }
        function onAuthFailed() { root.handleAuthFailed(); }
    }

    // Start monitoring as soon as fprintd is detected + fingerprint auth is
    // enabled — not only when the user toggles the setting.
    onActiveChanged: {
        if (active && Config.lockscreen.enableFingerprint && !root.monitoring) {
            root.startMonitoring();
        } else if (!active && root.monitoring) {
            root.stopMonitoring();
        }
    }

    function update() {
        if (!Config.initialLoadComplete) {
            // Retry until config has fully loaded (no-op otherwise)
            Qt.callLater(update);
            return;
        }
        checkFprintdRunning();
    }

    function checkFprintdRunning() {
        singleShotProc.createObject(root, {
            cmdLine: "busctl list --no-pager",
            onDone: (exitCode, output) => {
                root.active = output.indexOf("net.reactivated.Fprint") !== -1;
            }
        });
    }

    function startMonitorProcess() {
        if (!dbusMonitorProc) {
            dbusMonitorProc = dbusMonitorComp.createObject(root);
        }
        dbusMonitorProc.running = true;
    }

    function handleDbusLine(data) {
        if (data.indexOf("VerifyStart") !== -1) {
            root.requestCount++;
            root.authInProgress = true;
            // Detection is async (process-based), so it's callback-driven:
            // the popup only opens once both the app and window resolved.
            root.detectCallingApp((app) => {
                root.detectCallingWindow((window) => {
                    root.currentApp = app;
                    root.currentWindow = window;
                    root.authRequested(app, window);
                    root.showFingerprintPopup(app, window);
                });
            });
        }
        if (data.indexOf("VerifyStop") !== -1) {
            root.authInProgress = false;
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
        if (root.monitoring)
            return;

        root.monitoring = true;
        root.requestCount = 0;
        root.authInProgress = false;

        root.startMonitorProcess();
    }

    function stopMonitoring() {
        root.monitoring = false;
        root.authInProgress = false;
        if (dbusMonitorProc && dbusMonitorProc.running) {
            // Process has no kill() — SIGTERM via running=false terminates
            // dbus-monitor (and monitoring is already false, so onExited
            // won't restart it).
            dbusMonitorProc.running = false;
        }
    }

    function detectCallingApp(callback) {
        singleShotProc.createObject(root, {
            cmdLine: "ps -eo pid,comm --no-headers | tail -5 | head -1 | awk '{print $2}'",
            onDone: (exitCode, output) => callback(output.trim() || "unknown")
        });
    }

    function detectCallingWindow(callback) {
        singleShotProc.createObject(root, {
            cmdLine: "xdotool getwindowfocus getwindowname 2>/dev/null || echo 'unknown'",
            onDone: (exitCode, output) => callback(output.trim() || "unknown")
        });
    }

    function showFingerprintPopup(app, window) {
        ensurePopup();
        if (!root.fpPopup)
            return;
        root.fpPopup.title = "Fingerprint Authentication";
        root.fpPopup.message = "App: " + app + "\nPlace your finger on the sensor";
        root.fpPopup.open();
        root.fpPopup.startScanning();
    }

    function hideFingerprintPopup() {
        if (root.fpPopup)
            root.fpPopup.close();
    }

    // The popup is a PanelWindow — it can't live as a QML-global, so the
    // interceptor owns the single instance. (The old code relied on a
    // `typeof FingerprintPopup` check that could never be true, making the
    // whole polkit/sudo indicator dead code.)
    Component {
        id: fpPopupComp
        FingerprintPopup {}
    }

    property var fpPopup: null

    function ensurePopup() {
        if (!root.fpPopup)
            root.fpPopup = fpPopupComp.createObject(root);
    }

    Component.onDestruction: {
        if (root.fpPopup) {
            root.fpPopup.destroy();
            root.fpPopup = null;
        }
    }

    Component.onCompleted: {
        Qt.callLater(function() {
            update();
        });
    }
}
