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
        taskInput.forceActiveFocus();
    }

    function submitTask() {
        if (TodoService.addTask(taskInput.text)) {
            taskInput.text = "";
            taskInput.forceActiveFocus();
        }
    }

    Component.onCompleted: {
        Qt.callLater(() => taskInput.forceActiveFocus());
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
                        text: Icons.list
                        font.family: Icons.font
                        font.pixelSize: 24
                        color: Colors.overPrimary
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: "To-do List"
                        font.family: Config.theme.font
                        font.pixelSize: 22
                        font.weight: Font.Bold
                        color: Colors.overSurface
                    }

                    Text {
                        text: TodoService.openCount + " open / " + TodoService.completedCount + " done"
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
                            width: TodoService.tasks.length > 0 ? parent.width * (TodoService.completedCount / TodoService.tasks.length) : 0
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
                    id: taskInput
                    Layout.fillWidth: true
                    placeholderText: "Add a task..."
                    color: Colors.overSurface
                    font.family: Config.theme.font
                    selectByMouse: true
                    onAccepted: root.submitTask()

                    background: StyledRect {
                        variant: taskInput.activeFocus ? "focus" : "internalbg"
                        radius: Styling.radius(6)
                    }
                }

                Button {
                    id: addButton
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    enabled: taskInput.text.trim().length > 0
                    flat: true
                    onClicked: root.submitTask()

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

                Button {
                    id: clearCompletedButton
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    enabled: TodoService.completedCount > 0
                    flat: true
                    onClicked: TodoService.clearCompleted()

                    background: StyledRect {
                        variant: clearCompletedButton.enabled ? (clearCompletedButton.down ? "error" : "pane") : "common"
                        radius: Styling.radius(6)
                    }

                    contentItem: Text {
                        text: "X"
                        font.family: Config.theme.font
                        font.pixelSize: 16
                        color: clearCompletedButton.enabled && clearCompletedButton.down ? Colors.overError : Colors.overSurface
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
                active: TodoService.tasks.length === 0
                sourceComponent: emptyState
            }

            ListView {
                id: taskList
                anchors.fill: parent
                anchors.margins: 8
                clip: true
                spacing: 8
                model: TodoService.tasks
                visible: TodoService.tasks.length > 0

                delegate: StyledRect {
                    required property var modelData
                    required property int index

                    width: taskList.width
                    height: Math.max(56, taskRow.implicitHeight + 20)
                    variant: modelData.completed ? "pane" : "common"
                    radius: Styling.radius(6)

                    RowLayout {
                        id: taskRow
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        Button {
                            id: toggleButton
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            flat: true
                            onClicked: TodoService.toggleTask(modelData.id)

                            background: StyledRect {
                                variant: modelData.completed ? "primary" : "internalbg"
                                radius: height / 2
                            }

                            contentItem: Text {
                                text: modelData.completed ? "x" : ""
                                font.family: Config.theme.font
                                font.pixelSize: 14
                                font.weight: Font.Bold
                                color: modelData.completed ? Colors.overPrimary : Colors.overSurface
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.text
                            wrapMode: Text.Wrap
                            font.family: Config.theme.font
                            font.pixelSize: 14
                            color: modelData.completed ? Colors.overSurfaceVariant : Colors.overSurface
                            font.strikeout: modelData.completed
                            maximumLineCount: 3
                            elide: Text.ElideRight
                        }

                        Button {
                            id: deleteButton
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36
                            flat: true
                            onClicked: TodoService.removeTask(modelData.id)

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
                    text: Icons.list
                    font.family: Icons.font
                    font.pixelSize: 40
                    color: Colors.overSurfaceVariant
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Nothing queued"
                    font.family: Config.theme.font
                    font.pixelSize: 18
                    font.weight: Font.Medium
                    color: Colors.overSurface
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Add your first task above."
                    font.family: Config.theme.font
                    font.pixelSize: 13
                    color: Colors.overSurfaceVariant
                }
            }
        }
    }
}
