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
    property var overflowPopupRef: null

    property int trayItemSize: 20
    property bool isHovered: false
    property bool dragging: false
    // True from the moment a press turns into a drag; blocks the
    // click activation until the next press
    property bool dragOccurred: false

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

    onDragFinished: stopDrag()

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
