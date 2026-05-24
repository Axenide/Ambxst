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

/**
 * TaskTrayItem — Single running app icon in the task tray
 * Shows app icon, click to focus, right-click for window list
 */
Item {
    id: root

    required property var appData  // TaskbarApps entry (appId, toplevels, pinned, toplevelCount)
    property int iconSize: 20
    property bool expanded: true  // Show full icon vs compact indicator
    property string orientation: "horizontal"

    readonly property bool hasWindows: appData && appData.toplevels && appData.toplevels.length > 0
    readonly property bool isFocused: {
        if (!hasWindows) return false;
        var activeToplevel = ToplevelManager.activeToplevel;
        if (!activeToplevel) return false;
        return appData.toplevels.some(t => t.address === activeToplevel.handle);
    }

    width: expanded ? iconSize + 8 : 4
    height: expanded ? iconSize + 8 : (orientation === "vertical" ? iconSize + 8 : 4)

    // App icon
    IconImage {
        id: appIcon
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        source: "image://desktop-icon/" + root.appData.appId
        visible: root.expanded
        opacity: root.isFocused ? 1.0 : 0.75
    }

    // Active indicator dot
    Rectangle {
        anchors {
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
            bottomMargin: 1
        }
        width: root.isFocused ? 6 : 4
        height: root.isFocused ? 6 : 4
        radius: width / 2
        color: root.isFocused ? Styling.srItem("primary") : Colors.outline
        opacity: root.hasWindows ? 1.0 : 0.0
        visible: !root.expanded || root.hasWindows

        Behavior on width { NumberAnimation { duration: 150 } }
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    // Click to focus/launch
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                // Right-click: show window list menu
                var menu = contextMenuComponent.createObject(root);
                menu.appData = root.appData;
                menu.popup();
            } else if (root.hasWindows) {
                // Left-click: focus next window or first window
                var toplevels = root.appData.toplevels;
                var activeToplevel = ToplevelManager.activeToplevel;
                var currentIdx = -1;
                for (var i = 0; i < toplevels.length; i++) {
                    if (toplevels[i].address === activeToplevel.handle) {
                        currentIdx = i;
                        break;
                    }
                }
                var nextIdx = (currentIdx + 1) % toplevels.length;
                toplevels[nextIdx].activate();
            } else if (root.appData.pinned) {
                // Launch pinned app
                TaskbarApps.launchApp(root.appData.appId);
            }
        }
    }

    Component {
        id: contextMenuComponent
        Menu {
            id: menu
            title: root.appData.appId

            Instantiator {
                model: root.appData.toplevels || []

                MenuItem {
                    required property var modelData
                    text: modelData.title || modelData.appId || "Window"
                    icon.source: "image://desktop-icon/" + root.appData.appId

                    onTriggered: {
                        modelData.activate();
                        menu.close();
                    }
                }

                onObjectAdded: (index, object) => menu.insertItem(index, object)
                onObjectRemoved: (index, object) => menu.removeItem(object)
            }

            MenuSeparator { visible: root.appData.toplevels && root.appData.toplevels.length > 0 }

            MenuItem {
                text: root.appData.pinned ? "Unpin from dock" : "Pin to dock"
                onTriggered: {
                    TaskbarApps.togglePin(root.appData.appId);
                    menu.close();
                }
            }
        }
    }
}
