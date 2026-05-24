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
 * TaskTray — Systray visibility manager
 *
 * Matches ToggleButton/PresetsButton styling exactly.
 * Left-click: opens a popup with all tray icons (click icon to activate).
 * Right-click: opens a settings popup to show/hide specific icons.
 */
StyledRect {
    id: root

    required property var bar
    property bool vertical: bar.orientation === "vertical"
    property bool layerEnabled: true

    property real radius: 0
    property real startRadius: radius
    property real endRadius: radius

    property bool isHovered: false
    readonly property var trayItems: SystemTray.items || []
    readonly property int visibleCount: root.trayItems.length

    // ── ToggleButton styling ──
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

    Rectangle {
        anchors.fill: parent
        color: Styling.srItem("overprimary")
        opacity: root.isHovered ? 0.25 : 0
        radius: parent.radius ?? 0
        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation { duration: Config.animDuration / 2 }
        }
    }

    Text {
        anchors.centerIn: parent
        text: Icons.dotsThree
        font.family: Icons.font; font.pixelSize: 18
        color: Styling.srItem("overprimary")
    }

    HoverHandler {
        onHoveredChanged: root.isHovered = hovered
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                iconListPopup.isOpen ? iconListPopup.close() : iconListPopup.open();
            } else {
                settingsPopup.isOpen ? settingsPopup.close() : settingsPopup.open();
            }
        }
    }

    StyledToolTip {
        visible: root.isHovered && !iconListPopup.isOpen && !settingsPopup.isOpen
        tooltipText: visibleCount > 0 ? visibleCount + " items in tray" : "No tray items"
    }

    // ── Left-click: icon list (shows all tray icons) ──
    BarPopup {
        id: iconListPopup
        anchorItem: root
        bar: root.bar

        RowLayout {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 4

            Repeater {
                model: root.trayItems

                delegate: Item {
                    required property SystemTrayItem modelData
                    width: 28; height: 28
                    property bool iconHovered: false

                    HoverHandler {
                        onHoveredChanged: iconHovered = hovered
                    }

                    StyledRect {
                        anchors.fill: parent; anchors.margins: 1
                        radius: 4
                        variant: iconHovered ? "focus" : "bg"
                        opacity: iconHovered ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 80 } }
                    }

                    IconImage {
                        anchors.centerIn: parent
                        width: 20; height: 20
                        source: modelData.icon; smooth: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            modelData.activate();
                            iconListPopup.close();
                        }
                    }
                }
            }

            Text {
                text: "No tray icons"
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                color: Colors.outline
                visible: trayItems.length === 0
                Layout.preferredWidth: 80
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    // ── Right-click: per-icon settings ──
    BarPopup {
        id: settingsPopup
        anchorItem: root
        bar: root.bar

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 2

            Text {
                text: "Tray Icons"
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                font.bold: true
                color: Colors.overBackground
                Layout.fillWidth: true
                Layout.bottomMargin: 4; leftPadding: 4
            }

            Repeater {
                model: root.trayItems

                delegate: Item {
                    required property SystemTrayItem modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32

                    StyledRect {
                        anchors.fill: parent
                        variant: rowMouse.containsMouse ? "focus" : "bg"
                        radius: 4
                        opacity: rowMouse.containsMouse ? 1.0 : 0.7
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 6; anchors.rightMargin: 6
                        spacing: 8

                        IconImage {
                            width: 20; height: 20
                            source: modelData.icon; smooth: true
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            text: modelData.tooltipTitle || modelData.title || "App"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            color: Colors.overBackground
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                        }

                        // Click to activate
                        Text {
                            text: Icons.caretRight
                            font.family: Icons.font; font.pixelSize: 12
                            color: Colors.outline
                            visible: rowMouse.containsMouse
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: {
                            modelData.activate();
                            settingsPopup.close();
                        }
                    }
                }
            }

            Text {
                text: !trayItems.length ? "No tray icons" : ""
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                color: Colors.outline
                visible: !trayItems.length
                Layout.fillWidth: true; Layout.topMargin: 12
                horizontalAlignment: Text.AlignHCenter
            }

            Item { Layout.fillHeight: true }
        }
    }
}
