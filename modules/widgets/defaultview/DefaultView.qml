import QtQuick
import Quickshell.Services.Mpris
import qs.modules.theme
import qs.modules.services
import qs.modules.notch
import qs.modules.components
import qs.config

Item {
    id: root
    anchors.top: parent.top
    focus: false

    // Layout constants
    readonly property int notificationPadding: 16
    readonly property int notificationPaddingBottom: Config.notchTheme === "island" ? 20 : 16
    readonly property int notificationPaddingTop: 8

    // State
    readonly property bool hasActiveNotifications: Notifications.popupList.length > 0
    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    property bool notchHovered: false
    property bool isNavigating: false

    HoverHandler {
        id: contentHoverHandler
    }

    readonly property bool expandedState: contentHoverHandler.hovered || notchHovered || isNavigating || Visibilities.playerMenuOpen

    property real mainRowMargin: (Config.notchTheme === "island" && hasActiveNotifications) ? 64 : 16

    Behavior on mainRowMargin {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutBack
            easing.overshoot: 1.2
        }
    }

    // Computed dimensions
    readonly property real mainRowContentWidth: 200 + userInfo.width + separator1.width + separator2.width + notifIndicator.width + (mainRow.spacing * 4) + mainRowMargin
    readonly property real mainRowHeight: Config.showBackground ? (Config.notchTheme === "island" ? 36 : 44) : (Config.notchTheme === "island" ? 36 : 40)
    readonly property real notificationMinWidth: expandedState ? 420 : 320
    readonly property real notificationContainerHeight: notificationView.implicitHeight + notificationPaddingTop + notificationPaddingBottom

    implicitWidth: Math.round(hasActiveNotifications ? Math.max(notificationMinWidth + (notificationPadding * 2), mainRowContentWidth) : mainRowContentWidth)

    implicitHeight: hasActiveNotifications ? mainRowHeight + notificationContainerHeight : mainRowHeight

    Behavior on implicitWidth {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutBack
            easing.overshoot: 1.2
        }
    }

    Keys.onPressed: event => {
        if (expandedState && activePlayer) {
            if (event.key === Qt.Key_Space) {
                activePlayer.togglePlaying();
                event.accepted = true;
            } else if (event.key === Qt.Key_Left && activePlayer.canSeek) {
                activePlayer.position = Math.max(0, activePlayer.position - 10);
                event.accepted = true;
            } else if (event.key === Qt.Key_Right && activePlayer.canSeek) {
                activePlayer.position = Math.min(activePlayer.length, activePlayer.position + 10);
                event.accepted = true;
            } else if (event.key === Qt.Key_Up && activePlayer.canGoPrevious) {
                activePlayer.previous();
                event.accepted = true;
            } else if (event.key === Qt.Key_Down && activePlayer.canGoNext) {
                activePlayer.next();
                event.accepted = true;
            }
        }
    }

    Column {
        anchors.fill: parent
        spacing: 0

        // mainRow container
        Row {
            id: mainRow
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - mainRowMargin
            height: mainRowHeight
            spacing: 4

            UserInfo {
                id: userInfo
                anchors.verticalCenter: parent.verticalCenter
            }

            Separator {
                id: separator1
                vert: true
                anchors.verticalCenter: parent.verticalCenter
            }

            CompactPlayer {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - userInfo.width - separator1.width - separator2.width - notifIndicator.width - (parent.spacing * 4)
                height: 32
                player: activePlayer
                notchHovered: expandedState
            }

            Separator {
                id: separator2
                vert: true
                anchors.verticalCenter: parent.verticalCenter
            }

            NotificationIndicator {
                id: notifIndicator
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Notification container with its own padding
        Item {
            id: notificationContainer
            width: parent.width
            height: hasActiveNotifications ? notificationContainerHeight : 0
            visible: hasActiveNotifications

            NotchNotificationView {
                id: notificationView
                anchors.fill: parent
                anchors.topMargin: notificationPaddingTop
                anchors.leftMargin: notificationPadding
                anchors.rightMargin: notificationPadding
                anchors.bottomMargin: notificationPaddingBottom
                visible: hasActiveNotifications
                opacity: visible ? 1 : 0
                notchHovered: expandedState
                onIsNavigatingChanged: root.isNavigating = isNavigating

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                }
            }
        }
    }
}
