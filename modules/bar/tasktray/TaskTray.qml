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

    // Local hidden items list — triggers reactive updates when reassigned
    property var _hidden: []
    function _toggle(key) {
        var a = _hidden.slice();
        var i = a.indexOf(key);
        if (i >= 0) a.splice(i, 1); else a.push(key);
        _hidden = a;
        console.log("_hidden:", JSON.stringify(a));
    }

    property var _ctxItem: null

    readonly property int _visCount: {
        var n = 0;
        var h = _hidden;
        for (var i = 0; i < allItems.length; i++) {
            var it = allItems[i];
            var k = i + "_" + (it.title || it.tooltipTitle || it.id || "item" + i).toString();
            if (h.indexOf(k) < 0) n++;
        }
        return n;
    }

    readonly property int _dw: expanded && _visCount > 0 ? Math.min(_visCount, 10) * 28 + 10 : (expanded && allItems.length > 0 ? 40 : 0)

    Layout.preferredWidth: 36 + (expanded ? 2 + _dw : 0)
    Layout.preferredHeight: 36
    Layout.fillWidth: vertical
    Layout.fillHeight: !vertical
    
    Behavior on Layout.preferredWidth {
        enabled: !vertical && Config.animDuration > 0
        NumberAnimation { duration: Config.animDuration / 2; easing.type: Easing.OutCubic }
    }

    HoverHandler { onHoveredChanged: root.isHovered = hovered }

    // ── Toggle button ──
    StyledRect {
        id: toggleBtn
        width: 36; variant: "bg"
        anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
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
            text: Icons.dotsThree; font.family: Icons.font; font.pixelSize: 18
            color: Styling.srItem("overprimary")
        }

        StyledRect {
            anchors.top: parent.top; anchors.right: parent.right
            anchors.topMargin: -2; anchors.rightMargin: -2
            width: 14; height: 14; radius: 7; variant: "primary"
            visible: _visCount > 0 && !root.expanded
            Text {
                anchors.centerIn: parent
                text: Math.min(_visCount, 9)
                font.family: Config.theme.font; font.pixelSize: 8; font.bold: true; color: Colors.background
            }
        }

        MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.LeftButton) root.expanded = !root.expanded;
                else settingsPopup.open();
            }
        }

        StyledToolTip {
            visible: root.isHovered && !root.expanded
            tooltipText: _visCount > 0 ? _visCount + " visible" : "Empty tray"
        }
    }

    // ── Expanded dock ──
    StyledRect {
        id: dockBg
        anchors.left: toggleBtn.right; anchors.right: parent.right
        anchors.top: parent.top; anchors.bottom: parent.bottom
        visible: expanded && allItems.length > 0
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
                    readonly property string _k: index + "_" + (modelData.title || modelData.tooltipTitle || modelData.id || "item" + index).toString()
                    visible: root._hidden.indexOf(_k) < 0

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
                                root._ctxItem = modelData; ctxPopup.open();
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Native context menu ──
    BarPopup {
        id: ctxPopup; anchorItem: root; bar: root.bar
        QsMenuOpener { id: mo; menu: root._ctxItem ? root._ctxItem.menu : null }
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
                            ctxPopup.close(); root._ctxItem = null;
                        }
                    }
                }
            }
        }
    }

    // ── Settings popup ──
    BarPopup {
        id: settingsPopup; anchorItem: toggleBtn; bar: root.bar

        ColumnLayout {
            anchors.fill: parent; anchors.margins: 6; spacing: 2

            Text {
                text: "Tray Icons (" + _visCount + "/" + allItems.length + ")"
                font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-1)
                font.bold: true; color: Colors.overBackground
                Layout.fillWidth: true; Layout.bottomMargin: 4; leftPadding: 4
            }

            Repeater {
                model: root.allItems

                delegate: Item {
                    required property SystemTrayItem modelData
                    Layout.fillWidth: true; Layout.preferredHeight: 34

                    readonly property string _key: index + "_" + (modelData.title || modelData.tooltipTitle || modelData.id || "item" + index).toString()

                    // Click area for the whole row — declared FIRST so it's BEHIND the contents
                    MouseArea {
                        id: _rowMA
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: event => {
                            if (event.button === Qt.LeftButton) { modelData.activate(); settingsPopup.close(); }
                            else if (event.button === Qt.RightButton && modelData.hasMenu) {
                                root._ctxItem = modelData; ctxPopup.open();
                            }
                        }
                    }

                    StyledRect {
                        anchors.fill: parent
                        radius: 4
                        variant: _rowMA.containsMouse ? "focus" : "bg"
                        opacity: _rowMA.containsMouse ? 1.0 : 0.7
                    }

                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6; spacing: 8

                        // Circle toggle — declared AFTER _rowMA so it's on top
                        Text {
                            id: _circle
                            text: root._hidden.indexOf(_key) >= 0 ? Icons.circleNotch : Icons.circle
                            font.family: Icons.font; font.pixelSize: 16
                            color: root._hidden.indexOf(_key) >= 0 ? Colors.outline : Styling.srItem("primary")
                            Layout.alignment: Qt.AlignVCenter

                            MouseArea {
                                anchors.fill: parent; anchors.margins: -4
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root._toggle(_key);
                                    mouse.accepted = true;
                                }
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
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
}
