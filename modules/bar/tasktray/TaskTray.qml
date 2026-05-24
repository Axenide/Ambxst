pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config

Item {
    id: root

    required property var bar
    property bool vertical: bar.orientation === "vertical"
    property bool isHovered: false
    property bool layerEnabled: true

    property real radius: 0
    property real startRadius: radius
    property real endRadius: radius

    property bool expanded: false
    readonly property var allItems: typeof SystemTray !== "undefined" && SystemTray.items ? SystemTray.items : []

    // Debug: visibility version counter
    property int visVer: 0
    property int clickCount: 0

    Connections {
        target: Config.bar
        function onHiddenIconsChanged() {
            root.visVer++;
            console.log("TaskTray: hiddenIcons changed →", JSON.stringify(Config.bar.hiddenIcons));
        }
    }

    function isItemHidden(item) {
        if (!item) return false;
        var key = (item.title || item.tooltipTitle || item.id || "").toString().toLowerCase();
        if (!key) return false;
        // Force dependency on visVer so this function re-evaluates
        var v = root.visVer;
        var h = Config.bar.hiddenIcons || [];
        for (var i = 0; i < h.length; i++) {
            if (key.indexOf(h[i].toLowerCase()) >= 0) return true;
        }
        return false;
    }

    function toggleItemVis(item) {
        if (!item) return;
        root.clickCount++;
        var key = (item.title || item.tooltipTitle || item.id || "").toString().toLowerCase();
        if (!key) { console.log("TaskTray: empty key"); return; }
        
        var h = (Config.bar.hiddenIcons || []).slice();
        var found = -1;
        for (var i = 0; i < h.length; i++) {
            if (key.indexOf(h[i].toLowerCase()) >= 0) { found = i; break; }
        }
        if (found >= 0) {
            h.splice(found, 1);
            console.log("TaskTray: unhide", key, "→", JSON.stringify(h));
        } else {
            h.push(key);
            console.log("TaskTray: hide", key, "→", JSON.stringify(h));
        }
        Config.bar.hiddenIcons = h;
    }

    readonly property int visibleCount: {
        var n = 0; var v = root.visVer;
        for (var i = 0; i < allItems.length; i++) {
            if (!root.isItemHidden(allItems[i])) n++;
        }
        return n;
    }

    property var contextItem: null

    readonly property int dockW: expanded && visibleCount > 0 ? Math.min(visibleCount, 10) * 28 + 10 : 0
    Layout.preferredWidth: 36 + (expanded ? 2 + dockW : 0)
    Layout.preferredHeight: 36
    Layout.fillWidth: vertical
    Layout.fillHeight: !vertical
    width: 36 + (expanded ? 2 + dockW : 0); height: 36

    Behavior on Layout.preferredWidth {
        enabled: !vertical && Config.animDuration > 0
        NumberAnimation { duration: Config.animDuration / 2; easing.type: Easing.OutCubic }
    }

    HoverHandler { onHoveredChanged: root.isHovered = hovered }

    StyledRect {
        id: toggleBtn
        anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
        width: 36; variant: "bg"
        enableShadow: root.layerEnabled && Config.showBackground; z: 2
        topLeftRadius: root.vertical ? root.startRadius : root.startRadius
        topRightRadius: root.expanded ? 0 : root.endRadius
        bottomLeftRadius: root.vertical ? root.endRadius : root.startRadius
        bottomRightRadius: root.expanded ? 0 : root.endRadius
        Rectangle {
            anchors.fill: parent
            color: Styling.srItem("overprimary")
            opacity: root.isHovered && !root.expanded ? 0.25 : 0
            radius: parent.radius ?? 0
            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation { duration: Config.animDuration / 2 }
            }
        }
        Text {
            anchors.centerIn: parent
            text: Icons.dotsThree
            font.family: Icons.font; font.pixelSize: 18
            color: Styling.srItem("overprimary")
        }
        StyledRect {
            anchors.top: parent.top; anchors.right: parent.right
            anchors.topMargin: -2; anchors.rightMargin: -2
            width: 14; height: 14; radius: 7; variant: "primary"
            visible: visibleCount > 0 && !root.expanded
            Text {
                anchors.centerIn: parent
                text: Math.min(visibleCount, 9)
                font.family: Config.theme.font; font.pixelSize: 8; font.bold: true; color: Colors.background
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.LeftButton) root.expanded = !root.expanded;
                else settingsPopup.open();
            }
        }
        StyledToolTip {
            visible: root.isHovered && !root.expanded
            tooltipText: visibleCount > 0 ? visibleCount + " visible" : "Empty tray"
        }
    }

    // Expanded dock
    StyledRect {
        id: dockBg
        anchors.left: toggleBtn.right; anchors.right: parent.right
        anchors.top: parent.top; anchors.bottom: parent.bottom
        visible: expanded && visibleCount > 0
        variant: "bg"; enableShadow: false; clip: true
        topLeftRadius: 0; topRightRadius: root.endRadius
        bottomLeftRadius: 0; bottomRightRadius: root.endRadius
        opacity: expanded ? 1.0 : 0.0
        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation { duration: Config.animDuration / 2 }
        }
        RowLayout {
            anchors.centerIn: parent; spacing: 2
            Repeater {
                model: root.allItems
                delegate: Item {
                    required property SystemTrayItem modelData
                    width: 26; height: 26
                    // Inline visibility check for proper reactivity
                    visible: {
                        var key = (modelData.title || modelData.tooltipTitle || modelData.id || "").toString().toLowerCase();
                        if (!key) return true;
                        var _ = root.visVer;
                        var h = Config.bar.hiddenIcons || [];
                        for (var i = 0; i < h.length; i++) {
                            if (key.indexOf(h[i].toLowerCase()) >= 0) return false;
                        }
                        return true;
                    }
                    property bool hov: false
                    HoverHandler { onHoveredChanged: hov = hovered }
                    StyledRect {
                        anchors.fill: parent; anchors.margins: 1; radius: 4
                        variant: "bg"; opacity: hov ? 0.5 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 80 } }
                    }
                    IconImage {
                        anchors.centerIn: parent; width: 18; height: 18
                        source: modelData.icon; smooth: true
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: event => {
                            if (event.button === Qt.LeftButton) modelData.activate();
                            else if (event.button === Qt.RightButton && modelData.hasMenu) {
                                root.contextItem = modelData; ctxPopup.open();
                            }
                        }
                    }
                }
            }
        }
    }

    // Native context menu
    BarPopup {
        id: ctxPopup; anchorItem: root; bar: root.bar
        QsMenuOpener { id: mo; menu: root.contextItem ? root.contextItem.menu : null }
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 4; spacing: 2
            Repeater {
                model: mo.children ? mo.children.values : []
                delegate: Item {
                    required property var modelData
                    Layout.fillWidth: true; Layout.preferredHeight: 28
                    readonly property bool sep: modelData.isSeparator === true
                    Rectangle {
                        anchors.left: parent.left; anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 1; color: Colors.outlineVariant; visible: sep
                    }
                    StyledRect {
                        anchors.fill: parent; radius: 4
                        variant: mm.containsMouse ? "focus" : "bg"; visible: !sep
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 8; spacing: 6
                            IconImage {
                                width: 16; height: 16; source: modelData.icon ?? ""; smooth: true
                                visible: modelData.icon !== undefined; Layout.alignment: Qt.AlignVCenter
                            }
                            Text {
                                text: modelData.text || ""
                                font.family: Styling.defaultFont; font.pixelSize: Styling.fontSize(-1)
                                color: Colors.overBackground; elide: Text.ElideRight
                                Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter
                            }
                        }
                    }
                    MouseArea {
                        id: mm; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                        onClicked: {
                            if (modelData.trigger) modelData.trigger();
                            ctxPopup.close(); root.contextItem = null;
                        }
                    }
                }
            }
        }
    }

    // Settings popup
    BarPopup {
        id: settingsPopup; anchorItem: toggleBtn; bar: root.bar

        ColumnLayout {
            anchors.fill: parent; anchors.margins: 6; spacing: 2

            Text {
                text: "Tray Icons (" + visibleCount + "/" + allItems.length + ")"
                font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-1)
                font.bold: true; color: Colors.overBackground
                Layout.fillWidth: true; Layout.bottomMargin: 4; leftPadding: 4
            }

            // Debug info
            Text {
                text: "ver:" + root.visVer + " clicks:" + root.clickCount + " hidden:" + (Config.bar.hiddenIcons || []).length
                font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-5)
                color: Colors.outline; visible: false // hide by default, enable for debug
            }

            Repeater {
                model: root.allItems

                delegate: Item {
                    required property SystemTrayItem modelData
                    Layout.fillWidth: true; Layout.preferredHeight: 34

                    StyledRect {
                        anchors.fill: parent
                        variant: sm.containsMouse ? "focus" : "bg"
                        radius: 4; opacity: sm.containsMouse ? 1.0 : 0.7
                    }

                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6; spacing: 8

                        // Toggle circle — inline binding for reactivity
                        Text {
                            id: circleIcon
                            text: {
                                var key = (modelData.title || modelData.tooltipTitle || modelData.id || "").toString().toLowerCase();
                                var _ = root.visVer;
                                var h = Config.bar.hiddenIcons || [];
                                var hidden = false;
                                for (var i = 0; i < h.length; i++) {
                                    if (key.indexOf(h[i].toLowerCase()) >= 0) { hidden = true; break; }
                                }
                                return hidden ? Icons.circleNotch : Icons.circle;
                            }
                            font.family: Icons.font; font.pixelSize: 16
                            color: {
                                var key = (modelData.title || modelData.tooltipTitle || modelData.id || "").toString().toLowerCase();
                                var _ = root.visVer;
                                var h = Config.bar.hiddenIcons || [];
                                var hidden = false;
                                for (var i = 0; i < h.length; i++) {
                                    if (key.indexOf(h[i].toLowerCase()) >= 0) { hidden = true; break; }
                                }
                                return hidden ? Colors.outline : Styling.srItem("primary");
                            }
                            Layout.alignment: Qt.AlignVCenter
                        }

                        // Activate on click
                        MouseArea {
                            anchors.fill: circleIcon; anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.toggleItemVis(modelData);
                                mouse.accepted = true;
                            }
                        }

                        IconImage {
                            width: 20; height: 20; source: modelData.icon; smooth: true
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            text: modelData.tooltipTitle || modelData.title || "App"
                            font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-2)
                            color: Colors.overBackground; elide: Text.ElideRight
                            Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter
                        }
                    }

                    MouseArea {
                        id: sm; anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: event => {
                            if (event.button === Qt.LeftButton) { modelData.activate(); settingsPopup.close(); }
                            else if (event.button === Qt.RightButton && modelData.hasMenu) {
                                root.contextItem = modelData; ctxPopup.open();
                            }
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
}
