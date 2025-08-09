import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components

BgRect {
    id: clockContainer

    property string currentTime: ""

    Layout.preferredWidth: timeDisplay.implicitWidth + 18
    Layout.preferredHeight: 36

    Text {
        id: timeDisplay
        anchors.centerIn: parent

        text: clockContainer.currentTime
        color: Colors.adapter.overBackground
        font.pixelSize: 14
        font.family: Styling.defaultFont
        font.bold: true
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            var now = new Date();
            clockContainer.currentTime = Qt.formatDateTime(now, "hh:mm:ss");
        }
    }
}
