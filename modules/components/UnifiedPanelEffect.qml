pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.modules.theme

Item {
    id: root
    
    property Item sourceItem
    property Item maskSource
    property bool maskEnabled: false
    property bool maskInverted: false
    
    // GPU optimization: set to true only during animations
    property bool liveUpdate: false
    
    // Shadow parameters from Config
    property color shadowColor: Config.resolveColor(Config.theme.shadowColor)
    property real shadowOpacity: Config.theme.shadowOpacity
    property real shadowBlur: Config.theme.shadowBlur
    property real shadowXOffset: Config.theme.shadowXOffset
    property real shadowYOffset: Config.theme.shadowYOffset
    property bool drawSource: true
    
    // Border parameters from Config
    readonly property var borderData: Config.theme.srBg.border
    property color borderColor: Config.resolveColor(borderData[0])
    property real borderWidth: borderData[1]
    
    // Capture the mask
    ShaderEffectSource {
        id: maskEffectSource
        sourceItem: root.maskSource
        hideSource: true
        live: root.liveUpdate
        smooth: true
        visible: false
        enabled: root.maskEnabled && root.maskSource
        // textureSize removed to restore precision
    }

    // Capture the source item
    ShaderEffectSource {
        id: sourceEffectSource
        sourceItem: root.sourceItem
        hideSource: true
        live: root.liveUpdate
        smooth: true
        recursive: false // Proxy is used, recursion not needed
        // textureSize removed to restore precision
    }
    
    // Pass 1: Horizontal Blur
    ShaderEffect {
        id: pass1
        anchors.fill: parent
        visible: false // Only used as source for pass 2
        
        property var source: sourceEffectSource
        property real radius: Math.max(root.shadowBlur * 16.0, 1.0) // Restored radius multiplier
        property vector2d texelSize: Qt.vector2d(1.0 / width, 1.0 / height)
        
        vertexShader: "unified_pass1.vert.qsb"
        fragmentShader: "unified_pass1.frag.qsb"
    }
    
    ShaderEffectSource {
        id: intermediateSource
        sourceItem: pass1
        live: root.liveUpdate
        hideSource: false
        smooth: true
        // textureSize removed
    }
    
    // Pass 2: Vertical Blur + Dilation + Composition
    ShaderEffect {
        id: pass2
        anchors.fill: parent
        
        property var source: sourceEffectSource
        property var intermediate: intermediateSource
        property var maskSource: root.maskEnabled && root.maskSource ? maskEffectSource : sourceEffectSource
        
        property real radius: Math.max(root.shadowBlur * 16.0, 1.0) // Restored radius multiplier
        property vector2d texelSize: Qt.vector2d(1.0 / width, 1.0 / height)
        property real borderWidth: root.borderWidth // Restored border width
        property vector4d borderColor: {
            let c = root.borderColor;
            return Qt.vector4d(c.r * c.a, c.g * c.a, c.b * c.a, c.a);
        }
        property vector4d shadowColor: {
            let c = root.shadowColor;
            let a = c.a * root.shadowOpacity;
            return Qt.vector4d(c.r * a, c.g * a, c.b * a, a);
        }
        property vector2d shadowOffset: Qt.vector2d(root.shadowXOffset, root.shadowYOffset)
        
        property real maskEnabled: root.maskEnabled ? 1.0 : 0.0
        property real maskInverted: root.maskInverted ? 1.0 : 0.0
        property real drawSource: root.drawSource ? 1.0 : 0.0
        
        vertexShader: "unified_pass2.vert.qsb"
        fragmentShader: "unified_pass2.frag.qsb"
    }
}
