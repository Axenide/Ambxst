import QtQuick
import qs.config
import qs.modules.theme

Item {
    id: root

    required property var variantConfig
    property real rectOpacity: 1.0

    readonly property var gradientStops: variantConfig.gradient
    readonly property string gradientType: variantConfig.gradientType
    readonly property real gradientAngle: variantConfig.gradientAngle
    readonly property real gradientCenterX: variantConfig.gradientCenterX
    readonly property real gradientCenterY: variantConfig.gradientCenterY
    readonly property real halftoneDotMin: variantConfig.halftoneDotMin
    readonly property real halftoneDotMax: variantConfig.halftoneDotMax
    readonly property real halftoneStart: variantConfig.halftoneStart
    readonly property real halftoneEnd: variantConfig.halftoneEnd
    readonly property color halftoneDotColor: Config.resolveColor(variantConfig.halftoneDotColor)
    readonly property color halftoneBackgroundColor: Config.resolveColor(variantConfig.halftoneBackgroundColor)

    // Linear gradient texture generator
    Canvas {
        id: linearGradientCanvas
        width: 256
        height: 32 // Increase height to avoid interpolation artifacts at non-integer scales
        visible: false

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            var stops = root.gradientStops;
            if (!stops || stops.length === 0)
                return;

            var grad = ctx.createLinearGradient(0, 0, width, 0);
            for (var i = 0; i < stops.length; i++) {
                var s = stops[i];
                grad.addColorStop(s[1], Config.resolveColor(s[0]));
            }

            ctx.fillStyle = grad;
            ctx.fillRect(0, 0, width, height);
        }

        Connections {
            target: root
            function onGradientStopsChanged() {
                linearGradientCanvas.requestPaint();
            }
        }
        Connections {
            target: Colors
            function onLoaded() {
                linearGradientCanvas.requestPaint();
            }
        }
        Component.onCompleted: requestPaint()
    }

    // Shared gradient texture source
    ShaderEffectSource {
        id: gradientTextureSource
        sourceItem: linearGradientCanvas
        hideSource: true
        smooth: true
        wrapMode: ShaderEffectSource.ClampToEdge
        visible: false
    }

    // Linear gradient
    ShaderEffect {
        anchors.fill: parent
        opacity: root.rectOpacity
        visible: root.gradientType === "linear"

        property real angle: root.gradientAngle
        property real canvasWidth: width
        property real canvasHeight: height
        property var gradTex: gradientTextureSource

        vertexShader: "linear_gradient.vert.qsb"
        fragmentShader: "linear_gradient.frag.qsb"
    }

    // Radial gradient
    ShaderEffect {
        anchors.fill: parent
        opacity: root.rectOpacity
        visible: root.gradientType === "radial"

        property real centerX: root.gradientCenterX
        property real centerY: root.gradientCenterY
        property real canvasWidth: width
        property real canvasHeight: height
        property var gradTex: gradientTextureSource

        vertexShader: "radial_gradient.vert.qsb"
        fragmentShader: "radial_gradient.frag.qsb"
    }

    // Halftone gradient
    ShaderEffect {
        anchors.fill: parent
        opacity: root.rectOpacity
        visible: root.gradientType === "halftone"

        property real angle: root.gradientAngle
        property real dotMinSize: root.halftoneDotMin
        property real dotMaxSize: root.halftoneDotMax
        property real gradientStart: root.halftoneStart
        property real gradientEnd: root.halftoneEnd
        property vector4d dotColor: {
            const c = root.halftoneDotColor || Qt.rgba(1, 1, 1, 1);
            return Qt.vector4d(c.r, c.g, c.b, c.a);
        }
        property vector4d backgroundColor: {
            const c = root.halftoneBackgroundColor || Qt.rgba(0, 0.5, 1, 1);
            return Qt.vector4d(c.r, c.g, c.b, c.a);
        }
        property real canvasWidth: width
        property real canvasHeight: height

        vertexShader: "halftone.vert.qsb"
        fragmentShader: "halftone.frag.qsb"
    }
}
