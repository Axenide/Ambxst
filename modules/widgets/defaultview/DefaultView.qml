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
    readonly property var activePlayer: MprisController.activePlayer
    property bool notchHovered: false
    property bool isNavigating: false

    // Position detection
    readonly property string notchPosition: Config.notchPosition ?? "top"
    readonly property bool isBottom: notchPosition === "bottom"

    MouseArea {
        id: interactiveArea
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        
        onWheel: (wheel) => {
            console.log("[DefaultView] MouseArea wheel event. delta:", wheel.angleDelta.y, "x:", wheel.x, "root.width:", root.width);
            var delta = wheel.angleDelta.y;
            if (delta === 0) return;
            
            var isUp = delta > 0;
            var step = 0.01;

            // Left half: Brightness
            if (wheel.x < width / 2) {
                 console.log("[DefaultView] MouseArea Brightness");
                var win = Window.window;
                // Try to find monitor for this screen
                var monitor = Brightness.getMonitorForScreen(win.screen);
                
                // If not found, just use the first available monitor (common case for single screen or main screen)
                if (!monitor && Brightness.monitors.length > 0) {
                     monitor = Brightness.monitors[0];
                }

                if (monitor) {
                    var newBrightness = isUp 
                        ? Math.min(1.0, monitor.brightness + step)
                        : Math.max(0.01, monitor.brightness - step);
                    monitor.setBrightness(newBrightness);
                } else {
                    console.log("[DefaultView] Monitor not found");
                }
            } 
            // Right half: Volume
            else {
                 console.log("[DefaultView] MouseArea Volume");
                var newVolume = isUp 
                    ? Math.min(Audio.hardMaxValue, Audio.value + step)
                    : Math.max(0.0, Audio.value - step);
                Audio.setVolume(newVolume);
            }
        }
    }

    readonly property bool expandedState: interactiveArea.containsMouse || notchHovered || isNavigating || Visibilities.playerMenuOpen

    property real mainRowMargin: 16

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

        // If bottom position, we populate content bottom-up.
        // But Column fills top-down. 
        // We can move the mainRow to the bottom of this Column or use a different layout strategy.
        // Easiest is to reverse the visual order by using move property or just conditionally rendering order? 
        // QML items can be reordered visually? No.
        // We can use States or just conditional anchoring if not using Column.
        // But this uses Column.

        // Reorder children based on position:
        // Top: mainRow then notificationContainer
        // Bottom: notificationContainer then mainRow
        
        // Since we cannot dynamically reorder children in a Column easily without Repeater/Loader tricks,
        // we can use Item + Anchors instead of Column for full control.
        
    }

    Item {
        anchors.fill: parent

        // mainRow container
        Row {
            id: mainRow
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: isBottom ? undefined : parent.top
            anchors.bottom: isBottom ? parent.bottom : undefined
            width: parent.width - mainRowMargin
            height: mainRowHeight
            spacing: 4
            z: 2 // Ensure it stays above notifications if overlap occurs (though they shouldn't)

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
            
            // Position relative to mainRow
            anchors.top: isBottom ? undefined : mainRow.bottom
            anchors.bottom: isBottom ? mainRow.top : undefined
            
            NotchNotificationView {
                id: notificationView
                anchors.fill: parent
                // Invert padding based on position? Or keep as is?
                // If bottom, "top" margin is visually the one close to mainRow?
                // Let's keep padding consistent for now, but ensure proper spacing.
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
