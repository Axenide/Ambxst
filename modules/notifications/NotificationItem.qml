import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import qs.modules.theme
import qs.modules.services
import qs.config
import "./NotificationAnimation.qml"
import "./notification_utils.js" as NotificationUtils

Item {
    id: root
    property var notificationObject
    property bool expanded: false
    property real fontSize: 12
    property real padding: 8
    property bool onlyNotification: false
    
    property bool isValid: notificationObject !== null && 
                          (notificationObject.summary !== null && notificationObject.summary.length > 0) ||
                          (notificationObject.body !== null && notificationObject.body.length > 0)
    
    signal destroyRequested

    implicitHeight: background.height

    function processNotificationBody(body) {
        if (!body) return ""
        return body.replace(/<[^>]*>/g, "").replace(/\n/g, " ");
    }

    function destroyWithAnimation() {
        notificationAnimation.startDestroy();
    }

    NotificationAnimation {
        id: notificationAnimation
        targetItem: background
        dismissOvershoot: 20
        parentWidth: root.width

        onDestroyFinished: {
            Notifications.discardNotification(notificationObject.id);
        }
    }

    MouseArea {
        id: dragManager
        anchors.fill: root
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

        onPressed: mouse => {
            if (mouse.button === Qt.MiddleButton) {
                root.destroyWithAnimation();
            }
        }
    }

    Rectangle {
        id: background
        width: parent.width
        height: contentColumn.implicitHeight + padding * 2
        radius: 8
        visible: root.isValid
        color: (notificationObject.urgency == NotificationUrgency.Critical) ? Colors.adapter.error : "transparent"

        Behavior on height {
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutCubic
            }
        }

        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            anchors.margins: root.padding
            spacing: expanded ? 8 : 4

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                NotificationAppIcon {
                    id: appIcon
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    Layout.alignment: Qt.AlignTop
                    size: 32
                    radius: Config.roundness > 0 ? Config.roundness + 4 : 0
                    visible: notificationObject && (notificationObject.appIcon !== "" || notificationObject.image !== "")
                    appIcon: notificationObject ? notificationObject.appIcon : ""
                    image: notificationObject ? notificationObject.image : ""
                    summary: notificationObject ? notificationObject.summary : ""
                    urgency: notificationObject ? notificationObject.urgency : NotificationUrgency.Normal
                }

                Column {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        width: parent.width
                        text: notificationObject.summary || ""
                        font.family: Config.theme.font
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        color: Colors.adapter.primary
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: processNotificationBody(notificationObject.body || "")
                        font.family: Config.theme.font
                        font.pixelSize: root.fontSize
                        color: Colors.adapter.overBackground
                        wrapMode: Text.NoWrap
                        elide: Text.ElideRight
                        visible: text.length > 0
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: expanded && notificationObject.actions.length > 0

                Repeater {
                    model: notificationObject.actions
                    Button {
                        Layout.fillWidth: true
                        text: modelData.text
                        onClicked: {
                            Notifications.attemptInvokeAction(notificationObject.id, modelData.identifier);
                        }
                    }
                }
            }
        }
    }
}
