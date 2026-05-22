import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import "../controls"

StyledRect {
    id: root
    variant: "pane"
    Layout.alignment: Qt.AlignHCenter
    implicitWidth: internalBgRect.implicitWidth + 8
    implicitHeight: columnLayout.implicitHeight + 8
    radius: Styling.radius(4)
    
    property int expandedPanel: -1 // -1: none, 0: wifi, 1: bluetooth
    
    onVisibleChanged: {
        if (!visible) {
            root.expandedPanel = -1;
        } else {
            BluetoothService.initialize();
        }
    }
    
    Behavior on implicitHeight {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutCubic
        }
    }

    ColumnLayout {
        id: columnLayout
        anchors.fill: parent
        anchors.margins: 4
        spacing: 0
        
        StyledRect {
            id: internalBgRect
            variant: "internalbg"
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: buttonRow.implicitWidth + 8
            implicitHeight: buttonRow.implicitHeight + 8
            radius: Styling.radius(0)

            RowLayout {
                id: buttonRow
                anchors.centerIn: parent
                spacing: 4

                ControlButton {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    iconName: {
                        if (!NetworkService.wifiEnabled)
                            return Icons.wifiOff;
                        const strength = NetworkService.networkStrength;
                        if (strength === 0)
                            return Icons.wifiHigh;
                        if (strength < 25)
                            return Icons.wifiNone;
                        if (strength < 50)
                            return Icons.wifiLow;
                        if (strength < 75)
                            return Icons.wifiMedium;
                        return Icons.wifiHigh;
                    }
                    isActive: NetworkService.wifiEnabled || root.expandedPanel === 0
                    tooltipText: NetworkService.wifiEnabled ? "Wi-Fi: On" : "Wi-Fi: Off"
                    onClicked: NetworkService.toggleWifi()
                    onRightClicked: root.togglePanel(0)
                    onLongPressed: root.togglePanel(0)
                }

                ControlButton {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    iconName: {
                        if (!BluetoothService.enabled)
                            return Icons.bluetoothOff;
                        if (BluetoothService.connected)
                            return Icons.bluetoothConnected;
                        return Icons.bluetooth;
                    }
                    isActive: BluetoothService.enabled || root.expandedPanel === 1
                    tooltipText: {
                        if (!BluetoothService.enabled)
                            return "Bluetooth: Off";
                        if (BluetoothService.connected)
                            return "Bluetooth: Connected";
                        return "Bluetooth: On";
                    }
                    onClicked: BluetoothService.toggle()
                    onRightClicked: root.togglePanel(1)
                    onLongPressed: root.togglePanel(1)
                }

                ControlButton {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    iconName: Icons.nightLight
                    isActive: NightLightService.active
                    tooltipText: NightLightService.active ? "Night Light: On" : "Night Light: Off"
                    onClicked: NightLightService.toggle()
                }

                ControlButton {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    iconName: Icons.caffeine
                    isActive: CaffeineService.inhibit
                    tooltipText: CaffeineService.inhibit ? "Caffeine: On" : "Caffeine: Off"
                    onClicked: CaffeineService.toggleInhibit()
                }

                ControlButton {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    iconName: Icons.gameMode
                    isActive: GameModeService.toggled
                    tooltipText: GameModeService.toggled ? "Game Mode: On" : "Game Mode: Off"
                    onClicked: GameModeService.toggle()
                }
            }
        }
        
        Item {
            id: panelArea
            Layout.fillWidth: true
            Layout.preferredHeight: root.expandedPanel !== -1 ? root.width - 8 : 0 
            clip: true
            opacity: root.expandedPanel !== -1 ? 1 : 0
            
            Behavior on Layout.preferredHeight {
                enabled: Config.animDuration > 0
                NumberAnimation { duration: Config.animDuration; easing.type: Easing.OutQuart }
            }
            
            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation { duration: Config.animDuration; easing.type: Easing.OutQuart }
            }
            
            StyledRect {
                variant: "internalbg"
                anchors.fill: parent
                anchors.margins: 4
                radius: Styling.radius(0)
                clip: true

                Item {
                    id: panelStack
                    anchors.fill: parent
                    anchors.margins: 8 // Extra margin for content
                    
                    Loader {
                        id: wifiLoader
                        anchors.fill: parent
                        active: root.expandedPanel === 0
                        source: "../controls/WifiPanel.qml"
                        asynchronous: true
                        
                        opacity: root.expandedPanel === 0 ? 1 : 0
                        x: root.expandedPanel === 0 ? 0 : (root.expandedPanel === 1 ? -width : width)
                        
                        onLoaded: {
                            if (item) {
                                item.maxContentWidth = width;
                            }
                        }

                        Behavior on opacity { enabled: Config.animDuration > 0; NumberAnimation { duration: Config.animDuration; easing.type: Easing.OutQuart } }
                        Behavior on x { enabled: Config.animDuration > 0; NumberAnimation { duration: Config.animDuration; easing.type: Easing.OutQuart } }
                    }

                    Loader {
                        id: bluetoothLoader
                        anchors.fill: parent
                        active: root.expandedPanel === 1
                        source: "../controls/BluetoothPanel.qml"
                        asynchronous: true
                        
                        opacity: root.expandedPanel === 1 ? 1 : 0
                        x: root.expandedPanel === 1 ? 0 : (root.expandedPanel === 0 ? width : -width)
                        
                        onLoaded: {
                            if (item) {
                                item.maxContentWidth = width;
                            }
                        }

                        Behavior on opacity { enabled: Config.animDuration > 0; NumberAnimation { duration: Config.animDuration; easing.type: Easing.OutQuart } }
                        Behavior on x { enabled: Config.animDuration > 0; NumberAnimation { duration: Config.animDuration; easing.type: Easing.OutQuart } }
                    }
                }
            }
        }
    }
    
    function togglePanel(index) {
        if (root.expandedPanel === index) {
            root.expandedPanel = -1;
        } else {
            root.expandedPanel = index;
        }
    }
}
