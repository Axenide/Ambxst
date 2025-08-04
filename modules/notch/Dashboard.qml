import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.globals
import qs.config

Item {
    id: root

    property var state: QtObject {
        property int currentTab: 0
    }

    readonly property real nonAnimWidth: 400 + viewWrapper.anchors.margins * 2

    implicitWidth: nonAnimWidth
    implicitHeight: mainLayout.implicitHeight

    Column {
        id: mainLayout
        anchors.fill: parent
        spacing: 8

        // Tab buttons
        Row {
            id: tabs

            width: parent.width
            spacing: 8

            Repeater {
                model: ["Widgets", "Pins", "Kanban", "Wallpapers"]

                Button {
                    required property int index
                    required property string modelData

                    text: modelData
                    flat: true
                    implicitWidth: (tabs.width - tabs.spacing * 3) / 4

                    background: Rectangle {
                        color: root.state.currentTab === index ? Colors.adapter.surfaceContainer : "transparent"
                        radius: Configuration.roundness > 0 ? Configuration.roundness + 4 : 0

                        Behavior on color {
                            ColorAnimation {
                                duration: Configuration.animDuration - 100
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    contentItem: Text {
                        text: parent.text
                        color: root.state.currentTab === index ? Colors.adapter.primary : Colors.adapter.overBackground
                        font.family: Styling.defaultFont
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter

                        Behavior on color {
                            ColorAnimation {
                                duration: Configuration.animDuration - 100
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    onClicked: root.state.currentTab = index

                    Behavior on scale {
                        NumberAnimation {
                            duration: Configuration.animDuration / 3
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

        // Content area
        Rectangle {
            id: viewWrapper

            width: parent.width
            height: parent.height - tabs.height - 8 // Adjust height to fit below tabs

            radius: Configuration.roundness > 0 ? Configuration.roundness + 4 : 0
            color: Colors.adapter.surfaceContainer
            clip: true

            layer.enabled: true
            layer.samples: 4

            SwipeView {
                id: view

                anchors.fill: parent

                currentIndex: root.state.currentTab

                onCurrentIndexChanged: {
                    root.state.currentTab = currentIndex;
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
            duration: Configuration.animDuration + 100
            easing.type: Easing.OutBack
            easing.overshoot: 1.1
        }
    }

    Behavior on animatedHeight {
        NumberAnimation {
            duration: Configuration.animDuration + 100
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

    component DashboardPane: Item {
        implicitWidth: 400
        implicitHeight: 300

        property alias sourceComponent: loader.sourceComponent

        Loader {
            id: loader
            anchors.fill: parent
            active: true // Simplificamos: siempre cargar para debugging
        }
    }

    component OverviewTab: Rectangle {
        color: "transparent"
        implicitWidth: 400
        implicitHeight: 300

        Text {
            anchors.centerIn: parent
            text: "Widgets"
            color: Colors.adapter.overSurfaceVariant
            font.family: Styling.defaultFont
            font.pixelSize: 16
            font.weight: Font.Medium
        }
    }

    component SystemTab: Rectangle {
        color: "transparent"
        implicitWidth: 400
        implicitHeight: 300

        Text {
            anchors.centerIn: parent
            text: "Pins"
            color: Colors.adapter.overSurfaceVariant
            font.family: Styling.defaultFont
            font.pixelSize: 16
            font.weight: Font.Medium
        }
    }

    component QuickSettingsTab: Rectangle {
        color: "transparent"
        implicitWidth: 400
        implicitHeight: 300

        Text {
            anchors.centerIn: parent
            text: "Kanban"
            color: Colors.adapter.overSurfaceVariant
            font.family: Styling.defaultFont
            font.pixelSize: 16
            font.weight: Font.Medium
        }
    }

    component WallpapersTab: Rectangle {
        color: "transparent"
        implicitWidth: 400
        implicitHeight: 300

        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            Text {
                text: "Wallpapers"
                color: Colors.adapter.overSurface
                font.family: Styling.defaultFont
                font.pixelSize: 16
                font.weight: Font.Bold
            }

            ScrollView {
                width: parent.width
                height: parent.height - parent.children[0].height - parent.spacing

                GridView {
                    id: wallpaperGrid
                    cellWidth: 120
                    cellHeight: 90
                    model: GlobalStates.wallpaperManager ? GlobalStates.wallpaperManager.wallpaperPaths : []

                    delegate: Rectangle {
                        width: wallpaperGrid.cellWidth - 8
                        height: wallpaperGrid.cellHeight - 8
                        radius: 8
                        color: Colors.adapter.surface
                        border.color: isCurrentWallpaper ? Colors.adapter.primary : Colors.adapter.outline
                        border.width: isCurrentWallpaper ? 2 : 1

                        property bool isCurrentWallpaper: GlobalStates.wallpaperManager && GlobalStates.wallpaperManager.currentIndex === index

                        Behavior on border.color {
                            ColorAnimation {
                                duration: Configuration.animDuration - 100
                                easing.type: Easing.OutCubic
                            }
                        }

                        Image {
                            anchors.fill: parent
                            anchors.margins: 4
                            source: "file://" + modelData
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            smooth: true
                            clip: true

                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                radius: 4
                                border.color: parent.parent.isCurrentWallpaper ? Colors.adapter.primary : "transparent"
                                border.width: 1
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onEntered: {
                                if (!parent.isCurrentWallpaper) {
                                    parent.color = Colors.adapter.surfaceContainerHigh;
                                }
                            }
                            onExited: {
                                if (!parent.isCurrentWallpaper) {
                                    parent.color = Colors.adapter.surface;
                                }
                            }
                            onPressed: parent.scale = 0.95
                            onReleased: parent.scale = 1.0

                            onClicked: {
                                if (GlobalStates.wallpaperManager) {
                                    GlobalStates.wallpaperManager.setWallpaperByIndex(index);
                                }
                            }
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Configuration.animDuration / 2
                                easing.type: Easing.OutCubic
                            }
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: Configuration.animDuration / 3
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }
        }
    }
}
