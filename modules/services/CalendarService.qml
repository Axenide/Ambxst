pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.modules.globals
import qs.modules.theme
pragma ComponentBehavior: Bound

// Calendar integration service — Python process, stdin/stdout JSON protocol.
Singleton {
    id: root

    // Accounts and calendars
    property var accounts: []
    property var calendars: []

    // Events
    property var events: []

    // Status
    property bool syncing: false
    property bool hasAccounts: accounts.length > 0
    property bool gcalcliFound: false
    property string authError: ""

    // Config shortcuts
    readonly property bool enabled: Config.calendar && Config.calendar.enabled !== false
    readonly property int syncInterval: Config.calendar ? (Config.calendar.syncInterval || 15) : 15
    readonly property bool notificationsEnabled: Config.calendar ? Config.calendar.notifications !== false : true
    readonly property bool barIndicatorEnabled: Config.calendar ? Config.calendar.barIndicator !== false : true
    readonly property bool barShowNextEvent: Config.calendar ? (Config.calendar.barShowNextEvent === true) : false
    readonly property bool barAlwaysShow: Config.calendar ? (Config.calendar.barAlwaysShow === true) : false
    readonly property int defaultReminder: Config.calendar ? (Config.calendar.defaultReminder || 15) : 15
    readonly property bool soundOnArrival: Config.calendar ? Config.calendar.soundOnArrival !== false : true
    readonly property string arrivalSoundPath: Config.calendar ? (Config.calendar.arrivalSoundPath || "") : ""
    readonly property bool blinkOnArrival: Config.calendar ? Config.calendar.blinkOnArrival !== false : true

    // Arrival state — set when an event fires the "starting now" notification
    property var arrivingEvent: null
    property bool iconBlinking: false

    // CRUD operation state
    property bool operationPending: false
    property string _lastProviderError: ""
    signal operationResult(bool success, string message)

    // Main calendar process
    property Process calendarProcess: Process {
        id: calendarProcess
        stdinEnabled: true

        command: [
            "python3",
            Quickshell.shellDir + "/scripts/calendar_service.py",
            root.syncInterval.toString(),
            root.defaultReminder.toString(),
            root.soundOnArrival ? "1" : "0",
            root.arrivalSoundPath,
            root.blinkOnArrival ? "1" : "0"
        ]

        stdout: SplitParser {
            onRead: data => {
                try {
                    const msg = JSON.parse(data);
                    root.handleMessage(msg);
                } catch (e) {
                    console.warn("CalendarService: Failed to parse: " + e);
                }
            }
        }
    }

    // Send command to Python process
    function sendCommand(cmd) {
        if (!calendarProcess.running) return;
        calendarProcess.write(JSON.stringify(cmd) + "\n");
    }

    // ── Public API ──

    function sync() {
        sendCommand({"cmd": "sync"});
    }

    function createEvent(event) {
        sendCommand({"cmd": "create", "event": event});
    }

    function updateEvent(event) {
        sendCommand({"cmd": "update", "event": event});
    }

    function deleteEvent(calendarId, eventId) {
        sendCommand({"cmd": "delete", "calendarId": calendarId, "eventId": eventId});
    }

    function authGoogle() {
        const clientId = Config.calendar ? (Config.calendar.googleClientId || "") : "";
        const clientSecret = Config.calendar ? (Config.calendar.googleClientSecret || "") : "";
        sendCommand({"cmd": "auth_google", "client_id": clientId, "client_secret": clientSecret});
    }

    function authCalDAV(url, user, pass_, name) {
        sendCommand({"cmd": "auth_caldav", "url": url, "user": user, "pass": pass_, "name": name || ""});
    }

    function removeAccount(accountId) {
        sendCommand({"cmd": "remove_account", "accountId": accountId});
    }

    function importGcalcli() {
        sendCommand({"cmd": "import_gcalcli"});
    }

    function setCalendarEnabled(calendarId, enabled) {
        sendCommand({"cmd": "set_calendar_enabled", "calendarId": calendarId, "enabled": enabled});
    }

    function setSyncInterval(interval) {
        sendCommand({"cmd": "set_sync_interval", "interval": interval});
    }

    // ── Query helpers ──

    function eventsForDate(year, month, day) {
        const dateStr = year + "-" +
            String(month).padStart(2, "0") + "-" +
            String(day).padStart(2, "0");
        let result = [];
        for (let i = 0; i < events.length; i++) {
            const ev = events[i];
            const start = ev.start || "";
            if (start.startsWith(dateStr)) {
                result.push(ev);
            } else if (ev.allDay && start.substring(0, 10) <= dateStr && (ev.end || "").substring(0, 10) > dateStr) {
                result.push(ev);
            }
        }
        return result;
    }

    function hasEventsOnDate(year, month, day) {
        return eventsForDate(year, month, day).length > 0;
    }

    function nextUpcomingEvent() {
        const now = new Date();
        let closest = null;
        let closestTime = Infinity;
        for (let i = 0; i < events.length; i++) {
            const ev = events[i];
            if (ev.allDay) continue;
            try {
                const start = new Date(ev.start);
                const end = ev.end ? new Date(ev.end) : start;
                // Include in-progress events (start <= now < end) — rank them by start time
                const inProgress = start <= now && now < end;
                const diff = inProgress ? 0 : (start.getTime() - now.getTime());
                if ((inProgress || diff > 0) && diff < closestTime) {
                    closestTime = diff;
                    closest = ev;
                }
            } catch (e) { /* unparseable date, skip */ }
        }
        return closest;
    }

    function todayEvents() {
        const now = new Date();
        const all = eventsForDate(now.getFullYear(), now.getMonth() + 1, now.getDate());
        const upcoming = [];
        const past = [];
        for (let i = 0; i < all.length; i++) {
            const ev = all[i];
            if (ev.allDay) { upcoming.push(ev); continue; }
            try {
                const end = new Date(ev.end || ev.start);
                if (end >= now) upcoming.push(ev);
                else past.push(ev);
            } catch (e) { upcoming.push(ev); }
        }
        upcoming.sort((a, b) => new Date(a.start) - new Date(b.start));
        past.sort((a, b) => new Date(b.start) - new Date(a.start));
        return upcoming.concat(past);
    }

    function calendarColor(calendarId) {
        for (let i = 0; i < calendars.length; i++) {
            if (calendars[i].id === calendarId)
                return calendars[i].color || Colors.primary;
        }
        return Colors.primary;
    }

    function calendarName(calendarId) {
        for (let i = 0; i < calendars.length; i++) {
            if (calendars[i].id === calendarId)
                return calendars[i].name || "Calendar";
        }
        return "Calendar";
    }

    function calendarProvider(calendarId) {
        for (let i = 0; i < calendars.length; i++) {
            if (calendars[i].id === calendarId) {
                const accountId = calendars[i].accountId;
                for (let j = 0; j < accounts.length; j++) {
                    if (accounts[j].id === accountId)
                        return accounts[j].provider || "";
                }
            }
        }
        return "";
    }

    function accountName(accountId) {
        for (let i = 0; i < accounts.length; i++) {
            if (accounts[i].id === accountId)
                return accounts[i].email || accounts[i].name || accountId;
        }
        return accountId;
    }

    // ── Message handler ──

    function handleMessage(msg) {
        switch (msg.type) {
        case "static":
            root.accounts = msg.accounts || [];
            root.calendars = msg.calendars || [];
            break;
        case "events":
            root.events = msg.data || [];
            break;
        case "sync_status":
            root.syncing = msg.syncing || false;
            break;
        case "gcalcli_status":
            root.gcalcliFound = msg.found || false;
            break;
        case "auth_complete":
            root.authError = "";
            break;
        case "auth_error":
            root.authError = msg.message || "Unknown error";
            console.warn("CalendarService auth error: " + msg.message);
            break;
        case "notify":
            // Sound played by Python process — no duplicate here.
            break;
        case "notify_arrive":
            root.arrivingEvent = msg.event || null;
            if (root.blinkOnArrival) {
                root.iconBlinking = true;
                blinkStopTimer.restart();
            }
            // Sound played by Python process — no duplicate here.
            break;
        case "cmd_start":
            root.operationPending = true;
            root._lastProviderError = "";
            break;
        case "cmd_result": {
            root.operationPending = false;
            const errMsg = msg.success ? "" : (msg.message || root._lastProviderError || "Operation failed");
            root._lastProviderError = "";
            root.operationResult(msg.success === true, errMsg);
            break;
        }
        case "error":
            // Store for the next cmd_result so the real error surfaces in the UI
            root._lastProviderError = msg.message || "";
            console.warn("CalendarService error: " + msg.message);
            break;
        }
    }

    Component.onCompleted: {
        if (root.enabled && Config.initialLoadComplete)
            calendarProcess.running = true;
    }

    onEnabledChanged: {
        if (enabled && Config.initialLoadComplete) calendarProcess.running = true;
        else calendarProcess.running = false;
    }

    onSyncIntervalChanged:     if (calendarProcess.running) restartProcess()
    onSoundOnArrivalChanged:   if (calendarProcess.running) restartProcess()
    onArrivalSoundPathChanged: if (calendarProcess.running) restartProcess()
    onBlinkOnArrivalChanged:   if (calendarProcess.running) restartProcess()

    Connections {
        target: Config
        function onInitialLoadCompleteChanged() {
            if (Config.initialLoadComplete && root.enabled)
                calendarProcess.running = true;
        }
    }

    function restartProcess() {
        calendarProcess.running = false;
        Qt.callLater(() => { calendarProcess.running = true; });
    }

    // Stop blinking after 30 seconds (or user can dismiss by clicking the bar icon)
    Timer {
        id: blinkStopTimer
        interval: 30000
        repeat: false
        onTriggered: root.iconBlinking = false
    }

    function dismissArrival() {
        root.iconBlinking = false;
        root.arrivingEvent = null;
        blinkStopTimer.stop();
    }


}
