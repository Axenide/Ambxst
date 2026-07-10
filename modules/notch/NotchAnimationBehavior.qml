import QtQuick
import qs.config

// Standard animation behavior for elements appearing inside the notch
Item {
    id: root

    // Controls visibility with animated entrance/exit
    property bool isVisible: false

    // Scale + opacity entrance — scale pops from 0.85 with OutBack overshoot
    scale: isVisible ? 1.0 : 0.85
    opacity: isVisible ? 1.0 : 0.0
    visible: opacity > 0

    // Subtle vertical translate: drop in from slightly above when appearing
    property real slideOffset: isVisible ? 0 : -5
    transform: Translate { y: root.slideOffset }

    Behavior on slideOffset {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutQuart
        }
    }

    Behavior on scale {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            // Overshoot only on entrance; closing settles smoothly without overshoot
            easing.type: root.isVisible ? Easing.OutBack : Easing.OutQuart
            easing.overshoot: 1.2
        }
    }

    Behavior on opacity {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutQuart
        }
    }
}
