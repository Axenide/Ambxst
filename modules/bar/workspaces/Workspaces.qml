import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Widgets
import Qt5Compat.GraphicalEffects
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.globals
import qs.config

Item {
    id: workspacesWidget
    required property var bar
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(bar.screen)
    readonly property Toplevel activeWindow: ToplevelManager.activeToplevel

    readonly property int workspaceGroup: Math.floor((monitor?.activeWorkspace?.id - 1 || 0) / Config.workspaces.shown)
    property list<bool> workspaceOccupied: []
    property int widgetPadding: 4
    property int workspaceButtonWidth: parent.height - widgetPadding * 2
    property real workspaceIconSize: workspaceButtonWidth * 0.6
    property real workspaceIconSizeShrinked: workspaceButtonWidth * 0.5
    property real workspaceIconOpacityShrinked: 1
    property real workspaceIconMarginShrinked: -4
    property int workspaceIndexInGroup: (monitor?.activeWorkspace?.id - 1 || 0) % Config.workspaces.shown

    function updateWorkspaceOccupied() {
        workspaceOccupied = Array.from({
            length: Config.workspaces.shown
        }, (_, i) => {
            return Hyprland.workspaces.values.some(ws => ws.id === workspaceGroup * Config.workspaces.shown + i + 1);
        });
    }

    Component.onCompleted: updateWorkspaceOccupied()

    Connections {
        target: Hyprland.workspaces
        function onValuesChanged() {
            updateWorkspaceOccupied();
        }
    }

    // Monitor changes for this specific monitor
    Connections {
        target: monitor
        function onActiveWorkspaceChanged() {
            updateWorkspaceOccupied();
        }
    }

    onWorkspaceGroupChanged: {
        updateWorkspaceOccupied();
    }

    implicitWidth: rowLayout.implicitWidth + widgetPadding * 2
    implicitHeight: rowLayout.implicitHeight + widgetPadding * 2

    BgRect {
        anchors.fill: parent
    }

    WheelHandler {
        onWheel: event => {
            if (event.angleDelta.y < 0)
                Hyprland.dispatch(`workspace r+1`);
            else if (event.angleDelta.y > 0)
                Hyprland.dispatch(`workspace r-1`);
        }
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.BackButton
        onPressed: event => {
            if (event.button === Qt.BackButton) {
                Hyprland.dispatch(`togglespecialworkspace`);
            }
        }
    }

    RowLayout {
        id: rowLayout
        z: 1

        spacing: 0
        anchors.fill: parent
        anchors.margins: widgetPadding
        implicitHeight: workspaceButtonWidth

        Repeater {
            model: Config.workspaces.shown

            Rectangle {
                z: 1
                implicitWidth: workspaceButtonWidth
                implicitHeight: workspaceButtonWidth
                radius: Math.max(0, Config.roundness - widgetPadding)
                property var leftOccupied: (workspaceOccupied[index - 1] && !(!activeWindow?.activated && monitor?.activeWorkspace?.id === index))
                property var rightOccupied: (workspaceOccupied[index + 1] && !(!activeWindow?.activated && monitor?.activeWorkspace?.id === index + 2))
                property var radiusLeft: leftOccupied ? 0 : Math.max(0, Config.roundness - widgetPadding)
                property var radiusRight: rightOccupied ? 0 : Math.max(0, Config.roundness - widgetPadding)

                topLeftRadius: radiusLeft
                bottomLeftRadius: radiusLeft
                topRightRadius: radiusRight
                bottomRightRadius: radiusRight

                color: Colors.surfaceBright
                opacity: (workspaceOccupied[index] && !(!activeWindow?.activated && monitor?.activeWorkspace?.id === index + 1)) ? Config.opacity : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Config.animDuration - 100
                        easing.type: Easing.OutQuad
                    }
                }
                Behavior on radiusLeft {
                    NumberAnimation {
                        duration: Config.animDuration - 100
                        easing.type: Easing.OutQuad
                    }
                }

                Behavior on radiusRight {
                    NumberAnimation {
                        duration: Config.animDuration - 100
                        easing.type: Easing.OutQuad
                    }
                }
            }
        }
    }

    Rectangle {
        z: 2
        property real activeWorkspaceMargin: 4
        implicitHeight: parent.workspaceButtonWidth - activeWorkspaceMargin * 2
        radius: {
            const currentWorkspaceHasWindows = Hyprland.workspaces.values.some(ws => ws.id === (monitor?.activeWorkspace?.id || 1) && HyprlandData.windowList.some(w => w.workspace.id === ws.id));
            if (Config.roundness === 0) {
                return 0;
            }
            return currentWorkspaceHasWindows ? Math.max(0, Config.roundness - parent.widgetPadding - activeWorkspaceMargin) : implicitHeight / 2;
        }

        Behavior on radius {
            NumberAnimation {
                duration: Config.animDuration - 100
                easing.type: Easing.OutQuad
            }
        }
        color: Colors.adapter.primary
        anchors.verticalCenter: parent.verticalCenter

        property real idx1: workspaceIndexInGroup
        property real idx2: workspaceIndexInGroup
        x: Math.min(idx1, idx2) * workspaceButtonWidth + activeWorkspaceMargin + widgetPadding
        implicitWidth: Math.abs(idx1 - idx2) * workspaceButtonWidth + workspaceButtonWidth - activeWorkspaceMargin * 2

        Behavior on activeWorkspaceMargin {
            NumberAnimation {
                duration: Config.animDuration / 2
                easing.type: Easing.OutQuad
            }
        }
        Behavior on idx1 {
            NumberAnimation {
                duration: Config.animDuration / 3
                easing.type: Easing.OutSine
            }
        }
        Behavior on idx2 {
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutSine
            }
        }
    }

    RowLayout {
        id: rowLayoutNumbers
        z: 3

        spacing: 0
        anchors.fill: parent
        anchors.margins: widgetPadding
        implicitHeight: workspaceButtonWidth

        Repeater {
            model: Config.workspaces.shown

            Button {
                id: button
                property int workspaceValue: workspaceGroup * Config.workspaces.shown + index + 1
                Layout.fillHeight: true
                onPressed: Hyprland.dispatch(`workspace ${workspaceValue}`)
                width: workspaceButtonWidth

                background: Item {
                    id: workspaceButtonBackground
                    implicitWidth: workspaceButtonWidth
                    implicitHeight: workspaceButtonWidth
                    property var biggestWindow: {
                        const windowsInThisWorkspace = HyprlandData.windowList.filter(w => w.workspace.id == button.workspaceValue);
                        return windowsInThisWorkspace.reduce((maxWin, win) => {
                            const maxArea = (maxWin?.size?.[0] ?? 0) * (maxWin?.size?.[1] ?? 0);
                            const winArea = (win?.size?.[0] ?? 0) * (win?.size?.[1] ?? 0);
                            return winArea > maxArea ? win : maxWin;
                        }, null);
                    }
                    property var mainAppIconSource: Quickshell.iconPath(AppSearch.guessIcon(biggestWindow?.class), "image-missing")

                    Text {
                        opacity: Config.workspaces.alwaysShowNumbers || ((Config.workspaces.showNumbers && (!Config.workspaces.showAppIcons || !workspaceButtonBackground.biggestWindow || Config.workspaces.alwaysShowNumbers)) || (Config.workspaces.alwaysShowNumbers && !Config.workspaces.showAppIcons)) ? 1 : 0
                        z: 3

                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize - ((text.length - 1) * (text !== "10") * 2)
                        text: `${button.workspaceValue}`
                        elide: Text.ElideRight
                        color: (monitor?.activeWorkspace?.id == button.workspaceValue) ? Colors.background : (workspaceOccupied[index] ? Colors.adapter.overBackground : Colors.adapter.overSecondaryFixedVariant)

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 150
                                easing.type: Easing.OutQuad
                            }
                        }
                    }
                    Rectangle {
                        opacity: (Config.workspaces.showNumbers || Config.workspaces.alwaysShowNumbers || (Config.workspaces.showAppIcons && workspaceButtonBackground.biggestWindow)) ? 0 : 1
                        visible: opacity > 0
                        anchors.centerIn: parent
                        width: workspaceButtonWidth * 0.2
                        height: width
                        radius: width / 2
                        color: (monitor?.activeWorkspace?.id == button.workspaceValue) ? Colors.background : (workspaceOccupied[index] ? Colors.adapter.overBackground : Colors.adapter.overSecondaryFixedVariant)

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 150
                                easing.type: Easing.OutQuad
                            }
                        }
                    }
                    Item {
                        anchors.centerIn: parent
                        width: workspaceButtonWidth
                        height: workspaceButtonWidth
                        opacity: !Config.workspaces.showAppIcons ? 0 : (workspaceButtonBackground.biggestWindow && !Config.workspaces.alwaysShowNumbers && Config.workspaces.showAppIcons) ? 1 : workspaceButtonBackground.biggestWindow ? workspaceIconOpacityShrinked : 0
                        visible: opacity > 0
                        IconImage {
                            id: mainAppIcon
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            anchors.bottomMargin: (!Config.workspaces.alwaysShowNumbers && Config.workspaces.showAppIcons) ? (workspaceButtonWidth - workspaceIconSize) / 2 : workspaceIconMarginShrinked
                            anchors.rightMargin: (!Config.workspaces.alwaysShowNumbers && Config.workspaces.showAppIcons) ? (workspaceButtonWidth - workspaceIconSize) / 2 : workspaceIconMarginShrinked

                            source: workspaceButtonBackground.mainAppIconSource
                            implicitSize: (!Config.workspaces.alwaysShowNumbers && Config.workspaces.showAppIcons) ? workspaceIconSize : workspaceIconSizeShrinked

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 150
                                    easing.type: Easing.OutQuad
                                }
                            }
                            Behavior on anchors.bottomMargin {
                                NumberAnimation {
                                    duration: 150
                                    easing.type: Easing.OutQuad
                                }
                            }
                            Behavior on anchors.rightMargin {
                                NumberAnimation {
                                    duration: 150
                                    easing.type: Easing.OutQuad
                                }
                            }
                            Behavior on implicitSize {
                                NumberAnimation {
                                    duration: 150
                                    easing.type: Easing.OutQuad
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
