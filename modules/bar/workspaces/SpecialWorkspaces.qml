import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Hyprland
import qs.config
import qs.modules.components
import qs.modules.services
import qs.modules.theme

Item {
    id: root

    required property var entries
    required property string activeSpecial
    required property int itemSize

    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Appearance.spacing.small

        Repeater {
            model: root.entries || []

            ColumnLayout {
                id: ws

                required property var modelData
                required property int index

                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: root.itemSize
                    Layout.preferredHeight: root.itemSize

                    StyledRect {
                        anchors.fill: parent
                        variant: modelData?.name === root.activeSpecial ? "primary" : "transparent"
                        radius: Appearance.rounding.full
                        enableShadow: false
                    }

                    IconImage {
                        id: primaryIcon
                        anchors.centerIn: parent
                        implicitSize: Math.max(12, Math.round(root.itemSize * 0.75))
                        source: {
                            const windows = modelData?.windows || [];
                            if (windows.length === 0)
                                return "";
                            const win = windows[0];
                            return Quickshell.iconPath(AppSearch.getCachedIcon(win?.class || ""), "image-missing");
                        }
                        visible: source.length > 0 && !Config.tintIcons
                    }

                    Tinted {
                        sourceItem: primaryIcon
                        anchors.fill: primaryIcon
                        visible: sourceItem.visible && Config.tintIcons
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.max(6, Math.round(root.itemSize * 0.22))
                        height: width
                        radius: width / 2
                        color: modelData?.name === root.activeSpecial ? Colors.overPrimary : Colors.overBackground
                        opacity: (modelData?.windows || []).length > 0 ? 0 : (modelData?.name === root.activeSpecial ? 1 : 0.7)
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            const name = String(ws.modelData?.name || "");
                            const shortName = name.startsWith("special:") ? name.slice(8) : name;
                            if (shortName.length > 0)
                                Hyprland.dispatch(`togglespecialworkspace ${shortName}`);
                        }
                    }
                }

                Row {
                    spacing: 2
                    visible: (modelData?.windows || []).length > 0

                    Repeater {
                        model: modelData?.windows || []

                        Item {
                            required property var modelData
                            implicitWidth: Math.max(12, Math.round(root.itemSize * 0.35))
                            implicitHeight: implicitWidth

                            IconImage {
                                id: windowIcon
                                anchors.fill: parent
                                source: Quickshell.iconPath(AppSearch.getCachedIcon(modelData?.class || ""), "image-missing")
                                visible: !Config.tintIcons
                            }

                            Tinted {
                                sourceItem: windowIcon
                                anchors.fill: windowIcon
                                visible: Config.tintIcons
                            }
                        }
                    }
                }
            }
        }
    }
}
