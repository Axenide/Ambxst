import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.modules.globals
import qs.modules.theme
import qs.modules.launcher
import qs.modules.services
import qs.config
import "./overview"

PanelWindow {
    id: notchPanel

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"

    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // Get this screen's visibility state
    readonly property var screenVisibilities: Visibilities.getForScreen(screen.name)
    readonly property bool isScreenFocused: Hyprland.focusedMonitor && Hyprland.focusedMonitor.name === screen.name

    HyprlandFocusGrab {
        id: focusGrab
        windows: [notchPanel]
        active: screenVisibilities.launcher || screenVisibilities.dashboard || screenVisibilities.overview

        onCleared: {
            Visibilities.setActiveModule("");
        }
    }

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    mask: Region {
        item: notchContainer
    }

    Component.onCompleted: {
        Visibilities.registerPanel(screen.name, notchPanel);
    }

    Component.onDestruction: {
        Visibilities.unregisterPanel(screen.name);
    }

    // Default view component - user@host text
    Component {
        id: defaultViewComponent
        Item {
            implicitWidth: userHostText.implicitWidth
            implicitHeight: userHostText.implicitHeight
            Process {
                id: hostnameProcess
                command: ["hostname"]
                running: true

                stdout: StdioCollector {
                    id: hostnameCollector
                    waitForEnd: true

                    onStreamFinished: {}
                }
            }

            MouseArea {
                id: userHostArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: {
                    // Cycle through views: default -> dashboard -> overview -> launcher -> default
                    if (Visibilities.currentActiveModule === "dashboard") {
                        Visibilities.setActiveModule("overview");
                    } else if (Visibilities.currentActiveModule === "overview") {
                        Visibilities.setActiveModule("launcher");
                    } else if (Visibilities.currentActiveModule === "launcher") {
                        Visibilities.setActiveModule("");
                    } else {
                        Visibilities.setActiveModule("dashboard");
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: Config.animDuration / 2
                        }
                    }
                }
            }

            Text {
                id: userHostText
                anchors.centerIn: parent
                text: `${Quickshell.env("USER")}@${hostnameCollector.text.trim()}`
                color: userHostArea.pressed ? Colors.adapter.overBackground : (userHostArea.containsMouse ? Colors.adapter.primary : Colors.adapter.overBackground)
                font.family: Styling.defaultFont
                font.pixelSize: 14
                font.weight: Font.Bold

                Behavior on color {
                    ColorAnimation {
                        duration: Config.animDuration / 2
                    }
                }
            }
        }
    }

    // Launcher view component
    Component {
        id: launcherViewComponent
        Item {
            implicitWidth: 480
            implicitHeight: Math.min(launcherSearch.implicitHeight, 368)

            LauncherSearch {
                id: launcherSearch
                anchors.fill: parent

                onItemSelected: {
                    GlobalStates.clearLauncherState();
                    Visibilities.setActiveModule("");
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        GlobalStates.clearLauncherState();
                        Visibilities.setActiveModule("");
                        event.accepted = true;
                    }
                }

                Component.onCompleted: {
                    Qt.callLater(() => {
                        focusSearchInput();
                    });
                }
            }
        }
    }

    // Overview view component
    Component {
        id: overviewViewComponent
        Item {
            implicitWidth: overviewItem.implicitWidth
            implicitHeight: overviewItem.implicitHeight

            Overview {
                id: overviewItem
                anchors.centerIn: parent

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        Visibilities.setActiveModule("");
                        event.accepted = true;
                    }
                }

                Component.onCompleted: {
                    Qt.callLater(() => {
                        forceActiveFocus();
                    });
                }
            }
        }
    }

    // Dashboard view component
    Component {
        id: dashboardViewComponent
        Item {
            implicitWidth: 900
            implicitHeight: 400

            Dashboard {
                id: dashboardItem
                anchors.fill: parent

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        Visibilities.setActiveModule("");
                        event.accepted = true;
                    }
                }

                Component.onCompleted: {
                    Qt.callLater(() => {
                        forceActiveFocus();
                    });
                }
            }
        }
    }

    // Center notch
    Notch {
        id: notchContainer
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
            shadowBlur: screenVisibilities && (screenVisibilities.launcher || screenVisibilities.dashboard || screenVisibilities.overview) ? 2.0 : 1.0
            shadowColor: Colors.adapter.shadow
            shadowOpacity: screenVisibilities && (screenVisibilities.launcher || screenVisibilities.dashboard || screenVisibilities.overview) ? 0.75 : 0.5

            Behavior on shadowBlur {
                NumberAnimation {
                    duration: Config.animDuration
                    easing.type: screenVisibilities && (screenVisibilities.launcher || screenVisibilities.dashboard || screenVisibilities.overview) ? Easing.OutBack : Easing.OutQuart
                }
            }

            Behavior on shadowOpacity {
                NumberAnimation {
                    duration: Config.animDuration
                    easing.type: screenVisibilities && (screenVisibilities.launcher || screenVisibilities.dashboard || screenVisibilities.overview) ? Easing.OutBack : Easing.OutQuart
                }
            }
        }

        defaultViewComponent: defaultViewComponent
        launcherViewComponent: launcherViewComponent
        dashboardViewComponent: dashboardViewComponent
        overviewViewComponent: overviewViewComponent
        visibilities: screenVisibilities

        // Handle global keyboard events
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape && (screenVisibilities.launcher || screenVisibilities.dashboard || screenVisibilities.overview)) {
                Visibilities.setActiveModule("");
                event.accepted = true;
            }
        }
    }

    // Listen for launcher, dashboard and overview state changes
    Connections {
        target: screenVisibilities
        function onLauncherChanged() {
            if (screenVisibilities.launcher) {
                notchContainer.stackView.push(launcherViewComponent);
                Qt.callLater(() => {
                    // Additional focus to ensure search input gets focus
                    let currentItem = notchContainer.stackView.currentItem;
                    if (currentItem && currentItem.children[0] && currentItem.children[0].focusSearchInput) {
                        currentItem.children[0].focusSearchInput();
                    }
                });
            } else {
                if (notchContainer.stackView.depth > 1) {
                    notchContainer.stackView.pop();
                }
            }
        }

        function onDashboardChanged() {
            if (screenVisibilities.dashboard) {
                notchContainer.stackView.push(dashboardViewComponent);
            } else {
                if (notchContainer.stackView.depth > 1) {
                    notchContainer.stackView.pop();
                }
            }
        }

        function onOverviewChanged() {
            if (screenVisibilities.overview) {
                notchContainer.stackView.push(overviewViewComponent);
            } else {
                if (notchContainer.stackView.depth > 1) {
                    notchContainer.stackView.pop();
                }
            }
        }
    }
}
