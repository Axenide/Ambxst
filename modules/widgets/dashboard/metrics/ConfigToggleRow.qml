pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.config

RowLayout {
    id: tr
    Layout.fillWidth: true; Layout.preferredHeight: 26; spacing: 8
    property string icon: ""; property string label: ""; property bool on: true
    signal toggled(bool v)

    Text { text: tr.icon; font.family: Icons.font; font.pixelSize: Styling.fontSize(-2); color: Colors.overBackground; Layout.preferredWidth: 18 }
    Text { Layout.fillWidth: true; text: tr.label; font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-2); color: Colors.overBackground; elide: Text.ElideRight }

    Rectangle {
        Layout.preferredWidth: 40; Layout.preferredHeight: 22; radius: 11
        color: tr.on ? Styling.srItem("overprimary") : Qt.rgba(0.35,0.35,0.35,0.5)
        border.width: 1.5; border.color: tr.on ? Styling.srItem("overprimary") : Colors.outline
        Behavior on color { enabled: Anim.animationsEnabled; ColorAnimation { duration: 150 } }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: tr.on ? parent.width - width - 3 : 3
            width: 16; height: 16; radius: 8
            color: tr.on ? Colors.background : Colors.overSurfaceVariant
            Behavior on x { enabled: Anim.animationsEnabled; NumberAnimation { duration: 150; easing.type: Anim.easing("standard").type
                        easing.bezierCurve: Anim.easing("standard").bezierCurve } }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { tr.on = !tr.on; tr.toggled(tr.on) } }
    }
}
