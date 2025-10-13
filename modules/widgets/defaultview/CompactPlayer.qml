import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config

Item {
    id: compactPlayer

    required property MprisPlayer player
    required property bool notchHovered

    property bool isPlaying: player?.playbackState === MprisPlaybackState.Playing
    property real position: player?.position ?? 0.0
    property real length: player?.length ?? 1.0
    property bool hasArtwork: (player?.trackArtUrl ?? "") !== ""
    property var playerColors: hasArtwork ? PlayerColors.getColorsForPlayer(player) : null

    Timer {
        running: compactPlayer.isPlaying
        interval: 1000
        repeat: true
        onTriggered: {
            if (!positionSlider.isDragging) {
                positionSlider.value = compactPlayer.length > 0 ? Math.min(1.0, compactPlayer.position / compactPlayer.length) : 0;
            }
            compactPlayer.player?.positionChanged();
        }
    }

    ClippingRectangle {
        anchors.fill: parent
        radius: Config.roundness > 0 ? Math.max(Config.roundness - 4, 0) : 0
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

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: (compactPlayer.player !== null || compactPlayer.notchHovered) ? 4 : 0
            anchors.rightMargin: (compactPlayer.player !== null || compactPlayer.notchHovered) ? 4 : 0
            spacing: (compactPlayer.player !== null && compactPlayer.notchHovered) ? 4 : 0
            layer.enabled: true
            layer.effect: BgShadow {}

            Behavior on spacing {
                NumberAnimation {
                    duration: Config.animDuration
                    easing.type: Easing.OutQuart
                }
            }

            Item {
                id: artworkContainer
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                visible: compactPlayer.player !== null

                ClippingRectangle {
                    anchors.fill: parent
                    radius: compactPlayer.isPlaying ? (Config.roundness > 0 ? Math.max(Config.roundness - 8, 0) : 0) : (Config.roundness > 0 ? Math.max(Config.roundness - 4, 0) : 0)
                    color: "transparent"

                    Behavior on radius {
                        NumberAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.5
                        }
                    }

                    Image {
                        id: artworkImage
                        anchors.fill: parent
                        source: compactPlayer.player?.trackArtUrl ?? ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: false
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: artworkImage
                        brightness: -0.15
                        contrast: -0.5
                        saturation: -0.25
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

                    Text {
                        id: playPauseBtn
                        anchors.centerIn: parent
                        text: compactPlayer.isPlaying ? Icons.pause : Icons.play
                        textFormat: Text.RichText
                        color: playPauseHover.hovered ? (compactPlayer.hasArtwork && compactPlayer.playerColors ? compactPlayer.playerColors.primary : Colors.primaryFixed) : (compactPlayer.hasArtwork && compactPlayer.playerColors ? compactPlayer.playerColors.overBackground : Colors.whiteSource)
                        font.pixelSize: 16
                        font.family: Icons.font
                        opacity: compactPlayer.player?.canPause ?? false ? 1.0 : 0.3
                        scale: 1.0
                        layer.enabled: true
                        layer.effect: BgShadow {}

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
                }
            }

            Text {
                id: previousBtn
                text: Icons.previous
                textFormat: Text.RichText
                color: previousHover.hovered ? (compactPlayer.hasArtwork && compactPlayer.playerColors ? compactPlayer.playerColors.primary : Colors.primaryFixed) : (compactPlayer.hasArtwork && compactPlayer.playerColors ? compactPlayer.playerColors.overBackground : Colors.whiteSource)
                font.pixelSize: 16
                font.family: Icons.font
                opacity: compactPlayer.player?.canGoPrevious ?? false ? 1.0 : 0.3
                visible: compactPlayer.player !== null && compactPlayer.notchHovered && opacity > 0
                clip: true
                scale: 1.0

                readonly property real naturalWidth: implicitWidth
                Layout.preferredWidth: (compactPlayer.player !== null && compactPlayer.notchHovered) ? naturalWidth : 0

                Behavior on Layout.preferredWidth {
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

             StyledSlider {
                 id: positionSlider
                 Layout.fillWidth: true
                 Layout.preferredHeight: 4
                 Layout.leftMargin: compactPlayer.notchHovered ? 0 : 8
                 Layout.rightMargin: compactPlayer.notchHovered ? 0 : 8
                 visible: compactPlayer.player !== null

                  value: compactPlayer.length > 0 ? Math.min(1.0, compactPlayer.position / compactPlayer.length) : 0
                  progressColor: compactPlayer.hasArtwork && compactPlayer.playerColors ? compactPlayer.playerColors.primary : Colors.primaryFixed
                  backgroundColor: compactPlayer.hasArtwork && compactPlayer.playerColors ? compactPlayer.playerColors.shadow : Colors.shadow
                  wavy: compactPlayer.isPlaying
                  wavyAmplitude: compactPlayer.isPlaying ? 0.5 : 0.0
                  wavyFrequency: compactPlayer.isPlaying ? 4 : 0
                  heightMultiplier: compactPlayer.player ? 8 : 4
                  resizeAnim: false
                  scroll: false
                  tooltip: false

                 onValueChanged: {
                     if (isDragging && compactPlayer.player && compactPlayer.player.canSeek) {
                         compactPlayer.player.position = value * compactPlayer.length;
                     }
                 }
             }

              WavyLine {
                  Layout.fillWidth: true
                  Layout.preferredHeight: 16
                  Layout.leftMargin: 4
                  Layout.rightMargin: 4
                  visible: compactPlayer.player === null
                  frequency: 2
                  color: Colors.outline
                  amplitudeMultiplier: 1
                  height: 16
                  lineWidth: 4
                  fullLength: width
                  opacity: 1.0
              }

            Text {
                id: nextBtn
                text: Icons.next
                textFormat: Text.RichText
                color: nextHover.hovered ? (compactPlayer.hasArtwork && compactPlayer.playerColors ? compactPlayer.playerColors.primary : Colors.primaryFixed) : (compactPlayer.hasArtwork && compactPlayer.playerColors ? compactPlayer.playerColors.overBackground : Colors.whiteSource)
                font.pixelSize: 16
                font.family: Icons.font
                opacity: compactPlayer.player?.canGoNext ?? false ? 1.0 : 0.3
                visible: compactPlayer.player !== null && opacity > 0
                clip: true
                scale: 1.0

                readonly property real naturalWidth: implicitWidth
                Layout.preferredWidth: (compactPlayer.player !== null && compactPlayer.notchHovered) ? naturalWidth : 0

                Behavior on Layout.preferredWidth {
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

            Text {
                id: modeBtn
                text: {
                    if (MprisController.hasShuffle)
                        return Icons.shuffle;
                    switch (MprisController.loopState) {
                    case MprisLoopState.Track:
                        return Icons.repeatOnce;
                    case MprisLoopState.Playlist:
                        return Icons.repeat;
                    default:
                        return Icons.shuffle;
                    }
                }
                textFormat: Text.RichText
                color: modeHover.hovered ? (compactPlayer.hasArtwork && compactPlayer.playerColors ? compactPlayer.playerColors.primary : Colors.primaryFixed) : (compactPlayer.hasArtwork && compactPlayer.playerColors ? compactPlayer.playerColors.overBackground : Colors.whiteSource)
                font.pixelSize: 16
                font.family: Icons.font
                opacity: {
                    if (!(MprisController.shuffleSupported || MprisController.loopSupported))
                        return 0.3;
                    if (!MprisController.hasShuffle && MprisController.loopState === MprisLoopState.None)
                        return 0.3;
                    return 1.0;
                }
                visible: compactPlayer.player !== null
                clip: true
                scale: 1.0

                readonly property real naturalWidth: implicitWidth
                Layout.preferredWidth: (compactPlayer.player !== null && compactPlayer.notchHovered) ? naturalWidth : 0

                Behavior on Layout.preferredWidth {
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
                    id: modeHover
                    enabled: MprisController.shuffleSupported || MprisController.loopSupported
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    enabled: MprisController.shuffleSupported || MprisController.loopSupported
                    onClicked: {
                        modeBtn.scale = 1.1;
                        if (MprisController.hasShuffle) {
                            MprisController.setShuffle(false);
                            MprisController.setLoopState(MprisLoopState.Playlist);
                        } else if (MprisController.loopState === MprisLoopState.Playlist) {
                            MprisController.setLoopState(MprisLoopState.Track);
                        } else if (MprisController.loopState === MprisLoopState.Track) {
                            MprisController.setLoopState(MprisLoopState.None);
                        } else {
                            MprisController.setShuffle(true);
                        }
                        modeScaleTimer.restart();
                    }
                }

                Timer {
                    id: modeScaleTimer
                    interval: 100
                    onTriggered: modeBtn.scale = 1.0
                }
            }

            Text {
                id: playerIcon
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
                    if (dbusName.includes("telegram") || desktopEntry.includes("telegram") || identity.includes("telegram"))
                        return Icons.telegram;
                    return Icons.player;
                }
                textFormat: Text.RichText
                color: playerIconHover.hovered ? (compactPlayer.hasArtwork && compactPlayer.playerColors ? compactPlayer.playerColors.primary : Colors.primaryFixed) : (compactPlayer.hasArtwork && compactPlayer.playerColors ? compactPlayer.playerColors.overBackground : Colors.whiteSource)
                font.pixelSize: 20
                font.family: Icons.font
                verticalAlignment: Text.AlignVCenter
                visible: compactPlayer.player !== null

                Layout.preferredWidth: compactPlayer.player !== null ? implicitWidth : 0
                Layout.rightMargin: compactPlayer.player !== null ? 4 : 0

                Behavior on Layout.preferredWidth {
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                }

                Behavior on Layout.rightMargin {
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

                HoverHandler {
                    id: playerIconHover
                }

                function getPlayerIcon(player) {
                    if (!player)
                        return Icons.player;
                    const dbusName = (player.dbusName || "").toLowerCase();
                    const desktopEntry = (player.desktopEntry || "").toLowerCase();
                    const identity = (player.identity || "").toLowerCase();

                    if (dbusName.includes("spotify") || desktopEntry.includes("spotify") || identity.includes("spotify"))
                        return Icons.spotify;
                    if (dbusName.includes("chromium") || dbusName.includes("chrome") || desktopEntry.includes("chromium") || desktopEntry.includes("chrome"))
                        return Icons.chromium;
                    if (dbusName.includes("firefox") || desktopEntry.includes("firefox"))
                        return Icons.firefox;
                    if (dbusName.includes("telegram") || desktopEntry.includes("telegram") || identity.includes("telegram"))
                        return Icons.telegram;
                    return Icons.player;
                }

                function buildMenuItems() {
                    const players = MprisController.filteredPlayers;
                    const menuItems = [];

                    for (let i = 0; i < players.length; i++) {
                        const player = players[i];
                        const isActive = player === MprisController.activePlayer;
                        const playerColors = PlayerColors.getColorsForPlayer(player);

                        menuItems.push({
                            text: player.trackTitle || player.identity || "Unknown Player",
                            icon: getPlayerIcon(player),
                            highlightColor: playerColors.primary,
                            textColor: playerColors.overPrimary,
                            onTriggered: () => {
                                MprisController.setActivePlayer(player);
                            }
                        });
                    }

                    return menuItems;
                }

                Timer {
                    id: pressAndHoldTimer
                    interval: 1000
                    repeat: false
                    onTriggered: {
                        const items = playerIcon.buildMenuItems();
                        if (items.length > 0) {
                            Visibilities.contextMenu.openCustomMenu(items, 200, 36, "player");
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    onPressed: mouse => {
                        if (mouse.button === Qt.LeftButton) {
                            pressAndHoldTimer.start();
                        }
                    }

                    onReleased: {
                        pressAndHoldTimer.stop();
                    }

                    onClicked: mouse => {
                        if (mouse.button === Qt.LeftButton) {
                            MprisController.cyclePlayer(1);
                        } else if (mouse.button === Qt.RightButton) {
                            const items = playerIcon.buildMenuItems();
                            if (items.length > 0) {
                                Visibilities.contextMenu.openCustomMenu(items, 200, 36, "player");
                            }
                        }
                    }
                }
            }
        }
    }
}
