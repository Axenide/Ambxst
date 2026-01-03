pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    signal screenshotCaptured(string path)
    signal errorOccurred(string message)
    signal windowListReady(var windows)

    property string state: "idle" 
    property string currentMode: "region"
    property string tempDir: "/tmp/quickshell_screenshots"
    property string screenshotsDir: ""
    property string finalPath: ""
    property var _activeWorkspaceIds: []

    function getTempPath(screenName) {
        return tempDir + "/freeze_" + screenName + ".png";
    }

    function generateCapturePath(screenName) {
        return tempDir + "/freeze_" + screenName + "_" + Date.now() + ".png";
    }

    property Process freezeProcess: Process {
        id: freezeProcess
        property string targetScreen: ""
        onExited: exitCode => {
            if (exitCode === 0) {
                root.screenshotCaptured(getTempPath(targetScreen))
            } else {
                root.errorOccurred("Failed to capture " + targetScreen)
                root.state = "idle"
            }
        }
    }

    property Process xdgProcess: Process {
        command: ["bash", "-c", "xdg-user-dir PICTURES"]
        running: true
        stdout: StdioCollector {
            onTextChanged: {
                let dir = text.trim() || (Quickshell.env("HOME") + "/Pictures")
                root.screenshotsDir = dir + "/Screenshots"
                ensureDirProcess.running = true
            }
        }
    }

    property Process ensureDirProcess: Process {
        command: ["mkdir", "-p", root.tempDir, root.screenshotsDir]
    }

    // Centrally managed open/close logic
    function startCapture() {
        // Ensure directories exist before we start doing anything
        ensureDirProcess.running = true
        root.state = "loading"
        root.currentMode = "region"
    }

    function stopCapture() {
        root.state = "idle"
    }

    function freezeScreen(screenName) {
        freezeProcess.targetScreen = screenName;
        freezeProcess.command = ["grim", "-o", screenName, getTempPath(screenName)];
        freezeProcess.running = true;
    }

    function processRegion(x, y, w, h, inputPath) {
        var filename = "Screenshot_" + getTimestamp() + ".png"
        root.finalPath = root.screenshotsDir + "/" + filename
        var geom = `${w}x${h}+${x}+${y}`
        cropProcess.command = ["convert", inputPath, "-crop", geom, root.finalPath]
        cropProcess.running = true
        root.stopCapture()
    }

    function processFullscreen(inputPath) {
        var filename = "Screenshot_" + getTimestamp() + ".png"
        root.finalPath = root.screenshotsDir + "/" + filename
        cropProcess.command = ["cp", inputPath, root.finalPath]
        cropProcess.running = true
        root.stopCapture()
    }

    property Process cropProcess: Process {
        onExited: exitCode => { if (exitCode === 0) copyProcess.running = true }
    }

    property Process copyProcess: Process {
        command: ["bash", "-c", `wl-copy < "${root.finalPath}"`]
    }

    function getTimestamp() {
        var d = new Date()
        var pad = (n) => n < 10 ? '0' + n : n;
        return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()) + 
               '-' + pad(d.getHours()) + '-' + pad(d.getMinutes()) + '-' + pad(d.getSeconds());
    }

    function fetchWindows() { monitorsProcess.running = true }

    property Process monitorsProcess: Process {
        command: ["hyprctl", "-j", "monitors"]
        stdout: StdioCollector {}
        onExited: {
            try {
                let monitors = JSON.parse(monitorsProcess.stdout.text)
                // Defensive mapping: ensure monitor has activeWorkspace and id
                root._activeWorkspaceIds = monitors
                    .filter(m => m && m.activeWorkspace && typeof m.activeWorkspace.id !== "undefined")
                    .map(m => m.activeWorkspace.id)
                clientsProcess.running = true
            } catch(e) {
                root.errorOccurred("Failed to parse monitors: " + e.message)
            }
        }
    }

    property Process clientsProcess: Process {
        command: ["hyprctl", "-j", "clients"]
        stdout: StdioCollector {}
        onExited: {
            try {
                let all = JSON.parse(clientsProcess.stdout.text)
                let filtered = all.filter(c => {
                    if (!c) return false;
                    if (c.pinned) return true;
                    if (!c.workspace || typeof c.workspace.id === "undefined") return false;
                    return root._activeWorkspaceIds.includes(c.workspace.id)
                })
                root.windowListReady(filtered)
            } catch(e) {
                root.errorOccurred("Failed to parse clients: " + e.message)
            }
        }
    }
}
