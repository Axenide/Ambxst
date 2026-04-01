pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

Item {
    id: root

    // i18n helper — works with or without the I18n singleton
    function _t(key, fallback) {
        let str;
        try { str = I18n.t(key); } catch(e) { str = fallback; }
        for (let i = 2; i < arguments.length; i++)
            str = str.replace("%" + (i - 1), arguments[i]);
        return str;
    }

    property int day: 0
    property int month: 0
    property int year: 0
    property var dayEvents: []

    property bool editing: false
    property bool creating: false
    property var editingEvent: null

    signal closed()

    onDayChanged: refreshEvents()
    onMonthChanged: refreshEvents()
    onYearChanged: refreshEvents()

    function refreshEvents() {
        dayEvents = CalendarService.eventsForDate(year, month, day);
    }

    Connections {
        target: CalendarService
        function onEventsChanged() { root.refreshEvents(); }
    }

    readonly property var enabledCalendars: {
        let result = [];
        for (let i = 0; i < CalendarService.calendars.length; i++) {
            if (CalendarService.calendars[i].enabled !== false)
                result.push(CalendarService.calendars[i]);
        }
        return result;
    }

    function startCreate() {
        const dateStr = year + "-" +
            String(month).padStart(2, "0") + "-" +
            String(day).padStart(2, "0");
        editingEvent = {
            calendarId: enabledCalendars.length > 0 ? enabledCalendars[0].id : "",
            title: "",
            description: "",
            start: dateStr + "T09:00:00",
            end: dateStr + "T10:00:00",
            allDay: false,
            reminder: CalendarService.defaultReminder,
        };
        creating = true;
        editing = true;
    }

    function startEdit(event) {
        editingEvent = JSON.parse(JSON.stringify(event));
        creating = false;
        editing = true;
    }

    property string saveError: ""
    property bool saving: false

    function saveEvent() {
        if (!editingEvent) return;
        if (!editingEvent.title || editingEvent.title.trim() === "") {
            root.saveError = root._t("calendar.form.error_title_required", "Title is required");
            return;
        }
        if (!editingEvent.start || !editingEvent.end) {
            root.saveError = root._t("calendar.form.error_time_required", "Start and end time are required");
            return;
        }
        if (!editingEvent.allDay && editingEvent.end <= editingEvent.start) {
            root.saveError = root._t("calendar.form.error_end_after_start", "End time must be after start");
            return;
        }
        root.saveError = "";
        root.saving = true;
        saveTimeout.restart();
        if (creating) {
            CalendarService.createEvent(editingEvent);
        } else {
            CalendarService.updateEvent(editingEvent);
        }
    }

    function deleteEvent() {
        if (!editingEvent || !editingEvent.id) return;
        root.saving = true;
        saveTimeout.restart();
        CalendarService.deleteEvent(editingEvent.calendarId, editingEvent.id);
    }

    // Timeout: if Python doesn't respond within 15s, show error
    Timer {
        id: saveTimeout
        interval: 15000
        repeat: false
        onTriggered: {
            root.saving = false;
            root.saveError = root._t("calendar.form.error_timeout", "Request timed out — check your connection");
        }
    }

    Connections {
        target: CalendarService
        function onOperationResult(success, message) {
            if (!root.saving) return;
            saveTimeout.stop();
            root.saving = false;
            if (success) {
                root.saveError = "";
                root.editing = false;
                root.creating = false;
                root.editingEvent = null;
                Qt.callLater(root.refreshEvents);
            } else {
                root.saveError = message || root._t("calendar.form.error_operation_failed", "Operation failed");
            }
        }
    }

    function timeHours(dtStr) {
        if (!dtStr || !dtStr.includes("T")) return 9;
        return parseInt(dtStr.split("T")[1].split(":")[0]) || 0;
    }
    function timeMinutes(dtStr) {
        if (!dtStr || !dtStr.includes("T")) return 0;
        return parseInt(dtStr.split("T")[1].split(":")[1]) || 0;
    }
    function setEventTime(isStart, h, m) {
        if (!root.editingEvent) return;
        const pad = n => String(n).padStart(2, "0");
        const timeStr = pad(h) + ":" + pad(m) + ":00";
        // Extract date portion safely regardless of whether "T" is present
        const datePart = s => (s || "").includes("T") ? s.split("T")[0] : (s || "").substring(0, 10);
        try {
            // Clone the object so QML detects the property change and re-evaluates bindings
            const ev = Object.assign({}, root.editingEvent);
            if (isStart) {
                ev.start = datePart(ev.start) + "T" + timeStr;
                // Auto-set end = start + 30min if end is at or before new start
                const startTotal = h * 60 + m;
                const endTotal = root.timeHours(ev.end) * 60 + root.timeMinutes(ev.end);
                if (endTotal <= startTotal) {
                    const newEndTotal = (startTotal + 30) % (24 * 60);
                    ev.end = datePart(ev.end) + "T" + pad(Math.floor(newEndTotal / 60)) + ":" + pad(newEndTotal % 60) + ":00";
                }
            } else {
                ev.end = datePart(ev.end) + "T" + timeStr;
            }
            root.editingEvent = ev;
        } catch (e) {
            console.warn("setEventTime error:", e);
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Header ──
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            Layout.topMargin: 8
            spacing: 6

            // Back button — cancel edit → list, list → closed
            StyledRect {
                variant: backMouse.containsMouse ? "focus" : "common"
                implicitWidth: 28
                implicitHeight: 28
                radius: Styling.radius(-2)

                Text {
                    anchors.centerIn: parent
                    text: Icons.arrowLeft
                    font.family: Icons.font
                    font.pixelSize: 14
                    color: Colors.overBackground
                }

                MouseArea {
                    id: backMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.editing) {
                            root.editing = false;
                            root.creating = false;
                            root.editingEvent = null;
                        } else {
                            root.closed();
                        }
                    }
                }
            }

            // Date info column
            ColumnLayout {
                spacing: 1

                Text {
                    text: {
                        if (root.day <= 0) return "";
                        const d = new Date(root.year, root.month - 1, root.day);
                        return d.toLocaleDateString(Qt.locale(), "d MMMM yyyy");
                    }
                    font.family: Config.defaultFont
                    font.pixelSize: Styling.fontSize(0)
                    font.weight: Font.DemiBold
                    color: Colors.overBackground
                    elide: Text.ElideRight
                }

                Text {
                    text: {
                        if (root.day <= 0) return "";
                        const d = new Date(root.year, root.month - 1, root.day);
                        const dayName = d.toLocaleDateString(Qt.locale(), "dddd");
                        const count = root.dayEvents.length;
                        return dayName + " · " + count + " " + root._t(count === 1 ? "calendar.form.event_singular" : "calendar.form.events_plural", count === 1 ? "event" : "events");
                    }
                    font.family: Config.defaultFont
                    font.pixelSize: Styling.fontSize(-3)
                    color: Colors.outline
                    elide: Text.ElideRight
                }
            }

            Item { Layout.fillWidth: true }

            // Close button — always visible, always exits to calendar
            StyledRect {
                variant: closeMouse.containsMouse ? "focus" : "transparent"
                implicitWidth: 28
                implicitHeight: 28
                radius: Styling.radius(-2)

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    font.pixelSize: 13
                    color: Colors.outline
                }

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.editing = false;
                        root.creating = false;
                        root.editingEvent = null;
                        root.closed();
                    }
                }
            }

            // Add button (list mode)
            StyledRect {
                visible: !root.editing && root.enabledCalendars.length > 0
                variant: addMouse.containsMouse ? "primaryfocus" : "primary"
                implicitWidth: addText.implicitWidth + 16
                implicitHeight: 28
                radius: Styling.radius(-2)

                Text {
                    id: addText
                    anchors.centerIn: parent
                    text: root._t("calendar.form.add_event", "+ Add")
                    font.family: Config.defaultFont
                    font.pixelSize: Styling.fontSize(-2)
                    font.weight: Font.DemiBold
                    color: Colors.primary.hslLightness > 0.5 ? "black" : "white"
                }

                MouseArea {
                    id: addMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.startCreate()
                }
            }
        }

        Separator {
            Layout.fillWidth: true
            vert: false
        }

        // ── Scrollable content ──
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: contentCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: contentCol
                width: parent.width
                spacing: 4

                // ── List mode ──
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.margins: 8
                    spacing: 4
                    visible: !root.editing

                    Repeater {
                        model: root.dayEvents

                        EventItem {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            event: modelData
                            onEditRequested: root.startEdit(modelData)
                        }
                    }

                    Text {
                        visible: root.dayEvents.length === 0
                        Layout.fillWidth: true
                        Layout.topMargin: 8
                        Layout.bottomMargin: 8
                        text: CalendarService.hasAccounts ? root._t("calendar.form.no_events", "No events") : root._t("calendar.form.no_calendar", "No calendar connected")
                        font.family: Config.defaultFont
                        font.pixelSize: Styling.fontSize(-2)
                        color: Colors.outline
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                // ── Edit/Create form ──
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.margins: 12
                    spacing: 10
                    visible: root.editing && root.editingEvent !== null

                    // Title
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: root._t("calendar.form.label_title", "Title")
                            font.family: Config.defaultFont
                            font.pixelSize: Styling.fontSize(-3)
                            color: Colors.outline
                        }

                        TextField {
                            id: titleField
                            Layout.fillWidth: true
                            implicitHeight: 36
                            leftPadding: 8; rightPadding: 8
                            topPadding: 0; bottomPadding: 0
                            verticalAlignment: TextInput.AlignVCenter
                            text: root.editingEvent ? root.editingEvent.title : ""
                            placeholderText: root._t("calendar.form.placeholder_title", "Event title")
                            placeholderTextColor: Colors.outline
                            font.family: Config.defaultFont
                            font.pixelSize: Styling.fontSize(-1)
                            color: Colors.overBackground
                            selectByMouse: true
                            background: Item {
                                StyledRect {
                                    anchors.fill: parent
                                    variant: "common"
                                    radius: Styling.radius(-2)
                                    enableBorder: false
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: titleField.activeFocus ? Colors.primary : Colors.outlineVariant
                                    border.width: 1
                                    radius: Styling.radius(-2)
                                }
                            }
                            onTextChanged: if (root.editingEvent) root.editingEvent.title = text
                        }
                    }

                    // Start / End time
                    // SpinnerField: up/down arrows + direct text input + mouse wheel.
                    //
                    // Design notes:
                    //   • No IntValidator — it blocks keystrokes when typing mid-value (e.g. "09"→"091")
                    //     instead we use a digits-only regex and clamp in JS on commit.
                    //   • selectAll() on focus-gain so any keystroke immediately replaces the whole value.
                    //   • Qt.callLater for text reset so it runs after QML binding re-evaluation.
                    //   • _busy guard prevents double-fire from onEditingFinished + onActiveFocusChanged.
                    //   • External value changes (arrows, wheel, other field) sync via onSpinValueChanged
                    //     only when the TextInput is not focused.
                    component SpinnerField: ColumnLayout {
                        id: spinnerField

                        // Driven by a parent binding; never written from inside the component.
                        required property int spinValue
                        required property int spinMax   // 23 for hours, 59 for minutes

                        signal commit(int newValue)

                        spacing: 0

                        // ── helpers ────────────────────────────────────────────────────
                        function _wrap(v) {
                            const size = spinnerField.spinMax + 1;
                            return ((v % size) + size) % size;
                        }
                        function _formatted(v) {
                            return String(v).padStart(2, "0");
                        }

                        // ── up arrow ───────────────────────────────────────────────────
                        StyledRect {
                            implicitWidth: 28; implicitHeight: 16; radius: Styling.radius(-4)
                            variant: spinUpMouse.containsMouse ? "focus" : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: Icons.caretUp; font.family: Icons.font
                                font.pixelSize: 9; color: Colors.outline
                            }
                            MouseArea {
                                id: spinUpMouse
                                anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                preventStealing: true
                                onClicked: spinnerField.commit(spinnerField._wrap(spinnerField.spinValue + 1))
                            }
                        }

                        // ── editable value ─────────────────────────────────────────────
                        TextInput {
                            id: spinInput
                            Layout.alignment: Qt.AlignHCenter
                            width: 26
                            horizontalAlignment: TextInput.AlignHCenter
                            font.family: Config.defaultFont
                            font.pixelSize: Styling.fontSize(0)
                            font.weight: Font.Medium
                            color: Colors.overBackground
                            selectByMouse: true
                            maximumLength: 2
                            // Digits only — allows any 1-2 digit intermediate value without blocking
                            validator: RegularExpressionValidator { regularExpression: /^\d{0,2}$/ }

                            // Guard: prevents onEditingFinished + onActiveFocusChanged double-fire
                            property bool _busy: false

                            // ── sync external → display ───────────────────────────────
                            Component.onCompleted: {
                                spinInput.text = spinnerField._formatted(spinnerField.spinValue);
                            }
                            // Reactive binding to spinValue — fires whenever spinValue changes
                            // (arrow click, wheel, or the parent's editingEvent binding re-evaluates).
                            // Only update text while the user is NOT editing.
                            readonly property int externalValue: spinnerField.spinValue
                            onExternalValueChanged: {
                                if (!spinInput.activeFocus)
                                    spinInput.text = spinnerField._formatted(spinnerField.spinValue);
                            }

                            // ── commit typed value ────────────────────────────────────
                            function applyTyped() {
                                if (spinInput._busy) return;
                                spinInput._busy = true;

                                const digits = spinInput.text.replace(/\D/g, "");
                                const v = digits.length > 0 ? parseInt(digits, 10) : NaN;

                                if (!isNaN(v) && v >= 0 && v <= spinnerField.spinMax) {
                                    spinnerField.commit(v);
                                }

                                // Defer text normalisation so QML binding on spinValue
                                // has time to re-evaluate after commit → setEventTime.
                                Qt.callLater(function() {
                                    spinInput.text = spinnerField._formatted(spinnerField.spinValue);
                                    spinInput._busy = false;
                                });
                            }

                            // ── focus events ──────────────────────────────────────────
                            onActiveFocusChanged: {
                                if (activeFocus) {
                                    // Select all so the first keystroke replaces the value outright
                                    spinInput.selectAll();
                                } else {
                                    applyTyped();
                                }
                            }
                            // Enter / Return key — onEditingFinished fires here too
                            onEditingFinished: applyTyped()

                            // ── mouse wheel ───────────────────────────────────────────
                            WheelHandler {
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                onWheel: event => {
                                    const delta = event.angleDelta.y > 0 ? 1 : -1;
                                    spinnerField.commit(spinnerField._wrap(spinnerField.spinValue + delta));
                                }
                            }
                        }

                        // ── down arrow ─────────────────────────────────────────────────
                        StyledRect {
                            implicitWidth: 28; implicitHeight: 16; radius: Styling.radius(-4)
                            variant: spinDnMouse.containsMouse ? "focus" : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: Icons.caretDown; font.family: Icons.font
                                font.pixelSize: 9; color: Colors.outline
                            }
                            MouseArea {
                                id: spinDnMouse
                                anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                preventStealing: true
                                onClicked: spinnerField.commit(spinnerField._wrap(spinnerField.spinValue - 1))
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        // Start time picker
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: root._t("calendar.form.label_start", "Start")
                                font.family: Config.defaultFont
                                font.pixelSize: Styling.fontSize(-3)
                                color: Colors.outline
                            }

                            StyledRect {
                                Layout.fillWidth: true
                                implicitHeight: 64
                                variant: "common"
                                radius: Styling.radius(-2)

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 4

                                    SpinnerField {
                                        spinValue: root.editingEvent ? root.timeHours(root.editingEvent.start) : 9
                                        spinMax: 23
                                        onCommit: v => root.setEventTime(true, v, root.timeMinutes(root.editingEvent?.start))
                                    }

                                    Text { text: ":"; font.family: Config.defaultFont; font.pixelSize: Styling.fontSize(0); color: Colors.outline; bottomPadding: 2 }

                                    SpinnerField {
                                        spinValue: root.editingEvent ? root.timeMinutes(root.editingEvent.start) : 0
                                        spinMax: 59
                                        onCommit: v => root.setEventTime(true, root.timeHours(root.editingEvent?.start), v)
                                    }
                                }
                            }
                        }

                        // End time picker
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: root._t("calendar.form.label_end", "End")
                                font.family: Config.defaultFont
                                font.pixelSize: Styling.fontSize(-3)
                                color: Colors.outline
                            }

                            StyledRect {
                                Layout.fillWidth: true
                                implicitHeight: 64
                                variant: "common"
                                radius: Styling.radius(-2)

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 4

                                    SpinnerField {
                                        spinValue: root.editingEvent ? root.timeHours(root.editingEvent.end) : 10
                                        spinMax: 23
                                        onCommit: v => root.setEventTime(false, v, root.timeMinutes(root.editingEvent?.end))
                                    }

                                    Text { text: ":"; font.family: Config.defaultFont; font.pixelSize: Styling.fontSize(0); color: Colors.outline; bottomPadding: 2 }

                                    SpinnerField {
                                        spinValue: root.editingEvent ? root.timeMinutes(root.editingEvent.end) : 0
                                        spinMax: 59
                                        onCommit: v => root.setEventTime(false, root.timeHours(root.editingEvent?.end), v)
                                    }
                                }
                            }
                        }
                    }

                    // Calendar selector
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: root._t("calendar.form.label_calendar", "Calendar")
                            font.family: Config.defaultFont
                            font.pixelSize: Styling.fontSize(-3)
                            color: Colors.outline
                        }

                        ComboBox {
                            id: calSelector
                            Layout.fillWidth: true
                            implicitHeight: 36
                            model: root.enabledCalendars
                            textRole: "name"
                            valueRole: "id"
                            currentIndex: {
                                if (!root.editingEvent) return 0;
                                for (let i = 0; i < root.enabledCalendars.length; i++) {
                                    if (root.enabledCalendars[i].id === root.editingEvent.calendarId)
                                        return i;
                                }
                                return 0;
                            }
                            onCurrentValueChanged: {
                                if (!root.editingEvent || !currentValue) return;
                                const isGoogle = CalendarService.calendarProvider(currentValue) === "google";
                                root.editingEvent = Object.assign({}, root.editingEvent, {
                                    calendarId: currentValue,
                                    meetLink: isGoogle ? (root.editingEvent.meetLink || "") : ""
                                });
                            }
                            background: Rectangle {
                                color: calSelector.hovered ? Colors.surfaceContainerHigh : Colors.surfaceContainer
                                radius: Styling.radius(-2)
                                border.color: Colors.outlineVariant
                                border.width: 1
                            }
                            contentItem: Text {
                                leftPadding: 10
                                rightPadding: 32
                                text: calSelector.displayText
                                font.family: Config.defaultFont
                                font.pixelSize: Styling.fontSize(-1)
                                color: Colors.overBackground
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }
                            indicator: Text {
                                x: calSelector.width - width - 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: Icons.caretDown
                                font.family: Icons.font
                                font.pixelSize: 14
                                color: Colors.overBackground
                            }
                            popup: Popup {
                                y: calSelector.height + 4
                                width: calSelector.width
                                padding: 4
                                background: Rectangle {
                                    color: Colors.surfaceContainerLow
                                    radius: Styling.radius(-1)
                                    border.color: Colors.outlineVariant
                                    border.width: 1
                                }
                                contentItem: ListView {
                                    clip: true
                                    implicitHeight: Math.min(contentHeight, 200)
                                    model: calSelector.popup.visible ? calSelector.delegateModel : null
                                    currentIndex: calSelector.highlightedIndex
                                    ScrollIndicator.vertical: ScrollIndicator {}
                                }
                            }
                            delegate: ItemDelegate {
                                id: calDelegate
                                required property var modelData
                                required property int index
                                width: ListView.view.width
                                height: 32
                                highlighted: calSelector.highlightedIndex === index
                                background: Rectangle {
                                    color: calDelegate.highlighted ? Colors.surfaceContainerHigh : "transparent"
                                    radius: Styling.radius(-2)
                                }
                                contentItem: RowLayout {
                                    spacing: 8
                                    Rectangle {
                                        width: 10; height: 10; radius: 2
                                        color: calDelegate.modelData.color || Colors.primary
                                        Layout.leftMargin: 8
                                    }
                                    Text {
                                        text: calDelegate.modelData.name || ""
                                        font.family: Config.defaultFont
                                        font.pixelSize: Styling.fontSize(-1)
                                        color: Colors.overBackground
                                        verticalAlignment: Text.AlignVCenter
                                        Layout.fillWidth: true
                                    }
                                }
                            }
                        }
                    }

                    // Reminder selector
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: root._t("calendar.form.label_reminder", "Reminder")
                            font.family: Config.defaultFont
                            font.pixelSize: Styling.fontSize(-3)
                            color: Colors.outline
                        }

                        ComboBox {
                            id: reminderSelector
                            Layout.fillWidth: true
                            implicitHeight: 36
                            model: [
                                { text: root._t("calendar.form.reminder_none", "None"), value: 0 },
                                { text: root._t("calendar.form.reminder_minutes", "%1 min", 5), value: 5 },
                                { text: root._t("calendar.form.reminder_minutes", "%1 min", 10), value: 10 },
                                { text: root._t("calendar.form.reminder_minutes", "%1 min", 15), value: 15 },
                                { text: root._t("calendar.form.reminder_minutes", "%1 min", 30), value: 30 },
                                { text: root._t("calendar.form.reminder_1hour", "1 hour"), value: 60 },
                                { text: root._t("calendar.form.reminder_1day", "1 day"), value: 1440 },
                            ]
                            textRole: "text"
                            valueRole: "value"
                            currentIndex: {
                                if (!root.editingEvent) return 3;
                                const r = root.editingEvent.reminder || 0;
                                const vals = [0, 5, 10, 15, 30, 60, 1440];
                                const idx = vals.indexOf(r);
                                return idx >= 0 ? idx : 3;
                            }
                            onCurrentValueChanged: {
                                if (root.editingEvent && currentValue !== undefined)
                                    root.editingEvent.reminder = currentValue;
                            }
                            background: Rectangle {
                                color: reminderSelector.hovered ? Colors.surfaceContainerHigh : Colors.surfaceContainer
                                radius: Styling.radius(-2)
                                border.color: Colors.outlineVariant
                                border.width: 1
                            }
                            contentItem: Text {
                                leftPadding: 10
                                rightPadding: 32
                                text: reminderSelector.displayText
                                font.family: Config.defaultFont
                                font.pixelSize: Styling.fontSize(-1)
                                color: Colors.overBackground
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }
                            indicator: Text {
                                x: reminderSelector.width - width - 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: Icons.caretDown
                                font.family: Icons.font
                                font.pixelSize: 14
                                color: Colors.overBackground
                            }
                            popup: Popup {
                                y: reminderSelector.height + 4
                                width: reminderSelector.width
                                padding: 4
                                background: Rectangle {
                                    color: Colors.surfaceContainerLow
                                    radius: Styling.radius(-1)
                                    border.color: Colors.outlineVariant
                                    border.width: 1
                                }
                                contentItem: ListView {
                                    clip: true
                                    implicitHeight: Math.min(contentHeight, 200)
                                    model: reminderSelector.popup.visible ? reminderSelector.delegateModel : null
                                    currentIndex: reminderSelector.highlightedIndex
                                    ScrollIndicator.vertical: ScrollIndicator {}
                                }
                            }
                            delegate: ItemDelegate {
                                id: reminderDelegate
                                required property var modelData
                                required property int index
                                width: ListView.view.width
                                height: 32
                                highlighted: reminderSelector.highlightedIndex === index
                                background: Rectangle {
                                    color: reminderDelegate.highlighted ? Colors.surfaceContainerHigh : "transparent"
                                    radius: Styling.radius(-2)
                                }
                                contentItem: Text {
                                    leftPadding: 8
                                    text: reminderDelegate.modelData.text || ""
                                    font.family: Config.defaultFont
                                    font.pixelSize: Styling.fontSize(-1)
                                    color: Colors.overBackground
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }
                    }

                    // Description
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: root._t("calendar.form.label_description", "Description")
                            font.family: Config.defaultFont
                            font.pixelSize: Styling.fontSize(-3)
                            color: Colors.outline
                        }

                        TextField {
                            id: descField
                            Layout.fillWidth: true
                            implicitHeight: 36
                            leftPadding: 8; rightPadding: 8
                            topPadding: 0; bottomPadding: 0
                            verticalAlignment: TextInput.AlignVCenter
                            text: root.editingEvent ? (root.editingEvent.description || "") : ""
                            placeholderText: root._t("calendar.form.placeholder_description", "Optional...")
                            placeholderTextColor: Colors.outline
                            font.family: Config.defaultFont
                            font.pixelSize: Styling.fontSize(-1)
                            color: Colors.overBackground
                            selectByMouse: true
                            background: Item {
                                StyledRect {
                                    anchors.fill: parent
                                    variant: "common"
                                    radius: Styling.radius(-2)
                                    enableBorder: false
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: descField.activeFocus ? Colors.primary : Colors.outlineVariant
                                    border.width: 1
                                    radius: Styling.radius(-2)
                                }
                            }
                            onTextChanged: if (root.editingEvent) root.editingEvent.description = text
                        }
                    }

                    // Location / Link
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: root._t("calendar.form.label_location", "Location / Link")
                            font.family: Config.defaultFont
                            font.pixelSize: Styling.fontSize(-3)
                            color: Colors.outline
                        }

                        TextField {
                            id: locationField
                            Layout.fillWidth: true
                            implicitHeight: 36
                            leftPadding: 8; rightPadding: 8
                            topPadding: 0; bottomPadding: 0
                            verticalAlignment: TextInput.AlignVCenter
                            text: root.editingEvent ? (root.editingEvent.location || "") : ""
                            placeholderText: root._t("calendar.form.placeholder_location", "URL or address...")
                            placeholderTextColor: Colors.outline
                            font.family: Config.defaultFont
                            font.pixelSize: Styling.fontSize(-1)
                            color: Colors.overBackground
                            selectByMouse: true
                            background: Item {
                                StyledRect {
                                    anchors.fill: parent
                                    variant: "common"
                                    radius: Styling.radius(-2)
                                    enableBorder: false
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: locationField.activeFocus ? Colors.primary : Colors.outlineVariant
                                    border.width: 1
                                    radius: Styling.radius(-2)
                                }
                            }
                            onTextChanged: if (root.editingEvent) root.editingEvent.location = text
                        }
                    }

                    // Google Meet — only for Google calendars
                    RowLayout {
                        Layout.fillWidth: true
                        visible: root.editingEvent ? CalendarService.calendarProvider(root.editingEvent.calendarId) === "google" : false

                        Text {
                            text: root._t("calendar.form.label_meet", "Google Meet")
                            font.family: Config.defaultFont
                            font.pixelSize: Styling.fontSize(-3)
                            color: Colors.outline
                            Layout.fillWidth: true
                        }

                        StyledRect {
                            id: meetToggle
                            readonly property bool hasMeet: root.editingEvent ? (root.editingEvent.meetLink || "") !== "" : false
                            variant: meetMouse.containsMouse ? (hasMeet ? "focus" : "primaryfocus") : (hasMeet ? "common" : "primary")
                            implicitWidth: meetLabel.implicitWidth + 20
                            implicitHeight: 28
                            radius: Styling.radius(-2)

                            Text {
                                id: meetLabel
                                anchors.centerIn: parent
                                text: meetToggle.hasMeet ? root._t("calendar.form.meet_remove", "Remove Meet") : root._t("calendar.form.meet_add", "+ Add Meet")
                                font.family: Config.defaultFont
                                font.pixelSize: Styling.fontSize(-2)
                                font.weight: Font.Medium
                                color: meetToggle.hasMeet ? Colors.outline : (Colors.primary.hslLightness > 0.5 ? "black" : "white")
                            }

                            MouseArea {
                                id: meetMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                preventStealing: true
                                onClicked: {
                                    if (!root.editingEvent) return;
                                    if (meetToggle.hasMeet) {
                                        root.editingEvent.meetLink = "";
                                    } else {
                                        root.editingEvent.meetLink = "request";
                                    }
                                    // force property re-read
                                    root.editingEvent = Object.assign({}, root.editingEvent);
                                }
                            }
                        }
                    }

                }
            }
        }

        // ── Action footer (outside Flickable to avoid first-click swallowed by flick gesture) ──
        ColumnLayout {
            visible: root.editing
            Layout.fillWidth: true
            Layout.margins: 8
            Layout.topMargin: 4
            spacing: 6

            // Validation error
            Text {
                visible: root.saveError !== ""
                text: root.saveError
                font.family: Config.defaultFont
                font.pixelSize: Styling.fontSize(-3)
                color: "#e06c75"
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }

            // Action buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                StyledRect {
                    Layout.fillWidth: true
                    variant: (!root.saving && saveMouse.containsMouse) ? "primaryfocus" : "primary"
                    implicitHeight: 32
                    radius: Styling.radius(-2)
                    opacity: root.saving ? 0.6 : 1.0

                    Text {
                        anchors.centerIn: parent
                        text: root.saving ? root._t("calendar.form.saving", "Saving…") : root._t("calendar.form.save", "Save")
                        font.family: Config.defaultFont
                        font.pixelSize: Styling.fontSize(-1)
                        font.weight: Font.DemiBold
                        color: Colors.primary.hslLightness > 0.5 ? "black" : "white"
                    }

                    MouseArea {
                        id: saveMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: root.saving ? Qt.ArrowCursor : Qt.PointingHandCursor
                        preventStealing: true
                        onClicked: if (!root.saving) root.saveEvent()
                    }
                }

                StyledRect {
                    visible: !root.creating
                    variant: (!root.saving && deleteMouse.containsMouse) ? "focus" : "common"
                    implicitWidth: 64
                    implicitHeight: 32
                    radius: Styling.radius(-2)
                    opacity: root.saving ? 0.6 : 1.0

                    Text {
                        anchors.centerIn: parent
                        text: root._t("calendar.form.delete", "Delete")
                        font.family: Config.defaultFont
                        font.pixelSize: Styling.fontSize(-1)
                        color: Colors.red
                    }

                    MouseArea {
                        id: deleteMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: root.saving ? Qt.ArrowCursor : Qt.PointingHandCursor
                        preventStealing: true
                        onClicked: if (!root.saving) root.deleteEvent()
                    }
                }
            }
        }
    }
}
