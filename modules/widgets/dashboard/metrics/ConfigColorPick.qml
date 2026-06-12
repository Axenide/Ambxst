pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.config

Item {
    id: cp
    Layout.fillWidth: true
    property string label: ""; property string color: "#5EADFF"; property bool open: false
    property real hue: 0.58; property real sat: 0.7; property real light: 0.6
    signal picked(string hex)
    implicitHeight: header.height + (open ? 40 : 0)

    onColorChanged: {
        let r = parseInt(color.slice(1,3),16)/255, g = parseInt(color.slice(3,5),16)/255, b = parseInt(color.slice(5,7),16)/255
        let mx = Math.max(r,g,b), mn = Math.min(r,g,b), d = mx-mn
        sat = mx === 0 ? 0 : d/mx
        if (d === 0) hue = 0
        else if (mx === r) hue = ((g-b)/d + (g<b?6:0))/6
        else if (mx === g) hue = ((b-r)/d + 2)/6
        else hue = ((r-g)/d + 4)/6
        light = mx
    }

    function hsvHex(h,s,v) {
        let i=Math.floor(h*6), f=h*6-i
        let p=v*(1-s), q=v*(1-f*s), t=v*(1-(1-f)*s), r2,g2,b2
        if (i%6===0) { r2=v; g2=t; b2=p }
        else if (i%6===1) { r2=q; g2=v; b2=p }
        else if (i%6===2) { r2=p; g2=v; b2=t }
        else if (i%6===3) { r2=p; g2=q; b2=v }
        else if (i%6===4) { r2=t; g2=p; b2=v }
        else { r2=v; g2=p; b2=q }
        return "#"+[r2,g2,b2].map(x=>Math.round(x*255).toString(16).padStart(2,'0')).join('').toUpperCase()
    }

    function pick(h,s,l) { hue=h; sat=s; light=l; let hex=hsvHex(h,s,l); color=hex; picked(hex) }

    RowLayout { id: header; width: parent.width; spacing: 6
        Text { text: cp.label; font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-3); font.weight: Font.Medium; color: Colors.overBackground; Layout.preferredWidth: 60 }
        Rectangle { Layout.preferredWidth: 24; Layout.preferredHeight: 24; radius: 5; color: cp.color; border.width: 1.5; border.color: Colors.outline
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: cp.open = !cp.open } }
        Text { text: cp.color; font.family: Config.theme.monoFont; font.pixelSize: Styling.fontSize(-4); color: Colors.overSurfaceVariant; Layout.fillWidth: true }
    }

    ColumnLayout { anchors.top: header.bottom; anchors.topMargin: 4; anchors.left: parent.left; anchors.leftMargin: 34; width: parent.width - 34; visible: cp.open; spacing: 3
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 16; radius: 3
            gradient: Gradient { orientation: Gradient.Horizontal
                GradientStop { position: 0.0;  color: "#FF0000" }
                GradientStop { position: 0.17; color: "#FFFF00" }
                GradientStop { position: 0.33; color: "#00FF00" }
                GradientStop { position: 0.50; color: "#00FFFF" }
                GradientStop { position: 0.67; color: "#0000FF" }
                GradientStop { position: 0.83; color: "#FF00FF" }
                GradientStop { position: 1.0;  color: "#FF0000" }
            }
            Rectangle { x: parent.width * cp.hue - 6; y: -2; width: 12; height: parent.height + 4; radius: 2; color: "transparent"; border.width: 2; border.color: Colors.overBackground }
            MouseArea { anchors.fill: parent
                onPositionChanged: cp.pick(Math.max(0,Math.min(1,mouse.x/parent.width)), cp.sat, cp.light)
                onClicked: cp.pick(Math.max(0,Math.min(1,mouse.x/parent.width)), cp.sat, cp.light)
            }
        }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 16; radius: 3
            gradient: Gradient { orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#000000" }
                GradientStop { position: 0.5; color: cp.hsvHex(cp.hue, cp.sat, 0.5) }
                GradientStop { position: 1.0; color: "#FFFFFF" }
            }
            Rectangle { x: parent.width * cp.light - 6; y: -2; width: 12; height: parent.height + 4; radius: 2; color: "transparent"; border.width: 2; border.color: Colors.overBackground }
            MouseArea { anchors.fill: parent
                onPositionChanged: cp.pick(cp.hue, cp.sat, Math.max(0,Math.min(1,mouse.x/parent.width)))
                onClicked: cp.pick(cp.hue, cp.sat, Math.max(0,Math.min(1,mouse.x/parent.width)))
            }
        }
    }
}
