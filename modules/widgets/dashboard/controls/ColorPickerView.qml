pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import qs.modules.theme
import qs.modules.components
import qs.config

// Inline color picker view for ThemePanel
Item {
    id: root

    required property var colorNames
    required property string currentColor
    property string dialogTitle: "Select Color"

    signal colorSelected(string color)
    signal closed

    // Handle Escape key to close (without closing notch)
    Keys.onEscapePressed: event => {
        root.closed();
        event.accepted = true;
    }

    // Request focus when visible
    onVisibleChanged: {
        if (visible) {
            root.forceActiveFocus();
        }
    }

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

    ColumnLayout {
        id: mainColumn
        anchors.fill: parent
        spacing: 8

        // Header with back button and title (FIXED)
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            StyledRect {
                id: backButton
                variant: backMouseArea.containsMouse ? "focus" : "common"
                width: 36
                height: 36
                radius: Styling.radius(-2)
                enableShadow: true

                Text {
                    anchors.centerIn: parent
                    text: Icons.arrowLeft
                    font.family: Icons.font
                    font.pixelSize: 16
                    color: backButton.item
                }

                MouseArea {
                    id: backMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closed()
                }
            }

            Text {
                text: root.dialogTitle
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(1)
                font.weight: Font.Medium
                color: Colors.overBackground
                Layout.fillWidth: true
            }
        }

        // Custom HEX input row (FIXED)
        StyledRect {
            variant: "common"
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            radius: Styling.radius(-2)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
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
                    Keys.onEscapePressed: event => {
                        root.closed();
                        event.accepted = true;
                    }

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

                StyledRect {
                    id: pickerButton
                    variant: pickerMouseArea.containsMouse ? "focus" : "common"
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: Styling.radius(-3)
                    enableShadow: true

                    Text {
                        anchors.centerIn: parent
                        text: Icons.picker
                        font.family: Icons.font
                        font.pixelSize: 14
                        color: pickerButton.item
                    }

                    MouseArea {
                        id: pickerMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: colorDialog.open()
                    }

                    StyledToolTip {
                        visible: pickerMouseArea.containsMouse
                        text: "Color picker"
                    }
                }
            }
        }

        // Separator (FIXED)
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Colors.outline
            opacity: 0.2
        }

        // Color grid (SCROLLABLE)
        GridView {
            id: colorGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            cellWidth: width / 4
            cellHeight: 44
            model: root.colorNames

            delegate: Item {
                id: colorItem
                required property string modelData
                required property int index

                width: colorGrid.cellWidth
                height: colorGrid.cellHeight

                property bool isSelected: root.currentColor === modelData
                property bool isHovered: false

                StyledRect {
                    id: colorItemRect
                    anchors.fill: parent
                    anchors.margins: 2
                    variant: colorItem.isSelected ? "primary" : (colorItem.isHovered ? "focus" : "common")
                    radius: Styling.radius(-2)
                    enableShadow: true

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 6

                        Rectangle {
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                            radius: 10
                            color: Colors[colorItem.modelData] || "transparent"
                            border.color: Colors.outline
                            border.width: 1
                        }

                        Text {
                            text: colorItem.modelData
                            font.family: Styling.defaultFont
                            font.pixelSize: Styling.fontSize(-2)
                            color: colorItemRect.item
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onEntered: colorItem.isHovered = true
                        onExited: colorItem.isHovered = false

                        onClicked: {
                            root.colorSelected(colorItem.modelData);
                            // Don't close - let user continue selecting
                        }
                    }
                }
            }

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }
        }
    }

    ColorDialog {
        id: colorDialog
        title: root.dialogTitle
        selectedColor: Config.resolveColor(root.currentColor)

        onAccepted: {
            root.colorSelected(selectedColor.toString().toUpperCase());
            // Don't close - let user continue selecting
        }
    }
}
