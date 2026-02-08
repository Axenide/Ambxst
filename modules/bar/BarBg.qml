import QtQuick
import QtQuick.Effects
import qs.modules.theme
import qs.modules.corners
import qs.modules.components
import qs.config

Item {
    id: root
    required property string position

    default property alias content: contentContainer.data

    // Item should be always visible to allow children (widgets) to render
    // even if background is hidden.
    visible: true

    readonly property bool effectiveContainBar: Config.bar.containBar && (Config.bar.frameEnabled ?? false)

    // Corner size logic: only when at the very edge (no margins)
    readonly property int cornerSize: (Config.theme.enableCorners && !effectiveContainBar && root.outerMargin === 0) ? Styling.radius(4) : 0
    readonly property bool isHorizontal: position === "top" || position === "bottom"
    readonly property bool cornersVisible: Config.theme.enableCorners && cornerSize > 0

    // New logic: padding 4 if opaque (>1%), 0 if transparent
    readonly property real bgOpacity: Config.theme.srBarBg.opacity
    readonly property int padding: bgOpacity < 0.01 ? 0 : 4

    // Combined outer margin for screen/frame edges
    // This margin (4px) should only exist when bar is floating (!effectiveContainBar)
    readonly property int outerMargin: !effectiveContainBar ? 4 : 0

    // StyledRect expanded that covers bar + corners
    StyledRect {
        id: barBackground
        variant: "barbg"
        visible: Config.showBackground
        radius: Styling.radius(effectiveContainBar ? 4 : 0)
        enableBorder: true

        // Position and size expanded to cover corners
        x: (position === "right") ? -cornerSize : 0
        y: (position === "bottom") ? -cornerSize : 0
        width: root.width + (isHorizontal ? 0 : cornerSize)
        height: root.height + (isHorizontal ? cornerSize : 0)

        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: barMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }
    }

    Item {
        id: contentContainer
        anchors.fill: parent
        anchors.margins: root.padding
    }

    // Mascara combinada para la bar + corners
    Item {
        id: barMask
        visible: false
        x: barBackground.x
        y: barBackground.y
        width: barBackground.width
        height: barBackground.height
        layer.enabled: true
        layer.smooth: true

        // Rectangulo central (la bar misma)
        Rectangle {
            id: centerMask
            color: "white"
            x: root.position === "right" ? cornerSize : 0
            y: root.position === "bottom" ? cornerSize : 0
            width: root.width
            height: root.height
        }

        // Corner izquierdo/superior
        Item {
            id: cornerLeftMask
            width: cornerSize
            height: cornerSize

            states: [
                State {
                    name: "top"
                    when: root.position === "top"
                    PropertyChanges {
                        target: cornerLeftMask
                        x: 0
                        y: root.height
                    }
                },
                State {
                    name: "bottom"
                    when: root.position === "bottom"
                    PropertyChanges {
                        target: cornerLeftMask
                        x: 0
                        y: 0
                    }
                },
                State {
                    name: "left"
                    when: root.position === "left"
                    PropertyChanges {
                        target: cornerLeftMask
                        x: root.width
                        y: 0
                    }
                },
                State {
                    name: "right"
                    when: root.position === "right"
                    PropertyChanges {
                        target: cornerLeftMask
                        x: 0
                        y: 0
                    }
                }
            ]

            RoundCorner {
                anchors.fill: parent
                corner: {
                    if (root.position === "top")
                        return RoundCorner.CornerEnum.TopLeft;
                    if (root.position === "bottom")
                        return RoundCorner.CornerEnum.BottomLeft;
                    if (root.position === "left")
                        return RoundCorner.CornerEnum.TopLeft;
                    if (root.position === "right")
                        return RoundCorner.CornerEnum.TopRight;
                }
                size: Math.max(cornerSize, 1)
                color: "white"
            }
        }

        // Corner derecho/inferior
        Item {
            id: cornerRightMask
            width: cornerSize
            height: cornerSize

            states: [
                State {
                    name: "top"
                    when: root.position === "top"
                    PropertyChanges {
                        target: cornerRightMask
                        x: root.width - cornerSize
                        y: root.height
                    }
                },
                State {
                    name: "bottom"
                    when: root.position === "bottom"
                    PropertyChanges {
                        target: cornerRightMask
                        x: root.width - cornerSize
                        y: 0
                    }
                },
                State {
                    name: "left"
                    when: root.position === "left"
                    PropertyChanges {
                        target: cornerRightMask
                        x: root.width
                        y: root.height - cornerSize
                    }
                },
                State {
                    name: "right"
                    when: root.position === "right"
                    PropertyChanges {
                        target: cornerRightMask
                        x: 0
                        y: root.height - cornerSize
                    }
                }
            ]

            RoundCorner {
                anchors.fill: parent
                corner: {
                    if (root.position === "top")
                        return RoundCorner.CornerEnum.TopRight;
                    if (root.position === "bottom")
                        return RoundCorner.CornerEnum.BottomRight;
                    if (root.position === "left")
                        return RoundCorner.CornerEnum.BottomLeft;
                    if (root.position === "right")
                        return RoundCorner.CornerEnum.BottomRight;
                }
                size: Math.max(cornerSize, 1)
                color: "white"
            }
        }
    }
}
