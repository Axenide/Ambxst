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

    property string selectedVariant: ""

    signal updateVariant(string variantId, string property, var value)

    readonly property var variantCategories: [
        {
            name: "Base",
            variants: [
                { id: "bg", label: "Background" },
                { id: "internalbg", label: "Internal BG" },
                { id: "pane", label: "Pane" },
                { id: "common", label: "Common" },
                { id: "focus", label: "Focus" }
            ]
        },
        {
            name: "Primary",
            variants: [
                { id: "primary", label: "Primary" },
                { id: "primaryfocus", label: "Primary Focus" },
                { id: "overprimary", label: "Over Primary" }
            ]
        },
        {
            name: "Secondary",
            variants: [
                { id: "secondary", label: "Secondary" },
                { id: "secondaryfocus", label: "Secondary Focus" },
                { id: "oversecondary", label: "Over Secondary" }
            ]
        },
        {
            name: "Tertiary",
            variants: [
                { id: "tertiary", label: "Tertiary" },
                { id: "tertiaryfocus", label: "Tertiary Focus" },
                { id: "overtertiary", label: "Over Tertiary" }
            ]
        },
        {
            name: "Error",
            variants: [
                { id: "error", label: "Error" },
                { id: "errorfocus", label: "Error Focus" },
                { id: "overerror", label: "Over Error" }
            ]
        }
    ]

    RowLayout {
        anchors.fill: parent
        spacing: 8

        // Variants grid
        StyledRect {
            id: variantsPane
            Layout.preferredWidth: 280
            Layout.fillHeight: true
            variant: "pane"

            ScrollView {
                anchors.fill: parent
                anchors.margins: 8
                contentWidth: availableWidth
                clip: true

                ColumnLayout {
                    width: parent.width
                    spacing: 12

                    Text {
                        text: "StyledRect Variants"
                        font.family: Styling.defaultFont
                        font.pixelSize: Config.theme.fontSize
                        font.bold: true
                        color: Colors.primary
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Repeater {
                        model: root.variantCategories

                        delegate: ColumnLayout {
                            id: categoryDelegate
                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            spacing: 8

                            // Category header
                            Text {
                                text: categoryDelegate.modelData.name
                                font.family: Styling.defaultFont
                                font.pixelSize: Config.theme.fontSize
                                font.bold: true
                                color: Colors.overBackground
                                opacity: 0.7
                            }

                            // Variants grid
                            GridLayout {
                                columns: 4
                                rowSpacing: 8
                                columnSpacing: 8
                                Layout.fillWidth: true

                                Repeater {
                                    model: categoryDelegate.modelData.variants

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
                }
            }
        }

        // Variant editor panel
        Loader {
            id: editorLoader
            Layout.fillWidth: true
            Layout.fillHeight: true
            active: root.selectedVariant !== ""
            sourceComponent: VariantEditor {
                variantId: root.selectedVariant
                onUpdateVariant: (property, value) => {
                    root.updateVariant(root.selectedVariant, property, value);
                }
                onClose: root.selectedVariant = ""
            }
        }

        // Placeholder when no variant selected
        StyledRect {
            visible: root.selectedVariant === ""
            Layout.fillWidth: true
            Layout.fillHeight: true
            variant: "pane"

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 16

                Text {
                    text: Icons.cube
                    font.family: Icons.font
                    font.pixelSize: 48
                    color: Colors.overBackground
                    opacity: 0.5
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: "Select a variant to edit"
                    font.family: Styling.defaultFont
                    font.pixelSize: Config.theme.fontSize
                    color: Colors.overBackground
                    opacity: 0.5
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }
    }
}
