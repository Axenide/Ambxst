import QtQuick
import QtQuick.Effects
import qs.modules.theme
import qs.modules.corners
import qs.config

Rectangle {
    id: root
    required property string position
    
    readonly property bool effectiveContainBar: Config.bar.containBar && (Config.bar.frameEnabled ?? false)

    visible: Config.showBackground && (!effectiveContainBar || Config.bar.keepBarShadow)
    color: "black"
    radius: effectiveContainBar ? Styling.radius(4) : 0

    layer.enabled: true
    layer.smooth: true
    layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: root
        maskInverted: true
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
        shadowEnabled: true
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 0
        shadowBlur: 1
        shadowColor: Config.resolveColor(Config.theme.shadowColor)
        shadowOpacity: Config.theme.shadowOpacity
    }

    RoundCorner {
        id: shadowCornerLeft
        visible: Config.theme.enableCorners && !effectiveContainBar
        size: Config.roundness > 0 ? Config.roundness + 4 : 0
        x: root.position === "left" ? parent.width : (root.position === "right" ? -size : 0)
        y: root.position === "top" ? parent.height : (root.position === "bottom" ? -size : 0)
        corner: {
            if (root.position === "top") return RoundCorner.CornerEnum.TopLeft
            if (root.position === "bottom") return RoundCorner.CornerEnum.BottomLeft
            if (root.position === "left") return RoundCorner.CornerEnum.TopLeft
            if (root.position === "right") return RoundCorner.CornerEnum.TopRight
        }
        color: parent.color
    }

    RoundCorner {
        id: shadowCornerRight
        visible: Config.theme.enableCorners && !effectiveContainBar
        size: Config.roundness > 0 ? Config.roundness + 4 : 0
        x: root.position === "left" ? parent.width : (root.position === "right" ? -size : parent.width - size)
        y: root.position === "top" ? parent.height : (root.position === "bottom" ? -size : parent.height - size)
        corner: {
            if (root.position === "top") return RoundCorner.CornerEnum.TopRight
            if (root.position === "bottom") return RoundCorner.CornerEnum.BottomRight
            if (root.position === "left") return RoundCorner.CornerEnum.BottomLeft
            if (root.position === "right") return RoundCorner.CornerEnum.BottomRight
        }
        color: parent.color
    }
}
