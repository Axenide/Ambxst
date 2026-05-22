import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
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

    readonly property string thumbnailPath: {
        const ext = itemPath.substring(itemPath.lastIndexOf('.') + 1).toLowerCase();
        const videoExts = ['mp4', 'webm', 'mov', 'avi', 'mkv', 'gif'];
        const imageExts = ['jpg', 'jpeg', 'png', 'webp', 'tif', 'tiff', 'bmp'];

        if (itemType === 'folder' || isDesktopFile) {
            return '';
        }

        if (videoExts.includes(ext) || imageExts.includes(ext)) {
            const fileName = itemPath.substring(itemPath.lastIndexOf('/') + 1);
            // QUICKSHELL-GIT: return Quickshell.cacheDir + "/desktop_thumbnails/" + fileName + ".jpg";
            return Quickshell.env("HOME") + "/.cache/ambxst" + "/desktop_thumbnails/" + fileName + ".jpg";
        }

        return '';
    }

    readonly property bool hasThumbnail: thumbnailPath !== '' && Qt.platform.os !== "windows"
    property int thumbnailRefresh: 0

    FileView {
        path: root.thumbnailPath
        watchChanges: root.hasThumbnail

        onFileChanged: {
            root.thumbnailRefresh++;
        }
    }

    signal activated
    signal contextMenuRequested

    width: Config.desktop.iconSize * 1.5
    height: Config.desktop.iconSize + 40

    Rectangle {
        id: background
        anchors.fill: root
        color: Styling.srItem("overprimary")
        radius: Styling.radius(0)
        opacity: hoverHandler.hovered ? 0.25 : 0.0

        Behavior on color {
            enabled: Config.animDuration > 0
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
        id: contentLayout
        anchors.fill: root
        anchors.margins: 8
        spacing: 4
        layer.enabled: true
        layer.effect: Shadow {}

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Config.desktop.iconSize
            Layout.preferredHeight: Config.desktop.iconSize

            Loader {
                anchors.centerIn: parent
                width: Config.desktop.iconSize
                height: Config.desktop.iconSize
                sourceComponent: Config.tintIcons && !root.hasThumbnail ? tintedIconComponent : normalIconComponent
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            text: root.itemName
            color: Config.resolveColor(Config.desktop.textColor)
            font.family: Config.defaultFont
            font.pixelSize: Styling.fontSize(0)
            font.weight: Font.Bold
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
    }

    Component {
        id: normalIconComponent
        Image {
            mipmap: true
            property bool thumbnailExists: false
            source: {
                root.thumbnailRefresh;
                if (root.hasThumbnail) {
                    return "file://" + root.thumbnailPath;
                }
                return "image://icon/" + root.itemIcon;
            }
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: true
            cache: false

            onStatusChanged: {
                if (status === Image.Ready && root.hasThumbnail) {
                    thumbnailExists = true;
                } else if (status === Image.Error && root.hasThumbnail) {
                    thumbnailExists = false;
                    source = "image://icon/" + root.itemIcon;
                }
            }

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
                mipmap: true
                property bool thumbnailExists: false
                source: {
                    root.thumbnailRefresh;
                    if (root.hasThumbnail) {
                        return "file://" + root.thumbnailPath;
                    }
                    return "image://icon/" + root.itemIcon;
                }
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
                cache: false

                onStatusChanged: {
                    if (status === Image.Ready && root.hasThumbnail) {
                        thumbnailExists = true;
                    } else if (status === Image.Error && root.hasThumbnail) {
                        thumbnailExists = false;
                        source = "image://icon/" + root.itemIcon;
                    }
                }
            }
        }
    }
}
