import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.modules.services
import "./NotificationDelegate.qml"

ListView {
    id: root
    property bool popup: false

    spacing: 8

    // Mostrar todas las notificaciones individuales en lugar de grupos
    model: root.popup ? Notifications.popupNotifications : Notifications.notifications

    delegate: NotificationDelegate {
        required property int index
        required property var modelData
        anchors.left: parent?.left
        anchors.right: parent?.right
        notificationObject: modelData
        expanded: true // Siempre expandidas para mostrar toda la información
        onlyNotification: true // Mostrar como notificación individual con header

        onDestroyRequested:
        // No necesitamos lógica especial aquí
        {}
    }
}
