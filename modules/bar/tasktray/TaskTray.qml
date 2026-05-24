import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config

StyledRect {
    id: root

    required property var bar
    property bool vertical: bar.orientation === "vertical"
    property bool isHovered: false
    property bool layerEnabled: true
    property real radius: 0
    property real startRadius: radius
    property real endRadius: radius

    variant: "bg"
    enableShadow: root.layerEnabled && Config.showBackground
    Layout.preferredWidth: 36
    Layout.preferredHeight: 36
    Layout.maximumWidth: 36
    Layout.maximumHeight: 36
    Layout.fillWidth: vertical
    Layout.fillHeight: !vertical

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

    HoverHandler { onHoveredChanged: root.isHovered = hovered }

    MouseArea {
        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
        onClicked: trayPopup.isOpen ? trayPopup.close() : trayPopup.open()
    }

    StyledToolTip {
        visible: root.isHovered
        tooltipText: "System tray"
    }

    BarPopup {
        id: trayPopup
        anchorItem: root
        bar: root.bar

        RowLayout {
            anchors.fill: parent; anchors.margins: 6; spacing: 4
            Repeater {
                model: SystemTray && SystemTray.items ? SystemTray.items : []
                delegate: MouseArea {
                    required property SystemTrayItem modelData
                    width: 28; height: 28
                    cursorShape: Qt.PointingHandCursor
                    property bool hov: false
                    HoverHandler { onHoveredChanged: hov = hovered }
                    StyledRect {
                        anchors.fill: parent; anchors.margins: 1; radius: 5
                        variant: "bg"
                        opacity: hov ? 0.5 : 0.0
                    }
                    IconImage {
                        anchors.centerIn: parent; width: 22; height: 22
                        source: modelData.icon; smooth: true
                    }
                    onClicked: {
                        modelData.activate();
                        trayPopup.close();
                    }
                }
            }
        }
    }
}
