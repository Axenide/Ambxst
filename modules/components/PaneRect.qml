import QtQuick
import QtQuick.Effects
import qs.modules.theme
import qs.config

Rectangle {
    color: Colors.surfaceContainer
    radius: Config.roundness
    border.color: Colors.surfaceBright
    border.width: 0

    layer.enabled: false
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 0
        shadowBlur: 1
        shadowColor: Colors.adapter.shadow
        shadowOpacity: Config.theme.shadowOpacity
    }
}
