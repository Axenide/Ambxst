pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.config

// Titlebar for control panels with title, status, toggle and action buttons
RowLayout {
    id: root

    property string title: ""
    property string statusText: ""
    property color statusColor: Styling.srItem("overprimary")
    property bool showToggle: false
    property bool toggleChecked: false

    // Action buttons configuration
    // Each action: { icon: "...", tooltip: "...", onClicked: function, enabled: true, loading: false }
    property var actions: []

    // Custom content slot (appears between spacer and actions)
    default property alias customContent: customContentContainer.data

    signal toggleChanged(bool checked)

    Layout.fillWidth: true
    Layout.preferredHeight: 36
    spacing: 8

    // Title
    Text {
        text: root.title
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(0)
        font.weight: Font.Medium
        color: Colors.overBackground
    }

    // Status text (e.g., "Connecting...", "Bypassed")
    Text {
        visible: root.statusText !== ""
        text: root.statusText
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-2)
        color: root.statusColor
    }

    Item {
        Layout.fillWidth: true
    }

    // Custom content container
    Item {
        id: customContentContainer
        Layout.preferredWidth: childrenRect.width
        Layout.preferredHeight: childrenRect.height
        visible: children.length > 0
    }

    // Action buttons
    Repeater {
        model: root.actions

        delegate: Button {
            id: actionButton
            required property var modelData
            required property int index
            flat: true
            implicitWidth: 28
            implicitHeight: 28
            enabled: (modelData.enabled !== undefined ? modelData.enabled : true) && !(modelData.loading ?? false)

            property bool isLoading: modelData.loading ?? false

            background: StyledRect {
                variant: actionButton.hovered ? "focus" : "common"
                radius: Styling.radius(-4)
            }

            contentItem: Text {
                id: iconText
                text: actionButton.modelData.icon || ""
                font.family: Icons.font
                font.pixelSize: 14
                color: actionButton.isLoading ? Styling.srItem("overprimary") : (actionButton.enabled ? Colors.overBackground : Colors.outline)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter

                RotationAnimation on rotation {
                    running: actionButton.isLoading
                    from: 0
                    to: 360
                    duration: 1000
                    loops: Animation.Infinite
                }
            }

            onClicked: {
                if (actionButton.modelData.onClicked) {
                    actionButton.modelData.onClicked();
                }
            }

            StyledToolTip {
                visible: actionButton.hovered && actionButton.modelData.tooltip
                tooltipText: actionButton.modelData.tooltip || ""
            }
        }
    }

    // Toggle switch
    Switch {
        id: toggleSwitch
        visible: root.showToggle
        checked: root.toggleChecked
        onCheckedChanged: root.toggleChanged(checked)

        indicator: Rectangle {
            implicitWidth: 40
            implicitHeight: 20
            x: toggleSwitch.leftPadding
            y: parent.height / 2 - height / 2
            radius: height / 2
            color: toggleSwitch.checked ? Styling.srItem("overprimary") : Colors.surfaceBright
            border.color: toggleSwitch.checked ? Styling.srItem("overprimary") : Colors.outline

            Behavior on color {
                enabled: Config.animDuration > 0
                ColorAnimation {
                    duration: Config.animDuration / 2
                }
            }

            Rectangle {
                x: toggleSwitch.checked ? parent.width - width - 2 : 2
                y: 2
                width: parent.height - 4
                height: width
                radius: width / 2
                color: toggleSwitch.checked ? Colors.background : Colors.overSurfaceVariant

                Behavior on x {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration / 2
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
        background: null
    }
}
