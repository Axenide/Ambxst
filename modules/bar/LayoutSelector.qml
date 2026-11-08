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
        case "tile":
        case "vertical_tile":
            return Icons.dwindle;
        case "master":
        case "deck":
        case "center_tile":
        case "vertical_deck":
            return Icons.master;
        case "scrolling":
        case "scroller":
        case "vertical_scroller":
            return Icons.scrolling;
        case "monocle":
            return Icons.monocle;
        case "grid":
        case "vertical_grid":
            return Icons.squaresFour;
        default:
            return Icons.layout;
        }
    }

    function getLayoutDisplayName(layout) {
        switch (layout) {
        case "dwindle":
            return "Dwindle";
        case "tile":
            return "Tile";
        case "vertical_tile":
            return "Vertical Tile";
        case "master":
            return "Master";
        case "scrolling":
            return "Scrolling";
        case "scroller":
            return "Scroller";
        case "vertical_scroller":
            return "Vertical Scroller";
        case "monocle":
            return "Monocle";
        case "grid":
            return "Grid";
        case "vertical_grid":
            return "Vertical Grid";
        case "deck":
            return "Deck";
        case "vertical_deck":
            return "Vertical Deck";
        case "center_tile":
            return "Center Tile";
        case "right_tile":
            return "Right Tile";
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
