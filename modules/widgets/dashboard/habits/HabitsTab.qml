pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

Rectangle {
    id: root
    color: "transparent"
    implicitWidth: 400
    implicitHeight: 400

    function focusSearchInput() {
        habitInput.forceActiveFocus();
    }

    function submitHabit() {
        if (HabitService.addHabit(habitInput.text)) {
            habitInput.text = "";
            habitInput.forceActiveFocus();
        }
    }

    function weekdayLabel(daysAgo) {
        const labels = ["S", "M", "T", "W", "T", "F", "S"];
        const date = new Date();
        date.setDate(date.getDate() - daysAgo);
        return labels[date.getDay()];
    }

    Component.onCompleted: {
        Qt.callLater(() => habitInput.forceActiveFocus());
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        StyledRect {
            Layout.fillWidth: true
            Layout.preferredHeight: 96
            variant: "surface"
            radius: Styling.radius(8)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 16

                StyledRect {
                    Layout.preferredWidth: 56
                    Layout.preferredHeight: 56
                    Layout.alignment: Qt.AlignTop
                    variant: "primary"
                    radius: Styling.radius(6)

                    Text {
                        anchors.centerIn: parent
                        text: Icons.repeat
                        font.family: Icons.font
                        font.pixelSize: 24
                        color: Colors.overPrimary
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: "Habit Tracker"
                        font.family: Config.theme.font
                        font.pixelSize: 22
                        font.weight: Font.Bold
                        color: Colors.overSurface
                    }

                    Text {
                        text: HabitService.habits.length + " habits / " + HabitService.completedCount(0) + " done today"
                        font.family: Config.theme.font
                        font.pixelSize: 13
                        color: Colors.overSurfaceVariant
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 6
                        color: Colors.surfaceContainerHighest
                        radius: height / 2

                        Rectangle {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: HabitService.habits.length > 0 ? parent.width * (HabitService.completedCount(0) / HabitService.habits.length) : 0
                            height: parent.height
                            radius: parent.radius
                            color: Colors.primary

                            Behavior on width {
                                enabled: Config.animDuration > 0
                                NumberAnimation {
                                    duration: Config.animDuration
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }
                }
            }
        }

        StyledRect {
            Layout.fillWidth: true
            Layout.preferredHeight: 64
            variant: "surface"
            radius: Styling.radius(8)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                TextField {
                    id: habitInput
                    Layout.fillWidth: true
                    placeholderText: "Add a habit..."
                    color: Colors.overSurface
                    font.family: Config.theme.font
                    selectByMouse: true
                    onAccepted: root.submitHabit()

                    background: StyledRect {
                        variant: habitInput.activeFocus ? "focus" : "internalbg"
                        radius: Styling.radius(6)
                    }
                }

                Button {
                    id: addButton
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    enabled: habitInput.text.trim().length > 0
                    flat: true
                    onClicked: root.submitHabit()

                    background: StyledRect {
                        variant: addButton.enabled ? (addButton.down ? "overprimary" : "primary") : "common"
                        radius: Styling.radius(6)
                    }

                    contentItem: Text {
                        text: ">"
                        font.family: Config.theme.font
                        font.pixelSize: 18
                        font.weight: Font.Medium
                        color: addButton.enabled ? Colors.overPrimary : Colors.overSurfaceVariant
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }

        StyledRect {
            Layout.fillWidth: true
            Layout.fillHeight: true
            variant: "surface"
            radius: Styling.radius(8)

            Loader {
                anchors.fill: parent
                active: HabitService.habits.length === 0
                sourceComponent: emptyState
            }

            ListView {
                id: habitList
                anchors.fill: parent
                anchors.margins: 8
                clip: true
                spacing: 8
                model: HabitService.habits
                visible: HabitService.habits.length > 0

                delegate: StyledRect {
                    required property var modelData

                    width: habitList.width
                    height: Math.max(72, contentRow.implicitHeight + 20)
                    variant: HabitService.isDoneToday(modelData) ? "pane" : "common"
                    radius: Styling.radius(6)

                    RowLayout {
                        id: contentRow
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        Button {
                            id: toggleButton
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36
                            flat: true
                            onClicked: HabitService.toggleToday(modelData.id)

                            background: StyledRect {
                                variant: HabitService.isDoneToday(modelData) ? "primary" : "internalbg"
                                radius: height / 2
                            }

                            contentItem: Text {
                                text: HabitService.isDoneToday(modelData) ? "x" : ""
                                font.family: Config.theme.font
                                font.pixelSize: 16
                                font.weight: Font.Bold
                                color: HabitService.isDoneToday(modelData) ? Colors.overPrimary : Colors.overSurface
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.name
                                    font.family: Config.theme.font
                                    font.pixelSize: 15
                                    font.weight: Font.Medium
                                    color: Colors.overSurface
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: HabitService.streak(modelData) + "d"
                                    font.family: Config.theme.font
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                    color: Colors.primary
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Repeater {
                                    model: 7

                                    ColumnLayout {
                                        required property int index
                                        spacing: 4

                                        readonly property int daysAgo: 6 - index
                                        readonly property string dayKey: HabitService.dayKeyOffset(daysAgo)
                                        readonly property bool done: Boolean(modelData.history && modelData.history[dayKey])

                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: root.weekdayLabel(parent.daysAgo)
                                            font.family: Config.theme.font
                                            font.pixelSize: 10
                                            color: Colors.overSurfaceVariant
                                        }

                                        StyledRect {
                                            id: dayDot
                                            Layout.preferredWidth: 18
                                            Layout.preferredHeight: 18
                                            Layout.alignment: Qt.AlignHCenter
                                            variant: parent.done ? "primary" : "internalbg"
                                            radius: 9

                                            Text {
                                                anchors.centerIn: parent
                                                text: parent.done ? "x" : ""
                                                font.family: Config.theme.font
                                                font.pixelSize: 10
                                                color: parent.done ? Colors.overPrimary : Colors.overSurfaceVariant
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Button {
                            id: deleteButton
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36
                            flat: true
                            onClicked: HabitService.removeHabit(modelData.id)

                            background: StyledRect {
                                variant: deleteButton.down ? "error" : "pane"
                                radius: Styling.radius(5)
                            }

                            contentItem: Text {
                                text: "x"
                                font.family: Config.theme.font
                                font.pixelSize: 20
                                color: deleteButton.down ? Colors.overError : Colors.overSurface
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: emptyState

        Item {
            anchors.fill: parent

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 8

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Icons.repeat
                    font.family: Icons.font
                    font.pixelSize: 40
                    color: Colors.overSurfaceVariant
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "No habits yet"
                    font.family: Config.theme.font
                    font.pixelSize: 18
                    font.weight: Font.Medium
                    color: Colors.overSurface
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Add a daily habit above."
                    font.family: Config.theme.font
                    font.pixelSize: 13
                    color: Colors.overSurfaceVariant
                }
            }
        }
    }
}
