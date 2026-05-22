pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config

Button {
    id: root

    required property var appToplevel
    property int lastFocused: -1
    property real iconSize: Config.dock?.iconSize ?? 40
    property real countDotWidth: 10
    property real countDotHeight: 4
    property string dockPosition: "bottom"

    // Position helpers
    readonly property bool isBottom: dockPosition === "bottom"
    readonly property bool isLeft: dockPosition === "left"
    readonly property bool isRight: dockPosition === "right"
    readonly property bool isVertical: isLeft || isRight

    readonly property bool isSeparator: appToplevel?.appId === "SEPARATOR"
    readonly property var desktopEntry: (isSeparator || !appToplevel) ? null : DesktopEntries.heuristicLookup(appToplevel.appId)
    readonly property bool appIsActive: !isSeparator && (appToplevel?.toplevels?.some(t => t.activated === true) ?? false)
    readonly property bool appIsRunning: !isSeparator && (appToplevel?.toplevelCount ?? 0) > 0

    readonly property bool showIndicators: !isSeparator && (Config.dock?.showRunningIndicators ?? true) && appIsRunning
    readonly property int instanceCount: (isSeparator || !appToplevel) ? 0 : appToplevel.toplevelCount

    enabled: !isSeparator
    implicitWidth: isSeparator ? (isVertical ? iconSize * 0.6 : 2) : iconSize + 8
    implicitHeight: isSeparator ? (isVertical ? 2 : iconSize * 0.6) : iconSize + 8

    padding: 0
    topPadding: 0
    bottomPadding: 0
    leftPadding: 0
    rightPadding: 0

    background: Item {
        StyledRect {
            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            radius: Styling.radius(-2)
            variant: "focus"
            visible: !root.isSeparator && (root.hovered || root.pressed)
            opacity: root.pressed ? 1 : 0.7

            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 2
                }
            }
        }
    }

    contentItem: Item {
        // Separator
        Loader {
            active: root.isSeparator
            anchors.centerIn: parent
            sourceComponent: Separator {
                vert: !root.isVertical
                implicitWidth: root.isVertical ? root.iconSize * 0.6 : 2
                implicitHeight: root.isVertical ? 2 : root.iconSize * 0.6
            }
        }

        // App icon and indicators
        Loader {
            active: !root.isSeparator
            anchors.fill: parent
            sourceComponent: Item {
                anchors.fill: parent

                // App icon
                Item {
                    id: appIconContainer
                    anchors.centerIn: parent
                    width: root.iconSize
                    height: root.iconSize

                    readonly property string iconName: {
                        if (root.desktopEntry && root.desktopEntry.icon) {
                            return root.desktopEntry.icon;
                        }
                        return AppSearch.guessIcon(root.appToplevel?.appId ?? "");
                    }

                    Image {
                        id: appIcon
                        anchors.fill: parent
                        source: "image://icon/" + appIconContainer.iconName
                        sourceSize.width: root.iconSize * 2
                        sourceSize.height: root.iconSize * 2
                        fillMode: Image.PreserveAspectFit
                        mipmap: true
                    }

                    Tinted {
                        sourceItem: appIcon
                        anchors.fill: appIcon
                    }
                }

                // Running indicators - horizontal layout (for bottom dock)
                Row {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: -2
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 3
                    visible: root.showIndicators && !root.isVertical

                    Repeater {
                        model: Math.min(root.instanceCount, 3)
                        delegate: Rectangle {
                            required property int index
                            width: root.instanceCount <= 3 ? root.countDotWidth : root.countDotHeight
                            height: root.countDotHeight
                            radius: height / 2
                            color: root.appIsActive ? Styling.srItem("overprimary") : Qt.rgba(Colors.overBackground.r, Colors.overBackground.g, Colors.overBackground.b, 0.4)

                            Behavior on color {
                                enabled: Config.animDuration > 0
                                ColorAnimation {
                                    duration: Config.animDuration / 2
                                }
                            }
                        }
                    }
                }

                // Running indicators - vertical layout (for left/right dock)
                // Left dock: indicators on left edge, Right dock: indicators on right edge
                Column {
                    anchors.left: root.isLeft ? parent.left : undefined
                    anchors.leftMargin: -2
                    anchors.right: root.isRight ? parent.right : undefined
                    anchors.rightMargin: -2
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    visible: root.showIndicators && root.isVertical

                    Repeater {
                        model: Math.min(root.instanceCount, 3)
                        delegate: Rectangle {
                            required property int index
                            width: root.countDotHeight
                            height: root.instanceCount <= 3 ? root.countDotWidth : root.countDotHeight
                            radius: width / 2
                            color: root.appIsActive ? Styling.srItem("overprimary") : Qt.rgba(Colors.overBackground.r, Colors.overBackground.g, Colors.overBackground.b, 0.4)

                            Behavior on color {
                                enabled: Config.animDuration > 0
                                ColorAnimation {
                                    duration: Config.animDuration / 2
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Left click: launch or cycle through windows
    onClicked: {
        if (isSeparator)
            return;

        if (appToplevel.toplevelCount === 0) {
            // Launch the app
            if (desktopEntry) {
                AppSearch.launchApp(desktopEntry);
            }
            return;
        }

        // Cycle through running windows
        lastFocused = (lastFocused + 1) % appToplevel.toplevelCount;
        appToplevel.toplevels[lastFocused].activate();
    }

    // Middle click: always launch new instance
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.MiddleButton | Qt.RightButton

        onClicked: mouse => {
            if (root.isSeparator)
                return;

            if (mouse.button === Qt.MiddleButton) {
                // Launch new instance
                if (root.desktopEntry) {
                    AppSearch.launchApp(root.desktopEntry);
                }
            } else if (mouse.button === Qt.RightButton) {
                // Toggle pin
                TaskbarApps.togglePin(root.appToplevel?.appId ?? "");
            }
        }
    }

    // Tooltip
    StyledToolTip {
        show: root.hovered && !root.isSeparator
        tooltipText: root.desktopEntry?.name ?? root.appToplevel?.appId ?? ""
    }
}
