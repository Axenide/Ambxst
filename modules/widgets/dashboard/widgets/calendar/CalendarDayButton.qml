import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.config

Rectangle {
    id: button

    required property string day
    required property int isToday
    property bool bold: false
    property bool isCurrentDayOfWeek: false

    Layout.fillWidth: true
    Layout.fillHeight: false
    Layout.preferredWidth: 28
    Layout.preferredHeight: 28

    color: "transparent"
    radius: Styling.radius(-2)

    StyledRect {
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height)
        height: width
        variant: (isToday === 1) ? "primary" : "transparent"
        radius: parent.radius

        Text {
            anchors.fill: parent
            text: day
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.weight: Font.Bold
            font.pixelSize: Styling.fontSize(-2)
            font.family: Config.defaultFont
            color: {
                if (isToday === 1)
                    return Styling.srItem("primary");
                if (bold) {
                    return isCurrentDayOfWeek ? Colors.overBackground : Colors.outline;
                }
                if (isToday === 0)
                    return Colors.overSurface;
                return Colors.surfaceBright;
            }

            Behavior on color {
                enabled: Config.animDuration > 0
                ColorAnimation {
                    duration: 150
                }
            }
        }
    }
}
