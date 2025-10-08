import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

Item {
    id: root

    required property string itemName
    required property string itemPath
    required property string itemType
    required property string itemIcon
    property bool isDesktopFile: false

    signal activated
    signal contextMenuRequested

    width: Config.desktop.iconSize + Config.desktop.spacing
    height: Config.desktop.iconSize + 40

    Rectangle {
        id: background
        anchors.fill: parent
        anchors.margins: 4
        color: hoverHandler.hovered ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.3) : "transparent"
        radius: Config.roundness / 2

        Behavior on color {
            ColorAnimation {
                duration: Config.animDuration / 2
                easing.type: Easing.OutCubic
            }
        }
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        onDoubleTapped: {
            root.activated();

            if (root.isDesktopFile) {
                console.log("Executing desktop file:", root.itemPath);
                DesktopService.executeDesktopFile(root.itemPath);
            } else if (root.itemType === 'folder') {
                console.log("Opening folder:", root.itemPath);
                DesktopService.openFile(root.itemPath);
            } else {
                console.log("Opening file:", root.itemPath);
                DesktopService.openFile(root.itemPath);
            }
        }
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: {
            root.contextMenuRequested();
        }
    }

    HoverHandler {
        id: hoverHandler
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 4

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Config.desktop.iconSize
            Layout.preferredHeight: Config.desktop.iconSize

            Loader {
                anchors.centerIn: parent
                width: Config.desktop.iconSize
                height: Config.desktop.iconSize
                sourceComponent: Config.tintIcons ? tintedIconComponent : normalIconComponent
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            text: root.itemName
            color: Colors[Config.desktop.textColor] || Colors.overBackground
            font.family: Config.defaultFont
            font.pixelSize: Config.theme.fontSize
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight

            Rectangle {
                anchors.fill: parent
                anchors.margins: -2
                color: Qt.rgba(0, 0, 0, 0.6)
                radius: 4
                z: -1
            }
        }
    }

    Component {
        id: normalIconComponent
        Image {
            source: "image://icon/" + root.itemIcon
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: true

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.color: Colors.outline
                border.width: parent.status === Image.Error ? 1 : 0
                radius: 4

                Text {
                    anchors.centerIn: parent
                    text: root.itemType === 'folder' ? "📁" : "📄"
                    visible: parent.parent.status === Image.Error
                    font.pixelSize: Config.desktop.iconSize / 2
                }
            }
        }
    }

    Component {
        id: tintedIconComponent
        Tinted {
            sourceItem: Image {
                source: "image://icon/" + root.itemIcon
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
            }
        }
    }
}
