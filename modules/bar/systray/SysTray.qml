import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import qs.modules.globals
import qs.modules.services
import qs.modules.theme
import qs.modules.components
import qs.config

StyledRect {
    variant: "bg"
    id: root

    required property var bar

    property real radius: 0
    property real startRadius: radius
    property real endRadius: radius

    // Orientación derivada de la barra
    property bool vertical: bar.orientation === "vertical"

    readonly property var allItems: SystemTray.items?.values ?? []
    readonly property var hiddenIds: Config.bar?.systrayHidden ?? []
    readonly property var visibleItems: allItems.filter(item => !hiddenIds.includes(item.id))
    readonly property var overflowItems: allItems.filter(item => hiddenIds.includes(item.id))

    // The tray collapses to a chevron-only pill while every icon is in the popup
    readonly property bool hasItems: allItems.length > 0

    // Menu popup currently opened from an icon inside the overflow popup
    property var activeChildMenu: null

    // When the nested menu closes it drops the shared focus grab, so
    // the overflow popup must take it back
    onActiveChildMenuChanged: {
        if (activeChildMenu === null && overflowPopup.isOpen)
            overflowPopup.refreshFocusGrab();
    }

    // The caret points to where the overflow popup opens, per bar side
    readonly property string chevronIcon: {
        switch (bar.barPosition) {
        case "bottom":
            return Icons.caretUp;
        case "left":
            return Icons.caretRight;
        case "right":
            return Icons.caretLeft;
        default:
            return Icons.caretDown;
        }
    }

    // Hide when no tray items
    visible: hasItems

    topLeftRadius: root.vertical ? root.startRadius : root.startRadius
    topRightRadius: root.vertical ? root.startRadius : root.endRadius
    bottomLeftRadius: root.vertical ? root.endRadius : root.startRadius
    bottomRightRadius: root.vertical ? root.endRadius : root.endRadius

    // Ajustes de tamaño dinámicos según orientación
    height: vertical ? implicitHeight : parent.height
    Layout.preferredWidth: hasItems ? ((vertical ? columnLayout.implicitWidth : rowLayout.implicitWidth) + 16) : 0
    implicitWidth: hasItems ? ((vertical ? columnLayout.implicitWidth : rowLayout.implicitWidth) + 16) : 0
    implicitHeight: hasItems ? ((vertical ? columnLayout.implicitHeight : rowLayout.implicitHeight) + 16) : 0

    // Model mutations are deferred: committing mid-drop would destroy
    // delegates while their drop/click handlers are still on the stack
    function hideItem(id) {
        Qt.callLater(() => {
            if (!Config.bar)
                return;
            const current = Config.bar.systrayHidden ?? [];
            if (current.includes(id))
                return;
            Config.bar.systrayHidden = [...current, id];
        });
    }

    function showItem(id) {
        Qt.callLater(() => {
            if (!Config.bar)
                return;
            Config.bar.systrayHidden = (Config.bar.systrayHidden ?? []).filter(entry => entry !== id);
        });
    }

    function toggleOverflow() {
        overflowPopup.toggle();
    }

    RowLayout {
        id: rowLayout
        visible: !root.vertical
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Repeater {
            id: rowRepeater
            model: root.visibleItems

            SysTrayItem {
                required property SystemTrayItem modelData
                bar: root.bar
                item: modelData
                tray: root
                dragLayer: root.bar
            }
        }

        ChevronButton {
            id: chevronRow
            tray: root
        }
    }

    ColumnLayout {
        id: columnLayout
        visible: root.vertical
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Repeater {
            id: columnRepeater
            model: root.visibleItems

            SysTrayItem {
                required property SystemTrayItem modelData
                bar: root.bar
                item: modelData
                tray: root
                dragLayer: root.bar
            }
        }

        ChevronButton {
            id: chevronColumn
            tray: root
        }
    }

    component ChevronButton: Item {
        id: chevron

        required property var tray

        property bool hot: dropArea.containsDrag
            || GlobalStates.isSystrayChevronHot(chevron.tray.bar?.screen?.name ?? "")

        Layout.preferredWidth: 20
        Layout.preferredHeight: 20
        Layout.fillHeight: !chevron.tray.vertical
        Layout.fillWidth: chevron.tray.vertical

        MouseArea {
            id: chevronMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton
            onClicked: chevron.tray.toggleOverflow()
        }

        StyledRect {
            anchors.fill: parent
            variant: "bg"

            Rectangle {
                anchors.fill: parent
                color: Styling.srItem("overprimary")
                opacity: chevron.hot ? 0.45 : (chevronMouse.containsMouse ? 0.25 : 0)
                radius: Styling.radius(-3)

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration / 2
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                text: chevron.tray.chevronIcon
                font.family: Icons.font
                font.pixelSize: 14
                color: Colors.foreground
                opacity: chevron.hot ? 1 : 0.65

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration / 2
                    }
                }
            }
        }

        DropArea {
            id: dropArea
            anchors.fill: parent
            keys: ["ambxst.tray.item"]

            onDropped: drop => {
                if (drop.source !== undefined && drop.source !== null && drop.source !== "") {
                    chevron.tray.hideItem(String(drop.source));
                }
            }
        }
    }

    BarPopup {
        id: overflowPopup
        anchorItem: root.vertical ? chevronColumn : chevronRow
        bar: root.bar
        popupPadding: 10
        visualMargin: 16

        readonly property int columns: Math.max(1, Math.min(root.overflowItems.length, 5))
        readonly property int rows: Math.max(1, Math.ceil(root.overflowItems.length / columns))
        readonly property int gridWidth: columns * 20 + (columns - 1) * 8
        readonly property int gridHeight: rows * 20 + (rows - 1) * 8

        contentWidth: (root.overflowItems.length > 0 ? gridWidth : hintLabel.implicitWidth) + popupPadding * 2
        contentHeight: (root.overflowItems.length > 0 ? gridHeight : hintLabel.implicitHeight) + popupPadding * 2

        // A nested tray menu must not clear this popup's focus grab
        extraGrabWindows: root.activeChildMenu ? [root.activeChildMenu] : []

        onIsOpenChanged: {
            if (isOpen)
                return;
            const child = root.activeChildMenu;
            root.activeChildMenu = null;
            if (child)
                child.close();
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 8

            Grid {
                id: iconsGrid
                visible: root.overflowItems.length > 0
                columns: overflowPopup.columns
                spacing: 8

                Repeater {
                    model: root.overflowItems

                    SysTrayItem {
                        required property SystemTrayItem modelData
                        bar: root.bar
                        item: modelData
                        tray: root
                        inOverflow: true
                        overflowPopupRef: overflowPopup
                        dropTarget: root.vertical ? chevronColumn : chevronRow
                        dragLayer: overflowDragLayer
                    }
                }
            }

            Text {
                id: hintLabel
                visible: root.overflowItems.length === 0
                text: I18n.t("bar.systray.overflow_empty")
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                color: Colors.outline
            }
        }

        // Floating layer for drag previews inside the popup
        Item {
            id: overflowDragLayer
            anchors.fill: parent
            z: 100
        }
    }
}
