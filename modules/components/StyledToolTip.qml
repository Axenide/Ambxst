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
    property string desciription: ""
    property bool show: false

    text: tooltipText
    delay: 1000
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
            font.pixelSize: Config.theme.fontSize
            font.weight: Font.Bold
            font.family: Config.theme.font
        }

        Text {
            text: root.desciription
            visible: root.desciription.length > 0
            color: Colors.overBackground
            font.pixelSize: Config.theme.fontSize - 2
            font.family: Config.theme.font
        }
    }
}
