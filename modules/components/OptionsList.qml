pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Widgets
import qs.config
import qs.modules.theme
import qs.modules.components

// Shared expandable option list (context-menu style) used by the launcher,
// clipboard and presets tabs. Each model item: { text, icon, highlightColor,
// textColor, action }. Selection is driven externally via `currentIndex`; a
// hover emits `itemSelected(index)` so the owner can sync its state.
Item {
    id: root

    property var model: []
    property int currentIndex: 0
    property real rowHeight: 36
    property int maxRows: 0  // 0 = fit all rows
    property bool scrollable: false  // wheel + scrollbar when content overflows

    readonly property int visibleRowCount: Math.max(0, Math.min(root.model.length, root.maxRows > 0 ? root.maxRows : root.model.length))
    readonly property int preferredHeight: root.visibleRowCount * root.rowHeight

    signal itemSelected(int index)

    implicitHeight: root.preferredHeight

    RowLayout {
        anchors.fill: parent
        spacing: 0

        ClippingRectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Colors.background
            radius: Styling.radius(0)

            ListView {
                id: optionsListView
                anchors.fill: parent
                clip: true
                interactive: root.scrollable
                boundsBehavior: Flickable.StopAtBounds
                model: root.model
                currentIndex: root.currentIndex
                highlightFollowsCurrentItem: true
                highlightRangeMode: ListView.ApplyRange
                preferredHighlightBegin: 0
                preferredHighlightEnd: height

                property bool isScrolling: dragging || flicking

                highlight: StyledRect {
                    variant: {
                        if (optionsListView.currentIndex >= 0 && optionsListView.currentIndex < optionsListView.count) {
                            var item = optionsListView.model[optionsListView.currentIndex];
                            if (item && item.highlightColor) {
                                if (item.highlightColor === Colors.error)
                                    return "error";
                                if (item.highlightColor === Colors.secondary)
                                    return "secondary";
                                if (item.highlightColor === Colors.tertiary)
                                    return "tertiary";
                                return "primary";
                            }
                        }
                        return "primary";
                    }
                    radius: Styling.radius(0)
                    visible: optionsListView.currentIndex >= 0
                    z: -1
                }

                highlightMoveDuration: Config.animDuration > 0 ? Config.animDuration / 2 : 0
                highlightMoveVelocity: -1
                highlightResizeDuration: Config.animDuration / 2
                highlightResizeVelocity: -1

                delegate: Item {
                    required property var modelData
                    required property int index

                    width: optionsListView.width
                    height: root.rowHeight

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8

                            Text {
                                text: modelData && modelData.icon ? modelData.icon : ""
                                font.family: Icons.font
                                font.pixelSize: Styling.fontSize(0)
                                font.weight: Font.Bold
                                textFormat: Text.RichText
                                color: {
                                    if (optionsListView.currentIndex === index && modelData && modelData.textColor) {
                                        return modelData.textColor;
                                    }
                                    return Colors.overSurface;
                                }

                                Behavior on color {
                                    enabled: Config.animDuration > 0
                                    ColorAnimation {
                                        duration: Config.animDuration / 2
                                        easing.type: Easing.OutQuart
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData && modelData.text ? modelData.text : ""
                                font.family: Config.theme.font
                                font.pixelSize: Config.theme.fontSize
                                font.weight: optionsListView.currentIndex === index ? Font.Bold : Font.Normal
                                color: {
                                    if (optionsListView.currentIndex === index && modelData && modelData.textColor) {
                                        return modelData.textColor;
                                    }
                                    return Colors.overSurface;
                                }
                                elide: Text.ElideRight
                                maximumLineCount: 1

                                Behavior on color {
                                    enabled: Config.animDuration > 0
                                    ColorAnimation {
                                        duration: Config.animDuration / 2
                                        easing.type: Easing.OutQuart
                                    }
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: !optionsListView.isScrolling
                            cursorShape: Qt.PointingHandCursor

                            onEntered: {
                                if (optionsListView.isScrolling)
                                    return;
                                root.itemSelected(index);
                            }

                            onClicked: {
                                if (optionsListView.isScrolling)
                                    return;
                                if (modelData && modelData.action) {
                                    modelData.action();
                                }
                            }
                        }
                    }
                }
            }

            // Wheel scrolling when the content overflows the viewport
            MouseArea {
                anchors.fill: parent
                propagateComposedEvents: true
                acceptedButtons: Qt.NoButton
                enabled: root.scrollable

                onWheel: wheel => {
                    if (optionsListView.contentHeight > optionsListView.height) {
                        const delta = wheel.angleDelta.y;
                        optionsListView.contentY = Math.max(0, Math.min(optionsListView.contentHeight - optionsListView.height, optionsListView.contentY - delta));
                        wheel.accepted = true;
                    } else {
                        wheel.accepted = false;
                    }
                }
            }
        }

        ScrollBar {
            Layout.preferredWidth: 8
            Layout.preferredHeight: Math.max(0, root.preferredHeight - 32)
            Layout.alignment: Qt.AlignVCenter
            orientation: Qt.Vertical
            visible: root.scrollable && optionsListView.contentHeight > optionsListView.height

            position: optionsListView.contentY / optionsListView.contentHeight
            size: optionsListView.height / optionsListView.contentHeight

            background: Rectangle {
                color: Colors.background
                radius: Styling.radius(0)
            }

            contentItem: Rectangle {
                color: Styling.srItem("overprimary")
                radius: Styling.radius(0)
            }

            property bool scrollBarPressed: false

            onPressedChanged: {
                scrollBarPressed = pressed;
            }

            onPositionChanged: {
                if (scrollBarPressed && optionsListView.contentHeight > optionsListView.height) {
                    optionsListView.contentY = position * optionsListView.contentHeight;
                }
            }
        }
    }
}
