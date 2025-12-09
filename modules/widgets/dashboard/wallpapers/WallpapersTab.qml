import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.components
import qs.modules.globals
import qs.modules.services
import qs.config

// Componente principal para el selector de fondos de pantalla.
FocusScope {
    id: wallpapersTabRoot

    // Propiedades personalizadas para la funcionalidad del componente.
    property string searchText: ""
    property int selectedIndex: GlobalStates.wallpaperSelectedIndex

    property var activeFilters: []  // Lista de tipos de archivo seleccionados para filtrar

    // Configuración interna del grid
    readonly property int gridColumns: 8
    readonly property int wallpaperMargin: 4

    // Array de elementos focusables para navegación cíclica
    property var focusableElements: [
        {
            id: "oledCheckbox",
            focusFunc: function () {
                oledCheckboxContainer.keyboardNavigationActive = true;
                oledCheckbox.forceActiveFocus();
            }
        },
        {
            id: "schemeSelector",
            focusFunc: function () {
                schemeSelector.openAndFocus();
            }
        },
        {
            id: "filters",
            focusFunc: function () {
                filterBar.focusFilters();
            }
        }
    ]

    property int currentFocusIndex: -1

    // Función para enfocar el campo de búsqueda
    function focusSearch() {
        currentFocusIndex = -1;
        wallpaperSearchInput.focusInput();
    }

    // Alias para compatibilidad con Dashboard
    function focusSearchInput() {
        focusSearch();
    }

    // Función para enfocar los filtros
    function focusFilters() {
        currentFocusIndex = 2;
        focusableElements[2].focusFunc();
    }

    // Función para navegar hacia adelante (Tab)
    function focusNextElement() {
        if (currentFocusIndex === -1) {
            currentFocusIndex = 0;
            focusableElements[currentFocusIndex].focusFunc();
        } else if (currentFocusIndex === focusableElements.length - 1) {
            // Si estamos en el último elemento, volver al search
            focusSearch();
        } else {
            currentFocusIndex++;
            focusableElements[currentFocusIndex].focusFunc();
        }
    }

    // Función para navegar hacia atrás (Shift+Tab)
    function focusPreviousElement() {
        if (currentFocusIndex === -1 || currentFocusIndex === 0) {
            // Si estamos en el search o en el primer elemento focusable, volver al search
            focusSearch();
        } else {
            currentFocusIndex--;
            focusableElements[currentFocusIndex].focusFunc();
        }
    }

    // Función para posicionar el wallpaper actual centrado verticalmente
    function centerCurrentWallpaper() {
        const currentIndex = findCurrentWallpaperIndex();
        if (currentIndex !== -1) {
            GlobalStates.wallpaperSelectedIndex = currentIndex;
            selectedIndex = currentIndex;
            wallpaperGrid.currentIndex = currentIndex;

            // Calcular la fila del wallpaper actual
            const currentRow = Math.floor(currentIndex / wallpapersTabRoot.gridColumns);
            // Calcular el índice del primer item de esa fila
            const rowStartIndex = currentRow * wallpapersTabRoot.gridColumns;

            // Posicionar para que la fila esté centrada verticalmente
            wallpaperGrid.positionViewAtIndex(rowStartIndex, GridView.Center);
        }
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
        centerTimer.start();
    }

    // Actualizar subcarpetas cuando la pestaña se haga visible
    onVisibleChanged: {
        if (visible) {
            if (GlobalStates.wallpaperManager) {
                console.log("WallpapersTab became visible, updating subfolders");
                GlobalStates.wallpaperManager.scanSubfolders();
            }
            // Reposicionar al wallpaper actual cuando se hace visible
            centerTimer.restart();
        }
    }

    // Timer para asegurar que el centrado ocurre después de que el GridView esté listo
    Timer {
        id: centerTimer
        interval: 50
        repeat: false
        onTriggered: {
            centerCurrentWallpaper();
            focusSearch();
        }
    }

    // Propiedad calculada que filtra los fondos de pantalla según el texto de búsqueda y tipos activos.
    property var filteredWallpapers: {
        if (!GlobalStates.wallpaperManager)
            return [];

        let wallpapers = GlobalStates.wallpaperManager.wallpaperPaths;

        // Filtrar por texto de búsqueda
        if (searchText.length > 0) {
            wallpapers = wallpapers.filter(function (path) {
                const fileName = path.split('/').pop().toLowerCase();
                return fileName.includes(searchText.toLowerCase());
            });
        }

        // Filtrar por tipos activos si hay filtros seleccionados
        if (activeFilters.length > 0) {
            wallpapers = wallpapers.filter(function (path) {
                const fileType = GlobalStates.wallpaperManager.getFileType(path);
                const subfolder = GlobalStates.wallpaperManager.getSubfolderFromPath(path);

                // Verificar si coincide con algún filtro activo
                for (var i = 0; i < activeFilters.length; i++) {
                    var filter = activeFilters[i];
                    if (filter === fileType) {
                        return true;
                    }
                    if (filter.startsWith("subfolder_") && subfolder === filter.replace("subfolder_", "")) {
                        return true;
                    }
                }
                return false;
            });
        }

        return wallpapers;
    }

    // Scheme Selector posicionado absolutamente para que se superponga al expandirse
    SchemeSelector {
        id: schemeSelector
        anchors.right: parent.right
        anchors.top: parent.top
        width: 200
        z: 1000

        onSchemeSelectorClosed: {
            wallpapersTabRoot.focusSearch();
        }

        onEscapePressedOnScheme: {
            wallpapersTabRoot.focusSearch();
        }

        onTabPressed: {
            wallpapersTabRoot.focusNextElement();
        }

        onShiftTabPressed: {
            wallpapersTabRoot.focusPreviousElement();
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        // Barra superior con OLED mode, búsqueda y scheme selector
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 48

            // OLED Mode a la izquierda
            Item {
                id: oledCheckboxContainer
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 200
                height: 48

                property bool keyboardNavigationActive: false

                StyledRect {
                    variant: oledCheckboxContainer.keyboardNavigationActive && oledCheckbox.activeFocus ? "focus" : "pane"
                    anchors.fill: parent
                    radius: Styling.radius(4)
                    opacity: oledCheckbox.enabled ? 1.0 : 0.5

                    Behavior on opacity {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Config.animDuration / 2
                            easing.type: Easing.OutQuart
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 4

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: Colors.background
                            radius: Styling.radius(0)

                            Text {
                                anchors.fill: parent
                                text: "OLED Mode"
                                color: Colors.overSurface
                                font.family: Config.theme.font
                                font.pixelSize: Config.theme.fontSize
                                font.weight: Font.Medium
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: 8

                                Behavior on color {
                                    enabled: Config.animDuration > 0
                                    ColorAnimation {
                                        duration: Config.animDuration / 2
                                        easing.type: Easing.OutQuart
                                    }
                                }
                            }
                        }

                        Item {
                            id: oledCheckbox
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40

                            property bool checked: Config.theme.oledMode
                            property bool enabled: !Config.theme.lightMode

                            onActiveFocusChanged: {
                                if (!activeFocus) {
                                    oledCheckboxContainer.keyboardNavigationActive = false;
                                }
                            }

                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Tab) {
                                    oledCheckboxContainer.keyboardNavigationActive = false;
                                    if (event.modifiers & Qt.ShiftModifier) {
                                        wallpapersTabRoot.focusPreviousElement();
                                    } else {
                                        wallpapersTabRoot.focusNextElement();
                                    }
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                                    if (enabled) {
                                        Config.theme.oledMode = !Config.theme.oledMode;
                                    }
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Escape) {
                                    oledCheckboxContainer.keyboardNavigationActive = false;
                                    focusSearch();
                                    event.accepted = true;
                                }
                            }

                            // Update checked state when config changes
                            Connections {
                                target: Config.theme
                                function onOledModeChanged() {
                                    oledCheckbox.checked = Config.theme.oledMode;
                                }
                            }

                            Item {
                                anchors.fill: parent

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Styling.radius(0)
                                    color: Colors.background
                                    visible: !oledCheckbox.checked
                                }

                                StyledRect {
                                    variant: "primary"
                                    anchors.fill: parent
                                    radius: Styling.radius(0)
                                    visible: oledCheckbox.checked
                                    opacity: oledCheckbox.checked ? 1.0 : 0.0

                                    Behavior on opacity {
                                        enabled: Config.animDuration > 0
                                        NumberAnimation {
                                            duration: Config.animDuration / 2
                                            easing.type: Easing.OutQuart
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: Icons.accept
                                        color: Config.resolveColor(Config.theme.srPrimary.itemColor)
                                        font.family: Icons.font
                                        font.pixelSize: 20
                                        scale: oledCheckbox.checked ? 1.0 : 0.0

                                        Behavior on scale {
                                            enabled: Config.animDuration > 0
                                            NumberAnimation {
                                                duration: Config.animDuration / 2
                                                easing.type: Easing.OutBack
                                                easing.overshoot: 1.5
                                            }
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: oledCheckbox.enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                                onClicked: {
                                    if (oledCheckbox.enabled) {
                                        Config.theme.oledMode = !Config.theme.oledMode;
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Barra de búsqueda centrada
            SearchInput {
                id: wallpaperSearchInput
                anchors.centerIn: parent
                width: 400
                text: searchText
                placeholderText: "Search wallpapers..."
                iconText: ""
                clearOnEscape: false
                handleTabNavigation: true
                radius: Styling.radius(4)

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

                onTabPressed: {
                    focusNextElement();
                }

                onShiftTabPressed: {
                    focusPreviousElement();
                }

                onDownPressed: {
                    if (filteredWallpapers.length > 0) {
                        if (selectedIndex < filteredWallpapers.length - 1) {
                            let newIndex = selectedIndex + wallpapersTabRoot.gridColumns;
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
                        let newIndex = selectedIndex - wallpapersTabRoot.gridColumns;
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

            // Scheme Selector a la derecha (placeholder para el espacio)
            Item {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 200
                height: 48
            }
        }

        // FilterBar centrada
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: filterBar.height

            FilterBar {
                id: filterBar
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(implicitWidth, parent.width)
                activeFilters: wallpapersTabRoot.activeFilters

                onActiveFiltersChanged: {
                    wallpapersTabRoot.activeFilters = activeFilters;
                }

                onEscapePressedOnFilters: {
                    wallpapersTabRoot.focusSearch();
                }

                onTabPressed: {
                    wallpapersTabRoot.focusNextElement();
                }

                onShiftTabPressed: {
                    wallpapersTabRoot.focusPreviousElement();
                }
            }
        }

        // Grid de wallpapers
        ClippingRectangle {
            id: wallpaperGridContainer
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"
            radius: Styling.radius(4)
            clip: true

            // Calcular tamaño de celda basado en columnas y proporción 1:1
            // El grid tiene margins negativos, así que el ancho real es width + margin*2
            readonly property real gridWidth: width + (wallpapersTabRoot.wallpaperMargin * 2)
            readonly property real cellSize: gridWidth / wallpapersTabRoot.gridColumns

            GridView {
                id: wallpaperGrid
                anchors.fill: parent
                anchors.margins: -wallpapersTabRoot.wallpaperMargin
                cellWidth: wallpaperGridContainer.cellSize
                cellHeight: wallpaperGridContainer.cellSize
                flow: GridView.FlowLeftToRight
                boundsBehavior: Flickable.StopAtBounds
                model: filteredWallpapers
                currentIndex: selectedIndex

                // Optimizaciones de rendimiento
                cacheBuffer: cellHeight * 2
                displayMarginBeginning: cellHeight
                displayMarginEnd: cellHeight
                reuseItems: true

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

                // Elemento de realce para el wallpaper seleccionado.
                    highlight: Item {
                        width: wallpaperGrid.cellWidth
                        height: wallpaperGrid.cellHeight
                        z: 100

                    Behavior on x {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Config.animDuration / 2
                            easing.type: Easing.OutQuart
                        }
                    }

                    Behavior on y {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Config.animDuration / 2
                            easing.type: Easing.OutQuart
                        }
                    }

                    ClippingRectangle {
                        id: highlightRectangle
                        anchors.centerIn: parent
                        width: parent.width - wallpapersTabRoot.wallpaperMargin * 2
                        height: parent.height - wallpapersTabRoot.wallpaperMargin * 2
                        color: "transparent"
                        border.color: Colors.primary
                        border.width: 2
                        visible: selectedIndex >= 0
                        radius: Styling.radius(4)
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
                            radius: Styling.radius(24)
                            z: 5

                            // Etiqueta unificada que se anima con el highlight
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottomMargin: 0
                                height: 28
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

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.horizontalCenter: parent.horizontalCenter
                                        width: wallpaperGrid.cellWidth - 20
                                    height: parent.height
                                    color: "transparent"
                                    clip: true

                                    Text {
                                        id: labelText
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.horizontalCenter: needsScroll ? undefined : parent.horizontalCenter
                                        x: needsScroll ? 4 : undefined
                                        text: {
                                            if (parent.parent.isCurrentWallpaper) {
                                                return "CURRENT";
                                            } else if (wallpaperGrid.currentIndex >= 0 && wallpaperGrid.currentIndex < filteredWallpapers.length) {
                                                return filteredWallpapers[wallpaperGrid.currentIndex].split('/').pop();
                                            }
                                            return "";
                                        }
                                        color: parent.parent.isCurrentWallpaper ? Config.resolveColor(Config.theme.srOverPrimary.itemColor) : Colors.overBackground
                                        font.family: Config.theme.font
                                        font.pixelSize: Config.theme.fontSize
                                        font.weight: Font.Bold
                                        horizontalAlignment: Text.AlignHCenter

                                        readonly property bool needsScroll: contentWidth > parent.width - 8

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
                                            running: labelText.needsScroll && labelText.parent && labelText.parent.parent.visible && !labelText.parent.parent.isCurrentWallpaper
                                            loops: Animation.Infinite

                                            PauseAnimation {
                                                duration: 1000
                                            }
                                            NumberAnimation {
                                                target: labelText
                                                property: "x"
                                                to: labelText.parent.width - labelText.contentWidth - 4
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

                                    // Dummy item to fill remaining height and keep items top-aligned
                                    Item {
                                        Layout.fillHeight: true
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
                    width: wallpaperGrid.cellWidth
                    height: wallpaperGrid.cellHeight
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
                        var buffer = wallpaperGrid.cellHeight;
                        return itemBottom + buffer >= gridTop && itemTop - buffer <= gridBottom;
                    }

                    // Contenedor de imagen optimizado con ClippingRectangle para radius
                    Item {
                        anchors.fill: parent
                        anchors.margins: wallpapersTabRoot.wallpaperMargin

                        ClippingRectangle {
                            anchors.fill: parent
                            color: Colors.surface
                            radius: Styling.radius(4)

                            // Lazy loader que solo carga cuando el item está visible
                            Loader {
                                anchors.fill: parent
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
                                        color: Colors.overSurfaceVariant
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
                        enabled: Config.animDuration > 0
                        ColorAnimation {
                            duration: Config.animDuration / 2
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on scale {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Config.animDuration / 3
                            easing.type: Easing.OutCubic
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
            sourceComponent: staticImageComponent // All thumbnails are now static images
            property string sourceFile: parent.sourceFile
        }
    }

    // Componentes de imagen optimizados y reutilizables
    Component {
        id: staticImageComponent
        Image {
            source: {
                if (!parent.sourceFile)
                    return "";

                // Usar thumbnail si está disponible, fallback a original
                var thumbnailPath = GlobalStates.wallpaperManager.getThumbnailPath(parent.sourceFile);
                return thumbnailPath ? "file://" + thumbnailPath : "file://" + parent.sourceFile;
            }
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
            cache: false // Evitar acumular cache innecesario

            // Fallback a imagen original si el thumbnail falla
            onStatusChanged: {
                if (status === Image.Error && source.toString().includes("/by-shell/Ambxst/image_thumbnails/")) {
                    console.log("Thumbnail failed, using original:", parent.sourceFile);
                    source = "file://" + parent.sourceFile;
                }
            }
        }
    }
}
