import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.services
import qs.modules.globals
import qs.modules.components
import qs.config

MouseArea {
    id: root

    required property var bar
    required property SystemTrayItem item

    // Overflow wiring — only set for instances living inside the popup
    property bool inOverflow: false
    property var tray: null
    property var overflowPopupRef: null
    property Item dragLayer: null
    // Drag layer inside the overflow popup; lets bar-side previews float
    // above the popup window while crossing over it
    property Item popupDragLayer: null

    property int trayItemSize: 20
    property bool isHovered: false
    property bool dragging: false
    // True from the moment a press turns into a drag; blocks the
    // click activation until the next press
    property bool dragOccurred: false
    // True once the drag committed (hide/show); stops further drag
    // processing while the pointer is still held
    property bool dragCommitted: false

    property real pressOffsetX: 0
    property real pressOffsetY: 0

    // Last drag position in item-local coords, kept for release/cancel
    // fallbacks when the pointer grab is broken by the compositor
    property real lastDragX: 0
    property real lastDragY: 0

    // Drag start position in window-scene coords, used to check whether
    // an overflow drag moved toward the bar side
    property real dragStartLocalX: 0
    property real dragStartLocalY: 0

    readonly property int dragThreshold: Qt.styleHints?.startDragDistance ?? 10

    readonly property string iconSource: {
        const iconPath = root.item.icon.toString();
        if (iconPath.includes("spotify")) {
            return Quickshell.iconPath("spotify-client");
        }
        return root.item.icon;
    }

    acceptedButtons: Qt.LeftButton | Qt.RightButton
    Layout.fillHeight: bar.orientation === "horizontal"
    Layout.fillWidth: bar.orientation === "vertical"
    implicitWidth: trayItemSize
    implicitHeight: trayItemSize

    onPressed: mouse => {
        dragOccurred = false;
        dragCommitted = false;
        pressOffsetX = mouse.x;
        pressOffsetY = mouse.y;
    }

    onPositionChanged: mouse => updateDrag(mouse)

    onReleased: mouse => {
        if (dragOccurred && !dragCommitted) {
            if (inOverflow) {
                if (isNearAnchorEdge(mouse.x, mouse.y) || movedTowardAnchor(mouse.x, mouse.y))
                    commitShow();
            } else {
                finishBarDrag(mouse.x, mouse.y);
            }
        }
        stopDrag();
    }

    onCanceled: {
        if (dragOccurred && !dragCommitted) {
            if (inOverflow) {
                // The grab broke while leaving the popup toward the bar:
                // hand the tracking off to the hover proxies instead of
                // committing, so the release point decides the drop
                if (isNearAnchorEdge(lastDragX, lastDragY) || movedTowardAnchor(lastDragX, lastDragY))
                    beginHandoff();
                else
                    stopDrag();
                return;
            }
            if (isOverPopup(lastDragX, lastDragY, 10))
                commitHide();
            else
                stopDrag();
            return;
        }
        stopDrag();
    }

    onClicked: event => {
        if (dragOccurred) {
            event.accepted = true;
            return;
        }
        switch (event.button) {
        case Qt.LeftButton:
            item.activate();
            break;
        case Qt.RightButton:
            if (item.hasMenu) {
                systrayPopup.toggle();
            }
            break;
        }
        event.accepted = true;
    }

    function stopDrag() {
        dragging = false;
        dragPreview.visible = false;
        if (overflowPopupRef) {
            overflowPopupRef.dragExtendInput = false;
            overflowPopupRef.suppressInput = false;
        }
        if (GlobalStates.systrayDragItem === root) {
            GlobalStates.systrayDragHandoff = false;
            GlobalStates.systrayDragItem = null;
        }
        dragPreview.parent = root.dragLayer ?? root;
    }

    // Popup → bar handoff: the pointer grab broke while heading to the
    // bar, so the panel and popup hover proxies take over tracking until
    // the real release. The preview moves into the panel window, where it
    // can render across the bar and the desktop
    function beginHandoff() {
        const popup = overflowPopupRef;
        if (!popup || dragCommitted)
            return;
        GlobalStates.systrayDragHandoff = true;
        GlobalStates.systrayDragScreen = root.bar?.screen?.name ?? "";
        GlobalStates.systrayDragItem = root;
        const origin = popup.anchorItem.mapToItem(null, popup.anchor.rect.x, popup.anchor.rect.y);
        const point = mapToItem(null, lastDragX, lastDragY);
        if (dragPreview.parent !== root.bar)
            dragPreview.parent = root.bar;
        dragPreview.x = point.x + origin.x - pressOffsetX;
        dragPreview.y = point.y + origin.y - pressOffsetY;
    }

    // Called by the hover proxies with panel-scene coordinates. Renders
    // the preview above the popup window while crossing over it, and
    // finishes the handoff once the button comes up
    function proxyMove(globalX, globalY, pressed) {
        if (GlobalStates.systrayDragItem !== root)
            return;
        const popup = overflowPopupRef;
        if (popup) {
            const origin = popup.anchorItem.mapToItem(null, popup.anchor.rect.x, popup.anchor.rect.y);
            const overPopup = globalX >= origin.x && globalX <= origin.x + popup.width
                && globalY >= origin.y && globalY <= origin.y + popup.height;
            if (overPopup && popupDragLayer) {
                const layerOrigin = popupDragLayer.mapToItem(null, 0, 0);
                dragPreview.parent = popupDragLayer;
                dragPreview.x = globalX - origin.x - layerOrigin.x - pressOffsetX;
                dragPreview.y = globalY - origin.y - layerOrigin.y - pressOffsetY;
            } else {
                if (dragPreview.parent !== root.bar)
                    dragPreview.parent = root.bar;
                dragPreview.x = globalX - pressOffsetX;
                dragPreview.y = globalY - pressOffsetY;
            }
        }
        if (!pressed)
            finishHandoff(globalX, globalY);
    }

    function finishHandoff(globalX, globalY) {
        const popup = overflowPopupRef;
        if (popup) {
            const origin = popup.anchorItem.mapToItem(null, popup.anchor.rect.x, popup.anchor.rect.y);
            if (isNearAnchorEdgeAt(Qt.point(globalX - origin.x, globalY - origin.y))) {
                commitShow();
                return;
            }
        }
        stopDrag();
    }

    function updateDrag(mouse) {
        if (dragCommitted)
            return;
        if (!(mouse.buttons & Qt.LeftButton))
            return;

        const dx = mouse.x - pressOffsetX;
        const dy = mouse.y - pressOffsetY;
        if (!dragOccurred) {
            if (Math.abs(dx) < dragThreshold && Math.abs(dy) < dragThreshold)
                return;
            dragOccurred = true;
            const startPoint = mapToItem(null, mouse.x, mouse.y);
            dragStartLocalX = startPoint.x;
            dragStartLocalY = startPoint.y;
        }

        lastDragX = mouse.x;
        lastDragY = mouse.y;

        positionPreview(mouse.x, mouse.y);

        if (!dragging) {
            dragging = true;
            dragPreview.visible = true;
            if (overflowPopupRef) {
                if (inOverflow)
                    overflowPopupRef.dragExtendInput = true;
                else
                    overflowPopupRef.suppressInput = true;
            }
        }
    }

    function positionPreview(mouseX, mouseY) {
        if (!dragLayer)
            return;

        // While over the overflow popup, render the preview from the
        // popup's own layer so it floats above the popup window instead
        // of sliding under it. The popup window's top-left corner sits at
        // the anchor rect origin, so the panel-scene point maps into the
        // popup layer by subtracting both origins
        if (!inOverflow && popupDragLayer && isOverPopup(mouseX, mouseY, overflowPopupRef?.shadowMargin ?? 0)) {
            const popupOrigin = overflowPopupRef.anchorItem.mapToItem(null, overflowPopupRef.anchor.rect.x, overflowPopupRef.anchor.rect.y);
            const layerOrigin = popupDragLayer.mapToItem(null, 0, 0);
            const scenePoint = mapToItem(null, mouseX, mouseY);
            dragPreview.parent = popupDragLayer;
            dragPreview.x = scenePoint.x - popupOrigin.x - layerOrigin.x - pressOffsetX;
            dragPreview.y = scenePoint.y - popupOrigin.y - layerOrigin.y - pressOffsetY;
            return;
        }

        if (dragPreview.parent !== dragLayer)
            dragPreview.parent = dragLayer;

        const point = mapToItem(dragLayer, mouseX, mouseY);
        dragPreview.x = point.x - pressOffsetX;
        dragPreview.y = point.y - pressOffsetY;
    }

    // Bar-side drop into the open overflow popup. The zone is the popup's
    // visible card (shadow margins excluded) expanded by `approach`, so
    // the commit fires before the pointer crosses onto the popup surface
    // and risks breaking the panel's grab
    function isOverPopup(mouseX, mouseY, approach) {
        const popup = overflowPopupRef;
        if (!popup || !popup.isOpen)
            return false;

        const origin = popup.anchorItem.mapToItem(null, popup.anchor.rect.x, popup.anchor.rect.y);
        const point = mapToItem(null, mouseX, mouseY);
        const inset = popup.shadowMargin - approach;
        return point.x >= origin.x + inset
            && point.x <= origin.x + popup.width - inset
            && point.y >= origin.y + inset
            && point.y <= origin.y + popup.height - inset;
    }

    // Overflow-side acceptance zone: a band just inside the popup's
    // visible content edge, on the side facing the bar (where the chevron
    // button is). The window's bar-facing extension counts too, so a
    // release over the chevron commits as well
    function isNearAnchorEdgeAt(point) {
        const popup = overflowPopupRef;
        if (!popup || !popup.isOpen)
            return false;

        const inset = popup.shadowMargin + popup.dragExtendDepth + 8;
        switch (bar.barPosition) {
        case "bottom":
            return point.y >= popup.height - inset;
        case "left":
            return point.x <= inset;
        case "right":
            return point.x >= popup.width - inset;
        default:
            return point.y <= inset;
        }
    }

    function isNearAnchorEdge(mouseX, mouseY) {
        return isNearAnchorEdgeAt(mapToItem(null, mouseX, mouseY));
    }

    // True when the drag traveled toward the bar side by at least the
    // drag threshold; catches fast flings whose last delivered event
    // never reached the anchor edge band
    function movedTowardAnchorAt(point) {
        switch (bar.barPosition) {
        case "bottom":
            return point.y - dragStartLocalY >= dragThreshold;
        case "left":
            return dragStartLocalX - point.x >= dragThreshold;
        case "right":
            return point.x - dragStartLocalX >= dragThreshold;
        default:
            return dragStartLocalY - point.y >= dragThreshold;
        }
    }

    function movedTowardAnchor(mouseX, mouseY) {
        return movedTowardAnchorAt(mapToItem(null, mouseX, mouseY));
    }

    function commitHide() {
        if (dragCommitted)
            return;
        dragCommitted = true;
        if (tray)
            tray.hideItem(item.id);
        stopDrag();
    }

    function commitShow() {
        if (dragCommitted)
            return;
        dragCommitted = true;
        if (tray)
            tray.showItem(item.id);
        stopDrag();
    }

    function finishBarDrag(mouseX, mouseY) {
        if (dragPreview.Drag.active) {
            const dropped = dragPreview.Drag.target !== null;
            dragPreview.Drag.drop();
            if (dropped)
                return;
        }
        if (isOverPopup(mouseX, mouseY, 10) && tray)
            tray.hideItem(item.id);
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
            if (!root.inOverflow || !root.overflowPopupRef)
                return;
            root.overflowPopupRef.activeChildMenu = isOpen ? systrayPopup : null;
        }

        // Using QsMenuOpener to access menu items
        QsMenuOpener {
            id: menuOpener
            menu: root.item.menu
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
                    model: menuOpener.children ? menuOpener.children.values : []

                    delegate: ColumnLayout {
                        required property var modelData

                        Layout.fillWidth: true
                        spacing: 2

                        property bool submenuExpanded: false

                        SystrayMenuItem {
                            Layout.fillWidth: true

                            textStr: modelData.text || ""
                            iconSource: modelData.icon || ""
                            isImageIcon: iconSource.indexOf("/") !== -1 || iconSource.indexOf(".") !== -1
                            isSeparator: modelData.isSeparator || false
                            hasSubmenu: modelData.hasChildren || false
                            expanded: parent.submenuExpanded
                            buttonType: modelData.buttonType || 0
                            checkState: modelData.checkState || 0

                            onClicked: {
                                if (modelData.hasChildren) {
                                    parent.submenuExpanded = !parent.submenuExpanded;
                                } else {
                                    if (modelData.triggered) {
                                        modelData.triggered();
                                    } else if (modelData.activate) {
                                        modelData.activate();
                                    }
                                    systrayPopup.close();
                                }
                            }
                        }

                        // Submenu children — uses its own QsMenuOpener to trigger lazy loading
                        ColumnLayout {
                            visible: submenuExpanded && modelData.hasChildren
                            Layout.fillWidth: true
                            spacing: 2

                            QsMenuOpener {
                                id: subMenuOpener
                                menu: modelData.hasChildren ? modelData : null
                            }

                            Repeater {
                                model: subMenuOpener.children ? subMenuOpener.children.values : []

                                delegate: SystrayMenuItem {
                                    required property var modelData

                                    Layout.fillWidth: true
                                    depth: 1

                                    textStr: modelData.text || ""
                                    iconSource: modelData.icon || ""
                                    isImageIcon: iconSource.indexOf("/") !== -1 || iconSource.indexOf(".") !== -1
                                    isSeparator: modelData.isSeparator || false
                                    buttonType: modelData.buttonType || 0
                                    checkState: modelData.checkState || 0

                                    onClicked: {
                                        if (modelData.triggered) {
                                            modelData.triggered();
                                        } else if (modelData.activate) {
                                            modelData.activate();
                                        }
                                        systrayPopup.close();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Item {
        id: dragPreview
        parent: root.dragLayer ?? root
        visible: false
        width: root.trayItemSize
        height: root.trayItemSize
        z: 9999
        opacity: 0.95

        Drag.active: root.dragging && !root.inOverflow
        Drag.source: root.item?.id ?? ""
        Drag.keys: ["ambxst.tray.item"]
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2

        IconImage {
            id: previewIcon
            anchors.fill: parent
            source: root.iconSource
            smooth: true
        }

        Tinted {
            sourceItem: previewIcon
            anchors.fill: previewIcon
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
        tooltipText: root.item.tooltipTitle || root.item.title
        desciription: root.item.tooltipDescription || ""
    }

    HoverHandler {
        onHoveredChanged: root.isHovered = hovered
    }

    Component.onDestruction: {
        if (GlobalStates.systrayDragItem === root) {
            GlobalStates.systrayDragHandoff = false;
            GlobalStates.systrayDragItem = null;
        }
        if (systrayPopup.isOpen)
            systrayPopup.close();
    }
}
