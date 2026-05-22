import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.config

Button {
    id: root

    property string textStr: ""

    // Clean text logic from ContextMenu.qml
    readonly property string cleanText: {
        let t = textStr;
        if (!t) return "";
        t = String(t);
        if (t.startsWith(":/// ")) {
            t = t.substring(5);
        }
        return t.trim();
    }

    property var iconSource: ""
    property bool isImageIcon: false
    property bool isSeparator: false
    property bool hasSubmenu: false
    property bool expanded: false
    property int depth: 0
    // 0 = None, 1 = CheckBox, 2 = RadioButton
    property int buttonType: 0
    // Qt.Unchecked = 0, Qt.PartiallyChecked = 1, Qt.Checked = 2
    property int checkState: 0

    implicitWidth: 200
    implicitHeight: isSeparator ? 10 : 36
    enabled: !isSeparator

    // Reset default styling
    padding: 0
    background: Rectangle {
        color: {
            if (root.isSeparator) return "transparent"
            return root.hovered ? Styling.srItem("overprimary") : "transparent"
        }
        radius: Styling.radius(0)

        // Separator line
        Rectangle {
            visible: root.isSeparator
            height: 1
            color: Colors.surfaceBright
            anchors.centerIn: parent
            width: parent.width - 16
        }
    }

    contentItem: RowLayout {
        spacing: 8
        visible: !root.isSeparator

        // Add margins for content
        anchors.fill: parent
        anchors.leftMargin: 8 + root.depth * 12
        anchors.rightMargin: 8

        // Check/Radio indicator
        Item {
            visible: root.buttonType > 0
            Layout.preferredWidth: 16
            Layout.preferredHeight: 16

            // Checkbox
            Rectangle {
                visible: root.buttonType === 1
                anchors.centerIn: parent
                width: 14
                height: 14
                radius: 3
                color: root.checkState === Qt.Unchecked ? "transparent" : Colors.primary
                border.color: root.checkState === Qt.Unchecked ? Colors.outline : Colors.primary
                border.width: 1.5

                Text {
                    anchors.centerIn: parent
                    visible: root.checkState !== Qt.Unchecked
                    text: root.checkState === Qt.PartiallyChecked ? "\u2212" : "\u2713"
                    color: Colors.overPrimary
                    font.pixelSize: 10
                    font.bold: true
                }
            }

            // RadioButton
            Rectangle {
                visible: root.buttonType === 2
                anchors.centerIn: parent
                width: 14
                height: 14
                radius: 7
                color: "transparent"
                border.color: root.checkState === Qt.Checked ? Colors.primary : Colors.outline
                border.width: 1.5

                Rectangle {
                    anchors.centerIn: parent
                    visible: root.checkState === Qt.Checked
                    width: 7
                    height: 7
                    radius: 4
                    color: Colors.primary
                }
            }
        }

        // Icon
        Loader {
            Layout.preferredWidth: 16
            Layout.preferredHeight: 16
            visible: root.iconSource !== "" && root.buttonType === 0
            sourceComponent: root.isImageIcon ? imageIcon : fontIcon

            Component {
                id: fontIcon
                Text {
                    text: root.iconSource
                    font.family: Icons.font
                    font.pixelSize: 14
                    color: root.hovered ? Colors.overPrimary : Colors.overBackground
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Component {
                id: imageIcon
                Image {
                    source: root.iconSource
                    fillMode: Image.PreserveAspectFit
                    mipmap: true
                }
            }
        }

        // Text
        Text {
            Layout.fillWidth: true
            text: root.cleanText
            color: root.hovered ? Colors.overPrimary : Colors.overBackground
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(0)
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }

        // Submenu chevron
        Text {
            visible: root.hasSubmenu
            text: root.expanded ? "\u25BE" : "\u25B8"
            color: root.hovered ? Colors.overPrimary : Colors.overBackground
            font.pixelSize: Styling.fontSize(0)
            verticalAlignment: Text.AlignVCenter
        }
    }
}
