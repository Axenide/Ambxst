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
    property int trayItemSize: 20
    property bool isHovered: false

    acceptedButtons: Qt.LeftButton | Qt.RightButton
    Layout.fillHeight: bar.orientation === "horizontal"
    Layout.fillWidth: bar.orientation === "vertical"
    implicitWidth: trayItemSize
    implicitHeight: trayItemSize

    onClicked: event => {
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

    BarPopup {
        id: systrayPopup
        anchorItem: root
        bar: root.bar

        // Use a reasonable width for the menu
        contentWidth: 220
        // Height adapts to content, with a max limit if needed.
        // Must include vertical padding (8 top + 8 bottom = 16)
        contentHeight: Math.min(itemsColumn.implicitHeight + 16, 400)

        popupPadding: 8
        // 8px standard margin + 8px SysTray container padding to ensure correct offset from the main bar
        visualMargin: 16

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
        source: {
            const iconPath = root.item.icon.toString();
            if (iconPath.includes("spotify")) {
                return Quickshell.iconPath("spotify-client");
            }
            return root.item.icon;
        }
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        smooth: true
        // Keep the raw icon hidden when the tinted layer is active.
        opacity: systrayIconTint.active ? 0 : 1
    }

    Tinted {
        id: systrayIconTint
        sourceItem: trayIcon
        anchors.fill: trayIcon
        active: Config.matchSysTrayIconColor
        fullTint: true
        tintColor: Config.tintIcons ? Styling.srItem("overprimary") : Colors.overBackground
    }

    Tinted {
        sourceItem: trayIcon
        anchors.fill: trayIcon
        active: Config.tintIcons && !Config.matchSysTrayIconColor
    }

    StyledToolTip {
        show: root.isHovered
        tooltipText: root.item.tooltipTitle || root.item.title
        desciription: root.item.tooltipDescription || ""
    }

    HoverHandler {
        onHoveredChanged: root.isHovered = hovered
    }
}
