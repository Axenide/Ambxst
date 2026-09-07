pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.services
import qs.modules.components
import qs.modules.theme
import qs.modules.globals
import qs.config

Item {
    id: root

    required property var bar

    property bool vertical: bar.orientation === "vertical"
    property bool isHovered: false
    property bool layerEnabled: true

    property real radius: 0
    property real startRadius: radius
    property real endRadius: radius

    property bool popupOpen: calPopup.isOpen

    // i18n helper — works with or without the I18n singleton
    function _t(key, fallback) {
        let str;
        try { str = I18n.t(key); } catch(e) { str = fallback; }
        for (let i = 2; i < arguments.length; i++)
            str = str.replace("%" + (i - 1), arguments[i]);
        return str;
    }

    readonly property bool showNextEvent: CalendarService.barShowNextEvent
    readonly property bool alwaysShow: CalendarService.barAlwaysShow
    readonly property var nextEvent: showNextEvent ? CalendarService.nextUpcomingEvent() : null
    property var todayEvents: CalendarService.todayEvents()

    // Split today's events into upcoming (allDay + future timed) and past (past timed)
    readonly property var upcomingTodayEvents: {
        void _tick;
        const now = new Date();
        return todayEvents.filter(ev => {
            if (ev.allDay) return true;
            try { return new Date(ev.end || ev.start) >= now; } catch(e) { return true; }
        });
    }
    readonly property var pastTodayEvents: {
        void _tick;
        const now = new Date();
        return todayEvents.filter(ev => {
            if (ev.allDay) return false;
            try { return new Date(ev.end || ev.start) < now; } catch(e) { return false; }
        });
    }

    readonly property bool hasEvents: {
        if (showNextEvent && nextEvent !== null) return true;
        if (alwaysShow) return todayEvents.length > 0;
        return upcomingTodayEvents.length > 0;
    }

    Connections {
        target: CalendarService
        function onEventsChanged() {
            root.todayEvents = CalendarService.todayEvents();
        }
    }


    visible: root.hasEvents

    implicitWidth: root.hasEvents ? (root.vertical ? 0 : bg.implicitWidth) : 0
    implicitHeight: root.hasEvents ? bg.implicitHeight : 0
    Layout.preferredWidth: root.hasEvents ? (root.vertical ? 0 : bg.implicitWidth) : 0
    Layout.preferredHeight: root.hasEvents ? bg.implicitHeight : 0
    Layout.fillWidth: root.vertical

    HoverHandler {
        onHoveredChanged: root.isHovered = hovered
    }

    StyledRect {
        id: bg
        variant: root.popupOpen ? "primary" : "bg"
        anchors.fill: parent
        enableShadow: root.layerEnabled

        implicitWidth: root.vertical ? 0 : (itemsRow.implicitWidth + 16)
        implicitHeight: root.vertical ? (itemsCol.implicitHeight + 8) : 36

        topLeftRadius: root.vertical ? root.startRadius : root.startRadius
        topRightRadius: root.vertical ? root.startRadius : root.endRadius
        bottomLeftRadius: root.vertical ? root.endRadius : root.startRadius
        bottomRightRadius: root.vertical ? root.endRadius : root.endRadius

        readonly property color itemColor: root.popupOpen ? Styling.srItem("primary") : Colors.overBackground

        Rectangle {
            anchors.fill: parent
            color: Styling.srItem("overprimary")
            opacity: root.popupOpen ? 0 : (root.isHovered ? 0.25 : 0)
            radius: parent.radius ?? 0
            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation { duration: Config.animDuration / 2 }
            }
        }

        // Horizontal layout
        RowLayout {
            id: itemsRow
            anchors.centerIn: parent
            visible: !root.vertical
            spacing: 6

            Text {
                id: blinkIconH
                text: Icons.calendarBlank
                font.family: Icons.font
                font.pixelSize: 13
                color: root.popupOpen ? bg.itemColor : Colors.primary
            }

            ColumnLayout {
                spacing: 0
                visible: root.showNextEvent && root.nextEvent !== null

                Text {
                    text: root.nextEvent ? root.nextEvent.title : ""
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-3)
                    font.weight: Font.Medium
                    color: bg.itemColor
                    elide: Text.ElideRight
                    Layout.maximumWidth: 100
                }

                Text {
                    text: root.timeUntilLive
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-4)
                    color: root.popupOpen ? bg.itemColor : Colors.outline
                }
            }

            // Today-only mode: show count badge (upcoming events only)
            Text {
                visible: !root.showNextEvent && root.upcomingTodayEvents.length > 0
                text: root.upcomingTodayEvents.length.toString()
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-3)
                font.weight: Font.Medium
                color: root.popupOpen ? bg.itemColor : Colors.outline
            }
        }

        // Vertical layout
        ColumnLayout {
            id: itemsCol
            anchors.centerIn: parent
            visible: root.vertical
            spacing: 2

            Text {
                id: blinkIconV
                Layout.alignment: Qt.AlignHCenter
                text: Icons.calendarBlank
                font.family: Icons.font
                font.pixelSize: 13
                color: root.popupOpen ? bg.itemColor : Colors.primary
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.upcomingTodayEvents.length.toString()
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-3)
                font.weight: Font.Medium
                color: bg.itemColor
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (CalendarService.iconBlinking)
                    CalendarService.dismissArrival();
                calPopup.toggle();
            }
        }
    }

    // Blinking animation for the calendar icon when an event is starting now
    readonly property alias _blinkIconH: blinkIconH
    readonly property alias _blinkIconV: blinkIconV

    SequentialAnimation {
        id: blinkAnim
        loops: Animation.Infinite
        NumberAnimation { targets: [blinkIconH, blinkIconV]; property: "opacity"; from: 1.0; to: 0.15; duration: 450; easing.type: Easing.InOutSine }
        NumberAnimation { targets: [blinkIconH, blinkIconV]; property: "opacity"; from: 0.15; to: 1.0; duration: 450; easing.type: Easing.InOutSine }
    }

    Connections {
        target: CalendarService
        function onIconBlinkingChanged() {
            if (CalendarService.iconBlinking) {
                blinkAnim.start();
            } else {
                blinkAnim.stop();
                blinkIconH.opacity = 1.0;
                blinkIconV.opacity = 1.0;
            }
        }
    }

    // Popup with today's events
    BarPopup {
        id: calPopup
        anchorItem: bg
        bar: root.bar
        popupPadding: 12
        contentWidth: root.vertical ? 260 : Math.max(bg.width, 260)
        contentHeight: popupColumn.implicitHeight + 24

        ColumnLayout {
            id: popupColumn
            width: parent.width
            spacing: 8

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: Icons.calendarBlank
                    font.family: Icons.font
                    font.pixelSize: 14
                    color: Colors.primary
                }

                Text {
                    Layout.fillWidth: true
                    text: {
                        const now = new Date();
                        return now.toLocaleDateString(Qt.locale(), "d MMMM, dddd");
                    }
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(0)
                    font.weight: Font.DemiBold
                    color: Colors.overBackground
                    elide: Text.ElideRight
                }
            }

            Separator {
                Layout.fillWidth: true
                vert: false
                Layout.topMargin: -4
                Layout.bottomMargin: -4
            }

            // Section label component
            component SectionLabel: Text {
                required property string labelText
                Layout.fillWidth: true
                text: labelText
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-3)
                font.weight: Font.DemiBold
                color: Colors.outline
                Layout.topMargin: 2
            }

            // Event row component
            component EventCard: StyledRect {
                required property var eventData
                property bool dimmed: false
                Layout.fillWidth: true
                variant: "common"
                radius: Styling.radius(-2)
                implicitHeight: evRow.implicitHeight + 14
                opacity: dimmed ? 0.5 : 1.0

                RowLayout {
                    id: evRow
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    anchors.topMargin: 7
                    anchors.bottomMargin: 7
                    spacing: 10

                    Rectangle {
                        width: 3
                        Layout.fillHeight: true
                        radius: 2
                        color: CalendarService.calendarColor(eventData.calendarId)
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: eventData.title || root._t("calendar.event.untitled", "Untitled")
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            font.weight: Font.Medium
                            color: Colors.overBackground
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: {
                                if (eventData.allDay) return root._t("calendar.event.all_day", "All day");
                                const s = eventData.start || "";
                                const e = eventData.end || "";
                                const st = s.includes("T") ? s.split("T")[1].substring(0,5) : "";
                                const et = e.includes("T") ? e.split("T")[1].substring(0,5) : "";
                                return st + (et ? " – " + et : "");
                            }
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-3)
                            color: Colors.outline
                        }
                    }
                }
            }

            // Upcoming events (always shown)
            SectionLabel {
                labelText: root._t("calendar.bar.section_upcoming", "Upcoming")
                visible: root.alwaysShow && root.pastTodayEvents.length > 0
            }

            Repeater {
                model: root.alwaysShow ? root.upcomingTodayEvents : root.todayEvents

                delegate: EventCard {
                    required property var modelData
                    eventData: modelData
                    dimmed: false
                }
            }

            // Past events section (only when alwaysShow is on)
            SectionLabel {
                labelText: root._t("calendar.bar.section_past", "Past")
                visible: root.alwaysShow && root.pastTodayEvents.length > 0
            }

            Repeater {
                model: root.alwaysShow ? root.pastTodayEvents : []

                delegate: EventCard {
                    required property var modelData
                    eventData: modelData
                    dimmed: true
                }
            }

            // Empty state
            Text {
                visible: root.todayEvents.length === 0
                text: root._t("calendar.bar.no_events", "No events today")
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                color: Colors.outline
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 4
                Layout.bottomMargin: 4
            }
        }
    }

    // Refresh timer — force re-evaluation of timeUntil
    property int _tick: 0
    readonly property string timeUntilLive: {
        void _tick; // depend on tick to force re-eval
        if (!nextEvent) return "";
        try {
            const now = new Date();
            const start = new Date(nextEvent.start);
            const diff = Math.max(0, Math.floor((start.getTime() - now.getTime()) / 60000));
            if (diff < 1) return root._t("calendar.bar.time_now", "now");
            if (diff < 60) return root._t("calendar.bar.time_minutes", "in %1 min", diff);
            const hours = Math.floor(diff / 60);
            return root._t("calendar.bar.time_hours", "in %1h %2m", hours, diff % 60);
        } catch(e) { return ""; }
    }

    Timer {
        running: root.visible && (root.nextEvent !== null || root.alwaysShow)
        interval: 30000
        repeat: true
        onTriggered: root._tick++
    }
}
