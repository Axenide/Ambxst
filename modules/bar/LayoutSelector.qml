import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.globals
import qs.modules.components
import qs.config

StyledRect {
    id: root
    variant: "bg"

    required property string orientation

    // Calculate width/height based on number of layouts
    readonly property int buttonSize: 32
    readonly property int spacing: 2
    readonly property int padding: 2
    readonly property int totalButtons: GlobalStates.availableLayouts.length

    // For vertical mode, reverse the order
    readonly property var displayLayouts: orientation === "vertical" ? GlobalStates.availableLayouts.slice().reverse() : GlobalStates.availableLayouts

    Layout.preferredWidth: orientation === "horizontal" ? (totalButtons * buttonSize + (totalButtons - 1) * spacing + padding * 2) : 36
    Layout.preferredHeight: orientation === "vertical" ? (totalButtons * buttonSize + (totalButtons - 1) * spacing + padding * 2) : 36

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

    function getLayoutIcon(layout) {
        switch (layout) {
        case "dwindle":
            return Icons.dwindle;
        case "master":
            return Icons.master;
        case "scrolling":
            return Icons.scrolling;
        default:
            return Icons.dwindle;
        }
    }

    function getLayoutDisplayName(layout) {
        switch (layout) {
        case "dwindle":
            return "Dwindle";
        case "master":
            return "Master";
        case "scrolling":
            return "Scrolling";
        default:
            return layout;
        }
    }

    Item {
        anchors.fill: parent
        anchors.margins: padding

        Loader {
            id: contentLoader
            anchors.fill: parent

            sourceComponent: orientation === "horizontal" ? horizontalLayout : verticalLayout
        }
    }

    Component {
        id: horizontalLayout

        RowLayout {
            spacing: root.spacing

            Repeater {
                model: root.displayLayouts

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
                        text: root.getLayoutIcon(modelData)
                        color: GlobalStates.compositorLayout === modelData ? Styling.srItem("primary") : Colors.overBackground
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
                        GlobalStates.setCompositorLayout(modelData);
                    }

                    StyledToolTip {
                        visible: parent.hovered
                        tooltipText: root.getLayoutDisplayName(modelData)
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
                model: root.displayLayouts

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
                        text: root.getLayoutIcon(modelData)
                        color: GlobalStates.compositorLayout === modelData ? Styling.srItem("primary") : Colors.overBackground
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
                        GlobalStates.setCompositorLayout(modelData);
                    }

                    StyledToolTip {
                        visible: parent.hovered
                        tooltipText: root.getLayoutDisplayName(modelData)
                    }
                }
            }
        }
    }
}
