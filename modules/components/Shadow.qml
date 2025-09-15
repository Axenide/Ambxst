import QtQuick
import QtQuick.Effects
import qs.modules.theme
import qs.config

MultiEffect {
    shadowEnabled: true
    shadowHorizontalOffset: Config.theme.currentTheme === "sticker" ? 2 : 0
    shadowVerticalOffset: Config.theme.currentTheme === "sticker" ? 2 : 0
    shadowBlur: Config.theme.currentTheme === "sticker" ? 0 : 1
    shadowColor: Colors.adapter.shadow
    shadowOpacity: Config.theme.currentTheme === "sticker" ? 1 : Config.theme.shadowOpacity
}
