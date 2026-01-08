pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Path to usage.json file in dataPath
    property string usageFilePath: Quickshell.dataPath("usage.json")
    
    // In-memory cache: { appId: { count: N, lastUsed: timestamp } }
    property var usageData: ({})
    
    // Decay factor for time-based scoring (apps used recently get higher scores)
    readonly property int maxBoostScore: 200
    readonly property int dayInMs: 86400000
    
    // Process for reading usage data
    property Process readProcess: Process {
        id: readProc
        running: false
        
        onExited: function (exitCode, exitStatus) {
            if (exitCode === 0 && stdout.trim() !== "") {
                try {
                    root.usageData = JSON.parse(stdout);
                } catch (e) {
                    console.warn("UsageTracker: Failed to parse usage.json:", e);
                    root.usageData = {};
                }
            } else {
                root.usageData = {};
            }
        }
    }
    
    // Process for writing usage data
    property Process writeProcess: Process {
        id: writeProc
        running: false
        
        onExited: function (exitCode, exitStatus) {
            if (exitCode !== 0) {
                console.warn("UsageTracker: Failed to write usage.json");
            }
        }
    }

    Component.onCompleted: {
        loadUsageData();
    }

    // Load usage data from file
    function loadUsageData() {
        readProc.command = ["bash", "-c", "cat " + usageFilePath + " 2>/dev/null || echo '{}'"];
        readProc.running = true;
    }

    // Save usage data to file
    function saveUsageData() {
        var jsonData = JSON.stringify(usageData, null, 2);
        // Escape single quotes for bash
        jsonData = jsonData.replace(/'/g, "'\\''");
        writeProc.command = ["bash", "-c", "echo '" + jsonData + "' > " + usageFilePath];
        writeProc.running = true;
    }

    // Record that an app was used
    function recordUsage(appId) {
        if (!appId) {
            console.warn("UsageTracker: recordUsage called with empty appId");
            return;
        }

        var now = Date.now();
        
        if (usageData[appId]) {
            usageData[appId].count++;
            usageData[appId].lastUsed = now;
        } else {
            usageData[appId] = {
                count: 1,
                lastUsed: now
            };
        }
        
        // Force property change notification
        usageData = usageData;
        
        saveUsageData();
    }

    // Get usage score for an app (used for sorting)
    // Higher score = more recently/frequently used
    function getUsageScore(appId) {
        if (!appId || !usageData[appId]) {
            return 0;
        }

        var data = usageData[appId];
        var now = Date.now();
        var daysSinceLastUse = (now - data.lastUsed) / dayInMs;
        
        // Time decay: apps used within last day get full boost, then decay exponentially
        // Formula: baseScore + (maxBoost * e^(-daysSinceLastUse/7))
        // This gives apps used in the last week a significant boost, with decay over time
        var timeBoost = maxBoostScore * Math.exp(-daysSinceLastUse / 7);
        
        // Frequency score: logarithmic scale to prevent over-weighting heavily used apps
        var frequencyScore = Math.log(data.count + 1) * 20;
        
        return timeBoost + frequencyScore;
    }

    // Get all apps sorted by usage (most used/recent first)
    function getTopApps(limit) {
        if (!limit) limit = 10;
        
        var apps = [];
        for (var appId in usageData) {
            apps.push({
                appId: appId,
                score: getUsageScore(appId),
                count: usageData[appId].count,
                lastUsed: usageData[appId].lastUsed
            });
        }
        
        apps.sort(function(a, b) {
            return b.score - a.score;
        });
        
        return apps.slice(0, limit);
    }

    // Clear old entries (apps not used in 90 days)
    function pruneOldEntries() {
        var now = Date.now();
        var ninetyDaysInMs = dayInMs * 90;
        var changed = false;
        
        for (var appId in usageData) {
            if (now - usageData[appId].lastUsed > ninetyDaysInMs) {
                delete usageData[appId];
                changed = true;
            }
        }
        
        if (changed) {
            usageData = usageData;
            saveUsageData();
        }
    }
}
