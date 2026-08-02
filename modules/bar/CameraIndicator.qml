pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.services
import qs.modules.components
import qs.modules.theme
import qs.modules.globals
import qs.config

// Camera privacy indicator: shows a dimmed webcam icon when no camera is in
// use, and switches to a red pulsing indicator (with a popup listing the
// processes holding the camera open) while any application uses a camera.
Item {
    id: root

    required property var bar

    property bool vertical: bar.orientation === "vertical"
    property bool isHovered: false
    property bool layerEnabled: true

    property real radius: 0
    property real startRadius: radius
    property real endRadius: radius

    // Hidden unless a camera exists or a camera is currently in use.
    property bool anyCameras: CameraService.cameras.length > 0
    visible: anyCameras

    // Popup visibility state
    property bool popupOpen: camPopup.isOpen

    Layout.preferredWidth: 36
    Layout.preferredHeight: 36
    Layout.fillWidth: vertical
    Layout.fillHeight: !vertical

    HoverHandler {
        onHoveredChanged: root.isHovered = hovered
    }

    StyledRect {
        id: buttonBg
        variant: root.popupOpen ? "primary" : "bg"
        anchors.fill: parent
        enableShadow: root.layerEnabled

        topLeftRadius: root.vertical ? root.startRadius : root.startRadius
        topRightRadius: root.vertical ? root.startRadius : root.endRadius
        bottomLeftRadius: root.vertical ? root.endRadius : root.startRadius
        bottomRightRadius: root.vertical ? root.endRadius : root.endRadius

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

        Text {
            id: camIcon
            anchors.centerIn: parent
            text: CameraService.cameraInUse ? Icons.webcam : Icons.webcamSlash
            font.family: Icons.font
            font.pixelSize: Styling.fontSize(0)
            color: root.popupOpen
                ? buttonBg.item
                : (CameraService.cameraInUse ? Colors.red : Colors.overSurfaceVariant)

            Behavior on color {
                enabled: Config.animDuration > 0
                ColorAnimation {
                    duration: Config.animDuration / 2
                }
            }
        }

        // Red pulsing halo while a camera is in use — draw attention without
        // stealing focus (privacy indicator, not an error dialog).
        Rectangle {
            anchors.fill: parent
            radius: parent.radius ?? 0
            color: "transparent"
            border.width: 2
            border.color: Colors.red
            visible: CameraService.cameraInUse && !root.popupOpen

            opacity: 0.3 + 0.4 * haloPulse.pulse
            scale: 1 + 0.08 * haloPulse.pulse

            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 2
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: camPopup.toggle()
        }

        StyledToolTip {
            visible: root.isHovered && !root.popupOpen
            tooltipText: CameraService.cameraInUse
                ? "Camera in use by " + CameraService.cameraUsers.length + " app(s)"
                : "No camera in use"
        }
    }

    // Gentle pulse while in use (drives the halo opacity/scale above).
    Timer {
        id: haloPulse
        property real pulse: 0
        property bool rising: true
        interval: 800
        repeat: true
        running: CameraService.cameraInUse
        onTriggered: {
            if (rising) {
                pulse += 0.5;
                if (pulse >= 1) {
                    pulse = 1;
                    rising = false;
                }
            } else {
                pulse -= 0.5;
                if (pulse <= 0) {
                    pulse = 0;
                    rising = true;
                }
            }
        }
    }

    // Popup: which apps are using the camera
    BarPopup {
        id: camPopup
        anchorItem: buttonBg
        bar: root.bar

        contentWidth: Math.max(260, mainColumn.implicitWidth + camPopup.popupPadding * 2)
        contentHeight: Math.min(220, Math.max(64, headerRow.implicitHeight + usersColumn.implicitHeight + camPopup.popupPadding * 2))

        ColumnLayout {
            id: mainColumn
            anchors.fill: parent
            spacing: 8

            RowLayout {
                id: headerRow
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: CameraService.cameraInUse ? Icons.webcam : Icons.webcamSlash
                    font.family: Icons.font
                    font.pixelSize: Styling.fontSize(6)
                    color: CameraService.cameraInUse ? Colors.red : Colors.overSurfaceVariant
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: CameraService.cameraInUse ? "Camera in use" : "No camera in use"
                        font.family: Styling.defaultFont
                        font.pixelSize: Styling.fontSize(0)
                        font.bold: true
                        color: Colors.overBackground
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: CameraService.cameraInUse
                        text: CameraService.cameraUsers.length + " application(s) holding the camera"
                        font.family: Styling.defaultFont
                        font.pixelSize: Styling.fontSize(-1)
                        color: Colors.overSurfaceVariant
                    }
                }
            }

            ColumnLayout {
                id: usersColumn
                Layout.fillWidth: true
                spacing: 2
                visible: CameraService.cameraInUse

                Repeater {
                    model: CameraService.cameraUsers
                    delegate: RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: Icons.dotsThree
                            font.family: Icons.font
                            font.pixelSize: Styling.fontSize(0)
                            color: Colors.red
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.name
                            font.family: Styling.defaultFont
                            font.pixelSize: Styling.fontSize(0)
                            color: Colors.overBackground
                            elide: Text.ElideRight
                        }

                        Text {
                            text: "PID " + modelData.pid
                            font.family: Styling.defaultFont
                            font.pixelSize: Styling.fontSize(-1)
                            color: Colors.overSurfaceVariant
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: !CameraService.cameraInUse
                text: "No application is currently using the camera"
                font.family: Styling.defaultFont
                font.pixelSize: Styling.fontSize(-1)
                color: Colors.overSurfaceVariant
            }
        }
    }
}
