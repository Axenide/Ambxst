pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config

/**
 * TaskTrayItem — Running app icon in the task tray dock
 * Shows app icon with clean styling. Left-click to focus, right-click for window list.
 */
Item {
    id: root

    required property var appData
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

    // Hover/active background
    StyledRect {
        anchors.fill: parent
        anchors.margins: 1
        variant: root.isActive ? "primary" : (root.isHovered ? "focus" : "bg")
        radius: 4
        enableShadow: false
        opacity: root.isActive ? 1.0 : (root.isHovered ? 0.8 : 0.0)
        Behavior on opacity { NumberAnimation { duration: 100 } }
    }

    // App icon
    Image {
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        source: "image://icon/" + AppSearch.guessIcon(root.appData?.appId ?? "")
        sourceSize.width: root.iconSize * 2
        sourceSize.height: root.iconSize * 2
        fillMode: Image.PreserveAspectFit
    }

    // Click handler
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
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
