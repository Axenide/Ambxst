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
    property int iconSize: 20
    property int spacing: 4
    property int columns: 3 // para layout grid
    property int textSpacing: 8

    signal actionTriggered(var action)

    property int currentIndex: 0

    function getNextValidIndex(current, step) {
        let next = current;
        let limit = actions.length;
        for (let i = 0; i < limit; i++) {
            next = (next + step + limit) % limit;
            let action = actions[next];
            let isEnabled = (action.enabled !== undefined ? action.enabled : true);
            if ((!action.type || action.type !== "separator") && isEnabled)
                return next;
        }
        return current;
    }

    implicitWidth: container.implicitWidth
    implicitHeight: container.implicitHeight

    Component.onCompleted: {
        root.forceActiveFocus();
        if (repeater.count > 0) {
            repeater.itemAt(0).forceActiveFocus();
        }
    }

    onActiveFocusChanged: {
        if (activeFocus && repeater.count > 0) {
            Qt.callLater(() => {
                let item = repeater.itemAt(currentIndex);
                if (item)
                    item.forceActiveFocus();
            });
        }
    }

    Keys.onPressed: event => {
        let nextIndex = currentIndex;

        if (layout === "row") {
            if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) {
                nextIndex = getNextValidIndex(currentIndex, 1);
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
                nextIndex = getNextValidIndex(currentIndex, -1);
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
            let item = repeater.itemAt(currentIndex);
            if (item)
                item.forceActiveFocus();
            event.accepted = true;
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"

        // Highlight que se desplaza entre botones
        StyledRect {
            id: highlight
            variant: (repeater.count > 0 && repeater.itemAt(root.currentIndex) && repeater.itemAt(root.currentIndex).actionModel.variant) ? repeater.itemAt(root.currentIndex).actionModel.variant : "primary"
            radius: Styling.radius(4)
            z: 0 // Por debajo de los botones
            visible: repeater.count > 0

            property Item targetItem: repeater.count > 0 ? repeater.itemAt(root.currentIndex) : null

            // Target values (geometry relative to container)
            property real tx: targetItem ? targetItem.x : 0
            property real ty: targetItem ? targetItem.y : 0
            property real tw: targetItem ? targetItem.width : 0
            property real th: targetItem ? targetItem.height : 0

            // Tracker 1 (Fast / Lead)
            property real t1x: tx
            property real t1y: ty
            property real t1w: tw
            property real t1h: th

            Behavior on t1x {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 3
                    easing.type: Easing.OutSine
                }
            }
            Behavior on t1y {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 3
                    easing.type: Easing.OutSine
                }
            }
            Behavior on t1w {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 3
                    easing.type: Easing.OutSine
                }
            }
            Behavior on t1h {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 3
                    easing.type: Easing.OutSine
                }
            }

            // Tracker 2 (Slow / Follow)
            property real t2x: tx
            property real t2y: ty
            property real t2w: tw
            property real t2h: th

            Behavior on t2x {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration
                    easing.type: Easing.OutSine
                }
            }
            Behavior on t2y {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration
                    easing.type: Easing.OutSine
                }
            }
            Behavior on t2w {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration
                    easing.type: Easing.OutSine
                }
            }
            Behavior on t2h {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration
                    easing.type: Easing.OutSine
                }
            }

            // Final geometry combining both trackers to create elastic effect
            x: Math.min(t1x, t2x) + container.x
            y: Math.min(t1y, t2y) + container.y
            width: Math.max(t1x + t1w, t2x + t2w) - Math.min(t1x, t2x)
            height: Math.max(t1y + t1h, t2y + t2h) - Math.min(t1y, t2y)
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

                delegate: Item {
                    id: delegateWrapper
                    readonly property bool isSeparator: (modelData.type === "separator")
                    property var actionModel: modelData

                    implicitWidth: isSeparator ? (root.layout === "row" ? 2 : root.buttonSize) : (root.buttonSize + (hasText ? textMetrics.width + root.textSpacing : 0))
                    implicitHeight: isSeparator ? (root.layout === "row" ? root.buttonSize : 2) : root.buttonSize
                    z: 1

                    readonly property bool hasText: {
                        if (!modelData)
                            return false;
                        if (typeof modelData.text === "string")
                            return modelData.text.length > 0;
                        return false;
                    }

                    TextMetrics {
                        id: textMetrics
                        text: delegateWrapper.hasText ? modelData.text : ""
                        font.family: Config.defaultFont
                        font.pixelSize: root.iconSize * 0.7
                        font.weight: Font.DemiBold
                    }

                    function triggerAction() {
                        if (!isSeparator)
                            actionButton.triggerAction();
                    }

                    Button {
                        id: actionButton
                        anchors.fill: parent
                        visible: !delegateWrapper.isSeparator
                        enabled: !delegateWrapper.isSeparator && (modelData.enabled !== undefined ? modelData.enabled : true)
                        opacity: enabled ? 1.0 : 0.5

                        Process {
                            id: commandProcess
                            command: ["bash", "-c", delegateWrapper.actionModel.command || ""]
                            running: false
                        }

                        function triggerAction() {
                            if (!enabled) return;
                            root.actionTriggered(delegateWrapper.actionModel);
                            if (delegateWrapper.actionModel.command) {
                                commandProcess.running = true;
                            }
                        }

                        background: Rectangle {
                            color: "transparent"
                            radius: Styling.radius(4)
                        }

                        contentItem: Item {
                            anchors.fill: parent

                            // 1. Icono centrado en el área base del botón (siempre fijo a la izquierda)
                            Text {
                                width: root.buttonSize
                                height: parent.height
                                anchors.left: parent.left
                                text: modelData.icon || ""
                                textFormat: Text.RichText
                                font.family: Icons.font
                                font.pixelSize: root.iconSize
                                color: actionButton.pressed ? Styling.srItem("overprimary") : (index === root.currentIndex ? (highlight.targetItem ? highlight.item : Styling.srItem("primary")) : Colors.overBackground)
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

                            // 2. Texto alineado a la derecha del área base del botón
                            Text {
                                visible: delegateWrapper.hasText
                                text: visible ? modelData.text : ""
                                anchors.left: parent.left
                                anchors.leftMargin: root.buttonSize // Empieza justo después del área del icono
                                anchors.verticalCenter: parent.verticalCenter

                                font.family: Config.defaultFont
                                font.pixelSize: root.iconSize * 0.7
                                font.weight: Font.DemiBold
                                color: actionButton.pressed ? Styling.srItem("overprimary") : (index === root.currentIndex ? (highlight.targetItem ? highlight.item : Styling.srItem("primary")) : Colors.overBackground)
                                verticalAlignment: Text.AlignVCenter

                                Behavior on color {
                                    enabled: Config.animDuration > 0
                                    ColorAnimation {
                                        duration: Config.animDuration / 2
                                        easing.type: Easing.OutQuart
                                    }
                                }
                            }
                        }

                        onClicked: triggerAction()

                        onHoveredChanged: {
                            if (hovered && actionButton.enabled) {
                                root.currentIndex = index;
                            }
                        }

                        onActiveFocusChanged: {
                            if (activeFocus) {
                                root.currentIndex = index;
                            }
                        }

                        StyledToolTip {
                            visible: parent.hovered
                            tooltipText: modelData.tooltip || ""
                            delay: 500
                        }
                    }

                    Item {
                        anchors.fill: parent
                        visible: delegateWrapper.isSeparator
                        Separator {
                            anchors.centerIn: parent
                            vert: root.layout === "row"
                        }
                    }
                }
            }
        }
    }
}
