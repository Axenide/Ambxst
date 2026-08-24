pragma Singleton

import QtQuick
import QtQml
import Quickshell
import Quickshell.Io
import qs.modules.globals
import qs.config

// WallpaperCommandService is the QML subscriber for the "wallpaper" IPC
// service. The CLI dispatches a one-shot `wallpaper.set` event with the
// file path and optional scheme/oled/tint/monitor overrides; this
// service applies them through the same Wallpaper.qml API the UI uses.
//
// The `-oled` and `-tint` flags are run-time toggles: they don't persist
// to the JSON config on disk. We achieve that by suspending the Config
// auto-save while the values flip, then resuming it on the next tick.
//
// Ad-hoc files (those outside the configured wallpaper directory) are
// copied into the directory before they're applied. That keeps
// setWallpaper's existing single-source-of-truth invariant — the path
// must live in wallpaperPaths — while letting `ambxst wallpaper <any>`
// just work.
//
// When `-monitor` is omitted, we propagate the new wallpaper to every
// screen Quickshell knows about (plus anything already pinned in
// perScreenWallpapers). Wallpaper.qml's `effectiveWallpaper` prefers the
// per-screen entry over the global `currentWall` — without touching it,
// the call would only update the fallback and any screen with its own
// override would stay put.
Singleton {
    id: root

    Component.onCompleted: {
        BackendService.addSubscription(["wallpaper"], (service, data) => {
            if (service === "wallpaper.set" && data) {
                root.apply(data);
            }
        });
    }

    // Best-effort copy of an external path into the configured wallpaper
    // directory. Returns the original path if it's already inside the
    // directory, or a fresh absolute path on success. Falls back to the
    // original path on any error so callers can still attempt to apply.
    function importInto(path) {
        const manager = GlobalStates.wallpaperManager;
        if (!manager || !manager.wallpaperDir) return path;

        let target = manager.wallpaperDir;
        while (target.endsWith("/")) target = target.substring(0, target.length - 1);
        if (target === "" || path === target) return path;
        if (path.startsWith(target + "/")) return path;

        const base = path.substring(path.lastIndexOf("/") + 1) || "wallpaper";
        const stamp = Date.now();
        const safe = base.replace(/[^A-Za-z0-9._-]/g, "_");
        const dst = target + "/cli_" + stamp + "_" + safe;
        importProcess.command = ["cp", "--", path, dst];
        importProcess.destination = dst;
        importProcess.sourcePath = path;
        importProcess.running = true;
        return dst;
    }

    Process {
        id: importProcess
        property string destination: ""
        property string sourcePath: ""
        running: false
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                console.warn("WallpaperCommandService: copy failed, applying source path directly:", sourcePath);
                root._apply(root._pendingMonitor, sourcePath);
            } else {
                root._apply(root._pendingMonitor, destination);
            }
        }
    }

    property string _pendingMonitor: ""

    // Collect every screen name we should propagate to. Includes the
    // screens Quickshell knows about plus any monitor name already pinned
    // in perScreenWallpapers — the latter matters for setups where
    // wallpaper.set goes through before the user has the second monitor
    // attached at boot.
    function collectAllScreenNames() {
        const names = new Set();
        if (Quickshell && Quickshell.screens) {
            for (let i = 0; i < Quickshell.screens.length; i++) {
                const s = Quickshell.screens[i];
                if (s && s.name) names.add(s.name);
            }
        }
        try {
            const manager = GlobalStates.wallpaperManager;
            if (manager) {
                const perScreen = manager.perScreenWallpapers || {};
                for (const k in perScreen) {
                    if (k) names.add(k);
                }
            }
        } catch (e) { /* best effort */ }
        return Array.from(names);
    }

    function _apply(monitor, resolvedPath) {
        const manager = GlobalStates.wallpaperManager;
        if (!manager) {
            root._pendingMonitor = "";
            return;
        }
        if (monitor) {
            manager.setWallpaper(resolvedPath, monitor);
            root._pendingMonitor = "";
            return;
        }
        const screens = collectAllScreenNames();
        if (screens.length === 0) {
            // No monitors known — fall back to the manager's own screen.
            manager.setWallpaper(resolvedPath, null);
        } else {
            for (let i = 0; i < screens.length; i++) {
                manager.setWallpaper(resolvedPath, screens[i]);
            }
        }
        root._pendingMonitor = "";
    }

    function apply(payload) {
        if (!payload || !payload.path) {
            console.warn("WallpaperCommandService: missing path");
            return;
        }
        const manager = GlobalStates.wallpaperManager;
        if (!manager) {
            console.warn("WallpaperCommandService: no wallpaper manager yet");
            return;
        }

        if (typeof payload.scheme === "string" && payload.scheme !== "") {
            manager.setMatugenScheme(payload.scheme);
        }

        if (payload.oled !== undefined || payload.tint !== undefined) {
            Config.pauseAutoSave = true;
            try {
                if (payload.oled !== undefined) {
                    Config.theme.oledMode = payload.oled === true;
                }
                if (payload.tint !== undefined) {
                    manager.tintEnabled = payload.tint === true;
                }
            } finally {
                Qt.callLater(() => { Config.pauseAutoSave = false; });
            }
        }

        const monitor = typeof payload.monitor === "string" && payload.monitor !== "" ? payload.monitor : "";
        _pendingMonitor = monitor;

        const candidate = importInto(payload.path);
        // If the file is already in the configured directory the import
        // function returns the original path synchronously and the
        // process.onExited callback never fires — call _apply directly.
        if (candidate === payload.path) {
            _apply(monitor, payload.path);
        }
    }
}
