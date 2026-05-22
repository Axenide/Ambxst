pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.services
import qs.modules.components
import qs.modules.theme
import qs.modules.globals
import qs.config

Item {
    id: root

    required property var bar

    property bool vertical: bar.orientation === "vertical"
    property bool isHovered: false
    property bool layerEnabled: true

    property real radius: 0
    property real startRadius: radius
    property real endRadius: radius

    // Popup visibility state
    property bool popupOpen: batteryPopup.isOpen

    // Function to interpolate color between green and red based on battery percentage
    function getBatteryColor() {
        if (!Battery.available)
            return Colors.overBackground;

        const pct = Battery.percentage;
        if (pct <= 15)
            return Colors.red;
        if (pct >= 85)
            return Colors.green;

        // Linear interpolation between red (15%) and green (85%)
        const ratio = (pct - 15) / (85 - 15);
        return Qt.rgba(Colors.red.r + (Colors.green.r - Colors.red.r) * ratio, Colors.red.g + (Colors.green.g - Colors.red.g) * ratio, Colors.red.b + (Colors.green.b - Colors.red.b) * ratio, 1);
    }

    Layout.preferredWidth: 36
    Layout.preferredHeight: 36
    Layout.fillWidth: vertical
    Layout.fillHeight: !vertical

    HoverHandler {
        onHoveredChanged: root.isHovered = hovered
    }

    // Main button with circular progress
    StyledRect {
        id: buttonBg
        variant: root.popupOpen ? "primary" : "bg"
        anchors.fill: parent
        enableShadow: root.layerEnabled

        topLeftRadius: root.vertical ? root.startRadius : root.startRadius
        topRightRadius: root.vertical ? root.startRadius : root.endRadius
        bottomLeftRadius: root.vertical ? root.endRadius : root.startRadius
        bottomRightRadius: root.vertical ? root.endRadius : root.endRadius

        // Background highlight on hover
        Rectangle {
            anchors.fill: parent
            color: Styling.srItem("overprimary")
            opacity: root.popupOpen ? 0 : (root.isHovered ? 0.25 : 0)
            radius: parent.radius ?? 0

            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 2
                }
            }
        }

        // Circular progress indicator (only if battery available)
        Item {
            id: progressCanvas
            anchors.centerIn: parent
            width: 32
            height: 32
            visible: Battery.available

            property real angle: (Battery.percentage / 100) * (360 - 2 * gapAngle)
            property real radius: 12
            property real lineWidth: 3
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
                        ctx.strokeStyle = root.getBatteryColor();
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
                    target: Battery
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

        // Central icon (Lightning/Plug for battery, PowerProfile icon otherwise)
        Text {
            id: batteryIcon
            anchors.centerIn: parent
            text: Battery.available ? (Battery.isPluggedIn ? Icons.plug : Icons.lightning) : PowerProfile.getProfileIcon(PowerProfile.currentProfile)
            font.family: Icons.font
            font.pixelSize: Battery.available ? 14 : 18
            color: root.popupOpen ? buttonBg.item : Colors.overBackground

            Behavior on color {
                enabled: Config.animDuration > 0
                ColorAnimation {
                    duration: Config.animDuration / 2
                }
            }

            Connections {
                target: Battery
                function onIsPluggedInChanged() {
                    batteryIcon.text = Battery.available ? (Battery.isPluggedIn ? Icons.plug : Icons.lightning) : PowerProfile.getProfileIcon(PowerProfile.currentProfile);
                }
                function onAvailableChanged() {
                    batteryIcon.text = Battery.available ? (Battery.isPluggedIn ? Icons.plug : Icons.lightning) : PowerProfile.getProfileIcon(PowerProfile.currentProfile);
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: batteryPopup.toggle()
        }

        StyledToolTip {
            visible: root.isHovered && !root.popupOpen
            tooltipText: Battery.available ? ("Battery: " + Math.round(Battery.percentage) + "%" + (Battery.isCharging ? " (Charging)" : "")) : ("Power Profile: " + PowerProfile.getProfileDisplayName(PowerProfile.currentProfile))
        }
    }

    // Battery popup with Power Profiles
    BarPopup {
        id: batteryPopup
        anchorItem: buttonBg
        bar: root.bar

        contentWidth: Math.max(280, mainColumn.implicitWidth + batteryPopup.popupPadding * 2)
        // Fixed height calculation to prevent expansion animation on first open
        // Battery details (60px) + spacing (4px) + Profiles (36px)
        contentHeight: (Battery.available ? 64 : 0) + 36 + batteryPopup.popupPadding * 2

        ColumnLayout {
            id: mainColumn
            anchors.fill: parent
            spacing: 4

            StyledRect {
                id: batteryDetailsContainer
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                visible: Battery.available
                variant: "common"
                enableShadow: false

                radius: Styling.radius(0)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    anchors.topMargin: 8
                    anchors.bottomMargin: 8
                    spacing: 12

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: Battery.getBatteryIcon()
                        font.family: Icons.font
                        font.pixelSize: 24
                        color: root.getBatteryColor()
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: Battery.isPluggedIn ? (Battery.isCharging ? "Charging" : "Full") : "On battery"
                            font.family: Styling.defaultFont
                            font.pixelSize: Styling.fontSize(0)
                            font.bold: true
                            color: Colors.overBackground
                        }

                        Text {
                            text: Battery.isPluggedIn ? (Battery.timeToFull !== "" ? "Full in " + Battery.timeToFull : "Fully charged") : (Battery.timeToEmpty !== "" ? Battery.timeToEmpty + " remaining" : "")
                            font.family: Styling.defaultFont
                            font.pixelSize: Styling.fontSize(-1)
                            color: Colors.overBackground
                            opacity: 0.8
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }

                    // Battery percentage display
                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: Math.round(Battery.percentage) + "%"
                        font.family: Styling.defaultFont
                        font.pixelSize: Styling.fontSize(2)
                        font.bold: true
                        color: root.getBatteryColor()
                        opacity: 0.8
                    }
                }
            }

            RowLayout {
                id: profilesRow
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 4

                Repeater {
                    model: PowerProfile.availableProfiles

                    delegate: StyledRect {
                        id: profileButton
                        required property string modelData
                        required property int index

                        Layout.fillWidth: true
                        Layout.preferredWidth: 80
                        height: 36

                        readonly property bool isSelected: PowerProfile.currentProfile === modelData
                        readonly property bool isFirst: index === 0
                        readonly property bool isLast: index === PowerProfile.availableProfiles.length - 1
                        property bool buttonHovered: false

                        readonly property real defaultRadius: Styling.radius(0)
                        readonly property real selectedRadius: Styling.radius(0) / 2

                        variant: isSelected ? "primary" : (buttonHovered ? "focus" : "common")
                        enableShadow: false

                        topLeftRadius: isSelected ? (isFirst ? defaultRadius : selectedRadius) : defaultRadius
                        bottomLeftRadius: isSelected ? (isFirst ? defaultRadius : selectedRadius) : defaultRadius
                        topRightRadius: isSelected ? (isLast ? defaultRadius : selectedRadius) : defaultRadius
                        bottomRightRadius: isSelected ? (isLast ? defaultRadius : selectedRadius) : defaultRadius

                        Text {
                            anchors.centerIn: parent
                            text: PowerProfile.getProfileIcon(profileButton.modelData)
                            font.family: Icons.font
                            font.pixelSize: 18
                            color: profileButton.item
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onEntered: profileButton.buttonHovered = true
                            onExited: profileButton.buttonHovered = false

                            onClicked: {
                                PowerProfile.setProfile(profileButton.modelData);
                            }
                        }

                        StyledToolTip {
                            show: profileButton.buttonHovered
                            tooltipText: PowerProfile.getProfileDisplayName(profileButton.modelData)
                        }
                    }
                }
            }
        }
    }
}
