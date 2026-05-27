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

    // Organic entry and displacement animations for notifications
    add: Transition {
        NumberAnimation {
            property: "opacity"
            from: 0; to: 1
            duration: Anim.emphasizedNormal
            easing.type: Anim.easing("decelerate").type
            easing.bezierCurve: Anim.easing("decelerate").bezierCurve
        }
        NumberAnimation {
            property: "scale"
            from: 0.92; to: 1
            duration: Anim.emphasizedNormal
            easing.type: Anim.springSnappy().type
            easing.bezierCurve: Anim.springSnappy().bezierCurve
        }
    }
    displaced: Transition {
        NumberAnimation {
            properties: "y"
            duration: Anim.standardNormal
            easing.type: Anim.springSnappy().type
            easing.bezierCurve: Anim.springSnappy().bezierCurve
        }
    }

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
