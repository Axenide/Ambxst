import QtQuick
import QtQuick.Layouts
import qs.config
import qs.modules.theme

Rectangle {
    property bool vert: false

    color: Colors.overBackground
    opacity: 0.1
    radius: Styling.radius(0)

    implicitWidth: vert ? 3 : 20
    implicitHeight: vert ? 5 : 2

    Layout.fillWidth: !vert
    Layout.fillHeight: vert
}
