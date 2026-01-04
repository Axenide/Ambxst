pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.globals

QtObject {
    id: root

    signal screenshotCaptured(string path)
    signal errorOccurred(string message)
    signal windowListReady(var windows)

    property string tempPath: "/tmp/ambxst_freeze.png"
    property string cropPath: "/tmp/ambxst_crop.png"
    
    // We'll store the resolved XDG_PICTURES_DIR/Screenshots here
    property string screenshotsDir: ""
    property string finalPath: ""
    
    // Current output name for targeted capture
    property string currentOutput: ""
    
    // Internal storage for active workspace IDs
    property var _activeWorkspaceIds: []

    // Process to resolve XDG_PICTURES_DIR
    property Process xdgProcess: Process {
        id: xdgProcess
        command: ["bash", "-c", "xdg-user-dir PICTURES"]
        stdout: StdioCollector {
             onTextChanged: {
                // Not running immediately, handled in onExited
             }
        }
        running: true // Run on load
        onExited: exitCode => {
            if (exitCode === 0) {
                var dir = xdgProcess.stdout.text.trim()
                if (dir === "") {
                    // Fallback to home/Pictures if xdg-user-dir fails or returns empty
                    dir = Quickshell.env("HOME") + "/Pictures"
                }
                root.screenshotsDir = dir + "/Screenshots"
                // Ensure directory exists
                ensureDirProcess.running = true
            }
        }
    }

    property Process ensureDirProcess: Process {
        id: ensureDirProcess
        command: ["mkdir", "-p", root.screenshotsDir]
    }

    // Process for initial freeze - captures specific output
    property Process freezeProcess: Process {
        id: freezeProcess
        // Command is set dynamically in freezeScreen()
        onExited: exitCode => {
            if (exitCode === 0) {
                root.screenshotCaptured(root.tempPath)
            } else {
                root.errorOccurred("Failed to capture screen (grim)")
            }
        }
    }
    
    // Process for fetching monitors (to get active workspaces reliably)
    property Process monitorsProcess: Process {
        id: monitorsProcess
        command: ["hyprctl", "-j", "monitors"]
        stdout: StdioCollector {}
        onExited: exitCode => {
            if (exitCode === 0) {
                try {
                    var monitors = JSON.parse(monitorsProcess.stdout.text)
                    var ids = []
                    for (var i = 0; i < monitors.length; i++) {
                        if (monitors[i].activeWorkspace) {
                            ids.push(monitors[i].activeWorkspace.id)
                        }
                    }
                    root._activeWorkspaceIds = ids
                    console.log("Screenshot: Active workspaces found via hyprctl: " + JSON.stringify(ids))
                    
                    // Now fetch clients
                    clientsProcess.running = true
                } catch (e) {
                    console.warn("Screenshot: Failed to parse monitors: " + e.message)
                    // Fallback: try fetching clients anyway, filtering might fail or be permissive
                    root._activeWorkspaceIds = []
                    clientsProcess.running = true
                }
            } else {
                console.warn("Screenshot: Failed to fetch monitors")
                root._activeWorkspaceIds = []
                clientsProcess.running = true
            }
        }
    }

    // Process for fetching windows
    property Process clientsProcess: Process {
        id: clientsProcess
        command: ["hyprctl", "-j", "clients"]
        stdout: StdioCollector {}
        onExited: exitCode => {
            if (exitCode === 0) {
                try {
                    var allClients = JSON.parse(clientsProcess.stdout.text)
                    
                    // Filter using the IDs we got from monitorsProcess
                    var activeIds = root._activeWorkspaceIds
                    
                    var filteredClients = allClients.filter(c => {
                        // Keep pinned windows OR windows on active workspaces
                        return c.pinned || (activeIds.length > 0 && activeIds.includes(c.workspace.id))
                    })
                    
                    console.log("Screenshot: Total clients: " + allClients.length + ", Filtered: " + filteredClients.length)
                    
                    root.windowListReady(filteredClients)
                    
                } catch (e) {
                    console.warn("Screenshot: Error processing windows: " + e.message)
                    root.errorOccurred("Failed to parse window list: " + e.message)
                }
            } else {
                console.warn("Screenshot: hyprctl clients failed with code " + exitCode)
            }
        }
    }

    // Process for cropping/saving
    property Process cropProcess: Process {
        id: cropProcess
        // command set dynamically
        onExited: exitCode => {
            if (exitCode === 0) {
                // After successful save/crop, copy to clipboard
                copyProcess.running = true
            } else {
                root.errorOccurred("Failed to save image")
            }
        }
    }

    property Process copyProcess: Process {
        id: copyProcess
        command: ["bash", "-c", `wl-copy < "${root.finalPath}"`]
        onExited: exitCode => {
            if (exitCode !== 0) {
                console.warn("Failed to copy to clipboard")
            }
        }
    }

    function freezeScreen(outputName) {
        root.currentOutput = outputName || ""
        if (root.currentOutput !== "") {
            // Capture specific output
            freezeProcess.command = ["grim", "-o", root.currentOutput, root.tempPath]
        } else {
            // Fallback to all outputs
            freezeProcess.command = ["grim", root.tempPath]
        }
        freezeProcess.running = true
    }

    function fetchWindows() {
        // Start the chain: Monitors -> Clients
        monitorsProcess.running = true
    }

    function getTimestamp() {
        // Simple timestamp format YYYY-MM-DD-HH-mm-ss
        var d = new Date()
        // Manually format to avoid weird ISO chars
        var pad = (n) => n < 10 ? '0' + n : n;
        return d.getFullYear() + '-' + 
               pad(d.getMonth() + 1) + '-' + 
               pad(d.getDate()) + '-' + 
               pad(d.getHours()) + '-' + 
               pad(d.getMinutes()) + '-' + 
               pad(d.getSeconds());
    }

    function processRegion(x, y, w, h) {
        if (root.screenshotsDir === "") {
            // Fallback if xdg process hasn't finished yet?
             root.screenshotsDir = Quickshell.env("HOME") + "/Pictures/Screenshots"
        }
        
        var filename = "Screenshot_" + getTimestamp() + ".png"
        root.finalPath = root.screenshotsDir + "/" + filename
        
        // Ensure integer values for geometry
        var ix = Math.round(x)
        var iy = Math.round(y)
        var iw = Math.round(w)
        var ih = Math.round(h)
        
        // convert /tmp/ambxst_freeze.png -crop WxH+X+Y /path/to/save.png
        var geom = `${iw}x${ih}+${ix}+${iy}`
        console.log("Screenshot: Cropping region:", geom)
        cropProcess.command = ["convert", root.tempPath, "-crop", geom, "+repage", root.finalPath]
        cropProcess.running = true
    }

    function processFullscreen() {
        if (root.screenshotsDir === "") {
             root.screenshotsDir = Quickshell.env("HOME") + "/Pictures/Screenshots"
        }
        
        var filename = "Screenshot_" + getTimestamp() + ".png"
        root.finalPath = root.screenshotsDir + "/" + filename

        // Just copy the freeze file to final path
        cropProcess.command = ["cp", root.tempPath, root.finalPath]
        cropProcess.running = true
    }

    property Process openScreenshotsProcess: Process {
        id: openScreenshotsProcess
        command: ["xdg-open", root.screenshotsDir]
    }

    function openScreenshotsFolder() {
        if (root.screenshotsDir === "") {
             // Fallback attempt if not ready
             openScreenshotsProcess.command = ["xdg-open", Quickshell.env("HOME") + "/Pictures/Screenshots"];
        } else {
             openScreenshotsProcess.command = ["xdg-open", root.screenshotsDir];
        }
        openScreenshotsProcess.running = true;
    }
}
