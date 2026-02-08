import QtQuick
import QtQuick.Effects
import qs.config

MultiEffect {
    shadowEnabled: true
    shadowBlur: 0
    shadowOpacity: 1.0

    maskSpreadAtMin: 1.0
    maskSpreadAtMax: 1.0

    shadowColor: Config.resolveColor(Config.theme.srBg.border[0])
}
