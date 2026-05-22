pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Widgets
import qs.config
import qs.modules.theme

ClippingRectangle {
    id: root

    clip: true
    antialiasing: true
    contentUnderBorder: true

    required property string variant

    property string gradientOrientation: "vertical"
    property bool enableShadow: false
    property bool enableBorder: true
    property bool animateRadius: true
    property real backgroundOpacity: -1  // -1 means use config value

    readonly property var variantConfig: Styling.getStyledRectConfig(variant) || {}

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

    readonly property var borderData: variantConfig.border

    readonly property color solidColor: Config.resolveColor(variantConfig.color)
    readonly property bool hasSolidColor: variantConfig.color !== undefined && variantConfig.color !== ""

    readonly property color itemColor: Config.resolveColor(variantConfig.itemColor)
    property color item: itemColor

    readonly property real rectOpacity: backgroundOpacity >= 0 ? backgroundOpacity : variantConfig.opacity

    // Check if gradient is actually a single color (optimization: treat as solid)
    readonly property bool isSingleColorGradient: gradientStops && gradientStops.length === 1
    readonly property color singleGradientColor: isSingleColorGradient ? Config.resolveColor(gradientStops[0][0]) : "transparent"

    // Whether we need a multi-stop gradient shader
    readonly property bool needsGradientShader: (gradientType === "linear" || gradientType === "radial") && !isSingleColorGradient && gradientStops && gradientStops.length >= 2

    // Number of active stops (clamped to max 8)
    readonly property int numGradientStops: gradientStops ? Math.min(gradientStops.length, 8) : 0

    // Resolve gradient stops into vec4 color array for shader uniforms
    function resolveStopColor(index) {
        if (!gradientStops || index >= gradientStops.length) return Qt.vector4d(0,0,0,0);
        const resolved = Config.resolveColor(gradientStops[index][0]);
        // Qt.color() ensures hex strings become proper color objects with .r/.g/.b/.a
        const c = Qt.color(resolved);
        return Qt.vector4d(c.r, c.g, c.b, c.a);
    }

    // Pack stop positions into two vec4s (positions 0-3 in first, 4-7 in second)
    readonly property vector4d stopPositionsPack0: Qt.vector4d(
        gradientStops && gradientStops.length > 0 ? gradientStops[0][1] : 0,
        gradientStops && gradientStops.length > 1 ? gradientStops[1][1] : 0,
        gradientStops && gradientStops.length > 2 ? gradientStops[2][1] : 0,
        gradientStops && gradientStops.length > 3 ? gradientStops[3][1] : 0
    )
    readonly property vector4d stopPositionsPack1: Qt.vector4d(
        gradientStops && gradientStops.length > 4 ? gradientStops[4][1] : 0,
        gradientStops && gradientStops.length > 5 ? gradientStops[5][1] : 0,
        gradientStops && gradientStops.length > 6 ? gradientStops[6][1] : 0,
        gradientStops && gradientStops.length > 7 ? gradientStops[7][1] : 0
    )

    radius: variantConfig.radius !== undefined ? variantConfig.radius : Styling.radius(0)

    // Helper to apply opacity to a color via alpha channel
    function applyOpacity(baseColor, opacityValue) {
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * opacityValue);
    }

    // Color priority: single-color gradient > explicit solid color > transparent (for real gradients)
    // Apply rectOpacity via alpha channel to avoid affecting children
    color: {
        if (isSingleColorGradient && (gradientType === "linear" || gradientType === "radial")) {
            return applyOpacity(singleGradientColor, rectOpacity);
        }
        if (hasSolidColor && gradientType !== "linear" && gradientType !== "radial" && gradientType !== "halftone") {
            return applyOpacity(solidColor, rectOpacity);
        }
        return "transparent";
    }

    Behavior on radius {
        enabled: root.animateRadius && Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration / 4
        }
    }

    // Linear gradient - procedural (no texture)
    Loader {
        anchors.fill: parent
        active: root.gradientType === "linear" && root.needsGradientShader

        sourceComponent: ShaderEffect {
            opacity: root.rectOpacity

            property real angle: root.gradientAngle
            property real canvasWidth: width
            property real canvasHeight: height
            property int numStops: root.numGradientStops

            property vector4d stopColor0: root.resolveStopColor(0)
            property vector4d stopColor1: root.resolveStopColor(1)
            property vector4d stopColor2: root.resolveStopColor(2)
            property vector4d stopColor3: root.resolveStopColor(3)
            property vector4d stopColor4: root.resolveStopColor(4)
            property vector4d stopColor5: root.resolveStopColor(5)
            property vector4d stopColor6: root.resolveStopColor(6)
            property vector4d stopColor7: root.resolveStopColor(7)

            property vector4d stopPositionsPack0: root.stopPositionsPack0
            property vector4d stopPositionsPack1: root.stopPositionsPack1

            vertexShader: "linear_gradient.vert.qsb"
            fragmentShader: "linear_gradient.frag.qsb"
        }
    }

    // Radial gradient - procedural (no texture)
    Loader {
        anchors.fill: parent
        active: root.gradientType === "radial" && root.needsGradientShader

        sourceComponent: ShaderEffect {
            opacity: root.rectOpacity

            property real centerX: root.gradientCenterX
            property real centerY: root.gradientCenterY
            property real canvasWidth: width
            property real canvasHeight: height
            property int numStops: root.numGradientStops

            property vector4d stopColor0: root.resolveStopColor(0)
            property vector4d stopColor1: root.resolveStopColor(1)
            property vector4d stopColor2: root.resolveStopColor(2)
            property vector4d stopColor3: root.resolveStopColor(3)
            property vector4d stopColor4: root.resolveStopColor(4)
            property vector4d stopColor5: root.resolveStopColor(5)
            property vector4d stopColor6: root.resolveStopColor(6)
            property vector4d stopColor7: root.resolveStopColor(7)

            property vector4d stopPositionsPack0: root.stopPositionsPack0
            property vector4d stopPositionsPack1: root.stopPositionsPack1

            vertexShader: "radial_gradient.vert.qsb"
            fragmentShader: "radial_gradient.frag.qsb"
        }
    }

    // Halftone gradient - no texture needed, purely procedural
    Loader {
        anchors.fill: parent
        active: root.gradientType === "halftone"

        sourceComponent: ShaderEffect {
            opacity: root.rectOpacity

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

    // Shadow effect
    layer.enabled: enableShadow
    layer.effect: Shadow {}

    // Border overlay to avoid ClippingRectangle artifacts
    ClippingRectangle {
        anchors.fill: parent
        radius: root.radius
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius
        color: "transparent"
        border.color: Config.resolveColor(borderData[0])
        border.width: borderData[1]
        visible: root.enableBorder
    }
}
