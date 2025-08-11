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
    readonly property int gridRows: 3
    readonly property int gridColumns: 5
    property int selectedIndex: GlobalStates.wallpaperSelectedIndex
    property bool navigationInProgress: false

    // Timer para limitar la velocidad de navegación
    Timer {
        id: navigationTimer
        interval: Config.animDuration / 2
        onTriggered: navigationInProgress = false
    }

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
                    // Auto-highlight first wallpaper when text is entered
                    if (text.length > 0 && filteredWallpapers.length > 0) {
                        GlobalStates.wallpaperSelectedIndex = 0;
                        selectedIndex = 0;
                        wallpaperGrid.currentIndex = 0;
                    } else {
                        GlobalStates.wallpaperSelectedIndex = -1;
                        selectedIndex = -1;
                        wallpaperGrid.currentIndex = -1;
                    }
                }

                onEscapePressed: {
                    Visibilities.setActiveModule("");
                }

                onDownPressed: {
                    if (filteredWallpapers.length > 0 && !navigationInProgress) {
                        navigationInProgress = true;
                        navigationTimer.restart();
                        
                        if (selectedIndex < filteredWallpapers.length - 1) {
                            let newIndex = selectedIndex + gridColumns;
                            if (newIndex >= filteredWallpapers.length) {
                                newIndex = filteredWallpapers.length - 1;
                            }
                            GlobalStates.wallpaperSelectedIndex = newIndex;
                            selectedIndex = newIndex;
                            wallpaperGrid.currentIndex = newIndex;
                        } else if (selectedIndex === -1) {
                            GlobalStates.wallpaperSelectedIndex = 0;
                            selectedIndex = 0;
                            wallpaperGrid.currentIndex = 0;
                        }
                    }
                }

                onUpPressed: {
                    if (filteredWallpapers.length > 0 && selectedIndex > 0 && !navigationInProgress) {
                        navigationInProgress = true;
                        navigationTimer.restart();
                        
                        let newIndex = selectedIndex - gridColumns;
                        if (newIndex < 0) {
                            newIndex = 0;
                        }
                        GlobalStates.wallpaperSelectedIndex = newIndex;
                        selectedIndex = newIndex;
                        wallpaperGrid.currentIndex = newIndex;
                    } else if (selectedIndex === 0 && searchText.length === 0 && !navigationInProgress) {
                        navigationInProgress = true;
                        navigationTimer.restart();
                        
                        GlobalStates.wallpaperSelectedIndex = -1;
                        selectedIndex = -1;
                        wallpaperGrid.currentIndex = -1;
                    }
                }

                onAccepted: {
                    if (selectedIndex >= 0 && selectedIndex < filteredWallpapers.length) {
                        let selectedWallpaper = filteredWallpapers[selectedIndex];
                        if (selectedWallpaper && GlobalStates.wallpaperManager) {
                            GlobalStates.wallpaperManager.setWallpaper(selectedWallpaper);
                        }
                    }
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Left && filteredWallpapers.length > 0 && !navigationInProgress) {
                        navigationInProgress = true;
                        navigationTimer.restart();
                        
                        if (selectedIndex > 0) {
                            GlobalStates.wallpaperSelectedIndex = selectedIndex - 1;
                            selectedIndex = selectedIndex - 1;
                            wallpaperGrid.currentIndex = selectedIndex;
                        } else if (selectedIndex === -1) {
                            GlobalStates.wallpaperSelectedIndex = 0;
                            selectedIndex = 0;
                            wallpaperGrid.currentIndex = 0;
                        }
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Right && filteredWallpapers.length > 0 && !navigationInProgress) {
                        navigationInProgress = true;
                        navigationTimer.restart();
                        
                        if (selectedIndex < filteredWallpapers.length - 1) {
                            GlobalStates.wallpaperSelectedIndex = selectedIndex + 1;
                            selectedIndex = selectedIndex + 1;
                            wallpaperGrid.currentIndex = selectedIndex;
                        } else if (selectedIndex === -1) {
                            GlobalStates.wallpaperSelectedIndex = 0;
                            selectedIndex = 0;
                            wallpaperGrid.currentIndex = 0;
                        }
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Home && filteredWallpapers.length > 0 && !navigationInProgress) {
                        navigationInProgress = true;
                        navigationTimer.restart();
                        
                        GlobalStates.wallpaperSelectedIndex = 0;
                        selectedIndex = 0;
                        wallpaperGrid.currentIndex = 0;
                        event.accepted = true;
                    } else if (event.key === Qt.Key_End && filteredWallpapers.length > 0 && !navigationInProgress) {
                        navigationInProgress = true;
                        navigationTimer.restart();
                        
                        GlobalStates.wallpaperSelectedIndex = filteredWallpapers.length - 1;
                        selectedIndex = filteredWallpapers.length - 1;
                        wallpaperGrid.currentIndex = selectedIndex;
                        event.accepted = true;
                    }
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
                    font.family: Config.theme.font
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    lineHeight: 1.2
                }
            }
        }

        // Grid de wallpapers a la derecha
        Rectangle {
            id: wallpaperGridContainer
            width: wallpaperWidth * gridColumns
            height: parent.height
            color: Colors.surfaceContainer
            radius: Config.roundness > 0 ? Config.roundness : 0
            border.color: Colors.adapter.outline
            border.width: 0
            clip: true

            readonly property int wallpaperHeight: height / gridRows
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
                    currentIndex: selectedIndex

                    // Función para centrar el elemento seleccionado en el scroll
                    function centerCurrentItem() {
                        if (currentIndex >= 0 && currentIndex < count) {
                            // Calcular fila y posición Y del elemento actual
                            let currentRow = Math.floor(currentIndex / gridColumns);
                            let itemY = currentRow * cellHeight;
                            let itemCenterY = itemY + cellHeight / 2;

                            // Calcular posición ideal del scroll para centrar el elemento
                            let scrollViewHeight = scrollView.height;
                            let contentHeight = Math.ceil(count / gridColumns) * cellHeight;
                            let targetScrollY = itemCenterY - scrollViewHeight / 2;

                            // Asegurar que está dentro de los límites
                            targetScrollY = Math.max(0, Math.min(targetScrollY, contentHeight - scrollViewHeight));

                            // Aplicar el scroll con animación suave
                            if (contentHeight > scrollViewHeight) {
                                let normalizedPosition = targetScrollY / (contentHeight - scrollViewHeight);
                                scrollPositionAnimation.to = Math.max(0, Math.min(1, normalizedPosition));
                                scrollPositionAnimation.start();
                            }
                        }
                    }

                    // Animación para el scroll suave
                    NumberAnimation {
                        id: scrollPositionAnimation
                        target: scrollView.ScrollBar.vertical
                        property: "position"
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                    // Sincronizar currentIndex con selectedIndex
                    onCurrentIndexChanged: {
                        if (currentIndex !== selectedIndex) {
                            GlobalStates.wallpaperSelectedIndex = currentIndex;
                            selectedIndex = currentIndex;
                        }
                        // Centrar el elemento cuando cambie la selección
                        Qt.callLater(centerCurrentItem);
                    }

                    highlight: Rectangle {
                        color: "transparent"
                        border.color: Colors.adapter.primary
                        border.width: 2
                        visible: selectedIndex >= 0
                        z: 5

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

                    delegate: Rectangle {
                        width: wallpaperGridContainer.wallpaperWidth
                        height: wallpaperGridContainer.wallpaperHeight
                        color: Colors.surface

                        property bool isCurrentWallpaper: {
                            if (!GlobalStates.wallpaperManager)
                                return false;
                            return GlobalStates.wallpaperManager.currentWallpaper === modelData;
                        }

                        property bool isHovered: false
                        property bool isSelected: selectedIndex === index

                        Loader {
                            anchors.fill: parent
                            sourceComponent: {
                                if (!GlobalStates.wallpaperManager)
                                    return null;

                                var fileType = GlobalStates.wallpaperManager.getFileType(modelData);
                                if (fileType === 'image') {
                                    return staticImageComponent;
                                } else if (fileType === 'gif') {
                                    return animatedImageComponent;
                                }
                                return staticImageComponent; // fallback
                            }

                            property string sourceFile: modelData
                        }

                        // Highlight border para navegación por teclado
                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.color: Colors.adapter.primary
                            // border.width: 2
                            radius: 4
                            visible: parent.isSelected
                            z: 15

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Config.animDuration
                                    easing.type: Easing.OutQuart
                                }
                            }
                        }

                        // Etiqueta "CURRENT" para wallpaper actual
                        Rectangle {
                            visible: parent.isCurrentWallpaper
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 24
                            color: Colors.adapter.surfaceContainerLowest

                            Text {
                                anchors.centerIn: parent
                                text: "CURRENT"
                                color: Colors.adapter.primary
                                font.family: Config.theme.font
                                font.pixelSize: 14
                                font.weight: Font.Bold
                            }
                        }

                        Component {
                            id: staticImageComponent
                            Image {
                                source: parent.sourceFile ? "file://" + parent.sourceFile : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                smooth: true
                            }
                        }

                        Component {
                            id: animatedImageComponent
                            AnimatedImage {
                                source: parent.sourceFile ? "file://" + parent.sourceFile : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                smooth: true
                                playing: false  // Solo se anima al hacer hover
                            }
                        }

                        // Etiqueta con nombre del archivo al hacer hover o seleccionar
                        Rectangle {
                            visible: (parent.isHovered || parent.isSelected) && !parent.isCurrentWallpaper
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 24
                            color: Colors.adapter.surfaceContainerLowest
                            z: 10
                            clip: true

                            Text {
                                id: hoverText
                                anchors.verticalCenter: parent.verticalCenter
                                x: 4
                                text: modelData ? modelData.split('/').pop() : ""
                                color: Colors.adapter.overBackground
                                font.family: Config.theme.font
                                font.pixelSize: 14

                                readonly property bool needsScroll: width > parent.width - 8

                                SequentialAnimation {
                                    id: scrollAnimation
                                    // running: hoverText.needsScroll && parent.visible
                                    loops: Animation.Infinite

                                    PauseAnimation {
                                        duration: 1000
                                    }
                                    NumberAnimation {
                                        target: hoverText
                                        property: "x"
                                        to: hoverText.parent.width - hoverText.width - 4
                                        duration: 2000
                                        easing.type: Easing.InOutQuad
                                    }
                                    PauseAnimation {
                                        duration: 1000
                                    }
                                    NumberAnimation {
                                        target: hoverText
                                        property: "x"
                                        to: 4
                                        duration: 2000
                                        easing.type: Easing.InOutQuad
                                    }
                                }
                            }

                            onVisibleChanged: {
                                if (visible) {
                                    hoverText.x = 4;
                                    if (hoverText.needsScroll) {
                                        scrollAnimation.restart();
                                    }
                                } else {
                                    scrollAnimation.stop();
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onEntered: {
                                parent.isHovered = true;
                                // Sincronizar selección con hover
                                GlobalStates.wallpaperSelectedIndex = index;
                                selectedIndex = index;
                                wallpaperGrid.currentIndex = index;

                                if (!parent.isCurrentWallpaper) {
                                    parent.color = Colors.surfaceContainerHigh;
                                }
                                // Activar animación de GIF al hacer hover
                                var loader = parent.children[0]; // El Loader
                                if (loader && loader.item && loader.item.hasOwnProperty('playing')) {
                                    loader.item.playing = true;
                                }
                            }
                            onExited: {
                                parent.isHovered = false;
                                if (!parent.isCurrentWallpaper) {
                                    parent.color = Colors.surface;
                                }
                                // Desactivar animación de GIF al salir del hover
                                var loader = parent.children[0]; // El Loader
                                if (loader && loader.item && loader.item.hasOwnProperty('playing')) {
                                    loader.item.playing = false;
                                }
                            }
                            onPressed: parent.scale = 0.95
                            onReleased: parent.scale = 1.0

                            onClicked: {
                                // Aplicar wallpaper seleccionado
                                if (GlobalStates.wallpaperManager) {
                                    GlobalStates.wallpaperManager.setWallpaper(modelData);
                                }
                            }
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Config.animDuration
                                easing.type: Easing.OutCubic
                            }
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: Config.animDuration
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }
        }
    }
}
