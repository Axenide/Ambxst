import QtQuick
import QtQuick.Controls
import QtQuick.Effects
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

        property int defaultRadius: Config.roundness > 0 ? (screenNotchOpen || hasActiveNotifications ? Config.roundness + 20 : Config.roundness + 4) : 0
        property int islandRadius: Config.roundness > 0 ? (screenNotchOpen || hasActiveNotifications ? Config.roundness + 20 : Config.roundness + 4) : 0

        property int topLeftRadius: Config.notchTheme === "default" ? (notchContainer.position === "bottom" ? defaultRadius : 0) : islandRadius
        property int topRightRadius: Config.notchTheme === "default" ? (notchContainer.position === "bottom" ? defaultRadius : 0) : islandRadius
        property int bottomLeftRadius: Config.notchTheme === "island" ? islandRadius : (notchContainer.position === "top" ? defaultRadius : 0)
        property int bottomRightRadius: Config.notchTheme === "island" ? islandRadius : (notchContainer.position === "top" ? defaultRadius : 0)

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

    // Unified outline canvas (single continuous stroke around silhouette)
    Canvas {
        id: outlineCanvas
        anchors.centerIn: parent
        width: parent.implicitWidth
        height: parent.implicitHeight
        z: 5000
        antialiasing: true
        
        readonly property var borderData: Config.theme.srBg.border
        readonly property int borderWidth: borderData[1]
        readonly property color borderColor: Config.resolveColor(borderData[0])
        
        visible: Config.notchTheme === "default" && borderWidth > 0
        
        onPaint: {
            if (Config.notchTheme !== "default")
                return; // Only draw for default theme
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            
            if (borderWidth <= 0)
                return; // No outline when borderWidth is 0
            
            ctx.strokeStyle = borderColor;
            ctx.lineWidth = borderWidth;
            ctx.lineJoin = "round";
            ctx.lineCap = "round";

            // Offset to move path inward by half the border width
            var offset = borderWidth / 2;
            
            // "Corner" radius (the smooth connection to the screen edge)
            var rCorner = Config.roundness > 0 ? Config.roundness + 4 : 0;
            var wCenter = notchRect.width;

            ctx.beginPath();

            if (notchContainer.position === "top") {
                var bl = notchRect.bottomLeftRadius;
                var br = notchRect.bottomRightRadius;
                var yBottom = height - offset;

                if (rCorner > 0) {
                    // Start at top-left, adjusted inward
                    ctx.moveTo(offset, offset);
                    // Left top corner arc - center at (offset, rCorner), radius reduced by offset
                    ctx.arc(offset, rCorner, rCorner - offset, 3 * Math.PI / 2, 2 * Math.PI);
                    // This ends at (rCorner, rCorner)
                } else {
                    ctx.moveTo(offset, offset);
                    ctx.lineTo(rCorner, rCorner);
                }
                // Left vertical line down
                ctx.lineTo(rCorner, yBottom - bl);
                // Bottom left corner
                if (bl > 0) {
                    ctx.arcTo(rCorner, yBottom, rCorner + bl, yBottom, bl - offset);
                }
                // Bottom horizontal line
                ctx.lineTo(rCorner + wCenter - br, yBottom);
                // Bottom right corner
                if (br > 0) {
                    ctx.arcTo(rCorner + wCenter, yBottom, rCorner + wCenter, yBottom - br, br - offset);
                }
                // Right vertical line up
                ctx.lineTo(rCorner + wCenter, rCorner);
                // Right top corner arc - center at (width - offset, rCorner), from 180° to 270°
                if (rCorner > 0) {
                    ctx.arc(width - offset, rCorner, rCorner - offset, Math.PI, 3 * Math.PI / 2);
                }
            } else { // Bottom position
                var tl = notchRect.topLeftRadius;
                var tr = notchRect.topRightRadius;
                var yTop = offset;
                var yBottom = height - offset;

                if (rCorner > 0) {
                    // Start at bottom-left
                    ctx.moveTo(offset, yBottom);
                    // Left bottom corner arc (concave)
                    ctx.arc(offset, height - rCorner, rCorner - offset, Math.PI / 2, 0, true); 
                    // Note: Canvas arc is clockwise by default. To emulate the "RoundCorner" feel (inverted), 
                    // we need to draw it such that it curves from (offset, yBottom) inwards to (rCorner, height-rCorner).
                    // Actually, let's mirror the top logic:
                    // Center at (offset, height - rCorner)
                    // Start angle: PI/2 (90 deg - bottom)
                    // End angle: 0 (0 deg - right)
                    // Counter-clockwise (true) to curve "in"
                } else {
                    ctx.moveTo(offset, yBottom);
                    ctx.lineTo(rCorner, height - rCorner);
                }
                
                // Left vertical line up
                ctx.lineTo(rCorner, yTop + tl);
                
                // Top left corner
                if (tl > 0) {
                    ctx.arcTo(rCorner, yTop, rCorner + tl, yTop, tl - offset);
                }
                
                // Top horizontal line
                ctx.lineTo(rCorner + wCenter - tr, yTop);
                
                // Top right corner
                if (tr > 0) {
                    ctx.arcTo(rCorner + wCenter, yTop, rCorner + wCenter, yTop + tr, tr - offset);
                }
                
                // Right vertical line down
                ctx.lineTo(rCorner + wCenter, height - rCorner);
                
                // Right bottom corner arc
                if (rCorner > 0) {
                     ctx.arc(width - offset, height - rCorner, rCorner - offset, Math.PI, Math.PI / 2, true);
                }
            }

            ctx.stroke();
        }
        Connections {
            target: Colors
            function onPrimaryChanged() {
                outlineCanvas.requestPaint();
            }
        }
        Connections {
            target: Config.theme.srBg
            function onBorderChanged() {
                outlineCanvas.requestPaint();
            }
        }
        Connections {
            target: notchRect
            function onBottomLeftRadiusChanged() {
                outlineCanvas.requestPaint();
            }
            function onBottomRightRadiusChanged() {
                outlineCanvas.requestPaint();
            }
            function onWidthChanged() {
                outlineCanvas.requestPaint();
            }
            function onHeightChanged() {
                outlineCanvas.requestPaint();
            }
        }
        Connections {
            target: notchContainer
            function onImplicitWidthChanged() {
                outlineCanvas.requestPaint();
            }
            function onImplicitHeightChanged() {
                outlineCanvas.requestPaint();
            }
        }
        Connections {
            target: Config
            function onNotchThemeChanged() {
                outlineCanvas.requestPaint();
            }
        }
        Connections {
            target: leftCornerMaskPart
            function onWidthChanged() {
                outlineCanvas.requestPaint();
            }
        }
        Connections {
            target: rightCornerMaskPart
            function onWidthChanged() {
                outlineCanvas.requestPaint();
            }
        }
    }
}
