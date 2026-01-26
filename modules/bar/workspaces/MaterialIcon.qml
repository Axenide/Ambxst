import QtQuick
import qs.modules.theme

Text {
    property int fill: 0
    property int grade: 0

    font.family: Icons.font
    font.pixelSize: Styling.fontSize(0)
    textFormat: Text.StyledText
    color: Colors.overBackground
}
