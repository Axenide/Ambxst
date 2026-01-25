import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.globals
import qs.config

StyledRect {
    id: player
    variant: "pane"

    property real playerRadius: Config.roundness > 0 ? Config.roundness + 4 : 0
    property bool playersListExpanded: false

    visible: true
    radius: playerRadius

    implicitHeight: innerPlayer.implicitHeight + innerPlayer.anchors.margins * 2

    readonly property bool isDragging: seekBar.isDragging

    property bool isPlaying: MprisController.activePlayer?.playbackState === MprisPlaybackState.Playing
    property real position: MprisController.activePlayer?.position ?? 0.0
    property real length: MprisController.activePlayer?.length ?? 1.0
    property bool hasArtwork: (MprisController.activePlayer?.trackArtUrl ?? "") !== ""
    property bool hasActivePlayer: MprisController.activePlayer !== null
    property bool isSeeking: false

    Timer {
        id: seekUnlockTimer
        interval: 1000
        repeat: false
        onTriggered: player.isSeeking = false
    }

    function formatTime(seconds) {
        const totalSeconds = Math.floor(seconds);
        const hours = Math.floor(totalSeconds / 3600);
        const minutes = Math.floor((totalSeconds % 3600) / 60);
        const secs = totalSeconds % 60;

        if (hours > 0) {
            return hours + ":" + (minutes < 10 ? "0" : "") + minutes + ":" + (secs < 10 ? "0" : "") + secs;
        } else {
            return minutes + ":" + (secs < 10 ? "0" : "") + secs;
        }
    }

    // Function to sync seekBar with current media position
    function syncSeekBarPosition() {
        if (!seekBar.isDragging && !player.isSeeking && player.hasActivePlayer) {
            seekBar.value = player.length > 0 ? player.position / player.length : 0;
        }
    }

    Timer {
        running: player.isPlaying
        interval: 1000
        repeat: true
        onTriggered: {
            syncSeekBarPosition();
            MprisController.activePlayer?.positionChanged();
        }
    }

    Connections {
        target: MprisController.activePlayer
        function onPositionChanged() {
            syncSeekBarPosition();
        }
    }

    // Immediate sync when component becomes visible or when active player changes
    Component.onCompleted: {
        syncSeekBarPosition();
    }

    Connections {
        target: MprisController
        function onActivePlayerChanged() {
            // Small delay to ensure player properties are updated
            Qt.callLater(syncSeekBarPosition);
        }
    }

    // Sync when dashboard opens/closes by connecting to GlobalStates
    Connections {
        target: GlobalStates
        function onDashboardOpenChanged() {
            if (GlobalStates.dashboardOpen) {
                // Small delay to ensure component is fully rendered
                Qt.callLater(syncSeekBarPosition);
            }
        }
    }

    StyledRect {
        id: innerPlayer
        variant: "internalbg"
        anchors.fill: parent
        anchors.margins: 4
        radius: player.radius - 4

        implicitHeight: mainLayout.implicitHeight + mainLayout.anchors.margins * 2

        // Main Layout
        ColumnLayout {
            id: mainLayout
            anchors.centerIn: parent
            anchors.fill: parent
            anchors.margins: 16
            spacing: 8
            opacity: player.playersListExpanded ? 0.3 : 1.0

            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                }
            }

            // 1. Disc Area (Cover + Seek Ring)
            Item {
                id: discArea
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 180
                Layout.preferredHeight: 180
                Layout.topMargin: -8
                Layout.bottomMargin: -24

                CircularSeekBar {
                    id: seekBar
                    anchors.fill: parent
                    // value is managed by Timer/Connections to prevent jump-back
                    accentColor: Colors.primary
                    trackColor: Colors.outline
                    lineWidth: 6
                    wavy: true // Enable wavy progress
                    waveAmplitude: player.isPlaying ? 3 : 0
                    waveFrequency: 24

                    // Half circle (Top) from 9 o'clock (180) to 3 o'clock (360)
                    startAngleDeg: 180
                    spanAngleDeg: 180

                    enabled: player.hasActivePlayer && (MprisController.activePlayer?.canSeek ?? false)

                    onValueEdited: newValue => {
                        if (MprisController.activePlayer && MprisController.activePlayer.canSeek) {
                            player.isSeeking = true;
                            seekUnlockTimer.restart();
                            seekBar.value = newValue; // Optimistic update
                            MprisController.activePlayer.position = newValue * player.length;
                        }
                    }
                }

                // Cover Art Disc
                Item {
                    id: coverDiscContainer
                    anchors.centerIn: parent
                    // Increased padding to separate cover from handle (which extends inwards)
                    width: parent.width - 52
                    height: parent.height - 52

                    Item {
                        id: rotatingWrapper
                        anchors.fill: parent

                        ClippingRectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: Colors.surface

                            Image {
                                id: coverArt
                                anchors.fill: parent
                                source: MprisController.activePlayer?.trackArtUrl ?? ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true

                                RotationAnimation on rotation {
                                    id: rotateAnim
                                    from: 0
                                    to: 360
                                    duration: 8000
                                    loops: Animation.Infinite
                                    running: player.isPlaying
                                }

                                Behavior on rotation {
                                    enabled: !player.isPlaying
                                    SpringAnimation {
                                        spring: 0.8
                                        damping: 0.05
                                        epsilon: 0.25
                                    }
                                }

                                Connections {
                                    target: player
                                    function onIsPlayingChanged() {
                                        if (!player.isPlaying) {
                                            let currentRotation = coverArt.rotation % 360;
                                            if (currentRotation > 180) {
                                                coverArt.rotation = 360;
                                            } else {
                                                coverArt.rotation = 0;
                                            }
                                        }
                                    }
                                }

                                // Placeholder image or logic if needed
                                Rectangle {
                                    anchors.fill: parent
                                    color: Colors.surface
                                    visible: !player.hasArtwork

                                    WavyLine {
                                        anchors.centerIn: parent
                                        width: parent.width * 0.6
                                        height: 20
                                        color: Colors.primary
                                        frequency: 2
                                        amplitudeMultiplier: 2
                                        visible: true
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 2. Metadata Area
            ColumnLayout {
                // Layout.topMargin: -12  <-- Removed to test the other approach cleaner, or I can keep both if needed.
                // The user said "No cambió", so maybe the -12 wasn't enough or wasn't working.
                // I'll stick to the user's specific request: "reduce margin bottom of the component above".
                // So I will remove this one to avoid confusion and rely on the bottomMargin of discArea.
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    Layout.preferredHeight: visible ? implicitHeight : 0
                    text: player.hasActivePlayer ? (MprisController.activePlayer?.trackTitle ?? "") : "Nothing Playing"
                    color: Colors.overBackground
                    font.pixelSize: Config.theme.fontSize + 2
                    font.weight: Font.Bold
                    font.family: Config.theme.font
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    visible: text !== ""
                }

                Text {
                    Layout.fillWidth: true
                    Layout.preferredHeight: visible ? implicitHeight : 0
                    text: player.hasActivePlayer ? (MprisController.activePlayer?.trackAlbum ?? "") : "Enjoy the silence"
                    color: Colors.overBackground
                    font.pixelSize: Config.theme.fontSize
                    font.family: Config.theme.font
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    opacity: 0.7
                    visible: text !== ""
                }

                Text {
                    Layout.fillWidth: true
                    Layout.preferredHeight: visible ? implicitHeight : 0
                    text: player.hasActivePlayer ? (MprisController.activePlayer?.trackArtist ?? "") : "¯\\_(ツ)_/¯"
                    color: Colors.overBackground
                    font.pixelSize: Config.theme.fontSize
                    font.family: Config.theme.font
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    opacity: 0.7
                    visible: text !== ""
                }
            }

            // 3. Playback Controls
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8
                visible: player.hasActivePlayer

                // Player Selector
                MediaIconButton {
                    icon: player.getPlayerIcon(MprisController.activePlayer)
                    onClicked: mouse => {
                        if (mouse.button === Qt.LeftButton) {
                            MprisController.cyclePlayer(1);
                        } else if (mouse.button === Qt.RightButton) {
                            player.playersListExpanded = !player.playersListExpanded;
                        }
                    }
                }

                // Previous
                MediaIconButton {
                    icon: Icons.previous
                    enabled: MprisController.canGoPrevious
                    opacity: enabled ? 1.0 : 0.3
                    onClicked: MprisController.previous()
                }

                // Play/Pause
                StyledRect {
                    id: playPauseBtn
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44
                    variant: "primary"

                    animateRadius: false
                    radius: Styling.radius(16) // Default/Paused state

                    states: [
                        State {
                            name: "playing"
                            when: player.isPlaying
                            PropertyChanges {
                                target: playPauseBtn
                                radius: Styling.radius(0)
                            }
                        },
                        State {
                            name: "paused"
                            when: !player.isPlaying
                            PropertyChanges {
                                target: playPauseBtn
                                radius: Styling.radius(16)
                            }
                        }
                    ]

                    transitions: Transition {
                        NumberAnimation {
                            properties: "radius"
                            duration: 300
                            easing.type: Easing.OutBack
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: player.isPlaying ? Icons.pause : Icons.play
                        font.family: Icons.font
                        font.pixelSize: 22
                        color: playPauseBtn.item
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: MprisController.togglePlaying()
                    }
                }

                // Next
                MediaIconButton {
                    icon: Icons.next
                    enabled: MprisController.canGoNext
                    opacity: enabled ? 1.0 : 0.3
                    onClicked: MprisController.next()
                }

                // Mode
                MediaIconButton {
                    icon: {
                        if (MprisController.hasShuffle)
                            return Icons.shuffle;
                        if (MprisController.loopState === MprisLoopState.Track)
                            return Icons.repeatOnce;
                        if (MprisController.loopState === MprisLoopState.Playlist)
                            return Icons.repeat;
                        return Icons.shuffle;
                    }
                    opacity: (MprisController.shuffleSupported || MprisController.loopSupported) ? 1.0 : 0.3
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

            // 4. Duration Area
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: player.hasActivePlayer ? (player.formatTime(player.position) + " / " + player.formatTime(player.length)) : "--:-- / --:--"
                color: Colors.overBackground
                font.pixelSize: Config.theme.fontSize - 2
                font.family: Config.theme.font
                opacity: 0.5
            }
        }

        // Players List Overlay
        Item {
            id: overlayLayer
            anchors.fill: parent
            visible: player.playersListExpanded
            z: 100

            // Scrim
            Rectangle {
                anchors.fill: parent
                color: "black"
                opacity: 0.4
                radius: innerPlayer.radius

                MouseArea {
                    anchors.fill: parent
                    onClicked: player.playersListExpanded = false
                }
            }

            // List Container
            StyledRect {
                id: playersListContainer
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 4
                implicitHeight: Math.min(160, playersListView.contentHeight + 8)
                variant: "pane"
                radius: innerPlayer.radius - 4

                ListView {
                    id: playersListView
                    anchors.fill: parent
                    anchors.margins: 4
                    clip: true
                    model: MprisController.filteredPlayers

                    delegate: StyledRect {
                        id: playerItem
                        required property var modelData
                        required property int index

                        width: playersListView.width
                        height: 40
                        variant: mouseArea.containsMouse ? "focus" : "transparent"
                        radius: 4

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8

                            Text {
                                text: player.getPlayerIcon(modelData)
                                font.family: Icons.font
                                font.pixelSize: 18
                                color: Colors.overBackground
                            }

                            Text {
                                Layout.fillWidth: true
                                text: (modelData?.trackTitle || modelData?.identity || "Unknown Player")
                                color: Colors.overBackground
                                font.family: Config.theme.font
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                MprisController.setActivePlayer(modelData);
                                player.playersListExpanded = false;
                            }
                        }
                    }
                }
            }
        }
    }

    // Internal component for small buttons
    component MediaIconButton: Text {
        property string icon: ""
        signal clicked(var mouse)

        text: icon
        font.family: Icons.font
        font.pixelSize: 20
        color: mouseArea.containsMouse ? Colors.primary : Colors.overBackground

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => parent.clicked(mouse)
        }
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
}
