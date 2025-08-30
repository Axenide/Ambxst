import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.globals
import qs.modules.services
import qs.modules.widgets.overview
import qs.modules.notch
import qs.modules.widgets.wallpapers
import qs.config

NotchAnimationBehavior {
    id: root

    property var state: QtObject {
        property int currentTab: 0
    }

    readonly property var tabModel: ["Widgets", "Pins", "Kanban", "Wallpapers"]
    readonly property int tabCount: tabModel.length
    readonly property int tabSpacing: 8

    readonly property real nonAnimWidth: 400 + viewWrapper.anchors.margins * 2

    implicitWidth: nonAnimWidth
    implicitHeight: mainLayout.implicitHeight

    // Usar el comportamiento estándar de animaciones del notch
    isVisible: GlobalStates.dashboardOpen

    Column {
        id: mainLayout
        anchors.fill: parent
        spacing: 8

        // Tab buttons
        Item {
            id: tabsContainer
            width: parent.width
            height: 32

            // Background highlight que se desplaza
            Rectangle {
                id: tabHighlight
                width: (parent.width - root.tabSpacing * (root.tabCount - 1)) / root.tabCount
                height: parent.height
                x: root.state.currentTab * (width + root.tabSpacing)
                y: 0
                color: Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, Config.opacity)
                radius: Config.roundness > 0 ? Config.roundness + 4 : 0
                z: 0

                Behavior on x {
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                }
            }

            Row {
                id: tabs
                anchors.fill: parent
                spacing: root.tabSpacing

                Repeater {
                    model: root.tabModel

                    Button {
                        required property int index
                        required property string modelData

                        text: modelData
                        flat: true
                        implicitWidth: (tabsContainer.width - root.tabSpacing * (root.tabCount - 1)) / root.tabCount
                        height: tabsContainer.height

                        background: Rectangle {
                            color: "transparent"
                            radius: Config.roundness > 0 ? Config.roundness + 4 : 0
                        }

                        contentItem: Text {
                            text: parent.text
                            color: root.state.currentTab === index ? Colors.adapter.primary : Colors.adapter.overBackground
                            font.family: Config.theme.font
                            font.pixelSize: Config.theme.fontSize
                            font.weight: Font.Medium
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter

                            Behavior on color {
                                ColorAnimation {
                                    duration: Config.animDuration
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        onClicked: root.state.currentTab = index

                        Behavior on scale {
                            NumberAnimation {
                                duration: Config.animDuration / 3
                                easing.type: Easing.OutCubic
                            }
                        }

                        states: State {
                            name: "pressed"
                            when: parent.pressed
                            PropertyChanges {
                                target: parent
                                scale: 0.95
                            }
                        }
                    }
                }
            }
        }

        // Content area
        PaneRect {
            id: viewWrapper

            width: parent.width
            height: parent.height - tabs.height - 8 // Adjust height to fit below tabs

            radius: Config.roundness > 0 ? Config.roundness + 4 : 0
            clip: true

            SwipeView {
                id: view

                anchors.fill: parent

                currentIndex: root.state.currentTab

                onCurrentIndexChanged: {
                    root.state.currentTab = currentIndex;
                    // Auto-focus search input when switching to wallpapers tab
                    if (currentIndex === 3) {
                        Qt.callLater(() => {
                            if (wallpapersPane.item && wallpapersPane.item.focusSearch) {
                                wallpapersPane.item.focusSearch();
                            }
                        });
                    }
                }

                // Overview Tab
                DashboardPane {
                    sourceComponent: overviewComponent
                }

                // System Tab
                DashboardPane {
                    sourceComponent: systemComponent
                }

                // Quick Settings Tab
                DashboardPane {
                    sourceComponent: quickSettingsComponent
                }

                // Wallpapers Tab
                DashboardPane {
                    id: wallpapersPane
                    sourceComponent: wallpapersComponent
                }
            }
        }
    }

    // Animated size properties for smooth transitions
    property real animatedWidth: implicitWidth
    property real animatedHeight: implicitHeight

    width: animatedWidth
    height: animatedHeight

    // Update animated properties when implicit properties change
    onImplicitWidthChanged: animatedWidth = implicitWidth
    onImplicitHeightChanged: animatedHeight = implicitHeight

    Behavior on animatedWidth {
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutBack
            easing.overshoot: 1.1
        }
    }

    Behavior on animatedHeight {
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutBack
            easing.overshoot: 1.1
        }
    }

    // Component definitions for better performance (defined once, reused)
    Component {
        id: overviewComponent
        OverviewTab {}
    }

    Component {
        id: systemComponent
        SystemTab {}
    }

    Component {
        id: quickSettingsComponent
        QuickSettingsTab {}
    }

    Component {
        id: wallpapersComponent
        WallpapersTab {}
    }
}
