pragma ComponentBehavior: Bound

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

    property int maxContentWidth: 480
    readonly property int contentWidth: Math.min(width, maxContentWidth)
    readonly property real sideMargin: (width - contentWidth) / 2

    Component.onCompleted: {
        // Only refresh device list, don't start scanning automatically
        if (BluetoothService.enabled) {
            BluetoothService.updateDevices();
        }
    }

    Component.onDestruction: {
        BluetoothService.stopDiscovery();
    }

    // Device list - fills entire width for scroll/drag
    ListView {
        id: deviceList
        anchors.fill: parent
        clip: true
        spacing: 4

        model: BluetoothService.friendlyDeviceList

        header: Item {
            width: deviceList.width
            height: titlebar.visible ? titlebar.height + 8 : 0

            PanelTitlebar {
                id: titlebar
                width: root.contentWidth
                anchors.horizontalCenter: parent.horizontalCenter
                title: I18n.t("Bluetooth")
                showTitle: false
                showToggle: false
                actions: []
                visible: false
            }
        }

        delegate: Item {
            required property var modelData
            width: deviceList.width
            height: deviceItem.height

            BluetoothDeviceItem {
                id: deviceItem
                width: root.contentWidth
                anchors.horizontalCenter: parent.horizontalCenter
                device: parent.modelData
            }
        }

        // Empty state
        Text {
            anchors.centerIn: parent
            visible: deviceList.count === 0 && !BluetoothService.discovering
            text: BluetoothService.enabled ? "No devices found" : "Bluetooth is disabled"
            font.family: Config.theme.font
            font.pixelSize: Config.theme.fontSize
            color: Colors.overSurfaceVariant
        }
    }
}
