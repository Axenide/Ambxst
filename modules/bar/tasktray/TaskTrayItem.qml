pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.modules.components
import Quickshell.Wayland
import qs.modules.theme
import qs.modules.services
import qs.config

/**
 * TaskTrayItem — Single running app icon in the task tray
 * Matches the style of dock app buttons (small, clean, indicator dot)
 */
Item {
    id: root

    required property var appData  // TaskbarApps entry (appId, toplevels, pinned, toplevelCount)
    property int iconSize: 18

    readonly property bool hasWindows: appData && appData.toplevels && appData.toplevels.length > 0
    readonly property bool isActive: {
        if (!hasWindows) return false;
        var active = ToplevelManager.activeToplevel;
        if (!active) return false;
        return appData.toplevels.some(t => t.handle === active.handle);
    }

    width: 28
    height: 28

    property bool isHovered: false

    HoverHandler {
        onHoveredChanged: root.isHovered = hovered
    }

    // Hover background
    StyledRect {
        anchors.fill: parent
        variant: "bg"
        radius: 4
        opacity: root.isHovered ? 0.4 : 0.0
        Behavior on opacity { NumberAnimation { duration: 100 } }
    }

    // App icon
    Image {
        id: appIcon
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        source: "image://icon/" + AppSearch.guessIcon(root.appData?.appId ?? "")
        sourceSize.width: root.iconSize * 2
        sourceSize.height: root.iconSize * 2
        fillMode: Image.PreserveAspectFit
        opacity: root.isActive ? 1.0 : 0.7
        Behavior on opacity { NumberAnimation { duration: 100 } }
    }

    // Active indicator
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 2
        width: root.isActive ? 5 : 3
        height: root.isActive ? 5 : 3
        radius: width / 2
        color: root.isActive ? Styling.srItem("primary") : Colors.outline
        opacity: root.hasWindows ? 1.0 : 0.0
        Behavior on width { NumberAnimation { duration: 150 } }
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    // Click handlers
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                // Show window list context menu
                var menu = winMenuComponent.createObject(root);
                menu.appData = root.appData;
                menu.popup();
            } else if (root.hasWindows) {
                // Cycle through windows
                var windows = root.appData.toplevels;
                var active = ToplevelManager.activeToplevel;
                var idx = -1;
                for (var i = 0; i < windows.length; i++) {
                    if (windows[i].handle === active.handle) {
                        idx = i;
                        break;
                    }
                }
                var next = (idx + 1) % windows.length;
                windows[next].activate();
            } else if (root.appData.pinned) {
                // Launch pinned app
                TaskbarApps.launchApp(root.appData.appId);
            }
        }
    }

    // Context menu (window list)
    Component {
        id: winMenuComponent
        Menu {
            id: menu
            title: root.appData.appId

            Instantiator {
                model: root.appData.toplevels || []

                MenuItem {
                    required property var modelData
                    text: modelData.title || modelData.appId || "Window"
                    onTriggered: {
                        modelData.activate();
                        menu.close();
                    }
                }

                onObjectAdded: (idx, obj) => menu.insertItem(idx, obj)
                onObjectRemoved: (idx, obj) => menu.removeItem(obj)
            }

            MenuSeparator { visible: root.appData.toplevels && root.appData.toplevels.length > 0 }

            MenuItem {
                text: root.appData.pinned ? "Unpin" : "Pin to dock"
                onTriggered: {
                    TaskbarApps.togglePin(root.appData.appId);
                    menu.close();
                }
            }
        }
    }
}
