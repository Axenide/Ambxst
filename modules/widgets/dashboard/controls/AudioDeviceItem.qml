pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

Item {
    id: root

    required property PwNode node
    property bool isOutput: true
    property bool isSelected: false

    implicitHeight: 40
    implicitWidth: parent?.width ?? 300

    PwObjectTracker {
        objects: [root.node]
    }

    StyledRect {
        anchors.fill: parent
        variant: isSelected ? "primary" : (mouseArea.containsMouse ? "focus" : "common")
        radius: isSelected ? Styling.radius(-4) : Styling.radius(4)
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            if (root.isOutput) {
                Audio.setDefaultSink(root.node);
            } else {
                Audio.setDefaultSource(root.node);
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: 8
        anchors.bottomMargin: 8
        spacing: 12

        // Device icon
        Text {
            text: root.isOutput ? Icons.speakerHigh : Icons.mic
            font.family: Icons.font
            font.pixelSize: 18
            color: root.isSelected ? Styling.srItem("primary") : Colors.overBackground
        }

        // Device name
        Text {
            Layout.fillWidth: true
            text: Audio.friendlyDeviceName(root.node)
            font.family: Config.theme.font
            font.pixelSize: Config.theme.fontSize
            font.weight: root.isSelected ? Font.Bold : Font.Normal
            color: root.isSelected ? Styling.srItem("primary") : Colors.overBackground
            elide: Text.ElideRight
        }

        // Selected indicator
        Text {
            visible: root.isSelected
            text: Icons.accept
            font.family: Icons.font
            font.pixelSize: 16
            color: Styling.srItem("primary")
        }
    }
}
