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
    property var _ctxItem: null
    property var _hid: []

    function _toggle(k) {
        var a = _hid.slice();
        var i = a.indexOf(k);
        if (i >= 0) a.splice(i, 1); else a.push(k);
        _hid = a;
    }

    function _key(i, it) {
        return i + "_" + (it.title || it.tooltipTitle || it.id || "t" + i);
    }

    readonly property int _vc: {
        var n = 0, h = _hid;
        if (!SystemTray || !SystemTray.items) return 0;
        for (var i = 0; i < SystemTray.items.length; i++) {
            if (h.indexOf(_key(i, SystemTray.items[i])) < 0) n++;
        }
        return n;
    }

    readonly property int _n: SystemTray && SystemTray.items ? SystemTray.items.length : 0

    Layout.preferredWidth: 36
    Layout.preferredHeight: 36
    Layout.maximumWidth: 36
    Layout.maximumHeight: 36
    Layout.fillWidth: vertical
    Layout.fillHeight: !vertical
    width: 36; height: 36
    clip: false

    HoverHandler { onHoveredChanged: root.isHovered = hovered }

    // ── Toggle button background ──
    StyledRect {
        id: toggleBtn
        anchors.fill: parent
        variant: "bg"
        enableShadow: root.layerEnabled && Config.showBackground
        topLeftRadius: root.vertical ? root.startRadius : root.startRadius
        topRightRadius: root.endRadius
        bottomLeftRadius: root.vertical ? root.endRadius : root.startRadius
        bottomRightRadius: root.endRadius

        Rectangle {
            anchors.fill: parent
            color: Styling.srItem("overprimary")
            opacity: root.isHovered ? 0.25 : 0
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
            visible: _vc > 0 && !root.expanded
            Text {
                anchors.centerIn: parent
                text: Math.min(_vc, 9)
                font.family: Config.theme.font; font.pixelSize: 8; font.bold: true; color: Colors.background
            }
        }
    }

    // ── Click receiver (on top of everything inside toggleBtn) ──
    MouseArea {
        anchors.fill: parent
        z: 100
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            console.log("TaskTray click:", mouse.button);
            if (mouse.button === Qt.LeftButton) {
                root.expanded = !root.expanded;
            } else {
                setPopup.open();
            }
        }
    }

    StyledToolTip {
        visible: root.isHovered && !root.expanded
        tooltipText: _vc > 0 ? _vc + " visible" : "No icons"
    }

    // ── Floating dock ──
    StyledRect {
        id: dock
        anchors.left: parent.right; anchors.leftMargin: 2
        anchors.verticalCenter: parent.verticalCenter
        height: 30
        width: _vc > 0 ? Math.min(_vc, 10) * 28 + 10 : 40
        variant: "bg"; radius: 6
        enableShadow: root.layerEnabled && Config.showBackground
        visible: root.expanded && _n > 0

        opacity: root.expanded ? 1.0 : 0.0
        scale: root.expanded ? 1.0 : 0.8
        transformOrigin: Item.LeftCenter
        Behavior on opacity { NumberAnimation { duration: Config.animDuration > 0 ? Config.animDuration / 2 : 100 } }
        Behavior on scale { NumberAnimation { duration: Config.animDuration > 0 ? Config.animDuration / 2 : 100; easing.type: Easing.OutCubic } }

        RowLayout {
            anchors.centerIn: parent; spacing: 2
            Repeater {
                model: SystemTray && SystemTray.items ? SystemTray.items : []
                delegate: Item {
                    required property SystemTrayItem modelData
                    required property int index
                    width: 26; height: 26
                    readonly property string _k: root._key(index, modelData)
                    visible: root._hid.indexOf(_k) < 0
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
                    Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; height: 1; color: Colors.outlineVariant; visible: sep }
                    StyledRect {
                        anchors.fill: parent; radius: 4; variant: mm.containsMouse ? "focus" : "bg"; visible: !sep
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 8; spacing: 6
                            IconImage { width: 16; height: 16; source: modelData.icon ?? ""; smooth: true; visible: modelData.icon !== undefined; Layout.alignment: Qt.AlignVCenter }
                            Text { text: modelData.text || ""; font.family: Styling.defaultFont; font.pixelSize: Styling.fontSize(-1); color: Colors.overBackground; elide: Text.ElideRight; Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter }
                        }
                    }
                    MouseArea { id: mm; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true; onClicked: { if (modelData.trigger) modelData.trigger(); ctxPopup.close(); root._ctxItem = null; } }
                }
            }
        }
    }

    // ── Settings popup ──
    BarPopup {
        id: setPopup; anchorItem: root; bar: root.bar
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 6; spacing: 2
            Text {
                text: "Tray Icons (" + _vc + "/" + _n + ")"
                font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-1); font.bold: true
                color: Colors.overBackground
                Layout.fillWidth: true; Layout.bottomMargin: 4; leftPadding: 4
            }
            Repeater {
                model: SystemTray && SystemTray.items ? SystemTray.items : []
                delegate: Item {
                    required property SystemTrayItem modelData
                    required property int index
                    Layout.fillWidth: true; Layout.preferredHeight: 34
                    readonly property string _k: root._key(index, modelData)

                    MouseArea {
                        id: rowMA
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: event => {
                            if (event.button === Qt.LeftButton) { modelData.activate(); setPopup.close(); }
                            else if (event.button === Qt.RightButton && modelData.hasMenu) {
                                root._ctxItem = modelData; ctxPopup.open();
                            }
                        }
                    }

                    StyledRect {
                        anchors.fill: parent; radius: 4
                        variant: rowMA.containsMouse ? "focus" : "bg"
                        opacity: rowMA.containsMouse ? 1.0 : 0.7
                    }

                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6; spacing: 8
                        Text {
                            text: root._hid.indexOf(_k) >= 0 ? Icons.circleNotch : Icons.circle
                            font.family: Icons.font; font.pixelSize: 16
                            color: root._hid.indexOf(_k) >= 0 ? Colors.outline : Styling.srItem("primary")
                            Layout.alignment: Qt.AlignVCenter
                            MouseArea {
                                anchors.fill: parent; anchors.margins: -4
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { root._toggle(_k); mouse.accepted = true; }
                            }
                        }
                        IconImage { width: 20; height: 20; source: modelData.icon; smooth: true; Layout.alignment: Qt.AlignVCenter }
                        Text {
                            text: modelData.tooltipTitle || modelData.title || "App #" + (index + 1)
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
