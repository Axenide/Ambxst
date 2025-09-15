import QtQuick
import Quickshell.Widgets
import qs.modules.theme
import qs.config
import qs.modules.components

ClippingRectangle {
    color: Colors.background
    radius: Config.roundness
    border.color: Colors.adapter.overBackground
    border.width: Config.theme.currentTheme === "sticker" ? 2 : 0

    layer.enabled: true
    layer.effect: Shadow {}
}
