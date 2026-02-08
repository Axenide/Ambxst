import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

StyledRect {
    id: lockPlayer
    variant: "bg"

    property bool isPlaying: MprisController.activePlayer?.playbackState === MprisPlaybackState.Playing
    property real position: MprisController.activePlayer?.position ?? 0.0
    property real length: MprisController.activePlayer?.length ?? 1.0
    property bool hasArtwork: (MprisController.activePlayer?.trackArtUrl ?? "") !== ""
    property string wallpaperPath: {
        if (!GlobalStates.wallpaperManager) return "";
        let path = GlobalStates.wallpaperManager.currentWallpaper;
        let frame = GlobalStates.wallpaperManager.getLockscreenFramePath(path);
        return frame ? "file://" + frame : "";
    }

    visible: MprisController.activePlayer !== null
    height: 96
    radius: Config.roundness > 0 ? (height / 2) * (Config.roundness / 16) : 0
    backgroundOpacity: (MprisController.activePlayer || wallpaperPath !== "") ? 0.0 : 1.0

    Behavior on backgroundOpacity {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutQuart
        }
    }

    // Blurred wallpaper background fallback
    ClippingRectangle {
        anchors.fill: parent
        radius: lockPlayer.radius
        color: "transparent"

        Image {
            id: lockPlayerBgArt
            anchors.fill: parent
            source: (MprisController.activePlayer?.trackArtUrl ?? "") !== "" ? MprisController.activePlayer.trackArtUrl : lockPlayer.wallpaperPath
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
        }

        MultiEffect {
            anchors.fill: parent
            source: lockPlayerBgArt
            // Only enable blur when there's content to blur (saves GPU)
            blurEnabled: MprisController.activePlayer || wallpaperPath !== ""
            blurMax: 32
            blur: 0.75
            opacity: (MprisController.activePlayer || wallpaperPath !== "") ? 1.0 : 0.0
            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration
                    easing.type: Easing.OutQuart
                }
            }
        }

        StyledRect {
            anchors.fill: parent
            variant: "internalbg"
            opacity: (MprisController.activePlayer || wallpaperPath !== "") ? 0.5 : 0.0
            radius: lockPlayer.radius
        }
    }

    Timer {
        running: lockPlayer.isPlaying
        interval: 1000
        repeat: true
        onTriggered: {
            if (!positionSlider.isDragging) {
                positionSlider.value = lockPlayer.length > 0 ? Math.min(1.0, lockPlayer.position / lockPlayer.length) : 0;
            }
            MprisController.activePlayer?.positionChanged();
        }
    }

    Connections {
        target: MprisController.activePlayer
        function onPositionChanged() {
            if (!positionSlider.isDragging && MprisController.activePlayer) {
                positionSlider.value = lockPlayer.length > 0 ? Math.min(1.0, lockPlayer.position / lockPlayer.length) : 0;
            }
        }
    }

    Item {
        id: noPlayerContainer
        anchors.fill: parent
        anchors.margins: 16
        visible: !MprisController.activePlayer && wallpaperPath === ""

        WavyLine {
            id: noPlayerWavyLine
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            frequency: 4
            color: Colors.surfaceBright
            amplitudeMultiplier: 4
            height: 24
            lineWidth: 2
            fullLength: width
            visible: true
            opacity: 1.0
            // Disable animations - this is a static "no player" indicator
            animationsEnabled: false

            Behavior on color {
                enabled: Config.animDuration > 0
                ColorAnimation {
                    duration: Config.animDuration
                    easing.type: Easing.OutQuart
                }
            }
        }
    }

    RowLayout {
        id: contentLayout
        anchors.fill: parent
        anchors.margins: 16
        anchors.rightMargin: 28
        spacing: 16
        visible: MprisController.activePlayer || wallpaperPath !== ""

        // Album artwork con botón de play/pause superpuesto
    Connections {
        target: MprisController
        function onActivePlayerChanged() {
            if (!MprisController.activePlayer) {
                positionSlider.value = 0;
            }
        }
    }

    Item {

            Layout.preferredWidth: 64
            Layout.preferredHeight: 64
            Layout.alignment: Qt.AlignVCenter

            ClippingRectangle {
                id: artworkContainer
                anchors.fill: parent
                radius: Config.roundness > 0 ? (height / 2) * (Config.roundness / 16) : 0
                color: Colors.surface

                Image {
                    id: albumArt
                    anchors.fill: parent
                    source: (MprisController.activePlayer?.trackArtUrl ?? "") !== "" ? MprisController.activePlayer.trackArtUrl : lockPlayer.wallpaperPath
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: false
                }

                MultiEffect {
                    anchors.fill: parent
                    source: albumArt
                    // Only enable blur when hovered (saves GPU)
                    blurEnabled: playPauseHover.hovered
                    blurMax: 32
                    blur: playPauseHover.hovered ? 0.75 : 0

                    Behavior on blur {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutQuart
                        }
                    }
                }

                StyledRect {
                    anchors.fill: parent
                    variant: "internalbg"
                    opacity: playPauseHover.hovered ? 0.5 : 0.0

                    Behavior on opacity {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutQuart
                        }
                    }
                }
            }

            // Botón de play/pause superpuesto (visible solo en hover)
            Text {
                anchors.centerIn: parent
                text: lockPlayer.isPlaying ? Icons.pause : Icons.play
                textFormat: Text.RichText
                color: Styling.srItem("overprimary")
                font.pixelSize: 24
                font.family: Icons.font
                opacity: playPauseHover.hovered ? 1.0 : 0.0
                visible: MprisController.canTogglePlaying

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration / 2
                        easing.type: Easing.OutQuart
                    }
                }
            }

            HoverHandler {
                id: playPauseHover
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                enabled: MprisController.canTogglePlaying
                onClicked: MprisController.togglePlaying()
            }
        }

        // Información de la pista y controles
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 4

            // Título y artista
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: MprisController.activePlayer?.trackTitle ?? "No hay reproducción activa"
                    textFormat: Text.PlainText
                    color: Colors.overBackground
                    font.pixelSize: Config.theme.fontSize
                    font.weight: Font.Bold
                    font.family: Config.theme.font
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                    maximumLineCount: 1
                }

                Text {
                    Layout.fillWidth: true
                    text: MprisController.activePlayer?.trackArtist ?? ""
                    textFormat: Text.PlainText
                    color: Colors.overBackground
                    font.pixelSize: Config.theme.fontSize
                    font.family: Config.theme.font
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                    maximumLineCount: 1
                    visible: text !== ""
                    opacity: 0.7
                }
            }

            // Controles
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    id: previousBtn
                    text: Icons.previous
                    textFormat: Text.RichText
                    color: previousHover.hovered ? Styling.srItem("overprimary") : Colors.overBackground
                    font.pixelSize: 20
                    font.family: Icons.font
                    opacity: MprisController.canGoPrevious ? 1.0 : 0.3

                    Behavior on color {
                        enabled: Config.animDuration > 0
                        ColorAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutQuart
                        }
                    }

                    HoverHandler {
                        id: previousHover
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        enabled: MprisController.canGoPrevious
                        onClicked: MprisController.previous()
                    }
                }

                PositionSlider {
                    id: positionSlider
                    Layout.fillWidth: true
                    Layout.preferredHeight: 4

                    player: MprisController.activePlayer
                    useCustomColors: true
                    customProgressColor: Styling.srItem("overprimary")
                    customBackgroundColor: Colors.surfaceBright
                }

                Text {
                    id: nextBtn
                    text: Icons.next
                    textFormat: Text.RichText
                    color: nextHover.hovered ? Styling.srItem("overprimary") : Colors.overBackground
                    font.pixelSize: 20
                    font.family: Icons.font
                    opacity: MprisController.canGoNext ? 1.0 : 0.3

                    Behavior on color {
                        enabled: Config.animDuration > 0
                        ColorAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutQuart
                        }
                    }

                    HoverHandler {
                        id: nextHover
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        enabled: MprisController.canGoNext
                        onClicked: MprisController.next()
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
                    color: modeHover.hovered ? Styling.srItem("overprimary") : Colors.overBackground
                    font.pixelSize: 20
                    font.family: Icons.font
                    opacity: {
                        if (!(MprisController.shuffleSupported || MprisController.loopSupported))
                            return 0.3;
                        if (!MprisController.hasShuffle && MprisController.loopState === MprisLoopState.None)
                            return 0.3;
                        return 1.0;
                    }

                    Behavior on color {
                        enabled: Config.animDuration > 0
                        ColorAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutQuart
                        }
                    }

                    HoverHandler {
                        id: modeHover
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        enabled: MprisController.shuffleSupported || MprisController.loopSupported
                        onClicked: {
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
                        }
                    }
                }

                Text {
                    id: playerIcon
                    text: {
                        if (!MprisController.activePlayer)
                            return Icons.player;
                        const dbusName = (MprisController.activePlayer.dbusName || "").toLowerCase();
                        const desktopEntry = (MprisController.activePlayer.desktopEntry || "").toLowerCase();
                        const identity = (MprisController.activePlayer.identity || "").toLowerCase();

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
                    color: playerIconHover.hovered ? Styling.srItem("overprimary") : Colors.overBackground
                    font.pixelSize: 20
                    font.family: Icons.font
                    opacity: MprisController.activePlayer ? 1.0 : 0.3

                    Behavior on color {
                        enabled: Config.animDuration > 0
                        ColorAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutQuart
                        }
                    }

                    HoverHandler {
                        id: playerIconHover
                    }

                    Timer {
                        id: pressAndHoldTimer
                        interval: 1000
                        repeat: false
                        onTriggered: {
                            playersMenu.updateMenuItems();
                            playersMenu.popup(playerIcon);
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
                                playersMenu.updateMenuItems();
                                playersMenu.popup(playerIcon);
                            }
                        }
                    }

                    OptionsMenu {
                        id: playersMenu

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

                        function updateMenuItems() {
                            const players = MprisController.filteredPlayers;
                            const menuItems = [];

                            for (let i = 0; i < players.length; i++) {
                                const player = players[i];
                                const isActive = player === MprisController.activePlayer;

                                menuItems.push({
                                    text: player.trackTitle || player.identity || "Unknown Player",
                                    icon: getPlayerIcon(player),
                                    highlightColor: Styling.srItem("overprimary"),
                                    textColor: Colors.overPrimary,
                                    onTriggered: () => {
                                        MprisController.setActivePlayer(player);
                                        playersMenu.close();
                                    }
                                });
                            }

                            playersMenu.items = menuItems;
                        }
                    }
                }
            }
        }
    }
}
