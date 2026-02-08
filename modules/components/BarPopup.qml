pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.modules.theme
import qs.modules.components
import qs.config

// BarPopup: A popup component that anchors to bar elements
// Inspired by end-4/dots-hyprland BarPopup implementation
PopupWindow {
    id: root

    // Required: the item this popup anchors to
    required property Item anchorItem
    // Required: the bar panel for position detection
    required property var bar

    // Content to display inside the popup
    default property alias contentData: contentContainer.data

    // Visual configuration
    property int popupPadding: 8
    property int visualMargin: 8  // Distance from bar
    property int shadowMargin: 16  // Extra margin for shadow
    property string variant: "popup"  // StyledRect variant for background

    // Behavior configuration
    property bool closeOnFocusLost: true

    // Logical open state (changes immediately, not after animation)
    property bool isOpen: false

    // Signal emitted when popup is closed externally (click outside)
    signal closedExternally

    // Animation state
    property real popupOpacity: 0
    property real popupScale: 0.9

    // Bar position detection
    readonly property string barPosition: bar?.barPosition ?? "top"
    readonly property bool barAtTop: barPosition === "top"
    readonly property bool barAtBottom: barPosition === "bottom"
    readonly property bool barAtLeft: barPosition === "left"
    readonly property bool barAtRight: barPosition === "right"
    readonly property bool barVertical: barAtLeft || barAtRight

    // Total size including shadow margin
    readonly property int totalWidth: contentWidth + shadowMargin * 2
    readonly property int totalHeight: contentHeight + shadowMargin * 2
    property int contentWidth: 220
    property int contentHeight: 150

    implicitWidth: totalWidth
    implicitHeight: totalHeight

    // Frame detection
    readonly property bool frameEnabled: Config.bar?.frameEnabled ?? false
    readonly property bool containBar: Config.bar?.containBar ?? false
    readonly property int frameThickness: Config.bar?.frameThickness ?? 0
    readonly property int frameOffset: (frameEnabled && containBar) ? frameThickness : 0
    readonly property int effectiveFrameOffset: (frameEnabled && containBar) ? frameOffset : 0

    // Anchor positioning
    // The anchor.rect defines where the popup window's top-left corner will be placed
    // relative to the anchorItem's top-left corner
    anchor.item: anchorItem
    anchor.rect.x: {
        if (barVertical) {
            // Left bar: popup appears to the right of the button
            if (barAtLeft)
                return anchorItem.width + visualMargin + effectiveFrameOffset - shadowMargin;
            // Right bar: popup appears to the left of the button
            return -totalWidth + shadowMargin - visualMargin - effectiveFrameOffset;
        }
        // Top/Bottom bar: center horizontally relative to button
        return (anchorItem.width - totalWidth) / 2;
    }
    anchor.rect.y: {
        if (barVertical) {
            // Left/Right bar: center vertically relative to button
            return (anchorItem.height - totalHeight) / 2;
        }
        // Top bar: popup appears below the button
        if (barAtTop)
            return anchorItem.height + visualMargin + effectiveFrameOffset - shadowMargin;
        // Bottom bar: popup appears above the button
        return -totalHeight + shadowMargin - visualMargin - effectiveFrameOffset;
    }
    anchor.rect.width: 0
    anchor.rect.height: 0

    color: "transparent"
    visible: false

    // Focus grab for click-outside-to-close behavior
    property bool focusActive: false

    HyprlandFocusGrab {
        id: focusGrab
        active: root.visible && root.focusActive
        windows: [root]

        onCleared: {
            if (root.closeOnFocusLost && root.isOpen) {
                root.isOpen = false;
                root.closedExternally();
                root.close();
            }
        }
    }

    // Animation behaviors
    Behavior on popupOpacity {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutCubic
        }
    }

    Behavior on popupScale {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutCubic
        }
    }

    // Main content wrapper
    Item {
        id: popupContainer
        anchors.fill: parent
        anchors.margins: root.shadowMargin
        opacity: root.popupOpacity
        scale: root.popupScale
        transformOrigin: {
            if (root.barAtTop)
                return Item.Top;
            if (root.barAtBottom)
                return Item.Bottom;
            if (root.barAtLeft)
                return Item.Left;
            if (root.barAtRight)
                return Item.Right;
            return Item.Center;
        }

        StyledRect {
            id: background
            anchors.fill: parent
            variant: root.variant
            enableShadow: true
            radius: Styling.radius(8)

            Item {
                id: contentContainer
                anchors.fill: parent
                anchors.margins: root.popupPadding
            }
        }
    }

    function open() {
        if (visible)
            return;

        // Debug positioning
        console.log("BarPopup OPEN - position:", barPosition, "anchorItem:", anchorItem.width, "x", anchorItem.height, "rect.x:", anchor.rect.x, "rect.y:", anchor.rect.y);

        // Set logical state immediately
        isOpen = true;

        // Reset animation state
        popupOpacity = 0;
        popupScale = 0.9;

        // Show popup
        visible = true;

        // Start animation after a frame
        Qt.callLater(() => {
            popupOpacity = 1;
            popupScale = 1;
            focusActive = true;
        });
    }

    function close() {
        if (!visible)
            return;

        // Set logical state immediately
        isOpen = false;
        focusActive = false;

        // Animate out
        popupOpacity = 0;
        popupScale = 0.9;

        // Hide after animation
        closeTimer.restart();
    }

    function toggle() {
        if (visible) {
            close();
        } else {
            open();
        }
    }

    Timer {
        id: closeTimer
        interval: Config.animDuration > 0 ? Config.animDuration + 50 : 50
        onTriggered: {
            root.visible = false;
        }
    }
}
