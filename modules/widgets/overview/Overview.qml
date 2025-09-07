import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.modules.globals
import qs.modules.theme
import qs.modules.bar.workspaces
import qs.modules.services
import qs.config

Item {
    id: overviewRoot

    property real scale: Config.overview.scale
    property int rows: Config.overview.rows
    property int columns: Config.overview.columns
    property int workspacesShown: rows * columns
    property real workspaceSpacing: Config.overview.workspaceSpacing
    property real workspacePadding: 8
    property color activeBorderColor: Colors.adapter.primary

    // Use the screen's monitor instead of focused monitor for multi-monitor support
    property var currentScreen: null  // This will be set from parent
    readonly property var monitor: {
        const foundMonitor = currentScreen ? Hyprland.monitorFor(currentScreen) : Hyprland.focusedMonitor;
        return foundMonitor;
    }
    readonly property int workspaceGroup: Math.floor((monitor?.activeWorkspace?.id - 1 || 0) / workspacesShown)
    readonly property var windowList: HyprlandData.windowList
    readonly property var windowByAddress: HyprlandData.windowByAddress
    readonly property var monitors: HyprlandData.monitors
    readonly property var monitorData: {
        const found = monitors.find(m => m.id === monitor?.id);
        return found;
    }
    readonly property var toplevels: ToplevelManager.toplevels

    readonly property string barPosition: Config.bar.position
    readonly property int barReserved: (Config.bar.showBackground ? 44 : 40)

    property real workspaceImplicitWidth: {
        const isRotated = (monitorData?.transform % 2 === 1);
        const monitorScale = monitorData?.scale || 1.0;  // Use monitor's scale, not config scale
        const width = isRotated ? (monitor?.height || 1920) : (monitor?.width || 1920);
        let scaledWidth = (width / monitorScale) * scale;  // Apply monitor scale then config scale
        if (barPosition === "left" || barPosition === "right") {
            // Substraer la zona reservada de la barra en orientación horizontal
            scaledWidth -= barReserved * scale;
        }
        return Math.max(0, scaledWidth);
    }
    property real workspaceImplicitHeight: {
        const isRotated = (monitorData?.transform % 2 === 1);
        const monitorScale = monitorData?.scale || 1.0;  // Use monitor's scale, not config scale
        const height = isRotated ? (monitor?.width || 1080) : (monitor?.height || 1080);
        let scaledHeight = (height / monitorScale) * scale;  // Apply monitor scale then config scale
        if (barPosition === "top" || barPosition === "bottom") {
            // Substraer la zona reservada de la barra en orientación vertical
            scaledHeight -= barReserved * scale;
        }
        return Math.max(0, scaledHeight);
    }

    property int draggingFromWorkspace: -1
    property int draggingTargetWorkspace: -1

    implicitWidth: overviewBackground.implicitWidth
    implicitHeight: overviewBackground.implicitHeight

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            // Find any window in the current workspace and focus it
            let currentWorkspace = monitor?.activeWorkspace?.id;
            if (currentWorkspace) {
                // Find a window in the current workspace
                let windowInWorkspace = windowList.find(win => win?.workspace?.id === currentWorkspace && monitor?.id === win.monitor);

                Visibilities.setActiveModule("");

                // Use the same focus restoration pattern as double-click
                if (windowInWorkspace) {
                    Qt.callLater(() => {
                        Hyprland.dispatch(`focuswindow address:${windowInWorkspace.address}`);
                    });
                }
            } else {
                Visibilities.setActiveModule("");
            }
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

        implicitWidth: workspaceColumnLayout.implicitWidth + workspaceSpacing * 2
        implicitHeight: workspaceColumnLayout.implicitHeight + workspaceSpacing * 2
        radius: Config.roundness > 0 ? Config.roundness + 4 : 0
        color: Colors.surface

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
                            property color hoveredWorkspaceColor: Colors.surfaceContainer
                            property color hoveredBorderColor: Colors.adapter.outline
                            property bool hoveredWhileDragging: false

                            implicitWidth: overviewRoot.workspaceImplicitWidth + workspacePadding
                            implicitHeight: overviewRoot.workspaceImplicitHeight + workspacePadding
                            color: hoveredWhileDragging ? hoveredWorkspaceColor : defaultWorkspaceColor
                            radius: Math.max(0, Config.roundness - workspaceSpacing + 4)
                            border.width: 2
                            border.color: hoveredWhileDragging ? hoveredBorderColor : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: workspaceValue
                                font.pixelSize: Math.min(parent.width, parent.height) * 0.25
                                font.weight: Font.Bold
                                color: Colors.surfaceBright
                                opacity: 1
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton
                                onClicked: {
                                    if (overviewRoot.draggingTargetWorkspace === -1) {
                                        // Only switch workspace, don't close overview
                                        Hyprland.dispatch(`workspace ${workspaceValue}`);
                                    }
                                }
                                onDoubleClicked: {
                                    if (overviewRoot.draggingTargetWorkspace === -1) {
                                        // Double click closes overview and switches workspace
                                        Visibilities.setActiveModule("");
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
                model: ScriptModel {
                    values: {
                        const filteredWindows = overviewRoot.windowList.filter(win => {
                            const inWorkspaceGroup = (overviewRoot.workspaceGroup * overviewRoot.workspacesShown < win?.workspace?.id && win?.workspace?.id <= (overviewRoot.workspaceGroup + 1) * overviewRoot.workspacesShown);
                            const inMonitor = overviewRoot.monitor?.id === win.monitor;
                            return inWorkspaceGroup && inMonitor;
                        });

                        return filteredWindows.map(win => {
                            const toplevel = ToplevelManager.toplevels.values.find(t => `0x${t.HyprlandToplevel.address}` === win.address);
                            return {
                                windowData: win,
                                toplevel: toplevel || null
                            };
                        });
                    }
                }

                delegate: OverviewWindow {
                    id: window
                    required property var modelData
                    windowData: modelData.windowData
                    toplevel: modelData.toplevel
                    scale: overviewRoot.scale
                    availableWorkspaceWidth: overviewRoot.workspaceImplicitWidth
                    availableWorkspaceHeight: overviewRoot.workspaceImplicitHeight
                    monitorData: overviewRoot.monitorData
                    barPosition: overviewRoot.barPosition
                    barReserved: overviewRoot.barReserved

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
                        // Close overview and focus the specific clicked window
                        // Skip generic focus restoration since we're handling it specifically
                        Visibilities.setActiveModule("", true);
                        Qt.callLater(() => {
                            Hyprland.dispatch(`focuswindow address:${windowData.address}`);
                        });
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
                radius: Math.max(0, Config.roundness - workspaceSpacing + 4)
                border.width: 2
                border.color: overviewRoot.activeBorderColor

                Behavior on x {
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                }
                Behavior on y {
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                }
            }
        }
    }
}
