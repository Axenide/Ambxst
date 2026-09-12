pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.services
import qs.modules.components
import qs.modules.theme
import qs.modules.globals
import qs.config

Item {
    id: root

    required property var bar

    property bool vertical: bar.orientation === "vertical"
    property bool isHovered: false
    property bool layerEnabled: true

    property real radius: 0
    property real startRadius: radius
    property real endRadius: radius

    property bool popupOpen: layoutPopup.isOpen

    Layout.preferredWidth: 36
    Layout.preferredHeight: 36
    Layout.maximumWidth: 36
    Layout.maximumHeight: 36
    Layout.fillWidth: vertical
    Layout.fillHeight: !vertical

    HoverHandler {
        onHoveredChanged: root.isHovered = hovered
    }

    StyledRect {
        id: buttonBg
        variant: root.popupOpen ? "primary" : "bg"
        anchors.fill: parent
        enableShadow: root.layerEnabled

        topLeftRadius: root.vertical ? root.startRadius : root.startRadius
        topRightRadius: root.vertical ? root.startRadius : root.endRadius
        bottomLeftRadius: root.vertical ? root.endRadius : root.startRadius
        bottomRightRadius: root.vertical ? root.endRadius : root.endRadius

        Rectangle {
            anchors.fill: parent
            color: Styling.srItem("overprimary")
            opacity: root.popupOpen ? 0 : (root.isHovered ? 0.25 : 0)
            radius: parent.radius ?? 0

            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 2
                }
            }
        }

        Text {
            anchors.centerIn: parent
            text: KeyboardLayoutService.displayCode
            font.family: Styling.defaultFont
            font.pixelSize: 13
            font.bold: true
            color: root.popupOpen ? buttonBg.item : Styling.srItem("overprimary")

            Behavior on color {
                enabled: Config.animDuration > 0
                ColorAnimation {
                    duration: Config.animDuration / 2
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: false
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton) {
                    layoutPopup.toggle();
                } else {
                    KeyboardLayoutService.switchLayout();
                }
            }
        }

        StyledToolTip {
            visible: root.isHovered && !root.popupOpen
            tooltipText: KeyboardLayoutService.currentKeymap || ("Layout: " + KeyboardLayoutService.displayCode)
        }
    }

    BarPopup {
        id: layoutPopup
        anchorItem: buttonBg
        bar: root.bar

        contentWidth: layoutRow.implicitWidth + popupPadding * 2
        contentHeight: 36 + popupPadding * 2

        Row {
            id: layoutRow
            anchors.centerIn: parent
            spacing: 4

            Repeater {
                model: KeyboardLayoutService.availableLayouts

                delegate: StyledRect {
                    id: layoutButton
                    required property string modelData
                    required property int index

                    readonly property bool isSelected: KeyboardLayoutService.currentIndex === index
                    readonly property bool isFirst: index === 0
                    readonly property bool isLast: index === KeyboardLayoutService.availableLayouts.length - 1
                    property bool buttonHovered: false

                    readonly property real defaultRadius: Styling.radius(0)
                    readonly property real selectedRadius: Styling.radius(0) / 2

                    variant: isSelected ? "primary" : (buttonHovered ? "focus" : "common")
                    enableShadow: false
                    width: layoutLabel.implicitWidth + 48
                    height: 36

                    topLeftRadius: isSelected ? (isFirst ? defaultRadius : selectedRadius) : defaultRadius
                    bottomLeftRadius: isSelected ? (isFirst ? defaultRadius : selectedRadius) : defaultRadius
                    topRightRadius: isSelected ? (isLast ? defaultRadius : selectedRadius) : defaultRadius
                    bottomRightRadius: isSelected ? (isLast ? defaultRadius : selectedRadius) : defaultRadius

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            text: Icons.globe
                            font.family: Icons.font
                            font.pixelSize: 14
                            color: layoutButton.item
                        }

                        Text {
                            id: layoutLabel
                            text: KeyboardLayoutService.getDisplayName(layoutButton.modelData)
                            font.family: Styling.defaultFont
                            font.pixelSize: Styling.fontSize(0)
                            font.bold: true
                            color: layoutButton.item
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onEntered: layoutButton.buttonHovered = true
                        onExited: layoutButton.buttonHovered = false

                        onClicked: {
                            KeyboardLayoutService.setLayout(layoutButton.index);
                            layoutPopup.close();
                        }
                    }
                }
            }
        }
    }
}
