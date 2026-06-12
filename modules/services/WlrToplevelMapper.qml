pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

/*!
 * \brief Maps hyprctl window data to WlrToplevel handles for ScreencopyView.
 *
 * ToplevelManager.toplevels.values provides WlrToplevel objects from
 * native Wayland surfaces. This mapper bridges the gap by matching on
 * appId/title heuristics and maintains a fallback screenshot cache
 * for windows that can't get a live toplevel preview.
 */
Singleton {
    id: root

    // ── Internal cache ──
    property var _cachedToplevels: []

    property var _toplevelValues: ToplevelManager.toplevels ? ToplevelManager.toplevels.values : []
    on_ToplevelValuesChanged: {
        root._cachedToplevels = ToplevelManager.toplevels ? ToplevelManager.toplevels.values : [];
    }

    // Poll periodically for late-registering toplevels
    Timer {
        id: pollTimer
        interval: 600
        running: true
        repeat: true
        onTriggered: {
            var fresh = ToplevelManager.toplevels ? ToplevelManager.toplevels.values : [];
            if (fresh.length !== root._cachedToplevels.length) {
                root._cachedToplevels = fresh;
            }
        }
    }

    // ═══════════════════════════════════════════════════════
    // TOPLEVEL MATCHING
    // ═══════════════════════════════════════════════════════

    /*!
     * Find the best WlrToplevel match for a given window class and title.
     * Returns null if no match found.
     *
     * Strategy in order of priority:
     *   1. Exact appId match → exact title match
     *   2. Exact appId match → partial title match
     *   3. Exact appId match → focused instance
     *   4. appId ends-with class → exact title
     *   5. appId starts-with class → exact title
     *   6. appId contains class or vice versa → title match
     *   7. Anything that matches poorly → focused instance
     */
    function find(cls, title) {
        var tls = root._cachedToplevels;
        if (!tls || tls.length === 0) return null;

        var clsRaw = cls || "";
        var clsLower = clsRaw.toLowerCase().trim();
        if (!clsLower) return null;

        var titleStr = (title || "").trim();
        var titleLower = titleStr.toLowerCase();

        // Helper: score a toplevel match
        function score(t) {
            var s = 0;
            var aLower = (t.appId || "").toLowerCase().trim();

            // Exact appId match = 100
            if (aLower === clsLower) s += 100;
            // appId ends with .cls or contains .cls.
            else if (aLower.endsWith("." + clsLower) || aLower.endsWith(clsLower)) s += 80;
            // appId starts with cls
            else if (aLower.startsWith(clsLower)) s += 70;
            // cls ends with appId (reverse DNS like org.kde.dolphin → dolphin)
            else if (clsLower.endsWith("." + aLower) || clsLower.endsWith(aLower)) s += 75;
            // cls starts with /* appId or appId starts with cls
            else if (clsLower.indexOf(aLower) >= 0 || aLower.indexOf(clsLower) >= 0) s += 60;

            if (s === 0) return 0; // No appId match at all

            // Title bonus
            var tTitle = (t.title || "").trim();
            if (tTitle === titleStr) s += 50;         // Exact title
            else if (tTitle.toLowerCase() === titleLower) s += 45;
            else {
                var tLower = tTitle.toLowerCase();
                if (titleLower.indexOf(tLower) >= 0 || tLower.indexOf(titleLower) >= 0) s += 30;
                else if (titleLower.split(/[\s-]+/).some(function(w) { return tLower.indexOf(w) >= 0; })) s += 15;
            }

            // Boost focused window
            if (t.activated) s += 10;

            return s;
        }

        // Find best match
        var best = null;
        var bestScore = 0;
        for (var i = 0; i < tls.length; i++) {
            var sc = score(tls[i]);
            if (sc > bestScore) {
                bestScore = sc;
                best = tls[i];
            }
        }

        // Only return if score is meaningful (≥60 means at least a partial appId match)
        return bestScore >= 60 ? best : null;
    }

    /*!
     * Returns all unmatched windows (cls,title pairs that had no toplevel).
     * The overview can use this to trigger grim fallback screenshots.
     */
    property var unmatchedWindows: []

    function updateUnmatched(allWindows) {
        var result = [];
        if (!allWindows) { root.unmatchedWindows = result; return; }
        for (var i = 0; i < allWindows.length; i++) {
            var w = allWindows[i];
            var tl = root.find(w.class, w.title);
            if (!tl) {
                result.push({
                    cls: w.class || "",
                    title: w.title || "",
                    addr: w.address || "",
                    at: w.at || [0, 0],
                    size: w.size || [100, 100],
                    mon: w.monitor || 0
                });
            }
        }
        root.unmatchedWindows = result;
    }

    readonly property bool hasToplevels: _cachedToplevels.length > 0
    readonly property int count: _cachedToplevels.length

    // ═══════════════════════════════════════════════════════
    // GRIM FALLBACK SCREENSHOT
    // ═══════════════════════════════════════════════════════

    // Cache of grim screenshots by window address
    property var _screenshotCache: ({})
    property bool _capturing: false

    // Take a fallback screenshot using grim (one-shot, async)
    // Output: /tmp/ambxst_preview_<addr>.png
    Process {
        id: grimProcess
        stdout: StdioCollector {
            onStreamFinished: {
                // grim writes image to stdout or file
                // We write to file: handled by command args
                root._capturing = false;
            }
        }
    }

    /*!
     * Capture a grim screenshot for a window that has no toplevel.
     * Only works for windows on the CURRENT visible workspace.
     * The image is saved to /tmp/ambxst_preview_<addr>.png
     * and can be loaded via: file:///tmp/ambxst_preview_<addr>.png
     */
    function captureScreenshot(addr, at, size) {
        if (!addr || !at || !size || root._capturing) return;
        root._capturing = true;

        var x = at[0] || 0;
        var y = at[1] || 0;
        var w = size[0] || 100;
        var h = size[1] || 100;
        var out = "/tmp/ambxst_preview_" + addr.replace(/[^a-f0-9]/g, '') + ".png";

        grimProcess.command = ["grim", "-g", x + "," + y + " " + w + "x" + h, out];
        grimProcess.running = true;
    }

    /*!
     * Get the grim screenshot path for a window address.
     * Returns null if no screenshot has been captured.
     */
    function screenshotPath(addr) {
        if (!addr) return null;
        var safe = addr.replace(/[^a-f0-9]/g, '');
        var path = "/tmp/ambxst_preview_" + safe + ".png";
        // Check if file exists by attempting to access it
        // In QML, we can't check file existence, so we just return the path
        // The Image.onStatusChanged handler can check if it loaded
        return "file://" + path;
    }

    /*!
     * Capture grim screenshots for all unmatched windows.
     * Should be called when the overview opens.
     */
    function captureAllUnmatched() {
        var um = root.unmatchedWindows;
        for (var i = 0; i < um.length; i++) {
            var win = um[i];
            root.captureScreenshot(win.addr, win.at, win.size);
        }
    }
}
