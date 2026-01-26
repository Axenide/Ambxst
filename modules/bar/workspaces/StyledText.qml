import QtQuick
import qs.config
import qs.modules.theme

Text {
    font.family: Config.theme.font
    font.pixelSize: Styling.fontSize(0)
    color: Colors.overBackground
    textFormat: Text.StyledText
}
