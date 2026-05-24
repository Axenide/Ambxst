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

/**
 * TaskTray — Systray hide/reveal toggle
 *
 * Matches ToggleButton/PresetsButton styling exactly.
 * Toggle icon: StyledRect bg, hover overlay, icon font.
 * Expanded: reveals hidden systray items in a floating dock.
 * Right-click toggle: BarPopup with full systray list.
 */
StyledRect {
    id: root

    required property var bar
    property bool vertical: bar.orientation === "vertical"
    property bool layerEnabled: true

    property real radius: 0
    property real startRadius: radius
    property real endRadius: radius

    property bool expanded: false
    property bool isHovered: false
    property bool btnHovered: false
    readonly property bool hasItems: SystemTray.items.length > 0
    readonly property var trayItems: SystemTray.items || []

    // ── Same styling as ToggleButton/PresetsButton ──
    variant: "bg"
    enableShadow: root.layerEnabled && Config.showBackground
    Layout.preferredWidth: 36
    Layout.preferredHeight: 36
    Layout.maximumWidth: 36
    Layout.maximumHeight: 36
    Layout.fillWidth: vertical
    Layout.fillHeight: !vertical

    topLeftRadius: root.vertical ? root.startRadius : root.startRadius
    topRightRadius: root.vertical ? root.startRadius : root.endRadius
    bottomLeftRadius: root.vertical ? root.endRadius : root.startRadius
    bottomRightRadius: root.vertical ? root.endRadius : root.endRadius

    // Hover overlay — same as ToggleButton
    Rectangle {
        anchors.fill: parent
        color: Styling.srItem("overprimary")
        opacity: root.expanded ? 0 : (root.isHovered ? 0.25 : 0)
        radius: parent.radius ?? 0
        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation { duration: Config.animDuration / 2 }
        }
    }

    // Icon — exactly like ToggleButton
    Text {
        anchors.centerIn: parent
        text: Icons.dotsThree
        font.family: Icons.font
        font.pixelSize: 18
        color: Styling.srItem("overprimary")
    }

    // Badge when collapsed
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

    // Hover tracking
    HoverHandler {
        onHoveredChanged: root.isHovered = hovered
    }

    // Click handling
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                root.expanded = !root.expanded;
            } else {
                trayPopup.open();
            }
        }
    }

    // Tooltip
    StyledToolTip {
        visible: root.isHovered && !trayPopup.isOpen && !root.expanded
        text: hasItems ? trayItems.length + " hidden icons" : "No hidden icons"
        
        font.family: Config.theme.font
    }

    // ── Floating dock with tray items ──
    StyledRect {
        id: dockBg
        anchors {
            left: parent.right; leftMargin: 2
            verticalCenter: parent.verticalCenter
        }
        width: dockRow.implicitWidth + 10
        height: 30
        variant: "bg"; radius: 6
        enableShadow: root.layerEnabled && Config.showBackground
        visible: hasItems
        z: 100

        opacity: root.expanded ? 1.0 : 0.0
        scale: root.expanded ? 1.0 : 0.8
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
                    required property SystemTrayItem modelData
                    width: 22; height: 22
                    property bool iconHovered: false

                    HoverHandler {
                        onHoveredChanged: iconHovered = hovered
                    }

                    Rectangle {
                        anchors.fill: parent; anchors.margins: 1; radius: 3
                        color: Styling.srItem("overprimary")
                        opacity: iconHovered ? 0.2 : 0.0
                    }

                    IconImage {
                        anchors.centerIn: parent
                        width: 16; height: 16
                        source: modelData.icon
                        smooth: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: event => {
                            if (event.button === Qt.LeftButton) {
                                modelData.activate();
                            }
                            event.accepted = true;
                        }
                    }
                }
            }
        }
    }

    // ── Popup: full systray list (right-click) ──
    BarPopup {
        id: trayPopup
        anchorItem: root
        bar: root.bar

        ColumnLayout {
            anchors.fill: parent; anchors.margins: 6; spacing: 2

            Text {
                text: "System Tray"
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
                        onClicked: {
                            modelData.activate();
                            trayPopup.close();
                        }
                    }
                }
            }

            // Toggle option
            Rectangle {
                Layout.fillWidth: true; height: 1
                color: Colors.outlineVariant; visible: hasItems
                Layout.topMargin: 4; Layout.bottomMargin: 4
            }

            Item {
                Layout.fillWidth: true; Layout.preferredHeight: 32
                StyledRect {
                    anchors.fill: parent
                    variant: toggleHover.containsMouse ? "focus" : "bg"
                    radius: 4; opacity: toggleHover.containsMouse ? 1.0 : 0.7
                }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6; spacing: 8
                    Text {
                        text: root.expanded ? Icons.caretUp : Icons.caretDown
                        font.family: Icons.font; font.pixelSize: 16
                        color: Colors.overBackground; Layout.alignment: Qt.AlignVCenter
                    }
                    Text {
                        text: root.expanded ? "Hide from tray" : "Show in tray"
                        font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-2)
                        color: Colors.overBackground; Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter
                    }
                }
                MouseArea {
                    id: toggleHover; anchors.fill: parent
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
