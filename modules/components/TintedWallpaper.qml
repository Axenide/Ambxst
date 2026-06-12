import QtQuick
import QtQuick.Effects
import qs.modules.theme
import qs.config

Item {
    id: root
    property string source: ""
    property real radius: 0
    property bool tintEnabled: false
    
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

    // ─── Optimized palette texture ───
    // Instead of rendering a Row of Rectangles via ShaderEffectSource(live: true) every frame
    // (which forces a full render-to-texture pass 60 times per second),
    // we use a Canvas that paints ONCE via requestPaint() only when needed.
    // The ShaderEffectSource has live: false — it only re-captures when we call scheduleUpdate().
    // This is the QML equivalent of "pre-baking" a texture.

    Canvas {
        id: paletteCanvas
        width: root.optimizedPalette.length
        height: 1
        visible: false

        onPaint: {
            var ctx = getContext("2d");
            if (!ctx) return;
            ctx.clearRect(0, 0, width, height);
            var pal = root.optimizedPalette;
            for (var i = 0; i < pal.length; i++) {
                ctx.fillStyle = Colors[pal[i]];
                ctx.fillRect(i, 0, 1, 1);
            }
        }

        Component.onCompleted: requestPaint()    // ⚡ Trigger initial paint

        // Repaint when theme colors change (Colors is a FileView, uses onFileChanged)
        Connections {
            target: Colors
            function onFileChanged() { Qt.callLater(paletteCanvas.requestPaint); }
        }
    }

    ShaderEffectSource {
        id: paletteTextureSource
        sourceItem: paletteCanvas
        live: false                    // ⚡ Only capture once, not every frame
        hideSource: true
        visible: false
        smooth: false
        recursive: false

        // Force re-capture when Canvas repaints
        Connections {
            target: paletteCanvas
            function onPainted() { paletteTextureSource.scheduleUpdate(); }
        }
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
            source: root.source
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
    }
}
