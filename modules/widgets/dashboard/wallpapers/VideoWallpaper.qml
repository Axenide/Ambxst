import QtQuick
import QtMultimedia
import qs.modules.globals
import qs.modules.services
import qs.modules.theme
import qs.config

Item {
    id: videoWallpaper

    property string sourceFile
    property string screenName: ""
    property bool tint: false
    signal requestVideoSync

    readonly property real positionMs: player.position
    readonly property var screenMonitor: AxctlService.monitorFor(screenName)
    readonly property bool screenHasFullscreen: {
        if (!screenMonitor)
            return false;
        const clients = AxctlService.clients.values || [];
        return clients.some(client => client.fullscreen === true && client.monitor === screenMonitor.id);
    }
    // Game mode pauses every video wallpaper, on every screen.
    readonly property bool gameModeOnScreen: GameModeClient.toggled
    readonly property bool shouldPausePlayback: gameModeOnScreen || (Config.performance.pauseWallpapersOnFullscreen && screenHasFullscreen)

    readonly property var optimizedPalette: ["background", "overBackground", "shadow", "surface", "surfaceBright", "surfaceDim", "surfaceContainer", "surfaceContainerHigh", "surfaceContainerHighest", "surfaceContainerLow", "surfaceContainerLowest", "primary", "secondary", "tertiary", "red", "lightRed", "green", "lightGreen", "blue", "lightBlue", "yellow", "lightYellow", "cyan", "lightCyan", "magenta", "lightMagenta"]

    onSourceFileChanged: restartPlayback()
    onShouldPausePlaybackChanged: updatePlayback()
    Component.onCompleted: restartPlayback()

    function restartPlayback() {
        if (!sourceFile)
            return;
        player.stop();
        player.source = "file://" + sourceFile;
        syncDebounce.restart();
        // skwd-wall plays this one; leave the player empty.
        if (skwdHandOff())
            return;
        updatePlayback();
    }

    function updatePlayback() {
        if (!sourceFile)
            return;
        // skwd-wall pauses it itself (SkwdWall.pauses).
        if (skwdOffloaded)
            return;
        if (shouldPausePlayback) {
            if (player.playbackState === MediaPlayer.PlayingState)
                player.pause();
            return;
        }
        if (player.playbackState !== MediaPlayer.PlayingState)
            player.play();
    }

    Timer {
        id: syncDebounce
        interval: 300
        onTriggered: videoWallpaper.requestVideoSync()
    }

    MediaPlayer {
        id: player
        audioOutput: mutedAudio
        videoOutput: videoOut
        loops: MediaPlayer.Infinite

        onErrorOccurred: (error, errorString) => {
            console.warn("VideoWallpaper playback error:", error, errorString, "source:", videoWallpaper.sourceFile);
        }
    }

    AudioOutput {
        id: mutedAudio
        muted: true
        volume: 0
    }

    Item {
        id: paletteSourceItem
        visible: true
        width: videoWallpaper.optimizedPalette.length
        height: 1
        opacity: 0

        Row {
            anchors.fill: parent
            Repeater {
                model: videoWallpaper.optimizedPalette
                Rectangle {
                    width: 1
                    height: 1
                    color: Colors[modelData]
                }
            }
        }
    }

    ShaderEffectSource {
        id: paletteTextureSource
        sourceItem: paletteSourceItem
        hideSource: true
        visible: false
        smooth: false
        recursive: false
    }

    VideoOutput {
        id: videoOut
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
        layer.enabled: videoWallpaper.tint
        layer.effect: ShaderEffect {
            property var paletteTexture: paletteTextureSource
            property real paletteSize: videoWallpaper.optimizedPalette.length
            property real texWidth: videoOut.width
            property real texHeight: videoOut.height

            vertexShader: "palette.vert.qsb"
            fragmentShader: "palette.frag.qsb"
        }
    }

    Connections {
        target: GlobalStates
        function onVideoSyncTickChanged() {
            if (videoWallpaper.shouldPausePlayback)
                return;
            // Nothing to realign, skwd-wall plays it.
            if (videoWallpaper.skwdOffloaded)
                return;
            player.seek(0);
            if (player.playbackState !== MediaPlayer.PlayingState)
                player.play();
        }
    }

    // ── skwd-wall ─────────────────────────────────────────────────────
    // skwd-wall renders this video (SkwdWall) instead of the QtMultimedia
    // player above, so the player is left empty.
    readonly property bool skwdOffloaded: SkwdWall.offloads(sourceFile)
    // Handed over, or handed back (skwd stopped or failed): start over.
    onSkwdOffloadedChanged: restartPlayback()

    function skwdHandOff() {
        if (!skwdOffloaded)
            return false;
        player.stop();
        player.source = "";
        // Renderers that wait for the first decoded frame count a handed-off
        // video as shown.
        if ("hasFirstFrame" in videoWallpaper && !videoWallpaper.hasFirstFrame) {
            videoWallpaper.hasFirstFrame = true;
            videoWallpaper.firstFrameReady();
        }
        return true;
    }
}
