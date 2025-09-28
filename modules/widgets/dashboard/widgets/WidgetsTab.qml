import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.modules.notifications
import qs.config

Rectangle {
    color: "transparent"
    implicitWidth: 600
    implicitHeight: 300

    RowLayout {
        anchors.fill: parent
        spacing: 8

        // Left panel - Widgets content
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Colors.surface
            radius: Config.roundness + 4

            Text {
                anchors.centerIn: parent
                text: "Widgets"
                color: Colors.adapter.overSurfaceVariant
                font.family: Config.theme.font
                font.pixelSize: 16
                font.weight: Font.Medium
            }
        }

        // Right panel - Notification history
        Rectangle {
            Layout.preferredWidth: 340
            Layout.fillHeight: true
            color: Colors.surface
            radius: Config.roundness + 4
            clip: true

            ScrollView {
                anchors.fill: parent
                anchors.margins: 8

                ListView {
                    id: notificationList
                    spacing: 8
                    model: Notifications.appNameList

                    delegate: NotificationGroup {
                        required property int index
                        required property string modelData
                        width: notificationList.width
                        notificationGroup: Notifications.groupsByAppName[modelData]
                        expanded: false  // Always expanded for history view
                        popup: false
                    }
                }
            }
        }
    }
}
