import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.config

Item {
    id: root

    signal clicked()

    property string textStr: ""

    readonly property string cleanText: {
        let t = textStr;
        if (!t) return "";
        t = String(t);
        var m = t.match(/^:\/\/+\s*/); if (m) t = t.substring(m[0].length);
        return t.trim();
    }

    property var iconSource: ""
    property bool isImageIcon: false
    property bool isSeparator: false
    property bool hasSubmenu: false
    property bool expanded: false
    property int depth: 0
    property int buttonType: 0
    property int checkState: 0

    implicitWidth: 200
    implicitHeight: isSeparator ? 10 : 36

    // Capturar clics directamente sin Button
    MouseArea {
        id: clickArea
        anchors.fill: parent
        enabled: !root.isSeparator
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true

        onClicked: {
            if (root.isSeparator) return;
            root.clicked();
        }
    }

    // Fondo
    Rectangle {
        anchors.fill: parent
        color: isSeparator ? "transparent" : (clickArea.containsMouse ? Styling.srItem("overprimary") : "transparent")
        radius: Styling.radius(0)

        Rectangle {
            visible: root.isSeparator
            height: 1
            color: Colors.surfaceBright
            anchors.centerIn: parent
            width: parent.width - 16
        }
    }

    // Contenido
    RowLayout {
        spacing: 8
        visible: !root.isSeparator
        anchors.fill: parent
        anchors.leftMargin: 8 + root.depth * 12
        anchors.rightMargin: 8

        // Check/Radio indicator
        Item {
            visible: root.buttonType > 0
            Layout.preferredWidth: 16
            Layout.preferredHeight: 16

            Rectangle {
                visible: root.buttonType === 1
                anchors.centerIn: parent; width: 14; height: 14; radius: 3
                color: root.checkState === Qt.Unchecked ? "transparent" : Colors.primary
                border.color: root.checkState === Qt.Unchecked ? Colors.outline : Colors.primary
                border.width: 1.5
                Text {
                    anchors.centerIn: parent
                    visible: root.checkState !== Qt.Unchecked
                    text: root.checkState === Qt.PartiallyChecked ? "\u2212" : "\u2713"
                    color: Colors.overPrimary; font.pixelSize: 10; font.bold: true
                }
            }

            Rectangle {
                visible: root.buttonType === 2
                anchors.centerIn: parent; width: 14; height: 14; radius: 7
                color: "transparent"
                border.color: root.checkState === Qt.Checked ? Colors.primary : Colors.outline
                border.width: 1.5
                Rectangle {
                    anchors.centerIn: parent; visible: root.checkState === Qt.Checked
                    width: 7; height: 7; radius: 4; color: Colors.primary
                }
            }
        }

        // Icon
        Loader {
            Layout.preferredWidth: 16; Layout.preferredHeight: 16
            visible: root.iconSource !== "" && root.buttonType === 0
            sourceComponent: root.isImageIcon ? imageIcon : fontIcon
            Component {
                id: fontIcon
                Text {
                    text: root.iconSource
                    font.family: Icons.font; font.pixelSize: 14
                    color: clickArea.containsMouse ? Colors.overPrimary : Colors.overBackground
                }
            }
            Component {
                id: imageIcon
                Image {
                    source: root.iconSource
                    fillMode: Image.PreserveAspectFit; mipmap: true
                }
            }
        }

        // Text
        Text {
            Layout.fillWidth: true
            text: root.cleanText
            color: clickArea.containsMouse ? Colors.overPrimary : Colors.overBackground
            font.family: Config.theme.font; font.pixelSize: Styling.fontSize(0)
            elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter
        }

        // Submenu chevron
        Text {
            visible: root.hasSubmenu
            text: root.expanded ? "\u25BE" : "\u25B8"
            color: clickArea.containsMouse ? Colors.overPrimary : Colors.overBackground
            font.pixelSize: Styling.fontSize(0); verticalAlignment: Text.AlignVCenter
        }
    }
}
