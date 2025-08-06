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
        active: isScreenFocused && (screenVisibilities.launcher || screenVisibilities.dashboard || screenVisibilities.overview)

        onCleared: {
            screenVisibilities.launcher = false;
            screenVisibilities.dashboard = false;
            screenVisibilities.overview = false;
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
                    if (screenVisibilities.dashboard) {
                        screenVisibilities.dashboard = false;
                        screenVisibilities.overview = true;
                    } else if (screenVisibilities.overview) {
                        screenVisibilities.overview = false;
                        screenVisibilities.launcher = true;
                    } else if (screenVisibilities.launcher) {
                        screenVisibilities.launcher = false;
                    } else {
                        screenVisibilities.dashboard = true;
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
                    screenVisibilities.launcher = false;
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        screenVisibilities.launcher = false;
                        event.accepted = true;
                    }
                }

                Component.onCompleted: {
                    clearSearch();
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
                        screenVisibilities.overview = false;
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
                        screenVisibilities.dashboard = false;
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
            shadowBlur: GlobalStates.getNotchOpen(screen.name) ? 2.0 : 1.0
            shadowColor: Colors.adapter.shadow
            shadowOpacity: GlobalStates.getNotchOpen(screen.name) ? 0.75 : 0.5

            Behavior on shadowBlur {
                NumberAnimation {
                    duration: Config.animDuration
                    easing.type: GlobalStates.getNotchOpen(screen.name) ? Easing.OutBack : Easing.OutQuart
                }
            }

            Behavior on shadowOpacity {
                NumberAnimation {
                    duration: Config.animDuration
                    easing.type: GlobalStates.getNotchOpen(screen.name) ? Easing.OutBack : Easing.OutQuart
                }
            }
        }

        defaultViewComponent: defaultViewComponent
        launcherViewComponent: launcherViewComponent
        dashboardViewComponent: dashboardViewComponent
        overviewViewComponent: overviewViewComponent

        // Handle global keyboard events
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape && (screenVisibilities.launcher || screenVisibilities.dashboard || screenVisibilities.overview)) {
                screenVisibilities.launcher = false;
                screenVisibilities.dashboard = false;
                screenVisibilities.overview = false;
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
                    notchPanel.activate();
                    notchPanel.forceActiveFocus();
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
                Qt.callLater(() => {
                    notchPanel.requestActivate();
                    notchPanel.forceActiveFocus();
                });
            } else {
                if (notchContainer.stackView.depth > 1) {
                    notchContainer.stackView.pop();
                }
            }
        }

        function onOverviewChanged() {
            if (screenVisibilities.overview) {
                notchContainer.stackView.push(overviewViewComponent);
                Qt.callLater(() => {
                    notchPanel.requestActivate();
                    notchPanel.forceActiveFocus();
                });
            } else {
                if (notchContainer.stackView.depth > 1) {
                    notchContainer.stackView.pop();
                }
            }
        }
    }
}
