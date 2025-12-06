pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.config

// Reusable color picker button with preview, label, and popup
Rectangle {
    id: root

    required property var colorNames
    required property string currentColor
    property string label: ""

    property bool circlePreview: false  // Use circular preview (for dot colors)
    property bool compact: false  // Compact mode for tighter spaces
    property string dialogTitle: "Select Color"

    signal colorSelected(string color)

    height: compact ? 36 : 56
    color: Colors.surfaceContainer
    radius: Styling.radius(-1)
    border.color: Colors.outlineVariant
    border.width: 1

    // Helper to get display name
    readonly property string displayName: {
        if (!currentColor) return "";
        const val = currentColor.toString();
        return val.startsWith("#") ? "Custom" : val;
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: compact ? 6 : 8
        spacing: compact ? 6 : 8

        // Color preview
        Rectangle {
            Layout.preferredWidth: compact ? 24 : 32
            Layout.preferredHeight: compact ? 24 : 32
            radius: root.circlePreview ? (compact ? 12 : 16) : Styling.radius(-4)
            color: Config.resolveColor(root.currentColor)
            border.color: Colors.outline
            border.width: 1
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: compact ? 0 : 2
            visible: !compact || root.label !== ""

            Text {
                text: root.label
                font.family: Styling.defaultFont
                font.pixelSize: Styling.fontSize(-2)
                font.bold: true
                color: Colors.overBackground
                opacity: 0.6
                visible: root.label !== ""
            }

            Text {
                text: root.displayName
                font.family: Styling.defaultFont
                font.pixelSize: Styling.fontSize(0)
                font.bold: true
                color: Colors.overBackground
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        Text {
            text: Icons.caretDown
            font.family: Icons.font
            font.pixelSize: compact ? 12 : 14
            color: Colors.overBackground
            opacity: 0.5
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: colorPopup.open()
    }

    ColorPickerPopup {
        id: colorPopup
        y: parent.height + 4
        colorNames: root.colorNames
        currentColor: root.currentColor
        dialogTitle: root.dialogTitle
        onColorSelected: color => root.colorSelected(color)
    }
}
