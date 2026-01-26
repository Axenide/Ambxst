pragma Singleton
import QtQuick
import qs.modules.theme

QtObject {
    readonly property QtObject palette: QtObject {
        readonly property color m3surfaceContainer: Colors.surfaceContainer
        readonly property color m3surfaceContainerHigh: Colors.surfaceContainerHigh
        readonly property color m3onSurface: Colors.overBackground
        readonly property color m3onSurfaceVariant: Colors.overSurfaceVariant
        readonly property color m3outlineVariant: Colors.outlineVariant
        readonly property color m3tertiary: Colors.tertiary
        readonly property color m3onTertiary: Colors.overTertiary
        readonly property color m3primary: Colors.primary
        readonly property color m3onPrimary: Colors.overPrimary
    }

    function layer(color, _level) {
        return color;
    }
}
