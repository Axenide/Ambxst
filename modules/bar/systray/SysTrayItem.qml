import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.components
import qs.config

MouseArea {
    id: root

    required property var bar
    required property SystemTrayItem item
    property int trayItemSize: 20
    property bool isHovered: false

    acceptedButtons: Qt.LeftButton | Qt.RightButton
    Layout.fillHeight: bar.orientation === "horizontal"
    Layout.fillWidth: bar.orientation === "vertical"
    implicitWidth: trayItemSize
    implicitHeight: trayItemSize

    // Popup de prueba para verificar clicks
    Popup {
        id: testPopup
        x: popupX; y: popupY
        width: 200; height: 150

        background: Rectangle {
            color: Colors.background
            border.color: Colors.surfaceBright
            border.width: 2
            radius: 8
        }

        Column {
            anchors.centerIn: parent
            spacing: 10
            Text { text: "RIGHT CLICK WORKS!"; color: Colors.overPrimary; font.bold: true }
            Button {
                text: "Cerrar"
                onClicked: testPopup.close()
            }
        }
    }

    property real popupX: 0
    property real popupY: 0

    onClicked: event => {
        switch (event.button) {
        case Qt.LeftButton:
            item.activate();
            break;
        case Qt.RightButton:
            popupX = event.x;
            popupY = event.y;
            testPopup.open();
            break;
        }
        event.accepted = true;
    }

    // DEBUG: borde rojo para confirmar que este código está cargado
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.color: "red"
        border.width: 2
        radius: 4
    }

    IconImage {
        id: trayIcon
        source: {
            const iconPath = root.item.icon.toString();
            if (iconPath.includes("spotify")) {
                return Quickshell.iconPath("spotify-client");
            }
            return root.item.icon;
        }
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        smooth: true
    }

    Tinted {
        sourceItem: trayIcon
        anchors.fill: trayIcon
    }

    StyledToolTip {
        show: root.isHovered
        tooltipText: root.item.tooltipTitle || root.item.title
        desciription: root.item.tooltipDescription || ""
    }

    HoverHandler {
        onHoveredChanged: root.isHovered = hovered
    }
}
