pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.globals
import "layout.js" as CalendarLayout

Item {
    id: root

    property int monthShift: 0
    property date currentDate: new Date()
    property var viewingDate: CalendarLayout.getDateInXMonthsTime(monthShift, currentDate)
    property var calendarLayoutData: CalendarLayout.getCalendarLayout(viewingDate, monthShift === 0)
    property var calendarLayout: calendarLayoutData.calendar
    property int currentWeekRow: calendarLayoutData.currentWeekRow
    property int currentDayOfWeek: {
        if (monthShift !== 0)
            return -1;
        return (currentDate.getDay() + 6) % 7;
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.currentDate = new Date()
    }

    // Currently selected day for EventPopup
    property int selectedDay: 0
    property int selectedMonth: 0
    property int selectedYear: 0
    property var selectedDayEvents: []

    // Viewing month/year for passing to day buttons
    readonly property int viewingMonth: viewingDate.getMonth() + 1
    readonly property int viewingYear: viewingDate.getFullYear()

    signal openCalendarSettings()
    signal daySelected(int day, int month, int year)

    function clearSelection() {
        selectedDay = 0;
        selectedMonth = 0;
        selectedYear = 0;
    }

    function getDayAbbrev(dayIndex) {
        var d = new Date(2024, 0, 1 + dayIndex);
        var dayName = d.toLocaleDateString(Qt.locale(), "ddd");
        return (dayName.charAt(0).toUpperCase() + dayName.slice(1, 2)).replace(".", "");
    }

    function openDayPopup(dayData, item) {
        const d = parseInt(dayData.day);
        if (isNaN(d)) return;
        // Determine actual month/year for this day cell
        let m = root.viewingMonth;
        let y = root.viewingYear;
        if (dayData.today === -1) {
            // Day from adjacent month — not current viewing month
            if (d > 15) { m--; } else { m++; }
            if (m < 1) { m = 12; y--; }
            if (m > 12) { m = 1; y++; }
        }
        root.selectedDay = d;
        root.selectedMonth = m;
        root.selectedYear = y;
        root.selectedDayEvents = CalendarService.eventsForDate(y, m, d);
        root.daySelected(d, m, y);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        StyledRect {
            id: calendarPane
            variant: "pane"
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Styling.radius(4)
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 4
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    Layout.maximumHeight: 32
                    spacing: 4

                    // Gear button for calendar settings
                    StyledRect {
                        id: gearButton
                        variant: gearMouseArea.pressed ? "primary" : (gearMouseArea.containsMouse ? "focus" : "internalbg")
                        Layout.preferredWidth: 32
                        Layout.fillHeight: true
                        radius: Styling.radius(0)
                        visible: true

                        readonly property color buttonItem: gearMouseArea.pressed ? itemColor : Styling.srItem("overprimary")

                        Text {
                            anchors.centerIn: parent
                            text: Icons.gear
                            font.family: Icons.font
                            font.pixelSize: 14
                            color: gearButton.buttonItem
                        }

                        MouseArea {
                            id: gearMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.openCalendarSettings()
                            cursorShape: Qt.PointingHandCursor
                        }
                    }

                    StyledRect {
                        id: titleRect
                        variant: "internalbg"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Styling.radius(0)

                        Text {
                            anchors.centerIn: parent
                            text: viewingDate.toLocaleDateString(Qt.locale(), "MMMM yyyy")
                            font.family: Config.defaultFont
                            font.pixelSize: Config.theme.fontSize
                            font.weight: Font.Bold
                            color: titleRect.item
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    StyledRect {
                        id: leftButton
                        variant: leftMouseArea.pressed ? "primary" : (leftMouseArea.containsMouse ? "focus" : "internalbg")
                        Layout.preferredWidth: 32
                        Layout.fillHeight: true
                        radius: Styling.radius(0)

                        readonly property color buttonItem: leftMouseArea.pressed ? itemColor : Styling.srItem("overprimary")

                        Text {
                            anchors.centerIn: parent
                            text: Icons.caretLeft
                            font.family: Icons.font
                            font.pixelSize: 16
                            color: leftButton.buttonItem
                        }

                        MouseArea {
                            id: leftMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: monthShift--
                            cursorShape: Qt.PointingHandCursor
                        }
                    }

                    StyledRect {
                        id: rightButton
                        variant: rightMouseArea.pressed ? "primary" : (rightMouseArea.containsMouse ? "focus" : "internalbg")
                        Layout.preferredWidth: 32
                        Layout.fillHeight: true
                        radius: Styling.radius(0)

                        readonly property color buttonItem: rightMouseArea.pressed ? itemColor : Styling.srItem("overprimary")

                        Text {
                            anchors.centerIn: parent
                            text: Icons.caretRight
                            font.family: Icons.font
                            font.pixelSize: 16
                            color: rightButton.buttonItem
                        }

                        MouseArea {
                            id: rightMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: monthShift++
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                }

                StyledRect {
                    variant: "internalbg"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Styling.radius(0)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 0

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter

                            Repeater {
                                model: 7
                                delegate: CalendarDayButton {
                                    required property int index
                                    day: root.getDayAbbrev(index)
                                    isToday: 0
                                    bold: true
                                    isCurrentDayOfWeek: index === root.currentDayOfWeek
                                }
                            }
                        }

                        Separator {
                            Layout.fillWidth: true
                            Layout.leftMargin: 8
                            Layout.rightMargin: 8
                            Layout.preferredHeight: 2
                            vert: false
                        }

                        Repeater {
                            model: 6
                            delegate: StyledRect {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredHeight: 28
                                variant: (rowIndex === root.currentWeekRow) ? "pane" : "transparent"
                                radius: Styling.radius(-4)

                                required property int index
                                property int rowIndex: index

                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 0

                                    Repeater {
                                        model: 7
                                        delegate: CalendarDayButton {
                                            required property int index
                                            readonly property var cellData: calendarLayout[rowIndex][index]
                                            day: cellData.day
                                            isToday: cellData.today
                                            year: {
                                                let y = root.viewingYear;
                                                if (cellData.today === -1) {
                                                    let m = root.viewingMonth;
                                                    const d = parseInt(cellData.day);
                                                    if (d > 15) { m--; } else { m++; }
                                                    if (m < 1) y--;
                                                    if (m > 12) y++;
                                                }
                                                return y;
                                            }
                                            month: {
                                                if (cellData.today === -1) {
                                                    let m = root.viewingMonth;
                                                    const d = parseInt(cellData.day);
                                                    if (d > 15) { m--; } else { m++; }
                                                    if (m < 1) m = 12;
                                                    if (m > 12) m = 1;
                                                    return m;
                                                }
                                                return root.viewingMonth;
                                            }
                                            isSelected: root.selectedDay > 0 && parseInt(cellData.day) === root.selectedDay && month === root.selectedMonth && year === root.selectedYear
                                            onClicked: root.openDayPopup(cellData, this)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }


        }
    }
}
