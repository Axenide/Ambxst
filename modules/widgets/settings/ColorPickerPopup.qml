pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import qs.modules.theme
import qs.config

Popup {
    id: root

    required property var colorNames
    required property string currentColor
    property string dialogTitle: "Select Color"

    signal colorSelected(string color)

    width: 280
    height: 290
    padding: 4

    // Helper to check if current color is hex
    readonly property bool isHexColor: currentColor && currentColor.toString().startsWith("#")
    readonly property string currentHex: {
        if (!currentColor) return "000000";
        const val = currentColor.toString();
        if (val.startsWith("#")) {
            return val.replace("#", "").toUpperCase();
        }
        const resolved = Config.resolveColor(val);
        return resolved ? resolved.toString().replace("#", "").toUpperCase().slice(0, 6) : "000000";
    }

    background: Rectangle {
        color: Colors.surfaceContainerLow
        radius: Styling.radius(-1)
        border.color: Colors.outlineVariant
        border.width: 1
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 4

        // Custom HEX input row
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            Layout.margins: 2
            color: hexInput.activeFocus ? Colors.surfaceContainerHigh : Colors.surfaceContainer
            radius: Styling.radius(-2)
            border.color: hexInput.activeFocus ? Colors.primary : Colors.outlineVariant
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6

                Rectangle {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    radius: Styling.radius(-4)
                    color: Config.resolveColor(root.currentColor)
                    border.color: Colors.outline
                    border.width: 1
                }

                Text {
                    text: "#"
                    font.family: "monospace"
                    font.pixelSize: Styling.fontSize(0)
                    color: Colors.overBackground
                    opacity: 0.6
                }

                TextInput {
                    id: hexInput
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    text: root.currentHex
                    onTextChanged: {
                        if (text !== root.currentHex && !activeFocus) {
                            text = root.currentHex;
                        }
                    }

                    font.family: "monospace"
                    font.pixelSize: Styling.fontSize(0)
                    color: Colors.overBackground
                    verticalAlignment: Text.AlignVCenter
                    selectByMouse: true
                    maximumLength: 8

                    validator: RegularExpressionValidator {
                        regularExpression: /[0-9A-Fa-f]{0,8}/
                    }

                    onTextEdited: {
                        let hex = text.trim();
                        if (hex.length === 6 || hex.length === 8) {
                            root.colorSelected("#" + hex.toUpperCase());
                        }
                    }

                    Keys.onReturnPressed: {
                        let hex = text.trim();
                        if (hex.length >= 6) {
                            root.colorSelected("#" + hex.toUpperCase());
                        }
                        focus = false;
                    }
                    Keys.onEnterPressed: Keys.onReturnPressed(event)

                    Connections {
                        target: root
                        function onCurrentHexChanged() {
                            if (!hexInput.activeFocus) {
                                hexInput.text = root.currentHex;
                            }
                        }
                    }
                }

                Text {
                    text: "Custom"
                    font.family: Styling.defaultFont
                    font.pixelSize: Styling.fontSize(-1)
                    color: Colors.overBackground
                    opacity: 0.5
                }

                Button {
                    id: pickerButton
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24

                    background: Rectangle {
                        color: pickerButton.hovered ? Colors.surfaceContainerHigh : "transparent"
                        radius: Styling.radius(-4)
                    }

                    contentItem: Text {
                        text: Icons.picker
                        font.family: Icons.font
                        font.pixelSize: 14
                        color: Colors.overBackground
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: colorDialog.open()

                    ToolTip.visible: hovered
                    ToolTip.text: "Color picker"
                    ToolTip.delay: 500
                }
            }
        }

        // Separator
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            color: Colors.outline
            opacity: 0.2
        }

        // Color list
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.colorNames

            delegate: ItemDelegate {
                id: colorItem
                required property string modelData
                required property int index

                width: ListView.view.width
                height: 32

                background: Rectangle {
                    color: colorItem.hovered ? Colors.surfaceContainerHigh : "transparent"
                    radius: Styling.radius(-2)
                }

                contentItem: RowLayout {
                    spacing: 8

                    Rectangle {
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                        radius: Styling.radius(-4)
                        color: Colors[colorItem.modelData] || "transparent"
                        border.color: Colors.outline
                        border.width: 1
                    }

                    Text {
                        text: colorItem.modelData
                        font.family: Styling.defaultFont
                        font.pixelSize: Styling.fontSize(0)
                        color: Colors.overBackground
                        Layout.fillWidth: true
                    }

                    Text {
                        text: Icons.accept
                        font.family: Icons.font
                        font.pixelSize: 14
                        color: Colors.primary
                        visible: root.currentColor === colorItem.modelData
                    }
                }

                onClicked: {
                    root.colorSelected(colorItem.modelData);
                    root.close();
                }
            }
        }
    }

    ColorDialog {
        id: colorDialog
        title: root.dialogTitle
        selectedColor: Config.resolveColor(root.currentColor)

        onAccepted: {
            root.colorSelected(selectedColor.toString().toUpperCase());
        }
    }
}
