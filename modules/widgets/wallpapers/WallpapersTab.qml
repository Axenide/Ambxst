import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.components
import qs.modules.globals
import qs.modules.services
import qs.config

// Componente principal para el selector de fondos de pantalla.
Rectangle {
    // Configuración de estilo y layout del componente.
    color: Colors.background
    radius: Config.roundness > 0 ? Config.roundness : 0

    // Propiedades personalizadas para la funcionalidad del componente.
    property string searchText: ""
    readonly property int gridRows: 3
    readonly property int gridColumns: 5
    property int selectedIndex: GlobalStates.wallpaperSelectedIndex

    // Función para enfocar el campo de búsqueda.
    function focusSearch() {
        wallpaperSearchInput.focusInput();
    }

    // Función para encontrar el índice del wallpaper actual en la lista filtrada
    function findCurrentWallpaperIndex() {
        if (!GlobalStates.wallpaperManager || !GlobalStates.wallpaperManager.currentWallpaper) {
            return -1;
        }

        const currentWallpaper = GlobalStates.wallpaperManager.currentWallpaper;
        return filteredWallpapers.indexOf(currentWallpaper);
    }

    // Llama a focusSearch una vez que el componente se ha completado.
    Component.onCompleted: {
        Qt.callLater(() => {
            // Primero intentar encontrar el wallpaper actual
            const currentIndex = findCurrentWallpaperIndex();
            if (currentIndex !== -1) {
                GlobalStates.wallpaperSelectedIndex = currentIndex;
                selectedIndex = currentIndex;
                wallpaperGrid.currentIndex = currentIndex;
                // Posicionar la vista en el wallpaper actual
                wallpaperGrid.positionViewAtIndex(currentIndex, GridView.Center);
            }

            focusSearch();
        });
    }

    // Propiedad calculada que filtra los fondos de pantalla según el texto de búsqueda.
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

    // Layout principal con una fila para la barra lateral y la cuadrícula.
    Row {
        anchors.fill: parent
        spacing: 8

        // Columna para el buscador y las opciones.
        Column {
            // El ancho se calcula dinámicamente para llenar el espacio.
            width: parent.width - wallpaperGridContainer.width - 8
            height: parent.height + 4
            spacing: 8

            // Barra de búsqueda.
            SearchInput {
                id: wallpaperSearchInput
                width: parent.width
                text: searchText
                placeholderText: "Search wallpapers..."
                iconText: ""
                clearOnEscape: false
                radius: Config.roundness > 0 ? Config.roundness : 0

                // Manejo de eventos de búsqueda y teclado.
                onSearchTextChanged: text => {
                    searchText = text;
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
                    if (filteredWallpapers.length > 0) {
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
                    if (filteredWallpapers.length > 0 && selectedIndex > 0) {
                        let newIndex = selectedIndex - gridColumns;
                        if (newIndex < 0) {
                            newIndex = 0;
                        }
                        GlobalStates.wallpaperSelectedIndex = newIndex;
                        selectedIndex = newIndex;
                        wallpaperGrid.currentIndex = newIndex;
                    } else if (selectedIndex === 0 && searchText.length === 0) {
                        GlobalStates.wallpaperSelectedIndex = -1;
                        selectedIndex = -1;
                        wallpaperGrid.currentIndex = -1;
                    }
                }
                onLeftPressed: {
                    if (filteredWallpapers.length > 0) {
                        if (selectedIndex > 0) {
                            GlobalStates.wallpaperSelectedIndex = selectedIndex - 1;
                            selectedIndex = selectedIndex - 1;
                            wallpaperGrid.currentIndex = selectedIndex;
                        } else if (selectedIndex === -1) {
                            GlobalStates.wallpaperSelectedIndex = 0;
                            selectedIndex = 0;
                            wallpaperGrid.currentIndex = 0;
                        }
                    }
                }
                onRightPressed: {
                    if (filteredWallpapers.length > 0) {
                        if (selectedIndex < filteredWallpapers.length - 1) {
                            GlobalStates.wallpaperSelectedIndex = selectedIndex + 1;
                            selectedIndex = selectedIndex + 1;
                            wallpaperGrid.currentIndex = selectedIndex;
                        } else if (selectedIndex === -1) {
                            GlobalStates.wallpaperSelectedIndex = 0;
                            selectedIndex = 0;
                            wallpaperGrid.currentIndex = 0;
                        }
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
            }

            // Área placeholder para opciones futuras.
            Rectangle {
                width: parent.width
                height: parent.height - wallpaperSearchInput.height - 12
                color: Colors.surface
                radius: Config.roundness > 0 ? Config.roundness : 0
                border.color: Colors.adapter.outline
                border.width: 0

                Text {
                    anchors.centerIn: parent
                    text: "Placeholder\nfor future\noptions"
                    color: Colors.adapter.overSurfaceVariant
                    font.family: Config.theme.font
                    font.pixelSize: Config.theme.fontSize
                    horizontalAlignment: Text.AlignHCenter
                    lineHeight: 1.2
                }
            }
        }

        // Contenedor para la cuadrícula de fondos de pantalla.
        Rectangle {
            id: wallpaperGridContainer
            width: wallpaperHeight * gridColumns
            height: parent.height
            color: "transparent"
            radius: Config.roundness > 0 ? Config.roundness : 0
            border.color: Colors.adapter.outline
            border.width: 0
            clip: true

            readonly property int wallpaperHeight: (height + wallpaperMargin) / gridRows
            readonly property int wallpaperWidth: (width + wallpaperMargin) / gridColumns
            readonly property int wallpaperMargin: 4

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

                    // Optimizaciones de rendimiento
                    cacheBuffer: cellHeight * 2 // Cachear 2 filas extra para scroll suave
                    displayMarginBeginning: cellHeight // Margen para precargar elementos
                    displayMarginEnd: cellHeight
                    reuseItems: true // Reutilizar elementos del delegado

                    // Configuración de scroll optimizada
                    flickDeceleration: 5000
                    maximumFlickVelocity: 8000

                    // Sincronizar currentIndex con selectedIndex
                    onCurrentIndexChanged: {
                        if (currentIndex !== selectedIndex) {
                            GlobalStates.wallpaperSelectedIndex = currentIndex;
                            selectedIndex = currentIndex;
                        }
                    }

                    // Optimización: Actualizar visibilidad cuando cambia el scroll
                    onContentYChanged:
                    // Forzar actualización de isInViewport en elementos cercanos
                    // QML manejará automáticamente la re-evaluación de las propiedades
                    {}

                    // Elemento de realce para el wallpaper seleccionado.
                    highlight: Item {
                        width: wallpaperGridContainer.wallpaperWidth
                        height: wallpaperGridContainer.wallpaperHeight
                        z: 100

                        Behavior on x {
                            NumberAnimation {
                                duration: Config.animDuration / 2
                                easing.type: Easing.OutQuart
                            }
                        }

                        Behavior on y {
                            NumberAnimation {
                                duration: Config.animDuration / 2
                                easing.type: Easing.OutQuart
                            }
                        }

                        ClippingRectangle {
                            id: highlightRectangle
                            anchors.centerIn: parent
                            width: parent.width - wallpaperGridContainer.wallpaperMargin * 2
                            height: parent.height - wallpaperGridContainer.wallpaperMargin * 2
                            color: "transparent"
                            border.color: Colors.adapter.primary
                            border.width: 2
                            visible: selectedIndex >= 0
                            radius: Config.roundness > 0 ? Config.roundness : 0
                            z: 10

                            // Borde interior original
                            Rectangle {
                                anchors.fill: parent
                                anchors.topMargin: -20
                                anchors.bottomMargin: 0
                                anchors.leftMargin: -20
                                anchors.rightMargin: -20
                                color: "transparent"
                                border.color: Colors.background
                                border.width: 28
                                radius: Config.roundness > 0 ? Config.roundness + 20 : 0
                                z: 5

                                // Etiqueta unificada que se anima con el highlight
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottomMargin: 0
                                    height: 28
                                    // color: Colors.background
                                    color: "transparent"
                                    z: 6
                                    clip: true

                                    property var currentItem: wallpaperGrid.currentItem
                                    property bool isCurrentWallpaper: {
                                        if (!GlobalStates.wallpaperManager || wallpaperGrid.currentIndex < 0)
                                            return false;
                                        return GlobalStates.wallpaperManager.currentWallpaper === filteredWallpapers[wallpaperGrid.currentIndex];
                                    }
                                    property bool showHoveredItem: currentItem && currentItem.isHovered && !visible

                                    visible: selectedIndex >= 0 || showHoveredItem

                                    Text {
                                        id: labelText
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.horizontalCenter: needsScroll ? undefined : parent.horizontalCenter
                                        x: needsScroll ? 4 : undefined
                                        text: {
                                            if (parent.isCurrentWallpaper) {
                                                return "CURRENT";
                                            } else if (wallpaperGrid.currentIndex >= 0 && wallpaperGrid.currentIndex < filteredWallpapers.length) {
                                                return filteredWallpapers[wallpaperGrid.currentIndex].split('/').pop();
                                            }
                                            return "";
                                        }
                                        color: parent.isCurrentWallpaper ? Colors.adapter.primary : Colors.adapter.overBackground
                                        font.family: Config.theme.font
                                        font.pixelSize: Config.theme.fontSize
                                        font.weight: Font.Bold
                                        horizontalAlignment: Text.AlignHCenter

                                        readonly property bool needsScroll: width > parent.width - 8

                                        // Resetear posición cuando cambia el texto o cuando deja de necesitar scroll
                                        onTextChanged: {
                                            if (needsScroll) {
                                                x = 4;
                                            }
                                        }

                                        onNeedsScrollChanged: {
                                            if (needsScroll) {
                                                x = 4;
                                                scrollAnimation.restart();
                                            }
                                        }

                                        SequentialAnimation {
                                            id: scrollAnimation
                                            running: labelText.needsScroll && labelText.parent && labelText.parent.visible && !labelText.parent.isCurrentWallpaper
                                            loops: Animation.Infinite

                                            PauseAnimation {
                                                duration: 1000
                                            }
                                            NumberAnimation {
                                                target: labelText
                                                property: "x"
                                                to: labelText.parent.width - labelText.width - 4
                                                duration: 2000
                                                easing.type: Easing.InOutQuad
                                            }
                                            PauseAnimation {
                                                duration: 1000
                                            }
                                            NumberAnimation {
                                                target: labelText
                                                property: "x"
                                                to: 4
                                                duration: 2000
                                                easing.type: Easing.InOutQuad
                                            }
                                        }
                                    }

                                    onVisibleChanged: {
                                        if (visible) {
                                            labelText.x = 4;
                                            if (labelText.needsScroll && !isCurrentWallpaper) {
                                                scrollAnimation.restart();
                                            }
                                        } else {
                                            scrollAnimation.stop();
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Delegado para cada elemento de la cuadrícula con lazy loading optimizado.
                    delegate: Rectangle {
                        width: wallpaperGridContainer.wallpaperWidth
                        height: wallpaperGridContainer.wallpaperHeight
                        color: "transparent"

                        property bool isCurrentWallpaper: {
                            if (!GlobalStates.wallpaperManager)
                                return false;
                            return GlobalStates.wallpaperManager.currentWallpaper === modelData;
                        }

                        property bool isHovered: false
                        property bool isSelected: selectedIndex === index

                        // Calcular si el item está visible en el viewport (con buffer para precarga)
                        readonly property bool isInViewport: {
                            var gridTop = wallpaperGrid.contentY;
                            var gridBottom = gridTop + wallpaperGrid.height;
                            var itemTop = y;
                            var itemBottom = itemTop + height;

                            // Buffer de una fila arriba y abajo para precarga suave
                            var buffer = wallpaperGridContainer.wallpaperHeight;
                            return itemBottom + buffer >= gridTop && itemTop - buffer <= gridBottom;
                        }

                        // Contenedor de imagen optimizado con ClippingRectangle para radius
                        Item {
                            anchors.fill: parent
                            anchors.margins: wallpaperGridContainer.wallpaperMargin

                            ClippingRectangle {
                                anchors.fill: parent
                                color: Colors.surface
                                radius: Config.roundness > 0 ? Config.roundness : 0

                                // Lazy loader que solo carga cuando el item está visible
                                Loader {
                                    anchors.fill: parent
                                    // active: parent.parent.parent.isInViewport
                                    sourceComponent: wallpaperComponent
                                    property string sourceFile: modelData

                                    // Placeholder mientras carga
                                    Rectangle {
                                        anchors.fill: parent
                                        color: Colors.surface
                                        visible: !parent.active

                                        Text {
                                            anchors.centerIn: parent
                                            text: "⏳"
                                            font.pixelSize: 24
                                            color: Colors.adapter.overSurfaceVariant
                                        }
                                    }
                                }
                            }
                        }

                        // Manejo de eventos de ratón.
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onEntered: {
                                parent.isHovered = true;
                                GlobalStates.wallpaperSelectedIndex = index;
                                selectedIndex = index;
                                wallpaperGrid.currentIndex = index;
                            }
                            onExited: {
                                parent.isHovered = false;
                            }
                            onPressed: parent.scale = 0.95
                            onReleased: parent.scale = 1.0

                            onClicked: {
                                if (GlobalStates.wallpaperManager) {
                                    GlobalStates.wallpaperManager.setWallpaper(modelData);
                                }
                            }
                        }

                        // Animaciones de color y escala.
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

    // Componente optimizado para wallpapers con lazy loading
    Component {
        id: wallpaperComponent

        Loader {
            sourceComponent: {
                if (!GlobalStates.wallpaperManager)
                    return null;

                var fileType = GlobalStates.wallpaperManager.getFileType(parent.sourceFile);
                if (fileType === 'image') {
                    return staticImageComponent;
                } else if (fileType === 'gif') {
                    return animatedImageComponent;
                } else if (fileType === 'video') {
                    return videoThumbnailComponent;
                }
                return staticImageComponent; // Fallback
            }
            property string sourceFile: parent.sourceFile
        }
    }

    // Componentes de imagen optimizados y reutilizables
    Component {
        id: staticImageComponent
        Image {
            source: parent.sourceFile ? "file://" + parent.sourceFile : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
            cache: false // Evitar acumular cache innecesario
        }
    }

    Component {
        id: animatedImageComponent
        AnimatedImage {
            source: parent.sourceFile ? "file://" + parent.sourceFile : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
            playing: false
            cache: false
        }
    }

    Component {
        id: videoThumbnailComponent
        Item {
            property string thumbnailPath: {
                // Construir ruta del thumbnail basado en el nombre del video
                var videoName = parent.sourceFile.split('/').pop();
                var baseName = videoName.substring(0, videoName.lastIndexOf('.'));
                return "file://" + Quickshell.env("HOME") + "/.cache/quickshell/video_thumbnails/" + baseName + ".jpg";
            }

            // Thumbnail pre-generado
            Image {
                anchors.fill: parent
                source: parent.thumbnailPath
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                cache: false

                // Placeholder mientras carga o si falla
                Rectangle {
                    anchors.fill: parent
                    color: Colors.surface
                    visible: parent.status !== Image.Ready

                    Text {
                        anchors.centerIn: parent
                        text: {
                            if (parent.parent.status === Image.Loading)
                                return "⏳";
                            if (parent.parent.status === Image.Error)
                                return "❌";
                            return "📹";
                        }
                        font.pixelSize: 24
                        color: Colors.adapter.overSurfaceVariant
                    }
                }
            }
        }
    }
}
