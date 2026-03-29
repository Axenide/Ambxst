import QtQuick
import QtQuick.Layouts
import qs.modules.services
import qs.modules.components
import qs.modules.theme
import qs.modules.globals
import Quickshell.Services.UPower
import qs.config

StyledRect {
    id: batteryPane
    variant: "pane"
    Layout.fillWidth: true
    Layout.preferredHeight: 92 * amountOfRows
    radius: Styling.radius(4)
    visible: amountOfRows > 0 ? true : false

    property int amountOfRows: Math.ceil((UPower.devices.values.length) / 3)
    property int itemSize: 84
    property int iconSize: 32

    function getBatteryColor(device) {
        const pct = device.percentage * 100;
        if (pct <= 15)
            return Colors.red;
        if (pct >= 85)
            return Colors.green;

        // Linear interpolation between red (15%) and green (85%)
        const ratio = (pct - 15) / (85 - 15);
        return Qt.rgba(Colors.red.r + (Colors.green.r - Colors.red.r) * ratio, Colors.red.g + (Colors.green.g - Colors.red.g) * ratio, Colors.red.b + (Colors.green.b - Colors.red.b) * ratio, 1);
    }

    function getTypeIcon(icon) {
        if (icon.includes("Headset") || icon.includes("Headphones"))
            return Icons.headphones;
        if (icon.includes("Keyboard"))
            return Icons.keyboard;
        if (icon.includes("Mouse"))
            return Icons.mouse;
        if (icon.includes("Gaming") || icon.includes("gamepad"))
            return Icons.gamepad;
        if (icon.includes("Phone"))
            return Icons.mobilePhone;
        if (icon.includes("Speaker") || icon.includes("Audio"))
            return Icons.speaker;
        if (icon.includes("Tablet"))
            return Icons.tablet
        if (icon.includes("Bluetooth"))
            return Icons.bluetooth
        if (icon.includes("Watch"))
            return Icons.watch;
        if (icon.includes("Printer"))
            return Icons.printer;
        if (icon.includes("Camera"))
            return Icons.camera;
        return Icons.genericDevice;
    }


    ColumnLayout {
        anchors.fill: parent
        spacing: 4
        anchors.leftMargin: 1

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 4
            columns: 3
            rows: amountOfRows

            Repeater {
                model: UPower.devices
                Item {
                    id: device
                    required property var modelData
                    property bool isHovered: false

                    visible: modelData.isPresent == true

                    Layout.preferredHeight: itemSize
                    Layout.preferredWidth: itemSize

                    StyledRect {
                        id: deviceBox

                        readonly property real percentage: device.modelData.percentage * 100
                        readonly property bool isCharging: device.modelData.state === UPowerDevice.Charging
                        readonly property bool isPluggedIn: (device.modelData.state === UPowerDevice.Charging || device.modelData.state === UPowerDevice.FullyCharged || device.modelData.state === UPowerDevice.PendingCharge)
                        readonly property int chargeState: device.modelData.state

                        variant: "internalbg"
                        anchors.fill: parent

                        // Circular progress indicator

                        HoverHandler {
                            onHoveredChanged: device.isHovered = hovered
                        }

                        Item {
                            id: progressCanvas
                            anchors.centerIn: parent
                            width: itemSize
                            height: itemSize
                            visible: true

                            property real angle: (deviceBox.percentage / 100) * (360 - 2 * gapAngle)
                            property real radius: itemSize / 2.75
                            property real lineWidth: 4
                            property real gapAngle: 45

                            Canvas {
                                id: canvas
                                anchors.fill: parent
                                antialiasing: true

                                onPaint: {
                                    let ctx = getContext("2d");
                                    ctx.reset();

                                    let centerX = width / 2;
                                    let centerY = height / 2;
                                    let radius = progressCanvas.radius;
                                    let lineWidth = progressCanvas.lineWidth;

                                    ctx.lineCap = "round";

                                    // Base start angle (matching CircularControl: bottom + gap)
                                    let baseStartAngle = (Math.PI / 2) + (progressCanvas.gapAngle * Math.PI / 180);
                                    let progressAngleRad = progressCanvas.angle * Math.PI / 180;

                                    // Draw background track (remaining part)
                                    let totalAngleRad = (360 - 2 * progressCanvas.gapAngle) * Math.PI / 180;

                                    ctx.strokeStyle = Colors.outlineVariant;
                                    ctx.lineWidth = lineWidth;
                                    ctx.beginPath();
                                    ctx.arc(centerX, centerY, radius, baseStartAngle + progressAngleRad, baseStartAngle + totalAngleRad, false);
                                    ctx.stroke();

                                    // Draw progress
                                    if (progressCanvas.angle > 0) {
                                        ctx.strokeStyle = batteryPane.getBatteryColor(device.modelData);
                                        ctx.lineWidth = lineWidth;
                                        ctx.beginPath();
                                        ctx.arc(centerX, centerY, radius, baseStartAngle, baseStartAngle + progressAngleRad, false);
                                        ctx.stroke();
                                    }
                                }

                                Connections {
                                    target: progressCanvas
                                    function onAngleChanged() {
                                        canvas.requestPaint();
                                    }
                                }

                                Connections {
                                    target: deviceBox
                                    function onPercentageChanged() {
                                        canvas.requestPaint();
                                    }
                                }
                            }

                            Behavior on angle {
                                enabled: Config.animDuration > 0
                                NumberAnimation {
                                    duration: 400
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        Text {
                            id: batteryChargeIcon
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 4
                            text: deviceBox.isPluggedIn ? ( device.modelData.state === UPowerDevice.PendingCharge ? Icons.plug : Icons.lightning) : ""
                            font.family: "Phosphor-Fill"
                            font.pixelSize: 16
                            color: Colors.overBackground
                        }

                        Text {
                            id: batteryIcon
                            anchors.centerIn: parent
                            text: device.modelData.isLaptopBattery == true ? Icons.laptop : batteryPane.getTypeIcon(UPowerDeviceType.toString(device.modelData.type))
                            font.family: "Phosphor-Light"
                            font.pixelSize: 40
                            color: Colors.overBackground

                            Behavior on color {
                                enabled: Config.animDuration > 0
                                ColorAnimation {
                                    duration: Config.animDuration / 2
                                }
                            }

                        }

                        Text {
                            id: batteryPercentage
                            anchors.top: batteryIcon.bottom
                            anchors.horizontalCenter: batteryIcon.horizontalCenter
                            anchors.topMargin: 3
                            text: " " + Math.round(deviceBox.percentage) + "%"
                            color: Colors.overBackground
                            font.pixelSize: Config.theme.fontSize + 2
                            font.weight: Font.Bold
                            font.family: Config.theme.font
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    Rectangle {
                        anchors.top: deviceBox.bottom
                        anchors.topMargin: 28
                        anchors.horizontalCenter: deviceBox.horizontalCenter
                        StyledToolTip {
                            visible: device.isHovered
                            tooltipText: device.modelData.model + (deviceBox.isCharging ? " (Charging)" : "")
                        }
                    }
                }
            }
        }
    }
}

