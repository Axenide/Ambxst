pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.services

QtObject {
    id: root

    property bool isRecording: false
    property string duration: ""
    property string lastError: ""
    property string currentOutputFile: ""

    // The backend owns the recorder child process directly, so the old
    // NixOS wrapper probe no longer applies.
    property bool canRecordDirectly: true

    property string videosDir: ""
    property real _elapsedBase: 0
    property date _startedAt: new Date()
    property bool _initialized: false

    function initialize() {
        if (_initialized) return;
        _initialized = true;

        subHandle = BackendService.addSubscription(["recorder"], (service, data) => {
            if (service !== "recorder.state" || !data) return;
            Qt.callLater(() => root._applyState(data));
        });

        BackendService.call("recorder.status", {}, (result, error) => {
            if (!error && result) root._applyState(result);
        });
        BackendService.call("recorder.dir", {}, (result, error) => {
            if (!error && result && result.dir) root.videosDir = result.dir;
        });
    }

    property var subHandle: null

    function _applyState(state) {
        var wasRecording = root.isRecording;
        root.isRecording = state.recording === true;
        root.lastError = state.error || "";

        if (root.isRecording) {
            if (!wasRecording) {
                root._startedAt = new Date(Date.now() - (state.elapsedMs || 0));
                root.currentOutputFile = state.path || "";
                durationTimer.start();
            }
            root._updateDuration();
        } else {
            durationTimer.stop();
            root.duration = "";
            var finishedPath = state.lastPath || root.currentOutputFile;
            if (wasRecording) {
                if (root.lastError !== "") {
                    Notifications.notifyInternal({
                        "summary": "Screen Recorder Error",
                        "body": "Failed to record. Check logs.",
                        "urgency": "critical",
                        "appName": "ScreenRecorder"
                    });
                } else if (finishedPath) {
                    root.sendSavedNotification(finishedPath);
                }
            }
            root.currentOutputFile = "";
        }
    }

    property Timer durationTimer: Timer {
        interval: 1000
        repeat: true
        running: false
        onTriggered: root._updateDuration()
    }

    function _updateDuration() {
        var elapsed = Math.max(0, Math.floor((Date.now() - root._startedAt.getTime()) / 1000));
        var h = Math.floor(elapsed / 3600);
        var m = Math.floor((elapsed % 3600) / 60);
        var s = elapsed % 60;
        var pad = n => n < 10 ? "0" + n : "" + n;
        root.duration = h > 0 ? pad(h) + ":" + pad(m) + ":" + pad(s) : pad(m) + ":" + pad(s);
    }

    function toggleRecording() {
        if (isRecording) {
            BackendService.call("recorder.stop", {});
        } else {
            // Default: Portal, no audio
            startRecording(false, false, "portal", "");
        }
    }

    function startRecording(recordAudioOutput, recordAudioInput, mode, regionStr) {
        if (isRecording)
            return;

        var params = {
            mode: mode,
            audioOut: recordAudioOutput === true,
            audioIn: recordAudioInput === true,
            framerate: 60
        };
        if (mode === "region" && regionStr) {
            params.region = regionStr;
        }

        BackendService.call("recorder.start", params, (result, error) => {
            if (error) {
                console.warn("[ScreenRecorder] Start failed: " + error);
                Notifications.notifyInternal({
                    "summary": "Screen Recorder Error",
                    "body": "Failed to start. Check logs.",
                    "urgency": "critical",
                    "appName": "ScreenRecorder"
                });
            } else if (result && result.path) {
                root.currentOutputFile = result.path;
            }
        });

        Notifications.notifyInternal({
            "summary": "Screen Recorder",
            "body": "Starting recording...",
            "appName": "ScreenRecorder",
            "expireTimeout": 2000
        });
    }

    function sendSavedNotification(path) {
        const fileName = path.substring(path.lastIndexOf("/") + 1);
        const folder = path.substring(0, path.lastIndexOf("/"));
        Notifications.notifyInternal({
            "summary": "Screen Recorder",
            "body": "Recording saved: " + fileName,
            "actions": [{
                    "identifier": "open",
                    "text": "Open"
                }, {
                    "identifier": "open-folder",
                    "text": "Open Folder"
                }],
            "actionHandlers": {
                "open": function () {
                    Quickshell.execDetached(["xdg-open", path]);
                },
                "open-folder": function () {
                    Quickshell.execDetached(["xdg-open", folder]);
                }
            }
        });
    }

    property Process openVideosProcess: Process {
        id: openVideosProcess
        command: ["xdg-open", root.videosDir]
    }

    function openRecordingsFolder() {
        openVideosProcess.running = true;
    }
}
