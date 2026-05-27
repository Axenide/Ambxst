pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.globals

QtObject {
    id: root

    signal screenshotCaptured(string path) // Generic signal (maybe unused now for per-monitor)
    signal monitorScreenshotReady(string monitorName, string path) // NEW: Signal for per-monitor readiness
    signal errorOccurred(string message)
    signal windowListReady(var windows)
    signal monitorsListReady(var monitors)
    signal lensImageReady(string path)
    signal imageSaved(string path) // New signal for Overlay

    property string tempPathBase: "/tmp/ambxst_freeze"
    property string cropPath: "/tmp/ambxst_crop.png"
    property string lensPath: "/tmp/image.png"
    
    property string captureMode: "normal"
    
    property string screenshotsDir: ""
    property string finalPath: ""
    
    property var _activeWorkspaceIds: []
    property var monitors: [] // List of monitor objects
    
    // Selection state to synchronize UI across monitors
    property int selectionX: 0
    property int selectionY: 0
    property int selectionW: 0
    property int selectionH: 0
    
    // Store monitor scale factor for coordinate scaling
    property real monitorScale: 1.0

    property bool _initialized: false

    function initialize() {
        if (_initialized) return;
        _initialized = true;
        xdgProcess.running = true;
    }

    // Process to resolve XDG_PICTURES_DIR
    property Process xdgProcess: Process {
        id: xdgProcess
        command: ["bash", "-c", "xdg-user-dir PICTURES"]
        stdout: StdioCollector {
             onTextChanged: {
                // Not running immediately, handled in onExited
             }
        }
        running: false
        onExited: exitCode => {
            if (exitCode === 0) {
                var dir = xdgProcess.stdout.text.trim()
                if (dir === "") {
                    dir = Quickshell.env("HOME") + "/Pictures"
                }
                root.screenshotsDir = dir + "/Screenshots"
                ensureDirProcess.running = true
            }
        }
    }

    property Process ensureDirProcess: Process {
        id: ensureDirProcess
        command: ["mkdir", "-p", root.screenshotsDir]
    }

    // Dynamic list of freeze processes, managed via bash for simplicity?
    // Or we can use a single shell script that forks grim for each monitor.
    // "grim -o name1 path1 & grim -o name2 path2 & wait"
    property Process freezeProcess: Process {
        id: freezeProcess
        // Command built dynamically
        command: [] 
        onExited: exitCode => {
            root._freezing = false; // Reset lock flag
            if (exitCode === 0) {
                // Notify all monitors that their screenshot is ready
                // We assume if the batch command finished, all are done.
                for (var i = 0; i < root.monitors.length; i++) {
                    var m = root.monitors[i];
                    var path = root.tempPathBase + "_" + m.name + ".png";
                    root.monitorScreenshotReady(m.name, path);
                }
                // Also emit generic for compatibility?
                root.screenshotCaptured(root.tempPathBase + "_ALL.png") // Dummy path?
            } else {
                root.errorOccurred("Failed to capture screen (grim)")
                root._freezing = false;
            }
        }
    }
    
    // Process for fetching monitors
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
                    root.windowListReady(filteredClients)
                } catch (e) {
                    console.warn("Screenshot: Error processing windows: " + e.message)
                }
            }
        }
    }

    // Process for cropping/saving
    property Process cropProcess: Process {
        id: cropProcess
        // command set dynamically
        onExited: exitCode => {
            if (exitCode === 0) {
                if (root.captureMode === "lens") {
                    root.runLensScript()
                    root.captureMode = "normal" 
                } else {
                    copyProcess.running = true
                    root.imageSaved(root.finalPath)
                }
            } else {
                root.errorOccurred("Failed to save image")
            }
        }
    }

    property Process copyProcess: Process {
        id: copyProcess
        command: ["bash", "-c", `cat "${root.finalPath}" | wl-copy --type image/png`]
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) console.warn("Screenshot Copy Error: " + text)
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0) {
                console.warn("Failed to copy to clipboard (Exit code: " + exitCode + ")")
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
                root.errorOccurred("Failed to open Google Lens: " + lensProcess.stderr.text)
            }
        }
    }

    // Prevent double execution
    property bool _freezing: false

    function freezeScreen() {
        if (_freezing) return;
        _freezing = true;

        // FAST PATH: Use Quickshell.screens to start freeze immediately
        // Map Quickshell screens to the format expected (physical dimensions)
        var qsScreens = Quickshell.screens;
        var mappedMonitors = [];
        for (var i = 0; i < qsScreens.length; i++) {
             var s = qsScreens[i];
             mappedMonitors.push({
                 id: i, // Dummy ID
                 name: s.name,
                 x: s.x,
                 y: s.y,
                 width: s.width * s.scale, // approx physical width
                 height: s.height * s.scale, // approx physical height
                 scale: s.scale
             });
        }
        root.monitors = mappedMonitors;
        
        // Trigger freeze immediately
        root.executeFreezeBatch();

		root.fetchWindows();
    }
    
    function fetchWindows() {
        // Start fetching full metadata (workspaces) for Window Mode
        monitorsProcess.running = true
    }
    
    function executeFreezeBatch() {
        if (root.monitors.length === 0) {
            console.warn("Screenshot: No monitors found to freeze");
            _freezing = false;
            return;
        }
        
        // Build a single command string to run grim for all monitors in parallel
        // cmd: grim -o output1 path1 & grim -o output2 path2 & wait
        var cmd = "";
        for (var i = 0; i < root.monitors.length; i++) {
            var m = root.monitors[i];
            var path = root.tempPathBase + "_" + m.name + ".png";
            // Ensure path is quoted safely
            cmd += `grim -o "${m.name}" "${path}" & `;
        }
        cmd += "wait";
        
        console.log("Screenshot: Executing freeze batch: " + cmd);
        freezeProcess.command = ["bash", "-c", cmd];
        freezeProcess.running = true;
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

    // Modified processRegion to handle per-monitor cropping
    // It finds the monitor for the given coords, loads THAT monitor's freeze file, and crops.
    function processRegion(x, y, w, h) {
        if (root.captureMode === "lens") {
            root.finalPath = root.lensPath;
        } else {
            if (root.screenshotsDir === "") {
                root.screenshotsDir = Quickshell.env("HOME") + "/Pictures/Screenshots"
            }
            var filename = "Screenshot_" + getTimestamp() + ".png"
            root.finalPath = root.screenshotsDir + "/" + filename
        }
        
        // Find monitor for these global logical coordinates
        var m = null;
        if (root.monitors.length > 0) {
            // Check which monitor contains the center of the region?
            // Or the top-left? Top-left is safer.
            // Note: monitor.x and monitor.y are logical position
            // monitor.width is PHYSICAL width. logical width = width / scale
            m = root.monitors.find(mon => {
                var logicalW = mon.width / mon.scale;
                var logicalH = mon.height / mon.scale;

				// When monitors are rotated, we use the height for width and vice versa
				// 1 = 90 deg, 3 = 270 deg, 5 = 90 deg mirrored, 7 = 270 deg mirrored
				// source: https://wiki.hypr.land/Configuring/Monitors/#rotating
				// this way we select the correct monitor
				if(mon.transform === 1 || mon.transform === 3 || mon.transform === 5 || mon.transform === 7) {
					var logicalW  = mon.height / mon.scale;
					var logicalH  = mon.width / mon.scale;
				}

                return x >= mon.x && x < (mon.x + logicalW) &&
                       y >= mon.y && y < (mon.y + logicalH);
            });
        }
        
        if (!m) {
            console.warn("Screenshot: Could not find monitor for region " + x + "," + y);
            // Fallback? Try to use first monitor?
            if (root.monitors.length > 0) m = root.monitors[0];
            else return; 
        }
        
        // Calculate coordinates relative to that monitor
        var localX = x - m.x;
        var localY = y - m.y;
        
        // Convert to physical coordinates for cropping the PHYSICAL grim output for THIS monitor
        // Grim output for a single monitor is just size WxH (physical).
        var physX = Math.round(localX * m.scale);
        var physY = Math.round(localY * m.scale);
        var physW = Math.round(w * m.scale);
        var physH = Math.round(h * m.scale);
        
        console.log(`Screenshot: Cropping on monitor ${m.name} (Scale ${m.scale})`);
        console.log(`Screenshot: Logical Local: ${localX},${localY} ${w}x${h} -> Physical: ${physX},${physY} ${physW}x${physH}`);
        
        var srcPath = root.tempPathBase + "_" + m.name + ".png";
        
        // convert input.png -crop WxH+X+Y output.png
        var geom = `${physW}x${physH}+${physX}+${physY}`;
        cropProcess.command = ["convert", srcPath, "-crop", geom, root.finalPath];
        cropProcess.running = true;
    }

    function processFullscreen() {
        if (root.captureMode === "lens") {
            root.finalPath = root.lensPath;
        } else {
            if (root.screenshotsDir === "") {
                root.screenshotsDir = Quickshell.env("HOME") + "/Pictures/Screenshots"
            }
            var filename = "Screenshot_" + getTimestamp() + ".png"
            root.finalPath = root.screenshotsDir + "/" + filename
        }

        // Fullscreen capture usually means "All Screens" or "Current Screen"?
        // The previous implementation was "All Screens".
        // But users usually want "Current Screen" if they click on a screen.
        // However, if we want ALL screens stitched, we'd need to stitch them ourselves now.
        // Let's assume the user clicked on a specific screen, so we capture THAT screen.
        // We need to know WHICH screen was clicked. 
        // But processFullscreen() takes no arguments currently.
        // We should modify it to take a monitor name or coords.
        
        // For now, let's implement "Capture Monitor under Mouse" if possible?
        // Or if we can't easily, maybe we just stitch them all?
        // Stitching is complex. 
        
        // Let's try to infer from mouse position? We don't have it here.
        // Let's assume the focused monitor?
        // Let's default to primary or first monitor for safety if no context provided.
        // Ideally, we update ScreenshotTool to pass the screen name.
        
        // TEMPORARY: Just capture the first monitor to verify the pipeline works.
        // Or better: Re-run grim without -o to get the full stitched image again?
        // That duplicates work but is safest for "Full Screenshot".
        
        var cmd = ["grim", root.finalPath];
        cropProcess.command = cmd;
        cropProcess.running = true;
    }
    
    // Overloaded processFullscreen to take a screen name (for "Screen" mode on specific monitor)
    function processMonitorScreen(monitorName) {
         if (root.captureMode === "lens") {
            root.finalPath = root.lensPath;
        } else {
            if (root.screenshotsDir === "") {
                root.screenshotsDir = Quickshell.env("HOME") + "/Pictures/Screenshots"
            }
            var filename = "Screenshot_" + getTimestamp() + ".png"
            root.finalPath = root.screenshotsDir + "/" + filename
        }
        
        var srcPath = root.tempPathBase + "_" + monitorName + ".png";
        cropProcess.command = ["cp", srcPath, root.finalPath];
        cropProcess.running = true;
    }

    property Process openScreenshotsProcess: Process {
        id: openScreenshotsProcess
        command: ["xdg-open", root.screenshotsDir]
    }

    function openScreenshotsFolder() {
        if (root.screenshotsDir === "") {
             openScreenshotsProcess.command = ["xdg-open", Quickshell.env("HOME") + "/Pictures/Screenshots"];
        } else {
             openScreenshotsProcess.command = ["xdg-open", root.screenshotsDir];
        }
        openScreenshotsProcess.running = true;
    }

    function runLensScript() {
        var scriptPath = Qt.resolvedUrl("../../scripts/google_lens.sh").toString().replace("file://", "");
        verifyImageProcess.command = ["test", "-f", root.lensPath];
        verifyImageProcess.running = true;
    }
    
    property Process verifyImageProcess: Process {
        id: verifyImageProcess
        onExited: exitCode => {
            if (exitCode === 0) {
                var scriptPath = Qt.resolvedUrl("../../scripts/google_lens.sh").toString().replace("file://", "");
                lensProcess.command = ["bash", scriptPath];
                lensProcess.running = true;
            } else {
                root.errorOccurred("Image file not ready for Google Lens")
            }
        }
    }
}
