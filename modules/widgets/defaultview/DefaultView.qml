import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.modules.theme
import qs.modules.services
import qs.modules.notch
import qs.modules.components
import qs.config

Item {
    id: root

    implicitWidth: Math.round(hasActiveNotifications ? (notificationHoverHandler.hovered ? 420 + 48 : 320 + 48) : (root.notchHovered ? 420 : 200 + userInfo.width + separator1.width + separator2.width + notifIndicator.width + (mainRow.spacing * 4) + 32))
    implicitHeight: mainRow.height + (hasActiveNotifications ? (notificationHoverHandler.hovered ? notificationView.implicitHeight + 32 : notificationView.implicitHeight + 16) : 0)

    Behavior on implicitHeight {
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutQuart
        }
    }

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutBack
            easing.overshoot: 1.2
        }
    }

    readonly property bool hasActiveNotifications: Notifications.popupList.length > 0
    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    property bool notchHovered: false

    HoverHandler {
        id: notificationHoverHandler
        enabled: hasActiveNotifications
    }

    Column {
        anchors.fill: parent
        spacing: hasActiveNotifications ? 4 : 0

        Behavior on spacing {
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutBack
                easing.overshoot: 1.2
            }
        }

        Row {
            id: mainRow
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 32
            spacing: 8

            UserInfo {
                id: userInfo
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                id: separator1
                anchors.verticalCenter: parent.verticalCenter
                text: "•"
                color: Colors.outline
                font.pixelSize: Config.theme.fontSize
                font.family: Config.theme.font
                font.bold: true
            }

            Item {
                id: compactPlayer
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - userInfo.width - separator1.width - separator2.width - notifIndicator.width - (parent.spacing * 4)
                height: 32

                property MprisPlayer player: activePlayer
                property bool isPlaying: player?.playbackState === MprisPlaybackState.Playing
                property real position: player?.position ?? 0.0
                property real length: player?.length ?? 1.0

                Timer {
                    running: compactPlayer.isPlaying
                    interval: 1000
                    repeat: true
                    onTriggered: compactPlayer.player?.positionChanged()
                }

                HoverHandler {
                    id: playerHover
                }

                ClippingRectangle {
                    anchors.fill: parent
                    radius: Math.max(0, Config.roundness - 4)
                    color: Colors.surface

                    Image {
                        id: backgroundArt
                        anchors.fill: parent
                        source: compactPlayer.player?.trackArtUrl ?? ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: false
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: backgroundArt
                        brightness: -0.25
                        contrast: -0.75
                        saturation: -0.5
                        blurEnabled: true
                        blurMax: 32
                        blur: 0.75
                        opacity: (compactPlayer.player?.trackArtUrl ?? "") !== "" ? 1.0 : 0.0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Config.animDuration
                                easing.type: Easing.OutQuart
                            }
                        }
                    }

                    Loader {
                        id: artworkLoader
                        anchors.left: parent.left
                        anchors.leftMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        active: (compactPlayer.player?.trackArtUrl ?? "") !== ""
                        width: (active && (playerHover.hovered || root.notchHovered)) ? 24 : 0
                        height: 24

                        Behavior on width {
                            NumberAnimation {
                                duration: Config.animDuration
                                easing.type: Easing.OutQuart
                            }
                        }

                        sourceComponent: ClippingRectangle {
                            width: 24
                            height: 24
                            radius: Math.max(0, Config.roundness - 8)
                            color: Colors.overPrimaryFixed

                            Image {
                                anchors.fill: parent
                                source: compactPlayer.player?.trackArtUrl ?? ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                        }
                    }

                    Row {
                        id: controlButtons
                        anchors.left: artworkLoader.right
                        anchors.leftMargin: (artworkLoader.active && (playerHover.hovered || root.notchHovered)) ? 8 : 4
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: (playerHover.hovered || root.notchHovered) ? 4 : 0

                        Behavior on anchors.leftMargin {
                            NumberAnimation {
                                duration: Config.animDuration
                                easing.type: Easing.OutQuart
                            }
                        }

                        Behavior on spacing {
                            NumberAnimation {
                                duration: Config.animDuration
                                easing.type: Easing.OutQuart
                            }
                        }

                        Text {
                            id: previousBtn
                            anchors.verticalCenter: parent.verticalCenter
                            text: Icons.previous
                            textFormat: Text.RichText
                            color: previousHover.hovered ? Colors.primaryFixed : Colors.whiteSource
                            font.pixelSize: 16
                            font.family: Icons.font
                            opacity: compactPlayer.player?.canGoPrevious ?? false ? 1.0 : 0.3
                            visible: opacity > 0
                            clip: true
                            scale: 1.0

                            readonly property real naturalWidth: implicitWidth
                            width: (playerHover.hovered || root.notchHovered) ? naturalWidth : 0

                            Behavior on width {
                                NumberAnimation {
                                    duration: Config.animDuration
                                    easing.type: Easing.OutQuart
                                }
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Config.animDuration
                                    easing.type: Easing.OutQuart
                                }
                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: Config.animDuration
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 1.5
                                }
                            }

                            HoverHandler {
                                id: previousHover
                                enabled: compactPlayer.player?.canGoPrevious ?? false
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: compactPlayer.player?.canGoPrevious ?? false ? Qt.PointingHandCursor : Qt.ArrowCursor
                                enabled: compactPlayer.player?.canGoPrevious ?? false
                                onClicked: {
                                    previousBtn.scale = 1.5;
                                    compactPlayer.player?.previous();
                                    previousScaleTimer.restart();
                                }
                            }

                            Timer {
                                id: previousScaleTimer
                                interval: 100
                                onTriggered: previousBtn.scale = 1.0
                            }
                        }

                        Text {
                            id: playPauseBtn
                            anchors.verticalCenter: parent.verticalCenter
                            text: compactPlayer.isPlaying ? Icons.pause : Icons.play
                            textFormat: Text.RichText
                            color: playPauseHover.hovered ? Colors.primaryFixed : Colors.whiteSource
                            font.pixelSize: 16
                            font.family: Icons.font
                            opacity: compactPlayer.player?.canPause ?? false ? 1.0 : 0.3
                            scale: 1.0

                            Behavior on color {
                                ColorAnimation {
                                    duration: Config.animDuration
                                    easing.type: Easing.OutQuart
                                }
                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: Config.animDuration
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 1.5
                                }
                            }

                            HoverHandler {
                                id: playPauseHover
                                enabled: compactPlayer.player !== null
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: compactPlayer.player ? Qt.PointingHandCursor : Qt.ArrowCursor
                                enabled: compactPlayer.player !== null
                                onClicked: {
                                    playPauseBtn.scale = 1.1;
                                    compactPlayer.player?.togglePlaying();
                                    playPauseScaleTimer.restart();
                                }
                            }

                            Timer {
                                id: playPauseScaleTimer
                                interval: 100
                                onTriggered: playPauseBtn.scale = 1.0
                            }
                        }

                        Text {
                            id: nextBtn
                            anchors.verticalCenter: parent.verticalCenter
                            text: Icons.next
                            textFormat: Text.RichText
                            color: nextHover.hovered ? Colors.primaryFixed : Colors.whiteSource
                            font.pixelSize: 16
                            font.family: Icons.font
                            opacity: compactPlayer.player?.canGoNext ?? false ? 1.0 : 0.3
                            visible: opacity > 0
                            clip: true
                            scale: 1.0

                            readonly property real naturalWidth: implicitWidth
                            width: (playerHover.hovered || root.notchHovered) ? naturalWidth : 0

                            Behavior on width {
                                NumberAnimation {
                                    duration: Config.animDuration
                                    easing.type: Easing.OutQuart
                                }
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Config.animDuration
                                    easing.type: Easing.OutQuart
                                }
                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: Config.animDuration
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 1.5
                                }
                            }

                            HoverHandler {
                                id: nextHover
                                enabled: compactPlayer.player?.canGoNext ?? false
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: compactPlayer.player?.canGoNext ?? false ? Qt.PointingHandCursor : Qt.ArrowCursor
                                enabled: compactPlayer.player?.canGoNext ?? false
                                onClicked: {
                                    nextBtn.scale = 1.1;
                                    compactPlayer.player?.next();
                                    nextScaleTimer.restart();
                                }
                            }

                            Timer {
                                id: nextScaleTimer
                                interval: 100
                                onTriggered: nextBtn.scale = 1.0
                            }
                        }
                    }

                    Item {
                        id: positionControl
                        anchors.left: controlButtons.right
                        anchors.right: playerIcon.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        height: 4

                        property bool isDragging: false
                        property real dragPosition: 0.0

                        property real progressRatio: isDragging ? dragPosition : (compactPlayer.length > 0 ? compactPlayer.position / compactPlayer.length : 0)

                        Rectangle {
                            anchors.right: parent.right
                            width: (1 - positionControl.progressRatio) * parent.width - 4
                            height: parent.height
                            radius: height / 2
                            color: Colors.shadow
                        }

                        Loader {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            active: compactPlayer.isPlaying
                            sourceComponent: WavyLine {
                                id: wavyFill
                                frequency: 8
                                color: Colors.primaryFixed
                                amplitudeMultiplier: 0.8
                                height: positionControl.height * 8
                                width: Math.max(0, positionControl.width * positionControl.progressRatio - 4)
                                lineWidth: positionControl.height
                                fullLength: positionControl.width

                                FrameAnimation {
                                    running: compactPlayer.isPlaying
                                    onTriggered: wavyFill.requestPaint()
                                }
                            }
                        }

                        Loader {
                            active: !compactPlayer.isPlaying
                            sourceComponent: Rectangle {
                                anchors.left: parent.left
                                width: Math.max(0, positionControl.width * positionControl.progressRatio - 4)
                                height: positionControl.height
                                radius: height / 2
                                color: Colors.primaryFixed
                            }
                        }

                        Rectangle {
                            id: dragHandle
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.max(0, Math.min(positionControl.width - width, positionControl.width * positionControl.progressRatio - width / 2))
                            width: positionControl.isDragging ? 4 : 4
                            height: positionControl.isDragging ? 20 : 16
                            radius: width / 2
                            color: Colors.whiteSource

                            Behavior on width {
                                NumberAnimation {
                                    duration: Config.animDuration
                                    easing.type: Easing.OutQuart
                                }
                            }

                            Behavior on height {
                                NumberAnimation {
                                    duration: Config.animDuration
                                    easing.type: Easing.OutQuart
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: compactPlayer.player?.canSeek ?? false ? Qt.PointingHandCursor : Qt.ArrowCursor
                            enabled: compactPlayer.player?.canSeek ?? false
                            onClicked: mouse => {
                                if (compactPlayer.player && compactPlayer.player.canSeek) {
                                    compactPlayer.player.position = (mouse.x / width) * compactPlayer.length;
                                }
                            }
                            onPressed: {
                                positionControl.isDragging = true;
                                positionControl.dragPosition = Math.min(Math.max(0, mouseX / width), 1);
                            }
                            onReleased: {
                                if (compactPlayer.player && compactPlayer.player.canSeek) {
                                    compactPlayer.player.position = positionControl.dragPosition * compactPlayer.length;
                                }
                                positionControl.isDragging = false;
                            }
                            onPositionChanged: {
                                if (positionControl.isDragging) {
                                    positionControl.dragPosition = Math.min(Math.max(0, mouseX / width), 1);
                                }
                            }
                        }
                    }

                    Text {
                        id: playerIcon
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            if (!compactPlayer.player)
                                return Icons.player;
                            const dbusName = (compactPlayer.player.dbusName || "").toLowerCase();
                            const desktopEntry = (compactPlayer.player.desktopEntry || "").toLowerCase();
                            const identity = (compactPlayer.player.identity || "").toLowerCase();

                            if (dbusName.includes("spotify") || desktopEntry.includes("spotify") || identity.includes("spotify"))
                                return Icons.spotify;
                            if (dbusName.includes("chromium") || dbusName.includes("chrome") || desktopEntry.includes("chromium") || desktopEntry.includes("chrome"))
                                return Icons.chromium;
                            if (dbusName.includes("firefox") || desktopEntry.includes("firefox"))
                                return Icons.firefox;
                            return Icons.player;
                        }
                        textFormat: Text.RichText
                        color: playerIconHover.hovered ? Colors.primaryFixed : Colors.whiteSource
                        font.pixelSize: 20
                        font.family: Icons.font
                        verticalAlignment: Text.AlignVCenter

                        Behavior on color {
                            ColorAnimation {
                                duration: Config.animDuration
                                easing.type: Easing.OutQuart
                            }
                        }

                        HoverHandler {
                            id: playerIconHover
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton

                            onClicked: mouse => {
                                if (mouse.button === Qt.LeftButton) {
                                    MprisController.cyclePlayer(1);
                                } else if (mouse.button === Qt.RightButton) {
                                    MprisController.cyclePlayer(-1);
                                }
                            }
                        }
                    }
                }
            }

            Text {
                id: separator2
                anchors.verticalCenter: parent.verticalCenter
                text: "•"
                color: Colors.outline
                font.pixelSize: Config.theme.fontSize
                font.family: Config.theme.font
                font.bold: true
            }

            NotificationIndicator {
                id: notifIndicator
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            height: hasActiveNotifications ? (notificationHoverHandler.hovered ? notificationView.implicitHeight + 32 : notificationView.implicitHeight + 16) : 0
            clip: false
            visible: height > 0

            Behavior on height {
                NumberAnimation {
                    duration: Config.animDuration
                    easing.type: Easing.OutQuart
                }
            }

            NotchNotificationView {
                id: notificationView
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: notificationHoverHandler.hovered ? 24 : 24
                anchors.rightMargin: notificationHoverHandler.hovered ? 24 : 24
                anchors.bottomMargin: 8
                opacity: hasActiveNotifications ? 1 : 0
                notchHovered: notificationHoverHandler.hovered

                Behavior on opacity {
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                }

                Behavior on anchors.leftMargin {
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                }

                Behavior on anchors.rightMargin {
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                }
            }
        }
    }
}
