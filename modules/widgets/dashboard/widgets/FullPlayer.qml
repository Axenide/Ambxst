import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

PaneRect {
    id: player

    height: layout.implicitHeight + layout.anchors.margins

    property bool isPlaying: MprisController.activePlayer?.playbackState === MprisPlaybackState.Playing
    property real position: MprisController.activePlayer?.position ?? 0.0
    property real length: MprisController.activePlayer?.length ?? 1.0

    Timer {
        running: player.isPlaying
        interval: 1000
        repeat: true
        onTriggered: MprisController.activePlayer?.positionChanged()
    }

    ClippingRectangle {
        anchors.fill: parent
        radius: Config.roundness > 0 ? Config.roundness + 4 : 0
        color: Colors.surface

        Image {
            id: backgroundArt
            anchors.fill: parent
            source: MprisController.activePlayer?.trackArtUrl ?? ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
        }

        MultiEffect {
            anchors.fill: parent
            source: backgroundArt
            brightness: -0.15
            contrast: -0.5
            saturation: -0.25
            // blurEnabled: true
            blurMax: 32
            blur: 0.75
            opacity: (MprisController.activePlayer?.trackArtUrl ?? "") !== "" ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: Config.animDuration
                    easing.type: Easing.OutQuart
                }
            }
        }

        ColumnLayout {
            id: layout
            anchors.fill: parent
            anchors.margins: 16
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                spacing: 8

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: MprisController.activePlayer?.trackTitle ?? "No hay reproducción activa"
                        textFormat: Text.PlainText
                        color: Colors.whiteSource
                        font.pixelSize: Config.theme.fontSize
                        font.weight: Font.Bold
                        font.family: Config.theme.font
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: MprisController.activePlayer?.trackArtist ?? ""
                        textFormat: Text.PlainText
                        color: Colors.whiteSource
                        font.pixelSize: Config.theme.fontSize
                        font.family: Config.theme.font
                        opacity: 0.7
                        elide: Text.ElideRight
                        visible: text !== ""
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    color: playPauseHover.hovered ? Colors.whiteSource : Colors.primaryFixed
                    radius: player.isPlaying ? Math.max(0, Config.roundness - 4) : Config.roundness > 0 ? Config.roundness + 4 : 0
                    opacity: MprisController.canTogglePlaying ? 1.0 : 0.3

                    Behavior on radius {
                        NumberAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.5
                        }
                    }

                    Text {
                        id: playPauseBtn
                        anchors.centerIn: parent
                        text: player.isPlaying ? Icons.pause : Icons.play
                        textFormat: Text.RichText
                        color: Colors.shadow
                        font.pixelSize: 20
                        font.family: Icons.font
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
            }

            RowLayout {
                Layout.fillWidth: true
                // Layout.preferredHeight: 40
                spacing: 8

                Text {
                    id: previousBtn
                    text: Icons.previous
                    textFormat: Text.RichText
                    color: previousHover.hovered ? Colors.primaryFixed : Colors.whiteSource
                    font.pixelSize: 20
                    font.family: Icons.font
                    opacity: MprisController.canGoPrevious ? 1.0 : 0.3

                    Behavior on color {
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

                Item {
                    id: positionControl
                    Layout.fillWidth: true
                    Layout.preferredHeight: 4

                    property bool isDragging: false
                    property real dragPosition: 0.0
                    property int dragSeparation: 4

                    property real progressRatio: isDragging ? dragPosition : (player.length > 0 ? Math.min(1.0, player.position / player.length) : 0)

                    Rectangle {
                        anchors.right: parent.right
                        width: (1 - positionControl.progressRatio) * parent.width - positionControl.dragSeparation
                        height: parent.height
                        radius: height / 2
                        color: Colors.shadow
                        visible: MprisController.activePlayer !== null
                    }

                    Loader {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        active: player.isPlaying || !MprisController.activePlayer
                        sourceComponent: WavyLine {
                            id: wavyFill
                            frequency: 8
                            color: MprisController.activePlayer ? Colors.primaryFixed : Colors.outline
                            amplitudeMultiplier: 0.8
                            height: MprisController.activePlayer ? positionControl.height * 8 : positionControl.height * 4
                            width: MprisController.activePlayer ? Math.max(0, positionControl.width * positionControl.progressRatio - positionControl.dragSeparation) : positionControl.width
                            lineWidth: positionControl.height
                            fullLength: positionControl.width

                            Behavior on color {
                                ColorAnimation {
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

                            FrameAnimation {
                                running: player.isPlaying || !MprisController.activePlayer
                                onTriggered: wavyFill.requestPaint()
                            }
                        }
                    }

                    Loader {
                        active: !player.isPlaying && MprisController.activePlayer
                        sourceComponent: Rectangle {
                            anchors.left: parent.left
                            width: Math.max(0, positionControl.width * positionControl.progressRatio - positionControl.dragSeparation)
                            height: positionControl.height
                            radius: height / 2
                            color: Colors.primaryFixed
                        }
                    }

                    Rectangle {
                        id: dragHandle
                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.max(0, Math.min(positionControl.width - width, positionControl.width * positionControl.progressRatio - width / 2))
                        width: 4
                        height: positionControl.isDragging ? 20 : 16
                        radius: width / 2
                        color: Colors.whiteSource
                        visible: MprisController.activePlayer !== null

                        Behavior on height {
                            NumberAnimation {
                                duration: Config.animDuration
                                easing.type: Easing.OutQuart
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: MprisController.activePlayer?.canSeek ?? false ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled: MprisController.activePlayer?.canSeek ?? false
                        onClicked: mouse => {
                            if (MprisController.activePlayer && MprisController.activePlayer.canSeek) {
                                MprisController.activePlayer.position = (mouse.x / width) * player.length;
                            }
                        }
                        onPressed: {
                            positionControl.isDragging = true;
                            positionControl.dragPosition = Math.min(Math.max(0, mouseX / width), 1);
                        }
                        onReleased: {
                            if (MprisController.activePlayer && MprisController.activePlayer.canSeek) {
                                MprisController.activePlayer.position = positionControl.dragPosition * player.length;
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
                    id: nextBtn
                    text: Icons.next
                    textFormat: Text.RichText
                    color: nextHover.hovered ? Colors.primaryFixed : Colors.whiteSource
                    font.pixelSize: 20
                    font.family: Icons.font
                    opacity: MprisController.canGoNext ? 1.0 : 0.3

                    Behavior on color {
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
                    color: modeHover.hovered ? Colors.primaryFixed : Colors.whiteSource
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
                        return Icons.player;
                    }
                    textFormat: Text.RichText
                    color: playerIconHover.hovered ? Colors.primaryFixed : Colors.whiteSource
                    font.pixelSize: 20
                    font.family: Icons.font
                    opacity: MprisController.activePlayer ? 1.0 : 0.3

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
    }
}
