pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    readonly property string currentVersion: Config.version
    readonly property string repoCommitsUrl: "https://api.github.com/repos/Leriart/NothingLess/commits/main"
    readonly property string changelogUrl: "https://github.com/Leriart/NothingLess/releases"
    // QUICKSHELL-GIT: readonly property string cacheFile: Quickshell.cachePath("update_check.json")
    readonly property string cacheFile: Quickshell.env("HOME") + "/.cache/nothingless/update_check.json"
    readonly property string installPath: Quickshell.env("HOME") + "/.local/src/nothingless"

    property string lastSeenCommit: ""
    property string localCommit: ""
    property double lastCheckTime: 0
    property double nextCheckTime: 0

    // Public state for UI binding
    property bool isChecking: false
    property bool updateAvailable: false
    property string latestVersion: ""

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
                    root.lastSeenCommit = data.lastSeenCommit || "";
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
            lastSeenCommit: root.lastSeenCommit
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
        if (root.isChecking) return;
        root.isChecking = true;
        root.updateAvailable = false;
        root.latestVersion = "";

        // First, detect local commit via git
        detectLocalCommit(function() {
            _fetchRemoteCommit();
        });
    }

    function detectLocalCommit(callback) {
        const proc = Qt.createQmlObject('import Quickshell.Io; Process {}', root);
        proc.command = ["git", "-C", root.installPath, "rev-parse", "--short", "HEAD"];
        proc.stdout = Qt.createQmlObject('import Quickshell.Io; StdioCollector {}', proc);
        proc.onExited.connect(function(exitCode) {
            if (exitCode === 0) {
                root.localCommit = proc.stdout.text().trim();
            }
            proc.destroy();
            if (callback) callback();
        });
        proc.running = true;
    }

    function _fetchRemoteCommit() {
        const xhr = new XMLHttpRequest();
        xhr.open("GET", root.repoCommitsUrl);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                root.isChecking = false;
                if (xhr.status === 200) {
                    try {
                        const commit = JSON.parse(xhr.responseText);
                        if (commit && commit.sha) {
                            const remoteSha = commit.sha.substring(0, 7);
                            root.latestVersion = remoteSha;

                            // Compare remote commit with local commit (or last seen)
                            const knownCommit = root.localCommit || root.lastSeenCommit;
                            if (knownCommit && remoteSha !== knownCommit) {
                                root.updateAvailable = true;
                                if (remoteSha !== root.lastSeenCommit || !isNotificationInHistory()) {
                                    sendUpdateNotification(remoteSha);
                                    root.lastSeenCommit = remoteSha;
                                }
                            } else {
                                root.updateAvailable = false;
                                // Update lastSeenCommit to match current state
                                root.lastSeenCommit = knownCommit || remoteSha;
                            }
                        }
                    } catch (e) {
                        console.log("[UpdateService] Error parsing GitHub commit:", e);
                    }
                }
                root.lastCheckTime = Date.now();
                
                if (root.nextCheckTime <= Date.now()) {
                    root.nextCheckTime = Date.now() + 3600000;
                }
                
                saveCache();
            }
        }
        xhr.send();
    }

    function isNotificationInHistory() {
        if (typeof Notifications === "undefined" || !Notifications.list) return false;
        for (let i = 0; i < Notifications.list.length; i++) {
            const notif = Notifications.list[i];
            if (notif && notif.appName === "NothingLess Update") {
                return true;
            }
        }
        return false;
    }

    function sendUpdateNotification(newSha) {
        const summary = "NothingLess update available!";
        const localInfo = root.localCommit ? " (local: " + root.localCommit + ")" : "";
        const body = "New commit: " + newSha + localInfo;
        const cmd = "notify-send -a 'NothingLess Update' -i system-software-update -w '" + summary + "' '" + body + "' --action=changelog=Changelog --action=later='Maybe later' --action=update=Update";
        
        notificationProcess.running = false;
        notificationProcess.command = ["bash", "-c", cmd];
        notificationProcess.running = true;
    }

    property Process notificationProcess: Process {
        id: notificationProcess
        stdout: StdioCollector {
            id: stdoutCollector
        }
        onExited: exitCode => {
            const action = stdoutCollector.text.trim();
            if (action === "changelog") {
                Quickshell.execDetached(["xdg-open", root.changelogUrl]);
            } else if (action === "later") {
                root.nextCheckTime = Date.now() + 8 * 3600000;
                root.saveCache();
            } else if (action === "update") {
                Quickshell.execDetached(["bash", "-c", "curl -sL https://github.com/Leriart/NothingLess/raw/main/install.sh | sh"]);
            }
        }
    }
}
