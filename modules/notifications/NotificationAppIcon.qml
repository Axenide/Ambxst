import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs.modules.theme
import qs.modules.services
import qs.config

Item {
    id: root
    property var appIcon: ""
    property string appName: ""
    property var summary: ""
    property var urgency: NotificationUrgency.Normal
    property var image: ""
    property real scale: 1
    property real size: 48 * scale
    property real appIconScale: scale
    property real smallAppIconScale: 0.4
    property real appIconSize: size * appIconScale
    property real smallAppIconSize: size * smallAppIconScale
    // Image first, then app icon (or the icon of the app's desktop entry), then Icons.bell.
    property bool imageFailed: false
    onImageChanged: imageFailed = false
    readonly property string imageSource: imageFailed ? "" : Notifications.iconSource(image)
    readonly property string appIconSource: Notifications.iconSource(appIcon) || Notifications.iconSource(DesktopEntries.heuristicLookup(appName)?.icon ?? "")
    readonly property string mainSource: imageSource || appIconSource

    implicitWidth: size
    implicitHeight: size
    property real radius: Styling.radius(-8)

    // Contenedor principal con recorte (Clipping)
    ClippingRectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color: root.urgency == NotificationUrgency.Critical ? Colors.shadow : Colors.surfaceBright
            border.width: root.urgency == NotificationUrgency.Critical ? 2 : 0
            border.color: root.urgency == NotificationUrgency.Critical ? Colors.criticalRed : "transparent"
            radius: root.radius
            visible: root.mainSource == "" || mainImage.status === Image.Error

            Text {
                anchors.centerIn: parent
                text: {
                    if (root.urgency == NotificationUrgency.Critical) return Icons.alert;
                    if (root.appName === "Pomodoro") return Icons.timer;
                    return Icons.bell;
                }
                font.family: Icons.font
                font.pixelSize: root.size * 0.5
                color: root.urgency == NotificationUrgency.Critical ? Colors.criticalText : Styling.srItem("overprimary")

                SequentialAnimation on opacity {
                    running: root.urgency == NotificationUrgency.Critical
                    loops: Animation.Infinite
                    NumberAnimation {
                        from: 1.0
                        to: 0.5
                        duration: 800
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        from: 0.5
                        to: 1.0
                        duration: 800
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }

        Image {
            id: mainImage
            mipmap: true
            anchors.fill: parent
            source: root.mainSource
            visible: status !== Image.Error
            fillMode: Image.PreserveAspectCrop
            smooth: true
            onStatusChanged: {
                if (status === Image.Error && root.imageSource !== "")
                    root.imageFailed = true;
            }
        }
    }

    // App icon pequeño superpuesto si hay imagen
    Loader {
        id: notifImageAppIconLoader
        active: root.imageSource != "" && root.appIconSource != ""
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: root.smallAppIconSize
        height: root.smallAppIconSize
        sourceComponent: Rectangle {
            color: "transparent"
            Image {
                mipmap: true
                anchors.fill: parent
                source: root.appIconSource
                fillMode: Image.PreserveAspectCrop
                smooth: true
            }
        }
    }
}
