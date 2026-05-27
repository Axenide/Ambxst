import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.widgets.defaultview

/*!
    IslandContent.qml — The Dynamic Island compact view rendered inside the bar.

    Shows the same DefaultView content (clock, user info, media, metrics)
    that the notch normally shows, but as a compact pill inside the bar's
    RowLayout. Loaded lazily by BarContent when dynamic mode + island is active.
*/
Item {
    id: root

    implicitWidth: islandContentLoader.implicitWidth
    implicitHeight: islandContentLoader.implicitHeight + 4

    Loader {
        id: islandContentLoader
        anchors.centerIn: parent
        sourceComponent: DefaultView {
            notchHovered: false
            parentHoverActive: false
        }
        active: true
        asynchronous: true
    }
}
