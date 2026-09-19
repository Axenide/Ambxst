import QtQuick
import QtMultimedia
import QtQuick.Effects
import qs.modules.theme
import qs.config

Item {
    id: root
    property string source: ""
    property real radius: 0
    property bool tintEnabled: false

    readonly property bool isVideo: {
        var ext = source.toString().toLowerCase().split('?')[0].split('.').pop();
        return ["mp4", "webm", "mov", "avi", "mkv", "gif"].includes(ext);
    }

    property real pendingSeekMs: -1

    readonly property real videoPosition: videoPlayer.position

    function applyPendingSeek() {
        if (pendingSeekMs < 0)
            return;
        var status = videoPlayer.mediaStatus;
        if (status >= MediaPlayer.LoadedMedia && status !== MediaPlayer.InvalidMedia) {
            videoPlayer.seek(pendingSeekMs);
            pendingSeekMs = -1;
        }
    }

    function videoPlayAt(ms) {
        if (!root.isVideo)
            return;
        pendingSeekMs = ms;
        videoPlayer.play();
        applyPendingSeek();
    }

    function videoSeek(ms) {
        if (root.isVideo)
            videoPlayer.seek(ms);
    }

    function videoPlay() {
        if (root.isVideo)
            videoPlayer.play();
    }

    onIsVideoChanged: {
        if (isVideo)
            videoPlayer.play();
        else
            videoPlayer.stop();
    }

    MediaPlayer {
        id: videoPlayer
        loops: MediaPlayer.Infinite
        audioOutput: mutedAudio
        videoOutput: videoOut
        source: root.isVideo ? root.source : ""

        onMediaStatusChanged: applyPendingSeek()
    }

    AudioOutput {
        id: mutedAudio
        muted: true
        volume: 0
    }

    // Subset of colors for optimization (approx 25 colors vs 98)
    // Copied from Wallpaper.qml to ensure consistency
    readonly property var optimizedPalette: [
        "background", "overBackground", "shadow",
        "surface", "surfaceBright", "surfaceDim",
        "surfaceContainer", "surfaceContainerHigh", "surfaceContainerHighest", "surfaceContainerLow", "surfaceContainerLowest",
        "primary", "secondary", "tertiary",
        "red", "lightRed",
        "green", "lightGreen",
        "blue", "lightBlue",
        "yellow", "lightYellow",
        "cyan", "lightCyan",
        "magenta", "lightMagenta"
    ]

    // Palette generation for the shader
    Item {
        id: paletteSourceItem
        visible: true
        width: root.optimizedPalette.length
        height: 1
        opacity: 0

        Row {
            anchors.fill: parent
            Repeater {
                model: root.optimizedPalette
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

    // Container for masking (rounded corners)
    Item {
        anchors.fill: parent
        layer.enabled: root.radius > 0
        layer.effect: MultiEffect {
            maskEnabled: true
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
            maskSource: ShaderEffectSource {
                sourceItem: Rectangle {
                    width: root.width
                    height: root.height
                    radius: root.radius
                }
            }
        }

        Image {
            mipmap: true
            id: rawImage
            anchors.fill: parent
            visible: !root.isVideo
            source: root.isVideo ? "" : root.source
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true

            // Tint layer
            layer.enabled: root.tintEnabled
            layer.effect: ShaderEffect {
                property var paletteTexture: paletteTextureSource
                property real paletteSize: root.optimizedPalette.length
                property real texWidth: rawImage.width
                property real texHeight: rawImage.height

                vertexShader: "../widgets/dashboard/wallpapers/palette.vert.qsb"
                fragmentShader: "../widgets/dashboard/wallpapers/palette.frag.qsb"
            }
        }

        VideoOutput {
            id: videoOut
            anchors.fill: parent
            visible: root.isVideo
            fillMode: VideoOutput.PreserveAspectCrop

            layer.enabled: root.tintEnabled
            layer.effect: ShaderEffect {
                property var paletteTexture: paletteTextureSource
                property real paletteSize: root.optimizedPalette.length
                property real texWidth: videoOut.width
                property real texHeight: videoOut.height

                vertexShader: "../widgets/dashboard/wallpapers/palette.vert.qsb"
                fragmentShader: "../widgets/dashboard/wallpapers/palette.frag.qsb"
            }
        }
    }
}
