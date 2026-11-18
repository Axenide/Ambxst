pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config

MouseArea {
    id: root

    required property var bar
    required property var item

    // Overflow wiring — only set for instances living inside the popup
    property bool inOverflow: false
    property var overflowPopupRef: null

    property int trayItemSize: 20
    property bool isHovered: false
    property bool dragging: false
    // True from the moment a press turns into a drag; blocks the
    // click activation until the next press
    property bool dragOccurred: false
    property var menuItems: []

    property real pressOffsetX: 0
    property real pressOffsetY: 0

    readonly property int dragThreshold: Qt.styleHints?.startDragDistance ?? 10

    readonly property string iconSource: root.item.iconPath || (root.item.iconName ? (root.item.iconName.startsWith("/") ? AxctlBackend.imageUrl(root.item.iconName) : "image://icon/" + root.item.iconName) : "image-missing")

    acceptedButtons: Qt.LeftButton | Qt.RightButton
    Layout.fillHeight: bar.orientation === "horizontal"
    Layout.fillWidth: bar.orientation === "vertical"
    implicitWidth: trayItemSize
    implicitHeight: trayItemSize

    // Native Wayland drag: the compositor carries the icon above every
    // surface and delivers the drop to whichever window sits under the
    // pointer, so bar ↔ popup transfers need no coordinate work
    Drag.dragType: Drag.Automatic
    Drag.mimeData: {
        "text/x-ambxst-tray-item": root.item?.id ?? ""
    }
    Drag.supportedActions: Qt.MoveAction
    Drag.hotSpot.x: trayItemSize / 2
    Drag.hotSpot.y: trayItemSize / 2

    onPressed: mouse => {
        dragOccurred = false;
        pressOffsetX = mouse.x;
        pressOffsetY = mouse.y;
    }

    onPositionChanged: mouse => updateDrag(mouse)

    Drag.onDragFinished: stopDrag()

    onClicked: event => {
        if (dragOccurred) {
            event.accepted = true;
            return;
        }
        switch (event.button) {
        case Qt.LeftButton:
            if (root.item.itemIsMenu && root.item.menu) systrayPopup.toggle();
            else if (root.item.itemIsMenu) AxctlSystemTray.contextMenu(root.item.id);
            else AxctlSystemTray.activate(root.item.id);
            break;
        case Qt.RightButton:
            if (root.item.hasMenu) {
                if (root.item.menu) systrayPopup.toggle();
                else AxctlSystemTray.contextMenu(root.item.id);
            }
            break;
        }
        event.accepted = true;
    }

    onWheel: wheel => {
        const horizontal = bar.orientation === "vertical";
        const delta = horizontal ? wheel.angleDelta.x : wheel.angleDelta.y;
        if (delta !== 0) AxctlSystemTray.scroll(root.item.id, delta, horizontal ? "horizontal" : "vertical");
        wheel.accepted = true;
    }

    function updateDrag(mouse) {
        if (dragging || !(mouse.buttons & Qt.LeftButton))
            return;

        const dx = mouse.x - pressOffsetX;
        const dy = mouse.y - pressOffsetY;
        if (Math.abs(dx) < dragThreshold && Math.abs(dy) < dragThreshold)
            return;

        dragOccurred = true;

        // Render the drag image before activating: the compositor icon
        // must exist once the native drag takes over the pointer
        root.grabToImage(result => {
            if (!dragOccurred || !root.pressed)
                return;
            dragging = true;
            root.Drag.imageSource = result.url;
            root.Drag.active = true;
        });
    }

    function stopDrag() {
        dragging = false;
        root.Drag.active = false;
    }

    Component {
        id: menuEntryComponent

        ColumnLayout {
            id: menuEntry
            property var menuItem: null
            property string trayID: ""
            property int depth: 0
            property bool submenuExpanded: false

            spacing: 2

            SystrayMenuItem {
                Layout.fillWidth: true
                textStr: menuEntry.menuItem?.label || ""
                iconSource: menuEntry.menuItem?.iconPath || ""
                isImageIcon: iconSource.indexOf("/") !== -1 || iconSource.indexOf(".") !== -1
                isSeparator: menuEntry.menuItem?.type === "separator"
                hasSubmenu: (menuEntry.menuItem?.children || []).length > 0
                expanded: menuEntry.submenuExpanded
                depth: menuEntry.depth
                enabled: menuEntry.menuItem?.enabled !== false && !isSeparator
                buttonType: menuEntry.menuItem?.toggleType === "checkmark" ? 1 : menuEntry.menuItem?.toggleType === "radio" ? 2 : 0
                checkState: menuEntry.menuItem?.toggleState === 1 ? Qt.Checked : Qt.Unchecked

                onClicked: {
                    if ((menuEntry.menuItem?.children || []).length > 0) {
                        menuEntry.submenuExpanded = !menuEntry.submenuExpanded;
                    } else if (menuEntry.menuItem) {
                        AxctlSystemTray.menuEvent(menuEntry.trayID, menuEntry.menuItem.id, "clicked");
                        systrayPopup.close();
                    }
                }
            }

            ColumnLayout {
                visible: menuEntry.submenuExpanded && (menuEntry.menuItem?.children || []).length > 0
                Layout.fillWidth: true
                spacing: 2

                Repeater {
                    model: menuEntry.menuItem?.children || []

                    delegate: Loader {
                        id: childEntryLoader
                        required property var modelData
                        property var node: modelData
                        Layout.fillWidth: true
                        sourceComponent: menuEntryComponent

                        onLoaded: {
                            childEntryLoader.item.menuItem = childEntryLoader.node;
                            childEntryLoader.item.trayID = menuEntry.trayID;
                            childEntryLoader.item.depth = menuEntry.depth + 1;
                        }
                    }
                }
            }
        }
    }

    BarPopup {
        id: systrayPopup
        anchorItem: root
        bar: root.bar

        // Nested inside the overflow popup it must not close it
        groupId: root.inOverflow ? "systrayMenu" : "bar"

        // Use a reasonable width for the menu
        contentWidth: 220
        // Height adapts to content, with a max limit if needed.
        // Must include vertical padding (8 top + 8 bottom = 16)
        contentHeight: Math.min(itemsColumn.implicitHeight + 16, 400)

        popupPadding: 8
        // 8px standard margin + 8px SysTray container padding to ensure correct offset from the main bar
        visualMargin: 16

        onIsOpenChanged: {
            if (isOpen && root.item.menu) {
                AxctlSystemTray.loadMenu(root.item.id, (items, error) => {
                    if (error) {
                        console.warn("SysTrayItem: failed to load menu:", error);
                        if (!systrayPopup.isOpen) return;
                        systrayPopup.close();
                        AxctlSystemTray.contextMenu(root.item.id, 0, 0, (_, contextError) => {
                            if (contextError) console.warn("SysTrayItem: failed to open fallback context menu:", contextError);
                        });
                        return;
                    }
                    root.menuItems = items || [];
                });
            }
            if (!root.inOverflow || !root.overflowPopupRef)
                return;
            root.overflowPopupRef.activeChildMenu = isOpen ? systrayPopup : null;
        }

        ScrollView {
            anchors.fill: parent
            contentWidth: availableWidth
            clip: true

            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                id: itemsColumn
                width: parent.width
                spacing: 2

                Repeater {
                    model: root.menuItems

                    delegate: Loader {
                        id: rootMenuEntryLoader
                        required property var modelData
                        Layout.fillWidth: true
                        sourceComponent: menuEntryComponent

                        onLoaded: {
                            rootMenuEntryLoader.item.menuItem = rootMenuEntryLoader.modelData;
                            rootMenuEntryLoader.item.trayID = root.item.id;
                        }
                    }
                }
            }
        }
    }

    IconImage {
        id: trayIcon
        source: root.iconSource
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        smooth: true
        opacity: root.dragging ? 0.3 : 1

        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration / 2
            }
        }
    }

    Tinted {
        sourceItem: trayIcon
        anchors.fill: trayIcon
    }

    StyledToolTip {
        show: root.isHovered && !root.dragging
        tooltipText: root.item.toolTipTitle || root.item.title
        desciription: root.item.toolTip || ""
    }

    HoverHandler {
        onHoveredChanged: root.isHovered = hovered
    }

    Component.onDestruction: {
        if (systrayPopup.isOpen)
            systrayPopup.close();
    }
}
