import QtQuick
import qs.config
import qs.modules.theme

Item {
    id: root
    property real amplitudeMultiplier: 0.5
    property real frequency: 6
    property color color: Styling.srItem("overprimary")
    property real lineWidth: 4
    property real fullLength: width
    property real speed: 2.4

    // Factor de supersampling optimizado
    readonly property real supersampleFactor: 2.0

    // Control for animations - can be disabled from parent to save GPU
    property bool animationsEnabled: true

    layer.enabled: true
    layer.smooth: true
    layer.samples: 4  // MSAA para el layer principal

    // Contenedor para el shader renderizado a mayor resolución
    Item {
        id: shaderContainer
        anchors.fill: parent
        visible: Config.performance.wavyLine

        ShaderEffect {
            id: wavyShader
            // Renderizar a 4x la resolución
            width: root.width * root.supersampleFactor
            height: root.height * root.supersampleFactor

            // Escalar hacia abajo al tamaño original
            scale: 1.0 / root.supersampleFactor
            transformOrigin: Item.TopLeft

            property real phase: 0
            property real amplitude: root.lineWidth * root.amplitudeMultiplier * root.supersampleFactor
            property real frequency: root.frequency
            property vector4d shaderColor: Qt.vector4d(root.color.r, root.color.g, root.color.b, root.color.a)
            property real lineWidth: root.lineWidth * root.supersampleFactor
            property real canvasWidth: root.width * root.supersampleFactor
            property real canvasHeight: root.height * root.supersampleFactor
            property real fullLength: root.fullLength * root.supersampleFactor

            vertexShader: Qt.resolvedUrl("wavyline.vert.qsb")
            fragmentShader: Qt.resolvedUrl("wavyline.frag.qsb")

            smooth: true
            antialiasing: true
            blending: true  // Habilitar blending para mejor antialiasing

            // Layer con MSAA y tamaño completo
            layer.enabled: true
            layer.smooth: true
            layer.samples: 4  // Multisampling antialiasing
            layer.textureSize: Qt.size(width, height)
            layer.mipmap: true

            Component.onCompleted: {
                if (Config.performance.wavyLine) {
                    animationFrameAnimation.start();
                }
            }

            FrameAnimation {
                id: animationFrameAnimation
                running: Config.performance.wavyLine && wavyShader.visible && root.visible && root.animationsEnabled
                onTriggered: {
                    var deltaTime = 0.016; // ~60fps default
                    wavyShader.phase += root.speed * deltaTime;
                }
            }
        }
    }

    Rectangle {
        id: simpleRect
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 4
        visible: !Config.performance.wavyLine
        color: root.color
        radius: 2
    }

    function requestPaint() {
    // Mantenido por compatibilidad
    }
}
