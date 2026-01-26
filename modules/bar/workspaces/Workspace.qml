import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.config
import qs.modules.services
import qs.modules.components
import qs.modules.theme

ColumnLayout {
    id: root

    required property int index
    required property int activeWsId
    required property var occupied
    required property int groupOffset
    required property int itemSize

    readonly property bool isWorkspace: true
    readonly property int size: implicitWidth

    readonly property int ws: groupOffset + index + 1
    readonly property bool isOccupied: occupied[ws] ?? false
    readonly property var focusedWindow: {
        const windows = (HyprlandData.windowList || []).filter(w => w.workspace?.id === root.ws);
        if (windows.length === 0)
            return null;
        return windows.reduce((best, win) => {
            const bestFocus = best?.focusHistoryID ?? Infinity;
            const winFocus = win?.focusHistoryID ?? Infinity;
            return winFocus < bestFocus ? win : best;
        }, null);
    }
    readonly property string focusedIcon: Quickshell.iconPath(AppSearch.getCachedIcon(focusedWindow?.class || ""), "image-missing")

    Layout.alignment: Qt.AlignHCenter
    Layout.preferredWidth: itemSize

    spacing: 0

    Item {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: itemSize
        Layout.preferredHeight: itemSize

        IconImage {
            id: wsIcon
            anchors.centerIn: parent
            implicitSize: Math.max(12, Math.round(itemSize * 0.65))
            source: focusedIcon
            visible: root.isOccupied && source.length > 0 && !Config.tintIcons
        }

        Tinted {
            sourceItem: wsIcon
            anchors.fill: wsIcon
            visible: root.isOccupied && wsIcon.visible && Config.tintIcons
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.max(6, Math.round(itemSize * 0.22))
            height: width
            radius: width / 2
            color: root.activeWsId === root.ws ? Colours.palette.m3primary : Colours.palette.m3outlineVariant
            opacity: root.isOccupied ? 0 : (root.activeWsId === root.ws ? 1 : 0.6)
        }
    }

    Loader {
        id: windows

        Layout.alignment: Qt.AlignHCenter
        Layout.fillWidth: true
        Layout.preferredWidth: itemSize

        visible: active
        active: Config.workspaces.showAppIcons && root.isOccupied

        sourceComponent: Row {
            spacing: 2

            Repeater {
                model: (HyprlandData.windowList || []).filter(w => w.workspace?.id === root.ws)

                IconImage {
                    required property var modelData
                    implicitSize: Math.max(10, Math.round(itemSize * 0.35))
                    source: Quickshell.iconPath(AppSearch.getCachedIcon(modelData?.class || ""), "image-missing")
                    visible: !Config.tintIcons
                }
            }
        }
    }
}
