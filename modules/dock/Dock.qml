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
            case "bottom": return "left";
            case "left": return "right";
            case "right": return "left";
            case "top": return "bottom";
            default: return "bottom";
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

            // Reveal logic: pinned, hover, no active window
            property bool reveal: root.pinned || 
                (Config.dock?.hoverToReveal && dockMouseArea.containsMouse) || 
                !ToplevelManager.activeToplevel?.activated

            anchors {
                bottom: root.isBottom
                left: root.isLeft
                right: root.isRight
            }

            // Total margin includes dock + margins (window side + edge side)
            readonly property int totalMargin: root.windowSideMargin + root.edgeSideMargin
            readonly property int shadowSpace: 32
            readonly property int dockSize: Config.dock?.height ?? 56
            
            // Reserve space when pinned (without shadow space to not push windows too far)
            exclusiveZone: root.pinned ? dockSize + totalMargin : 0

            implicitWidth: root.isVertical 
                ? dockSize + totalMargin + shadowSpace * 2
                : dockContent.implicitWidth + shadowSpace * 2
            implicitHeight: root.isVertical
                ? dockContent.implicitHeight + shadowSpace * 2
                : dockSize + totalMargin + shadowSpace * 2
            
            WlrLayershell.namespace: "quickshell:dock"
            color: "transparent"

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
                width: root.isVertical 
                    ? (dockWindow.reveal ? dockWindow.dockSize + dockWindow.totalMargin + dockWindow.shadowSpace : (Config.dock?.hoverRegionHeight ?? 4))
                    : dockContent.implicitWidth + 20
                height: root.isVertical
                    ? dockContent.implicitHeight + 20
                    : (dockWindow.reveal ? dockWindow.dockSize + dockWindow.totalMargin + dockWindow.shadowSpace : (Config.dock?.hoverRegionHeight ?? 4))

                // Position using x/y instead of anchors to avoid sticky anchor issues
                x: root.isBottom 
                    ? (parent.width - width) / 2
                    : (root.isLeft ? 0 : parent.width - width)
                y: root.isVertical 
                    ? (parent.height - height) / 2
                    : parent.height - height

                Behavior on x {
                    enabled: Config.animDuration > 0
                    NumberAnimation { duration: Config.animDuration / 4; easing.type: Easing.OutCubic }
                }
                Behavior on y {
                    enabled: Config.animDuration > 0
                    NumberAnimation { duration: Config.animDuration / 4; easing.type: Easing.OutCubic }
                }

                Behavior on width {
                    enabled: Config.animDuration > 0 && root.isVertical
                    NumberAnimation { duration: Config.animDuration / 4; easing.type: Easing.OutCubic }
                }

                Behavior on height {
                    enabled: Config.animDuration > 0 && !root.isVertical
                    NumberAnimation { duration: Config.animDuration / 4; easing.type: Easing.OutCubic }
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
                            if (root.isBottom) return dockContent.implicitWidth + cornerSize * 2;
                        }
                        return dockContent.implicitWidth;
                    }
                    height: {
                        if (root.isDefault && cornerSize > 0) {
                            if (root.isVertical) return dockContent.implicitHeight + cornerSize * 2;
                        }
                        return dockContent.implicitHeight;
                    }
                    
                    // Position using x/y
                    x: root.isBottom 
                        ? (parent.width - width) / 2
                        : (root.isLeft ? root.edgeSideMargin : parent.width - width - root.edgeSideMargin)
                    y: root.isVertical 
                        ? (parent.height - height) / 2
                        : parent.height - height - root.edgeSideMargin

                    Behavior on x {
                        enabled: Config.animDuration > 0
                        NumberAnimation { duration: Config.animDuration / 4; easing.type: Easing.OutCubic }
                    }
                    Behavior on y {
                        enabled: Config.animDuration > 0
                        NumberAnimation { duration: Config.animDuration / 4; easing.type: Easing.OutCubic }
                    }

                    // Animation for dock reveal
                    opacity: dockWindow.reveal ? 1 : 0
                    Behavior on opacity {
                        enabled: Config.animDuration > 0
                        NumberAnimation { duration: Config.animDuration / 2; easing.type: Easing.OutCubic }
                    }

                    // Slide animation
                    transform: Translate {
                        x: root.isVertical 
                            ? (dockWindow.reveal ? 0 : (root.isLeft ? -(dockContainer.width + root.edgeSideMargin) : (dockContainer.width + root.edgeSideMargin)))
                            : 0
                        y: root.isBottom 
                            ? (dockWindow.reveal ? 0 : (dockContainer.height + root.edgeSideMargin))
                            : 0
                        Behavior on x {
                            enabled: Config.animDuration > 0
                            NumberAnimation { duration: Config.animDuration / 2; easing.type: Easing.OutCubic }
                        }
                        Behavior on y {
                            enabled: Config.animDuration > 0
                            NumberAnimation { duration: Config.animDuration / 2; easing.type: Easing.OutCubic }
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
                                if (root.isBottom) return fullRadius;
                                if (root.isLeft) return 0;
                                if (root.isRight) return fullRadius;
                                return fullRadius;
                            }
                            topRightRadius: {
                                if (root.isBottom) return fullRadius;
                                if (root.isLeft) return fullRadius;
                                if (root.isRight) return 0;
                                return fullRadius;
                            }
                            bottomLeftRadius: {
                                if (root.isBottom) return 0;
                                if (root.isLeft) return 0;
                                if (root.isRight) return fullRadius;
                                return fullRadius;
                            }
                            bottomRightRadius: {
                                if (root.isBottom) return 0;
                                if (root.isLeft) return fullRadius;
                                if (root.isRight) return 0;
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
                                if (root.isBottom) return 0;
                                if (root.isLeft) return 0;  // Left edge (screen border)
                                if (root.isRight) return parent.width - dockContainer.cornerSize;  // Right edge (screen border)
                                return 0;
                            }
                            y: {
                                if (root.isBottom) return parent.height - dockContainer.cornerSize;
                                return 0;  // Top of container for vertical docks
                            }
                            size: Math.max(dockContainer.cornerSize, 1)
                            corner: {
                                if (root.isBottom) return RoundCorner.CornerEnum.BottomRight;
                                if (root.isLeft) return RoundCorner.CornerEnum.BottomLeft;  // Curves down toward dock
                                if (root.isRight) return RoundCorner.CornerEnum.BottomRight;  // Curves down toward dock
                                return RoundCorner.CornerEnum.BottomRight;
                            }
                            color: "white"
                        }
                        
                        // Second corner - position and type change based on dock position
                        RoundCorner {
                            id: corner2
                            x: {
                                if (root.isBottom) return parent.width - dockContainer.cornerSize;
                                if (root.isLeft) return 0;  // Left edge (screen border)
                                if (root.isRight) return parent.width - dockContainer.cornerSize;  // Right edge (screen border)
                                return 0;
                            }
                            y: parent.height - dockContainer.cornerSize  // Always at bottom of container
                            size: Math.max(dockContainer.cornerSize, 1)
                            corner: {
                                if (root.isBottom) return RoundCorner.CornerEnum.BottomLeft;
                                if (root.isLeft) return RoundCorner.CornerEnum.TopLeft;  // Curves up toward dock
                                if (root.isRight) return RoundCorner.CornerEnum.TopRight;  // Curves up toward dock
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
                                if (root.isBottom) return dockContainer.cornerSize;
                                return 0;  // Vertical docks: no x offset
                            }
                            y: {
                                if (root.isBottom) return 0;
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
                                
                                background: Rectangle {
                                    radius: Styling.radius(-2)
                                    color: root.pinned ? 
                                        Colors.primary : 
                                        (pinButton.hovered ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.15) : "transparent")
                                    
                                    Behavior on color {
                                        enabled: Config.animDuration > 0
                                        ColorAnimation { duration: Config.animDuration / 2 }
                                    }
                                }
                                
                                contentItem: Text {
                                    text: Icons.pin
                                    font.family: Icons.font
                                    font.pixelSize: 16
                                    color: root.pinned ? Colors.overPrimary : Colors.overBackground
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    
                                    rotation: root.pinned ? 0 : 45
                                    Behavior on rotation {
                                        enabled: Config.animDuration > 0
                                        NumberAnimation { duration: Config.animDuration / 2 }
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
                                
                                background: Rectangle {
                                    radius: Styling.radius(-2)
                                    color: overviewButton.hovered ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.15) : "transparent"
                                    
                                    Behavior on color {
                                        enabled: Config.animDuration > 0
                                        ColorAnimation { duration: Config.animDuration / 2 }
                                    }
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
                                
                                background: Rectangle {
                                    radius: Styling.radius(-2)
                                    color: root.pinned ? 
                                        Colors.primary : 
                                        (pinButtonV.hovered ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.15) : "transparent")
                                    
                                    Behavior on color {
                                        enabled: Config.animDuration > 0
                                        ColorAnimation { duration: Config.animDuration / 2 }
                                    }
                                }
                                
                                contentItem: Text {
                                    text: Icons.pin
                                    font.family: Icons.font
                                    font.pixelSize: 16
                                    color: root.pinned ? Colors.overPrimary : Colors.overBackground
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    
                                    rotation: root.pinned ? 0 : 45
                                    Behavior on rotation {
                                        enabled: Config.animDuration > 0
                                        NumberAnimation { duration: Config.animDuration / 2 }
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
                                
                                background: Rectangle {
                                    radius: Styling.radius(-2)
                                    color: overviewButtonV.hovered ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.15) : "transparent"
                                    
                                    Behavior on color {
                                        enabled: Config.animDuration > 0
                                        ColorAnimation { duration: Config.animDuration / 2 }
                                    }
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
                            ctx.lineCap = "round";

                            var offset = borderWidth / 2;
                            var cs = dockContainer.cornerSize;
                            
                            // Floating radii
                            var tl = dockBackground.topLeftRadius;
                            var tr = dockBackground.topRightRadius;
                            var bl = dockBackground.bottomLeftRadius;
                            var br = dockBackground.bottomRightRadius;

                            ctx.beginPath();
                            
                            if (root.isBottom) {
                                // Start at Bottom Left (Screen Edge)
                                ctx.moveTo(offset, height - offset);
                                
                                // Left Fillet (Bottom Edge -> Left Side)
                                // ACW from 90 (Bottom) to 0 (Right)
                                ctx.arc(offset, height - cs, cs - offset, Math.PI / 2, 0, true);
                                
                                // Line Up
                                ctx.lineTo(cs, tl);
                                
                                // Top Left Corner
                                if (tl > 0) ctx.arcTo(cs, offset, cs + tl, offset, tl - offset);
                                else ctx.lineTo(cs, offset);
                                
                                // Line Right
                                ctx.lineTo(width - cs - tr, offset);
                                
                                // Top Right Corner
                                if (tr > 0) ctx.arcTo(width - cs, offset, width - cs, offset + tr, tr - offset);
                                else ctx.lineTo(width - cs, offset);
                                
                                // Line Down
                                ctx.lineTo(width - cs, height - cs);
                                
                                // Right Fillet (Right Side -> Bottom Edge)
                                // ACW from 180 (Left) to 90 (Bottom)
                                ctx.arc(width - offset, height - cs, cs - offset, Math.PI, Math.PI / 2, true);
                                
                                // Close to start
                                ctx.lineTo(offset, height - offset);
                                
                            } else if (root.isLeft) {
                                // Start at Top Left (Screen Edge)
                                ctx.moveTo(offset, offset);
                                
                                // Top Fillet (Left Edge -> Top Side)
                                // ACW from 180 (Left) to 90 (Bottom/Right-ish) - wait, Angle 90 is Down.
                                // In standard canvas: 0 Right, 90 Down, 180 Left, 270 Top.
                                // We want Tangent Down (at 180) to Tangent Right (at 270 Top).
                                // My manual logic said: Center (cs, offset). Start (offset, offset) [Angle 180]. End (cs, cs) [Angle 90].
                                // Angle 90 is Down.
                                // Wait, if we are at (cs, cs) relative to (cs, offset).
                                // dx=0, dy=cs-offset. Positive Y is Down. So Angle 90 is correct.
                                // Tangent at 90 (Bottom point of circle) is Horizontal.
                                // ACW (Decreasing Angle). 180 -> 90? No, 180 -> 90 is crossing 0/360 if ACW?
                                // No. 180 -> 90 is CW (decreasing). 180 -> 270 is ACW (increasing).
                                // Canvas arc(start, end, anticlockwise).
                                // true = anticlockwise.
                                // 180 -> 270 (Top) is ACW.
                                // But (cs, cs) is Angle 90 (Bottom).
                                // We want to go from Left Edge (Angle 180) to Top Edge of Dock (Tanget Right).
                                // Tangent Right is at Angle 270 (Top of Circle).
                                // So we need to end at Angle 270.
                                // Point at 270: (cs, offset - R) = (cs, offset - (cs - offset)) = (cs, 2*offset - cs).
                                // This is way above.
                                // This means my center calculation was for a different shape.
                                // Let's look at Bottom Dock Left Fillet again.
                                // Center (offset, height - cs). Radius cs - offset.
                                // Start (offset, height - offset).
                                // dy = (height - offset) - (height - cs) = cs - offset.
                                // This is +R. So Angle 90 (Down/Bottom).
                                // Tangent at 90 is Horizontal.
                                // We are moving Right. Tangent Vector (1, 0).
                                // ACW circle at 90: Tangent is (1, 0). Correct.
                                // End (cs, height - cs).
                                // dy = 0. dx = cs - offset. Angle 0 (Right).
                                // Tangent at 0: Vertical Up (0, -1).
                                // ACW circle at 0: Tangent is (0, -1). Correct.
                                // So Bottom Dock ACW 90 -> 0 works.

                                // Now Left Dock Top Fillet.
                                // Connects x=0 to y=cs.
                                // Moving Down along x=0, then Curve, then Right along y=cs.
                                // Start Tangent: Down (0, 1).
                                // End Tangent: Right (1, 0).
                                // 90 degree turn Left (Counter-Clockwise turn).
                                // So we need an ACW arc.
                                // Start Point: (offset, offset).
                                // End Point: (cs, cs).
                                // Circle Center (cs, offset).
                                // At Start: (offset, offset). Relative (-R, 0). Angle 180.
                                // Tangent of ACW circle at 180: Down (0, 1). Correct.
                                // At End: (cs, cs). Relative (0, R). Angle 90.
                                // Tangent of ACW circle at 90: Right (1, 0). Correct.
                                // Wait, ACW traversal of unit circle:
                                // 0 (Right) -> goes Up? No.
                                // Standard coord: Y down.
                                // x = cos t, y = sin t.
                                // t increases -> ACW? No, Clockwise on screen (since Y is flipped).
                                // Math ACW (counter-clockwise) is X -> Y.
                                // On screen (+X Right, +Y Down), X -> Y is Clockwise rotation visually.
                                // So increasing angle is CW on screen.
                                // Canvas `anticlockwise` parameter:
                                // "true" means Counter-Clockwise in Math? Or Visually?
                                // "The arc() method creates a circular arc centered at (x, y) with a radius r. The path starts at startAngle and ends at endAngle, traveling in the direction given by anticlockwise (defaulting to clockwise)."
                                // HTML5 Canvas: Default is Clockwise (false).
                                // Screen coords: 0 is Right. PI/2 is Down.
                                // 0 -> PI/2 is Clockwise visually.
                                // So increasing angle = Clockwise.
                                // `anticlockwise = true` means decreasing angle.
                                // Bottom Dock: 90 -> 0. Decreasing. ACW.
                                // Left Dock: 180 -> 90. Decreasing. ACW.
                                // So logic holds.
                                
                                ctx.arc(cs, offset, cs - offset, Math.PI, Math.PI / 2, true);
                                
                                // Line Right
                                ctx.lineTo(width - tr, cs);
                                
                                // Top Right Corner
                                if (tr > 0) ctx.arcTo(width - offset, cs, width - offset, cs + tr, tr - offset);
                                else ctx.lineTo(width - offset, cs);
                                
                                // Line Down
                                ctx.lineTo(width - offset, height - cs - br);
                                
                                // Bottom Right Corner
                                if (br > 0) ctx.arcTo(width - offset, height - cs, width - offset - br, height - cs, br - offset);
                                else ctx.lineTo(width - offset, height - cs);
                                
                                // Line Left
                                ctx.lineTo(cs, height - cs);
                                
                                // Bottom Fillet (Bottom Side -> Left Edge)
                                // ACW from 270 (Top - wait) to 180 (Left).
                                // Start (cs, height - cs). Center (cs, height - offset).
                                // Relative: (0, -R). Angle 270 (3*PI/2).
                                // End (offset, height - offset).
                                // Relative: (-R, 0). Angle 180.
                                // 270 -> 180. Decreasing. ACW.
                                ctx.arc(cs, height - offset, cs - offset, 3 * Math.PI / 2, Math.PI, true);
                                
                                // Close
                                ctx.lineTo(offset, offset);
                                
                            } else if (root.isRight) {
                                // Start at Top Right (Screen Edge)
                                ctx.moveTo(width - offset, offset);
                                
                                // Top Fillet (Right Edge -> Top Side)
                                // Moving Down along x=width, then Curve, then Left along y=cs.
                                // Tangent Start: Down (0, 1).
                                // Tangent End: Left (-1, 0).
                                // Turn Right (Clockwise).
                                // Use `anticlockwise = false`.
                                // Start (width - offset, offset).
                                // End (width - cs, cs).
                                // Center (width - cs, offset).
                                // Start Rel: (R, 0). Angle 0.
                                // End Rel: (0, R). Angle 90.
                                // 0 -> 90. Increasing. CW.
                                ctx.arc(width - cs, offset, cs - offset, 0, Math.PI / 2, false);
                                
                                // Line Left
                                ctx.lineTo(tl, cs);
                                
                                // Top Left Corner
                                if (tl > 0) ctx.arcTo(offset, cs, offset, cs + tl, tl - offset);
                                else ctx.lineTo(offset, cs);
                                
                                // Line Down
                                ctx.lineTo(offset, height - cs - bl);
                                
                                // Bottom Left Corner
                                if (bl > 0) ctx.arcTo(offset, height - cs, offset + bl, height - cs, bl - offset);
                                else ctx.lineTo(offset, height - cs);
                                
                                // Line Right
                                ctx.lineTo(width - cs, height - cs);
                                
                                // Bottom Fillet (Bottom Side -> Right Edge)
                                // CW from 270 (Top) to 360/0 (Right).
                                // Start (width - cs, height - cs).
                                // End (width - offset, height - offset).
                                // Center (width - cs, height - offset).
                                // Start Rel: (0, -R). Angle 270.
                                // End Rel: (R, 0). Angle 0 (or 360).
                                // 270 -> 360. CW.
                                ctx.arc(width - cs, height - offset, cs - offset, 3 * Math.PI / 2, 2 * Math.PI, false);
                                
                                // Close
                                ctx.lineTo(width - offset, offset);
                            }
                            
                            ctx.stroke();
                        }
                        
                        // Signal connections for repainting
                        Connections { target: Colors; function onPrimaryChanged() { outlineCanvas.requestPaint(); } }
                        Connections { target: Config.theme.srBg; function onBorderChanged() { outlineCanvas.requestPaint(); } }
                        Connections { target: dockBackground; function onBottomLeftRadiusChanged() { outlineCanvas.requestPaint(); } }
                        Connections { target: dockBackground; function onBottomRightRadiusChanged() { outlineCanvas.requestPaint(); } }
                        Connections { target: dockBackground; function onTopLeftRadiusChanged() { outlineCanvas.requestPaint(); } }
                        Connections { target: dockBackground; function onTopRightRadiusChanged() { outlineCanvas.requestPaint(); } }
                        Connections { target: dockContainer; function onWidthChanged() { outlineCanvas.requestPaint(); } }
                        Connections { target: dockContainer; function onHeightChanged() { outlineCanvas.requestPaint(); } }
                        Connections { target: root; function onIsDefaultChanged() { outlineCanvas.requestPaint(); } }
                        Connections { target: root; function onPositionChanged() { outlineCanvas.requestPaint(); } }
                    }
                }
            }
        }
    }
}

