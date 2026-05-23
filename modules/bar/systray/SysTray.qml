import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import qs.modules.theme
import qs.config
import qs.modules.components

    StyledRect {
    variant: "bg"
    id: root

    // Hide when no tray items
    visible: hasItems

    topLeftRadius: root.vertical ? root.startRadius : root.startRadius
    topRightRadius: root.vertical ? root.startRadius : root.endRadius
    bottomLeftRadius: root.vertical ? root.endRadius : root.startRadius
    bottomRightRadius: root.vertical ? root.endRadius : root.endRadius

    required property var bar
    
    property real radius: 0
    property real startRadius: radius
    property real endRadius: radius

    // Orientación derivada de la barra
    property bool vertical: bar.orientation === "vertical"

    // Filtered tray items (UntypedObjectModel doesn't support .filter())
    readonly property var filteredItems: {
        var result = [];
        var items = SystemTray.items;
        var hidden = Config.bar.hiddenIcons;
        for (var i = 0; i < items.length; i++) {
            var item = items[i];
            var title = (item.title || item.tooltipTitle || "").toLowerCase();
            var hide = false;
            for (var j = 0; j < hidden.length; j++) {
                if (title.includes(hidden[j].toLowerCase())) {
                    hide = true;
                    break;
                }
            }
            if (!hide) result.push(item);
        }
        return result;
    }

    // Hide completely when empty - check both orientations
    readonly property bool hasItems: rowRepeater.count > 0 || columnRepeater.count > 0

    // Ajustes de tamaño dinámicos según orientación
    height: vertical ? implicitHeight : parent.height
    Layout.preferredWidth: hasItems ? ((vertical ? columnLayout.implicitWidth : rowLayout.implicitWidth) + 16) : 0
    implicitWidth: hasItems ? ((vertical ? columnLayout.implicitWidth : rowLayout.implicitWidth) + 16) : 0
    implicitHeight: hasItems ? ((vertical ? columnLayout.implicitHeight : rowLayout.implicitHeight) + 16) : 0

    RowLayout {
        id: rowLayout
        visible: !root.vertical
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Repeater {
            id: rowRepeater
            model: root.filteredItems

            SysTrayItem {
                required property SystemTrayItem modelData
                bar: root.bar
                item: modelData
            }
        }
    }

    ColumnLayout {
        id: columnLayout
        visible: root.vertical
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Repeater {
            id: columnRepeater
            model: root.filteredItems

            SysTrayItem {
                required property SystemTrayItem modelData
                bar: root.bar
                item: modelData
            }
        }
    }
}
