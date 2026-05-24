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
    property int _t: 0
    Timer { interval: 2000; repeat: true; running: true; onTriggered: _t++; }

    readonly property int _n: { _t; return SystemTray && SystemTray.items ? SystemTray.items.length : 0; }
    readonly property int _dw: expanded && _n > 0 ? Math.min(_n, 10) * 32 + 10 : 0

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
            visible: _n > 0 && !root.expanded
            Text {
                anchors.centerIn: parent
                text: Math.min(_n, 9)
                font.family: Config.theme.font; font.pixelSize: 8; font.bold: true; color: Colors.background
            }
        }
        StyledToolTip {
            visible: root.isHovered && !root.expanded
            tooltipText: _n > 0 ? _n + " tray icons" : "No tray icons"
        }
    }

    MouseArea {
        anchors.fill: parent; z: 5; cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => {
            if (event.button === Qt.LeftButton) root.expanded = !root.expanded;
            else if (_n > 0) setPopup.open();
        }
    }

    StyledRect {
        id: dockBg
        anchors.left: toggleBtn.right; anchors.right: parent.right
        anchors.top: parent.top; anchors.bottom: parent.bottom
        visible: expanded && _n > 0
        variant: "bg"; enableShadow: false; clip: true
        topLeftRadius: 0; topRightRadius: root.endRadius
        bottomLeftRadius: 0; bottomRightRadius: root.endRadius
        opacity: expanded ? 1.0 : 0.0
        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation { duration: Config.animDuration / 2 }
        }
        RowLayout { anchors.centerIn: parent; spacing: 4
            Repeater {
                id: dockRep
                model: SystemTray && SystemTray.items ? SystemTray.items : []
                delegate: Item {
                    required property SystemTrayItem modelData
                    required property int index
                    width: 26; height: 26
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

    BarPopup {
        id: ctxPopup; anchorItem: root; bar: root.bar
        contentWidth: 240; contentHeight: Math.min(ctxCol.implicitHeight + 16, 400)
        QsMenuOpener { id: mo; menu: root._ctxItem ? root._ctxItem.menu : null }
        ColumnLayout { id: ctxCol; anchors.fill: parent; anchors.margins: 4; spacing: 2
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
                    MouseArea { id: mm; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true; onClicked: event => { if (modelData.trigger) modelData.trigger(); ctxPopup.close(); root._ctxItem = null; } }
                }
            }
        }
    }

    BarPopup {
        id: setPopup; anchorItem: root; bar: root.bar
        contentWidth: setCol.implicitWidth + 16; contentHeight: Math.min(setCol.implicitHeight + 16, 400)
        ColumnLayout { id: setCol; anchors.fill: parent; anchors.margins: 6; spacing: 2
            Text {
                text: "Tray (" + _n + ")"
                font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-1); font.bold: true
                color: Colors.overBackground; Layout.fillWidth: true; Layout.bottomMargin: 4; leftPadding: 4
            }
            Repeater {
                id: setRep
                model: SystemTray && SystemTray.items ? SystemTray.items : []
                delegate: Item {
                    required property SystemTrayItem modelData
                    required property int index
                    Layout.fillWidth: true; Layout.preferredHeight: 32
                    StyledRect {
                        anchors.fill: parent; radius: 4
                        variant: rowMA.containsMouse ? "focus" : "bg"
                        opacity: rowMA.containsMouse ? 1.0 : 0.7
                    }
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6; spacing: 8
                        IconImage { width: 20; height: 20; source: modelData.icon; smooth: true; Layout.alignment: Qt.AlignVCenter }
                        Text {
                            text: modelData.tooltipTitle || modelData.title || "App #" + (index + 1)
                            font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-2)
                            color: Colors.overBackground; elide: Text.ElideRight
                            Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter
                        }
                    }
                    MouseArea {
                        id: rowMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: event => {
                            if (event.button === Qt.LeftButton) { modelData.activate(); setPopup.close(); }
                            else if (event.button === Qt.RightButton && modelData.hasMenu) {
                                root._ctxItem = modelData; ctxPopup.open();
                            }
                        }
                    }
                }
            }
            Item { Layout.fillHeight: true }
        }
    }
}
