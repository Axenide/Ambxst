import QtQuick
import QtQuick.Controls
import qs.modules.theme
import qs.modules.components
import qs.modules.globals
import qs.modules.services
import qs.config

Rectangle {
    color: Colors.background
    anchors.fill: parent
    anchors.margins: 4
    radius: Config.roundness > 0 ? Config.roundness : 0

    property string searchText: ""
    readonly property int gridColumns: 3

    function focusSearch() {
        wallpaperSearchInput.focusInput();
    }

    Component.onCompleted: {
        Qt.callLater(() => {
            focusSearch();
        });
    }

    property var filteredWallpapers: {
        if (!GlobalStates.wallpaperManager)
            return [];
        if (searchText.length === 0)
            return GlobalStates.wallpaperManager.wallpaperPaths;

        return GlobalStates.wallpaperManager.wallpaperPaths.filter(function (path) {
            const fileName = path.split('/').pop().toLowerCase();
            return fileName.includes(searchText.toLowerCase());
        });
    }

    Row {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        // Sidebar izquierdo con search y opciones
        Column {
            width: parent.width - wallpaperGridContainer.width - 8  // Expandir para llenar el espacio restante
            height: parent.height + 4
            spacing: 8

            // Barra de búsqueda
            SearchInput {
                id: wallpaperSearchInput
                width: parent.width
                text: searchText
                placeholderText: "Search wallpapers..."
                iconText: ""
                clearOnEscape: false
                radius: Config.roundness > 0 ? Config.roundness - 8 : 0

                onSearchTextChanged: text => {
                    searchText = text;
                }

                onEscapePressed: {
                    Visibilities.setActiveModule("");
                }
            }

            // Área placeholder para opciones futuras
            Rectangle {
                width: parent.width
                height: parent.height - 36 - 16
                color: Colors.surfaceContainer
                radius: Config.roundness > 0 ? Config.roundness : 0
                border.color: Colors.adapter.outline
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "Placeholder\nfor future\noptions"
                    color: Colors.adapter.overSurfaceVariant
                    font.family: Styling.defaultFont
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    lineHeight: 1.2
                }
            }
        }

        // Grid de wallpapers a la derecha
        Rectangle {
            id: wallpaperGridContainer
            width: wallpaperGridContainer.height
            height: parent.height
            color: Colors.surfaceContainer
            radius: Config.roundness > 0 ? Config.roundness : 0
            border.color: Colors.adapter.outline
            border.width: 0
            clip: true

            readonly property int wallpaperHeight: height / 3  // 1/3 de la altura del contenedor
            readonly property int wallpaperWidth: wallpaperHeight  // Mantener cuadrados

            ScrollView {
                id: scrollView
                anchors.fill: parent

                GridView {
                    id: wallpaperGrid
                    width: parent.width
                    cellWidth: wallpaperGridContainer.wallpaperWidth
                    cellHeight: wallpaperGridContainer.wallpaperHeight
                    model: filteredWallpapers

                    delegate: Rectangle {
                        width: wallpaperGridContainer.wallpaperWidth
                        height: wallpaperGridContainer.wallpaperHeight
                        color: Colors.surface
                        border.color: isCurrentWallpaper ? Colors.adapter.primary : "transparent"
                        border.width: isCurrentWallpaper ? 2 : 0

                        property bool isCurrentWallpaper: {
                            if (!GlobalStates.wallpaperManager)
                                return false;
                            return GlobalStates.wallpaperManager.currentWallpaper === modelData;
                        }

                        Behavior on border.color {
                            ColorAnimation {
                                duration: Config.animDuration
                                easing.type: Easing.OutCubic
                            }
                        }

                        Image {
                            anchors.fill: parent
                            source: "file://" + modelData
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            smooth: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onEntered: {
                                if (!parent.isCurrentWallpaper) {
                                    parent.color = Colors.surfaceContainerHigh;
                                }
                            }
                            onExited: {
                                if (!parent.isCurrentWallpaper) {
                                    parent.color = Colors.surface;
                                }
                            }
                            onPressed: parent.scale = 0.95
                            onReleased: parent.scale = 1.0

                            onClicked: {
                                if (GlobalStates.wallpaperManager) {
                                    GlobalStates.wallpaperManager.setWallpaper(modelData);
                                }
                            }
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Config.animDuration / 2
                                easing.type: Easing.OutCubic
                            }
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: Config.animDuration / 3
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }
        }
    }
}
