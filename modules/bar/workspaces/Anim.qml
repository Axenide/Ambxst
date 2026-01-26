import QtQuick
import qs.config

NumberAnimation {
    duration: Config.animDuration > 0 ? Config.animDuration : 150
    easing.type: Easing.OutQuart
}
