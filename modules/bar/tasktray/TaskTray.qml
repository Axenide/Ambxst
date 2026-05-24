pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config

Item {
    id: root

    required property var bar
    property bool vertical: bar.orientation === "vertical"
    property bool isHovered: false
    property bool layerEnabled: true

    property real radius: 0
    property real startRadius: radius
    property real endRadius: radius

    readonly property bool taskTrayEnabled: Config.bar?.taskTrayEnabled ?? true
    readonly property bool showToggleButton: Config.bar?.taskTrayShowToggle ?? true

    property bool expanded: false
    readonly property bool hasItems: SystemTray.items.length > 0
    readonly property bool popupOpen: trayPopup.isOpen
    readonly property var trayItems: SystemTray.items || []

    // Tray icon context menu state
    property var activeTrayItem: null

    Layout.preferredWidth: 36
    Layout.preferredHeight: 36
    Layout.maximumWidth: 36
    Layout.maximumHeight: 36
    Layout.fillWidth: vertical
    Layout.fillHeight: !vertical

    width: 36; height: 36

    HoverHandler {
        onHoveredChanged: root.isHovered = hovered
    }

    // ── Toggle button — matches LayoutSelectorButton ──
    StyledRect {
        id: toggleBtn
        anchors.fill: parent
        visible: showToggleButton
        variant: root.popupOpen ? "primary" : "bg"
        enableShadow: root.layerEnabled

        topLeftRadius: root.vertical ? root.startRadius : root.startRadius
        topRightRadius: root.vertical ? root.startRadius : root.endRadius
        bottomLeftRadius: root.vertical ? root.endRadius : root.startRadius
        bottomRightRadius: root.vertical ? root.endRadius : root.endRadius

        Rectangle {
            anchors.fill: parent
            color: Styling.srItem("overprimary")
            opacity: root.popupOpen ? 0 : (root.isHovered ? 0.25 : 0)
            radius: parent.radius ?? 0
            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation { duration: Config.animDuration / 2 }
            }
        }

        Text {
            anchors.centerIn: parent
            text: Icons.terminalWindow
            font.family: Icons.font; font.pixelSize: 18
            color: root.popupOpen ? toggleBtn.item : Styling.srItem("overprimary")
        }

        // Badge
        StyledRect {
            anchors.top: parent.top; anchors.right: parent.right
            anchors.topMargin: -2; anchors.rightMargin: -2
            width: 16; height: 16; radius: 8
            variant: "primary"
            visible: hasItems && !root.expanded
            Text {
                anchors.centerIn: parent
                text: Math.min(trayItems.length, 99)
                font.family: Config.theme.font; font.pixelSize: 9; font.bold: true
                color: Colors.background
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    trayPopup.open();
                } else {
                    root.expanded = !root.expanded;
                }
            }
        }

        StyledToolTip {
            visible: root.isHovered && !root.popupOpen
            tooltipText: hasItems ? trayItems.length + " items hidden" : "No hidden items"
        }
    }

    // ── Systray dock — floating popout ──
    StyledRect {
        id: dockBg
        anchors {
            left: toggleBtn.right; leftMargin: 2
            verticalCenter: parent.verticalCenter
        }
        width: dockRow.implicitWidth + 8
        height: 30
        variant: "bg"; radius: 6
        enableShadow: root.layerEnabled
        visible: hasItems
        z: 10

        opacity: expanded ? 1.0 : 0.0
        scale: expanded ? 1.0 : 0.8
        transformOrigin: Item.LeftCenter
        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation { duration: Config.animDuration / 2 }
        }
        Behavior on scale {
            enabled: Config.animDuration > 0
            NumberAnimation { duration: Config.animDuration / 2; easing.type: Easing.OutCubic }
        }

        RowLayout {
            id: dockRow
            anchors.centerIn: parent
            spacing: 2

            Repeater {
                model: root.trayItems

                delegate: Item {
                    id: trayIconArea
                    required property SystemTrayItem modelData
                    width: 24; height: 24
                    property bool iconHovered: false

                    HoverHandler {
                        onHoveredChanged: trayIconArea.iconHovered = hovered
                    }

                    // Hover bg
                    StyledRect {
                        anchors.fill: parent; anchors.margins: 1
                        variant: "bg"; radius: 4
                        opacity: trayIconArea.iconHovered ? 0.5 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 80 } }
                    }

                    // Tray icon
                    IconImage {
                        id: trayIconImg
                        anchors.centerIn: parent
                        width: 18; height: 18
                        source: trayIconArea.modelData.icon
                        smooth: true
                    }

                    Tinted {
                        sourceItem: trayIconImg
                        anchors.fill: trayIconImg
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: event => {
                            if (event.button === Qt.LeftButton) {
                                trayIconArea.modelData.activate();
                            } else {
                                // Show native tray context menu
                                if (trayIconArea.modelData.hasMenu) {
                                    root.activeTrayItem = trayIconArea.modelData;
                                    trayMenuPopup.open();
                                }
                            }
                            event.accepted = true;
                        }
                    }
                }
            }
        }
    }

    // ── Per-icon native context menu ──
    BarPopup {
        id: trayMenuPopup
        anchorItem: dockBg
        bar: root.bar
        visible: root.activeTrayItem !== null

        // QsMenuOpener unwraps the StatusNotifier menu items
        QsMenuOpener {
            id: trayMenuOpener
            menu: root.activeTrayItem ? root.activeTrayItem.menu : null
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 4
            spacing: 2

            Repeater {
                model: trayMenuOpener.children ? trayMenuOpener.children.values : []

                delegate: Item {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28

                    readonly property bool isSeparator: modelData.isSeparator === true

                    // Separator
                    Rectangle {
                        anchors.left: parent.left; anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 1; color: Colors.outlineVariant
                        visible: isSeparator
                    }

                    // Menu item
                    StyledRect {
                        anchors.fill: parent
                        radius: 4
                        variant: menuMouse.containsMouse ? "focus" : "bg"
                        visible: !isSeparator

                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 8
                            spacing: 8

                            // Icon
                            IconImage {
                                width: 16; height: 16
                                source: modelData.icon ?? ""
                                smooth: true
                                visible: modelData.icon !== undefined
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Text {
                                text: modelData.text || ""
                                font.family: Styling.defaultFont
                                font.pixelSize: Styling.fontSize(-1)
                                color: Colors.overBackground
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }

                        MouseArea {
                            id: menuMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                if (modelData.trigger) modelData.trigger();
                                trayMenuPopup.close();
                                root.activeTrayItem = null;
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Toggle popup (right-click) ──
    BarPopup {
        id: trayPopup
        anchorItem: toggleBtn
        bar: root.bar

        ColumnLayout {
            anchors.fill: parent; anchors.margins: 6; spacing: 2

            Text {
                text: "Hidden Icons"
                font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-1)
                font.bold: true; color: Colors.overBackground
                Layout.fillWidth: true; Layout.bottomMargin: 4; leftPadding: 4
            }

            Repeater {
                model: root.trayItems

                delegate: Item {
                    required property SystemTrayItem modelData
                    Layout.fillWidth: true; Layout.preferredHeight: 32

                    StyledRect {
                        anchors.fill: parent
                        variant: popupMouse.containsMouse ? "focus" : "bg"
                        radius: 4; opacity: popupMouse.containsMouse ? 1.0 : 0.7
                    }

                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6; spacing: 8

                        IconImage {
                            width: 20; height: 20
                            source: modelData.icon; smooth: true
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            text: modelData.tooltipTitle || modelData.title || "App"
                            font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-2)
                            color: Colors.overBackground; elide: Text.ElideRight
                            Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            text: Icons.caretRight
                            font.family: Icons.font; font.pixelSize: 12; color: Colors.outline
                            visible: popupMouse.containsMouse; Layout.alignment: Qt.AlignVCenter
                        }
                    }

                    MouseArea {
                        id: popupMouse; anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: event => {
                            if (event.button === Qt.LeftButton) {
                                modelData.activate(); trayPopup.close();
                            } else if (event.button === Qt.RightButton && modelData.hasMenu) {
                                root.activeTrayItem = modelData;
                                trayMenuPopup.open();
                            }
                        }
                    }
                }
            }

            MenuSeparator {
                Layout.fillWidth: true; visible: hasItems
                Layout.topMargin: 4; Layout.bottomMargin: 4
            }

            Item {
                Layout.fillWidth: true; Layout.preferredHeight: 32
                StyledRect {
                    anchors.fill: parent
                    variant: toggleOption.containsMouse ? "focus" : "bg"
                    radius: 4; opacity: toggleOption.containsMouse ? 1.0 : 0.7
                }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6; spacing: 8
                    Text {
                        text: root.expanded ? Icons.minus : Icons.plus
                        font.family: Icons.font; font.pixelSize: 16
                        color: Colors.overBackground; Layout.alignment: Qt.AlignVCenter
                    }
                    Text {
                        text: root.expanded ? "Hide tray icons" : "Show tray icons"
                        font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-2)
                        color: Colors.overBackground; Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter
                    }
                }
                MouseArea {
                    id: toggleOption; anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                    onClicked: { root.expanded = !root.expanded; trayPopup.close(); }
                }
            }

            Text {
                text: !hasItems ? "No tray icons" : ""
                font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-1)
                color: Colors.outline; visible: !hasItems
                Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; Layout.topMargin: 12
            }

            Item { Layout.fillHeight: true }
        }
    }
}
