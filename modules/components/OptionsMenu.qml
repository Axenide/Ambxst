import QtQuick
import QtQuick.Controls
import qs.modules.theme
import qs.config

Menu {
    id: root

    // Propiedades principales
    property var items: []

    // Update menu width when items change
    onItemsChanged: {
        hoveredIndex = -1;
        previousHoveredIndex = -1;
        updateMenuWidth();
    }
    property int menuWidth: 140

    // Function to update menu width when items change
    function updateMenuWidth() {
        if (!items || items.length === 0) {
            menuWidth = 120;
            return;
        }

        let maxWidth = 0;
        for (let i = 0; i < items.length; i++) {
            if (items[i].isSeparator)
                continue;

            let text = items[i].text || "";
            let textWidth = textMetrics.measureText(text);
            let iconSpace = hasIcons ? 24 : 0;
            let totalItemWidth = textWidth + iconSpace + 40;

            if (totalItemWidth > maxWidth) {
                maxWidth = totalItemWidth;
            }
        }
        menuWidth = Math.min(Math.max(maxWidth, 120), 300);
    }
    property int itemHeight: 36

    // Propiedades de estilo del menú
    property color backgroundColor: Colors.background
    property color borderColor: Colors.surfaceBright
    property int borderWidth: 2
    property int menuRadius: Config.roundness

    // Propiedades de highlight por defecto
    property color defaultHighlightColor: Styling.srItem("overprimary")
    property color defaultTextColor: Colors.overPrimary
    property color normalTextColor: Colors.overBackground

    // Propiedades internas
    property int hoveredIndex: -1
    property int previousHoveredIndex: -1

    // Detectar si algún item tiene iconos para ajustar el layout
    property bool hasIcons: {
        for (let i = 0; i < items.length; i++) {
            if (items[i].icon && items[i].icon !== "") {
                return true;
            }
        }
        return false;
    }

    // TextMetrics para medir el texto
    TextMetrics {
        id: textMetrics
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(0)
        font.weight: Font.Bold

        function measureText(text) {
            textMetrics.text = text;
            return textMetrics.width;
        }
    }

    // Configuración del menú
    width: menuWidth  // Use fixed width instead of calculated to avoid binding loop
    padding: 8
    spacing: 0

    // Estilo del menú principal
    background: Item {
        implicitWidth: root.menuWidth

        // Fondo principal
        Rectangle {
            anchors.fill: parent
            color: root.backgroundColor
            radius: root.menuRadius
            border.width: root.borderWidth
            border.color: root.borderColor
        }

        // Highlight animado que sigue al hover
        Rectangle {
            id: menuHighlight
            width: root.menuWidth - 16
            height: root.itemHeight
            color: {
                if (root.hoveredIndex === -1 || root.hoveredIndex >= root.items.length)
                    return root.defaultHighlightColor;
                let item = root.items[root.hoveredIndex];
                return item && item.highlightColor !== undefined ? item.highlightColor : root.defaultHighlightColor;
            }
            radius: root.menuRadius > 6 ? root.menuRadius - 6 : 0
            visible: {
                if (root.hoveredIndex === -1 || root.hoveredIndex >= root.items.length)
                    return false;
                let item = root.items[root.hoveredIndex];
                return item && !item.isSeparator;
            }
            opacity: visible ? 1.0 : 0

            x: 8 // Padding offset
            y: {
                if (root.hoveredIndex === -1 || root.hoveredIndex >= root.items.length)
                    return 8;

                let yPosition = 8;
                for (let i = 0; i < root.hoveredIndex; i++) {
                    let item = root.items[i];
                    if (item && item.isSeparator) {
                        yPosition += 10;
                    } else {
                        yPosition += root.itemHeight;
                    }
                }
                return yPosition;
            }

            Behavior on y {
                enabled: root.previousHoveredIndex !== -1 && root.hoveredIndex !== -1 && Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 2
                    easing.type: Easing.OutQuart
                }
            }

            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 2
                    easing.type: Easing.OutQuart
                }
            }

            Behavior on color {
                enabled: Config.animDuration > 0
                ColorAnimation {
                    duration: Config.animDuration / 2
                    easing.type: Easing.OutQuart
                }
            }
        }
    }

    // Generar MenuItems dinámicamente
    Instantiator {
        model: root.items
        delegate: MenuItem {
            id: menuItem
            property int itemIndex: index
            property var itemData: modelData
            property bool isSeparatorItem: itemData.isSeparator || false

            text: itemData.text || ""
            width: root.menuWidth
            height: isSeparatorItem ? 10 : root.itemHeight // 2px separador + 4px margen arriba + 4px margen abajo
            enabled: !isSeparatorItem

            // Fondo - diferente para separadores
            background: Rectangle {
                anchors.fill: parent
                anchors.topMargin: isSeparatorItem ? 4 : 0
                anchors.bottomMargin: isSeparatorItem ? 4 : 0
                color: isSeparatorItem ? Colors.surface : "transparent"
                radius: isSeparatorItem ? 0 : (root.menuRadius > 6 ? root.menuRadius - 6 : 0)
            }

            // Manejo del hover - desactivado para separadores
            onHoveredChanged: {
                if (isSeparatorItem)
                    return;

                if (hovered) {
                    root.previousHoveredIndex = root.hoveredIndex;
                    root.hoveredIndex = itemIndex;
                } else {
                    let menuRoot = root;
                    let currentIndex = itemIndex;
                    Qt.callLater(() => {
                        if (menuRoot.hoveredIndex === currentIndex) {
                            menuRoot.previousHoveredIndex = menuRoot.hoveredIndex;
                            menuRoot.hoveredIndex = -1;
                        }
                    });
                }
            }

            // Contenido del item
            contentItem: Item {
                anchors.fill: parent

                Row {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: root.hasIcons ? 8 : 0
                    visible: !menuItem.isSeparatorItem

                    // Icono (opcional) - Puede ser fuente o imagen
                    Loader {
                        id: iconLoader
                        width: root.hasIcons ? 16 : 0
                        height: root.hasIcons ? 16 : 0
                        visible: root.hasIcons
                        anchors.verticalCenter: parent.verticalCenter

                        property bool isImageIcon: menuItem.itemData.isImageIcon || false
                        property string iconSource: menuItem.itemData.icon || ""

                        sourceComponent: {
                            if (iconSource === "" || !root.hasIcons)
                                return null;
                            return isImageIcon ? imageIconComponent : fontIconComponent;
                        }

                        Component {
                            id: fontIconComponent
                            Text {
                                text: iconLoader.iconSource
                                color: {
                                    if (root.hoveredIndex === menuItem.itemIndex) {
                                        return menuItem.itemData.textColor !== undefined ? menuItem.itemData.textColor : root.defaultTextColor;
                                    }
                                    return root.normalTextColor;
                                }
                                font.family: Icons.font
                                font.pixelSize: 14
                                font.weight: Font.Bold
                                anchors.centerIn: parent
                                textFormat: Text.RichText

                                Behavior on color {
                                    enabled: Config.animDuration > 0
                                    ColorAnimation {
                                        duration: Config.animDuration / 2
                                        easing.type: Easing.OutQuart
                                    }
                                }
                            }
                        }

                        Component {
                            id: imageIconComponent
                            Image {
                                mipmap: true
                                source: iconLoader.iconSource
                                width: 16
                                height: 16
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                anchors.centerIn: parent

                                onStatusChanged: {
                                    if (status === Image.Error) {
                                        console.log("Failed to load icon:", source);
                                    }
                                }
                            }
                        }
                    }

                    // Texto
                    Text {
                        text: menuItem.itemData.text || ""
                        color: {
                            if (root.hoveredIndex === menuItem.itemIndex) {
                                return menuItem.itemData.textColor !== undefined ? menuItem.itemData.textColor : root.defaultTextColor;
                            }
                            return root.normalTextColor;
                        }
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(0)
                        font.weight: Font.Bold
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        width: root.menuWidth - 32 - iconLoader.width - (root.hasIcons ? parent.spacing : 0)

                        Behavior on color {
                            enabled: Config.animDuration > 0
                            ColorAnimation {
                                duration: Config.animDuration / 2
                                easing.type: Easing.OutQuart
                            }
                        }
                    }
                }
            }

            // Acción al hacer click
            onTriggered: {
                if (itemData && itemData.onTriggered) {
                    let callback = itemData.onTriggered;
                    Qt.callLater(callback);
                }
            }
        }

        onObjectAdded: (index, object) => {
            root.addItem(object);
        }

        onObjectRemoved: (index, object) => {
            root.removeItem(object);
        }
    }
}
