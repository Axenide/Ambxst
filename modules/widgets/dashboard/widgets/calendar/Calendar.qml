import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import "layout.js" as CalendarLayout

Item {
    id: root

    property int monthShift: 0
    property var viewingDate: CalendarLayout.getDateInXMonthsTime(monthShift)
    property var calendarLayoutData: CalendarLayout.getCalendarLayout(viewingDate, monthShift === 0)
    property var calendarLayout: calendarLayoutData.calendar
    property int currentWeekRow: calendarLayoutData.currentWeekRow
    property int currentDayOfWeek: {
        if (monthShift !== 0)
            return -1;
        var now = new Date();
        return (now.getDay() + 6) % 7;
    }

    function getDayAbbrev(dayIndex) {
        var keys = [
            "calendar.day.mon", "calendar.day.tue", "calendar.day.wed",
            "calendar.day.thu", "calendar.day.fri", "calendar.day.sat",
            "calendar.day.sun"
        ];
        return I18n.t(keys[dayIndex]);
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

                    StyledRect {
                        id: titleRect
                        variant: "internalbg"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Styling.radius(0)

                        Text {
                            anchors.centerIn: parent
                            text: {
                                var monthKeys = [
                                    "calendar.month.january", "calendar.month.february",
                                    "calendar.month.march", "calendar.month.april",
                                    "calendar.month.may", "calendar.month.june",
                                    "calendar.month.july", "calendar.month.august",
                                    "calendar.month.september", "calendar.month.october",
                                    "calendar.month.november", "calendar.month.december"
                                ];
                                return I18n.t(monthKeys[viewingDate.getMonth()]) + " " + viewingDate.getFullYear();
                            }
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
                                            day: calendarLayout[rowIndex][index].day
                                            isToday: calendarLayout[rowIndex][index].today
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
