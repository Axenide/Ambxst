import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.bar.workspaces
import qs.config

// Workspace button shared by the horizontal and vertical workspace layouts.
// Orientation-agnostic: the parent layout decides fill direction/size, this
// button only renders the workspace number, app icon and occupancy dot.
Button {
    id: root

    property int workspaceValue: 1
    property bool occupied: false
    property bool active: false
    property real buttonWidth: 36
    property real iconSize: 22
    property real iconSizeShrinked: 18
    property real iconOpacityShrinked: 1
    property real iconMarginShrinked: -4
    property var labelFontSize: null

    background: Item {
        id: workspaceButtonBackground
        implicitWidth: root.buttonWidth
        implicitHeight: root.buttonWidth
        property var focusedWindow: {
            const windowsInThisWorkspace = CompositorData.workspaceWindowsMap[root.workspaceValue] || [];
            if (windowsInThisWorkspace.length === 0)
                return null;
            // Get the window with the lowest focusHistoryID (most recently focused)
            return windowsInThisWorkspace.reduce((best, win) => {
                const bestFocus = (best && best.focusHistoryID !== undefined ? best.focusHistoryID : Infinity);
                const winFocus = (win && win.focusHistoryID !== undefined ? win.focusHistoryID : Infinity);
                return winFocus < bestFocus ? win : best;
            }, null);
        }
        readonly property var focusedDesktopEntry: focusedWindow ? DesktopEntries.heuristicLookup(focusedWindow.class) : null
        property var mainAppIconSource: {
            if (focusedDesktopEntry && focusedDesktopEntry.icon) {
                return Quickshell.iconPath(focusedDesktopEntry.icon, "image-missing");
            }
            return Quickshell.iconPath(AppSearch.getCachedIcon(focusedWindow ? focusedWindow.class : undefined), "image-missing");
        }

        Text {
            opacity: Config.workspaces.alwaysShowNumbers || ((Config.workspaces.showNumbers && (!Config.workspaces.showAppIcons || !workspaceButtonBackground.focusedWindow || Config.workspaces.alwaysShowNumbers)) || (Config.workspaces.alwaysShowNumbers && !Config.workspaces.showAppIcons)) ? 1 : 0
            z: 3

            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.family: Config.theme.font
            font.pixelSize: root.labelFontSize ? root.labelFontSize(text) : Config.theme.fontSize
            text: `${root.workspaceValue}`
            elide: Text.ElideRight
            color: root.active ? Styling.srItem("primary") : (root.occupied ? Colors.overBackground : Colors.overSecondaryFixedVariant)

            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: 150
                    easing.type: Styling.animEasing
                }
            }
        }
        Rectangle {
            opacity: (Config.workspaces.showNumbers || Config.workspaces.alwaysShowNumbers || (Config.workspaces.showAppIcons && workspaceButtonBackground.focusedWindow)) ? 0 : (root.active || root.occupied ? 1 : 0.5)
            visible: opacity > 0
            anchors.centerIn: parent
            width: root.buttonWidth * 0.2
            height: width
            radius: width / 2
            color: root.active ? Styling.srItem("primary") : Colors.overBackground

            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: 150
                    easing.type: Styling.animEasing
                }
            }
        }
        Item {
            anchors.centerIn: parent
            width: root.buttonWidth
            height: root.buttonWidth
            opacity: !Config.workspaces.showAppIcons ? 0 : (workspaceButtonBackground.focusedWindow && !Config.workspaces.alwaysShowNumbers && Config.workspaces.showAppIcons) ? 1 : workspaceButtonBackground.focusedWindow ? root.iconOpacityShrinked : 0
            visible: opacity > 0
            IconImage {
                id: mainAppIcon
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.bottomMargin: (!Config.workspaces.alwaysShowNumbers && Config.workspaces.showAppIcons) ? Math.round((root.buttonWidth - root.iconSize) / 2) : root.iconMarginShrinked
                anchors.rightMargin: (!Config.workspaces.alwaysShowNumbers && Config.workspaces.showAppIcons) ? Math.round((root.buttonWidth - root.iconSize) / 2) : root.iconMarginShrinked

                source: workspaceButtonBackground.mainAppIconSource
                implicitSize: (!Config.workspaces.alwaysShowNumbers && Config.workspaces.showAppIcons) ? root.iconSize : root.iconSizeShrinked

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: 150
                        easing.type: Styling.animEasing
                    }
                }
                Behavior on anchors.bottomMargin {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: 150
                        easing.type: Styling.animEasing
                    }
                }
                Behavior on anchors.rightMargin {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: 150
                        easing.type: Styling.animEasing
                    }
                }
                Behavior on implicitSize {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: 150
                        easing.type: Styling.animEasing
                    }
                }
            }

            Tinted {
                sourceItem: mainAppIcon
                anchors.fill: mainAppIcon
            }
        }
    }
}
