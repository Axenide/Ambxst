pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

Rectangle {
    id: button

    required property string day
    required property int isToday
    property bool bold: false
    property bool isCurrentDayOfWeek: false
    property int year: 0
    property int month: 0
    property bool isHeaderDay: bold
    property bool isSelected: false

    readonly property bool accountsConnected: CalendarService.hasAccounts

    signal clicked()

    readonly property var dayEvents: {
        if (!accountsConnected) return [];
        if (isHeaderDay || year === 0 || day === "") return [];
        const d = parseInt(day);
        if (isNaN(d)) return [];
        return CalendarService.eventsForDate(year, month, d);
    }
    readonly property bool hasEvents: dayEvents.length > 0

    Layout.fillWidth: true
    Layout.fillHeight: false
    Layout.preferredWidth: 28
    Layout.preferredHeight: 28

    color: "transparent"
    radius: Styling.radius(-2)

    // Original layout — no accounts, static calendar
    StyledRect {
        visible: !button.accountsConnected
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height)
        height: width
        variant: (isToday === 1) ? "primary" : "transparent"
        radius: parent.radius

        Text {
            anchors.fill: parent
            text: day
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.weight: Font.Bold
            font.pixelSize: Styling.fontSize(-2)
            font.family: Config.defaultFont
            color: {
                if (isToday === 1)
                    return Styling.srItem("primary");
                if (bold) {
                    return isCurrentDayOfWeek ? Colors.overBackground : Colors.outline;
                }
                if (isToday === 0)
                    return Colors.overSurface;
                return Colors.surfaceBright;
            }

            Behavior on color {
                enabled: Config.animDuration > 0
                ColorAnimation {
                    duration: 150
                }
            }
        }

    }

    // Enhanced layout — with accounts, event dots inside cell
    StyledRect {
        visible: button.accountsConnected
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height)
        height: width
        variant: (isToday === 1) ? "primary" : (dayMouseArea.containsMouse && !isHeaderDay ? "focus" : "transparent")
        radius: button.radius

        Text {
            anchors.centerIn: parent
            text: day
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.weight: Font.Bold
            font.pixelSize: Styling.fontSize(-2)
            font.family: Config.defaultFont
            color: {
                if (isToday === 1)
                    return Styling.srItem("primary");
                if (bold) {
                    return isCurrentDayOfWeek ? Colors.overBackground : Colors.outline;
                }
                if (isToday === 0)
                    return Colors.overSurface;
                return Colors.surfaceBright;
            }

            Behavior on color {
                enabled: Config.animDuration > 0
                ColorAnimation { duration: 150 }
            }
        }

        // Event indicator dots — overlay at bottom of cell
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 2
            spacing: 2
            visible: button.hasEvents && !button.isHeaderDay

            Repeater {
                model: Math.min(button.dayEvents.length, 3)
                delegate: Rectangle {
                    required property int index
                    width: 3
                    height: 3
                    radius: 2
                    color: {
                        const ev = button.dayEvents[index];
                        if (!ev) return Colors.primary;
                        return CalendarService.calendarColor(ev.calendarId);
                    }
                }
            }
        }

        MouseArea {
            id: dayMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: isHeaderDay ? Qt.ArrowCursor : Qt.PointingHandCursor
            onClicked: if (!isHeaderDay) button.clicked()
        }
    }

    // Selection border — sibling of StyledRects, not clipped by them
    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height)
        height: width
        color: "transparent"
        border.color: Colors.primary
        border.width: 1.5
        radius: Styling.radius(-2)
        visible: button.isSelected
        opacity: 0.7
    }
}
