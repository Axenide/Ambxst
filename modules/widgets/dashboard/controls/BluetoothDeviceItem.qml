pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

Item {
    id: root

    required property BluetoothDevice device

    property bool expanded: false

    implicitHeight: contentColumn.implicitHeight + 16  // 8px margins top + bottom

    Behavior on implicitHeight {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutCubic
        }
    }

    StyledRect {
        anchors.fill: parent
        variant: mouseArea.containsMouse ? "focus" : "common"
        radius: Styling.radius(4)
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.expanded = !root.expanded
    }

    ColumnLayout {
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: 8
        spacing: 8

        // Main row with device info
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            spacing: 12

            // Device icon
            Text {
                text: {
                    const icon = root.device?.icon ?? "bluetooth";
                    if (icon.includes("audio-headset") || icon.includes("headphone"))
                        return Icons.headphones;
                    if (icon.includes("input-keyboard"))
                        return Icons.keyboard;
                    if (icon.includes("input-mouse"))
                        return Icons.mouse;
                    if (icon.includes("phone"))
                        return Icons.phone;
                    if (icon.includes("watch"))
                        return Icons.watch;
                    if (icon.includes("input-gaming") || icon.includes("gamepad"))
                        return Icons.gamepad;
                    if (icon.includes("printer"))
                        return Icons.printer;
                    if (icon.includes("camera"))
                        return Icons.camera;
                    if (icon.includes("audio-speakers") || icon.includes("speaker"))
                        return Icons.speaker;
                    return Icons.bluetooth;
                }
                font.family: Icons.font
                font.pixelSize: 20
                color: root.device?.connected ? Styling.srItem("overprimary") : Colors.overBackground
            }

            // Device name and status
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: root.device?.name ?? "Unknown device"
                    font.family: Config.theme.font
                    font.pixelSize: Config.theme.fontSize
                    font.weight: Font.Medium
                    color: Colors.overBackground
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.device?.connected || root.device?.paired || root.expanded
                    text: {
                        let status = "";
                        if (root.device?.connected) {
                            status = "Connected";
                        } else if (root.device?.paired) {
                            status = "Paired";
                        } else {
                            status = "Not paired";
                        }

                        if (root.device?.batteryAvailable) {
                            status += ` - ${root.device.battery}%`;
                        }

                        return status;
                    }
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-2)
                    color: Colors.overSurfaceVariant
                    elide: Text.ElideRight

                    Behavior on opacity {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Config.animDuration / 2
                        }
                    }
                }
            }

            // Battery indicator
            Row {
                visible: root.device?.batteryAvailable ?? false
                spacing: 4

                Text {
                    text: {
                        const battery = root.device?.battery ?? 0;
                        if (battery > 80)
                            return Icons.batteryFull;
                        if (battery > 60)
                            return Icons.batteryHigh;
                        if (battery > 40)
                            return Icons.batteryMedium;
                        if (battery > 20)
                            return Icons.batteryLow;
                        return Icons.batteryEmpty;
                    }
                    font.family: Icons.font
                    font.pixelSize: 18
                    color: {
                        const battery = root.device?.battery ?? 0;
                        if (battery > 60)
                            return Colors.green;
                        if (battery > 40)
                            return Colors.yellow;
                        if (battery > 20)
                            return Colors.red;
                        return Colors.error;
                    }
                }
            }
        }

        // Expanded content with action buttons
        RowLayout {
            Layout.fillWidth: true
            visible: root.expanded
            spacing: 8
            opacity: root.expanded ? 1 : 0

            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 2
                }
            }

            // Forget button (for paired devices)
            Button {
                id: forgetButton
                visible: root.device?.paired ?? false
                flat: true
                implicitWidth: 80
                implicitHeight: 32

                background: StyledRect {
                    variant: "error"
                    radius: Styling.radius(4)
                }

                contentItem: Text {
                    text: "Forget"
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    color: Styling.srItem("error")
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: root.device?.forget()
            }

            Item {
                Layout.fillWidth: true
            }

            // Connect/Disconnect button
            Button {
                id: actionButton
                flat: true
                implicitWidth: 100
                implicitHeight: 32

                background: StyledRect {
                    variant: root.device?.connected ? "internalbg" : "primary"
                    radius: Styling.radius(4)
                }

                contentItem: Text {
                    text: root.device?.connected ? "Disconnect" : "Connect"
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    color: root.device?.connected ? Colors.overSurfaceVariant : Styling.srItem("primary")
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    if (root.device?.connected) {
                        root.device.disconnect();
                    } else {
                        root.device.connect();
                    }
                }
            }
        }
    }
}
