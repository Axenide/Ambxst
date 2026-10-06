import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
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
    readonly property var hiddenIds: StateService.systrayHidden
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

    // The caret points to where the overflow popup opens, per bar side;
    // the chevron rotates while the popup is open
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
            const current = StateService.systrayHidden ?? [];
            if (current.includes(id))
                return;
            StateService.systrayHidden = [...current, id];
        });
    }

    function showItem(id) {
        Qt.callLater(() => {
            StateService.systrayHidden = (StateService.systrayHidden ?? []).filter(entry => entry !== id);
        });
    }

    function toggleOverflow() {
        overflowPopup.toggle();
    }

    // Drop zone for showing overflow icons: dropping a hidden item
    // anywhere over the tray pill puts it back in the bar
    DropArea {
        anchors.fill: parent
        keys: ["text/x-ambxst-tray-item"]

        onDropped: drop => {
            const id = drop.getDataAsString("text/x-ambxst-tray-item");
            if (id && root.hiddenIds.includes(id))
                root.showItem(id);
        }
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
                overflowPopupRef: overflowPopup
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
                overflowPopupRef: overflowPopup
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
            variant: "pane"
            radius: Styling.radius(-6)

            Rectangle {
                anchors.fill: parent
                color: parent.item || "transparent"
                opacity: chevron.hot ? 0.45 : (chevronMouse.containsMouse ? 0.25 : 0)
                radius: parent.radius

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
                color: Colors.primary
                opacity: chevron.hot ? 1 : 0.8
                rotation: overflowPopup.isOpen ? 180 : 0

                Behavior on rotation {
                    enabled: Config.animDuration > 0
                    RotationAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutCubic
                    }
                }

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
            keys: ["text/x-ambxst-tray-item"]

            onDropped: drop => {
                const id = drop.getDataAsString("text/x-ambxst-tray-item");
                if (!id)
                    return;
                if (chevron.tray.hiddenIds.includes(id))
                    chevron.tray.showItem(id);
                else
                    chevron.tray.hideItem(id);
            }
        }
    }

    BarPopup {
        id: overflowPopup
        anchorItem: root.vertical ? chevronColumn : chevronRow
        bar: root.bar
        popupPadding: 10
        visualMargin: 16
        clickThroughMargins: true

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
                        inOverflow: true
                        overflowPopupRef: overflowPopup
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

        // Drop zone for hiding bar icons: dropping a visible item
        // over the popup card moves it into the overflow grid
        DropArea {
            id: popupDropArea
            anchors.fill: parent
            keys: ["text/x-ambxst-tray-item"]

            onDropped: drop => {
                const id = drop.getDataAsString("text/x-ambxst-tray-item");
                if (id && !root.hiddenIds.includes(id))
                    root.hideItem(id);
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: Styling.radius(8)
            color: Colors.primary
            opacity: popupDropArea.containsDrag ? 0.15 : 0

            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 2
                }
            }
        }
    }
}
