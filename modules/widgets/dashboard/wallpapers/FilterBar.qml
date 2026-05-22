import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.globals
import qs.config

// Componente para la barra de filtros de tipo de archivo
FocusScope {
    id: root

    // Propiedades públicas
    property var activeFilters: []

    // Asegurar que activeFilters siempre sea un array válido
    readonly property var safeFilters: activeFilters || []

    // Señales
    signal filterToggled(string filterType)
    signal escapePressedOnFilters
    signal shiftTabPressed
    signal tabPressed

    // Propiedad para rastrear si el scrollbar está siendo presionado
    property bool scrollBarPressed: false

    // Propiedad para navegación por teclado
    property int focusedFilterIndex: -1
    property int lastFocusedFilterIndex: 0
    property bool keyboardNavigationActive: false

    // Función para tomar el foco
    function focusFilters() {
        keyboardNavigationActive = true;
        // Restaurar el último filtro que tuvo foco, o el primero si no hay historial
        focusedFilterIndex = lastFocusedFilterIndex >= 0 && lastFocusedFilterIndex < filterModel.count ? lastFocusedFilterIndex : 0;
        ensureVisible(focusedFilterIndex);
        root.focus = true;
    }

    // Configuración del Flickable
    height: 32 + (scrollBar.visible ? 4 + scrollBar.implicitHeight : 0)
    implicitWidth: filterRow.width

    onActiveFocusChanged: {
        if (!activeFocus) {
            keyboardNavigationActive = false;
            // Recordar el índice del filtro enfocado antes de perder el foco
            if (focusedFilterIndex >= 0) {
                lastFocusedFilterIndex = focusedFilterIndex;
            }
            focusedFilterIndex = -1;
        }
    }

    Keys.onPressed: event => {
        // Manejar Shift+Tab para volver al search
        if (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier)) {
            keyboardNavigationActive = false;
            focusedFilterIndex = -1;
            shiftTabPressed();
            event.accepted = true;
            return;
        }

        // Manejar Tab para avanzar al siguiente elemento
        if (event.key === Qt.Key_Tab) {
            keyboardNavigationActive = false;
            focusedFilterIndex = -1;
            tabPressed();
            event.accepted = true;
            return;
        }

        if (!keyboardNavigationActive)
            return;

        if (event.key === Qt.Key_Left) {
            if (focusedFilterIndex > 0) {
                focusedFilterIndex--;
                ensureVisible(focusedFilterIndex);
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
            if (focusedFilterIndex < filterModel.count - 1) {
                focusedFilterIndex++;
                ensureVisible(focusedFilterIndex);
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            if (focusedFilterIndex >= 0 && focusedFilterIndex < filterModel.count) {
                const filterType = filterModel.get(focusedFilterIndex).type;
                const index = root.activeFilters.indexOf(filterType);
                if (index > -1) {
                    root.activeFilters.splice(index, 1);
                } else {
                    root.activeFilters.push(filterType);
                }
                root.activeFilters = root.activeFilters.slice();
                root.filterToggled(filterType);
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            keyboardNavigationActive = false;
            focusedFilterIndex = -1;
            escapePressedOnFilters();
            event.accepted = true;
        }
    }

    function ensureVisible(index) {
        if (index < 0 || index >= filterRepeater.count)
            return;

        const item = filterRepeater.itemAt(index);
        if (!item)
            return;

        const itemX = item.x;
        const itemWidth = item.width;
        const viewportWidth = flickable.width;
        const contentX = flickable.contentX;

        // Calcular la posición de destino con scroll suave
        let targetX = contentX;

        if (itemX < contentX) {
            // El elemento está fuera del viewport por la izquierda
            targetX = itemX;
        } else if (itemX + itemWidth > contentX + viewportWidth) {
            // El elemento está fuera del viewport por la derecha
            targetX = itemX + itemWidth - viewportWidth;
        }

        // Si necesitamos hacer scroll, animarlo
        if (targetX !== contentX) {
            scrollAnimation.to = targetX;
            scrollAnimation.restart();
        }
    }

    Flickable {
        id: flickable
        width: parent.width
        height: 32
        contentWidth: filterRow.width
        flickableDirection: Flickable.HorizontalFlick
        clip: true

        // Animación suave para el scroll programático
        NumberAnimation on contentX {
            id: scrollAnimation
            duration: Config.animDuration / 2
            easing.type: Easing.OutQuart
        }

        // Modelo de filtros
        ListModel {
            id: filterModel
            ListElement {
                label: "Images"
                type: "image"
            }
            ListElement {
                label: "GIF"
                type: "gif"
            }
            ListElement {
                label: "Videos"
                type: "video"
            }
        }

        // Función para actualizar filtros dinámicamente
        function updateFilters() {
            console.log("Updating filters in FilterBar");
            // Limpiar filtros de subcarpetas existentes
            for (var i = filterModel.count - 1; i >= 3; i--) {
                filterModel.remove(i);
            }

            // Agregar filtros de subcarpetas
            if (GlobalStates.wallpaperManager && GlobalStates.wallpaperManager.subfolderFilters) {
                var subfolders = GlobalStates.wallpaperManager.subfolderFilters;
                console.log("Adding subfolder filters:", subfolders);
                for (var j = 0; j < subfolders.length; j++) {
                    filterModel.append({
                        label: subfolders[j],
                        type: "subfolder_" + subfolders[j]
                    });
                }
            }
            console.log("Filter model now has", filterModel.count, "items");
        }

        // Actualizar filtros cuando cambien las subcarpetas
        Connections {
            target: GlobalStates.wallpaperManager
            function onSubfolderFiltersChanged() {
                flickable.updateFilters();
            }
        }

        Component.onCompleted: {
            flickable.updateFilters();
        }

        // Actualizar filtros cuando cambie el directorio de wallpapers
        Connections {
            target: GlobalStates.wallpaperManager
            function onWallpaperDirChanged() {
                flickable.updateFilters();
            }
        }

        Row {
            id: filterRow
            spacing: 4

            Repeater {
                id: filterRepeater
                model: filterModel
                delegate: StyledRect {
                    id: filterTag
                    required property string label
                    required property string type
                    required property int index

                    property bool isActive: root.activeFilters.includes(type)
                    property bool hasFocus: root.keyboardNavigationActive && root.focusedFilterIndex === index
                    property bool isHovered: false

                    // Variante dinámica según estado
                    variant: {
                        if (isActive && (hasFocus || isHovered))
                            return "primaryfocus";
                        if (isActive)
                            return "primary";
                        if (hasFocus || isHovered)
                            return "focus";
                        return "common";
                    }

                    // Ancho dinámico: incluye icono solo cuando está activo
                    width: filterText.width + 24 + (isActive ? filterIcon.width + 4 : 0)
                    height: 32
                    radius: isActive ? Styling.radius(0) / 2 : Styling.radius(0)

                    Item {
                        anchors.fill: parent
                        anchors.margins: 8

                        Row {
                            anchors.centerIn: parent
                            spacing: isActive ? 4 : 0

                            // Icono con animación de revelación
                            Item {
                                width: filterIcon.visible ? filterIcon.width : 0
                                height: filterIcon.height
                                clip: true

                                Text {
                                    id: filterIcon
                                    text: Icons.accept
                                    font.family: Icons.font
                                    font.pixelSize: 16
                                    color: filterTag.item
                                    visible: isActive
                                    opacity: isActive ? 1 : 0

                                    Behavior on opacity {
                                        enabled: Config.animDuration > 0
                                        NumberAnimation {
                                            duration: Config.animDuration / 3
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }

                                Behavior on width {
                                    enabled: Config.animDuration > 0
                                    NumberAnimation {
                                        duration: Config.animDuration / 3
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }

                            Text {
                                id: filterText
                                text: label
                                font.family: Config.theme.font
                                font.pixelSize: Config.theme.fontSize
                                color: filterTag.item

                                Behavior on color {
                                    enabled: Config.animDuration > 0
                                    ColorAnimation {
                                        duration: Config.animDuration / 3
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onEntered: filterTag.isHovered = true
                        onExited: filterTag.isHovered = false

                        onClicked: {
                            root.keyboardNavigationActive = false;
                            root.focusedFilterIndex = -1;

                            const index = root.activeFilters.indexOf(type);
                            if (index > -1) {
                                root.activeFilters.splice(index, 1);
                            } else {
                                root.activeFilters.push(type);
                            }
                            root.activeFilters = root.activeFilters.slice();  // Trigger update
                            root.filterToggled(type);
                        }
                    }

                    Behavior on width {
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

    ScrollBar {
        id: scrollBar
        anchors.top: flickable.bottom
        anchors.topMargin: 4
        Layout.preferredHeight: 4
        width: flickable.width
        height: implicitHeight
        orientation: Qt.Horizontal
        visible: flickable.contentWidth > flickable.width

        position: flickable.contentX / flickable.contentWidth
        size: flickable.width / flickable.contentWidth

        background: Rectangle {
            implicitWidth: 4
            implicitHeight: 4
            color: Colors.surface
            radius: Styling.radius(0)
        }

        contentItem: Rectangle {
            implicitWidth: 4
            implicitHeight: 4
            color: Styling.srItem("overprimary")
            radius: Styling.radius(0)
        }

        onPressedChanged: {
            scrollBarPressed = pressed;
        }

        onPositionChanged: {
            if (scrollBarPressed && flickable.contentWidth > flickable.width) {
                flickable.contentX = position * flickable.contentWidth;
            }
        }
    }
}
