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
    property Component dashboardViewComponent
    property Component overviewViewComponent
    property Component powermenuViewComponent
    property Component notificationViewComponent
    property var stackView: stackViewInternal
    property bool isExpanded: stackViewInternal.depth > 1
    property bool isHovered: false

    // Screen-specific visibility properties passed from parent
    property var visibilities
    readonly property bool screenNotchOpen: visibilities ? (visibilities.dashboard || visibilities.overview || visibilities.powermenu) : false
    readonly property bool hasActiveNotifications: Notifications.popupList.length > 0

    property int defaultHeight: Config.bar.showBackground ? (screenNotchOpen || hasActiveNotifications ? Math.max(stackContainer.height, 44) : 44) : (screenNotchOpen || hasActiveNotifications ? Math.max(stackContainer.height, 40) : 40)
    property int islandHeight: Config.bar.showBackground ? (screenNotchOpen || hasActiveNotifications ? Math.max(stackContainer.height, 40) : 40) : (screenNotchOpen || hasActiveNotifications ? Math.max(stackContainer.height, 36) : 36)

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

        property int defaultRadius: Config.roundness > 0 ? (screenNotchOpen || hasActiveNotifications ? Config.roundness + 20 : Config.roundness + 4) : 0

        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: defaultRadius
        bottomRightRadius: defaultRadius

        Behavior on radius {
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
        anchors.top: parent.top
        anchors.left: parent.left
        width: Config.notchTheme === "default" && Config.roundness > 0 ? Config.roundness + 4 : 0
        height: width

        RoundCorner {
            anchors.fill: parent
            corner: RoundCorner.CornerEnum.TopRight
            size: Math.max(parent.width, 1)
            color: "white"
        }
    }

        // Center rect mask
        Rectangle {
            id: centerMaskPart
            anchors.top: parent.top
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
        anchors.top: parent.top
        anchors.right: parent.right
        width: Config.notchTheme === "default" && Config.roundness > 0 ? Config.roundness + 4 : 0
        height: width

        RoundCorner {
            anchors.fill: parent
            corner: RoundCorner.CornerEnum.TopLeft
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

        property int topLeftRadius: Config.notchTheme === "default" ? 0 : islandRadius
        property int topRightRadius: Config.notchTheme === "default" ? 0 : islandRadius
        property int bottomLeftRadius: Config.notchTheme === "island" ? islandRadius : defaultRadius
        property int bottomRightRadius: Config.notchTheme === "island" ? islandRadius : defaultRadius

        // Fondo del notch solo para theme "island"
        StyledRect {
            variant: "bg"
            id: notchIslandBg
            visible: Config.notchTheme === "island"
            anchors.fill: parent
            layer.enabled: false
            clip: false // Desactivar clip para que no corte el border
            enableBorder: true // En island sí usar border de StyledRect
            
            // Usar el islandRadius como radius base también
            radius: parent.islandRadius

            topLeftRadius: parent.topLeftRadius
            topRightRadius: parent.topRightRadius
            bottomLeftRadius: parent.bottomLeftRadius
            bottomRightRadius: parent.bottomRightRadius
            
            Behavior on radius {
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
                anchors.margins: (screenNotchOpen || (Config.notchTheme === "island" && hasActiveNotifications)) ? 16 : 0
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
            
            var rTop = Config.roundness > 0 ? Config.roundness + 4 : 0;
            var bl = notchRect.bottomLeftRadius;
            var br = notchRect.bottomRightRadius;
            var wCenter = notchRect.width;
            var yBottom = height - 1 - offset;

            ctx.beginPath();
            if (rTop > 0) {
                // Start at top-left, adjusted inward
                ctx.moveTo(offset, offset);
                // Left top corner arc - center at (offset, rTop), radius reduced by offset
                ctx.arc(offset, rTop, rTop - offset, 3 * Math.PI / 2, 2 * Math.PI);
                // This ends at (rTop, rTop)
            } else {
                ctx.moveTo(offset, offset);
                ctx.lineTo(rTop, rTop);
            }
            // Left vertical line down
            ctx.lineTo(rTop, yBottom - bl);
            // Bottom left corner
            if (bl > 0) {
                ctx.arcTo(rTop, yBottom, rTop + bl, yBottom, bl - offset);
            }
            // Bottom horizontal line
            ctx.lineTo(rTop + wCenter - br, yBottom);
            // Bottom right corner
            if (br > 0) {
                ctx.arcTo(rTop + wCenter, yBottom, rTop + wCenter, yBottom - br, br - offset);
            }
            // Right vertical line up
            ctx.lineTo(rTop + wCenter, rTop);
            // Right top corner arc - center at (width - offset, rTop), from 180° to 270°
            if (rTop > 0) {
                ctx.arc(width - offset, rTop, rTop - offset, Math.PI, 3 * Math.PI / 2);
                // This ends at (width - offset - (rTop - offset), offset) = (width - rTop, offset)
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
