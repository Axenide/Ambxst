pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.modules.globals
import qs.config

/**
 * TaskTray — Running applications in the bar with show/hide toggle
 *
 * Matches the visual style of LayoutSelectorButton and other bar buttons.
 * Toggle icon with StyledRect bg/primary variants, hover animation.
 * Shows running app icons in a dock-like container when expanded.
 * Right-click → BarPopup with full app list.
 */
Item {
    id: root

    required property var bar
    property bool vertical: bar.orientation === "vertical"
    property bool isHovered: false
    property bool layerEnabled: true

    property real radius: 0
    property real startRadius: radius
    property real endRadius: radius

    // Config
    readonly property bool taskTrayEnabled: Config.bar?.taskTrayEnabled ?? true
    readonly property bool showToggleButton: Config.bar?.taskTrayShowToggle ?? true

    // State
    property bool expanded: true
    readonly property bool hasRunningApps: runningApps.length > 0

    // Running apps (from TaskbarApps, filtered to only those with windows)
    readonly property var runningApps: {
        var all = TaskbarApps.apps;
        if (!all) return [];
        var result = [];
        for (var i = 0; i < all.length; i++) {
            var app = all[i];
            if (app.appId === "SEPARATOR") continue;
            if (app.toplevels && app.toplevels.length > 0) {
                result.push(app);
            }
        }
        return result;
    }

    // Popup visibility
    property bool popupOpen: taskPopup.isOpen

    // Layout sizing
    Layout.preferredWidth: vertical ? 36 : implicitContentWidth
    Layout.preferredHeight: vertical ? implicitContentHeight : 36
    Layout.fillWidth: vertical
    Layout.fillHeight: !vertical

    readonly property int toggleSize: 36
    readonly property int appItemSize: 32

    readonly property int implicitContentWidth: {
        var w = 0;
        if (showToggleButton) w += toggleSize;
        if (expanded && hasRunningApps) {
            w += 4 + (runningApps.length * (appItemSize + 2));
        }
        return Math.max(36, w);
    }
    readonly property int implicitContentHeight: {
        var h = 0;
        if (showToggleButton) h += toggleSize;
        if (expanded && hasRunningApps) {
            h += 4 + (runningApps.length * (appItemSize + 2));
        }
        return Math.max(36, h);
    }

    width: vertical ? 36 : implicitContentWidth
    height: vertical ? implicitContentHeight : 36

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

    // ── Toggle button ──
    StyledRect {
        id: toggleBtn
        visible: showToggleButton
        variant: root.popupOpen ? "primary" : "bg"
        anchors {
            left: vertical ? undefined : parent.left
            top: vertical ? parent.top : undefined
            leftMargin: vertical ? 0 : 2
            topMargin: vertical ? 2 : 0
            verticalCenter: vertical ? undefined : parent.verticalCenter
            horizontalCenter: vertical ? parent.horizontalCenter : undefined
        }
        width: toggleSize - 4
        height: toggleSize - 4
        enableShadow: root.layerEnabled

        topLeftRadius: vertical ? startRadius : startRadius
        topRightRadius: vertical ? startRadius : endRadius
        bottomLeftRadius: vertical ? endRadius : startRadius
        bottomRightRadius: vertical ? endRadius : endRadius

        // Hover overlay
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

        // Icon
        Text {
            anchors.centerIn: parent
            text: Icons.terminalWindow
            font.family: Icons.font
            font.pixelSize: 18
            color: root.popupOpen ? toggleBtn.item : Styling.srItem("overprimary")
        }

        // Running count badge when collapsed
        StyledRect {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: -2
            anchors.rightMargin: -2
            width: 16; height: 16
            radius: 8
            variant: "primary"
            visible: hasRunningApps && !root.expanded

            Text {
                anchors.centerIn: parent
                text: Math.min(runningApps.length, 99)
                font.family: Config.theme.font
                font.pixelSize: 9
                font.bold: true
                color: Colors.background
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    taskPopup.open();
                } else {
                    root.expanded = !root.expanded;
                }
            }
        }

        StyledToolTip {
            visible: root.isHovered && !root.popupOpen
            tooltipText: hasRunningApps ? runningApps.length + " tasks running" : "No running tasks"
        }
    }

    // ── Running app icons (dock-style container) ──
    StyledRect {
        id: dockBg
        anchors {
            left: showToggleButton ? toggleBtn.right : parent.left
            leftMargin: 2
            verticalCenter: parent.verticalCenter
        }
        width: dockRow.implicitWidth + 8
        height: 32
        variant: "bg"
        radius: 6
        enableShadow: root.layerEnabled
        visible: expanded && hasRunningApps

        opacity: expanded ? 1.0 : 0.0
        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation { duration: Config.animDuration / 2 }
        }

        RowLayout {
            id: dockRow
            anchors.centerIn: parent
            spacing: 2

            Repeater {
                model: root.runningApps

                TaskTrayItem {
                    required property var modelData
                    appData: modelData
                    iconSize: 18
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }
    }

    // ── Popup (right-click) ──
    BarPopup {
        id: taskPopup
        anchorItem: showToggleButton ? toggleBtn : root
        bar: root.bar

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 2

            Text {
                text: "Running Tasks"
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                font.bold: true
                color: Colors.overBackground
                Layout.fillWidth: true
                Layout.bottomMargin: 4
                leftPadding: 4
            }

            Repeater {
                model: root.runningApps

                delegate: Item {
                    id: popupItem
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: 32

                    StyledRect {
                        id: itemBg
                        anchors.fill: parent
                        variant: itemMouse.containsMouse ? "focus" : "bg"
                        radius: 4
                        opacity: itemMouse.containsMouse ? 1.0 : 0.7
                        Behavior on opacity { NumberAnimation { duration: 80 } }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 6; anchors.rightMargin: 6
                        spacing: 8

                        Image {
                            width: 18; height: 18
                            source: "image://icon/" + AppSearch.guessIcon(modelData.appId)
                            sourceSize.width: 36; sourceSize.height: 36
                            fillMode: Image.PreserveAspectFit
                        }

                        Text {
                            text: modelData.appId
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            color: Colors.overBackground
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: Icons.caretRight
                            font.family: Icons.font
                            font.pixelSize: 12
                            color: Colors.outline
                            visible: itemMouse.containsMouse
                        }
                    }

                    MouseArea {
                        id: itemMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: {
                            if (modelData.toplevels && modelData.toplevels.length > 0) {
                                modelData.toplevels[0].activate();
                            }
                            taskPopup.close();
                        }
                    }
                }
            }

            Text {
                text: runningApps.length === 0 ? "No running tasks" : ""
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                color: Colors.outline
                visible: runningApps.length === 0
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                Layout.topMargin: 12
            }

            Item { Layout.fillHeight: true }
        }
    }
}
