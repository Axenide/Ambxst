pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.modules.services

Singleton {
    id: root

    readonly property string currentVersion: Config.version
    readonly property string repoUrl: "https://api.github.com/repos/Axenide/Ambxst/tags"
    readonly property string changelogUrl: "https://axeni.de/ambxst/changelog"
    // QUICKSHELL-GIT: readonly property string cacheFile: Quickshell.cachePath("update_check.json")
    readonly property string cacheFile: Quickshell.env("HOME") + "/.cache/ambxst/update_check.json"

    property string lastDetectedVersion: ""
    property double lastCheckTime: 0
    property double nextCheckTime: 0

    FileView {
        id: cacheFileView
        path: root.cacheFile
        onLoaded: {
            try {
                const content = text();
                if (content && content.trim() !== "") {
                    const data = JSON.parse(content);
                    root.lastCheckTime = data.lastCheckTime || 0;
                    root.nextCheckTime = data.nextCheckTime || 0;
                    root.lastDetectedVersion = data.lastDetectedVersion || "";
                } else {
                    root.nextCheckTime = Date.now();
                }
            } catch (e) {
                console.log("[UpdateService] Error loading update cache:", e);
                root.nextCheckTime = Date.now();
            }
        }
    }

    function saveCache() {
        const data = {
            lastCheckTime: root.lastCheckTime,
            nextCheckTime: root.nextCheckTime,
            lastDetectedVersion: root.lastDetectedVersion
        };
        cacheFileView.setText(JSON.stringify(data));
    }

    Timer {
        id: startupDelay
        interval: 2000
        running: true
        onTriggered: {
            if (Config.system.updateServiceEnabled) {
                checkUpdates();
            }
            checkTimer.running = true;
        }
    }

    Timer {
        id: checkTimer
        interval: 300000 // Every 5 minutes check if it's time
        running: false
        repeat: true
        onTriggered: {
            if (!Config.system.updateServiceEnabled) return;
            const now = Date.now();
            if (now >= root.nextCheckTime) {
                checkUpdates();
            }
        }
    }

    function checkUpdates() {
        const xhr = new XMLHttpRequest();
        xhr.open("GET", root.repoUrl);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        const tags = JSON.parse(xhr.responseText);
                        if (tags && Array.isArray(tags) && tags.length > 0) {
                            const latestTag = tags[0].name.replace(/^v/, "");
                            if (isNewer(latestTag, root.currentVersion)) {
                                if (latestTag !== root.lastDetectedVersion || !isNotificationInHistory()) {
                                    sendUpdateNotification(latestTag);
                                    root.lastDetectedVersion = latestTag;
                                }
                            }
                        }
                    } catch (e) {
                        console.log("[UpdateService] Error parsing GitHub tags:", e);
                    }
                }
                root.lastCheckTime = Date.now();
                
                // If nextCheckTime is in the past or now, set it to 1 hour from now
                if (root.nextCheckTime <= Date.now()) {
                    root.nextCheckTime = Date.now() + 3600000;
                }
                
                saveCache();
            }
        }
        xhr.send();
    }

    function isNewer(latest, current) {
        const l = latest.split('.').map(Number);
        const c = current.split('.').map(Number);
        for (let i = 0; i < Math.max(l.length, c.length); i++) {
            const lv = l[i] || 0;
            const cv = c[i] || 0;
            if (lv > cv) return true;
            if (lv < cv) return false;
        }
        return false;
    }

    function isNotificationInHistory() {
        if (typeof Notifications === "undefined" || !Notifications.list) return false;
        for (let i = 0; i < Notifications.list.length; i++) {
            const notif = Notifications.list[i];
            if (notif && notif.appName === "Ambxst Update") {
                return true;
            }
        }
        return false;
    }

    function sendUpdateNotification(newVersion) {
        const summary = "Ambxst update available!";
        const body = newVersion + " available! (Installed " + root.currentVersion + ")";

        // Routed through Ambxst's Notifications service so it can be
        // dismissed/tracked like every other Ambxst notification instead
        // of leaking into the system daemon. The actions keep their
        // previous behavior via localActionHandlers — `attemptInvokeAction`
        // fires them when the user clicks a button.
        Notifications.notifyInternal({
            summary: summary,
            body: body,
            appName: "Ambxst Update",
            appIcon: "system-software-update",
            urgency: "normal",
            replaceKey: "ambxst-update-available",
            actions: [
                { identifier: "changelog", text: "Changelog" },
                { identifier: "later",     text: "Maybe later" },
                { identifier: "update",    text: "Update" }
            ],
            actionHandlers: {
                "changelog": function () {
                    Quickshell.execDetached(["xdg-open", root.changelogUrl]);
                },
                "later": function () {
                    root.nextCheckTime = Date.now() + 8 * 3600000;
                    root.saveCache();
                },
                "update": function () {
                    TerminalService.execDetached("ambxst update; exec $SHELL");
                }
            }
        });
    }
        }
    }
}
