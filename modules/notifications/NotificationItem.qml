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

    function processNotificationBody(body, appName) {
        if (!body)
            return "";

        let processedBody = body;

        // Limpiar notificaciones de navegadores basados en Chromium
        if (appName) {
            const lowerApp = appName.toLowerCase();
            const chromiumBrowsers = ["brave", "chrome", "chromium", "vivaldi", "opera", "microsoft edge"];

            if (chromiumBrowsers.some(name => lowerApp.includes(name))) {
                const lines = body.split('\n\n');

                if (lines.length > 1 && lines[0].startsWith('<a')) {
                    processedBody = lines.slice(1).join('\n\n');
                }
            }
        }

        // No reemplazar saltos de línea con espacios
        return processedBody;
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
            width: parent.width
            anchors.fill: parent
            anchors.margins: root.padding
            spacing: onlyNotification ? 8 : (expanded ? 8 : 4)

            // Individual notification layout (like expanded popup)
            RowLayout {
                id: mainContentRow
                Layout.fillWidth: true
                implicitHeight: Math.max(onlyNotification ? 48 : 32, textColumn.implicitHeight)
                height: implicitHeight
                spacing: 8
                visible: onlyNotification

                // App icon
                NotificationAppIcon {
                    id: appIcon
                    Layout.preferredWidth: onlyNotification ? 48 : 32
                    Layout.preferredHeight: onlyNotification ? 48 : 32
                    Layout.alignment: Qt.AlignTop
                    size: onlyNotification ? 48 : 32
                    radius: Config.roundness > 0 ? Config.roundness + 4 : 0
                    visible: notificationObject && (notificationObject.appIcon !== "" || notificationObject.image !== "")
                    appIcon: notificationObject ? notificationObject.appIcon : ""
                    image: notificationObject ? notificationObject.image : ""
                    summary: notificationObject ? notificationObject.summary : ""
                    urgency: notificationObject ? notificationObject.urgency : NotificationUrgency.Normal
                }

                // Textos de la notificación
                Column {
                    id: textColumn
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: onlyNotification ? 4 : 0

                    // Fila del summary, app name y timestamp
                    Row {
                        width: parent.width
                        spacing: 4

                        // Contenedor izquierdo para summary y app name
                        Row {
                            width: parent.width - timestampText.width - parent.spacing
                            spacing: 4

                            Text {
                                id: summaryText
                                width: Math.min(implicitWidth, parent.width - (appNameText.visible ? appNameText.width + parent.spacing : 0))
                                text: notificationObject ? notificationObject.summary : ""
                                font.family: Config.theme.font
                                font.pixelSize: Config.theme.fontSize
                                font.weight: Font.Bold
                                color: Colors.adapter.primary
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                wrapMode: Text.NoWrap
                                verticalAlignment: Text.AlignVCenter
                            }

                            Text {
                                id: appNameText
                                width: Math.min(implicitWidth, Math.max(60, parent.width * 0.3))
                                text: notificationObject ? "• " + notificationObject.appName : ""
                                font.family: Config.theme.font
                                font.pixelSize: Config.theme.fontSize
                                font.weight: Font.Bold
                                color: Colors.adapter.outline
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                wrapMode: Text.NoWrap
                                verticalAlignment: Text.AlignVCenter
                                visible: text !== ""
                            }
                        }

                        // Timestamp a la derecha
                        Text {
                            id: timestampText
                            text: notificationObject ? NotificationUtils.getFriendlyNotifTimeString(notificationObject.time) : ""
                            font.family: Config.theme.font
                            font.pixelSize: Config.theme.fontSize
                            font.weight: Font.Bold
                            color: Colors.adapter.outline
                            verticalAlignment: Text.AlignVCenter
                            visible: text !== ""
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Text {
                        width: parent.width
                        text: notificationObject ? processNotificationBody(notificationObject.body, notificationObject.appName) : ""
                        font.family: Config.theme.font
                        font.pixelSize: Config.theme.fontSize
                        font.weight: Font.Bold
                        color: Colors.adapter.overBackground
                        wrapMode: onlyNotification ? Text.Wrap : Text.NoWrap
                        maximumLineCount: onlyNotification ? 3 : 1
                        elide: Text.ElideRight
                        visible: onlyNotification || text !== ""
                    }
                }

                // Columna de botones (solo visible con hover o expanded)
                Column {
                    Layout.preferredWidth: onlyNotification ? 32 : 0
                    Layout.alignment: Qt.AlignTop
                    spacing: 4
                    visible: onlyNotification
                    clip: true

                    // Botón de descartar
                    Button {
                        width: 32
                        height: 32
                        hoverEnabled: true

                        background: Rectangle {
                            color: parent.pressed ? Colors.adapter.error : (parent.hovered ? Colors.surfaceBright : Colors.surface)
                            radius: Config.roundness > 0 ? Config.roundness + 4 : 0

                            Behavior on color {
                                ColorAnimation {
                                    duration: Config.animDuration
                                }
                            }
                        }

                        contentItem: Text {
                            text: Icons.cancel
                            font.family: Icons.font
                            font.pixelSize: 16
                            color: parent.pressed ? Colors.adapter.overError : (parent.hovered ? Colors.adapter.overBackground : Colors.adapter.error)
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter

                            Behavior on color {
                                ColorAnimation {
                                    duration: Config.animDuration
                                }
                            }
                        }

                        onClicked: {
                            if (notificationObject) {
                                Notifications.discardNotification(notificationObject.id);
                            }
                        }
                    }
                }
            }

            // Grouped notification layout (original)
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: !onlyNotification

                NotificationAppIcon {
                    id: groupedAppIcon
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

            // Botones de acción (para notificaciones individuales o expandidas)
            Item {
                id: actionButtonsRow
                Layout.fillWidth: true
                implicitHeight: ((onlyNotification || expanded) && notificationObject && notificationObject.actions.length > 0) ? 32 : 0
                height: implicitHeight
                clip: true

                RowLayout {
                    anchors.fill: parent
                    spacing: 4

                    Repeater {
                        model: notificationObject ? notificationObject.actions : []

                        Button {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32

                            text: modelData.text
                            font.family: Config.theme.font
                            font.pixelSize: Config.theme.fontSize
                            font.weight: Font.Bold
                            hoverEnabled: true

                            background: Rectangle {
                                color: parent.pressed ? Colors.adapter.primary : (parent.hovered ? Colors.surfaceBright : Colors.surface)
                                radius: Config.roundness > 0 ? Config.roundness + 4 : 0

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Config.animDuration
                                    }
                                }
                            }

                            contentItem: Text {
                                text: parent.text
                                font: parent.font
                                color: parent.pressed ? Colors.adapter.overPrimary : (parent.hovered ? Colors.adapter.primary : Colors.adapter.overBackground)
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Config.animDuration
                                    }
                                }
                            }

                            onClicked: {
                                Notifications.attemptInvokeAction(notificationObject.id, modelData.identifier);
                            }
                        }
                    }
                }
            }
        }
    }
}
