pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.components
import qs.config

Item {
    id: root

    property string selectedVariant: "bg"  // Start with srBg selected

    signal updateVariant(string variantId, string property, var value)

    readonly property var allVariants: [
        { id: "bg", label: "Background" },
        { id: "internalbg", label: "Internal BG" },
        { id: "pane", label: "Pane" },
        { id: "common", label: "Common" },
        { id: "focus", label: "Focus" },
        { id: "primary", label: "Primary" },
        { id: "primaryfocus", label: "Primary Focus" },
        { id: "overprimary", label: "Over Primary" },
        { id: "secondary", label: "Secondary" },
        { id: "secondaryfocus", label: "Secondary Focus" },
        { id: "oversecondary", label: "Over Secondary" },
        { id: "tertiary", label: "Tertiary" },
        { id: "tertiaryfocus", label: "Tertiary Focus" },
        { id: "overtertiary", label: "Over Tertiary" },
        { id: "error", label: "Error" },
        { id: "errorfocus", label: "Error Focus" },
        { id: "overerror", label: "Over Error" }
    ]

    StyledRect {
        anchors.fill: parent
        variant: "pane"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            // Horizontal scrollable variant selector
            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 100
                spacing: 8

                // Flickable with variants
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 88
                    color: "transparent"
                    clip: true

                    Flickable {
                        id: variantsFlickable
                        anchors.fill: parent
                        contentWidth: variantsRow.width
                        contentHeight: height
                        flickableDirection: Flickable.HorizontalFlick
                        boundsBehavior: Flickable.StopAtBounds

                        RowLayout {
                            id: variantsRow
                            height: parent.height
                            spacing: 8

                            Repeater {
                                model: root.allVariants

                                delegate: VariantPreview {
                                    required property var modelData
                                    required property int index

                                    variantId: modelData.id
                                    variantLabel: modelData.label
                                    isSelected: root.selectedVariant === modelData.id

                                    onClicked: root.selectedVariant = modelData.id
                                }
                            }
                        }
                    }
                }

                // Custom horizontal scrollbar
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 6
                    color: Colors.surface
                    radius: 3

                    Rectangle {
                        id: scrollHandle
                        height: parent.height
                        radius: 3
                        color: Colors.primary
                        opacity: variantsFlickable.moving || scrollbarMouseArea.containsMouse ? 0.8 : 0.5

                        readonly property real visibleRatio: Math.min(1.0, variantsFlickable.width / variantsFlickable.contentWidth)
                        readonly property real maxX: parent.width - width

                        width: parent.width * visibleRatio
                        x: variantsFlickable.contentWidth > variantsFlickable.width 
                           ? (variantsFlickable.contentX / (variantsFlickable.contentWidth - variantsFlickable.width)) * maxX 
                           : 0

                        Behavior on opacity {
                            enabled: (Config.animDuration ?? 0) > 0
                            NumberAnimation { duration: (Config.animDuration ?? 0) / 2 }
                        }

                        MouseArea {
                            id: scrollbarMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            property real dragStartX: 0
                            property real dragStartContentX: 0

                            onPressed: mouse => {
                                dragStartX = mouse.x;
                                dragStartContentX = variantsFlickable.contentX;
                            }

                            onPositionChanged: mouse => {
                                if (pressed) {
                                    const delta = mouse.x - dragStartX;
                                    const contentDelta = delta / scrollHandle.maxX * (variantsFlickable.contentWidth - variantsFlickable.width);
                                    variantsFlickable.contentX = Math.max(0, Math.min(
                                        dragStartContentX + contentDelta,
                                        variantsFlickable.contentWidth - variantsFlickable.width
                                    ));
                                }
                            }
                        }
                    }
                }
            }

            // Editor panel
            VariantEditor {
                Layout.fillWidth: true
                Layout.fillHeight: true
                variantId: root.selectedVariant
                onUpdateVariant: (property, value) => {
                    root.updateVariant(root.selectedVariant, property, value);
                }
                onClose: {} // No close button in new design
            }
        }
    }
}
