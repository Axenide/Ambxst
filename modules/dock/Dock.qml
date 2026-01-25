pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.modules.corners
import qs.modules.globals
import qs.config

Scope {
    id: root

    property bool pinned: Config.dock?.pinnedOnStartup ?? false

    // Theme configuration
    readonly property string theme: Config.dock?.theme ?? "default"
    readonly property bool isFloating: theme === "floating"
    readonly property bool isDefault: theme === "default"

    // Position configuration with fallback logic to avoid bar collision
    readonly property string userPosition: Config.dock?.position ?? "bottom"
    readonly property string barPosition: Config.bar?.position ?? "top"

    // Effective position: if dock and bar are on the same side, dock moves to fallback
    readonly property string position: {
        if (userPosition !== barPosition) {
            return userPosition;
        }
        // Collision detected - apply fallback
        switch (userPosition) {
        case "bottom":
            return "left";
        case "left":
            return "right";
        case "right":
            return "left";
        case "top":
            return "bottom";
        default:
            return "bottom";
        }
    }

    readonly property bool isBottom: position === "bottom"
    readonly property bool isLeft: position === "left"
    readonly property bool isRight: position === "right"
    readonly property bool isVertical: isLeft || isRight

    // Margin calculations - different for each theme
    readonly property int dockMargin: Config.dock?.margin ?? 8
    readonly property int hyprlandGapsOut: Config.hyprland?.gapsOut ?? 4

    // For default theme: edge margin is 0, window side margin is also adjusted
    // For floating theme: both margins use dockMargin
    readonly property int windowSideMargin: {
        if (isDefault) {
            // Default: no margin on edge, normal margin on window side minus gaps
            return dockMargin > 0 ? Math.max(0, dockMargin - hyprlandGapsOut) : 0;
        } else {
            // Floating: normal margin calculation
            return dockMargin > 0 ? Math.max(0, dockMargin - hyprlandGapsOut) : 0;
        }
    }
    readonly property int edgeSideMargin: isDefault ? 0 : dockMargin

    Variants {
        model: {
            const screens = Quickshell.screens;
            const list = Config.dock?.screenList ?? [];
            if (!list || list.length === 0)
                return screens;
            return screens.filter(screen => list.includes(screen.name));
        }

        PanelWindow {
            id: dockWindow

            required property ShellScreen modelData
            screen: modelData

            // Reference to the bar panel on this screen to check its state
            readonly property var barPanelRef: Visibilities.barPanels[screen.name]
            // Only allow exclusive zone if the bar is also pinned (to prevent pushing the bar when it's floating)
            readonly property bool barPinned: {
                if (barPanelRef && typeof barPanelRef.pinned !== 'undefined') {
                    return barPanelRef.pinned;
                }
                return true; // Default to true if not found, to maintain original behavior
            }

            // Fullscreen detection - check if active toplevel is fullscreen on this screen
            readonly property bool activeWindowFullscreen: {
                const toplevel = ToplevelManager.activeToplevel;
                if (!toplevel || !toplevel.activated || toplevel.screens[0] != screen)
                    return false;
                // Check if the toplevel is fullscreen
                return toplevel.fullscreen === true;
            }

            // Reveal logic: pinned, hover, no active window
            property bool reveal: {
                // Fullscreen behavior: Force auto-hide if allowed, otherwise hide
                if (activeWindowFullscreen) {
                    return (Config.dock?.availableOnFullscreen ?? false) && (Config.dock?.hoverToReveal && dockMouseArea.containsMouse);
                }

                // Normal behavior
                return root.pinned || (Config.dock?.hoverToReveal && dockMouseArea.containsMouse) || !ToplevelManager.activeToplevel?.activated && ToplevelManager.activeToplevel?.screens[0] == screen
            }

            anchors {
                bottom: root.isBottom
                left: root.isLeft
                right: root.isRight
            }

            // Total margin includes dock + margins (window side + edge side)
            readonly property int totalMargin: root.windowSideMargin + root.edgeSideMargin
            readonly property int shadowSpace: 32
            readonly property int dockSize: Config.dock?.height ?? 56

            // Reserve space when pinned, but ONLY if bar is also pinned (to avoid displacement issues)
            // If bar is unpinned (auto-hide), dock becomes overlay-only (0 zone)
            exclusiveZone: (root.pinned && barPinned && !activeWindowFullscreen) ? dockSize + totalMargin : 0

            implicitWidth: root.isVertical ? dockSize + totalMargin + shadowSpace * 2 : dockContent.implicitWidth + shadowSpace * 2
            implicitHeight: root.isVertical ? dockContent.implicitHeight + shadowSpace * 2 : dockSize + totalMargin + shadowSpace * 2

            WlrLayershell.namespace: "quickshell"
            WlrLayershell.layer: WlrLayer.Overlay
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore

            mask: Region {
                item: dockMouseArea
            }

            // Content sizing helper
            Item {
                id: dockContent
                implicitWidth: root.isVertical ? dockWindow.dockSize : dockLayoutHorizontal.implicitWidth + 16
                implicitHeight: root.isVertical ? dockLayoutVertical.implicitHeight + 16 : dockWindow.dockSize
            }

            MouseArea {
                id: dockMouseArea
                hoverEnabled: true

                // Size
                width: root.isVertical ? (dockWindow.reveal ? dockWindow.dockSize + dockWindow.totalMargin + dockWindow.shadowSpace : (Config.dock?.hoverRegionHeight ?? 4)) : dockContent.implicitWidth + 20
                height: root.isVertical ? dockContent.implicitHeight + 20 : (dockWindow.reveal ? dockWindow.dockSize + dockWindow.totalMargin + dockWindow.shadowSpace : (Config.dock?.hoverRegionHeight ?? 4))

                // Position using x/y instead of anchors to avoid sticky anchor issues
                x: root.isBottom ? (parent.width - width) / 2 : (root.isLeft ? 0 : parent.width - width)
                y: root.isVertical ? (parent.height - height) / 2 : parent.height - height

                Behavior on x {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration / 4
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on y {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration / 4
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on width {
                    enabled: Config.animDuration > 0 && root.isVertical
                    NumberAnimation {
                        duration: Config.animDuration / 4
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on height {
                    enabled: Config.animDuration > 0 && !root.isVertical
                    NumberAnimation {
                        duration: Config.animDuration / 4
                        easing.type: Easing.OutCubic
                    }
                }

                // Dock container
                Item {
                    id: dockContainer

                    // Corner size for default theme
                    readonly property int cornerSize: root.isDefault && Config.roundness > 0 ? Config.roundness + 4 : 0

                    // Size - includes corner space for default theme
                    // Bottom: corners are on left and right sides (extra width, same height)
                    // Vertical: corners are on top and bottom (same width, extra height)
                    width: {
                        if (root.isDefault && cornerSize > 0) {
                            if (root.isBottom)
                                return dockContent.implicitWidth + cornerSize * 2;
                        }
                        return dockContent.implicitWidth;
                    }
                    height: {
                        if (root.isDefault && cornerSize > 0) {
                            if (root.isVertical)
                                return dockContent.implicitHeight + cornerSize * 2;
                        }
                        return dockContent.implicitHeight;
                    }

                    // Position using x/y
                    x: root.isBottom ? (parent.width - width) / 2 : (root.isLeft ? root.edgeSideMargin : parent.width - width - root.edgeSideMargin)
                    y: root.isVertical ? (parent.height - height) / 2 : parent.height - height - root.edgeSideMargin

                    Behavior on x {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Config.animDuration / 4
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on y {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Config.animDuration / 4
                            easing.type: Easing.OutCubic
                        }
                    }

                    // Animation for dock reveal
                    opacity: dockWindow.reveal ? 1 : 0
                    Behavior on opacity {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Config.animDuration / 2
                            easing.type: Easing.OutCubic
                        }
                    }

                    // Slide animation
                    transform: Translate {
                        x: root.isVertical ? (dockWindow.reveal ? 0 : (root.isLeft ? -(dockContainer.width + root.edgeSideMargin) : (dockContainer.width + root.edgeSideMargin))) : 0
                        y: root.isBottom ? (dockWindow.reveal ? 0 : (dockContainer.height + root.edgeSideMargin)) : 0
                        Behavior on x {
                            enabled: Config.animDuration > 0
                            NumberAnimation {
                                duration: Config.animDuration / 2
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on y {
                            enabled: Config.animDuration > 0
                            NumberAnimation {
                                duration: Config.animDuration / 2
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    // Full background container with masking (default theme)
                    Item {
                        id: dockFullBgContainer
                        visible: root.isDefault
                        anchors.fill: parent

                        // Background rect - covers the entire area
                        StyledRect {
                            id: dockBackground
                            anchors.fill: parent

                            variant: "bg"
                            enableShadow: true
                            enableBorder: false

                            readonly property int fullRadius: Styling.radius(4)

                            // For default theme: corners on screen edge are 0 (flush with edge)
                            topLeftRadius: {
                                if (root.isBottom)
                                    return fullRadius;
                                if (root.isLeft)
                                    return 0;
                                if (root.isRight)
                                    return fullRadius;
                                return fullRadius;
                            }
                            topRightRadius: {
                                if (root.isBottom)
                                    return fullRadius;
                                if (root.isLeft)
                                    return fullRadius;
                                if (root.isRight)
                                    return 0;
                                return fullRadius;
                            }
                            bottomLeftRadius: {
                                if (root.isBottom)
                                    return 0;
                                if (root.isLeft)
                                    return 0;
                                if (root.isRight)
                                    return fullRadius;
                                return fullRadius;
                            }
                            bottomRightRadius: {
                                if (root.isBottom)
                                    return 0;
                                if (root.isLeft)
                                    return fullRadius;
                                if (root.isRight)
                                    return 0;
                                return fullRadius;
                            }
                        }

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: dockMask
                            maskThresholdMin: 0.5
                            maskSpreadAtMin: 1.0
                        }
                    }

                    // Mask for the full background (default theme)
                    Item {
                        id: dockMask
                        visible: false
                        anchors.fill: parent

                        layer.enabled: true
                        layer.smooth: true

                        // First corner - position and type change based on dock position
                        RoundCorner {
                            id: corner1
                            x: {
                                if (root.isBottom)
                                    return 0;
                                if (root.isLeft)
                                    return 0;  // Left edge (screen border)
                                if (root.isRight)
                                    return parent.width - dockContainer.cornerSize;  // Right edge (screen border)
                                return 0;
                            }
                            y: {
                                if (root.isBottom)
                                    return parent.height - dockContainer.cornerSize;
                                return 0;  // Top of container for vertical docks
                            }
                            size: Math.max(dockContainer.cornerSize, 1)
                            corner: {
                                if (root.isBottom)
                                    return RoundCorner.CornerEnum.BottomRight;
                                if (root.isLeft)
                                    return RoundCorner.CornerEnum.BottomLeft;  // Curves down toward dock
                                if (root.isRight)
                                    return RoundCorner.CornerEnum.BottomRight;  // Curves down toward dock
                                return RoundCorner.CornerEnum.BottomRight;
                            }
                            color: "white"
                        }

                        // Second corner - position and type change based on dock position
                        RoundCorner {
                            id: corner2
                            x: {
                                if (root.isBottom)
                                    return parent.width - dockContainer.cornerSize;
                                if (root.isLeft)
                                    return 0;  // Left edge (screen border)
                                if (root.isRight)
                                    return parent.width - dockContainer.cornerSize;  // Right edge (screen border)
                                return 0;
                            }
                            y: parent.height - dockContainer.cornerSize  // Always at bottom of container
                            size: Math.max(dockContainer.cornerSize, 1)
                            corner: {
                                if (root.isBottom)
                                    return RoundCorner.CornerEnum.BottomLeft;
                                if (root.isLeft)
                                    return RoundCorner.CornerEnum.TopLeft;  // Curves up toward dock
                                if (root.isRight)
                                    return RoundCorner.CornerEnum.TopRight;  // Curves up toward dock
                                return RoundCorner.CornerEnum.BottomLeft;
                            }
                            color: "white"
                        }

                        // Center rect mask (the main dock area)
                        Rectangle {
                            id: centerMask
                            width: dockContent.implicitWidth
                            height: dockContent.implicitHeight
                            color: "white"

                            // Position based on dock position
                            x: {
                                if (root.isBottom)
                                    return dockContainer.cornerSize;
                                return 0;  // Vertical docks: no x offset
                            }
                            y: {
                                if (root.isBottom)
                                    return 0;
                                return dockContainer.cornerSize;  // Vertical docks: after top corner
                            }

                            topLeftRadius: dockBackground.topLeftRadius
                            topRightRadius: dockBackground.topRightRadius
                            bottomLeftRadius: dockBackground.bottomLeftRadius
                            bottomRightRadius: dockBackground.bottomRightRadius
                        }
                    }

                    // Background for floating theme (simple, no round corners)
                    StyledRect {
                        id: dockBackgroundFloating
                        visible: root.isFloating
                        anchors.fill: parent
                        variant: "bg"
                        enableShadow: true
                        radius: Styling.radius(4)
                    }

                    // Horizontal layout (bottom dock)
                    RowLayout {
                        id: dockLayoutHorizontal
                        // For default theme, center in the dock content area (not the expanded container)
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: (dockContent.implicitHeight - implicitHeight) / 2
                        spacing: Config.dock?.spacing ?? 4
                        visible: !root.isVertical

                        // Pin button
                        Loader {
                            active: Config.dock?.showPinButton ?? true
                            visible: active
                            Layout.alignment: Qt.AlignVCenter

                            sourceComponent: Button {
                                id: pinButton
                                implicitWidth: 32
                                implicitHeight: 32

                                background: StyledRect {
                                    visible: root.pinned || pinButton.hovered
                                    variant: root.pinned ? "primary" : "focus"
                                    radius: Styling.radius(-2)
                                    enableShadow: false
                                    enableBorder: false
                                }

                                contentItem: Text {
                                    text: Icons.pin
                                    font.family: Icons.font
                                    font.pixelSize: 16
                                    color: root.pinned ? Styling.srItem("primary") : Colors.overBackground
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter

                                    rotation: root.pinned ? 0 : 45
                                    Behavior on rotation {
                                        enabled: Config.animDuration > 0
                                        NumberAnimation {
                                            duration: Config.animDuration / 2
                                        }
                                    }

                                    Behavior on color {
                                        enabled: Config.animDuration > 0
                                        ColorAnimation {
                                            duration: Config.animDuration / 2
                                        }
                                    }
                                }

                                onClicked: root.pinned = !root.pinned

                                StyledToolTip {
                                    show: pinButton.hovered
                                    tooltipText: root.pinned ? "Unpin dock" : "Pin dock"
                                }
                            }
                        }

                        // Separator after pin button
                        Loader {
                            active: Config.dock?.showPinButton ?? true
                            visible: active
                            Layout.alignment: Qt.AlignVCenter

                            sourceComponent: Separator {
                                vert: true
                                implicitHeight: (Config.dock?.iconSize ?? 40) * 0.6
                            }
                        }

                        // App buttons
                        Repeater {
                            model: TaskbarApps.apps

                            DockAppButton {
                                required property var modelData
                                appToplevel: modelData
                                Layout.alignment: Qt.AlignVCenter
                                dockPosition: "bottom"
                            }
                        }

                        // Separator before overview button
                        Loader {
                            active: Config.dock?.showOverviewButton ?? true
                            visible: active
                            Layout.alignment: Qt.AlignVCenter

                            sourceComponent: Separator {
                                vert: true
                                implicitHeight: (Config.dock?.iconSize ?? 40) * 0.6
                            }
                        }

                        // Overview button
                        Loader {
                            active: Config.dock?.showOverviewButton ?? true
                            visible: active
                            Layout.alignment: Qt.AlignVCenter

                            sourceComponent: Button {
                                id: overviewButton
                                implicitWidth: 32
                                implicitHeight: 32

                                background: StyledRect {
                                    visible: overviewButton.hovered
                                    variant: "focus"
                                    radius: Styling.radius(-2)
                                    enableShadow: false
                                    enableBorder: false
                                }

                                contentItem: Text {
                                    text: Icons.overview
                                    font.family: Icons.font
                                    font.pixelSize: 18
                                    color: Colors.overBackground
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                onClicked: {
                                    // Toggle overview on the current screen
                                    let visibilities = Visibilities.getForScreen(dockWindow.screen.name);
                                    if (visibilities) {
                                        visibilities.overview = !visibilities.overview;
                                    }
                                }

                                StyledToolTip {
                                    show: overviewButton.hovered
                                    tooltipText: "Overview"
                                }
                            }
                        }
                    }

                    // Vertical layout (left/right dock)
                    ColumnLayout {
                        id: dockLayoutVertical
                        // Center in the dock content area, accounting for corner space
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: dockContainer.cornerSize + (dockContent.implicitHeight - implicitHeight) / 2
                        spacing: Config.dock?.spacing ?? 4
                        visible: root.isVertical

                        // Pin button
                        Loader {
                            active: Config.dock?.showPinButton ?? true
                            visible: active
                            Layout.alignment: Qt.AlignHCenter

                            sourceComponent: Button {
                                id: pinButtonV
                                implicitWidth: 32
                                implicitHeight: 32

                                background: StyledRect {
                                    visible: root.pinned || pinButtonV.hovered
                                    variant: root.pinned ? "primary" : "focus"
                                    radius: Styling.radius(-2)
                                    enableShadow: false
                                    enableBorder: false
                                }

                                contentItem: Text {
                                    text: Icons.pin
                                    font.family: Icons.font
                                    font.pixelSize: 16
                                    color: root.pinned ? Styling.srItem("primary") : Colors.overBackground
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter

                                    rotation: root.pinned ? 0 : 45
                                    Behavior on rotation {
                                        enabled: Config.animDuration > 0
                                        NumberAnimation {
                                            duration: Config.animDuration / 2
                                        }
                                    }

                                    Behavior on color {
                                        enabled: Config.animDuration > 0
                                        ColorAnimation {
                                            duration: Config.animDuration / 2
                                        }
                                    }
                                }

                                onClicked: root.pinned = !root.pinned

                                StyledToolTip {
                                    show: pinButtonV.hovered
                                    tooltipText: root.pinned ? "Unpin dock" : "Pin dock"
                                }
                            }
                        }

                        // Separator after pin button
                        Loader {
                            active: Config.dock?.showPinButton ?? true
                            visible: active
                            Layout.alignment: Qt.AlignHCenter

                            sourceComponent: Separator {
                                vert: false
                                implicitWidth: (Config.dock?.iconSize ?? 40) * 0.6
                            }
                        }

                        // App buttons
                        Repeater {
                            model: TaskbarApps.apps

                            DockAppButton {
                                required property var modelData
                                appToplevel: modelData
                                Layout.alignment: Qt.AlignHCenter
                                dockPosition: root.position
                            }
                        }

                        // Separator before overview button
                        Loader {
                            active: Config.dock?.showOverviewButton ?? true
                            visible: active
                            Layout.alignment: Qt.AlignHCenter

                            sourceComponent: Separator {
                                vert: false
                                implicitWidth: (Config.dock?.iconSize ?? 40) * 0.6
                            }
                        }

                        // Overview button
                        Loader {
                            active: Config.dock?.showOverviewButton ?? true
                            visible: active
                            Layout.alignment: Qt.AlignHCenter

                            sourceComponent: Button {
                                id: overviewButtonV
                                implicitWidth: 32
                                implicitHeight: 32

                                background: StyledRect {
                                    visible: overviewButtonV.hovered
                                    variant: "focus"
                                    radius: Styling.radius(-2)
                                    enableShadow: false
                                    enableBorder: false
                                }

                                contentItem: Text {
                                    text: Icons.overview
                                    font.family: Icons.font
                                    font.pixelSize: 18
                                    color: Colors.overBackground
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                onClicked: {
                                    // Toggle overview on the current screen
                                    let visibilities = Visibilities.getForScreen(dockWindow.screen.name);
                                    if (visibilities) {
                                        visibilities.overview = !visibilities.overview;
                                    }
                                }

                                StyledToolTip {
                                    show: overviewButtonV.hovered
                                    tooltipText: "Overview"
                                }
                            }
                        }
                    }

                    // Unified outline canvas (single continuous stroke around silhouette)
                    Canvas {
                        id: outlineCanvas
                        anchors.fill: parent
                        z: 5000
                        antialiasing: true

                        readonly property var borderData: Config.theme.srBg.border
                        readonly property int borderWidth: borderData[1]
                        readonly property color borderColor: Config.resolveColor(borderData[0])

                        visible: root.isDefault && borderWidth > 0

                        onPaint: {
                            if (!root.isDefault)
                                return;
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);

                            if (borderWidth <= 0)
                                return;

                            ctx.strokeStyle = borderColor;
                            ctx.lineWidth = borderWidth;
                            ctx.lineJoin = "round";
                            ctx.lineCap = "butt";

                            var offset = borderWidth / 2;
                            var cs = dockContainer.cornerSize;
                            var hasFillets = cs > offset;
                            var filletRadius = hasFillets ? cs - offset : 0;

                            // Floating radii
                            var tl = dockBackground.topLeftRadius;
                            var tr = dockBackground.topRightRadius;
                            var bl = dockBackground.bottomLeftRadius;
                            var br = dockBackground.bottomRightRadius;

                            ctx.beginPath();

                            if (root.isBottom) {
                                if (hasFillets) {
                                    // With fillets - Draw Left to Right (Start Bottom Left)
                                    ctx.moveTo(offset, height - offset);

                                    // Left Fillet
                                    ctx.arc(offset, height - cs, filletRadius, Math.PI / 2, 0, true);

                                    // Line Up to Top Left Corner
                                    ctx.lineTo(cs, tl > 0 ? tl + offset : offset);

                                    // Top Left Corner
                                    if (tl > 0)
                                        ctx.arcTo(cs, offset, cs + tl, offset, tl - offset);
                                    else
                                        ctx.lineTo(cs, offset);

                                    // Line Right to Top Right Corner
                                    ctx.lineTo(width - cs - tr, offset);

                                    // Top Right Corner
                                    if (tr > 0)
                                        ctx.arcTo(width - cs, offset, width - cs, offset + tr, tr - offset);
                                    else
                                        ctx.lineTo(width - cs, offset);

                                    // Line Down to Right Fillet
                                    ctx.lineTo(width - cs, height - cs);

                                    // Right Fillet
                                    ctx.arc(width - offset, height - cs, filletRadius, Math.PI, Math.PI / 2, true);
                                } else {
                                    // No fillets - simple rectangle with rounded corners
                                    ctx.moveTo(offset, height - offset);
                                    ctx.lineTo(offset, tl > 0 ? tl + offset : offset);
                                    if (tl > 0)
                                        ctx.arcTo(offset, offset, offset + tl, offset, tl - offset);
                                    else
                                        ctx.lineTo(offset, offset);
                                    ctx.lineTo(width - tr - offset, offset);
                                    if (tr > 0)
                                        ctx.arcTo(width - offset, offset, width - offset, offset + tr, tr - offset);
                                    else
                                        ctx.lineTo(width - offset, offset);
                                    ctx.lineTo(width - offset, height - offset);
                                }
                            } else if (root.isLeft) {
                                if (hasFillets) {
                                    // With fillets - Mirror of right
                                    ctx.moveTo(offset, offset);

                                    // Top Fillet
                                    ctx.arc(cs, offset, filletRadius, Math.PI, Math.PI / 2, true);

                                    // Line Right to Top Right Corner
                                    ctx.lineTo(width - tr - offset, cs);

                                    // Top Right Corner
                                    if (tr > 0)
                                        ctx.arcTo(width - offset, cs, width - offset, cs + tr, tr - offset);
                                    else
                                        ctx.lineTo(width - offset, cs);

                                    // Line Down to Bottom Right Corner
                                    ctx.lineTo(width - offset, height - cs - br);

                                    // Bottom Right Corner
                                    if (br > 0)
                                        ctx.arcTo(width - offset, height - cs, width - offset - br, height - cs, br - offset);
                                    else
                                        ctx.lineTo(width - offset, height - cs);

                                    // Line Left to Bottom Fillet
                                    ctx.lineTo(cs, height - cs);

                                    // Bottom Fillet
                                    ctx.arc(cs, height - offset, filletRadius, 3 * Math.PI / 2, Math.PI, true);
                                } else {
                                    // No fillets - simple rectangle with rounded corners
                                    ctx.moveTo(offset, offset);
                                    ctx.lineTo(width - tr - offset, offset);
                                    if (tr > 0)
                                        ctx.arcTo(width - offset, offset, width - offset, offset + tr, tr - offset);
                                    else
                                        ctx.lineTo(width - offset, offset);
                                    ctx.lineTo(width - offset, height - br - offset);
                                    if (br > 0)
                                        ctx.arcTo(width - offset, height - offset, width - offset - br, height - offset, br - offset);
                                    else
                                        ctx.lineTo(width - offset, height - offset);
                                    ctx.lineTo(offset, height - offset);
                                }
                            } else if (root.isRight) {
                                if (hasFillets) {
                                    // With fillets
                                    ctx.moveTo(width - offset, offset);

                                    // Top Fillet
                                    ctx.arc(width - cs, offset, filletRadius, 0, Math.PI / 2, false);

                                    // Line Left to Top Left
                                    ctx.lineTo(tl + offset, cs);

                                    // Top Left Corner
                                    if (tl > 0)
                                        ctx.arcTo(offset, cs, offset, cs + tl, tl - offset);
                                    else
                                        ctx.lineTo(offset, cs);

                                    // Line Down to Bottom Left
                                    ctx.lineTo(offset, height - cs - bl);

                                    // Bottom Left Corner
                                    if (bl > 0)
                                        ctx.arcTo(offset, height - cs, offset + bl, height - cs, bl - offset);
                                    else
                                        ctx.lineTo(offset, height - cs);

                                    // Line Right to Bottom Fillet
                                    ctx.lineTo(width - cs, height - cs);

                                    // Bottom Fillet
                                    ctx.arc(width - cs, height - offset, filletRadius, 3 * Math.PI / 2, 2 * Math.PI, false);
                                } else {
                                    // No fillets - simple rectangle with rounded corners
                                    ctx.moveTo(width - offset, offset);
                                    ctx.lineTo(tl + offset, offset);
                                    if (tl > 0)
                                        ctx.arcTo(offset, offset, offset, offset + tl, tl - offset);
                                    else
                                        ctx.lineTo(offset, offset);
                                    ctx.lineTo(offset, height - bl - offset);
                                    if (bl > 0)
                                        ctx.arcTo(offset, height - offset, offset + bl, height - offset, bl - offset);
                                    else
                                        ctx.lineTo(offset, height - offset);
                                    ctx.lineTo(width - offset, height - offset);
                                }
                            }

                            ctx.stroke();
                        }

                        // Signal connections for repainting
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
                            target: dockBackground
                            function onBottomLeftRadiusChanged() {
                                outlineCanvas.requestPaint();
                            }
                        }
                        Connections {
                            target: dockBackground
                            function onBottomRightRadiusChanged() {
                                outlineCanvas.requestPaint();
                            }
                        }
                        Connections {
                            target: dockBackground
                            function onTopLeftRadiusChanged() {
                                outlineCanvas.requestPaint();
                            }
                        }
                        Connections {
                            target: dockBackground
                            function onTopRightRadiusChanged() {
                                outlineCanvas.requestPaint();
                            }
                        }
                        Connections {
                            target: dockContainer
                            function onWidthChanged() {
                                outlineCanvas.requestPaint();
                            }
                        }
                        Connections {
                            target: dockContainer
                            function onHeightChanged() {
                                outlineCanvas.requestPaint();
                            }
                        }
                        Connections {
                            target: root
                            function onIsDefaultChanged() {
                                outlineCanvas.requestPaint();
                            }
                        }
                        Connections {
                            target: root
                            function onPositionChanged() {
                                outlineCanvas.requestPaint();
                            }
                        }
                    }
                }
            }
        }
    }
}
