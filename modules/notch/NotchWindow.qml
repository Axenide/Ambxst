import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.modules.globals
import qs.modules.theme
import qs.modules.launcher
import qs.config

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

    HyprlandFocusGrab {
        id: focusGrab
        windows: [notchPanel]
        active: GlobalStates.launcherOpen || GlobalStates.dashboardOpen

        onCleared: {
            GlobalStates.launcherOpen = false;
            GlobalStates.dashboardOpen = false;
        }
    }

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    mask: Region {
        item: notchContainer
    }

    // Default view component - user@host text
    Component {
        id: defaultViewComponent
        Item {
            width: userHostText.implicitWidth + 24
            height: 28

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
                    // Toggle dashboard - si ya está abierto, se cierra; si no, abre dashboard y cierra launcher
                    if (GlobalStates.dashboardOpen) {
                        GlobalStates.dashboardOpen = false;
                    } else {
                        GlobalStates.launcherOpen = false;
                        GlobalStates.dashboardOpen = true;
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: Configuration.animDuration / 2
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
                        duration: Configuration.animDuration / 2
                    }
                }
            }
        }
    }

    // Launcher view component
    Component {
        id: launcherViewComponent
        Item {
            width: 480
            height: Math.min(launcherSearch.implicitHeight, 368)

            LauncherSearch {
                id: launcherSearch
                anchors.fill: parent

                onItemSelected: {
                    GlobalStates.launcherOpen = false;
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        GlobalStates.launcherOpen = false;
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

    // Dashboard view component
    Component {
        id: dashboardViewComponent
        Item {
            width: 900
            height: 400

            Dashboard {
                id: dashboardItem
                anchors.fill: parent

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        GlobalStates.dashboardOpen = false;
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
            shadowBlur: GlobalStates.notchOpen ? 2.0 : 1.0
            shadowColor: Colors.adapter.shadow
            shadowOpacity: GlobalStates.notchOpen ? 0.75 : 0.5

            Behavior on shadowBlur {
                NumberAnimation {
                    duration: Configuration.animDuration - 50
                    easing.type: GlobalStates.notchOpen ? Easing.OutBack : Easing.OutQuart
                }
            }

            Behavior on shadowOpacity {
                NumberAnimation {
                    duration: Configuration.animDuration - 50
                    easing.type: GlobalStates.notchOpen ? Easing.OutBack : Easing.OutQuart
                }
            }
        }

        defaultViewComponent: defaultViewComponent
        launcherViewComponent: launcherViewComponent
        dashboardViewComponent: dashboardViewComponent

        // Handle global keyboard events
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape && (GlobalStates.launcherOpen || GlobalStates.dashboardOpen)) {
                GlobalStates.launcherOpen = false;
                GlobalStates.dashboardOpen = false;
                event.accepted = true;
            }
        }
    }

    // Listen for launcher and dashboard state changes
    Connections {
        target: GlobalStates
        function onLauncherOpenChanged() {
            if (GlobalStates.launcherOpen) {
                notchContainer.stackView.push(launcherViewComponent);
                Qt.callLater(() => {
                    notchPanel.requestActivate();
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

        function onDashboardOpenChanged() {
            if (GlobalStates.dashboardOpen) {
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
    }
}
