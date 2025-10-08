import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.modules.desktop
import qs.modules.services
import qs.modules.theme
import qs.config

PanelWindow {
    id: desktop

    property int barSize: Config.bar.showBackground ? 44 : 40
    property int bottomTextMargin: 32
    property string barPosition: ["top", "bottom", "left", "right"].includes(Config.bar.position) ? Config.bar.position : "top"

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    color: "transparent"

    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "quickshell:desktop"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    visible: Config.desktop.enabled

    Component.onCompleted: {
        DesktopService.maxRowsHint = Qt.binding(() => iconContainer.maxRows);
    }

    GridView {
        id: iconContainer
        anchors.fill: parent
        anchors.margins: 16
        anchors.bottomMargin: desktop.barPosition === "bottom" ? desktop.barSize + 16 : 16
        anchors.topMargin: desktop.barPosition === "top" ? desktop.barSize + 16 : 16
        anchors.leftMargin: desktop.barPosition === "left" ? desktop.barSize + 16 : 16
        anchors.rightMargin: desktop.barPosition === "right" ? desktop.barSize + 16 : 16

        cellWidth: Config.desktop.iconSize + Config.desktop.spacing
        cellHeight: Config.desktop.iconSize + 40 + Config.desktop.spacing
        flow: GridView.FlowTopToBottom

        model: DesktopService.items

        property int maxRows: Math.floor(height / cellHeight)
        property int maxColumns: Math.floor(width / cellWidth)

        interactive: false

        displaced: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: Config.animDuration
                easing.type: Easing.OutCubic
            }
        }

        delegate: Item {
            id: delegateRoot
            required property string name
            required property string path
            required property string type
            required property string icon
            required property bool isDesktopFile
            required property int index

            width: iconContainer.cellWidth
            height: iconContainer.cellHeight

            DesktopIcon {
                id: iconItem
                anchors.fill: parent

                itemName: delegateRoot.name
                itemPath: delegateRoot.path
                itemType: delegateRoot.type
                itemIcon: delegateRoot.icon

                onActivated: {
                    console.log("Activated:", itemName);
                }

                onContextMenuRequested: {
                    console.log("Context menu requested for:", itemName);
                }

                Drag.active: dragHandler.active
                Drag.source: delegateRoot
                Drag.hotSpot.x: width / 2
                Drag.hotSpot.y: height / 2

                opacity: dragHandler.active ? 0.3 : 1.0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Config.animDuration / 2
                        easing.type: Easing.OutCubic
                    }
                }

                DragHandler {
                    id: dragHandler
                    target: dragPreview
                }
            }

            Item {
                id: dragPreview
                parent: dragHandler.active ? desktop : delegateRoot
                width: delegateRoot.width
                height: delegateRoot.height
                visible: dragHandler.active
                z: 999

                DesktopIcon {
                    anchors.fill: parent
                    itemName: delegateRoot.name
                    itemPath: delegateRoot.path
                    itemType: delegateRoot.type
                    itemIcon: delegateRoot.icon
                    opacity: 0.7
                    scale: 1.05
                }

                Drag.active: dragHandler.active
                Drag.source: delegateRoot
                Drag.hotSpot.x: width / 2
                Drag.hotSpot.y: height / 2

                Connections {
                    target: dragHandler
                    function onActiveChanged() {
                        if (!dragHandler.active) {
                            if (dragPreview.Drag.target) {
                                DesktopService.moveItem(delegateRoot.index, dragPreview.Drag.target.visualIndex);
                            }
                            dragPreview.Drag.drop();
                        }
                    }
                }
            }

            DropArea {
                anchors.fill: parent

                property int visualIndex: delegateRoot.index

                onEntered: drag => {
                    if (drag.source.index !== visualIndex) {
                        DesktopService.moveItem(drag.source.index, visualIndex);
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.color: Colors.primary
                border.width: 2
                radius: Config.roundness / 2
                visible: dropArea.containsDrag
                opacity: 0.5
            }

            DropArea {
                id: dropArea
                anchors.fill: parent

                property int visualIndex: delegateRoot.index
            }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: 200
        height: 60
        color: Qt.rgba(0, 0, 0, 0.7)
        radius: Config.roundness
        visible: !DesktopService.initialLoadComplete

        Text {
            anchors.centerIn: parent
            text: "Loading desktop..."
            color: "white"
            font.family: Config.defaultFont
            font.pixelSize: Config.theme.fontSize
        }
    }
}
