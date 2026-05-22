import QtQuick

// GPU-native CircularWavyProgress — renderizado 100% GPU via ShaderEffect.
// Las propiedades SON los uniforms del shader (ubuf.{} en circular_wavy.frag).
// Animación via NumberAnimation, sin Timer, sin requestPaint, sin grabToImage.
ShaderEffect {
    id: root

    // ── Uniformes del shader (nombres exactos = ubuf.{nombre}) ──
    property real radius: 0.45              // Normalizado 0.0-0.5 en UV space
    property real startAngle: Math.PI       // Radianes, 180° = lado izquierdo
    property real progressAngle: Math.PI    // Span en radianes
    property real amplitude: 0.01           // Normalizado al radio
    property real frequency: 20
    property real thickness: 0.02           // Normalizado en UV space
    property real pixelSize: 1.0 / Math.max(1, Math.min(width, height))
    property vector4d color: Qt.vector4d(1, 1, 1, 1)

    // ── Control de animación ──
    property bool animating: false
    property real animationSpeed: 1.0       // radianes/s

    readonly property bool _shouldAnimate: animating && visible && width > 0 && height > 0

    // ── Fase animada — cuando running=false, respeta el valor externo ──
    property real phase: 0.0

    NumberAnimation on phase {
        from: 0
        to: Math.PI * 2
        duration: {
            var period = Math.PI * 2 / Math.max(0.001, root.animationSpeed);
            return Math.max(1, period * 1000);
        }
        loops: Animation.Infinite
        running: root._shouldAnimate
    }

    vertexShader: "circular_wavy.vert.qsb"
    fragmentShader: "circular_wavy.frag.qsb"
}
