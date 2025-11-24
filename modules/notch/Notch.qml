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
    property int islandHeight: Config.bar.showBackground ? (screenNotchOpen || hasActiveNotifications ? Math.max(stackContainer.height, 36) : 36) : (screenNotchOpen || hasActiveNotifications ? Math.max(stackContainer.height, 36) : 36)

    implicitWidth: screenNotchOpen ? Math.max(stackContainer.width + 40, 290) : stackContainer.width + 24
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

    // Corner fills (keep for shape background). Their previous per-corner stroke canvases were removed.
    Item {
        id: leftCorner
        visible: Config.notchTheme === "default"
        anchors.top: parent.top
        anchors.right: notchRect.left
        width: size
        height: size
        property int size: Config.roundness > 0 ? Config.roundness + 4 : 0
        clip: true

        BgRect {
            id: leftCornerBg
            anchors.top: parent.top
            anchors.left: parent.left
            width: parent.width
            height: notchRect.height
            radius: 0
            border.width: 0
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: leftCornerMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }
        }

        Item {
            id: leftCornerMask
            anchors.top: parent.top
            anchors.left: parent.left
            width: parent.width
            height: notchRect.height
            visible: false
            layer.enabled: true
            layer.smooth: true

            RoundCorner {
                anchors.top: parent.top
                anchors.left: parent.left
                width: parent.width
                height: parent.width
                corner: RoundCorner.CornerEnum.TopRight
                size: parent.width
                color: "white"
            }
        }
    }

    BgRect {
        id: notchRect
        anchors.centerIn: parent
        width: parent.implicitWidth - 40
        height: parent.implicitHeight
        layer.enabled: false
        radius: 0
        border.width: Config.notchTheme === "default" ? 0 : Config.theme.borderSize

        property int defaultRadius: Config.roundness > 0 ? (screenNotchOpen || hasActiveNotifications ? Config.roundness + 20 : Config.roundness + 4) : 0
        property int islandRadius: Config.roundness > 0 ? (screenNotchOpen || hasActiveNotifications ? Config.roundness + 20 : Config.roundness) : 0

        topLeftRadius: Config.notchTheme === "default" ? 0 : (Config.notchTheme === "island" ? islandRadius : 0)
        topRightRadius: Config.notchTheme === "default" ? 0 : (Config.notchTheme === "island" ? islandRadius : 0)
        bottomLeftRadius: Config.notchTheme === "island" ? islandRadius : defaultRadius
        bottomRightRadius: Config.notchTheme === "island" ? islandRadius : defaultRadius
        clip: true

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

        Behavior on radius {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: screenNotchOpen || hasActiveNotifications ? Easing.OutBack : Easing.OutQuart
                easing.overshoot: screenNotchOpen || hasActiveNotifications ? 1.2 : 1.0
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

    Item {
        id: rightCorner
        visible: Config.notchTheme === "default"
        anchors.top: parent.top
        anchors.left: notchRect.right
        width: size
        height: size
        property int size: Config.roundness > 0 ? Config.roundness + 4 : 0
        clip: true

        BgRect {
            id: rightCornerBg
            anchors.top: parent.top
            anchors.right: parent.right
            width: parent.width
            height: notchRect.height
            radius: 0
            border.width: 0
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: rightCornerMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }
        }

        Item {
            id: rightCornerMask
            anchors.top: parent.top
            anchors.right: parent.right
            width: parent.width
            height: notchRect.height
            visible: false
            layer.enabled: true
            layer.smooth: true

            RoundCorner {
                anchors.top: parent.top
                anchors.right: parent.right
                width: parent.width
                height: parent.width
                corner: RoundCorner.CornerEnum.TopLeft
                size: parent.width
                color: "white"
            }
        }
    }

    // Unified outline canvas (single continuous stroke around silhouette)
    Canvas {
        id: outlineCanvas
        anchors.top: parent.top
        anchors.left: leftCorner.visible ? leftCorner.left : notchRect.left
        width: (Config.notchTheme === "default" && leftCorner.visible && rightCorner.visible) ? leftCorner.width + notchRect.width + rightCorner.width : notchRect.width
        height: notchRect.height
        z: 5000
        antialiasing: true
        visible: Config.notchTheme === "default" && Config.theme.borderSize > 0
        onPaint: {
            if (Config.notchTheme !== "default")
                return; // Only draw for default theme
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            // Resolve dynamic border color from config (HEX or named color)
            var colorKey = Config.theme.borderColor || "primary";
            var strokeColor = Config.resolveColor(colorKey);
            if (Config.theme.borderSize <= 0)
                return; // No outline when borderSize is 0
            ctx.strokeStyle = strokeColor;
            ctx.lineWidth = Config.theme.borderSize;
            ctx.lineJoin = "round";
            ctx.lineCap = "round";

            var rTop = leftCorner.visible ? leftCorner.size : 0;
            var bl = notchRect.bottomLeftRadius;
            var br = notchRect.bottomRightRadius;
            var wCenter = notchRect.width;
            var yBottom = height - 1;

            ctx.beginPath();
            if (rTop > 0) {
                ctx.moveTo(0, 0);
                ctx.arc(0, rTop, rTop, 3 * Math.PI / 2, 2 * Math.PI); // to (rTop, rTop)
            } else {
                ctx.moveTo(0, 0);
                ctx.lineTo(rTop, rTop);
            }
            ctx.lineTo(rTop, yBottom - bl);
            if (bl > 0) {
                ctx.arcTo(rTop, yBottom, rTop + bl, yBottom, bl);
            }
            ctx.lineTo(rTop + wCenter - br, yBottom);
            if (br > 0) {
                ctx.arcTo(rTop + wCenter, yBottom, rTop + wCenter, yBottom - br, br);
            }
            ctx.lineTo(rTop + wCenter, rTop);
            if (rTop > 0) {
                ctx.arc(rTop + wCenter + rTop, rTop, rTop, Math.PI, 3 * Math.PI / 2);
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
            target: Config.theme
            function onBorderSizeChanged() {
                outlineCanvas.requestPaint();
            }
            function onBorderColorChanged() {
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
            function onTopLeftRadiusChanged() {
                outlineCanvas.requestPaint();
            }
            function onTopRightRadiusChanged() {
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
            target: leftCorner
            function onSizeChanged() {
                outlineCanvas.requestPaint();
            }
        }
        Connections {
            target: rightCorner
            function onSizeChanged() {
                outlineCanvas.requestPaint();
            }
        }
    }
}
