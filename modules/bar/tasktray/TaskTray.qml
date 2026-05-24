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
import QtQuick

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
    // Repeater count (reliable — detects model changes internally)
    property int _dockN: dockRep ? dockRep.count : 0
    

    
    
    

    readonly property int _dw: expanded && _dockN > 0 ? Math.max(40, Math.min(_dockN, 10) * 32 + 10) : 0

    Layout.preferredWidth: 36 + (expanded ? 2 + _dw : 0)
    Layout.preferredHeight: 36
    Layout.fillWidth: vertical
    Layout.fillHeight: !vertical
    height: 36

    Behavior on Layout.preferredWidth {
        enabled: !vertical && Config.animDuration > 0
        NumberAnimation { duration: Config.animDuration / 2; easing.type: Easing.OutCubic }
    }

    Connections { target: dockRep; function onCountChanged() { _dockN = dockRep.count; } }
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
            onClicked: {
                root.expanded = !root.expanded;
        }
        }

        StyledToolTip {
            visible: root.isHovered && !root.expanded
            tooltipText: _dockN > 0 ? _dockN + " visible" : "No icons"
        }
    }

    // ── Expanded inline dock ──
    StyledRect {
        id: dockBg
        anchors.left: toggleBtn.right; anchors.right: parent.right
        anchors.top: parent.top; anchors.bottom: parent.bottom
        visible: expanded && _dockN > 0
        variant: "bg"; enableShadow: false; clip: true
        topLeftRadius: 0; topRightRadius: root.endRadius
        bottomLeftRadius: 0; bottomRightRadius: root.endRadius
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
                    width: 24; height: 24
property bool hov: false
                    HoverHandler { onHoveredChanged: hov = hovered }
                    StyledRect {
                        anchors.fill: parent; anchors.margins: 1; radius: 4
                        variant: "bg"; opacity: hov ? 0.5 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 80 } }
                }
                    IconImage {
                        anchors.centerIn: parent; width: 16; height: 16
                        source: modelData.icon; smooth: true
                }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
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
                            IconImage { width: 16; height: 16; source: modelData.icon ?? ""; smooth: true; visible: modelData.icon !== undefined; Layout.alignment: Qt.AlignVCenter }
                            Text { text: modelData.text || ""; font.family: Styling.defaultFont; font.pixelSize: Styling.fontSize(-1); color: Colors.overBackground; elide: Text.ElideRight; Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter }
                    }
                }
                    MouseArea { id: mm; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true; onClicked: { if (modelData.trigger) modelData.trigger(); ctxPopup.close(); root._ctxItem = null; } }
            }
        }
        }
    }

}
