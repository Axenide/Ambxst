pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import qs.modules.services
import QtQuick

/**
 * Camera device enumeration + in-use detection, backed by scripts/camera_monitor.py.
 * Exposes which cameras exist and whether any application currently holds one
 * open (privacy indicator). The scan is a cheap /proc fd walk, so a modest poll
 * interval keeps it fresh without meaningful overhead.
 */
Singleton {
    id: root

    signal cameraListChanged(var cameras)
    signal cameraUsageChanged(bool inUse, var users)

    // List of { name, node } objects, ordered by device node.
    property list<var> cameras: []
    // True while any application has a camera device open.
    property bool cameraInUse: false
    // List of { pid, name } processes holding a camera open.
    property list<var> cameraUsers: []

    // When true the UI shows the camera as disabled (privacy hint only; we
    // can't unload hardware from the shell, this is a cosmetic/OSD state).
    property bool cameraDisabled: false

    property int pollInterval: 2000

    property var suspendConnections: Connections {
        target: SuspendManager
        function onWakingUp() {
            // Devices may change on resume (usb cameras), re-scan promptly.
            cameraTimer.restart();
        }
    }

    readonly property string scriptPath: Qt.resolvedUrl("../../scripts/camera_monitor.py").toString().replace("file://", "")

    property Process cameraProcess: Process {
        id: proc
        command: ["python3", root.scriptPath]
        running: false

        stdout: StdioCollector {
            id: collector
            waitForEnd: true
        }

        onExited: (code) => {
            root._pollQueued = false;
            if (code !== 0) {
                // Missing python3 or script — keep last known state and retry.
                return;
            }
            const raw = collector.text.trim();
            if (!raw)
                return;
            try {
                const data = JSON.parse(raw);
                root.updateFromData(data);
            } catch (e) {
                console.warn("CameraService: failed to parse monitor output");
            }
        }
    }

    property bool _pollQueued: false

    function updateFromData(data) {
        const newCameras = data.cameras || [];
        const newInUse = !!data.inUse;
        const newUsers = data.users || [];

        const camChanged = !arrayEqual(root.cameras, newCameras);
        if (camChanged) {
            root.cameras = newCameras;
            root.cameraListChanged(newCameras);
        }

        if (newInUse !== root.cameraInUse || !arrayEqual(root.cameraUsers, newUsers)) {
            root.cameraInUse = newInUse;
            root.cameraUsers = newUsers;
            root.cameraUsageChanged(newInUse, newUsers);
        }
    }

    function arrayEqual(a, b) {
        if (a.length !== b.length)
            return false;
        for (let i = 0; i < a.length; i++) {
            const x = a[i], y = b[i];
            if (x === y)
                continue;
            if (!x || !y || x.name !== y.name || x.node !== y.node)
                return false;
        }
        return true;
    }

    function update() {
        if (proc.running || _pollQueued)
            return;
        _pollQueued = true;
        proc.running = true;
    }

    Timer {
        id: cameraTimer
        interval: root.pollInterval
        repeat: true
        running: true
        onTriggered: {
            if (!SuspendManager.isSuspending)
                root.update();
        }
    }

    reloadableId: "camera"

    Component.onCompleted: {
        Qt.callLater(root.update);
    }
}
