import QtQuick
import QtMultimedia
import qs.modules.globals
import qs.modules.theme

Item {
    id: videoWallpaper

    property string sourceFile
    property bool tint: false
    signal requestVideoSync

    readonly property real positionMs: player.position

    readonly property var optimizedPalette: ["background", "overBackground", "shadow", "surface", "surfaceBright", "surfaceDim", "surfaceContainer", "surfaceContainerHigh", "surfaceContainerHighest", "surfaceContainerLow", "surfaceContainerLowest", "primary", "secondary", "tertiary", "red", "lightRed", "green", "lightGreen", "blue", "lightBlue", "yellow", "lightYellow", "cyan", "lightCyan", "magenta", "lightMagenta"]

    onSourceFileChanged: restartPlayback()
    Component.onCompleted: restartPlayback()

    function restartPlayback() {
        if (!sourceFile)
            return;
        player.stop();
        player.source = "file://" + sourceFile;
        player.play();
        syncDebounce.restart();
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
            player.seek(0);
            if (player.playbackState !== MediaPlayer.PlayingState)
                player.play();
        }
    }
}
