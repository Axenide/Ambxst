pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

Popup {
    id: root

    property int day: 0
    property int month: 0
    property int year: 0
    property var dayEvents: []

    // Edit mode state
    property bool editing: false
    property bool creating: false
    property var editingEvent: null

    width: 320
    height: contentColumn.implicitHeight + 24
    padding: 0
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    onOpened: {
        editing = false;
        creating = false;
        editingEvent = null;
        refreshEvents();
    }

    function refreshEvents() {
        dayEvents = CalendarService.eventsForDate(year, month, day);
    }

    Connections {
        target: CalendarService
        function onEventsChanged() {
            if (root.opened) root.refreshEvents();
        }
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

    function saveEvent() {
        if (!editingEvent) return;
        if (creating) {
            CalendarService.createEvent(editingEvent);
        } else {
            CalendarService.updateEvent(editingEvent);
        }
        editing = false;
        creating = false;
        editingEvent = null;
        Qt.callLater(refreshEvents);
    }

    function deleteEvent() {
        if (!editingEvent || !editingEvent.id) return;
        CalendarService.deleteEvent(editingEvent.calendarId, editingEvent.id);
        editing = false;
        creating = false;
        editingEvent = null;
        Qt.callLater(refreshEvents);
    }

    background: StyledRect {
        variant: "bg"
        radius: Styling.radius(2)
        border.width: 1
        border.color: Colors.surfaceBright
    }

    contentItem: ColumnLayout {
        id: contentColumn
        width: root.width
        spacing: 0

        // ── Header ──
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: headerCol.implicitHeight
            Layout.margins: 12
            Layout.bottomMargin: 8

            // Date info (list mode)
            ColumnLayout {
                id: headerCol
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                visible: !root.editing

                Text {
                    text: {
                        const d = new Date(root.year, root.month - 1, root.day);
                        return d.toLocaleDateString(Qt.locale(), "d MMMM yyyy");
                    }
                    font.family: Config.defaultFont
                    font.pixelSize: Styling.fontSize(1)
                    font.weight: Font.DemiBold
                    color: Colors.overBackground
                }

                Text {
                    text: {
                        const d = new Date(root.year, root.month - 1, root.day);
                        const dayName = d.toLocaleDateString(Qt.locale(), "dddd");
                        const count = root.dayEvents.length;
                        return dayName + " · " + count + (count === 1 ? " event" : " events");
                    }
                    font.family: Config.defaultFont
                    font.pixelSize: Styling.fontSize(-3)
                    color: Colors.outline
                }
            }

            // Title (edit mode)
            Text {
                visible: root.editing
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.creating ? "New Event" : "Edit Event"
                font.family: Config.defaultFont
                font.pixelSize: Styling.fontSize(1)
                font.weight: Font.DemiBold
                color: Colors.overBackground
            }

            // Add button (list mode) — anchored right
            StyledRect {
                visible: !root.editing && root.enabledCalendars.length > 0
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                variant: addMouse.containsMouse ? "primaryfocus" : "primary"
                implicitWidth: addText.implicitWidth + 16
                implicitHeight: 28
                radius: Styling.radius(-2)

                Text {
                    id: addText
                    anchors.centerIn: parent
                    text: "+ Add"
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

            // Close button (edit mode) — anchored right
            StyledRect {
                visible: root.editing
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                variant: closeMouse.containsMouse ? "focus" : "common"
                implicitWidth: 28
                implicitHeight: 28
                radius: Styling.radius(-2)

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    font.pixelSize: 14
                    color: Colors.outline
                }

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { root.editing = false; root.creating = false; }
                }
            }
        }

        Separator {
            Layout.fillWidth: true
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            vert: false
        }

        // ── List mode ──
        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: 8
            spacing: 4
            visible: !root.editing

            // Events list
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

            // Empty state
            Text {
                visible: root.dayEvents.length === 0
                Layout.fillWidth: true
                Layout.topMargin: 8
                Layout.bottomMargin: 8
                text: CalendarService.hasAccounts ? "No events" : "No calendar connected"
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
                    text: "Title"
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
                    placeholderText: "Event title"
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
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: "Start"
                        font.family: Config.defaultFont
                        font.pixelSize: Styling.fontSize(-3)
                        color: Colors.outline
                    }

                    TextField {
                        id: startField
                        Layout.fillWidth: true
                        implicitHeight: 36
                        leftPadding: 8; rightPadding: 8
                        topPadding: 0; bottomPadding: 0
                        verticalAlignment: TextInput.AlignVCenter
                        text: {
                            if (!root.editingEvent) return "";
                            const s = root.editingEvent.start || "";
                            return s.includes("T") ? s.split("T")[1].substring(0, 5) : "";
                        }
                        placeholderText: "HH:MM"
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
                                border.color: startField.activeFocus ? Colors.primary : Colors.outlineVariant
                                border.width: 1
                                radius: Styling.radius(-2)
                            }
                        }
                        onTextChanged: {
                            if (!root.editingEvent) return;
                            const dateStr = root.editingEvent.start.split("T")[0];
                            root.editingEvent.start = dateStr + "T" + text + ":00";
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: "End"
                        font.family: Config.defaultFont
                        font.pixelSize: Styling.fontSize(-3)
                        color: Colors.outline
                    }

                    TextField {
                        id: endField
                        Layout.fillWidth: true
                        implicitHeight: 36
                        leftPadding: 8; rightPadding: 8
                        topPadding: 0; bottomPadding: 0
                        verticalAlignment: TextInput.AlignVCenter
                        text: {
                            if (!root.editingEvent) return "";
                            const e = root.editingEvent.end || "";
                            return e.includes("T") ? e.split("T")[1].substring(0, 5) : "";
                        }
                        placeholderText: "HH:MM"
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
                                border.color: endField.activeFocus ? Colors.primary : Colors.outlineVariant
                                border.width: 1
                                radius: Styling.radius(-2)
                            }
                        }
                        onTextChanged: {
                            if (!root.editingEvent) return;
                            const dateStr = root.editingEvent.end.split("T")[0];
                            root.editingEvent.end = dateStr + "T" + text + ":00";
                        }
                    }
                }
            }

            // Calendar selector
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: "Calendar"
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
                        if (root.editingEvent && currentValue)
                            root.editingEvent.calendarId = currentValue;
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

            // Reminder
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: "Reminder"
                    font.family: Config.defaultFont
                    font.pixelSize: Styling.fontSize(-3)
                    color: Colors.outline
                }

                ComboBox {
                    id: reminderSelector
                    Layout.fillWidth: true
                    implicitHeight: 36
                    model: [
                        { text: "None", value: 0 },
                        { text: "5 min", value: 5 },
                        { text: "10 min", value: 10 },
                        { text: "15 min", value: 15 },
                        { text: "30 min", value: 30 },
                        { text: "1 hour", value: 60 },
                        { text: "1 day", value: 1440 },
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
                    text: "Description"
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
                    placeholderText: "Optional..."
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

            // Action buttons
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 8

                StyledRect {
                    Layout.fillWidth: true
                    variant: saveMouse.containsMouse ? "primaryfocus" : "primary"
                    implicitHeight: 32
                    radius: Styling.radius(-2)

                    Text {
                        anchors.centerIn: parent
                        text: "Save"
                        font.family: Config.defaultFont
                        font.pixelSize: Styling.fontSize(-1)
                        font.weight: Font.DemiBold
                        color: Colors.primary.hslLightness > 0.5 ? "black" : "white"
                    }

                    MouseArea {
                        id: saveMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.saveEvent()
                    }
                }

                StyledRect {
                    visible: !root.creating
                    variant: deleteMouse.containsMouse ? "focus" : "common"
                    implicitWidth: 64
                    implicitHeight: 32
                    radius: Styling.radius(-2)

                    Text {
                        anchors.centerIn: parent
                        text: "Delete"
                        font.family: Config.defaultFont
                        font.pixelSize: Styling.fontSize(-1)
                        color: Colors.red
                    }

                    MouseArea {
                        id: deleteMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.deleteEvent()
                    }
                }
            }
        }
    }
}
