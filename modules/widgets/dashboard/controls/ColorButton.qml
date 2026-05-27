pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.config

// Reusable color picker button with preview and label
// Emits openColorPicker signal for parent to handle
StyledRect {
    id: root

    required property var colorNames
    required property string currentColor
    property string label: ""

    property bool circlePreview: false  // Use circular preview (for dot colors)
    property bool compact: false  // Compact mode for tighter spaces
    property string dialogTitle: "Select Color"

    signal colorSelected(string color)
    signal openColorPicker(var colorNames, string currentColor, string dialogTitle)

    variant: "pane"
    height: compact ? 36 : 56
    radius: Styling.radius(-1)

    // Helper to get display name
    readonly property string displayName: {
        if (!currentColor) return "";
        const val = currentColor.toString();
        return val.startsWith("#") ? "Custom" : val;
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: root.compact ? 6 : 8
        spacing: root.compact ? 6 : 8

        // Color preview
        Rectangle {
            Layout.preferredWidth: root.compact ? 24 : 32
            Layout.preferredHeight: root.compact ? 24 : 32
            radius: root.circlePreview ? (root.compact ? 12 : 16) : Styling.radius(-4)
            color: Config.resolveColor(root.currentColor)
            border.color: Colors.outline
            border.width: 1
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: root.compact ? 0 : 2
            visible: !root.compact || root.label !== ""

            Text {
                text: root.label
                font.family: Styling.defaultFont
                font.pixelSize: Styling.fontSize(-2)
                font.bold: true
                color: root.item
                opacity: 0.6
                visible: root.label !== ""
            }

            Text {
                text: root.displayName
                font.family: Styling.defaultFont
                font.pixelSize: Styling.fontSize(0)
                font.bold: true
                color: root.item
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        Text {
            text: Icons.caretRight
            font.family: Icons.font
            font.pixelSize: root.compact ? 12 : 14
            color: root.item
            opacity: 0.5
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.openColorPicker(root.colorNames, root.currentColor, root.dialogTitle);
        }
    }
}
