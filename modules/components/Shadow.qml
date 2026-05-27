import QtQuick
import QtQuick.Effects
import qs.modules.theme
import qs.config

MultiEffect {
    shadowEnabled: true
    shadowHorizontalOffset: Config.theme.shadowXOffset
    shadowVerticalOffset: Config.theme.shadowYOffset
    shadowBlur: Config.theme.shadowBlur
    shadowColor: Config.resolveColor(Config.theme.shadowColor)
    shadowOpacity: Config.theme.shadowOpacity
}
