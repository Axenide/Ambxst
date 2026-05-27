import QtQuick
import qs.modules.theme

// GPU-native WavyLine — reemplaza el Canvas + JS Math.sin loop por ShaderEffect con GLSL.
// La animación y la geometría de la onda corren 100% en la GPU, sin consumo de CPU.
ShaderEffect {
    id: root

    // =========================================================================
    // API Properties (misma interfaz que la versión Canvas)
    // =========================================================================
    property color color: Styling.srItem("overprimary")
    property real lineWidth: 2
    property real frequency: 2
    property real amplitudeMultiplier: 0.5
    property real fullLength: width
    property bool running: true

    // Legacy compatibility
    property real speed: 5  // Kept for API compat
    property bool animationsEnabled: true

    // =========================================================================
    // Animación de fase — property animada por NumberAnimation
    // =========================================================================
    readonly property bool shouldAnimate: running && animationsEnabled &&
                                          visible && width > 0 && opacity > 0

    property real _phase: 0

    NumberAnimation on _phase {
        id: phaseAnim
        from: 0
        to: Math.PI * 2
        duration: 1600
        loops: Animation.Infinite
        running: root.shouldAnimate
    }

    // =========================================================================
    // Unficos de entrada al shader
    // Nombres exactos = ubuf.{nombre} en el GLSL wavyline.frag
    // =========================================================================
    property real phase: _phase
    property real amplitude: lineWidth * amplitudeMultiplier
    property vector4d shaderColor: Qt.vector4d(color.r, color.g, color.b, color.a)
    property real canvasWidth: width
    property real canvasHeight: height

    vertexShader: "wavyline.vert.qsb"
    fragmentShader: "wavyline.frag.qsb"
}
