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

    function _key(i, it) {
        return i + "_" + (it.title || it.tooltipTitle || it.id || "t" + i);
    }

    // Explicit _vc property (no readonly binding — updated by _recalc)
    property int _vc: 0
    function _recalc() {
        try {
            if (!SystemTray || !SystemTray.items) { _vc = 0; return; }
            var len = SystemTray.items && SystemTray.items.length;
            if (!len) { _vc = 0; return; }
            if (_hid.length === 0) { _vc = len; return; }
            var n = 0;
            for (var i = 0; i < len; i++) {
                var it = SystemTray.items[i];
                if (it && _hid.indexOf(root._key(i, it)) < 0) n++;
            }
            _vc = n;
        } catch(e) {
            console.warn('_recalc:', e);
            _vc = 0;
        }
    }
    function _toggle(k) {
        var a = _hid.slice();
        var i = a.indexOf(k);
        if (i >= 0) a.splice(i, 1); else a.push(k);
        _hid = a;
        _recalc();
    }

    // Repeater count (reliable — detects model changes internally)
    property int _dockN: dockRep ? dockRep.count : 0
    property int _setN: setRep ? setRep.count : 0

    Connections { target: dockRep; function onCountChanged() { _dockN = dockRep.count; _setN = setRep.count; _recalc(); } }
    Connections { target: setRep; function onCountChanged() { _setN = setRep.count; _recalc(); } }
    Component.onCompleted: _recalc()

    readonly property int _dw: expanded && _setN > 0 ? Math.max(40, Math.min(_vc, 10) * 32 + 10) : 0

    Layout.preferredWidth: 36 + (expanded ? 2 + _dw : 0)
    Layout.preferredHeight: 36
    Layout.fillWidth: vertical
    Layout.fillHeight: !vertical
    height: 36

    Behavior on Layout.preferredWidth {
        enabled: !vertical && Config.animDuration > 0
        NumberAnimation { duration: Config.animDuration / 2; easing.type: Easing.OutCubic }
    }

    HoverHandler { onHoveredChanged: root.isHovered = hovered }

    // ── Toggle button ──
    StyledRect {
        id: toggleBtn
        width: 36
        anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
        variant: "bg"
        enableShadow: root.layerEnabled && Config.showBackground
        topLeftRadius: root.vertical ? root.startRadius : root.startRadius
        topRightRadius: root.expanded ? 0 : root.endRadius
        bottomLeftRadius: root.vertical ? root.endRadius : root.startRadius
        bottomRightRadius: root.expanded ? 0 : root.endRadius

        Rectangle {
            anchors.fill: parent
            color: Styling.srItem("overprimary")
            rotation: root.expanded ? 90 : 0
            Behavior on rotation {
                enabled: Config.animDuration > 0
                NumberAnimation { duration: Config.animDuration / 2; easing.type: Easing.OutCubic }
            }
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
            rotation: root.expanded ? 90 : 0
            Behavior on rotation {
                enabled: Config.animDuration > 0
                NumberAnimation { duration: Config.animDuration / 2; easing.type: Easing.OutCubic }
            }
        }


        MouseArea {
            anchors.fill: parent; z: 5; cursorShape: Qt.PointingHandCursor
            onClicked: event => {
                root.expanded = !root.expanded;
            }
        }

        StyledToolTip {
            visible: root.isHovered && !root.expanded
            tooltipText: _vc > 0 ? _vc + " visible" : "No icons"
        }
    }

    // ── Expanded inline dock ──
    StyledRect {
        id: dockBg
        anchors.left: toggleBtn.right; anchors.right: parent.right
        anchors.top: parent.top; anchors.bottom: parent.bottom
        visible: expanded && _dockN > 0
        variant: "bg"; enableShadow: false; clip: true
        topLeftRadius: 0; topRightRadius: root.expanded ? 0 : root.endRadius
        bottomLeftRadius: 0; bottomRightRadius: root.expanded ? 0 : root.endRadius
        opacity: expanded ? 1.0 : 0.0
        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation { duration: Config.animDuration / 2 }
        }

        RowLayout {
            anchors.centerIn: parent; spacing: 4
            Repeater {
                id: dockRep
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
        contentWidth: Math.max(220, ctxCol.implicitWidth + 16)
        contentHeight: Math.min(ctxCol.implicitHeight + 16, 400)
        QsMenuOpener { id: mo; menu: root._ctxItem ? root._ctxItem.menu : null }
        ColumnLayout {
            id: ctxCol
            anchors.fill: parent; anchors.margins: 4; spacing: 4
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
                            IconImage { width: 18; height: 18; source: modelData.icon ?? ""; smooth: true; visible: modelData.icon !== undefined; Layout.alignment: Qt.AlignVCenter }
                            Text { text: modelData.text || ""; font.family: Styling.defaultFont; font.pixelSize: Styling.fontSize(-1); color: Colors.overBackground; elide: Text.ElideRight; Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter }
                        }
                    }
                    MouseArea { id: mm; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true; onClicked: event => { if (modelData.trigger) modelData.trigger(); ctxPopup.close(); root._ctxItem = null; } }
                }
            }
        }
    }

    // ── Settings popup ──
    BarPopup {
        id: setPopup; anchorItem: root; bar: root.bar
        contentWidth: setCol.implicitWidth + 16
        contentHeight: Math.min(setCol.implicitHeight + 16, 400)
        ColumnLayout {
            id: setCol
            anchors.fill: parent; anchors.margins: 6; spacing: 4
            Text {
                text: "Tray (" + _vc + "/" + _setN + ")"
                font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-1); font.bold: true
                color: Colors.overBackground
                Layout.fillWidth: true; Layout.bottomMargin: 4; leftPadding: 4
            }
            Repeater {
                id: setRep
                model: SystemTray && SystemTray.items ? SystemTray.items : []
                delegate: Item {
                    required property SystemTrayItem modelData
                    required property int index
                    Layout.fillWidth: true; Layout.preferredHeight: 34
                    readonly property string _k: root._key(index, modelData)

                    // Row click (declared FIRST for correct stacking)
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
                                onClicked: event => { root._toggle(_k); event.accepted = true; }
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
