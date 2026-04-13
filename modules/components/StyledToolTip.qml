pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.config
import qs.modules.theme
import qs.modules.components

ToolTip {
    id: root
    property string tooltipText: ""
    property string description: ""
    property bool show: false

    text: tooltipText
    delay: 700
    timeout: -1
    visible: show && tooltipText.length > 0

    background: StyledRect {
        variant: "popup"
        radius: Styling.radius(-8)
    }

    contentItem: ColumnLayout {
        spacing: 0

        Text {
            text: root.tooltipText
            color: Colors.overBackground
            font.pixelSize: Styling.fontSize(0)
            font.weight: Font.Bold
            font.family: Config.theme.font
        }

        Text {
            text: root.description
            visible: root.description.length > 0
            color: Qt.rgba(Colors.overBackground.r, Colors.overBackground.g, Colors.overBackground.b, 0.7)
            font.pixelSize: Styling.fontSize(-2)
            font.family: Config.theme.font
        }
    }
}
