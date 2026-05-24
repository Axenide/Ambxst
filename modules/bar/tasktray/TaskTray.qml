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
import qs.modules.globals
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

    // ── Same exact sizing as ControlsButton / LayoutSelectorButton ──
    Layout.preferredWidth: 36
    Layout.preferredHeight: 36
    Layout.maximumWidth: 36
    Layout.maximumHeight: 36
    Layout.fillWidth: vertical
    Layout.fillHeight: !vertical

    width: vertical ? 36 : implicitWidthOverride
    height: vertical ? implicitHeightOverride : 36

    readonly property int trayItemSize: 24

    // Override width/height when expanded to include the dock
    readonly property int dockWidth: expanded && hasItems ? (dockRow.implicitWidth + 8) : 0
    readonly property int dockHeight: expanded && hasItems ? (dockRow.implicitHeight + 8) : 0

    readonly property int implicitWidthOverride: showToggleButton ? 36 + 2 + dockWidth : dockWidth
    readonly property int implicitHeightOverride: showToggleButton ? 36 + 2 + dockHeight : dockHeight

    Behavior on width {
        enabled: !vertical && Config.animDuration > 0
        NumberAnimation { duration: Config.animDuration / 2; easing.type: Easing.OutCubic }
    }
    Behavior on height {
        enabled: vertical && Config.animDuration > 0
        NumberAnimation { duration: Config.animDuration / 2; easing.type: Easing.OutCubic }
    }

    HoverHandler {
        onHoveredChanged: root.isHovered = hovered
    }

    // ── Toggle button: same size as LayoutSelectorButton ──
    StyledRect {
        id: toggleBtn
        visible: showToggleButton
        variant: root.popupOpen ? "primary" : "bg"
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
        }
        width: 36
        enableShadow: root.layerEnabled

        topLeftRadius: vertical ? startRadius : startRadius
        topRightRadius: vertical ? startRadius : endRadius
        bottomLeftRadius: vertical ? endRadius : startRadius
        bottomRightRadius: vertical ? endRadius : endRadius

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
            font.family: Icons.font
            font.pixelSize: 18
            color: root.popupOpen ? toggleBtn.item : Styling.srItem("overprimary")
        }

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

    // ── Systray dock: always exists so animation works, visibility via opacity ──
    StyledRect {
        id: dockBg
        anchors {
            left: showToggleButton ? toggleBtn.right : parent.left
            leftMargin: 2
            verticalCenter: parent.verticalCenter
        }
        width: dockRow.implicitWidth + 8
        height: 30
        variant: "bg"
        radius: 6
        enableShadow: root.layerEnabled
        visible: hasItems

        opacity: expanded ? 1.0 : 0.0
        scale: expanded ? 1.0 : 0.8
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

                delegate: MouseArea {
                    id: trayIconArea
                    required property SystemTrayItem modelData
                    width: trayItemSize
                    height: trayItemSize
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    property bool iconHovered: false

                    HoverHandler {
                        onHoveredChanged: trayIconArea.iconHovered = hovered
                    }

                    StyledRect {
                        anchors.fill: parent; anchors.margins: 1
                        variant: "bg"; radius: 4
                        opacity: trayIconArea.iconHovered ? 0.5 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 80 } }
                    }

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

                    onClicked: event => {
                        if (event.button === Qt.LeftButton) {
                            trayIconArea.modelData.activate();
                        } else if (event.button === Qt.RightButton && trayIconArea.modelData.hasMenu) {
                            var popup = trayIconArea.modelData.menu;
                            if (popup) popup.open();
                        }
                        event.accepted = true;
                    }
                }
            }
        }
    }

    // ── Popup with per-item toggle option ──
    BarPopup {
        id: trayPopup
        anchorItem: toggleBtn
        bar: root.bar

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 2

            Text {
                text: "Hidden Icons"
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                font.bold: true
                color: Colors.overBackground
                Layout.fillWidth: true
                Layout.bottomMargin: 4
                leftPadding: 4
            }

            Repeater {
                model: root.trayItems

                delegate: Item {
                    required property SystemTrayItem modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32

                    StyledRect {
                        anchors.fill: parent
                        variant: popupMouse.containsMouse ? "focus" : "bg"
                        radius: 4
                        opacity: popupMouse.containsMouse ? 1.0 : 0.7
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 6; anchors.rightMargin: 6
                        spacing: 8

                        IconImage {
                            id: popupIcon
                            width: 20; height: 20
                            source: modelData.icon
                            smooth: true
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

                        Text {
                            text: Icons.caretRight
                            font.family: Icons.font; font.pixelSize: 12
                            color: Colors.outline
                            visible: popupMouse.containsMouse
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }

                    MouseArea {
                        id: popupMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: {
                            modelData.activate();
                            trayPopup.close();
                        }
                    }
                }
            }

            // Toggle separator + option
            MenuSeparator {
                Layout.fillWidth: true
                visible: hasItems
                Layout.topMargin: 4
                Layout.bottomMargin: 4
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 32

                StyledRect {
                    anchors.fill: parent
                    variant: toggleOption.containsMouse ? "focus" : "bg"
                    radius: 4
                    opacity: toggleOption.containsMouse ? 1.0 : 0.7
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 6; anchors.rightMargin: 6
                    spacing: 8

                    Text {
                        text: root.expanded ? Icons.minus : Icons.plus
                        font.family: Icons.font; font.pixelSize: 16
                        color: Colors.overBackground
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Text {
                        text: root.expanded ? "Hide icons in tray" : "Show icons in tray"
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-2)
                        color: Colors.overBackground
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                    }
                }

                MouseArea {
                    id: toggleOption
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: {
                        root.expanded = !root.expanded;
                        trayPopup.close();
                    }
                }
            }

            Text {
                text: !hasItems ? "No hidden icons" : ""
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                color: Colors.outline
                visible: !hasItems
                Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                Layout.topMargin: 12
            }

            Item { Layout.fillHeight: true }
        }
    }
}
