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
    readonly property var allItems: SystemTray.items || []

    // Per-item visibility
    property var hiddenMap: ({})
    function isHidden(item) {
        var key = (item.title || item.tooltipTitle || "").toLowerCase();
        return hiddenMap[key] === true;
    }
    function toggleHidden(item) {
        var key = (item.title || item.tooltipTitle || "").toLowerCase();
        var h = Object.assign({}, root.hiddenMap);
        h[key] = !h[key];
        root.hiddenMap = h;
    }

    readonly property int totalCount: allItems.length
    readonly property int visibleCount: {
        var n = 0;
        for (var i = 0; i < allItems.length; i++) {
            if (!root.isHidden(allItems[i])) n++;
        }
        return n;
    }

    property var contextItem: null

    // ── Dynamic sizing: grows when expanded ──
    readonly property int dockW: expanded && visibleCount > 0 ? visibleCount * 28 + 10 : 0
    Layout.preferredWidth: 36 + (expanded ? 2 + dockW : 0)
    Layout.preferredHeight: 36
    Layout.fillWidth: vertical
    Layout.fillHeight: !vertical
    width: 36 + (expanded ? 2 + dockW : 0)
    height: 36

    Behavior on Layout.preferredWidth {
        enabled: !vertical && Config.animDuration > 0
        NumberAnimation { duration: Config.animDuration / 2; easing.type: Easing.OutCubic }
    }

    HoverHandler { onHoveredChanged: root.isHovered = hovered }

    // ── Toggle button (always 36px on the left) ──
    StyledRect {
        id: toggleBtn
        anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
        width: 36
        variant: "bg"
        enableShadow: root.layerEnabled && Config.showBackground
        z: 2

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

    // ── Expanded dock (inline, to the right of toggle) ──
    StyledRect {
        id: dockBg
        anchors.left: toggleBtn.right; anchors.right: parent.right
        anchors.top: parent.top; anchors.bottom: parent.bottom
        visible: expanded && visibleCount > 0
        variant: "bg"
        enableShadow: false
        clip: true

        topLeftRadius: 0
        topRightRadius: root.endRadius
        bottomLeftRadius: 0
        bottomRightRadius: root.endRadius

        opacity: expanded ? 1.0 : 0.0
        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation { duration: Config.animDuration / 2 }
        }

        RowLayout {
            anchors.centerIn: parent
            spacing: 2

            Repeater {
                model: root.allItems

                delegate: Item {
                    required property SystemTrayItem modelData
                    width: 26; height: 26
                    visible: !root.isHidden(modelData)
                    property bool hov: false

                    HoverHandler { onHoveredChanged: hov = hovered }

                    StyledRect {
                        anchors.fill: parent; anchors.margins: 1; radius: 4
                        variant: "bg"
                        opacity: hov ? 0.5 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 80 } }
                    }

                    IconImage {
                        anchors.centerIn: parent; width: 18; height: 18
                        source: modelData.icon; smooth: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: event => {
                            if (event.button === Qt.LeftButton) {
                                modelData.activate();
                            } else if (event.button === Qt.RightButton && modelData.hasMenu) {
                                root.contextItem = modelData;
                                ctxPopup.open();
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

    // ── Settings popup (right-click on toggle) ──
    BarPopup {
        id: settingsPopup; anchorItem: toggleBtn; bar: root.bar

        ColumnLayout {
            anchors.fill: parent; anchors.margins: 6; spacing: 2

            Text {
                text: "Tray Icons (" + visibleCount + "/" + totalCount + ")"
                font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-1)
                font.bold: true; color: Colors.overBackground
                Layout.fillWidth: true; Layout.bottomMargin: 4; leftPadding: 4
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

                        Text {
                            text: root.isHidden(modelData) ? Icons.circleNotch : Icons.circle
                            font.family: Icons.font; font.pixelSize: 16
                            color: root.isHidden(modelData) ? Colors.outline : Styling.srItem("primary")
                            Layout.alignment: Qt.AlignVCenter
                            MouseArea {
                                anchors.fill: parent; anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleHidden(modelData)
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
                            if (event.button === Qt.LeftButton) {
                                modelData.activate(); settingsPopup.close();
                            } else if (event.button === Qt.RightButton && modelData.hasMenu) {
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
