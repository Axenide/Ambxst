import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Shapes
import qs.modules.globals
import qs.modules.theme
import qs.modules.components
import qs.modules.corners
import qs.modules.services
import qs.config

Item {
    id: notchContainer

    z: 1000

    property Component defaultViewComponent
    property Component launcherViewComponent
    property Component dashboardViewComponent
    property Component powermenuViewComponent
    property Component toolsMenuViewComponent
    property Component notificationViewComponent
    property Component osdViewComponent
    property var stackView: stackViewInternal
    property bool isExpanded: stackViewInternal.depth > 1
    property bool isHovered: false

    // Screen-specific visibility properties passed from parent
    property var visibilities
    readonly property bool screenNotchOpen: visibilities ? (visibilities.launcher || visibilities.dashboard || visibilities.powermenu || visibilities.tools) : false
    readonly property bool hasActiveNotifications: Notifications.popupList.length > 0

    property int defaultHeight: Config.showBackground ? (screenNotchOpen || hasActiveNotifications ? Math.max(stackContainer.height, 44) : 44) : (screenNotchOpen || hasActiveNotifications ? Math.max(stackContainer.height, 40) : 40)
    property int islandHeight: screenNotchOpen || hasActiveNotifications ? Math.max(stackContainer.height, 36) : 36

    readonly property string position: Config.notchPosition ?? "top"

    // Corner size calculation for dynamic width (only for default theme)
    readonly property int cornerSize: Config.roundness > 0 ? Config.roundness + 4 : 0
    readonly property int totalCornerWidth: Config.notchTheme === "default" ? cornerSize * 2 : 0

    implicitWidth: screenNotchOpen 
        ? Math.max(stackContainer.width + totalCornerWidth, 290) 
        : stackContainer.width + totalCornerWidth
    implicitHeight: Config.notchTheme === "default" ? defaultHeight : (Config.notchTheme === "island" ? islandHeight : defaultHeight)

    Behavior on implicitWidth {
        enabled: (screenNotchOpen || stackViewInternal.busy) && Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: isExpanded ? Easing.OutBack : Easing.OutQuart
            easing.overshoot: isExpanded ? 1.2 : 1.0
        }
    }

    Behavior on implicitHeight {
        enabled: (screenNotchOpen || stackViewInternal.busy) && Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: isExpanded ? Easing.OutBack : Easing.OutQuart
            easing.overshoot: isExpanded ? 1.2 : 1.0
        }
    }

    // StyledRect extendido que cubre todo (notch + corners) para usar como máscara
    StyledRect {
        variant: "bg"
        id: notchFullBackground
        visible: Config.notchTheme === "default"
        anchors.centerIn: parent
        width: parent.implicitWidth
        height: parent.implicitHeight
        enabled: false // No interactuable
        enableBorder: false // No usar border de StyledRect, el Canvas se encarga
        animateRadius: false // Custom animation below

        property int defaultRadius: Config.roundness > 0 ? (screenNotchOpen || hasActiveNotifications ? Config.roundness + 20 : Config.roundness + 4) : 0

        topLeftRadius: notchContainer.position === "bottom" ? defaultRadius : 0
        topRightRadius: notchContainer.position === "bottom" ? defaultRadius : 0
        bottomLeftRadius: notchContainer.position === "top" ? defaultRadius : 0
        bottomRightRadius: notchContainer.position === "top" ? defaultRadius : 0

        Behavior on bottomLeftRadius {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: screenNotchOpen || hasActiveNotifications ? Easing.OutBack : Easing.OutQuart
                easing.overshoot: screenNotchOpen || hasActiveNotifications ? 1.2 : 1.0
            }
        }

        Behavior on bottomRightRadius {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: screenNotchOpen || hasActiveNotifications ? Easing.OutBack : Easing.OutQuart
                easing.overshoot: screenNotchOpen || hasActiveNotifications ? 1.2 : 1.0
            }
        }

        Behavior on topLeftRadius {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: screenNotchOpen || hasActiveNotifications ? Easing.OutBack : Easing.OutQuart
                easing.overshoot: screenNotchOpen || hasActiveNotifications ? 1.2 : 1.0
            }
        }

        Behavior on topRightRadius {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: screenNotchOpen || hasActiveNotifications ? Easing.OutBack : Easing.OutQuart
                easing.overshoot: screenNotchOpen || hasActiveNotifications ? 1.2 : 1.0
            }
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: notchFullMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }
    }

    // Máscara completa para el notch + corners
    Item {
        id: notchFullMask
        visible: false
        anchors.centerIn: parent
        width: parent.implicitWidth
        height: parent.implicitHeight
        layer.enabled: true
        layer.smooth: true

    // Left corner mask
    Item {
        id: leftCornerMaskPart
        anchors.top: notchContainer.position === "top" ? parent.top : undefined
        anchors.bottom: notchContainer.position === "bottom" ? parent.bottom : undefined
        anchors.left: parent.left
        width: Config.notchTheme === "default" && Config.roundness > 0 ? Config.roundness + 4 : 0
        height: width

        RoundCorner {
            anchors.fill: parent
            corner: notchContainer.position === "top" ? RoundCorner.CornerEnum.TopRight : RoundCorner.CornerEnum.BottomRight
            size: Math.max(parent.width, 1)
            color: "white"
        }
    }

        // Center rect mask
        Rectangle {
            id: centerMaskPart
            anchors.top: notchContainer.position === "top" ? parent.top : undefined
            anchors.bottom: notchContainer.position === "bottom" ? parent.bottom : undefined
            anchors.left: leftCornerMaskPart.right
            anchors.right: rightCornerMaskPart.left
            height: parent.height
            color: "white"

            topLeftRadius: notchRect.topLeftRadius
            topRightRadius: notchRect.topRightRadius
            bottomLeftRadius: notchRect.bottomLeftRadius
            bottomRightRadius: notchRect.bottomRightRadius
        }

    // Right corner mask
    Item {
        id: rightCornerMaskPart
        anchors.top: notchContainer.position === "top" ? parent.top : undefined
        anchors.bottom: notchContainer.position === "bottom" ? parent.bottom : undefined
        anchors.right: parent.right
        width: Config.notchTheme === "default" && Config.roundness > 0 ? Config.roundness + 4 : 0
        height: width

        RoundCorner {
            anchors.fill: parent
            corner: notchContainer.position === "top" ? RoundCorner.CornerEnum.TopLeft : RoundCorner.CornerEnum.BottomLeft
            size: Math.max(parent.width, 1)
            color: "white"
        }
    }
    }

    // Contenedor del notch (solo visual, sin fondo)
    Item {
        id: notchRect
        anchors.centerIn: parent
        width: parent.implicitWidth - totalCornerWidth
        height: parent.implicitHeight

    readonly property bool preventCornerChange: screenNotchOpen

        property int defaultRadius: Config.roundness > 0 ? (screenNotchOpen || (hasActiveNotifications && !preventCornerChange) ? Config.roundness + 20 : Config.roundness + 4) : 0
        property int islandRadius: Config.roundness > 0 ? (screenNotchOpen || (hasActiveNotifications && !preventCornerChange) ? Config.roundness + 20 : Config.roundness + 4) : 0

        property int topLeftRadius: Config.notchTheme === "default" 
            ? (notchContainer.position === "bottom" ? defaultRadius : 0) 
            : (notchContainer.position === "top" && (hasActiveNotifications && !preventCornerChange)
                ? (Config.roundness > 0 ? Config.roundness + 4 : 0)  // Small radius when at top with notifications
                : islandRadius)  // Otherwise use dynamic islandRadius
        property int topRightRadius: Config.notchTheme === "default" 
            ? (notchContainer.position === "bottom" ? defaultRadius : 0) 
            : (notchContainer.position === "top" && (hasActiveNotifications && !preventCornerChange)
                ? (Config.roundness > 0 ? Config.roundness + 4 : 0)  // Small radius when at top with notifications
                : islandRadius)  // Otherwise use dynamic islandRadius
        property int bottomLeftRadius: Config.notchTheme === "island" 
            ? (notchContainer.position === "bottom" && (hasActiveNotifications && !preventCornerChange)
                ? (Config.roundness > 0 ? Config.roundness + 4 : 0)  // Small radius when at bottom with notifications
                : islandRadius)  // Otherwise use dynamic islandRadius
            : (notchContainer.position === "top" ? defaultRadius : 0)
        property int bottomRightRadius: Config.notchTheme === "island" 
            ? (notchContainer.position === "bottom" && (hasActiveNotifications && !preventCornerChange)
                ? (Config.roundness > 0 ? Config.roundness + 4 : 0)  // Small radius when at bottom with notifications
                : islandRadius)  // Otherwise use dynamic islandRadius
            : (notchContainer.position === "top" ? defaultRadius : 0)

        // Fondo del notch solo para theme "island"
        StyledRect {
            variant: "bg"
            id: notchIslandBg
            visible: Config.notchTheme === "island"
            anchors.fill: parent
            layer.enabled: false
            clip: false // Desactivar clip para que no corte el border
            enableBorder: true // En island sí usar border de StyledRect
            animateRadius: false // Custom animation below
            
            // Usar el islandRadius como radius base también
            radius: parent.islandRadius

            topLeftRadius: parent.topLeftRadius
            topRightRadius: parent.topRightRadius
            bottomLeftRadius: parent.bottomLeftRadius
            bottomRightRadius: parent.bottomRightRadius
            
            Behavior on topLeftRadius {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration
                    easing.type: screenNotchOpen || hasActiveNotifications ? Easing.OutBack : Easing.OutQuart
                    easing.overshoot: screenNotchOpen || hasActiveNotifications ? 1.2 : 1.0
                }
            }

            Behavior on topRightRadius {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration
                    easing.type: screenNotchOpen || hasActiveNotifications ? Easing.OutBack : Easing.OutQuart
                    easing.overshoot: screenNotchOpen || hasActiveNotifications ? 1.2 : 1.0
                }
            }

            Behavior on bottomLeftRadius {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration
                    easing.type: screenNotchOpen || hasActiveNotifications ? Easing.OutBack : Easing.OutQuart
                    easing.overshoot: screenNotchOpen || hasActiveNotifications ? 1.2 : 1.0
                }
            }

            Behavior on bottomRightRadius {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration
                    easing.type: screenNotchOpen || hasActiveNotifications ? Easing.OutBack : Easing.OutQuart
                    easing.overshoot: screenNotchOpen || hasActiveNotifications ? 1.2 : 1.0
                }
            }
        }

        // HoverHandler para detectar hover sin bloquear eventos
        HoverHandler {
            id: notchHoverHandler
            enabled: true

            onHoveredChanged: {
                isHovered = hovered;
                if (stackViewInternal.currentItem && stackViewInternal.currentItem.hasOwnProperty("notchHovered")) {
                    stackViewInternal.currentItem.notchHovered = hovered;
                }
            }
        }

        Item {
            id: stackContainer
            anchors.centerIn: parent
            width: stackViewInternal.currentItem ? stackViewInternal.currentItem.implicitWidth + (screenNotchOpen ? 32 : 0) : (screenNotchOpen ? 32 : 0)
            height: stackViewInternal.currentItem ? stackViewInternal.currentItem.implicitHeight + (screenNotchOpen ? 32 : 0) : (screenNotchOpen ? 32 : 0)
            clip: true

            // Propiedad para controlar el blur durante las transiciones
            property real transitionBlur: 0.0

            // Aplicar MultiEffect con blur animable
            layer.enabled: transitionBlur > 0.0
            layer.effect: MultiEffect {
                blurEnabled: Config.performance.blurTransition
                blurMax: 64
                blur: Math.min(Math.max(stackContainer.transitionBlur, 0.0), 1.0)
            }

            // Animación simple de blur → nitidez durante transiciones
            PropertyAnimation {
                id: blurTransitionAnimation
                target: stackContainer
                property: "transitionBlur"
                from: 1.0
                to: 0.0
                duration: Config.animDuration
                easing.type: Easing.OutQuart
            }

            StackView {
                id: stackViewInternal
                anchors.fill: parent
                anchors.margins: screenNotchOpen ? 16 : 0
                initialItem: defaultViewComponent

                Component.onCompleted: {
                    isShowingDefault = true;
                    isShowingNotifications = false;
                }

                // Activar blur al inicio de transición y animarlo a nítido
                onBusyChanged: {
                    if (busy) {
                        stackContainer.transitionBlur = 1.0;
                        blurTransitionAnimation.start();
                    }
                }

                pushEnter: Transition {
                    PropertyAnimation {
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                    PropertyAnimation {
                        property: "scale"
                        from: 0.8
                        to: 1
                        duration: Config.animDuration
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.2
                    }
                }

                pushExit: Transition {
                    PropertyAnimation {
                        property: "opacity"
                        from: 1
                        to: 0
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                    PropertyAnimation {
                        property: "scale"
                        from: 1
                        to: 1.05
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                }

                popEnter: Transition {
                    PropertyAnimation {
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                    PropertyAnimation {
                        property: "scale"
                        from: 1.05
                        to: 1
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                }

                popExit: Transition {
                    PropertyAnimation {
                        property: "opacity"
                        from: 1
                        to: 0
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                    PropertyAnimation {
                        property: "scale"
                        from: 1
                        to: 0.95
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                }

                replaceEnter: Transition {
                    PropertyAnimation {
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                    PropertyAnimation {
                        property: "scale"
                        from: 0.8
                        to: 1
                        duration: Config.animDuration
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.2
                    }
                }

                replaceExit: Transition {
                    PropertyAnimation {
                        property: "opacity"
                        from: 1
                        to: 0
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                    PropertyAnimation {
                        property: "scale"
                        from: 1
                        to: 1.05
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                }
            }
        }
    }

    // Propiedades para mejorar el control del estado de las vistas
    property bool isShowingNotifications: false
    property bool isShowingDefault: false

    // Unified outline shape (single continuous stroke)
    Shape {
        id: outlineShape
        anchors.fill: parent
        z: 5000
        visible: Config.notchTheme === "default" && borderWidth > 0
        
        readonly property var borderData: Config.theme.srBg.border
        readonly property int borderWidth: borderData[1]
        readonly property color borderColor: Config.resolveColor(borderData[0])
        
        readonly property real offset: borderWidth / 2
        
        // "Corner" radius (the smooth connection to the screen edge)
        readonly property real rCorner: Config.roundness > 0 ? Config.roundness + 4 : 0
        readonly property real wCenter: notchRect.width
        
        // Adjusted radii for the path (inner radius of the stroke)
        readonly property real bl: Math.max(0, notchRect.bottomLeftRadius - offset)
        readonly property real br: Math.max(0, notchRect.bottomRightRadius - offset)
        readonly property real tl: Math.max(0, notchRect.topLeftRadius - offset)
        readonly property real tr: Math.max(0, notchRect.topRightRadius - offset)
        
        // Connection corner radius
        readonly property real rc: Math.max(0, rCorner - offset)
        
        readonly property real yBottom: height - offset
        readonly property real yTop: offset

        // ShapePath for Position "Top"
        ShapePath {
            // Using logic binding for visibility to avoid painting when not needed
            strokeWidth: outlineShape.borderWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            
            // Only visible when position is top
            
            // We can't easily toggle "visible" on ShapePath, but if the Shape is visible, it draws all paths.
            // We can move the startX/Y to something offscreen or make color transparent? 
            // Actually, let's use strokeColor: visible ? color : "transparent"
            strokeColor: notchContainer.position === "top" ? outlineShape.borderColor : "transparent"
            
            startX: outlineShape.offset
            startY: outlineShape.offset
            
            // Top Left Connection
            PathArc {
                x: outlineShape.rCorner
                y: outlineShape.rCorner
                radiusX: outlineShape.rc
                radiusY: outlineShape.rc
                useLargeArc: false
                direction: PathArc.Clockwise
            }
            
            // Left Vertical Line
            PathLine {
                x: outlineShape.rCorner
                y: outlineShape.yBottom - outlineShape.bl
            }
            
            // Bottom Left Corner
            PathArc {
                x: outlineShape.rCorner + outlineShape.bl
                y: outlineShape.yBottom
                radiusX: outlineShape.bl
                radiusY: outlineShape.bl
                useLargeArc: false
                direction: PathArc.CounterClockwise
            }
            
            // Bottom Horizontal Line
            PathLine {
                x: outlineShape.rCorner + outlineShape.wCenter - outlineShape.br
                y: outlineShape.yBottom
            }
            
            // Bottom Right Corner
            PathArc {
                x: outlineShape.rCorner + outlineShape.wCenter
                y: outlineShape.yBottom - outlineShape.br
                radiusX: outlineShape.br
                radiusY: outlineShape.br
                useLargeArc: false
                direction: PathArc.CounterClockwise
            }
            
            // Right Vertical Line
            PathLine {
                x: outlineShape.rCorner + outlineShape.wCenter
                y: outlineShape.rCorner
            }
            
            // Top Right Connection
            PathArc {
                x: parent.width - outlineShape.offset
                y: outlineShape.offset
                radiusX: outlineShape.rc
                radiusY: outlineShape.rc
                useLargeArc: false
                direction: PathArc.Clockwise
            }
        }

        // ShapePath for Position "Bottom"
        ShapePath {
            strokeWidth: outlineShape.borderWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            
            strokeColor: notchContainer.position === "bottom" ? outlineShape.borderColor : "transparent"
            
            startX: outlineShape.offset
            startY: outlineShape.yBottom
            
            // Bottom Left Connection
            PathArc {
                x: outlineShape.rCorner
                y: parent.height - outlineShape.rCorner
                radiusX: outlineShape.rc
                radiusY: outlineShape.rc
                useLargeArc: false
                direction: PathArc.CounterClockwise
            }
            
            // Left Vertical Line Up
            PathLine {
                x: outlineShape.rCorner
                y: outlineShape.yTop + outlineShape.tl
            }
            
            // Top Left Corner
            PathArc {
                x: outlineShape.rCorner + outlineShape.tl
                y: outlineShape.yTop
                radiusX: outlineShape.tl
                radiusY: outlineShape.tl
                useLargeArc: false
                direction: PathArc.Clockwise
            }
            
            // Top Horizontal Line
            PathLine {
                x: outlineShape.rCorner + outlineShape.wCenter - outlineShape.tr
                y: outlineShape.yTop
            }
            
            // Top Right Corner
            PathArc {
                x: outlineShape.rCorner + outlineShape.wCenter
                y: outlineShape.yTop + outlineShape.tr
                radiusX: outlineShape.tr
                radiusY: outlineShape.tr
                useLargeArc: false
                direction: PathArc.Clockwise
            }
            
            // Right Vertical Line Down
            PathLine {
                x: outlineShape.rCorner + outlineShape.wCenter
                y: parent.height - outlineShape.rCorner
            }
            
            // Bottom Right Connection
            PathArc {
                x: parent.width - outlineShape.offset
                y: parent.height - outlineShape.offset
                radiusX: outlineShape.rc
                radiusY: outlineShape.rc
                useLargeArc: false
                direction: PathArc.CounterClockwise
            }
        }
    }
}
