import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config
import "./NotificationAnimation.qml"
import "./NotificationAppIcon.qml"
import "./NotificationDismissButton.qml"
import "./NotificationActionButtons.qml"
import "./notification_utils.js" as NotificationUtils

Item {
    id: root
    property var notificationObject: null
    property var notifications: []
    property string summary: ""
    property bool expanded: false
    property real fontSize: Config.theme.fontSize
    property real padding: onlyNotification || expanded ? 8 : 0
    property bool onlyNotification: false
    property bool appNameAlreadyShown: false

    // Computed properties
    property var sortedNotifications: notifications.slice().sort((a, b) => a.time - b.time) // antiguo a reciente
    property var latestNotification: sortedNotifications.length > 0 ? sortedNotifications[sortedNotifications.length - 1] : notificationObject
    property var earliestNotification: sortedNotifications.length > 0 ? sortedNotifications[0] : notificationObject
    property bool multipleNotifications: notifications.length > 1
    property bool isValid: latestNotification && (latestNotification.summary || latestNotification.body)

    signal destroyRequested

    implicitHeight: mainNotificationColumn.implicitHeight

    function destroyWithAnimation() {
        notificationAnimation.startDestroy();
    }

    NotificationAnimation {
        id: notificationAnimation
        targetItem: background
        dismissOvershoot: 20
        parentWidth: root.width

        onDestroyFinished: {
            if (root.notifications.length > 0) {
                // Discard multiple
                const ids = root.notifications.map(notif => notif.id);
                Notifications.discardNotifications(ids);
            } else if (root.notificationObject) {
                Notifications.discardNotification(root.notificationObject.id);
            }
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

    Column {
        id: mainNotificationColumn
        width: parent.width
        spacing: onlyNotification ? 8 : (expanded ? 8 : 0)

        Item {
            id: background
            width: parent.width
            property int criticalMargins: (onlyNotification || expanded) && latestNotification && latestNotification.urgency == NotificationUrgency.Critical ? 16 : 0
            implicitHeight: contentColumn.implicitHeight + (criticalMargins * 2)
            height: implicitHeight
            visible: root.isValid

            Behavior on height {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: 8
                color: "transparent"
            }

            DiagonalStripePattern {
                id: stripeContainer
                anchors.fill: parent
                visible: latestNotification && latestNotification.urgency == NotificationUrgency.Critical
                radius: Styling.radius(4)
                animationRunning: visible
            }

            ColumnLayout {
                id: contentColumn
                anchors.fill: parent
                anchors.topMargin: background.criticalMargins
                anchors.bottomMargin: background.criticalMargins
                anchors.leftMargin: background.criticalMargins > 0 ? 8 : 0
                anchors.rightMargin: background.criticalMargins > 0 ? 8 : 0
                spacing: onlyNotification || expanded ? 8 : 0

                // Individual notification layout (like expanded popup)
                RowLayout {
                    id: mainContentRow
                    Layout.fillWidth: true
                    implicitHeight: Math.max(onlyNotification ? 48 : 32, textColumn.implicitHeight)
                    height: implicitHeight
                    spacing: 8
                    visible: onlyNotification

                    // Contenido principal
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        // App icon
                        NotificationAppIcon {
                            id: appIcon
                            Layout.preferredWidth: onlyNotification ? 48 : 32
                            Layout.preferredHeight: onlyNotification ? 48 : 32
                            Layout.alignment: Qt.AlignTop
                            size: onlyNotification ? 48 : 32
                            radius: Styling.radius(4)
                            appName: latestNotification ? latestNotification.appName : ""
                            appIcon: latestNotification ? (latestNotification.cachedAppIcon || latestNotification.appIcon) : ""
                            image: latestNotification ? (latestNotification.cachedImage || latestNotification.image) : ""
                            summary: latestNotification ? latestNotification.summary : ""
                            urgency: latestNotification ? latestNotification.urgency : NotificationUrgency.Normal
                        }

                        // Textos de la notificación
                        Column {
                            id: textColumn
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: onlyNotification ? 4 : 0

                            // Fila del summary, app name y timestamp
                            RowLayout {
                                width: parent.width
                                spacing: 4

                                // Contenedor izquierdo para summary y app name
                                Row {
                                    id: leftTextsContainer
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    spacing: 4

                                    Text {
                                        id: summaryText
                                        property real combinedImplicitWidth: implicitWidth + (appNameText.visible ? appNameText.implicitWidth + parent.spacing : 0)
                                        width: {
                                            if (combinedImplicitWidth <= leftTextsContainer.width) {
                                                return implicitWidth;
                                            }
                                            return leftTextsContainer.width - (appNameText.visible ? appNameText.width + parent.spacing : 0);
                                        }
                                        text: latestNotification ? latestNotification.summary : ""
                                        font.family: Config.theme.font
                                        font.pixelSize: Config.theme.fontSize
                                        font.weight: Font.Bold
                                        font.underline: latestNotification && latestNotification.urgency == NotificationUrgency.Critical && onlyNotification
                                        color: latestNotification && latestNotification.urgency == NotificationUrgency.Critical ? Colors.criticalText : Styling.srItem("overprimary")
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                        wrapMode: Text.NoWrap
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    Text {
                                        id: appNameText
                                        property real availableWidth: leftTextsContainer.width - summaryText.implicitWidth - (visible ? parent.spacing : 0)
                                        width: {
                                            if (summaryText.combinedImplicitWidth <= leftTextsContainer.width) {
                                                return implicitWidth;
                                            }
                                            return Math.min(implicitWidth, Math.max(60, availableWidth, leftTextsContainer.width * 0.3));
                                        }
                                        text: latestNotification ? "• " + latestNotification.appName : ""
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-2)
                                        font.weight: Font.Bold
                                        color: latestNotification && latestNotification.urgency == NotificationUrgency.Critical ? Colors.criticalText : Colors.outline
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                        wrapMode: Text.NoWrap
                                        verticalAlignment: Text.AlignVCenter
                                        visible: text !== "" && !root.appNameAlreadyShown
                                    }
                                }

                                // Timestamp a la derecha
                                Text {
                                    id: timestampText
                                    text: latestNotification ? NotificationUtils.getFriendlyNotifTimeString(latestNotification.time) : ""
                                    font.family: Config.theme.font
                                    font.pixelSize: Config.theme.fontSize
                                    font.weight: Font.Bold
                                    color: latestNotification && latestNotification.urgency == NotificationUrgency.Critical ? Colors.criticalText : Colors.outline
                                    verticalAlignment: Text.AlignVCenter
                                    visible: text !== ""
                                    Layout.alignment: Qt.AlignVCenter
                                }
                            }

                            Text {
                                width: parent.width
                                text: latestNotification ? NotificationUtils.processNotificationBody(latestNotification.body, latestNotification.appName) : ""
                                font.family: Config.theme.font
                                font.pixelSize: Config.theme.fontSize
                                font.weight: latestNotification && latestNotification.urgency == NotificationUrgency.Critical ? Font.Bold : Font.Normal
                                color: latestNotification && latestNotification.urgency == NotificationUrgency.Critical ? Colors.criticalText : Colors.overBackground
                                wrapMode: onlyNotification ? Text.Wrap : Text.NoWrap
                                maximumLineCount: onlyNotification ? 3 : 1
                                elide: Text.ElideRight
                                visible: onlyNotification || text !== ""
                            }
                        }
                    }

                    // Botón de descartar
                    Item {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        Layout.alignment: Qt.AlignTop

                        NotificationDismissButton {
                            visibleWhen: onlyNotification
                            urgency: latestNotification ? latestNotification.urgency : NotificationUrgency.Normal
                            onClicked: root.destroyWithAnimation()
                        }
                    }
                }

                // Grouped notification layout (original)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: !onlyNotification

                    // Contenido principal
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        NotificationAppIcon {
                            id: groupedAppIcon
                            Layout.preferredWidth: expanded ? 48 : 32
                            Layout.preferredHeight: expanded ? 48 : 32
                            Layout.alignment: Qt.AlignTop
                            size: expanded ? 48 : 32
                            radius: Styling.radius(4)
                            appName: latestNotification ? latestNotification.appName : ""
                            appIcon: latestNotification ? (latestNotification.cachedAppIcon || latestNotification.appIcon) : ""
                            image: latestNotification ? (latestNotification.cachedImage || latestNotification.image) : ""
                            summary: latestNotification ? latestNotification.summary : ""
                            urgency: latestNotification ? latestNotification.urgency : NotificationUrgency.Normal
                        }

                        Item {
                            Layout.fillWidth: true
                            implicitHeight: expanded ? columnLayout.implicitHeight : rowLayout.implicitHeight

                            RowLayout {
                                id: columnLayout
                                width: parent.width
                                spacing: 8
                                visible: expanded

                                Column {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    // Fila del summary y timestamp
                                    RowLayout {
                                        width: parent.width
                                        spacing: 4

                                        Text {
                                            Layout.maximumWidth: parent.width * 0.7
                                            text: root.summary || (latestNotification ? latestNotification.summary : "")
                                            font.family: Config.theme.font
                                            font.pixelSize: Config.theme.fontSize
                                            font.weight: Font.Bold
                                            font.underline: latestNotification && latestNotification.urgency == NotificationUrgency.Critical && expanded
                                            color: latestNotification && latestNotification.urgency == NotificationUrgency.Critical ? Colors.criticalText : Styling.srItem("overprimary")
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            text: latestNotification ? NotificationUtils.getFriendlyNotifTimeString(latestNotification.time) : ""
                                            font.family: Config.theme.font
                                            font.pixelSize: Config.theme.fontSize
                                            font.weight: Font.Bold
                                            color: latestNotification && latestNotification.urgency == NotificationUrgency.Critical ? Colors.criticalText : Colors.outline
                                            visible: text !== ""
                                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                        }
                                    }

                                    // Mostrar todos los body ordenados antiguo a reciente con spacing 4
                                    Column {
                                        width: parent.width
                                        spacing: 4

                                        Repeater {
                                            model: root.sortedNotifications

                                            Text {
                                                width: parent.width
                                                text: NotificationUtils.processNotificationBody(modelData.body || "", modelData.appName)
                                                font.family: Config.theme.font
                                                font.pixelSize: root.fontSize
                                                font.weight: modelData.urgency == NotificationUrgency.Critical ? Font.Bold : Font.Normal
                                                color: modelData.urgency == NotificationUrgency.Critical ? Colors.criticalText : Colors.overBackground
                                                wrapMode: Text.Wrap
                                                maximumLineCount: 3
                                                elide: Text.ElideRight
                                                visible: text.length > 0
                                            }
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                id: rowLayout
                                width: parent.width
                                spacing: 4
                                visible: !expanded

                                Text {
                                    Layout.maximumWidth: parent.width * 0.4
                                    text: root.summary || (latestNotification ? latestNotification.summary : "")
                                    font.family: Config.theme.font
                                    font.pixelSize: Config.theme.fontSize
                                    font.weight: Font.Bold
                                    color: latestNotification && latestNotification.urgency == NotificationUrgency.Critical ? Colors.criticalText : Styling.srItem("overprimary")
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: "•"
                                    font.family: Config.theme.font
                                    font.pixelSize: Config.theme.fontSize
                                    font.weight: Font.Bold
                                    color: latestNotification && latestNotification.urgency == NotificationUrgency.Critical ? Colors.criticalText : Colors.outline
                                    visible: latestNotification && latestNotification.body && latestNotification.body.length > 0
                                }

                                Text {
                                    text: latestNotification ? NotificationUtils.processNotificationBody(latestNotification.body || "").replace(/\n/g, ' ') : ""
                                    font.family: Config.theme.font
                                    font.pixelSize: root.fontSize
                                    font.weight: latestNotification && latestNotification.urgency == NotificationUrgency.Critical ? Font.Bold : Font.Normal
                                    color: latestNotification && latestNotification.urgency == NotificationUrgency.Critical ? Colors.criticalText : Colors.overBackground
                                    wrapMode: Text.NoWrap
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    visible: text.length > 0
                                }
                            }
                        }
                    }

                    // Botón de descartar
                    Item {
                        Layout.preferredWidth: expanded ? 24 : 0
                        Layout.minimumWidth: 0
                        Layout.preferredHeight: 24
                        Layout.alignment: Qt.AlignTop

                        NotificationDismissButton {
                            visibleWhen: expanded
                            urgency: latestNotification ? latestNotification.urgency : NotificationUrgency.Normal
                            onClicked: root.destroyWithAnimation()
                        }
                    }
                }
            }
        }

        // Botones de acción (para notificaciones individuales o expandidas)
        Item {
            id: actionButtonsContainer
            width: parent.width
            implicitHeight: (onlyNotification || expanded) && latestNotification && latestNotification.actions.length > 0 && !latestNotification.isCached ? 32 : 0
            height: implicitHeight
            clip: true

            RowLayout {
                anchors.fill: parent
                spacing: 4

                Repeater {
                    model: latestNotification && latestNotification.actions ? latestNotification.actions : []

                    Button {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32

                        text: modelData.text
                        font.family: Config.theme.font
                        font.pixelSize: Config.theme.fontSize
                        font.weight: Font.Bold
                        hoverEnabled: true

                        background: Item {
                            id: delegateBtnBg
                            property bool isCritical: latestNotification && latestNotification.urgency == NotificationUrgency.Critical
                            property color textColor: isCritical ? Colors.shadow : styledBg.item

                            Rectangle {
                                anchors.fill: parent
                                visible: parent.isCritical
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
                                visible: !parent.isCritical
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
                        }

                        onClicked: {
                            if (latestNotification) {
                                Notifications.attemptInvokeAction(latestNotification.id, modelData.identifier, false);
                                root.destroyRequested();
                            }
                        }
                    }
                }
            }
        }
    }
}
