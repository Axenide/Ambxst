pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config

/**
 * TaskTray — Running applications in the bar with show/hide toggle
 *
 * Matches the visual style of other bar components (ControlsButton, BatteryIndicator, etc.).
 * Toggle button: StyledRect with primary variant when open.
 * Animated expand/collapse of app icons.
 * Right-click toggle → BarPopup with task list.
 */
Item {
    id: root

    required property var bar
    property bool vertical: bar.orientation === "vertical"
    property bool layerEnabled: true

    property real radius: 0
    property real startRadius: radius
    property real endRadius: radius

    // Config
    readonly property bool taskTrayEnabled: Config.bar?.taskTrayEnabled ?? true
    readonly property bool showToggleButton: Config.bar?.taskTrayShowToggle ?? true

    // State
    property bool expanded: true
    property bool isHovered: false
    readonly property bool hasRunningApps: runningApps.length > 0

    // Available running apps (non-pinned, with windows)
    readonly property var runningApps: {
        // Return ALL taskbar apps for the popup, but only running ones for inline display
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

    // Size: same as other bar buttons (36x36 for the button, plus app icons)
    Layout.preferredWidth: vertical ? 36 : implicitWidth
    Layout.preferredHeight: vertical ? implicitHeight : 36
    Layout.fillWidth: vertical
    Layout.fillHeight: !vertical

    width: vertical ? 36 : (showToggleButton ? toggleButtonSize + appIconsWidth : appIconsWidth)
    height: vertical ? (showToggleButton ? toggleButtonSize + appIconsHeight : appIconsHeight) : 36
    implicitWidth: width
    implicitHeight: height

    readonly property int toggleButtonSize: 36
    readonly property int appIconsWidth: expanded ? (itemsRow.implicitWidth + 4) : 0
    readonly property int appIconsHeight: expanded ? itemsColumn.implicitHeight + 4 : 0

    Behavior on width { enabled: !vertical; NumberAnimation { duration: Config.animDuration > 0 ? Config.animDuration : 150; easing.type: Easing.OutCubic } }
    Behavior on height { enabled: vertical; NumberAnimation { duration: Config.animDuration > 0 ? Config.animDuration : 150; easing.type: Easing.OutCubic } }

    // ── Tooltip ──
    StyledToolTip {
        show: root.isHovered && !root.expanded && showToggleButton
        tooltipText: "Running tasks"
    }

    HoverHandler {
        onHoveredChanged: root.isHovered = hovered
    }

    // ── Toggle button ──
    StyledRect {
        id: toggleBtn
        visible: showToggleButton
        variant: root.expanded ? "primary" : "bg"
        anchors {
            left: vertical ? undefined : parent.left
            top: vertical ? parent.top : undefined
            leftMargin: vertical ? 0 : 2
            topMargin: vertical ? 2 : 0
            verticalCenter: vertical ? undefined : parent.verticalCenter
            horizontalCenter: vertical ? parent.horizontalCenter : undefined
        }
        width: toggleButtonSize - 4
        height: toggleButtonSize - 4
        enableShadow: root.layerEnabled

        topLeftRadius: root.vertical ? root.startRadius : root.startRadius
        topRightRadius: root.vertical ? root.startRadius : root.endRadius
        bottomLeftRadius: root.vertical ? root.endRadius : root.startRadius
        bottomRightRadius: root.vertical ? root.endRadius : root.endRadius

        // Hover overlay
        Rectangle {
            anchors.fill: parent
            color: Styling.srItem("overprimary")
            opacity: root.expanded ? 0 : (root.isHovered ? 0.25 : 0)
            radius: parent.radius ?? 0
            Behavior on opacity { NumberAnimation { duration: 100 } }
        }

        // Icon: window/list icon
        Text {
            anchors.centerIn: parent
            text: Icons.terminalWindow
            font.family: Icons.font
            font.pixelSize: 16
            color: root.expanded ? Styling.srItem("overprimary") : Colors.overBackground
            Behavior on color { ColorAnimation { duration: 100 } }
        }

        // Running app count indicator (small dot)
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 3
            width: root.expanded ? 6 : 4
            height: root.expanded ? 6 : 4
            radius: width / 2
            color: root.hasRunningApps
                ? (root.expanded ? Styling.srItem("overprimary") : Styling.srItem("primary"))
                : Colors.outline
            opacity: root.hasRunningApps ? 1.0 : 0.3
            Behavior on width { NumberAnimation { duration: 150 } }
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        MouseArea {
            id: toggleArea
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    root.showPopup();
                } else {
                    root.expanded = !root.expanded;
                }
            }
        }
    }

    // ── Running app icons (inline, animated) ──
    RowLayout {
        id: itemsRow
        visible: !vertical && (expanded || !showToggleButton)
        anchors {
            left: showToggleButton ? toggleBtn.right : parent.left
            leftMargin: 2
            verticalCenter: parent.verticalCenter
        }
        spacing: 2
        opacity: expanded || !showToggleButton ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 100 } }

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

    ColumnLayout {
        id: itemsColumn
        visible: vertical && (expanded || !showToggleButton)
        anchors {
            top: showToggleButton ? toggleBtn.bottom : parent.top
            topMargin: 2
            horizontalCenter: parent.horizontalCenter
        }
        spacing: 2
        opacity: expanded || !showToggleButton ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 100 } }

        Repeater {
            model: root.runningApps

            TaskTrayItem {
                required property var modelData
                appData: modelData
                iconSize: 18
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }

    // ── Popup (right-click) ──
    property bool popupOpen: taskPopup.isOpen

    function showPopup() {
        taskPopup.open();
    }

    BarPopup {
        id: taskPopup
        anchorItem: showToggleButton ? toggleBtn : root
        bar: root.bar

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 2

            // Header
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

            // App list
            Repeater {
                model: root.runningApps

                delegate: Item {
                    id: popupItem
                    required property int index
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    height: 32

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

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                text: modelData.appId
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-2)
                                font.bold: true
                                color: Colors.overBackground
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: modelData.toplevelCount + " window" + (modelData.toplevelCount !== 1 ? "s" : "")
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-4)
                                color: Colors.outline
                            }
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

            // Empty state
            Text {
                text: "No running tasks"
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                color: Colors.outline
                visible: root.runningApps.length === 0
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                Layout.topMargin: 12
            }

            Item { Layout.fillHeight: true }
        }
    }
}
