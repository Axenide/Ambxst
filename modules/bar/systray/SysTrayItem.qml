import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.services
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
        if (dragOccurred && !dragCommitted && !inOverflow)
            finishBarDrag(mouse.x, mouse.y);
        stopDrag();
    }

    onCanceled: stopDrag()

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
        }

        positionPreview(mouse.x, mouse.y);

        if (!dragging) {
            dragging = true;
            dragPreview.visible = true;
        }

        if (inOverflow) {
            // Commit while still inside the popup surface: crossing onto
            // the bar window can break the pointer grab, so never wait
            // for the release past the popup edge
            if (isNearAnchorEdge(mouse.x, mouse.y))
                commitShow();
        } else if (isOverPopup(mouse.x, mouse.y)) {
            commitHide();
        }
    }

    function positionPreview(mouseX, mouseY) {
        if (!dragLayer)
            return;
        const point = mapToItem(dragLayer, mouseX, mouseY);
        dragPreview.x = point.x - pressOffsetX;
        dragPreview.y = point.y - pressOffsetY;
    }

    // Bar-side drop into the open overflow popup: both items live in the
    // panel window, so the popup rect is mapped directly
    function isOverPopup(mouseX, mouseY) {
        const popup = overflowPopupRef;
        if (!popup || !popup.isOpen)
            return false;

        const origin = popup.anchorItem.mapToItem(null, popup.anchor.rect.x, popup.anchor.rect.y);
        const point = mapToItem(null, mouseX, mouseY);
        return point.x >= origin.x
            && point.x <= origin.x + popup.width
            && point.y >= origin.y
            && point.y <= origin.y + popup.height;
    }

    // Overflow-side commit zone: crossing the popup's visible content
    // edge on the side facing the bar (where the chevron button is)
    function isNearAnchorEdge(mouseX, mouseY) {
        const popup = overflowPopupRef;
        if (!popup || !popup.isOpen)
            return false;

        const origin = popup.anchorItem.mapToItem(null, popup.anchor.rect.x, popup.anchor.rect.y);
        const point = mapToItem(null, mouseX, mouseY);
        const content = popup.shadowMargin;
        switch (bar.barPosition) {
        case "bottom":
            return point.y >= origin.y + popup.height - content;
        case "left":
            return point.x <= origin.x + content;
        case "right":
            return point.x >= origin.x + popup.width - content;
        default:
            return point.y <= origin.y + content;
        }
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
        if (isOverPopup(mouseX, mouseY) && tray)
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
        if (systrayPopup.isOpen)
            systrayPopup.close();
    }
}
