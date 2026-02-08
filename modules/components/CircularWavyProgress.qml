import QtQuick
import QtQuick.Controls

Item {
    id: root
    
    // -- Geometry (Normalized 0.0 - 1.0 relative to width/height) --
    property real radius: 0.45
    property real startAngleRad: Math.PI // Default 180 deg
    property real progressAngleRad: Math.PI // Default 180 deg span
    
    // -- Wave --
    property real amplitude: 0.01
    property real frequency: 20
    property real phase: 0.0
    property real thickness: 0.02
    property color color: "white"
    
    // GPU optimization: only enable layer when animating
    property bool animating: amplitude > 0
    
    // -- Internal --
    readonly property real supersample: 2.0 // 2x is usually sufficient for high DPI, 4x if needed
    
    Item {
        anchors.fill: parent
        
        ShaderEffect {
            id: shader
            width: root.width * root.supersample
            height: root.height * root.supersample
            scale: 1.0 / root.supersample
            transformOrigin: Item.TopLeft
            
            // Uniforms
            property real radius: root.radius
            property real startAngle: root.startAngleRad
            property real progressAngle: root.progressAngleRad
            property real amplitude: root.amplitude
            property real frequency: root.frequency
            property real phase: root.phase
            property real thickness: root.thickness
            property real pixelSize: 1.0 / width // Pass pixel size for AA fallback
            property vector4d color: Qt.vector4d(root.color.r, root.color.g, root.color.b, root.color.a)
            
            fragmentShader: "circular_wavy.frag.qsb"
            vertexShader: "circular_wavy.vert.qsb"
            
            // Layering for smooth downscaling - conditional for GPU optimization
            layer.enabled: root.animating
            layer.smooth: true
            layer.mipmap: root.animating
            layer.textureSize: Qt.size(width, height)
        }
    }
}
