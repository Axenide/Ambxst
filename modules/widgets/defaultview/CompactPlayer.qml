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

    Connections {
        target: compactPlayer.player
        function onPositionChanged() {
            if (!positionSlider.isDragging && compactPlayer.player) {
                positionSlider.value = compactPlayer.length > 0 ? Math.min(1.0, compactPlayer.position / compactPlayer.length) : 0;
            }
        }
    }

    StyledRect {
        variant: "common"
        anchors.fill: parent
        radius: Styling.radius(-4)

        WavyLine {
            id: noPlayerWavyLine
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: -4
            frequency: 4
            color: Colors.surfaceBright
            amplitudeMultiplier: 4
            height: 24
            lineWidth: 2
            fullLength: width
            visible: compactPlayer.player === null
            opacity: 1.0
            Behavior on color {
                enabled: Config.animDuration > 0
                ColorAnimation {
                    duration: Config.animDuration
                    easing.type: Easing.OutQuart
                }
            }
            FrameAnimation {
                running: noPlayerWavyLine.visible
            }
        }

        ClippingRectangle {
            anchors.fill: parent
            radius: Styling.radius(-4)
            color: "transparent"

            Image {
                id: backgroundArt
                anchors.fill: parent
                source: compactPlayer.player?.trackArtUrl ?? ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: false
            }

            MultiEffect {
                anchors.fill: backgroundArt
                source: backgroundArt
                blurEnabled: true
                blurMax: 32
                blur: 0.75
                autoPaddingEnabled: false
                opacity: hasArtwork ? 1.0 : 0.0
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
                opacity: hasArtwork ? 0.5 : 0.0
                radius: Styling.radius(-4)
                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
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
            visible: compactPlayer.player !== null
            Behavior on spacing {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration
                    easing.type: Easing.OutQuart
                }
            }

            AnimatedImage {
                id: playingGif
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                fillMode: Image.PreserveAspectFit
                source: Qt.resolvedUrl("../../../assets/gifs/bongo-cat-transparent.gif")
                visible: compactPlayer.isPlaying && (Config.bar?.showBongoCat ?? true)
                playing: visible
                speed: 0.65
            }

            Item {
                id: artworkContainer
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                visible: compactPlayer.player !== null
                ClippingRectangle {
                    anchors.fill: parent
                    radius: compactPlayer.isPlaying ? Styling.radius(-8) : Styling.radius(-4)
                    color: "transparent"
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
                        blurMax: 32
                        blur: 0.75
                        opacity: hasArtwork ? 1.0 : 0.0 // Simplificado
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
                        opacity: hasArtwork ? 0.5 : 0.0
                    }
                    Text {
                        id: playPauseBtn
                        anchors.centerIn: parent
                        text: compactPlayer.isPlaying ? Icons.pause : Icons.play
                        textFormat: Text.RichText
                        color: playPauseHover.hovered ? (hasArtwork ? Styling.srItem("overprimary") : Styling.srItem("overprimary")) : (hasArtwork ? Colors.overBackground : Colors.overBackground)
                        font.pixelSize: 16
                        font.family: Icons.font
                        opacity: compactPlayer.player?.canPause ?? false ? 1.0 : 0.3
                        scale: 1.0
                        layer.enabled: true
                        layer.effect: BgShadow {}
                        Behavior on color {
                            enabled: Config.animDuration > 0
                            ColorAnimation {
                                duration: Config.animDuration
                                easing.type: Easing.OutQuart
                            }
                        }
                        Behavior on scale {
                            enabled: Config.animDuration > 0
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
                color: previousHover.hovered ? (hasArtwork ? Styling.srItem("overprimary") : Styling.srItem("overprimary")) : Colors.overBackground
                font.pixelSize: 16
                font.family: Icons.font
                opacity: compactPlayer.player?.canGoPrevious ?? false ? 1.0 : 0.3
                visible: compactPlayer.player !== null && compactPlayer.notchHovered && opacity > 0
                clip: true
                scale: 1.0
                readonly property real naturalWidth: implicitWidth
                Layout.preferredWidth: (compactPlayer.player !== null && compactPlayer.notchHovered) ? naturalWidth : 0
                Behavior on Layout.preferredWidth {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                }
                Behavior on color {
                    enabled: Config.animDuration > 0
                    ColorAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                }
                Behavior on scale {
                    enabled: Config.animDuration > 0
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

            PositionSlider {
                id: positionSlider
                Layout.fillWidth: true
                Layout.preferredHeight: 4
                Layout.leftMargin: compactPlayer.notchHovered ? 0 : 8
                Layout.rightMargin: compactPlayer.notchHovered ? 0 : 8
                visible: compactPlayer.player !== null
                player: compactPlayer.player
                // Le pasamos 'hasArtwork' para que el slider también pueda usar los colores dinámicos
                hasArtwork: compactPlayer.hasArtwork
            }

            Text {
                id: nextBtn
                text: Icons.next
                textFormat: Text.RichText
                color: nextHover.hovered ? (hasArtwork ? Styling.srItem("overprimary") : Styling.srItem("overprimary")) : Colors.overBackground
                font.pixelSize: 16
                font.family: Icons.font
                opacity: compactPlayer.player?.canGoNext ?? false ? 1.0 : 0.3
                visible: compactPlayer.player !== null && opacity > 0
                clip: true
                scale: 1.0
                readonly property real naturalWidth: implicitWidth
                Layout.preferredWidth: (compactPlayer.player !== null && compactPlayer.notchHovered) ? naturalWidth : 0
                Behavior on Layout.preferredWidth {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                }
                Behavior on color {
                    enabled: Config.animDuration > 0
                    ColorAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                }
                Behavior on scale {
                    enabled: Config.animDuration > 0
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
                color: modeHover.hovered ? (hasArtwork ? Styling.srItem("overprimary") : Styling.srItem("overprimary")) : Colors.overBackground
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
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                }
                Behavior on color {
                    enabled: Config.animDuration > 0
                    ColorAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                }
                Behavior on scale {
                    enabled: Config.animDuration > 0
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
                text: compactPlayer.getPlayerIcon(compactPlayer.player)
                textFormat: Text.RichText
                color: playerIconHover.hovered ? (hasArtwork ? Styling.srItem("overprimary") : Styling.srItem("overprimary")) : Colors.overBackground
                font.pixelSize: 20
                font.family: Icons.font
                verticalAlignment: Text.AlignVCenter
                visible: compactPlayer.player !== null
                Layout.preferredWidth: compactPlayer.player !== null ? implicitWidth : 0
                Layout.rightMargin: compactPlayer.player !== null ? 4 : 0
                Behavior on Layout.preferredWidth {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                }
                Behavior on Layout.rightMargin {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                }
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

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.LeftButton) {
                            MprisController.cyclePlayer(1);
                        } else if (mouse.button === Qt.RightButton) {
                            playerPopup.toggle();
                        }
                    }
                }
            }
        }
    }

    BarPopup {
        id: playerPopup
        anchorItem: playerIcon
        bar: ({
                position: Config.bar?.position ?? "top"
            })

        contentWidth: 250
        contentHeight: playersColumn.implicitHeight + playerPopup.popupPadding * 2

        ColumnLayout {
            id: playersColumn
            anchors.fill: parent
            spacing: 4

            Repeater {
                model: MprisController.filteredPlayers
                delegate: StyledRect {
                    id: playerItem
                    required property var modelData
                    required property int index

                    readonly property bool isSelected: compactPlayer.player === modelData
                    readonly property bool isFirst: index === 0
                    readonly property bool isLast: index === MprisController.filteredPlayers.length - 1

                    readonly property real defaultRadius: Styling.radius(4)
                    readonly property real selectedRadius: defaultRadius / 2

                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    variant: isSelected ? "primary" : (hoverHandler.hovered ? "focus" : "common")
                    enableShadow: false

                    topLeftRadius: isSelected ? (isFirst ? defaultRadius : selectedRadius) : defaultRadius
                    topRightRadius: isSelected ? (isFirst ? defaultRadius : selectedRadius) : defaultRadius
                    bottomLeftRadius: isSelected ? (isLast ? defaultRadius : selectedRadius) : defaultRadius
                    bottomRightRadius: isSelected ? (isLast ? defaultRadius : selectedRadius) : defaultRadius

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8

                        Text {
                            text: compactPlayer.getPlayerIcon(playerItem.modelData)
                            font.family: Icons.font
                            font.pixelSize: 16
                            color: playerItem.item
                        }

                        Text {
                            text: playerItem.modelData.trackTitle || playerItem.modelData.identity || "Unknown Player"
                            font.family: Styling.defaultFont
                            font.pixelSize: Styling.fontSize(0)
                            color: playerItem.item
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }

                    HoverHandler {
                        id: hoverHandler
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            MprisController.setActivePlayer(playerItem.modelData);
                        }
                    }
                }
            }
        }
    }
}
