import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config

StyledRect {
    id: root
    variant: "bg"

    required property string orientation

    // Calculate width/height based on number of profiles
    readonly property int buttonSize: 32
    readonly property int spacing: 2
    readonly property int padding: 2
    readonly property int totalButtons: PowerProfile.availableProfiles.length

    // For vertical mode, reverse the order (performance, balanced, power-saver)
    readonly property var displayProfiles: orientation === "vertical" ? PowerProfile.availableProfiles.slice().reverse() : PowerProfile.availableProfiles

    Layout.preferredWidth: orientation === "horizontal" ? (totalButtons * buttonSize + (totalButtons - 1) * spacing + padding * 2) : 36
    Layout.preferredHeight: orientation === "vertical" ? (totalButtons * buttonSize + (totalButtons - 1) * spacing + padding * 2) : 36

    opacity: PowerProfile.isAvailable && PowerProfile.availableProfiles.length > 0 ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutQuart
        }
    }

    Behavior on Layout.preferredWidth {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutQuart
        }
    }

    Behavior on Layout.preferredHeight {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutQuart
        }
    }

    Component.onCompleted: {
        // Refresh profile data after a short delay
        Qt.callLater(() => {
            PowerProfile.updateCurrentProfile();
            PowerProfile.updateAvailableProfiles();
        });
    }

    Item {
        anchors.fill: parent
        anchors.margins: padding

        // Sliding highlight indicator (behind buttons)
        StyledRect {
            id: highlight
            variant: "primary"
            z: 0
            radius: Styling.radius(-2)

            property int currentIndex: {
                for (let i = 0; i < root.displayProfiles.length; i++) {
                    if (root.displayProfiles[i] === PowerProfile.currentProfile) {
                        return i;
                    }
                }
                return 0;
            }

            width: orientation === "horizontal" ? buttonSize : parent.width
            height: orientation === "vertical" ? buttonSize : parent.height

            x: orientation === "horizontal" ? currentIndex * (buttonSize + spacing) : 0
            y: orientation === "vertical" ? currentIndex * (buttonSize + spacing) : 0

            Behavior on x {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 2
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on y {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 2
                    easing.type: Easing.OutCubic
                }
            }
        }

        // Buttons layout (in front of highlight)
        Loader {
            id: contentLoader
            anchors.fill: parent
            z: 1

            sourceComponent: orientation === "horizontal" ? horizontalLayout : verticalLayout
        }
    }

    Component {
        id: horizontalLayout

        RowLayout {
            spacing: root.spacing

            Repeater {
                model: root.displayProfiles

                Button {
                    required property string modelData
                    required property int index

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: buttonSize

                    focusPolicy: Qt.NoFocus
                    hoverEnabled: true

                    background: Rectangle {
                        color: "transparent"
                    }

                    contentItem: Text {
                        text: PowerProfile.getProfileIcon(modelData)
                        color: PowerProfile.currentProfile === modelData ? Styling.srItem("primary") : Colors.overBackground
                        font.family: Icons.font
                        font.pixelSize: 18
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter

                        Behavior on color {
                            enabled: Config.animDuration > 0
                            ColorAnimation {
                                duration: Config.animDuration / 2
                                easing.type: Easing.OutQuart
                            }
                        }
                    }

                    onClicked: {
                        PowerProfile.setProfile(modelData);
                    }

                    StyledToolTip {
                        visible: parent.hovered
                        tooltipText: PowerProfile.getProfileDisplayName(modelData)
                    }
                }
            }
        }
    }

    Component {
        id: verticalLayout

        ColumnLayout {
            spacing: root.spacing

            Repeater {
                model: root.displayProfiles

                Button {
                    required property string modelData
                    required property int index

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredHeight: buttonSize

                    focusPolicy: Qt.NoFocus
                    hoverEnabled: true

                    background: Rectangle {
                        color: "transparent"
                    }

                    contentItem: Text {
                        text: PowerProfile.getProfileIcon(modelData)
                        color: PowerProfile.currentProfile === modelData ? Styling.srItem("primary") : Colors.overBackground
                        font.family: Icons.font
                        font.pixelSize: 18
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter

                        Behavior on color {
                            enabled: Config.animDuration > 0
                            ColorAnimation {
                                duration: Config.animDuration / 2
                                easing.type: Easing.OutQuart
                            }
                        }
                    }

                    onClicked: {
                        PowerProfile.setProfile(modelData);
                    }

                    StyledToolTip {
                        visible: parent.hovered
                        tooltipText: PowerProfile.getProfileDisplayName(modelData)
                    }
                }
            }
        }
    }
}
