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
    property var notificationGroup
    property var notifications: notificationGroup?.notifications ?? []
    property int notificationCount: notifications.length
    property bool multipleNotifications: notificationCount > 1
    property bool expanded: false
    property bool popup: false
    property real padding: 16
    implicitHeight: background.implicitHeight

    property real dragConfirmThreshold: 70
    property real dismissOvershoot: 20
    property var qmlParent: root.parent.parent
    property var parentDragIndex: qmlParent?.dragIndex ?? -1
    property var parentDragDistance: qmlParent?.dragDistance ?? 0
    property var dragIndexDiff: Math.abs(parentDragIndex - (index ?? 0))
    property real xOffset: dragIndexDiff == 0 ? Math.max(0, parentDragDistance) : parentDragDistance > dragConfirmThreshold ? 0 : dragIndexDiff == 1 ? Math.max(0, parentDragDistance * 0.3) : dragIndexDiff == 2 ? Math.max(0, parentDragDistance * 0.1) : 0

    function destroyWithAnimation() {
        if (root.qmlParent && root.qmlParent.resetDrag)
            root.qmlParent.resetDrag();
        background.anchors.leftMargin = background.anchors.leftMargin;
        notificationAnimation.startDestroy();
    }

    NotificationAnimation {
        id: notificationAnimation
        targetItem: background
        dismissOvershoot: root.dismissOvershoot
        parentWidth: root.width

        onDestroyFinished: {
            root.notifications.forEach(notif => {
                Qt.callLater(() => {
                    Notifications.discardNotification(notif.id);
                });
            });
        }
    }

    function toggleExpanded() {
        root.expanded = !root.expanded;
    }

    // Escuchar cuando las notificaciones van a hacer timeout
    Connections {
        target: Notifications
        function onTimeoutWithAnimation(id) {
            // Verificar si la notificación que va a hacer timeout pertenece a este grupo
            const notifExists = root.notifications.some(notif => notif.id === id);
            if (notifExists && root.popup) {
                root.destroyWithAnimation();
            }
        }
    }

    // HoverHandler dedicado para pausar/reanudar timers
    HoverHandler {
        id: hoverHandler

        onHoveredChanged: {
            if (hovered) {
                if (notificationGroup?.appName) {
                    Notifications.pauseGroupTimers(notificationGroup.appName);
                }
            } else {
                if (notificationGroup?.appName) {
                    Notifications.resumeGroupTimers(notificationGroup.appName);
                }
            }
        }
    }

    MouseArea {
        id: dragManager
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                root.toggleExpanded();
            else if (mouse.button === Qt.MiddleButton)
                root.destroyWithAnimation();
        }

        property bool dragging: false
        property real dragDiffX: 0

        function resetDrag() {
            dragging = false;
            dragDiffX = 0;
        }
    }

    Rectangle {
        id: shadowRect
        anchors.fill: background
        anchors.margins: -2
        color: "transparent"
        border.color: "#00000020"
        border.width: popup ? 1 : 0
        radius: background.radius + 2
        visible: popup
    }

    Rectangle {
        id: background
        anchors.left: parent.left
        width: parent.width
        color: Colors.background
        radius: Config.roundness > 0 ? Config.roundness + 8 : 0
        border.color: Colors.surfaceContainerHigh
        border.width: 2
        anchors.leftMargin: root.xOffset

        Behavior on anchors.leftMargin {
            enabled: !dragManager.dragging
            NumberAnimation {
                duration: 300
                easing.type: Easing.OutCubic
            }
        }

        clip: true
        implicitHeight: expanded ? row.implicitHeight + padding * 2 : Math.min(80, row.implicitHeight + padding * 2)

        Behavior on implicitHeight {
            NumberAnimation {
                duration: 300
                easing.type: Easing.OutCubic
            }
        }

        RowLayout {
            id: row
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: root.padding
            spacing: 4

            NotificationAppIcon {
                Layout.alignment: Qt.AlignTop
                Layout.fillWidth: false
                image: root?.multipleNotifications ? "" : notificationGroup?.notifications[0]?.image ?? ""
                appIcon: notificationGroup?.appIcon
                summary: notificationGroup?.notifications[root.notificationCount - 1]?.summary
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: expanded ? (root.multipleNotifications ? (notificationGroup?.notifications[root.notificationCount - 1].image != "") ? 35 : 5 : 0) : 0

                Behavior on spacing {
                    NumberAnimation {
                        duration: 200
                    }
                }

                Item {
                    id: topRow
                    Layout.fillWidth: true
                    property real fontSize: 11
                    property bool showAppName: root.multipleNotifications
                    implicitHeight: Math.max(topTextRow.implicitHeight, expandButton.implicitHeight)

                    RowLayout {
                        id: topTextRow
                        anchors.left: parent.left
                        anchors.right: expandButton.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5

                        Text {
                            id: appName
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            text: (topRow.showAppName ? notificationGroup?.appName : notificationGroup?.notifications[0]?.summary) || ""
                            font.family: Config.theme.font
                            font.pixelSize: topRow.showAppName ? topRow.fontSize : 14
                            font.weight: Font.Bold
                            color: topRow.showAppName ? Colors.adapter.outline : Colors.adapter.primary
                        }
                        Text {
                            id: timeText
                            Layout.rightMargin: 10
                            horizontalAlignment: Text.AlignLeft
                            text: NotificationUtils.getFriendlyNotifTimeString(notificationGroup?.time)
                            font.family: Config.theme.font
                            font.pixelSize: topRow.fontSize
                            color: Colors.adapter.overBackground
                        }
                    }
                    NotificationGroupExpandButton {
                        id: expandButton
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        count: root.notificationCount
                        expanded: root.expanded
                        fontSize: topRow.fontSize
                        onClicked: {
                            root.toggleExpanded();
                        }
                    }
                }

                ListView {
                    id: notificationsColumn
                    implicitHeight: contentHeight
                    Layout.fillWidth: true
                    spacing: expanded ? 5 : 3
                    interactive: false

                    Behavior on spacing {
                        NumberAnimation {
                            duration: 200
                        }
                    }

                    model: expanded ? root.notifications.slice().reverse() : root.notifications.slice().reverse().slice(0, 2)

                    delegate: NotificationItem {
                        required property int index
                        required property var modelData
                        notificationObject: modelData
                        expanded: root.expanded
                        onlyNotification: (root.notificationCount === 1)
                        opacity: (!root.expanded && index == 1 && root.notificationCount > 2) ? 0.5 : 1
                        visible: root.expanded || (index < 2)
                        anchors.left: parent?.left
                        anchors.right: parent?.right

                        onDestroyRequested: {
                            if (root.notificationCount === 1) {
                                root.destroyWithAnimation();
                            }
                        }
                    }
                }
            }
        }
    }
}
