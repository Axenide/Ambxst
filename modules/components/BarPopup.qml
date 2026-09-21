pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.modules.services
import qs.modules.globals
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

    // Optional group identifier. Popups that share a groupId are
    // mutually exclusive: opening one closes the others in the same
    // group. Defaults to "bar" so the bar's flyout controls, clock
    // popups, layout selector, etc. don't stack on top of each other.
    property string groupId: "bar"

    // Extra windows (e.g. a nested child popup) that must not clear
    // this popup's focus grab while they are open.
    property list<var> extraGrabWindows: []

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

    implicitWidth: totalWidth + (barVertical ? dragExtendDepth : 0)
    implicitHeight: totalHeight + (barVertical ? 0 : dragExtendDepth)

    // Frame detection
    readonly property bool frameEnabled: Config.bar?.frameEnabled ?? false
    readonly property bool containBar: Config.bar?.containBar ?? false
    readonly property int frameThickness: Config.bar?.frameThickness ?? 0
    readonly property int frameOffset: (frameEnabled && containBar) ? frameThickness : 0
    readonly property int effectiveFrameOffset: (frameEnabled && containBar) ? frameOffset : 0

    // While true, the popup window statically extends toward the bar far
    // enough to cover the anchor item. The extension is transparent and
    // click-through by default; combined with dragExtendInput it lets
    // drags that started inside keep receiving motion and the release
    // while crossing onto the bar
    property bool extendTowardBar: false

    readonly property int dragExtendDepth: {
        if (!extendTowardBar)
            return 0;
        return effectiveFrameOffset + (barVertical ? anchorItem.width : anchorItem.height) + 12;
    }

    // Anchor positioning
    // The anchor.rect defines where the popup window's top-left corner will be placed
    // relative to the anchorItem's top-left corner
    anchor.item: anchorItem
    anchor.rect.x: {
        if (barVertical) {
            // Left bar: popup appears to the right of the button; the
            // extension grows leftward so the card stays in place
            if (barAtLeft)
                return anchorItem.width + visualMargin + effectiveFrameOffset - shadowMargin - dragExtendDepth;
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
        // Top bar: popup appears below the button; the extension grows
        // upward so the card stays in place
        if (barAtTop)
            return anchorItem.height + visualMargin + effectiveFrameOffset - shadowMargin - dragExtendDepth;
        // Bottom bar: popup appears above the button
        return -totalHeight + shadowMargin - visualMargin - effectiveFrameOffset;
    }
    anchor.rect.width: 0
    anchor.rect.height: 0

    color: "transparent"
    visible: false

    // When true, the transparent shadow margins do not capture input;
    // only the visible content area does. Lets pointer drags from the
    // parent window travel over the margins without breaking its grab.
    property bool clickThroughMargins: false

    // While true, the input mask expands to the whole popup window
    // (shadow margins included) so drags that started inside keep
    // receiving pointer events while crossing the margins
    property bool dragExtendInput: false

    // While true, the popup claims no pointer input at all. Drags that
    // started in the parent window keep their grab while crossing over
    // the popup instead of being canceled by the surface switch
    property bool suppressInput: false

    Region {
        id: contentInputMask
        item: background
        regions: [
            Region {
                item: root.dragExtendInput && root.visible ? fullWindowInput : null
            }
        ]
    }

    Item {
        id: fullWindowInput
        anchors.fill: parent
    }

    Region {
        id: emptyInputMask
    }

    mask: root.suppressInput ? emptyInputMask : (root.clickThroughMargins ? contentInputMask : null)

    // Full-window hover proxy used by systray drag handoffs: keeps
    // tracking the pointer while it crosses back over the popup after
    // the dragging item lost its grab
    property bool dragHandoffProxy: false

    MouseArea {
        anchors.fill: parent
        z: 10000
        visible: enabled
        enabled: root.dragHandoffProxy && root.visible && GlobalStates.systrayDragHandoff
            && GlobalStates.systrayDragScreen === (root.bar?.screen?.name ?? "")
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
        cursorShape: Qt.ClosedHandCursor

        onPositionChanged: mouse => {
            const item = GlobalStates.systrayDragItem;
            if (!item)
                return;
            const local = mapToItem(null, mouse.x, mouse.y);
            const origin = root.anchorItem.mapToItem(null, root.anchor.rect.x, root.anchor.rect.y);
            item.proxyMove(local.x + origin.x, local.y + origin.y, (mouse.buttons & Qt.LeftButton) !== 0);
        }
    }

    // Focus grab for click-outside-to-close behavior
    property bool focusActive: false

    FocusGrab {
        id: focusGrab
        active: root.visible && root.focusActive
        windows: [root].concat(root.extraGrabWindows)

        onCleared: {
            // Only one focus grab can exist at a time: a nested child
            // popup starting its own grab clears ours, which is not a
            // request to close while the child is still listed.
            if (root.closeOnFocusLost && root.isOpen && root.extraGrabWindows.length === 0) {
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
        // Keep the card pinned in place while the window extends toward
        // the bar
        anchors.topMargin: root.shadowMargin + (root.barAtTop ? root.dragExtendDepth : 0)
        anchors.bottomMargin: root.shadowMargin + (root.barAtBottom ? root.dragExtendDepth : 0)
        anchors.leftMargin: root.shadowMargin + (root.barAtLeft ? root.dragExtendDepth : 0)
        anchors.rightMargin: root.shadowMargin + (root.barAtRight ? root.dragExtendDepth : 0)
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

        // Group-aware mutual exclusion: ask Visibilities to close any
        // sibling popups already open in the same groupId, then
        // register this popup so future opens in the group close us.
        Visibilities.registerBarPopup(root);

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

        // Drop our registration so future opens in the same group
        // don't try to close a popup that's already gone.
        Visibilities.unregisterBarPopup(root);

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

    // Re-assert the focus grab after it was cleared externally (e.g. a
    // nested child popup took over and then closed)
    function refreshFocusGrab() {
        if (!visible || !isOpen)
            return;
        focusActive = false;
        focusActive = true;
    }

    Timer {
        id: closeTimer
        interval: Config.animDuration > 0 ? Config.animDuration + 50 : 50
        onTriggered: {
            root.visible = false;
        }
    }

    Component.onDestruction: {
        // Make sure a popup that's torn down (parent destroyed, panel
        // reloaded, etc.) doesn't leave a stale entry that blocks
        // future opens in its group.
        Visibilities.unregisterBarPopup(root);
    }
}
