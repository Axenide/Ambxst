import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.Notifications
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

Item {
    id: root
    property var actions: []
    property bool showWhen: true
    property var notificationObject: null
    property int urgency: NotificationUrgency.Normal

    Layout.fillWidth: true
    implicitHeight: showWhen && actions.length > 0 ? 32 : 0
    height: implicitHeight
    clip: true

    RowLayout {
        anchors.fill: parent
        spacing: 4

        Repeater {
            model: actions

            Button {
                Layout.fillWidth: true
                Layout.preferredHeight: 32

                text: modelData.text
                font.family: Config.theme.font
                font.pixelSize: Config.theme.fontSize
                font.weight: Font.Bold
                hoverEnabled: true

                background: Item {
                    id: buttonBg
                    property color textColor: root.urgency == NotificationUrgency.Critical ? Colors.shadow : styledBg.item
                    
                    Rectangle {
                        anchors.fill: parent
                        visible: root.urgency == NotificationUrgency.Critical
                        color: parent.parent.hovered ? Qt.lighter(Colors.criticalRed, 1.3) : Colors.criticalRed
                        radius: Styling.radius(4)

                        Behavior on color {
                            enabled: Config.animDuration > 0
                            ColorAnimation {
                                duration: Config.animDuration
                            }
                        }
                    }

                    StyledRect {
                        id: styledBg
                        anchors.fill: parent
                        visible: root.urgency != NotificationUrgency.Critical
                        variant: parent.parent.pressed ? "primary" : (parent.parent.hovered ? "focus" : "common")
                        radius: Styling.radius(4)
                    }
                }

                contentItem: Text {
                    text: parent.text
                    font: parent.font
                    color: parent.background.textColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight

                    Behavior on color {
                        enabled: Config.animDuration > 0
                        ColorAnimation {
                            duration: Config.animDuration
                        }
                    }
                }

                onClicked: {
                    if (root.notificationObject) {
                        Notifications.attemptInvokeAction(root.notificationObject.id, modelData.identifier);
                    }
                }
            }
        }
    }
}
