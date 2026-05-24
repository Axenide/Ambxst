pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell.Widgets
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.components

/**
 * TaskTray — Running applications in the bar with show/hide toggle
 * 
 * Shows a NothingLess toggle icon. When expanded, shows running app icons.
 * Right-click the toggle icon for a full app menu.
 */
Item {
    id: root

    required property var bar
    property string orientation: "horizontal"
    property int iconSize: 22

    readonly property bool isVertical: orientation === "vertical"

    // Config
    readonly property bool taskTrayEnabled: Config.bar?.taskTrayEnabled ?? true
    readonly property var alwaysVisibleApps: Config.bar?.taskTrayAlwaysVisible ?? []
    readonly property bool showToggleButton: Config.bar?.taskTrayShowToggle ?? true

    // State
    property bool expanded: true

    // Available running apps (filtered)
    readonly property var runningApps: {
        var all = TaskbarApps.apps;
        if (!all || all.length === 0) return [];
        var result = [];
        for (var i = 0; i < all.length; i++) {
            var app = all[i];
            // Skip separator
            if (app.appId === "SEPARATOR") continue;
            // Only show apps with running windows
            if (app.toplevels && app.toplevels.length > 0) {
                result.push(app);
            }
        }
        return result;
    }

    readonly property bool hasRunningApps: runningApps.length > 0

    visible: taskTrayEnabled && hasRunningApps
    width: isVertical ? implicitWidth : (visible ? contentWidth : 0)
    height: isVertical ? (visible ? contentHeight : 0) : parent.height
    implicitWidth: isVertical ? Math.max(toggleBtnWidth, iconsWidth) + 8 : contentWidth
    implicitHeight: isVertical ? contentHeight : Math.max(toggleBtnHeight, iconsHeight) + 8

    readonly property int toggleBtnSize: iconSize + 4
    readonly property int toggleBtnWidth: showToggleButton ? toggleBtnSize : 0
    readonly property int toggleBtnHeight: showToggleButton ? toggleBtnSize : 0

    readonly property int iconsWidth: isVertical ? toggleBtnWidth : (itemsRow.implicitWidth + 8)
    readonly property int iconsHeight: isVertical ? itemsColumn.implicitHeight + 8 : toggleBtnHeight

    readonly property int contentWidth: (isVertical ? toggleBtnWidth : toggleBtnWidth + itemsRow.implicitWidth + 8)
    readonly property int contentHeight: (isVertical ? toggleBtnHeight + itemsColumn.implicitHeight + 8 : toggleBtnHeight)

    // ── Toggle button ──
    StyledRect {
        id: toggleBtn
        width: root.toggleBtnSize
        height: root.toggleBtnSize
        anchors {
            left: isVertical ? undefined : parent.left
            top: isVertical ? parent.top : undefined
            leftMargin: isVertical ? 0 : 4
            topMargin: isVertical ? 4 : 0
            verticalCenter: isVertical ? undefined : parent.verticalCenter
            horizontalCenter: isVertical ? parent.horizontalCenter : undefined
        }
        variant: area.containsMouse ? "focus" : "bg"
        radius: Styling.radius(-4)
        visible: showToggleButton

        Text {
            anchors.centerIn: parent
            text: Icons.terminalWindow
            font.family: Icons.font
            font.pixelSize: root.iconSize - 4
            color: Colors.overBackground
        }

        // Active indicator
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 2
            width: 6; height: 3; radius: 1.5
            color: root.expanded ? Styling.srItem("primary") : Colors.outline
            opacity: root.hasRunningApps ? 1.0 : 0.3
        }

        // Running app count badge
        StyledRect {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: -2
            anchors.rightMargin: -2
            width: 14; height: 14
            radius: 7
            variant: "primary"
            visible: root.hasRunningApps && !root.expanded

            Text {
                anchors.centerIn: parent
                text: Math.min(root.runningApps.length, 99)
                font.family: Config.theme.font
                font.pixelSize: 8
                font.bold: true
                color: Colors.background
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    // Show popup menu with all running apps
                    var popup = popupComponent.createObject(root);
                    popup.show();
                } else {
                    // Toggle expanded state
                    root.expanded = !root.expanded;
                }
            }
        }
    }

    // ── Running app icons (visible when expanded) ──
    RowLayout {
        id: itemsRow
        visible: !isVertical && (expanded || !showToggleButton)
        anchors {
            left: showToggleButton ? toggleBtn.right : parent.left
            leftMargin: 4
            verticalCenter: parent.verticalCenter
        }
        spacing: 2
        height: parent.height

        Repeater {
            model: root.runningApps

            TaskTrayItem {
                required property var modelData
                appData: modelData
                iconSize: root.iconSize
                expanded: true
                orientation: root.orientation
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    ColumnLayout {
        id: itemsColumn
        visible: isVertical && (expanded || !showToggleButton)
        anchors {
            top: showToggleButton ? toggleBtn.bottom : parent.top
            topMargin: 4
            horizontalCenter: parent.horizontalCenter
        }
        spacing: 2
        width: parent.width

        Repeater {
            model: root.runningApps

            TaskTrayItem {
                required property var modelData
                appData: modelData
                iconSize: root.iconSize
                expanded: true
                orientation: root.orientation
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }

    // ── Popup menu (right-click) ──
    Component {
        id: popupComponent
        BarPopup {
            id: popup
            width: 240
            height: popupColumn.implicitHeight + 16

            ColumnLayout {
                id: popupColumn
                anchors.fill: parent
                anchors.margins: 8
                spacing: 4

                Text {
                    text: "Running Tasks"
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(0)
                    font.bold: true
                    color: Colors.overBackground
                    Layout.fillWidth: true
                    Layout.bottomMargin: 4
                }

                Repeater {
                    model: root.runningApps

                    delegate: StyledRect {
                        id: appItem
                        required property int index
                        required property var modelData

                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        variant: appMouse.containsMouse ? "focus" : "bg"
                        radius: Styling.radius(-4)

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8

                            IconImage {
                                width: 20; height: 20
                                source: "image://desktop-icon/" + modelData.appId
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    text: modelData.appId
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-1)
                                    font.bold: true
                                    color: Colors.overBackground
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: modelData.toplevelCount + " window" + (modelData.toplevelCount !== 1 ? "s" : "")
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-3)
                                    color: Colors.outline
                                }
                            }

                            Text {
                                text: Icons.caretRight
                                font.family: Icons.font
                                font.pixelSize: 14
                                color: Colors.outline
                            }
                        }

                        MouseArea {
                            id: appMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton

                            onClicked: {
                                // Focus the app
                                if (modelData.toplevels && modelData.toplevels.length > 0) {
                                    modelData.toplevels[0].activate();
                                }
                                popup.close();
                            }
                        }
                    }
                }

                Text {
                    text: root.runningApps.length === 0 ? "No running tasks" : ""
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    color: Colors.outline
                    visible: root.runningApps.length === 0
                }

                Item { Layout.fillHeight: true }
            }
        }
    }
}
