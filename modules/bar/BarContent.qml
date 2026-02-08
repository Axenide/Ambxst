import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import qs.modules.bar.workspaces
import qs.modules.theme
import qs.modules.bar.clock
import qs.modules.bar.systray
import qs.modules.widgets.overview
import qs.modules.widgets.dashboard
import qs.modules.widgets.powermenu
import qs.modules.widgets.presets
import qs.modules.corners
import qs.modules.components
import qs.modules.services
import qs.modules.globals
import qs.modules.bar
import qs.config
import "." as Bar
import "BarItemRegistry.js" as BarItems

Item {
    id: root

    required property ShellScreen screen

    property string barPosition: ["top", "bottom", "left", "right"].includes(Config.bar.position) ? Config.bar.position : "top"
    property string orientation: barPosition === "left" || barPosition === "right" ? "vertical" : "horizontal"

    // Auto-hide properties
    property bool pinned: Config.bar?.pinnedOnStartup ?? true

    // Fullscreen detection - check if active toplevel is fullscreen on this screen
    readonly property bool activeWindowFullscreen: {
        const toplevel = ToplevelManager.activeToplevel;
        if (!toplevel || !toplevel.activated)
            return false;
        // Check if the toplevel is fullscreen
        return toplevel.fullscreen === true;
    }

    // Whether auto-hide should be active (not pinned, or fullscreen forces it)
    readonly property bool shouldAutoHide: !pinned || activeWindowFullscreen

    onShouldAutoHideChanged: {
        if (!shouldAutoHide) {
            hoverActive = false;
            hideDelayTimer.stop();
        }
    }

    // Hover state with delay to prevent flickering
    property bool hoverActive: false

    // Track if mouse is over bar area
    readonly property bool isMouseOverBar: barMouseArea.containsMouse

    // Check if notch hover is active (for synchronized reveal when bar is at same side)
    // NOTE: We access Visibilities.notchPanels directly because UnifiedShellPanel registers itself as the panel ref
    readonly property var notchPanelRef: Visibilities.notchPanels[screen.name]
    readonly property string notchPosition: Config.notchPosition ?? "top"
    readonly property var notchContainerRef: Visibilities.getNotchForScreen(screen.name)
    readonly property bool notchHoverActive: {
        if (barPosition !== notchPosition)
            return false;
        
        if (notchPanelRef) {
            // UnifiedShellPanel exposes 'notchHoverActive' property alias pointing to notchContent.hoverActive
            // We need to check if that property exists on the panel object
            if (typeof notchPanelRef.notchHoverActive !== 'undefined') {
                return notchPanelRef.notchHoverActive;
            }
            // Fallback for compatibility
            if (typeof notchPanelRef.hoverActive !== 'undefined') {
                return notchPanelRef.hoverActive;
            }
        }
        return false;
    }

    // Check if notch is open (dashboard, powermenu, etc.)
    readonly property var screenVisibilities: Visibilities.getForScreen(screen.name)
    readonly property bool notchOpen: screenVisibilities ? (screenVisibilities.launcher || screenVisibilities.dashboard || screenVisibilities.powermenu || screenVisibilities.tools) : false

    // Radius logic for "Squished" style
    readonly property real outerRadius: Styling.radius(0)
    readonly property real innerRadius: (Config.bar.pillStyle === "squished") ? Styling.radius(0) / 2 : Styling.radius(0)
    readonly property bool pinButtonVisible: Config.bar?.showPinButton ?? true

    // Reveal logic
    readonly property bool reveal: {
        // If not auto-hiding, always reveal
        if (!shouldAutoHide)
            return true;

        // If fullscreen and not available on fullscreen, hide
        if (activeWindowFullscreen && !(Config.bar?.availableOnFullscreen ?? false)) {
            return false;
        }

        // Show if: hovering, notch hovering (when at top), notch open
        // IMPORTANT: notchHoverActive must be checked to synchronize with notch
        return isMouseOverBar || hoverActive || notchHoverActive || notchOpen;
    }

    // Timer to delay hiding the bar after mouse leaves
    Timer {
        id: hideDelayTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (!root.isMouseOverBar) {
                root.hoverActive = false;
            }
        }
    }

    // Watch for mouse state changes
    onIsMouseOverBarChanged: {
        if (isMouseOverBar) {
            hideDelayTimer.stop();
            hoverActive = true;
        } else {
            // Si está fijada, podemos resetear el hoverActive inmediatamente
            // Si está en auto-hide, usamos el timer para dar margen
            if (shouldAutoHide) {
                hideDelayTimer.restart();
            } else {
                hoverActive = false;
            }
        }
    }

    // Integrated dock configuration
    readonly property bool integratedDockEnabled: (Config.dock?.enabled ?? false) && (Config.dock?.theme ?? "default") === "integrated"
    // Map dock position for integrated based on orientation
    readonly property string integratedDockPosition: {
        const pos = Config.dock?.position ?? "center";

        if (root.orientation === "horizontal") {
            if (pos === "left" || pos === "start")
                return "start";
            if (pos === "right" || pos === "end")
                return "end";
            return "center";
        }
        
        // Vertical always falls back to center logic inside the column but we treat it as appended to group
        return "center";
    }

    // Radius helpers for dock connections
    readonly property bool dockAtStart: integratedDockEnabled && integratedDockPosition === "start"
    readonly property bool dockAtEnd: integratedDockEnabled && integratedDockPosition === "end"

    readonly property int frameOffset: (Config.bar?.frameEnabled ?? false) ? (Config.bar?.frameThickness ?? 6) : 0

    // Size derived from barBg properties
    readonly property int barPadding: barBg.padding
    readonly property int topOuterMargin: (orientation === "vertical" || barPosition === "top") ? barBg.outerMargin : 0
    readonly property int bottomOuterMargin: (orientation === "vertical" || barPosition === "bottom") ? barBg.outerMargin : 0
    readonly property int leftOuterMargin: (orientation === "horizontal" || barPosition === "left") ? barBg.outerMargin : 0
    readonly property int rightOuterMargin: (orientation === "horizontal" || barPosition === "right") ? barBg.outerMargin : 0

    readonly property int contentImplicitWidth: orientation === "horizontal" ? horizontalLayout.implicitWidth : verticalLayout.implicitWidth
    readonly property int contentImplicitHeight: orientation === "horizontal" ? horizontalLayout.implicitHeight : verticalLayout.implicitHeight
    
    readonly property int barTargetWidth: orientation === "vertical" ? (contentImplicitWidth + 2 * barPadding) : 0
    readonly property int barTargetHeight: orientation === "horizontal" ? (contentImplicitHeight + 2 * barPadding) : 0

    readonly property bool actualContainBar: Config.bar?.containBar && (Config.bar?.frameEnabled ?? false)
    readonly property int totalBarWidth: barTargetWidth + 
        ((root.barPosition === "left" || root.orientation === "horizontal") ? (root.frameOffset + root.leftOuterMargin) : 0) +
        ((root.barPosition === "right" || root.orientation === "horizontal") ? (root.frameOffset + root.rightOuterMargin) : 0)

    readonly property int totalBarHeight: barTargetHeight + 
        ((root.barPosition === "top" || root.orientation === "vertical") ? (root.frameOffset + root.topOuterMargin) : 0) +
        ((root.barPosition === "bottom" || root.orientation === "vertical") ? (root.frameOffset + root.bottomOuterMargin) : 0)

    // Base outer margin for reservation logic (4px + border when !containBar)
    readonly property int baseOuterMargin: barBg.outerMargin

    // Shadow logic for bar components
    readonly property bool shadowsEnabled: Config.showBackground && (!actualContainBar || Config.bar.keepBarShadow)

    readonly property var barItemIds: BarItems.itemIds

    function normalizeBarItemList(list, fallback) {
        if (list === undefined || list === null || typeof list.length === "undefined")
            return fallback ? fallback.slice() : [];

        var normalized = [];
        for (var i = 0; i < list.length; i++) {
            var itemId = list[i];
            if (barItemIds.includes(itemId))
                normalized.push(itemId);
        }
        return normalized;
    }

    function asArray(list) {
        var out = [];
        if (!list || typeof list.length === "undefined")
            return out;
        for (var i = 0; i < list.length; i++)
            out.push(list[i]);
        return out;
    }

    readonly property var barItemsLeft: normalizeBarItemList(Config.bar?.itemsLeft, BarItems.defaultLeft)
    readonly property var barItemsCenter: normalizeBarItemList(Config.bar?.itemsCenter, BarItems.defaultCenter)
    readonly property var barItemsRight: normalizeBarItemList(Config.bar?.itemsRight, BarItems.defaultRight)
    readonly property var barItemsCenterNonDock: barItemsCenter.filter(itemId => itemId !== "dock")
    readonly property var barItemsLeftVertical: normalizeBarItemList(Config.bar?.itemsLeftVertical, ["launcher", "systray", "tools", "presets"])
    readonly property var barItemsCenterVertical: normalizeBarItemList(Config.bar?.itemsCenterVertical, ["layout", "workspaces", "pin"]).filter(itemId => itemId !== "notch")
    readonly property var barItemsRightVertical: normalizeBarItemList(Config.bar?.itemsRightVertical, ["controls", "battery", "clock", "power"])
    readonly property bool barCenterDockEnabled: barItemsCenter.includes("dock")
    readonly property bool notchBlocksCenter: root.orientation === "horizontal"
        && (root.barPosition === "top" || root.barPosition === "bottom")
        && root.barPosition === notchPosition
        && (Config.bar?.centerItemsSplitByNotch ?? true)
    function computeNotchGap() {
        if (!notchBlocksCenter)
            return 0;
        const notchWidth = Math.max(
            Visibilities.getNotchWidth(screen.name),
            notchPanelRef?.notchWidth ?? 0,
            notchPanelRef?.notchHitboxWidth ?? 0,
            notchContainerRef?.implicitWidth ?? 0,
            notchContainerRef?.width ?? 0
        );
        const rawGap = Math.max(0, Math.round(notchWidth + 16));
        return rawGap;
    }

    readonly property int notchGapDebug: computeNotchGap()
    readonly property var barItemsCenterDisplay: {
        var items = asArray(barItemsCenterNonDock).filter(id => id !== "notch");
        if (!notchBlocksCenter)
            return items;
        var mid = Math.ceil(items.length / 2);
        items.splice(mid, 0, "notch");
        return items;
    }
    readonly property int centerNotchIndex: notchBlocksCenter ? barItemsCenterDisplay.indexOf("notch") : -1
    readonly property var barItemsCenterLeft: centerNotchIndex >= 0 ? barItemsCenterDisplay.slice(0, centerNotchIndex) : barItemsCenterDisplay
    readonly property var barItemsCenterRight: centerNotchIndex >= 0 ? barItemsCenterDisplay.slice(centerNotchIndex + 1) : []


    function componentForBarItem(itemId, groupRole) {
        switch (itemId) {
        case "launcher": return launcherItemComponent;
        case "workspaces": return workspacesItemComponent;
        case "layout": return layoutSelectorItemComponent;
        case "pin": return pinButtonItemComponent;
        case "dock": return (groupRole === "center") ? dockCenteredItemComponent : dockInlineItemComponent;
        case "presets": return presetsItemComponent;
        case "tools": return toolsItemComponent;
        case "systray": return systrayItemComponent;
        case "controls": return controlsItemComponent;
        case "battery": return batteryItemComponent;
        case "clock": return clockItemComponent;
        case "power": return powerItemComponent;
        case "separator": return separatorItemComponent;
        case "notch": return notchSpacerComponent;
        default: return null;
        }
    }

    function barItemsForRole(role) {
        if (root.orientation === "vertical") {
            if (role === "left")
                return barItemsLeftVertical;
            if (role === "center")
                return barItemsCenterVertical;
            return barItemsRightVertical;
        }
        if (role === "left")
            return barItemsLeft;
        if (role === "center")
            return barItemsCenterNonDock;
        return barItemsRight;
    }

    function barItemIndex(role, itemId) {
        var items = barItemsForRole(role);
        if (!items || typeof items.indexOf !== "function")
            return -1;
        return items.indexOf(itemId);
    }

    function barItemCount(role) {
        var items = barItemsForRole(role);
        return items ? items.length : 0;
    }

    function configureBarItem(itemId, item, startRadius, endRadius, groupRole) {
        if (!item)
            return;

        if (typeof item.startRadius !== "undefined")
            item.startRadius = startRadius;
        if (typeof item.endRadius !== "undefined")
            item.endRadius = endRadius;

        if (typeof item.enableShadow !== "undefined")
            item.enableShadow = root.shadowsEnabled;
        if (typeof item.layerEnabled !== "undefined")
            item.layerEnabled = root.shadowsEnabled;
        if (typeof item.bar !== "undefined")
            item.bar = root;
        if (typeof item.orientation !== "undefined")
            item.orientation = Qt.binding(() => root.orientation);
        if (typeof item.vertical !== "undefined")
            item.vertical = Qt.binding(() => root.orientation === "vertical");
        if (typeof item.groupRole !== "undefined")
            item.groupRole = groupRole;
    }

    // The hitbox for the mask
    property alias barHitbox: barMouseArea

    // MouseArea for hover detection - contains bar content (like Dock)
    MouseArea {
        id: barMouseArea
        hoverEnabled: true

        // Size includes margins
        width: root.orientation === "horizontal" ? root.width : (root.reveal ? root.totalBarWidth : Math.max(Config.bar?.hoverRegionHeight ?? 8, 4) + root.frameOffset + barBg.displacement)
        height: root.orientation === "vertical" ? root.height : (root.reveal ? root.totalBarHeight : Math.max(Config.bar?.hoverRegionHeight ?? 8, 4) + root.frameOffset + barBg.displacement)


        // Position using x/y
        x: {
            if (root.barPosition === "right") return parent.width - width;
            return 0;
        }
        y: {
            if (root.barPosition === "bottom") return parent.height - height;
            return 0;
        }

        Behavior on x {
            enabled: Config.animDuration > 0 && root.orientation === "vertical"
            NumberAnimation {
                duration: Config.animDuration / 4
                easing.type: Easing.OutCubic
            }
        }
        Behavior on y {
            enabled: Config.animDuration > 0 && root.orientation === "horizontal"
            NumberAnimation {
                duration: Config.animDuration / 4
                easing.type: Easing.OutCubic
            }
        }

        Behavior on width {
            enabled: Config.animDuration > 0 && root.orientation === "vertical"
            NumberAnimation {
                duration: Config.animDuration / 4
                easing.type: Easing.OutCubic
            }
        }
        Behavior on height {
            enabled: Config.animDuration > 0 && root.orientation === "horizontal"
            NumberAnimation {
                duration: Config.animDuration / 4
                easing.type: Easing.OutCubic
            }
        }

        // Bar content inside MouseArea (clicks pass through to children)
        Item {
            id: bar

            anchors {
                top: (root.barPosition === "top" || root.orientation === "vertical") ? parent.top : undefined
                bottom: (root.barPosition === "bottom" || root.orientation === "vertical") ? parent.bottom : undefined
                left: (root.barPosition === "left" || root.orientation === "horizontal") ? parent.left : undefined
                right: (root.barPosition === "right" || root.orientation === "horizontal") ? parent.right : undefined

                topMargin: (root.barPosition === "top" || root.orientation === "vertical") ? (root.frameOffset + root.topOuterMargin) : 0
                bottomMargin: (root.barPosition === "bottom" || root.orientation === "vertical") ? (root.frameOffset + root.bottomOuterMargin) : 0
                leftMargin: (root.barPosition === "left" || root.orientation === "horizontal") ? (root.frameOffset + root.leftOuterMargin) : 0
                rightMargin: (root.barPosition === "right" || root.orientation === "horizontal") ? (root.frameOffset + root.rightOuterMargin) : 0
            }


            // layer.enabled: true
            // layer.effect: Shadow {}

            // Opacity animation
            opacity: root.reveal ? 1 : 0
            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 2
                    easing.type: Easing.OutCubic
                }
            }

            // Slide animation
            transform: Translate {
                x: {
                    if (!root.shouldAutoHide)
                        return 0;
                    if (root.barPosition === "left")
                        return root.reveal ? 0 : -bar.width - (root.frameOffset + root.leftOuterMargin);
                    if (root.barPosition === "right")
                        return root.reveal ? 0 : bar.width + (root.frameOffset + root.rightOuterMargin);
                    return 0;
                }
                y: {
                    if (!root.shouldAutoHide)
                        return 0;
                    if (root.barPosition === "top")
                        return root.reveal ? 0 : -bar.height - (root.frameOffset + root.topOuterMargin);
                    if (root.barPosition === "bottom")
                        return root.reveal ? 0 : bar.height + (root.frameOffset + root.bottomOuterMargin);
                    return 0;
                }
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

            states: [
                State {
                    name: "top"
                    when: root.barPosition === "top"
                    PropertyChanges {
                        target: bar
                        height: root.barTargetHeight
                    }
                },
                State {
                    name: "bottom"
                    when: root.barPosition === "bottom"
                    PropertyChanges {
                        target: bar
                        height: root.barTargetHeight
                    }
                },
                State {
                    name: "left"
                    when: root.barPosition === "left"
                    PropertyChanges {
                        target: bar
                        width: root.barTargetWidth
                    }
                },
                State {
                    name: "right"
                    when: root.barPosition === "right"
                    PropertyChanges {
                        target: bar
                        width: root.barTargetWidth
                    }
                }
            ]

            BarBg {
                id: barBg
                anchors.fill: parent
                position: root.barPosition

                component BarItemLoader: Item {
                    id: barItemRoot
                    property string itemKey: ""
                    property int itemIndexCtx: -1
                    property int itemCountCtx: -1
                    property int itemIndexChainCtx: -1
                    property int itemCountChainCtx: -1
                    property string groupRole: "left"

                    Layout.alignment: Qt.AlignVCenter

                    readonly property string itemId: itemKey
                    readonly property int itemIndex: itemIndexCtx >= 0 ? itemIndexCtx : root.barItemIndex(groupRole, itemId)
                    readonly property int itemCount: itemCountCtx >= 0 ? itemCountCtx : root.barItemCount(groupRole)
                    readonly property bool useChainRadii: (Config.bar?.pillStyle ?? "default") === "squished" && itemIndexChainCtx >= 0 && itemCountChainCtx >= 0
                    readonly property int effectiveIndex: useChainRadii ? itemIndexChainCtx : itemIndex
                    readonly property int effectiveCount: useChainRadii ? itemCountChainCtx : itemCount
                    readonly property int chainIndex: effectiveIndex
                    readonly property real startRadius: {
                        if (effectiveCount <= 1)
                            return root.outerRadius;
                        return chainIndex <= 0 ? root.outerRadius : root.innerRadius;
                    }
                    readonly property real endRadius: {
                        if (effectiveCount <= 1)
                            return root.outerRadius;
                        return (chainIndex >= 0 && chainIndex === (effectiveCount - 1)) ? root.outerRadius : root.innerRadius;
                    }

                    implicitWidth: {
                        if (!itemLoader.item)
                            return 0;
                        if (itemLoader.item.implicitWidth > 0)
                            return itemLoader.item.implicitWidth;
                        if (itemLoader.item.Layout && itemLoader.item.Layout.preferredWidth > 0)
                            return itemLoader.item.Layout.preferredWidth;
                        return 36;
                    }
                    implicitHeight: {
                        if (!itemLoader.item)
                            return 0;
                        if (itemLoader.item.implicitHeight > 0)
                            return itemLoader.item.implicitHeight;
                        if (itemLoader.item.Layout && itemLoader.item.Layout.preferredHeight > 0)
                            return itemLoader.item.Layout.preferredHeight;
                        return 36;
                    }

                    Loader {
                        id: itemLoader
                        anchors.fill: barItemRoot
                        sourceComponent: root.componentForBarItem(itemId, groupRole)
                        onLoaded: {
                            root.configureBarItem(itemId, item, startRadius, endRadius, groupRole);
                            if (item && typeof item.startRadius !== "undefined")
                                item.startRadius = Qt.binding(() => barItemRoot.startRadius);
                            if (item && typeof item.endRadius !== "undefined")
                                item.endRadius = Qt.binding(() => barItemRoot.endRadius);
                            if (item && item.implicitWidth <= 0 && item.implicitHeight <= 0 && item.width <= 0 && item.height <= 0) {
                                item.anchors.fill = itemLoader;
                            }
                        }
                    }
                }

                Component {
                    id: launcherItemComponent
                    LauncherButton {
                        startRadius: 0
                        endRadius: 0
                        enableShadow: root.shadowsEnabled
                    }
                }

                Component {
                    id: workspacesItemComponent
                    Workspaces {
                        orientation: root.orientation
                        bar: QtObject {
                            property var screen: root.screen
                        }
                        startRadius: 0
                        endRadius: 0
                    }
                }

                Component {
                    id: layoutSelectorItemComponent
                    LayoutSelectorButton {
                        bar: root
                        layerEnabled: root.shadowsEnabled
                        startRadius: 0
                        endRadius: 0
                    }
                }

                Component {
                    id: pinButtonItemComponent
                    Item {
                        id: pinButtonItemRoot
                        property real startRadius: 0
                        property real endRadius: 0

                        implicitWidth: pinButtonLoader.item ? pinButtonLoader.item.implicitWidth : 0
                        implicitHeight: pinButtonLoader.item ? pinButtonLoader.item.implicitHeight : 0

                        Loader {
                            id: pinButtonLoader
                            active: root.pinButtonVisible
                            visible: active

                            sourceComponent: Button {
                                id: pinButton
                                implicitWidth: 36
                                implicitHeight: 36

                                background: StyledRect {
                                    id: pinButtonBg
                                    variant: root.pinned ? "primary" : "bg"
                                    enableShadow: root.shadowsEnabled

                                    topLeftRadius: pinButtonItemRoot.startRadius
                                    bottomLeftRadius: pinButtonItemRoot.startRadius
                                    topRightRadius: pinButtonItemRoot.endRadius
                                    bottomRightRadius: pinButtonItemRoot.endRadius

                                    Rectangle {
                                        anchors.fill: parent
                                        color: Styling.srItem("overprimary")
                                        opacity: root.pinned ? 0 : (pinButton.pressed ? 0.5 : (pinButton.hovered ? 0.25 : 0))
                                        radius: parent.radius ?? 0

                                        Behavior on opacity {
                                            enabled: (Config.animDuration ?? 0) > 0
                                            NumberAnimation {
                                                duration: (Config.animDuration ?? 0) / 2
                                            }
                                        }
                                    }
                                }

                                contentItem: Text {
                                    text: Icons.pin
                                    font.family: Icons.font
                                    font.pixelSize: 18
                                    color: root.pinned ? pinButtonBg.item : (pinButton.pressed ? Colors.background : (Styling.srItem("overprimary") || Colors.foreground))
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
                                    tooltipText: root.pinned ? "Unpin bar" : "Pin bar"
                                }
                            }
                        }
                    }
                }

                Component {
                    id: dockCenteredItemComponent
                    Item {
                        id: dockCenteredRoot
                        property real startRadius: 0
                        property real endRadius: 0

                        visible: root.integratedDockEnabled
                        anchors.fill: parent

                        Bar.IntegratedDock {
                            bar: root
                            orientation: root.orientation
                            anchors.verticalCenter: parent.verticalCenter
                            enableShadow: root.shadowsEnabled

                            startRadius: dockCenteredRoot.startRadius
                            endRadius: dockCenteredRoot.endRadius

                            property real targetX: {
                                if (root.integratedDockPosition === "start")
                                    return 0;
                                if (root.integratedDockPosition === "end")
                                    return parent.width - width;

                                return (bar.width - width) / 2 - (parent.x + 4);
                            }

                            x: Math.max(0, Math.min(parent.width - width, targetX))

                            width: Math.min(implicitWidth, parent.width)
                            height: implicitHeight
                        }
                    }
                }

                Component {
                    id: dockInlineItemComponent
                    Bar.IntegratedDock {
                        bar: root
                        orientation: root.orientation
                        enableShadow: root.shadowsEnabled
                        visible: root.integratedDockEnabled
                        startRadius: 0
                        endRadius: 0
                    }
                }

                Component {
                    id: presetsItemComponent
                    PresetsButton {
                        startRadius: 0
                        endRadius: 0
                        enableShadow: root.shadowsEnabled
                    }
                }

                Component {
                    id: toolsItemComponent
                    ToolsButton {
                        startRadius: 0
                        endRadius: 0
                        enableShadow: root.shadowsEnabled
                    }
                }

                Component {
                    id: systrayItemComponent
                    SysTray {
                        bar: root
                        enableShadow: root.shadowsEnabled
                        startRadius: 0
                        endRadius: 0
                    }
                }

                Component {
                    id: controlsItemComponent
                    ControlsButton {
                        bar: root
                        layerEnabled: root.shadowsEnabled
                        startRadius: 0
                        endRadius: 0
                    }
                }

                Component {
                    id: batteryItemComponent
                    Bar.BatteryIndicator {
                        bar: root
                        layerEnabled: root.shadowsEnabled
                        startRadius: 0
                        endRadius: 0
                    }
                }

                Component {
                    id: clockItemComponent
                    Clock {
                        bar: root
                        layerEnabled: root.shadowsEnabled
                        startRadius: 0
                        endRadius: 0
                    }
                }

                Component {
                    id: powerItemComponent
                    PowerButton {
                        startRadius: 0
                        endRadius: 0
                        enableShadow: root.shadowsEnabled
                    }
                }

                Component {
                    id: separatorItemComponent
                    Separator {
                        vert: root.orientation === "horizontal"
                        implicitWidth: root.orientation === "horizontal"
                            ? Math.max(3, (Config.theme.srBg.border[1] ?? 1) + 1)
                            : Math.max(12, root.contentImplicitWidth - 10)
                        implicitHeight: root.orientation === "horizontal"
                            ? Math.max(12, root.contentImplicitHeight - 10)
                            : Math.max(3, (Config.theme.srBg.border[1] ?? 1) + 1)
                    }
                }

                Component {
                    id: notchSpacerComponent
                    Item {
                        implicitWidth: centerOverlay?.effectiveNotchGap ?? 0
                        width: centerOverlay?.effectiveNotchGap ?? 0
                        implicitHeight: 36
                        visible: root.notchBlocksCenter
                    }
                }

                RowLayout {
                    id: horizontalLayout
                    visible: root.orientation === "horizontal"
                    anchors.fill: parent
                    spacing: 4

                    RowLayout {
                        id: leftGroup
                        spacing: 4
                        Layout.alignment: Qt.AlignVCenter

                        Repeater {
                            model: root.asArray(root.barItemsLeft)
                            delegate: BarItemLoader {
                                itemKey: modelData
                                itemIndexCtx: index
                                itemCountCtx: root.asArray(root.barItemsLeft).length
                                groupRole: "left"
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }

                    RowLayout {
                        id: rightGroup
                        spacing: 4
                        Layout.alignment: Qt.AlignVCenter

                        Repeater {
                            model: root.asArray(root.barItemsRight)
                            delegate: BarItemLoader {
                                itemKey: modelData
                                itemIndexCtx: index
                                itemCountCtx: root.asArray(root.barItemsRight).length
                                groupRole: "right"
                            }
                        }
                    }
                }

                Item {
                    id: centerOverlay
                    anchors.fill: parent
                    visible: root.orientation === "horizontal" && (root.barItemsCenterDisplay.length > 0 || root.barCenterDockEnabled)
                    property int effectiveNotchGap: root.computeNotchGap()
                    property int notchHalfGap: Math.round(effectiveNotchGap / 2)

                    BarItemLoader {
                        anchors.fill: parent
                        visible: root.barCenterDockEnabled
                        itemKey: "dock"
                        itemIndexCtx: 0
                        groupRole: "center"
                    }

                    RowLayout {
                        id: centerLeftGroup
                        anchors.right: parent.horizontalCenter
                        anchors.rightMargin: root.notchBlocksCenter ? centerOverlay.notchHalfGap : 0
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        visible: root.notchBlocksCenter && root.barItemsCenterLeft.length > 0

                        Repeater {
                            model: root.asArray(root.barItemsCenterLeft)
                            delegate: BarItemLoader {
                                itemKey: modelData
                                itemIndexCtx: index
                                itemCountCtx: root.asArray(root.barItemsCenterLeft).length
                                itemIndexChainCtx: root.notchBlocksCenter ? index : -1
                                itemCountChainCtx: root.notchBlocksCenter ? (root.asArray(root.barItemsCenterLeft).length + 1) : -1
                                groupRole: "center"
                            }
                        }
                    }

                    RowLayout {
                        id: centerRightGroup
                        anchors.left: parent.horizontalCenter
                        anchors.leftMargin: root.notchBlocksCenter ? centerOverlay.notchHalfGap : 0
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        visible: root.notchBlocksCenter && root.barItemsCenterRight.length > 0

                        Repeater {
                            model: root.asArray(root.barItemsCenterRight)
                            delegate: BarItemLoader {
                                itemKey: modelData
                                itemIndexCtx: index
                                itemCountCtx: root.asArray(root.barItemsCenterRight).length
                                itemIndexChainCtx: root.notchBlocksCenter ? (index + 1) : -1
                                itemCountChainCtx: root.notchBlocksCenter ? (root.asArray(root.barItemsCenterRight).length + 1) : -1
                                groupRole: "center"
                            }
                        }
                    }
                }

                RowLayout {
                    id: centerUnifiedGroup
                    anchors.centerIn: parent
                    spacing: 4
                    visible: !root.notchBlocksCenter && root.barItemsCenterDisplay.length > 0

                    Repeater {
                        model: root.asArray(root.barItemsCenterDisplay)
                        delegate: BarItemLoader {
                            itemKey: modelData
                            itemIndexCtx: index
                            itemCountCtx: root.asArray(root.barItemsCenterDisplay).length
                            groupRole: "center"
                        }
                    }
                }

                ColumnLayout {
                    id: verticalLayout
                    visible: root.orientation === "vertical"
                    anchors.fill: parent
                    spacing: 4

                    ColumnLayout {
                        id: verticalTopGroup
                        spacing: 4
                        Layout.alignment: Qt.AlignHCenter

                        Repeater {
                            model: root.asArray(root.barItemsLeftVertical)
                            delegate: BarItemLoader {
                                itemKey: modelData
                                itemIndexCtx: index
                                itemCountCtx: root.asArray(root.barItemsLeftVertical).length
                                groupRole: "left"
                            }
                        }
                    }

                    // Center Group Container
                    Item {
                        Layout.fillHeight: true
                        Layout.fillWidth: true

                        ColumnLayout {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: root.barItemsCenterVertical.length > 0

                            // Calculate target position to be absolutely centered in the bar (vertically)
                            property real targetY: {
                                if (!parent || !bar)
                                    return 0;

                                // Force re-evaluation when parent moves
                                var _trigger = parent.y;

                                var parentPos = parent.mapToItem(bar, 0, 0);
                                return (bar.height - height) / 2 - parentPos.y;
                            }

                            // Clamp y position
                            y: Math.max(0, Math.min(parent.height - height, targetY))

                            height: Math.min(parent.height, implicitHeight)
                            width: parent.width
                            spacing: 4

                            Repeater {
                                model: root.asArray(root.barItemsCenterVertical)
                                delegate: BarItemLoader {
                                    itemKey: modelData
                                    itemIndexCtx: index
                                    itemCountCtx: root.asArray(root.barItemsCenterVertical).length
                                    groupRole: "center"
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        id: verticalBottomGroup
                        spacing: 4
                        Layout.alignment: Qt.AlignHCenter

                        Repeater {
                            model: root.asArray(root.barItemsRightVertical)
                            delegate: BarItemLoader {
                                itemKey: modelData
                                itemIndexCtx: index
                                itemCountCtx: root.asArray(root.barItemsRightVertical).length
                                groupRole: "right"
                            }
                        }
                    }
                }
            }
        }
    }
}
