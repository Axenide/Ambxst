import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.config

StyledRect {
    id: root

    required property bool isActive
    required property string iconName
    required property string tooltipText
    signal clicked
    signal rightClicked
    signal longPressed

    property bool isHovered: mouseArea.containsMouse

    variant: {
        if (isActive && isHovered)
            return "primaryfocus";
        if (isActive)
            return "primary";
        if (isHovered)
            return "focus";
        return "pane";
    }

    radius: root.isActive ? Styling.radius(0) : Styling.radius(4)

    Text {
        anchors.centerIn: parent
        text: root.iconName
        color: root.item
        font.family: Icons.font
        font.pixelSize: 18
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        Behavior on color {
            enabled: Config.animDuration > 0
            ColorAnimation {
                duration: Config.animDuration / 2
                easing.type: Easing.OutQuart
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        pressAndHoldInterval: 1000
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                root.rightClicked();
            } else {
                root.clicked();
            }
        }
        onPressAndHold: root.longPressed()

        StyledToolTip {
            visible: mouseArea.containsMouse
            tooltipText: root.tooltipText
        }
    }
}
