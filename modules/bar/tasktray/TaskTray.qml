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

    property int _dockN: dockRep ? dockRep.count : 0
    property int _setN: setRep ? setRep.count : 0

    Connections { target: dockRep; function onCountChanged() { _dockN = dockRep.count; _setN = setRep.count; _recalc(); } }
    Connections { target: setRep; function onCountChanged() { _setN = setRep.count; _recalc(); } }
    Component.onCompleted: _recalc()

    readonly property int _dw: expanded && dockRep.count > 0 ? Math.max(40, Math.min(dockRep.count, 10) * 40 + 10) : 0

    Layout.preferredWidth: root.vertical ? 36 : (36 + (expanded ? 2 + _dw : 0))
    Layout.preferredHeight: root.vertical ? (36 + (expanded ? 2 + _dw : 0)) : 36
    Layout.fillWidth: vertical
    Layout.fillHeight: !vertical
    clip: true

    Behavior on Layout.preferredHeight {
        enabled: root.vertical && Config.animDuration > 0
        NumberAnimation { duration: Config.animDuration / 2; easing.type: Easing.OutCubic }
    }

    Behavior on Layout.preferredWidth {
        enabled: !root.vertical && Config.animDuration > 0
        NumberAnimation { duration: Config.animDuration / 2; easing.type: Easing.OutCubic }
    }

    HoverHandler { onHoveredChanged: root.isHovered = hovered }

    StyledRect {
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
            opacity: root.isHovered && !root.expanded ? 0.25 : 0
            radius: parent.radius ?? 0
            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation { duration: Config.animDuration / 2 }
            }
        }
    }

    Text {
        x: 9; y: 9
        text: Icons.dotsThree; font.family: Icons.font; font.pixelSize: 18
        color: Styling.srItem("overprimary")
        rotation: root.expanded ? 90 : 0
        Behavior on rotation {
            enabled: Config.animDuration > 0
            NumberAnimation { duration: Config.animDuration / 2; easing.type: Easing.OutCubic }
        }
    }

    MouseArea {
        anchors.fill: parent; z: 20; cursorShape: Qt.PointingHandCursor
        onClicked: event => { root.expanded = !root.expanded; }
    }

    StyledToolTip {
        visible: root.isHovered && !root.expanded
        tooltipText: _vc > 0 ? _vc + " visible" : "No icons"
    }

    RowLayout {
        visible: !root.vertical
        opacity: expanded ? 1.0 : 0.0
        Behavior on opacity { enabled: Config.animDuration > 0; NumberAnimation { duration: Config.animDuration / 2 } }
        anchors.left: root.vertical ? undefined : parent.left
        anchors.leftMargin: root.vertical ? 0 : 40
        anchors.verticalCenter: root.vertical ? undefined : parent.verticalCenter
        anchors.top: root.vertical ? parent.top : undefined
        anchors.topMargin: root.vertical ? 40 : 0
        anchors.horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
        spacing: 4
            Repeater {
                id: dockRep
                model: SystemTray && SystemTray.items ? SystemTray.items : []
                delegate: Item {
                    required property SystemTrayItem modelData
                    required property int index
                    width: 36; height: 36
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

    ColumnLayout {
        opacity: expanded ? 1.0 : 0.0
        Behavior on opacity { enabled: Config.animDuration > 0; NumberAnimation { duration: Config.animDuration / 2 } }
        anchors.top: parent.top; anchors.topMargin: 40
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 4
        visible: root.vertical && dockRep.count > 0

        Repeater {
            id: dockRepVert
            model: dockRep.model
            delegate: Item {
                required property SystemTrayItem modelData
                required property int index
                width: 36; height: 36
                visible: true
                StyledRect {
                    anchors.fill: parent; anchors.margins: 1; radius: 4
                    variant: "bg"
                    opacity: 0
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
                        else if (event.button === Qt.RightButton) {
                            root._ctxItem = modelData; ctxPopup.open();
                        }
                    }
                }
            }
        }
    }

    // ── Context menu ──
    BarPopup {
        id: ctxPopup; anchorItem: root; bar: root.bar
        contentWidth: 240
        contentHeight: Math.min(ctxCol.implicitHeight + 16, 400)
        popupPadding: 6; visualMargin: 16

        QsMenuOpener { id: mo; menu: root._ctxItem ? root._ctxItem.menu : null }

        ScrollView {
            anchors.fill: parent; clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                id: ctxCol; width: parent.width; spacing: 2

                Repeater {
                    model: mo.children

                    delegate: Item {
                        required property QsMenuHandle modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32

                        // Separador
                        Rectangle {
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            height: 1; color: Colors.surfaceBright
                            visible: modelData.isSeparator
                            anchors.leftMargin: 8; anchors.rightMargin: 8
                        }

                        readonly property bool _isCheck: modelData.buttonType === 1
                        readonly property bool _isRadio: modelData.buttonType === 2
                        property bool _hover: false

                        // Check/Radio
                        Item {
                            x: 8; y: 8; width: 16; height: 16
                            visible: !modelData.isSeparator && modelData.buttonType !== 0
                            Rectangle {
                                anchors.centerIn: parent; width: 14; height: 14
                                radius: _isRadio ? 7 : 3
                                color: modelData.checkState !== 0 ? Colors.primary : "transparent"
                                border.color: modelData.checkState !== 0 ? Colors.primary : Colors.outline
                                border.width: 1.5
                                Text {
                                    anchors.centerIn: parent
                                    visible: modelData.checkState !== 0 && !_isRadio
                                    text: modelData.checkState === 1 ? "\u2212" : "\u2713"
                                    color: Colors.overPrimary; font.pixelSize: 10; font.bold: true
                                }
                                Rectangle {
                                    anchors.centerIn: parent
                                    visible: modelData.checkState !== 0 && _isRadio
                                    width: 7; height: 7; radius: 4; color: Colors.primary
                                }
                            }
                        }

                        // Icono
                        Text {
                            x: modelData.buttonType !== 0 ? 30 : 10
                            y: 8; width: 16; height: 16
                            visible: !modelData.isSeparator && modelData.icon !== "" && modelData.buttonType === 0
                            text: modelData.icon; font.family: Icons.font; font.pixelSize: 14
                            color: _hover ? Colors.overPrimary : Colors.overBackground
                            verticalAlignment: Text.AlignVCenter
                        }

                        // Texto
                        Text {
                            readonly property real _ix: modelData.buttonType !== 0 ? 30 : (modelData.icon !== "" && modelData.buttonType === 0 ? 30 : 10)
                            x: _ix; y: 6; height: 20
                            width: parent.width - _ix - 22
                            visible: !modelData.isSeparator
                            text: {
                                var t = modelData.text || "";
                                var m = t.match(/^:\/\/+\s*/); if (m) t = t.substring(m[0].length);
                                return t.trim();
                            }
                            color: _hover ? Colors.overPrimary : Colors.overBackground
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(0)
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }

                        // Chevron submenu
                        Text {
                            x: parent.width - 20; y: 8; width: 12; height: 16
                            visible: !modelData.isSeparator && modelData.hasChildren
                            text: "\u25B8"; font.pixelSize: Styling.fontSize(0)
                            color: _hover ? Colors.overPrimary : Colors.overBackground
                            verticalAlignment: Text.AlignVCenter
                        }

                        // Fondo hover
                        Rectangle {
                            anchors.fill: parent; anchors.margins: 2
                            radius: Styling.radius(0)
                            visible: _hover && !modelData.isSeparator
                            color: Styling.srItem("overprimary")
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            enabled: !modelData.isSeparator
                            onEntered: _hover = true
                            onExited: _hover = false
                            onClicked: {
                                if (!modelData.isSeparator) {
                                    modelData.triggered();
                                    ctxPopup.close();
                                    Qt.callLater(() => { root._ctxItem = null; });
                                }
                            }
                        }
                    }
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
