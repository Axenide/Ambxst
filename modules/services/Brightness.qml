pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import qs.modules.services
import QtQuick

/**
 * For managing brightness of monitors. Supports both brightnessctl and
 * ddcutil.
 *
 * All real work — detection, reads, writes, save/restore — runs in
 * axctl (see Axenide/axctl pkg/server/brightness.go). This singleton
 * keeps per-screen state and shells out to `axctl brightness …` via
 * Quickshell.Io.Process.
 */
Singleton {
    id: root

    signal brightnessChanged(real value, var screen)
    signal osdShouldShow(var screen)

    property var ddcMonitors: []
    readonly property list<BrightnessMonitor> monitors: Quickshell.screens.map(screen => monitorComp.createObject(root, {
            screen
        }))

    property bool syncBrightness: StateService.get("syncBrightness", false)

    onSyncBrightnessChanged: {
        if (StateService.initialized) {
            StateService.set("syncBrightness", syncBrightness);
        }
    }

    property bool _restored: false
    Connections {
        target: StateService
        function onInitializedChanged() {
            root._restore();
        }
    }
    Component.onCompleted: root._restore()

    function _restore() {
        if (StateService.initialized && !root._restored) {
            root._restored = true;
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
        const focusedMonitor = AxctlService.focusedMonitor;
        if (!focusedMonitor || !focusedMonitor.name)
            return;
        const monitor = monitors.find(m => focusedMonitor.name === m.screen.name);
        if (monitor && monitor.ready)
            monitor.setBrightness(monitor.brightness + 0.05, false);
    }

    function decreaseBrightness(): void {
        const focusedMonitor = AxctlService.focusedMonitor;
        if (!focusedMonitor || !focusedMonitor.name)
            return;
        const monitor = monitors.find(m => focusedMonitor.name === m.screen.name);
        if (monitor && monitor.ready)
            monitor.setBrightness(monitor.brightness - 0.05, false);
    }

    reloadableId: "brightness"

    onMonitorsChanged: {
        ddcMonitors = [];
        ddcDetectTimer.restart();
    }

    Timer {
        id: ddcDetectTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (!SuspendManager.isSuspending) {
                listProc.running = true;
            }
        }
    }

    Timer {
        id: refreshTimer
        interval: 5000
        running: false
        repeat: true
        onTriggered: {
            if (monitors.length > 0 && !SuspendManager.isSuspending) {
                listProc.running = true;
            }
        }
    }

    Timer {
        id: bootTimer
        interval: 2000
        running: true
        repeat: false
        onTriggered: {
            for (let i = 0; i < root.monitors.length; ++i) {
                const m = root.monitors[i];
                if (m)
                    m.initialize();
            }
            refreshTimer.running = true;
        }
    }

    // Subscribe to `Event.BrightnessChanged` so the OSD and sliders
    // react to brightness changes from anywhere — keybinds, idle hooks,
    // external `axctl brightness …` calls — not only from this QML.
    // axctl emits the event with `{monitor, value}`; we route each one
    // into the matching BrightnessMonitor and let the existing signal
    // machinery update the OSD.
    readonly property string axctlSocketPath: {
        const env = Quickshell.env("AXCTL_SOCKET");
        return (env && env.length > 0) ? env : "/tmp/axctl-1000.sock";
    }

    Socket {
        id: axctlSub

        path: root.axctlSocketPath
        connected: false

        parser: SplitParser {
            onRead: data => {
                if (!data)
                    return;
                let msg;
                try {
                    msg = JSON.parse(data);
                } catch (e) {
                    return;
                }
                if (msg.method !== "Event.BrightnessChanged" || !msg.params)
                    return;
                const name = msg.params.monitor;
                const value = msg.params.value;
                if (typeof name !== "string" || typeof value !== "number")
                    return;

                if (name === "") {
                    for (let i = 0; i < root.monitors.length; ++i) {
                        const m = root.monitors[i];
                        if (m && m.ready)
                            m.applyReportedBrightness(value, true);
                    }
                    return;
                }

                for (let i = 0; i < root.monitors.length; ++i) {
                    const m = root.monitors[i];
                    if (m && m.ready && m.monitorName() === name) {
                        m.applyReportedBrightness(value, false);
                        break;
                    }
                }
            }
        }

        onConnectionStateChanged: {
            if (axctlSub.connected) {
                axctlSub.write(JSON.stringify({
                    id: 1,
                    method: "System.Subscribe",
                    params: {}
                }) + "\n");
                axctlSub.flush();
            }
        }

        onError: error => {
            console.warn("Brightness: axctl subscription error:", error);
            axctlSub.connected = false;
            axctlSubProbe.restart();
        }
    }

    Timer {
        id: axctlSubProbe
        interval: 5000
        running: true
        repeat: true
        onTriggered: {
            if (!axctlSub.connected) {
                axctlSub.connected = true;
            }
        }
    }

    // Refreshes the per-screen DDC bus cache from `axctl brightness
    // list` and pushes each reported value into its BrightnessMonitor.
    Process {
        id: listProc

        command: ["axctl", "brightness", "list"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                if (!data || !data.trim())
                    return;
                let parsed;
                try {
                    parsed = JSON.parse(data);
                } catch (e) {
                    return;
                }
                if (!Array.isArray(parsed))
                    return;
                const ddc = [];
                for (let i = 0; i < parsed.length; ++i) {
                    const entry = parsed[i];
                    if (entry.kind === "ddcutil") {
                        ddc.push({
                            busNum: entry.bus || ""
                        });
                    }
                }
                root.ddcMonitors = ddc;
                root.ddcMonitorsChanged();
                for (let j = 0; j < root.monitors.length; ++j) {
                    const mon = root.monitors[j];
                    if (mon && mon.ready) {
                        const name = mon.isDdc ? ("ddc-" + mon.busNum) : "backlight";
                        const entry = parsed.find(e => (e.key && e.key === name) || e.name === name);
                        if (entry && entry.brightness !== undefined) {
                            mon.applyReportedBrightness(entry.brightness, false);
                        }
                    }
                }
            }
        }
    }

    // Reusable factory for one-shot writes (debounced per monitor so we
    // don't spawn a process per slider tick).
    Component {
        id: writeProcFactory

        Process {
            property string monitorName: ""
            property real targetValue: 0
            command: ["axctl", "brightness", "set", monitorName, String(targetValue)]
            onExited: exitCode => {
                if (exitCode !== 0)
                    console.warn("axctl brightness set failed", exitCode, monitorName, targetValue);
            }
        }
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

            for (let i = 0; i < root.ddcMonitors.length; ++i) {
                const entry = root.ddcMonitors[i];
                if (entry && entry.busNum && !usedBuses.includes(entry.busNum))
                    return entry;
            }

            return null;
        }
        readonly property bool isDdc: !useBrightnessctl && !!ddcEntry
        readonly property string busNum: isDdc ? ddcEntry.busNum : ""
        property real brightness: 0
        property bool ready: false

        // Track our own writes so subscription echoes don't bounce the
        // value back. DDC quantization can make read-back differ from
        // what we sent, so we use a 2 % tolerance within a 1500 ms
        // settle window — anything outside either is an external change.
        property real lastWrittenValue: 0
        property int lastWrittenAt: 0

        // Two-flag system (DMS pattern) — separates user-driven writes
        // from external/keybind-driven changes. userControlledAt drops
        // echoes during the drag window; pendingOsd flags the next echo
        // to trigger the OSD.
        property int userControlledAt: 0
        property bool pendingOsd: false

        function isUserControlled(): bool {
            return Date.now() - monitor.userControlledAt < 1000;
        }
        function markUserControlled(): void {
            monitor.userControlledAt = Date.now();
        }
        function markPendingOsd(): void {
            monitor.pendingOsd = true;
        }

        onBrightnessChanged: {
            if (monitor.ready) {
                root.brightnessChanged(monitor.brightness, monitor.screen);
                if (monitor.pendingOsd) {
                    monitor.pendingOsd = false;
                    root.osdShouldShow(monitor.screen);
                }
            }
        }

        function monitorName(): string {
            return monitor.isDdc ? ("ddc-" + monitor.busNum) : "backlight";
        }

        function initialize() {
            monitor.ready = false;
            if (!useBrightnessctl && !isDdc)
                return;
            if (isDdc && !busNum)
                return;
            monitor.ready = true;
            root.brightnessChanged(monitor.brightness, monitor.screen);
        }

        function applyReportedBrightness(value, broadcast: bool) {
            if (value === undefined)
                return;
            if (monitor.isUserControlled() && !broadcast)
                return;
            if (!broadcast
                && Date.now() - monitor.lastWrittenAt < 1500
                && Math.abs(value - monitor.lastWrittenValue) < 0.02)
                return;
            if (Math.abs(value - monitor.brightness) < 0.001)
                return;
            monitor.brightness = value;
        }

        property var setTimer: Timer {
            id: setTimer
            interval: monitor.isDdc ? 100 : 0
            onTriggered: {
                monitor.syncBrightness();
            }
        }

        function syncBrightness() {
            if (monitor.isDdc && !monitor.busNum)
                return;
            monitor.lastWrittenAt = Date.now();
            monitor.lastWrittenValue = monitor.brightness;
            const proc = writeProcFactory.createObject(monitor, {
                monitorName: monitor.monitorName(),
                targetValue: monitor.brightness
            });
            proc.running = true;
        }

        function setBrightness(value: real, suppressOsd: bool): void {
            value = Math.max(0.01, Math.min(1, value));
            monitor.brightness = value;
            if (suppressOsd)
                monitor.markUserControlled();
            else
                monitor.markPendingOsd();
            setTimer.restart();
        }

        onBusNumChanged: {
            initialize();
        }
    }

    Component {
        id: monitorComp

        BrightnessMonitor {}
    }
}
