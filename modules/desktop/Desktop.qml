import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.modules.desktop
import qs.modules.services
import qs.modules.theme
import qs.modules.components
import qs.config

PanelWindow {
    id: desktop
    property int barSize: Config.showBackground ? 44 : 40
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
        DesktopService.maxColumnsHint = Qt.binding(() => iconContainer.maxColumns);
    }

    Item {
        id: iconContainer
        anchors.fill: parent
        anchors.margins: 16
        anchors.bottomMargin: desktop.barPosition === "bottom" ? desktop.barSize + 16 : 16
        anchors.topMargin: desktop.barPosition === "top" ? desktop.barSize + 16 : 16
        anchors.leftMargin: desktop.barPosition === "left" ? desktop.barSize + 16 : 16
        anchors.rightMargin: desktop.barPosition === "right" ? desktop.barSize + 16 : 16

        property int cellHeight: Config.desktop.iconSize + 40 + Config.desktop.spacingVertical
        property int cellWidth: cellHeight
        property int maxRows: Math.floor(height / cellHeight)
        property int maxColumns: Math.floor(width / cellWidth)

        Repeater {
            model: DesktopService.items

            delegate: Item {
                id: delegateRoot
                required property string name
                required property string path
                required property string type
                required property string icon
                required property bool isDesktopFile
                required property bool isPlaceholder
                required property int index

                width: iconContainer.cellWidth
                height: iconContainer.cellHeight

                x: Math.floor(index / iconContainer.maxRows) * iconContainer.cellWidth
                y: (index % iconContainer.maxRows) * iconContainer.cellHeight

                visible: !isPlaceholder

                Behavior on x {
                    enabled: !dragHandler.active && Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on y {
                    enabled: !dragHandler.active && Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutCubic
                    }
                }

                DesktopIcon {
                    id: iconItem
                    anchors.fill: parent

                    itemName: delegateRoot.name
                    itemPath: delegateRoot.path
                    itemType: delegateRoot.type
                    itemIcon: delegateRoot.icon
                    isDesktopFile: delegateRoot.isDesktopFile

                    onActivated: {
                        console.log("Activated:", itemName);
                    }

                    onContextMenuRequested: {
                        console.log("Context menu requested for:", itemName);
                        Visibilities.contextMenu.openCustomMenu([
                            {
                                text: "Open",
                                icon: Icons.launch,
                                isSeparator: false,
                                onTriggered: function () {
                                    if (delegateRoot.isDesktopFile) {
                                        DesktopService.executeDesktopFile(delegateRoot.path);
                                    } else {
                                        DesktopService.openFile(delegateRoot.path);
                                    }
                                }
                            },
                            {
                                isSeparator: true,
                                text: ""
                            },
                            {
                                text: "Delete",
                                icon: Icons.trash,
                                textColor: Colors.overError,
                                highlightColor: Colors.error,
                                isSeparator: false,
                                onTriggered: function () {
                                    DesktopService.trashFile(delegateRoot.path);
                                }
                            }
                        ], 160, 32, "desktop");
                    }

                    opacity: dragHandler.active ? 0.3 : 1.0

                    Behavior on opacity {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Config.animDuration / 2
                            easing.type: Easing.OutCubic
                        }
                    }

                    DragHandler {
                        id: dragHandler
                        target: dragPreview
                        onActiveChanged: {
                            if (!active) {
                                var targetIndex = delegateRoot.index;

                                console.log("Drop - Drag.target:", dragPreview.Drag.target);

                                if (dragPreview.Drag.target && dragPreview.Drag.target.visualIndex !== undefined) {
                                    targetIndex = dragPreview.Drag.target.visualIndex;
                                    console.log("Using Drag.target visualIndex:", targetIndex);
                                } else {
                                    var gridPos = iconContainer.mapFromItem(dragPreview.parent, dragPreview.x, dragPreview.y);
                                    var dropX = gridPos.x + dragPreview.width / 2;
                                    var dropY = gridPos.y + dragPreview.height / 2;

                                    if (dropX >= 0 && dropY >= 0 && dropX < iconContainer.width && dropY < iconContainer.height) {
                                        var col = Math.floor(dropX / iconContainer.cellWidth);
                                        var row = Math.floor(dropY / iconContainer.cellHeight);

                                        col = Math.max(0, Math.min(col, iconContainer.maxColumns - 1));
                                        row = Math.max(0, Math.min(row, iconContainer.maxRows - 1));

                                        targetIndex = col * iconContainer.maxRows + row;
                                        console.log("Calculated targetIndex:", targetIndex, "col:", col, "row:", row);
                                    }
                                }

                                if (targetIndex !== delegateRoot.index) {
                                    console.log("Moving from", delegateRoot.index, "to", targetIndex);
                                    DesktopService.moveItem(delegateRoot.index, targetIndex);
                                }

                                dragPreview.Drag.drop();
                            }
                        }
                    }
                }

                Item {
                    id: dragPreview
                    parent: iconContainer
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
                        isDesktopFile: delegateRoot.isDesktopFile
                        opacity: 0.7
                        scale: 1.05
                    }

                    Drag.active: dragHandler.active
                    Drag.source: delegateRoot
                    Drag.hotSpot.x: width / 2
                    Drag.hotSpot.y: height / 2
                    Drag.keys: ["desktopIcon"]
                }

                DropArea {
                    anchors.fill: parent
                    keys: ["desktopIcon"]

                    property int visualIndex: delegateRoot.index

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.color: Styling.srItem("overprimary")
                        border.width: 2
                        radius: Styling.radius(0) / 2
                        visible: parent.containsDrag
                        opacity: 0.5
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: 200
        height: 60
        color: Qt.rgba(0, 0, 0, 0.7)
        radius: Styling.radius(0)
        visible: !DesktopService.initialLoadComplete

        Text {
            anchors.centerIn: parent
            text: "Loading desktop..."
            color: "white"
            font.family: Config.defaultFont
            font.pixelSize: Styling.fontSize(0)
        }
    }
}
