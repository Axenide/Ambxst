pragma Singleton

import QtQuick
import QtQml
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string scriptPath: Qt.resolvedUrl("../../scripts/monitors_writer.py").toString().replace("file://", "")

    signal syncFinished(bool success, string message)
    signal monitorsListed(var monitors)

    // ── List monitors ──

    function listMonitors() {
        listProc.running = false;
        listProc.command = ["python3", root.scriptPath, "list"];
        listProc.running = true;
    }

    property Process listProc: Process {
        command: ["echo", ""]
        stdout: StdioCollector { id: listOut }
        running: false
        onExited: exitCode => {
            if (exitCode === 0) {
                try {
                    root.monitorsListed(JSON.parse(listOut.text));
                } catch (e) {
                    console.warn("MonitorsWriter list parse:", e);
                    root.monitorsListed([]);
                }
            } else {
                root.monitorsListed([]);
            }
        }
    }

    // ── Sync ──

    function syncWithData(monitorData) {
        if (!monitorData || monitorData.length === 0) return;
        var jsonStr = JSON.stringify(monitorData);
        syncProc.running = false;
        syncProc.command = ["python3", root.scriptPath, "sync", "--data", jsonStr];
        syncProc.running = true;
    }

    function sync() {
        syncProc.running = false;
        syncProc.command = ["python3", root.scriptPath, "sync"];
        syncProc.running = true;
    }

    property Process syncProc: Process {
        command: ["echo", ""]
        stdout: StdioCollector { id: syncOut }
        stderr: StdioCollector { id: syncErr }
        running: false
        onExited: exitCode => {
            var out = (syncOut.text || "") + (syncErr.text || "");
            var ok = exitCode === 0;
            console.log("MonitorsWriter:", out.trim() || (ok ? "OK" : "FAIL"));
            root.syncFinished(ok, ok ? "OK" : out.trim());
            // Do NOT call CompositorTomlWriter.writeTomlFile() here.
            // monitors_writer.py already writes [[monitors]] to axctl.toml.
            // Calling writeTomlFile() would OVERWRITE the entire toml file,
            // removing the [[monitors]] section that was just written.
        }
    }
}
