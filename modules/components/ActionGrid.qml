import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.modules.theme
import qs.modules.components
import qs.config

FocusScope {
    id: root

    property alias actions: repeater.model
    property string layout: "row" // "row" or "grid"
    property int buttonSize: 48
    property int iconSize: 24
    property int spacing: 4
    property int columns: 3 // para layout grid

    signal actionTriggered(var action)

    property int currentIndex: 0

    implicitWidth: layout === "row" ? (buttonSize * actions.length + spacing * (actions.length - 1)) : (buttonSize * Math.min(columns, actions.length) + spacing * (Math.min(columns, actions.length) - 1))
    implicitHeight: layout === "row" ? buttonSize : (Math.ceil(actions.length / columns) * buttonSize + spacing * (Math.ceil(actions.length / columns) - 1))

    Component.onCompleted: {
        root.forceActiveFocus();
        if (repeater.count > 0) {
            repeater.itemAt(0).forceActiveFocus();
        }
    }

    onActiveFocusChanged: {
        if (activeFocus && repeater.count > 0) {
            Qt.callLater(() => {
                repeater.itemAt(currentIndex).forceActiveFocus();
            });
        }
    }

    Keys.onPressed: event => {
        let nextIndex = currentIndex;

        if (layout === "row") {
            if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) {
                nextIndex = (currentIndex + 1) % actions.length;
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
                nextIndex = (currentIndex - 1 + actions.length) % actions.length;
            }
        } else {
            // grid layout
            if (event.key === Qt.Key_Right) {
                nextIndex = Math.min(currentIndex + 1, actions.length - 1);
            } else if (event.key === Qt.Key_Left) {
                nextIndex = Math.max(currentIndex - 1, 0);
            } else if (event.key === Qt.Key_Down) {
                nextIndex = Math.min(currentIndex + columns, actions.length - 1);
            } else if (event.key === Qt.Key_Up) {
                nextIndex = Math.max(currentIndex - columns, 0);
            }
        }

        if (event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
            if (repeater.itemAt(currentIndex)) {
                repeater.itemAt(currentIndex).triggerAction();
            }
            event.accepted = true;
        } else if (nextIndex !== currentIndex) {
            currentIndex = nextIndex;
            repeater.itemAt(currentIndex).forceActiveFocus();
            event.accepted = true;
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"

        // Highlight que se desplaza entre botones con efecto elástico
        Rectangle {
            id: highlight
            color: {
                // Buscar si algún botón está presionado
                for (let i = 0; i < repeater.count; i++) {
                    if (repeater.itemAt(i) && repeater.itemAt(i).pressed) {
                        return Colors.adapter.overPrimary;
                    }
                }
                return Colors.adapter.primary;
            }
            radius: Config.roundness > 0 ? Config.roundness + 4 : 0
            border.width: 0
            border.color: Colors.adapter.primary
            z: 0 // Por debajo de los botones
            visible: repeater.count > 0

            property real activeButtonMargin: 2
            property real idx1X: root.currentIndex % (root.layout === "row" ? root.actions.length : root.columns)
            property real idx2X: root.currentIndex % (root.layout === "row" ? root.actions.length : root.columns)
            property real idx1Y: root.layout === "row" ? 0 : Math.floor(root.currentIndex / root.columns)
            property real idx2Y: root.layout === "row" ? 0 : Math.floor(root.currentIndex / root.columns)

            // Posición y tamaño con efecto elástico
            x: {
                let minX = Math.min(idx1X, idx2X) * (root.buttonSize + root.spacing) + container.x + activeButtonMargin;
                return minX;
            }

            y: {
                let minY = Math.min(idx1Y, idx2Y) * (root.buttonSize + root.spacing) + container.y + activeButtonMargin;
                return minY;
            }

            width: {
                let stretchX = Math.abs(idx1X - idx2X) * (root.buttonSize + root.spacing) + root.buttonSize - activeButtonMargin * 2;
                return stretchX;
            }

            height: {
                let stretchY = Math.abs(idx1Y - idx2Y) * (root.buttonSize + root.spacing) + root.buttonSize - activeButtonMargin * 2;
                return stretchY;
            }

            Behavior on idx1X {
                NumberAnimation {
                    duration: Config.animDuration / 3
                    easing.type: Easing.OutSine
                }
            }
            Behavior on idx2X {
                NumberAnimation {
                    duration: Config.animDuration
                    easing.type: Easing.OutSine
                }
            }
            Behavior on idx1Y {
                NumberAnimation {
                    duration: Config.animDuration / 3
                    easing.type: Easing.OutSine
                }
            }
            Behavior on idx2Y {
                NumberAnimation {
                    duration: Config.animDuration
                    easing.type: Easing.OutSine
                }
            }
        }

        Grid {
            id: container
            anchors.centerIn: parent
            columns: root.layout === "row" ? root.actions.length : root.columns
            rows: root.layout === "row" ? 1 : Math.ceil(root.actions.length / root.columns)
            columnSpacing: root.spacing
            rowSpacing: root.spacing

            Repeater {
                id: repeater

                delegate: Button {
                    id: actionButton

                    implicitWidth: root.buttonSize
                    implicitHeight: root.buttonSize
                    z: 1 // Por encima del highlight

                    Process {
                        id: commandProcess
                        command: ["bash", "-c", modelData.command || ""]
                        running: false
                    }

                    function triggerAction() {
                        root.actionTriggered(modelData);
                        if (modelData.command) {
                            commandProcess.running = true;
                        }
                    }

                    background: Rectangle {
                        color: "transparent"
                        radius: Config.roundness > 0 ? Config.roundness + 4 : 0
                    }

                    contentItem: Text {
                        text: modelData.icon || ""
                        font.family: Icons.font
                        font.pixelSize: root.iconSize
                        color: actionButton.pressed ? Colors.adapter.primary : (index === root.currentIndex ? Colors.adapter.overPrimary : Colors.adapter.overBackground)
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter

                        Behavior on color {
                            ColorAnimation {
                                duration: Config.animDuration / 2
                                easing.type: Easing.OutQuart
                            }
                        }
                    }

                    onClicked: triggerAction()

                    onHoveredChanged: {
                        if (hovered) {
                            root.currentIndex = index;
                        }
                    }

                    onActiveFocusChanged: {
                        if (activeFocus) {
                            root.currentIndex = index;
                        }
                    }

                    ToolTip.visible: hovered
                    ToolTip.text: modelData.tooltip || ""
                    ToolTip.delay: 500
                }
            }
        }
    }
}
