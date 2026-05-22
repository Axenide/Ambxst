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
            // Defer update to avoid blocking UI initialization
            initialUpdateTimer.start();
        }
    }

    Timer {
        id: initialUpdateTimer
        interval: 300
        repeat: false
        onTriggered: BluetoothService.updateDevices()
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
        cacheBuffer: 1000
        reuseItems: true

        model: BluetoothService.friendlyDeviceList

        header: Item {
            width: deviceList.width
            height: titlebar.height + 8

            PanelTitlebar {
                id: titlebar
                width: root.contentWidth
                anchors.horizontalCenter: parent.horizontalCenter
                title: "Bluetooth"
                showToggle: true
                toggleChecked: BluetoothService.enabled

                actions: [
                    {
                        icon: Icons.popOpen,
                        tooltip: "Open Blueman",
                        onClicked: function () {
                            Quickshell.execDetached(["blueman-manager"]);
                        }
                    },
                    {
                        icon: Icons.sync,
                        tooltip: "Scan for devices",
                        enabled: BluetoothService.enabled,
                        loading: BluetoothService.discovering || BluetoothService.isUpdating,
                        onClicked: function () {
                            BluetoothService.startDiscovery();
                        }
                    }
                ]

                onToggleChanged: checked => {
                    BluetoothService.setEnabled(checked);
                    if (checked) {
                        BluetoothService.startDiscovery();
                    }
                }
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
