pragma Singleton
import QtQuick
import qs.config
import qs.modules.theme

QtObject {
    readonly property QtObject padding: QtObject {
        readonly property int small: 4
    }

    readonly property QtObject spacing: QtObject {
        readonly property int small: 4
        readonly property int normal: 8
    }

    readonly property QtObject rounding: QtObject {
        readonly property int full: Styling.radius(0)
    }

    readonly property QtObject anim: QtObject {
        readonly property QtObject durations: QtObject {
            readonly property int small: Math.max(120, Config.animDuration)
            readonly property int normal: Math.max(180, Config.animDuration)
        }

        readonly property QtObject curves: QtObject {
            readonly property int standardDecel: Easing.OutQuart
            readonly property int emphasized: Easing.OutQuart
        }
    }
}
