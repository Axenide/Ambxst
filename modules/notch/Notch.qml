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

    property bool unifiedEffectActive: false
    z: 1000
    clip: true

    // Scale applied via transform, not layout, to keep edge alignment
    transform: Scale {
        id: notchScale
        origin.x: notchContainer.width / 2
        origin.y: notchContainer.position === "top" ? 0 : notchContainer.height
        xScale: 1.0
        yScale: animScale
    }

    property real animScale: screenNotchOpen ? 1.0 : 0.9
    Behavior on animScale {
        enabled: Anim.animationsEnabled
        NumberAnimation {
            duration: Anim.standardNormal
            easing.type: Anim.springSnappy().type
            easing.bezierCurve: Anim.springSnappy().bezierCurve
        }
    }

    property Component defaultViewComponent
    property Component launcherViewComponent
    property Component dashboardViewComponent
    property Component powermenuViewComponent
    property Component toolsMenuViewComponent
    property Component notificationViewComponent
    property var stackView: stackViewInternal
    property bool isExpanded: stackViewInternal.depth > 1
    property bool parentHovered: false
    property bool isHovered: false

    onParentHoveredChanged: updateChildHover()
    onIsHoveredChanged: updateChildHover()

    function updateChildHover() {
        if (stackViewInternal.currentItem) {
            const h = isHovered || parentHovered;
            if (stackViewInternal.currentItem.hasOwnProperty("notchHovered")) {
                stackViewInternal.currentItem.notchHovered = h;
            }
            if (stackViewInternal.currentItem.hasOwnProperty("parentHoverActive")) {
                stackViewInternal.currentItem.parentHoverActive = h;
            }
        }
    }

    // Screen-specific visibility properties passed from parent
    property var visibilities
    readonly property bool screenNotchOpen: visibilities ? (visibilities.launcher || visibilities.dashboard || visibilities.powermenu || visibilities.tools) : false
    readonly property bool hasActiveNotifications: Notifications.popupList.length > 0

    property int defaultHeight: Config.showBackground ? (screenNotchOpen || hasActiveNotifications ? Math.max(stackContainer.height, 44) : 44) : (screenNotchOpen || hasActiveNotifications ? Math.max(stackContainer.height, 40) : 40)
    property int compactHeight: 36
    property int islandHeight: screenNotchOpen || hasActiveNotifications ? Math.max(stackContainer.height, compactHeight) : compactHeight

    // Force exact button height in island mode when idle
    readonly property bool _forceCompact: Config.notchTheme === "island" && !screenNotchOpen && !hasActiveNotifications

    readonly property string position: Config.notchPosition ?? "top"
    // Bar position for merging island with bar
    readonly property string barPosition: (Config.bar && Config.bar.position !== undefined) ? Config.bar.position : "top"
    // When island theme and same position as bar, offset from bar edge instead of screen edge
    readonly property bool mergeWithBar: Config.notchTheme === "island" && root.position === root.barPosition && (Config.bar && Config.bar.barMode === "dynamic")

    // Corner size calculation for dynamic width (only for default theme)
    readonly property int cornerSize: Config.roundness > 0 ? Config.roundness + 4 : 0
    readonly property int totalCornerWidth: Config.notchTheme === "default" ? cornerSize * 2 : 0

    // Island theme: centered on the bar like Dynamic Island
    anchors.horizontalCenter: Config.notchTheme === "island" ? parent.horizontalCenter : undefined

    implicitWidth: {
        let w = screenNotchOpen ? Math.max(stackContainer.width + totalCornerWidth, 290) : stackContainer.width + totalCornerWidth;
        // When merged with bar, cap width to not overflow bar bounds
        if (root.mergeWithBar && root.maxIslandWidth > 0) {
            w = Math.min(w, root.maxIslandWidth);
        }
        return w;
    }
    implicitHeight: Config.notchTheme === "default" ? defaultHeight
        : (Config.notchTheme === "island" ? (_forceCompact ? compactHeight : islandHeight)
        : defaultHeight)
    // When island merges with bar: notch IS part of the bar
    // Position at bar level with margins to not overlap buttons
    y: root.mergeWithBar ? (root.position === "top" ? 2 : parent.height - root.implicitHeight - 2) : 0
    // Match bar size when merged
    readonly property int maxIslandWidth: root.mergeWithBar ? (parent ? Math.min(parent.width, 400) : 400) : (parent ? Math.min(parent.width * 0.85, 600) : 600)
    // When merged, make the background transparent so bar bg shows through
    readonly property bool sectionInvisible: root.mergeWithBar && !root.screenNotchOpen && !root.hasActiveNotifications

    Behavior on implicitWidth {
        enabled: (screenNotchOpen || stackViewInternal.busy) && Anim.animationsEnabled
        NumberAnimation {
            property var _ease: isExpanded ? Anim.springSnappy() : Anim.easing("standard")
            duration: isExpanded ? Anim.emphasizedNormal : Anim.standardNormal
            easing.type: _ease.type
            easing.bezierCurve: _ease.bezierCurve
        }
    }

    Behavior on implicitHeight {
        enabled: (screenNotchOpen || stackViewInternal.busy) && Anim.animationsEnabled
        NumberAnimation {
            property var _ease: isExpanded ? Anim.springSnappy() : Anim.easing("standard")
            duration: isExpanded ? Anim.emphasizedNormal : Anim.standardNormal
            easing.type: _ease.type
            easing.bezierCurve: _ease.bezierCurve
        }
    }

    // StyledRect extendido que cubre todo (notch + corners) para usar como máscara
    StyledRect {
        id: notchFullBackground
        variant: "bg"
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
            enabled: Anim.animationsEnabled
            NumberAnimation {
                property var _ease: screenNotchOpen || hasActiveNotifications ? Anim.easing("emphasized") : Anim.easing("standard")
                duration: Anim.standardNormal
                easing.type: _ease.type
                easing.bezierCurve: _ease.bezierCurve
            }
        }

        Behavior on bottomRightRadius {
            enabled: Anim.animationsEnabled
            NumberAnimation {
                property var _ease: screenNotchOpen || hasActiveNotifications ? Anim.easing("emphasized") : Anim.easing("standard")
                duration: Anim.standardNormal
                easing.type: _ease.type
                easing.bezierCurve: _ease.bezierCurve
            }
        }

        Behavior on topLeftRadius {
            enabled: Anim.animationsEnabled
            NumberAnimation {
                property var _ease: screenNotchOpen || hasActiveNotifications ? Anim.easing("emphasized") : Anim.easing("standard")
                duration: Anim.standardNormal
                easing.type: _ease.type
                easing.bezierCurve: _ease.bezierCurve
            }
        }

        Behavior on topRightRadius {
            enabled: Anim.animationsEnabled
            NumberAnimation {
                property var _ease: screenNotchOpen || hasActiveNotifications ? Anim.easing("emphasized") : Anim.easing("standard")
                duration: Anim.standardNormal
                easing.type: _ease.type
                easing.bezierCurve: _ease.bezierCurve
            }
        }

        layer.enabled: true
        layer.smooth: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: notchFullMask
            maskThresholdMin: 0.5
            maskThresholdMax: 1.0
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

        // Helper function to check if we're actually showing the DefaultView
        function isActuallyShowingDefault() {
            return stackViewInternal.currentItem && stackViewInternal.depth === 1;
        }

        property int topLeftRadius: Config.notchTheme === "default" ? (notchContainer.position === "bottom" ? defaultRadius : 0) : (Config.notchTheme === "island" && hasActiveNotifications && isActuallyShowingDefault() && notchContainer.position === "top" ? (Config.roundness > 0 ? Config.roundness + 4 : 0)  // Small radius only when in DefaultView with notifications at top
            : islandRadius)  // Otherwise use dynamic islandRadius
        property int topRightRadius: Config.notchTheme === "default" ? (notchContainer.position === "bottom" ? defaultRadius : 0) : (Config.notchTheme === "island" && hasActiveNotifications && isActuallyShowingDefault() && notchContainer.position === "top" ? (Config.roundness > 0 ? Config.roundness + 4 : 0)  // Small radius only when in DefaultView with notifications at top
            : islandRadius)  // Otherwise use dynamic islandRadius
        property int bottomLeftRadius: Config.notchTheme === "island" ? (hasActiveNotifications && isActuallyShowingDefault() && notchContainer.position === "bottom" ? (Config.roundness > 0 ? Config.roundness + 4 : 0)  // Small radius only when in DefaultView with notifications at bottom
            : islandRadius)  // Otherwise use dynamic islandRadius
        : (notchContainer.position === "top" ? defaultRadius : 0)
        property int bottomRightRadius: Config.notchTheme === "island" ? (hasActiveNotifications && isActuallyShowingDefault() && notchContainer.position === "bottom" ? (Config.roundness > 0 ? Config.roundness + 4 : 0)  // Small radius only when in DefaultView with notifications at bottom
            : islandRadius)  // Otherwise use dynamic islandRadius
        : (notchContainer.position === "top" ? defaultRadius : 0)

        // Fondo del notch solo para theme "island"
        StyledRect {
            id: notchIslandBg
            variant: "bg"
            visible: Config.notchTheme === "island"
            anchors.fill: parent
            layer.enabled: false
            clip: false // Desactivar clip para que no corte el border
            enableBorder: !notchContainer.unifiedEffectActive // En island sí usar border de StyledRect, a menos que el unified shader esté activo
            animateRadius: false // Custom animation below

            // Usar el islandRadius como radius base también
            radius: parent.islandRadius

            topLeftRadius: parent.topLeftRadius
            topRightRadius: parent.topRightRadius
            bottomLeftRadius: parent.bottomLeftRadius
            bottomRightRadius: parent.bottomRightRadius

            Behavior on topLeftRadius {
                enabled: Anim.animationsEnabled
                NumberAnimation {
                    property var _ease: screenNotchOpen || hasActiveNotifications ? Anim.easing("emphasized") : Anim.easing("standard")
                    duration: Anim.standardNormal
                    easing.type: _ease.type
                    easing.bezierCurve: _ease.bezierCurve
                }
            }

            Behavior on topRightRadius {
                enabled: Anim.animationsEnabled
                NumberAnimation {
                    property var _ease: screenNotchOpen || hasActiveNotifications ? Anim.easing("emphasized") : Anim.easing("standard")
                    duration: Anim.standardNormal
                    easing.type: _ease.type
                    easing.bezierCurve: _ease.bezierCurve
                }
            }

            Behavior on bottomLeftRadius {
                enabled: Anim.animationsEnabled
                NumberAnimation {
                    property var _ease: screenNotchOpen || hasActiveNotifications ? Anim.easing("emphasized") : Anim.easing("standard")
                    duration: Anim.standardNormal
                    easing.type: _ease.type
                    easing.bezierCurve: _ease.bezierCurve
                }
            }

            Behavior on bottomRightRadius {
                enabled: Anim.animationsEnabled
                NumberAnimation {
                    property var _ease: screenNotchOpen || hasActiveNotifications ? Anim.easing("emphasized") : Anim.easing("standard")
                    duration: Anim.standardNormal
                    easing.type: _ease.type
                    easing.bezierCurve: _ease.bezierCurve
                }
            }
        }

        // HoverHandler para detectar hover sin bloquear eventos
        HoverHandler {
            id: notchHoverHandler
            enabled: true

            onHoveredChanged: {
                isHovered = hovered;
            }
        }

        Rectangle {
            id: stackContainer
            anchors.centerIn: parent
            color: "transparent"
            radius: Config.roundness > 0 ? (screenNotchOpen || hasActiveNotifications ? Config.roundness + 20 : Config.roundness + 4) : 0
            Behavior on radius {
                enabled: Anim.animationsEnabled
                NumberAnimation {
                    duration: Anim.standardNormal
                    easing.type: Anim.easing("standard").type
                    easing.bezierCurve: Anim.easing("standard").bezierCurve
                }
            }
            property real animMargin: screenNotchOpen ? 16 : 0
            Behavior on animMargin {
                enabled: Anim.animationsEnabled
                NumberAnimation {
                    duration: Anim.standardNormal
                    easing.type: Anim.easing("standard").type
                    easing.bezierCurve: Anim.easing("standard").bezierCurve
                }
            }
            width: stackViewInternal.currentItem ? stackViewInternal.currentItem.implicitWidth + animMargin * 2 : animMargin * 2
            height: _forceCompact ? compactHeight : (stackViewInternal.currentItem ? stackViewInternal.currentItem.implicitHeight + animMargin * 2 : animMargin * 2)
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
                duration: Anim.standardNormal
                easing.type: Anim.easing("standard").type
                easing.bezierCurve: Anim.easing("standard").bezierCurve
            }

            StackView {
                id: stackViewInternal
                anchors.fill: parent
                anchors.margins: stackContainer.animMargin
                initialItem: defaultViewComponent

                onCurrentItemChanged: {
                    notchContainer.updateChildHover();
                }

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
                        duration: Anim.standardNormal
                        easing.type: Anim.easing("decelerate").type
                        easing.bezierCurve: Anim.easing("decelerate").bezierCurve
                    }
                    PropertyAnimation {
                        property: "scale"
                        from: 0.85
                        to: 1
                        duration: Anim.emphasizedNormal
                        easing.type: Anim.springSnappy().type
                        easing.bezierCurve: Anim.springSnappy().bezierCurve
                    }
                }

                pushExit: Transition {
                    PropertyAnimation {
                        property: "opacity"
                        from: 1
                        to: 0
                        duration: Anim.standardNormal
                        easing.type: Anim.easing("standard").type
                        easing.bezierCurve: Anim.easing("standard").bezierCurve
                    }
                    PropertyAnimation {
                        property: "scale"
                        from: 1
                        to: 1.04
                        duration: Anim.standardNormal
                        easing.type: Anim.easing("standard").type
                        easing.bezierCurve: Anim.easing("standard").bezierCurve
                    }
                }

                popEnter: Transition {
                    PropertyAnimation {
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: Anim.standardNormal
                        easing.type: Anim.easing("decelerate").type
                        easing.bezierCurve: Anim.easing("decelerate").bezierCurve
                    }
                    PropertyAnimation {
                        property: "scale"
                        from: 1.04
                        to: 1
                        duration: Anim.standardNormal
                        easing.type: Anim.springSnappy().type
                        easing.bezierCurve: Anim.springSnappy().bezierCurve
                    }
                }

                popExit: Transition {
                    PropertyAnimation {
                        property: "opacity"
                        from: 1
                        to: 0
                        duration: Anim.emphasizedLarge
                        easing.type: Anim.easing("emphasized", "exit").type
                        easing.bezierCurve: Anim.easing("emphasized", "exit").bezierCurve
                    }
                    PropertyAnimation {
                        property: "scale"
                        from: 1
                        to: 0.94
                        duration: Anim.emphasizedLarge
                        easing.type: Anim.easing("emphasized", "exit").type
                        easing.bezierCurve: Anim.easing("emphasized", "exit").bezierCurve
                    }
                }

                replaceEnter: Transition {
                    PropertyAnimation {
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: Anim.standardNormal
                        easing.type: Anim.easing("decelerate").type
                        easing.bezierCurve: Anim.easing("decelerate").bezierCurve
                    }
                    PropertyAnimation {
                        property: "scale"
                        from: 0.85
                        to: 1
                        duration: Anim.emphasizedNormal
                        easing.type: Anim.springSnappy().type
                        easing.bezierCurve: Anim.springSnappy().bezierCurve
                    }
                }

                replaceExit: Transition {
                    PropertyAnimation {
                        property: "opacity"
                        from: 1
                        to: 0
                        duration: Anim.standardNormal
                        easing.type: Anim.easing("standard").type
                        easing.bezierCurve: Anim.easing("standard").bezierCurve
                    }
                    PropertyAnimation {
                        property: "scale"
                        from: 1
                        to: 1.04
                        duration: Anim.standardNormal
                        easing.type: Anim.easing("standard").type
                        easing.bezierCurve: Anim.easing("standard").bezierCurve
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

        visible: Config.notchTheme === "default" && borderWidth > 0 && !notchContainer.unifiedEffectActive

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
