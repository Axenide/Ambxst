pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.globals
import qs.config

QtObject {
    id: root

    signal monitorScreenshotReady(string monitorName, string path)
    signal errorOccurred(string message)
    signal windowListReady(var windows)
    signal monitorsListReady(var monitors)
    signal imageSaved(string path)

    property string lensPath: "/tmp/image.png"

    property string captureMode: "normal"

    property string screenshotsDir: ""
    property string finalPath: ""

    property var _activeWorkspaceIds: []
    property var monitors: []

    // Selection state to synchronize UI across monitors
    property int selectionX: 0
    property int selectionY: 0
    property int selectionW: 0
    property int selectionH: 0

    property bool _initialized: false
    property bool _freezing: false
    property int _pendingFrames: 0

    function initialize() {
        if (_initialized) return;
        _initialized = true;
        BackendService.call("screenshot.dir", {}, (result, error) => {
            if (!error && result && result.dir) {
                root.screenshotsDir = result.dir;
            }
        });
    }

    // Process for fetching monitors (window mode needs workspace metadata)
    property Process monitorsProcess: Process {
        id: monitorsProcess
        command: ["axctl", "monitor", "list"]
        stdout: StdioCollector {}
        onExited: exitCode => {
            if (exitCode === 0) {
                try {
                    var rawMonitors = JSON.parse(monitorsProcess.stdout.text)
                    var normalized = rawMonitors.map(m => ({
                        id: m.id,
                        name: m.name,
                        width: m.width,
                        height: m.height,
                        scale: m.scale,
                        refresh_rate: m.refresh_rate,
                        focused: m.is_focused,
                        x: m.metadata ? m.metadata.x : 0,
                        y: m.metadata ? m.metadata.y : 0,
                        transform: m.metadata ? m.metadata.transform : 0,
                        activeWorkspace: m.metadata ? { id: m.metadata.active_workspace } : null
                    }))
                    Qt.callLater(() => {
                        root.monitors = normalized;
                        var ids = []
                        for (var i = 0; i < normalized.length; i++) {
                            if (normalized[i].activeWorkspace) {
                                ids.push(normalized[i].activeWorkspace.id)
                            }
                        }
                        root._activeWorkspaceIds = ids
                        clientsProcess.running = true

                        root.monitorsListReady(normalized)
                    })
                } catch (e) {
                    console.warn("Screenshot: Failed to parse monitors: " + e.message)
                    root.errorOccurred("Failed to parse monitors")
                }
            } else {
                console.warn("Screenshot: Failed to fetch monitors")
                root.errorOccurred("Failed to fetch monitors")
            }
        }
    }

    // Process for fetching windows
    property Process clientsProcess: Process {
        id: clientsProcess
        command: ["axctl", "window", "list"]
        stdout: StdioCollector {}
        onExited: exitCode => {
            if (exitCode === 0) {
                try {
                    var allClients = JSON.parse(clientsProcess.stdout.text)
                    var activeIds = root._activeWorkspaceIds
                    var normalizedClients = allClients.map(c => ({
                        id: c.id,
                        app_id: c.app_id,
                        title: c.title,
                        is_floating: c.is_floating,
                        is_focused: c.is_focused,
                        is_fullscreen: c.is_fullscreen,
                        is_hidden: c.is_hidden,
                        workspace_id: c.workspace_id,
                        pinned: c.metadata ? c.metadata.pinned : false,
                        workspace: { id: c.workspace_id },
                        at: [c.metadata ? c.metadata.x : 0, c.metadata ? c.metadata.y : 0],
                        size: [c.metadata ? c.metadata.width : 0, c.metadata ? c.metadata.height : 0]
                    }))

                    var filteredClients = normalizedClients.filter(c => {
                        return c.pinned || (activeIds.length > 0 && activeIds.includes(c.workspace.id))
                    })
                    Qt.callLater(() => root.windowListReady(filteredClients))
                } catch (e) {
                    console.warn("Screenshot: Error processing windows: " + e.message)
                }
            }
        }
    }

    property Process lensProcess: Process {
        id: lensProcess
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: exitCode => {
            if (exitCode === 0) {
                console.log("Screenshot: Google Lens script executed successfully")
            } else {
                root.errorOccurred("Failed to open Google Lens")
            }
        }
    }

    function freezeScreen() {
        if (_freezing) return;
        _freezing = true;

        var qsScreens = Quickshell.screens;
        var mappedMonitors = [];
        for (var i = 0; i < qsScreens.length; i++) {
            var s = qsScreens[i];
            mappedMonitors.push({
                id: i,
                name: s.name,
                x: s.x,
                y: s.y,
                width: s.width * s.scale,
                height: s.height * s.scale,
                scale: s.scale
            });
        }
        root.monitors = mappedMonitors;

        root._pendingFrames = qsScreens.length;
        for (var j = 0; j < qsScreens.length; j++) {
            root._requestFrame(qsScreens[j].name);
        }

        root.fetchWindows();
    }

    function _requestFrame(outputName) {
        BackendService.call("screenshot.frame", { output: outputName }, (result, error) => {
            root._onFrameResult(outputName, result, error);
        });
    }

    function _onFrameResult(outputName, result, error) {
        if (error || !result || !result.path) {
            console.warn("Screenshot: frame failed for " + outputName + ": " + (error || "no path"));
        } else {
            root.monitorScreenshotReady(outputName, result.path);
        }
        root._pendingFrames--;
        if (root._pendingFrames <= 0) {
            root._freezing = false;
        }
    }

    function fetchWindows() {
        monitorsProcess.running = true
    }

    function getTimestamp() {
        var d = new Date()
        var pad = (n) => n < 10 ? '0' + n : n;
        return d.getFullYear() + '-' +
               pad(d.getMonth() + 1) + '-' +
               pad(d.getDate()) + '-' +
               pad(d.getHours()) + '-' +
               pad(d.getMinutes()) + '-' +
               pad(d.getSeconds());
    }

    function processRegion(x, y, w, h) {
        if (root.captureMode === "ocr" || root.captureMode === "qr") {
            root._runRecognition(root.captureMode, Math.round(x), Math.round(y), Math.round(w), Math.round(h));
            return;
        }
        var isLens = root.captureMode === "lens";
        var params = {
            mode: "region",
            x: Math.round(x),
            y: Math.round(y),
            width: Math.round(w),
            height: Math.round(h),
            clipboard: !isLens
        };
        if (isLens) {
            params.outPath = root.lensPath;
        }
        BackendService.call("screenshot.capture", params, (result, error) => {
            root._onCaptureResult(result, error);
        });
    }

    // OCR / QR reuse the region selection overlay; results land in the
    // clipboard on the backend side and surface as internal notifications.
    function _runRecognition(kind, x, y, w, h) {
        root.captureMode = "normal";
        var method = kind === "qr" ? "ocr.barcode" : "ocr.text";
        var params = { x: x, y: y, width: w, height: h };
        if (kind === "ocr") {
            params.langs = root.ocrLangs();
        }
        BackendService.call(method, params, (result, error) => {
            if (error) {
                Notifications.notifyInternal({
                    summary: kind === "qr" ? "QR Scan Error" : "OCR Error",
                    body: "" + error
                });
                return;
            }
            if (kind === "qr") {
                var found = result && result.content && result.content !== "";
                Notifications.notifyInternal({
                    summary: "QR/Barcode Result",
                    body: found ? "Content copied to clipboard" : "No code detected"
                });
            } else {
                var hasText = result && result.text && result.text !== "";
                Notifications.notifyInternal({
                    summary: "OCR Result",
                    body: hasText ? "Text copied to clipboard" : "No text detected"
                });
            }
        });
    }

    function ocrLangs() {
        var cfg = Config.system.ocr;
        var langs = [];
        if (cfg) {
            if (cfg.eng !== false) langs.push("eng");
            if (cfg.spa !== false) langs.push("spa");
            if (cfg.lat === true) langs.push("lat");
            if (cfg.jpn === true) langs.push("jpn");
            if (cfg.chi_sim === true) langs.push("chi_sim");
            if (cfg.chi_tra === true) langs.push("chi_tra");
            if (cfg.kor === true) langs.push("kor");
        } else {
            langs = ["eng", "spa"];
        }
        if (langs.length === 0) langs.push("eng");
        return langs.join("+");
    }

    function processMonitorScreen(monitorName) {
        var isLens = root.captureMode === "lens";
        var params = {
            mode: "output",
            output: monitorName,
            clipboard: !isLens
        };
        if (isLens) {
            params.outPath = root.lensPath;
        }
        BackendService.call("screenshot.capture", params, (result, error) => {
            root._onCaptureResult(result, error);
        });
    }

    function _onCaptureResult(result, error) {
        if (error || !result || !result.path) {
            root.errorOccurred("Failed to capture screenshot");
            return;
        }
        root.finalPath = result.path;
        if (root.captureMode === "lens") {
            root.runLensScript();
            root.captureMode = "normal";
        } else {
            root.imageSaved(root.finalPath);
        }
    }

    property Process openScreenshotsProcess: Process {
        id: openScreenshotsProcess
        command: ["xdg-open", ""]
    }

    function openScreenshotsFolder() {
        openScreenshotsProcess.command = ["xdg-open", root.screenshotsDir !== "" ? root.screenshotsDir : Quickshell.env("HOME") + "/Pictures/Screenshots"];
        openScreenshotsProcess.running = true;
    }

    function runLensScript() {
        var scriptPath = Qt.resolvedUrl("../../scripts/google_lens.sh").toString().replace("file://", "");
        lensProcess.command = ["bash", scriptPath, root.finalPath];
        lensProcess.running = true;
    }
}
