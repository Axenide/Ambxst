import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.modules.globals
import qs.modules.theme
import qs.modules.workspaces
import qs.modules.services
import qs.config

Item {
    id: overviewRoot

    property real scale: Configuration.overview.scale
    property int rows: Configuration.overview.rows
    property int columns: Configuration.overview.columns
    property int workspacesShown: rows * columns
    property real workspaceSpacing: Configuration.overview.workspaceSpacing
    property real workspacePadding: 8
    property color activeBorderColor: Colors.adapter.primary

    readonly property var monitor: Hyprland.focusedMonitor
    readonly property int workspaceGroup: Math.floor((monitor?.activeWorkspace?.id - 1 || 0) / workspacesShown)
    readonly property var windowList: HyprlandData.windowList
    readonly property var windowByAddress: HyprlandData.windowByAddress
    readonly property var monitors: HyprlandData.monitors
    readonly property var monitorData: monitors.find(m => m.id === monitor?.id)

    property real workspaceImplicitWidth: (monitorData?.transform % 2 === 1) ? ((monitor?.height || 1920) * scale) : ((monitor?.width || 1080) * scale)
    property real workspaceImplicitHeight: (monitorData?.transform % 2 === 1) ? ((monitor?.width || 1080) * scale) : ((monitor?.height || 1920) * scale)

    property int draggingFromWorkspace: -1
    property int draggingTargetWorkspace: -1

    implicitWidth: overviewBackground.implicitWidth
    implicitHeight: overviewBackground.implicitHeight

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            GlobalStates.overviewOpen = false;
            event.accepted = true;
        } else if (event.key === Qt.Key_Left) {
            Hyprland.dispatch("workspace r-1");
            event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
            Hyprland.dispatch("workspace r+1");
            event.accepted = true;
        }
    }

    Rectangle {
        id: overviewBackground
        anchors.centerIn: parent

        implicitWidth: workspaceColumnLayout.implicitWidth + 8
        implicitHeight: workspaceColumnLayout.implicitHeight + 8
        radius: Configuration.roundness + 4
        color: Colors.adapter.surfaceContainer

        ColumnLayout {
            id: workspaceColumnLayout
            anchors.centerIn: parent
            spacing: workspaceSpacing

            Repeater {
                model: overviewRoot.rows
                delegate: RowLayout {
                    id: row
                    property int rowIndex: index
                    spacing: workspaceSpacing

                    Repeater {
                        model: overviewRoot.columns
                        Rectangle {
                            id: workspace
                            property int colIndex: index
                            property int workspaceValue: overviewRoot.workspaceGroup * workspacesShown + rowIndex * overviewRoot.columns + colIndex + 1
                            property color defaultWorkspaceColor: Colors.background
                            property color hoveredWorkspaceColor: Colors.adapter.surfaceContainer
                            property color hoveredBorderColor: Colors.adapter.outline
                            property bool hoveredWhileDragging: false

                            implicitWidth: overviewRoot.workspaceImplicitWidth + workspacePadding
                            implicitHeight: overviewRoot.workspaceImplicitHeight + workspacePadding
                            color: hoveredWhileDragging ? hoveredWorkspaceColor : defaultWorkspaceColor
                            radius: Configuration.roundness
                            border.width: 2
                            border.color: hoveredWhileDragging ? hoveredBorderColor : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: workspaceValue
                                font.pixelSize: Math.min(parent.width, parent.height) * 0.25
                                font.weight: Font.Bold
                                color: Colors.adapter.surfaceContainerHigh
                                opacity: 1
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton
                                onClicked: {
                                    if (overviewRoot.draggingTargetWorkspace === -1) {
                                        GlobalStates.overviewOpen = false;
                                        Hyprland.dispatch(`workspace ${workspaceValue}`);
                                    }
                                }
                            }

                            DropArea {
                                anchors.fill: parent
                                onEntered: {
                                    overviewRoot.draggingTargetWorkspace = workspaceValue;
                                    if (overviewRoot.draggingFromWorkspace == overviewRoot.draggingTargetWorkspace)
                                        return;
                                    hoveredWhileDragging = true;
                                }
                                onExited: {
                                    hoveredWhileDragging = false;
                                    if (overviewRoot.draggingTargetWorkspace == workspaceValue)
                                        overviewRoot.draggingTargetWorkspace = -1;
                                }
                            }
                        }
                    }
                }
            }
        }

        Item {
            id: windowSpace
            anchors.centerIn: parent
            implicitWidth: workspaceColumnLayout.implicitWidth
            implicitHeight: workspaceColumnLayout.implicitHeight

            Repeater {
                model: overviewRoot.windowList.filter(win => {
                    const inWorkspaceGroup = (overviewRoot.workspaceGroup * overviewRoot.workspacesShown < win?.workspace?.id && win?.workspace?.id <= (overviewRoot.workspaceGroup + 1) * overviewRoot.workspacesShown);
                    const inMonitor = overviewRoot.monitor?.id === win.monitor;
                    return inWorkspaceGroup && inMonitor;
                })

                delegate: OverviewWindow {
                    id: window
                    required property var modelData
                    windowData: modelData
                    scale: overviewRoot.scale
                    availableWorkspaceWidth: overviewRoot.workspaceImplicitWidth
                    availableWorkspaceHeight: overviewRoot.workspaceImplicitHeight

                    property int workspaceColIndex: (windowData?.workspace.id - 1) % overviewRoot.columns
                    property int workspaceRowIndex: Math.floor((windowData?.workspace.id - 1) % overviewRoot.workspacesShown / overviewRoot.columns)

                    xOffset: (overviewRoot.workspaceImplicitWidth + workspacePadding + workspaceSpacing) * workspaceColIndex + workspacePadding / 2
                    yOffset: (overviewRoot.workspaceImplicitHeight + workspacePadding + workspaceSpacing) * workspaceRowIndex + workspacePadding / 2

                    onDragStarted: overviewRoot.draggingFromWorkspace = windowData?.workspace.id || -1
                    onDragFinished: targetWorkspace => {
                        overviewRoot.draggingFromWorkspace = -1;
                        if (targetWorkspace !== -1 && targetWorkspace !== windowData?.workspace.id) {
                            Hyprland.dispatch(`movetoworkspacesilent ${targetWorkspace}, address:${windowData?.address}`);
                        }
                    }
                    onWindowClicked: {
                        GlobalStates.overviewOpen = false;
                        Hyprland.dispatch(`focuswindow address:${windowData.address}`);
                    }
                    onWindowClosed: {
                        Hyprland.dispatch(`closewindow address:${windowData.address}`);
                    }
                }
            }

            Rectangle {
                id: focusedWorkspaceIndicator
                property int activeWorkspaceInGroup: (monitor?.activeWorkspace?.id || 1) - (overviewRoot.workspaceGroup * overviewRoot.workspacesShown)
                property int activeWorkspaceRowIndex: Math.floor((activeWorkspaceInGroup - 1) / overviewRoot.columns)
                property int activeWorkspaceColIndex: (activeWorkspaceInGroup - 1) % overviewRoot.columns

                x: (overviewRoot.workspaceImplicitWidth + workspacePadding + workspaceSpacing) * activeWorkspaceColIndex
                y: (overviewRoot.workspaceImplicitHeight + workspacePadding + workspaceSpacing) * activeWorkspaceRowIndex
                width: overviewRoot.workspaceImplicitWidth + workspacePadding
                height: overviewRoot.workspaceImplicitHeight + workspacePadding
                color: "transparent"
                radius: Configuration.roundness
                border.width: 2
                border.color: overviewRoot.activeBorderColor

                Behavior on x {
                    NumberAnimation {
                        duration: Configuration.animDuration
                        easing.type: Easing.OutQuart
                    }
                }
                Behavior on y {
                    NumberAnimation {
                        duration: Configuration.animDuration
                        easing.type: Easing.OutQuart
                    }
                }
            }
        }
    }
}
