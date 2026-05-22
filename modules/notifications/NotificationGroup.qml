import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import "./NotificationAnimation.qml"
import "./NotificationDelegate.qml"
import "./notification_utils.js" as NotificationUtils

Item {
    id: root
    property var notificationGroup
    property var notifications: notificationGroup?.notifications ?? []
    property int notificationCount: notifications.length
    property bool multipleNotifications: notificationCount > 1
    property var validNotifications: notifications.filter(n => n != null && n.summary != null)

    property var groupedNotifications: {
        // Ordenar notificaciones por tiempo descendente (más recientes primero)
        const sortedNotifications = root.validNotifications.slice().sort((a, b) => b.time - a.time);
        const groups = {};
        sortedNotifications.forEach(notif => {
            const summary = notif.summary || "";
            if (!groups[summary]) {
                groups[summary] = [];
            }
            groups[summary].push(notif);
        });
        // Limitar cada grupo a máximo 5 notificaciones visibles
        return Object.values(groups).map(notifications => ({
                    summary: notifications[0].summary,
                    notifications: notifications.slice(0, 5)
                }));
    }

    onNotificationGroupChanged: {}

    onValidNotificationsChanged: {}
    property bool expanded: false

    onNotificationCountChanged: {
        if (notificationCount === 1)
            root.expanded = true;
    }
    property bool popup: false
    property real padding: 8
    implicitHeight: background.implicitHeight

    property real dragConfirmThreshold: 70
    property real dismissOvershoot: 20
    property var qmlParent: root.parent.parent
    property var parentDragIndex: qmlParent?.dragIndex ?? -1
    property var parentDragDistance: qmlParent?.dragDistance ?? 0
    property var dragIndexDiff: Math.abs(parentDragIndex - (index ?? 0))
    property real xOffset: dragIndexDiff == 0 ? Math.max(0, parentDragDistance) : parentDragDistance > dragConfirmThreshold ? 0 : dragIndexDiff == 1 ? Math.max(0, parentDragDistance * 0.3) : dragIndexDiff == 2 ? Math.max(0, parentDragDistance * 0.1) : 0

    function destroyWithAnimation(isDiscardAll = false) {
        if (root.qmlParent && root.qmlParent.resetDrag)
            root.qmlParent.resetDrag();
        background.anchors.leftMargin = background.anchors.leftMargin;
        notificationAnimation.isDiscardAll = isDiscardAll;
        notificationAnimation.startDestroy();
    }

    NotificationAnimation {
        id: notificationAnimation
        targetItem: background
        dismissOvershoot: root.dismissOvershoot
        parentWidth: root.width

        onDestroyFinished: {
            if (!notificationAnimation.isDiscardAll) {
                // Usar discard masivo para mejor rendimiento
                const ids = root.notifications.map(notif => notif.id);
                Notifications.discardNotifications(ids);
            }
        }
    }

    function toggleExpanded() {
        if (root.multipleNotifications) {
            root.expanded = !root.expanded;
        }
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

    StyledRect {
        id: background
        variant: "internalbg"
        anchors.left: parent.left
        width: parent.width
        radius: Styling.radius(0)
        anchors.leftMargin: root.xOffset

        Behavior on anchors.leftMargin {
            enabled: !dragManager.dragging && Config.animDuration > 0
            NumberAnimation {
                duration: 300
                easing.type: Easing.OutCubic
            }
        }

        clip: true
        implicitHeight: expanded ? row.implicitHeight + padding * 2 : Math.max(56 + padding * 2, row.implicitHeight + padding * 2)

        Behavior on implicitHeight {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutBack
            }
        }

        RowLayout {
            id: row
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: root.padding
            spacing: root.padding / 2

            ColumnLayout {
                Layout.fillWidth: true
                spacing: root.notificationCount === 1 ? 0 : (root.expanded ? 8 : 4)

                Behavior on spacing {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutCubic
                    }
                }

                Item {
                    id: topRow
                    Layout.fillWidth: true
                    property real fontSize: Config.theme.fontSize
                    property bool showAppName: root.multipleNotifications
                    implicitHeight: root.multipleNotifications ? Math.max(topTextRow.implicitHeight, expandButton.implicitHeight) : 0
                    visible: root.multipleNotifications

                    RowLayout {
                        id: topTextRow
                        anchors.left: parent.left
                        anchors.right: expandButton.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5
                        visible: root.multipleNotifications

                        // Small app icon similar to NotificationAppIcon's overlay
                        Image {
                            mipmap: true
                            id: groupSmallAppIcon
                            Layout.preferredWidth: 16
                            Layout.preferredHeight: 16
                            source: (notificationGroup && notificationGroup.appIcon !== "") ? "image://icon/" + notificationGroup.appIcon : ""
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            visible: notificationGroup && notificationGroup.appIcon !== "" && root.validNotifications.some(n => n.image !== "")
                        }
                        Text {
                            text: Icons.info
                            textFormat: Text.RichText
                            font.family: Icons.font
                            font.pixelSize: 16
                            color: topRow.showAppName ? Colors.outline : Styling.srItem("overprimary")
                            visible: !groupSmallAppIcon.visible
                        }

                        Text {
                            id: appName
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            text: (topRow.showAppName ? notificationGroup?.appName : (root.validNotifications.length > 0 ? root.validNotifications[0]?.summary ?? "" : "")) || ""
                            font.family: Config.theme.font
                            font.pixelSize: Config.theme.fontSize
                            font.weight: Font.Bold
                            color: topRow.showAppName ? Colors.outline : Styling.srItem("overprimary")
                        }
                        Text {
                            id: timeText
                            Layout.rightMargin: 10
                            horizontalAlignment: Text.AlignLeft
                            text: root.multipleNotifications ? "" : NotificationUtils.getFriendlyNotifTimeString(notificationGroup?.time)
                            font.family: Config.theme.font
                            font.pixelSize: Config.theme.fontSize
                            color: Colors.overBackground
                            visible: text !== ""
                        }
                    }
                    NotificationGroupExpandButton {
                        id: expandButton
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        count: root.notificationCount
                        expanded: root.expanded
                        fontSize: topRow.fontSize
                        visible: root.multipleNotifications
                        onClicked: {
                            root.toggleExpanded();
                        }
                    }
                }

                ListView {
                    id: notificationsColumn
                    implicitHeight: contentHeight
                    Layout.fillWidth: true
                    spacing: root.expanded ? 16 : 0
                    interactive: false
                    cacheBuffer: 100
                    reuseItems: true

                    Behavior on spacing {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutCubic
                        }
                    }

                    model: expanded ? root.groupedNotifications : [
                        {
                            notifications: root.validNotifications,
                            isCompactGroup: true
                        }
                    ]

                    delegate: NotificationDelegate {
                        required property int index
                        required property var modelData
                        notifications: modelData.notifications || modelData
                        summary: modelData.summary || ""
                        expanded: root.expanded
                        onlyNotification: root.expanded ? (modelData.notifications ? modelData.notifications.length === 1 : modelData.length === 1) : false
                        appNameAlreadyShown: root.multipleNotifications
                        opacity: 1
                        visible: true
                        anchors.left: parent?.left
                        anchors.right: parent?.right

                        Component.onCompleted: {}

                        onDestroyRequested: {
                            // Destruir todo el grupo si es el único o si hay múltiples
                            root.destroyWithAnimation();
                        }
                    }
                }
            }
        }
    }
}
