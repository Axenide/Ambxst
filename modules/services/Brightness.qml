pragma Singleton
pragma ComponentBehavior: Bound

// From https://github.com/caelestia-dots/shell with modifications.
// License: GPLv3

import Quickshell
import Quickshell.Io
import qs.modules.services
import QtQuick

/**
 * For managing brightness of monitors. Supports both brightnessctl and ddcutil.
 */
Singleton {
    id: root

    signal brightnessChanged(real value, var screen)

    property var ddcMonitors: []
    readonly property list<BrightnessMonitor> monitors: Quickshell.screens.map(screen => monitorComp.createObject(root, {
            screen
        }))

    property bool syncBrightness: StateService.get("syncBrightness", false)

    property var suspendConnections: Connections {
        target: SuspendManager
        function onWakingUp() {
            // Re-initialize monitors on wake with a delay
            ddcDetectTimer.restart();
        }
    }

    onSyncBrightnessChanged: {
        if (StateService.initialized) {
            StateService.set("syncBrightness", syncBrightness);
        }
    }

    Connections {
        target: StateService
        function onStateLoaded() {
            root.syncBrightness = StateService.get("syncBrightness", false);
        }
    }

    function isInternalScreen(screen: ShellScreen): bool {
        if (!screen || !screen.name)
            return false;
        const lower = screen.name.toLowerCase();
        return lower.includes("edp") || lower.includes("lvds") || lower.includes("dsi");
    }

    function getMonitorForScreen(screen: ShellScreen): var {
        return monitors.find(m => m.screen === screen);
    }

    function increaseBrightness(): void {
        const focusedName = AxctlService.focusedMonitor.name;
        const monitor = monitors.find(m => focusedName === m.screen.name);
        if (monitor)
            monitor.setBrightness(monitor.brightness + 0.05);
    }

    function decreaseBrightness(): void {
        const focusedName = AxctlService.focusedMonitor.name;
        const monitor = monitors.find(m => focusedName === m.screen.name);
        if (monitor)
            monitor.setBrightness(monitor.brightness - 0.05);
    }

    reloadableId: "brightness"

    onMonitorsChanged: {
        ddcMonitors = [];
        // Debounce detection to avoid multiple processes during wake/screen changes
        ddcDetectTimer.restart();
    }

    Timer {
        id: ddcDetectTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (!SuspendManager.isSuspending) {
                ddcProc.running = true;
            }
        }
    }

    Process {
        id: ddcProc

        command: ["ddcutil", "detect", "--brief"]
        stdout: SplitParser {
            splitMarker: "\n\n"
            onRead: data => {
                const trimmed = data.trim();
                if (!trimmed.startsWith("Display "))
                    return;

                const lines = trimmed.split("\n").map(l => l.trim()).filter(l => l.length > 0);
                const busLine = lines.find(l => l.startsWith("I2C bus:"));
                if (!busLine)
                    return;

                const busSplit = busLine.split("/dev/i2c-");
                const busNum = busSplit.length > 1 ? busSplit[1] : "";
                if (!busNum)
                    return;

                const modelLine = lines.find(l => l.startsWith("Model:"));
                const monitorLine = lines.find(l => l.startsWith("Monitor:"));
                const manufacturerLine = lines.find(l => l.startsWith("Mfg id:"));

                let model = "";
                if (modelLine) {
                    model = modelLine.split(":").slice(1).join(":").trim();
                } else if (monitorLine) {
                    model = monitorLine.split(":").slice(1).join(":").trim();
                }

                if (manufacturerLine && model) {
                    const manufacturer = manufacturerLine.split(":").slice(1).join(":").trim();
                    if (manufacturer && !model.startsWith(manufacturer))
                        model = `${manufacturer} ${model}`;
                }

                root.ddcMonitors.push({
                    model,
                    busNum
                });
            }
        }
        onExited: root.ddcMonitorsChanged()
    }

    Process {
        id: setProc
    }

    component BrightnessMonitor: QtObject {
        id: monitor

        required property ShellScreen screen
        readonly property int monitorIndex: root.monitors.indexOf(this)
        readonly property bool useBrightnessctl: root.isInternalScreen(screen)
        readonly property var ddcEntry: {
            if (useBrightnessctl || root.ddcMonitors.length === 0)
                return null;

            const usedBuses = [];
            for (let i = 0; i < monitorIndex; ++i) {
                const mon = root.monitors[i];
                if (mon && mon.ddcEntry && mon.ddcEntry.busNum && !usedBuses.includes(mon.ddcEntry.busNum))
                    usedBuses.push(mon.ddcEntry.busNum);
            }

            const screenModel = screen && screen.model ? screen.model.toLowerCase() : "";
            if (screenModel) {
                const modelMatch = root.ddcMonitors.find(entry => entry.model && entry.model.toLowerCase() === screenModel && !usedBuses.includes(entry.busNum));
                if (modelMatch)
                    return modelMatch;
            }

            for (let i = 0; i < root.ddcMonitors.length; ++i) {
                const entry = root.ddcMonitors[i];
                if (entry && entry.busNum && !usedBuses.includes(entry.busNum))
                    return entry;
            }

            return null;
        }
        readonly property bool isDdc: !useBrightnessctl && !!ddcEntry
        readonly property string busNum: isDdc ? ddcEntry.busNum : ""
        property int rawMaxBrightness: 100
        property real brightness
        property bool ready: false

        onBrightnessChanged: {
            if (monitor.ready) {
                root.brightnessChanged(monitor.brightness, monitor.screen);
            }
        }

        function initialize() {
            monitor.ready = false;
            if (!useBrightnessctl && !isDdc)
                return;
            if (isDdc && !busNum)
                return;
            initProc.command = isDdc ? ["ddcutil", "-b", busNum, "getvcp", "10"] : ["sh", "-c", `echo "a b c $(brightnessctl g) $(brightnessctl m)"`];
            initProc.running = true;
        }

        readonly property Process initProc: Process {
            stdout: SplitParser {
                onRead: data => {
                    const trimmed = data.trim();
                    // Try verbose format: "current value = X, max value = Y"
                    const verboseMatch = trimmed.match(/current\s+value\s*=\s*(\d+).*max\s+value\s*=\s*(\d+)/);
                    if (verboseMatch) {
                        const currentRaw = parseInt(verboseMatch[1]);
                        const maxRaw = parseInt(verboseMatch[2]);
                        if (!isNaN(currentRaw) && !isNaN(maxRaw) && maxRaw > 0) {
                            monitor.rawMaxBrightness = maxRaw;
                            monitor.brightness = currentRaw / monitor.rawMaxBrightness;
                            monitor.ready = true;
                            root.brightnessChanged(monitor.brightness, monitor.screen);
                        }
                        return;
                    }
                    // Fallback: token-based (brief format / brightnessctl)
                    const tokens = trimmed.split(/\s+/);
                    if (tokens.length < 2)
                        return;
                    const currentRaw = parseInt(tokens[tokens.length - 2]);
                    const maxRaw = parseInt(tokens[tokens.length - 1]);
                    if (isNaN(currentRaw) || isNaN(maxRaw) || maxRaw <= 0)
                        return;
                    monitor.rawMaxBrightness = maxRaw;
                    monitor.brightness = currentRaw / monitor.rawMaxBrightness;
                    monitor.ready = true;
                    root.brightnessChanged(monitor.brightness, monitor.screen);
                }
            }
        }

        // We need a delay for DDC monitors because they can be quite slow and might act weird with rapid changes
        property var setTimer: Timer {
            id: setTimer
            interval: monitor.isDdc ? 300 : 0
            onTriggered: {
                syncBrightness();
            }
        }

        function syncBrightness() {
            if (isDdc && !busNum)
                return;
            const rounded = Math.round(monitor.brightness * monitor.rawMaxBrightness);
            setProc.command = isDdc ? ["ddcutil", "-b", busNum, "setvcp", "10", rounded] : ["brightnessctl", "--class", "backlight", "s", rounded, "--quiet"];
            setProc.startDetached();
        }

        function setBrightness(value: real): void {
            value = Math.max(0.01, Math.min(1, value));
            monitor.brightness = value;
            setTimer.restart();
        }

        Component.onCompleted: {
            initialize();
        }

        onBusNumChanged: {
            initialize();
        }
    }

    Component {
        id: monitorComp

        BrightnessMonitor {}
    }

    IpcHandler {
        target: "brightness"

        function increment() {
            onPressed: root.increaseBrightness();
        }

        function decrement() {
            onPressed: root.decreaseBrightness();
        }

        function set(value: real, monitorName: string) {
            if (!monitorName || monitorName === "") {
                // Set all monitors
                for (let i = 0; i < root.monitors.length; ++i) {
                    const mon = root.monitors[i];
                    if (mon && mon.ready) {
                        mon.setBrightness(value);
                    }
                }
            } else {
                // Set specific monitor
                const monitor = root.monitors.find(m => m.screen.name === monitorName);
                if (monitor && monitor.ready) {
                    monitor.setBrightness(value);
                } else {
                    console.warn("Monitor not found or not ready:", monitorName);
                }
            }
        }

        function adjust(delta: real, monitorName: string) {
            if (!monitorName || monitorName === "") {
                // Adjust all monitors
                for (let i = 0; i < root.monitors.length; ++i) {
                    const mon = root.monitors[i];
                    if (mon && mon.ready) {
                        mon.setBrightness(mon.brightness + delta);
                    }
                }
            } else {
                // Adjust specific monitor
                const monitor = root.monitors.find(m => m.screen.name === monitorName);
                if (monitor && monitor.ready) {
                    monitor.setBrightness(monitor.brightness + delta);
                } else {
                    console.warn("Monitor not found or not ready:", monitorName);
                }
            }
        }
    }
}
