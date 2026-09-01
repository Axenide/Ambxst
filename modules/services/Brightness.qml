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

        // Echo-skip state: record user-originated writes so silentRefresh()
        // (triggered by `ambxst brightness -r`) can ignore a hardware read
        // that races with an in-flight debounced write, instead of clobbering
        // the QML state with a stale mid-ramp value.
        property real lastUserWriteValue: 0
        property int lastUserWriteAt: 0

        // Concurrency guard for silentRefresh — a second pull while one is
        // already in flight reassigns initProc.command and would cancel the
        // first read, leaving the QML state stuck on the previous value.
        property bool silentRefreshInFlight: false

        // Dispatches the initProc stdout callback: "init" updates readiness
        // (used at startup and on bus-number changes), "refresh" skips the
        // readiness flip and applies echo-skip logic.
        property string readContext: "init"

        // Safety net: clear silentRefreshInFlight after 5s in case the
        // kernel never produces a response (DDC bus hung). The onExited
        // handler clears it earlier under normal conditions.
        property var refreshTimeout: Timer {
            interval: 5000
            repeat: false
            onTriggered: monitor.silentRefreshInFlight = false
        }
        onSilentRefreshInFlightChanged: refreshTimeout.running = monitor.silentRefreshInFlight

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
            monitor.readContext = "init";
            initProc.command = isDdc ? ["ddcutil", "-b", busNum, "getvcp", "10"] : ["sh", "-c", `echo "a b c $(brightnessctl g) $(brightnessctl m)"`];
            initProc.running = true;
        }

        // silentRefresh re-reads the monitor's brightness without
        // flipping `ready` (so an active slider drag or keybind hold is
        // not interrupted) and applies echo-skip logic to avoid stomping
        // on an in-flight debounced write.
        function silentRefresh() {
            if (!useBrightnessctl && !isDdc)
                return;
            if (isDdc && !busNum)
                return;
            if (monitor.silentRefreshInFlight)
                return;
            monitor.silentRefreshInFlight = true;
            monitor.readContext = "refresh";
            initProc.command = isDdc ? ["ddcutil", "-b", busNum, "getvcp", "10"] : ["sh", "-c", `echo "a b c $(brightnessctl g) $(brightnessctl m)"`];
            initProc.running = true;
        }

        readonly property Process initProc: Process {
            onExited: exitCode => {
                if (monitor.readContext === "refresh" && exitCode !== 0)
                    monitor.silentRefreshInFlight = false;
            }
            stdout: SplitParser {
                onRead: data => {
                    const trimmed = data.trim();
                    // Try verbose format: "current value = X, max value = Y"
                    const verboseMatch = trimmed.match(/current\s+value\s*=\s*(\d+).*max\s+value\s*=\s*(\d+)/);
                    let currentRaw = NaN;
                    let maxRaw = NaN;
                    if (verboseMatch) {
                        currentRaw = parseInt(verboseMatch[1]);
                        maxRaw = parseInt(verboseMatch[2]);
                    } else {
                        // Fallback: token-based (brief format / brightnessctl)
                        const tokens = trimmed.split(/\s+/);
                        if (tokens.length < 2)
                            return;
                        currentRaw = parseInt(tokens[tokens.length - 2]);
                        maxRaw = parseInt(tokens[tokens.length - 1]);
                    }
                    if (isNaN(currentRaw) || isNaN(maxRaw) || maxRaw <= 0)
                        return;
                    monitor.rawMaxBrightness = maxRaw;
                    const newVal = currentRaw / maxRaw;

                    if (monitor.readContext === "refresh") {
                        // Echo-skip: ignore hardware reads that match a
                        // user write in flight (e.g. user just dropped a
                        // slider to 0.45 and the debouncer hasn't fired
                        // yet — hardware still reports 0.55 from the
                        // previous value).
                        const since = Date.now() - monitor.lastUserWriteAt;
                        const drift = Math.abs(newVal - monitor.lastUserWriteValue);
                        if (since < 1500 && drift < 0.05) {
                            monitor.silentRefreshInFlight = false;
                            return;
                        }
                        monitor.brightness = newVal;
                        monitor.silentRefreshInFlight = false;
                        root.brightnessChanged(monitor.brightness, monitor.screen);
                        return;
                    }

                    monitor.brightness = newVal;
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
            monitor.lastUserWriteAt = Date.now();
            monitor.lastUserWriteValue = monitor.brightness;
            const rounded = Math.round(monitor.brightness * monitor.rawMaxBrightness);
            setProc.command = isDdc ? ["ddcutil", "-b", busNum, "setvcp", "10", rounded] : ["brightnessctl", "--class", "backlight", "s", rounded, "--quiet"];
            setProc.startDetached();
        }

        function setBrightness(value: real): void {
            value = Math.max(0.01, Math.min(1, value));
            monitor.brightness = value;
            monitor.lastUserWriteAt = Date.now();
            monitor.lastUserWriteValue = value;
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

        // pull re-reads each monitor's actual brightness without flipping
        // `ready` so an active slider drag or held brightness key isn't
        // interrupted. Used after `ambxst brightness -r` so the OSD picks
        // up the restored values.
        function pull(monitorName: string) {
            if (monitorName && monitorName !== "") {
                const mon = root.monitors.find(m => m.screen.name === monitorName);
                if (mon) {
                    mon.silentRefresh();
                } else {
                    console.warn("Monitor not found for pull:", monitorName);
                }
                return;
            }
            for (let i = 0; i < root.monitors.length; ++i) {
                const mon = root.monitors[i];
                if (mon) mon.silentRefresh();
            }
        }
    }
}
