import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.globals
import qs.config

Item {
    property bool schemeListExpanded: false
    readonly property var schemeDisplayNames: ["Content", "Expressive", "Fidelity", "Fruit Salad", "Monochrome", "Neutral", "Rainbow", "Tonal Spot"]
    property bool scrollBarPressed: false
    property real opacityValue: schemeListExpanded ? 1 : 0

    Connections {
        target: GlobalStates.wallpaperManager
        function onCurrentMatugenSchemeChanged() {
            // Force re-evaluation of the text binding when scheme changes
        }
    }

    function getSchemeDisplayName(scheme) {
        const map = {
            "scheme-content": "Content",
            "scheme-expressive": "Expressive",
            "scheme-fidelity": "Fidelity",
            "scheme-fruit-salad": "Fruit Salad",
            "scheme-monochrome": "Monochrome",
            "scheme-neutral": "Neutral",
            "scheme-rainbow": "Rainbow",
            "scheme-tonal-spot": "Tonal Spot"
        };
        return map[scheme] || scheme;
    }

    Layout.fillWidth: true
    implicitHeight: mainLayout.implicitHeight + 8

    Rectangle {
        color: Colors.surface
        radius: Config.roundness > 0 ? Config.roundness + 4 : 0
        anchors.fill: parent

        ColumnLayout {
            id: mainLayout
            anchors.fill: parent
            anchors.margins: 4
            spacing: 0

            // Top row with scheme button and dark/light button
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Button {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    text: GlobalStates.wallpaperManager && GlobalStates.wallpaperManager.currentMatugenScheme ? getSchemeDisplayName(GlobalStates.wallpaperManager.currentMatugenScheme) : "Selecciona esquema"
                    onClicked: schemeListExpanded = !schemeListExpanded

                    background: Rectangle {
                        color: Colors.background
                        radius: Config.roundness
                    }

                    contentItem: Text {
                        text: parent.text
                        color: Colors.overSurface
                        font.family: Config.theme.font
                        font.pixelSize: Config.theme.fontSize
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 8
                    }
                }

                Button {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    onClicked: {
                        Config.theme.lightMode = !Config.theme.lightMode;
                    }

                    background: Rectangle {
                        color: Colors.background
                        radius: Config.roundness
                    }

                    contentItem: Text {
                        text: Config.theme.lightMode ? Icons.sun : Icons.moon
                        color: Colors.primary
                        font.family: Icons.font
                        font.pixelSize: 20
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                ClippingRectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: schemeListExpanded ? 40 * 3 : 0
                    Layout.topMargin: schemeListExpanded ? 4 : 0
                    color: Colors.background
                    radius: Config.roundness
                    opacity: opacityValue

                    Flickable {
                        id: schemeFlickable
                        anchors.fill: parent
                        contentHeight: schemeColumn.height
                        clip: true

                        Column {
                            id: schemeColumn
                            width: parent.width
                            spacing: 0

                            Repeater {
                                model: ["scheme-content", "scheme-expressive", "scheme-fidelity", "scheme-fruit-salad", "scheme-monochrome", "scheme-neutral", "scheme-rainbow", "scheme-tonal-spot"]

                                Button {
                                    width: parent.width
                                    height: 40
                                    text: schemeDisplayNames[index]
                                    onClicked: {
                                         if (GlobalStates.wallpaperManager) {
                                             GlobalStates.wallpaperManager.setMatugenScheme(modelData);
                                             schemeListExpanded = false;
                                         }
                                     }

                                    background: Rectangle {
                                        color: "transparent"
                                    }

                                    contentItem: Text {
                                        text: parent.text
                                        color: Colors.overSurface
                                        font.family: Config.theme.font
                                        font.pixelSize: Config.theme.fontSize
                                        verticalAlignment: Text.AlignVCenter
                                        leftPadding: 8
                                    }
                                }
                            }
                        }
                    }

                    // Animate topMargin for ClippingRectangle
                    Behavior on Layout.topMargin {
                        NumberAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutQuart
                        }
                    }

                    Behavior on Layout.preferredHeight {
                        NumberAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutQuart
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutQuart
                        }
                    }
                }

                ScrollBar {
                    Layout.preferredWidth: 8
                    Layout.preferredHeight: schemeListExpanded ? (40 * 3) - 32 : 0
                    Layout.alignment: Qt.AlignVCenter
                    orientation: Qt.Vertical
                    visible: schemeFlickable.contentHeight > schemeFlickable.height

                    position: schemeFlickable.contentY / schemeFlickable.contentHeight
                    size: schemeFlickable.height / schemeFlickable.contentHeight

                    background: Rectangle {
                        color: Colors.background
                        radius: Config.roundness
                    }

                    contentItem: Rectangle {
                        color: Colors.primary
                        radius: Config.roundness
                    }

                    onPressedChanged: {
                        scrollBarPressed = pressed;
                    }

                    onPositionChanged: {
                        if (scrollBarPressed && schemeFlickable.contentHeight > schemeFlickable.height) {
                            schemeFlickable.contentY = position * schemeFlickable.contentHeight;
                        }
                    }
                }
            }
        }
    }
}
