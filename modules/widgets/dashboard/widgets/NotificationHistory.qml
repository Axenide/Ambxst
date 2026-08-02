import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.notifications
import qs.config
import qs.modules.globals

Item {
    id: root
    property var cascadeItems: []
    property int cascadeIndex: -1

    Shortcut {
        sequence: "Ctrl+L"
        enabled: GlobalStates.dashboardOpen && GlobalStates.dashboardCurrentTab === 0 && GlobalStates.widgetsTabCurrentIndex === 0
        onActivated: discardAllWithAnimation()
    }

    function discardAllWithAnimation() {
        const children = notificationList.contentItem.children;
        if (children.length === 0) {
            Notifications.discardAllNotifications();
            return;
        }

        // Capture the current items to avoid issues if they change during animation
        cascadeItems = [];
        for (let i = 0; i < children.length; i++) {
            if (children[i] && children[i].destroyWithAnimation) {
                cascadeItems.push(children[i]);
            }
        }

        if (cascadeItems.length === 0) {
            Notifications.discardAllNotifications();
            return;
        }

        cascadeIndex = cascadeItems.length - 1; // Start from last
        cascadeTimer.restart();
    }

    Timer {
        id: cascadeTimer
        interval: 100 // 0.1 seconds delay between each animation
        repeat: true
        onTriggered: {
            if (cascadeIndex >= 0) {
                const item = cascadeItems[cascadeIndex];
                if (item && item.destroyWithAnimation) {
                    item.destroyWithAnimation(true);
                }
                cascadeIndex--;
            } else {
                // All animations started, schedule final discard
                stop();
                cascadeItems = []; // Clear
                const totalDelay = Config.animDuration + 50;
                discardAllTimer.interval = totalDelay;
                discardAllTimer.restart();
            }
        }
    }

    Timer {
        id: discardAllTimer
        interval: Config.animDuration + 50 // Animation duration + small buffer
        repeat: false
        onTriggered: Notifications.discardAllNotifications()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        StyledRect {
            id: notificationPane
            variant: "pane"
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Styling.radius(4)
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 4
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    Layout.maximumHeight: 32
                    spacing: 4

                    StyledRect {
                        id: titleRect
                        variant: "internalbg"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Styling.radius(0)

                        Text {
                            anchors.centerIn: parent
                            text: "Notifications"
                            font.family: Config.defaultFont
                            font.pixelSize: Config.theme.fontSize
                            font.weight: Font.Bold
                            color: titleRect.item
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    StyledRect {
                        id: dndToggle
                        variant: Notifications.silent ? "primary" : (dndHover.containsMouse ? "focus" : "internalbg")
                        Layout.preferredWidth: 32
                        Layout.fillHeight: true
                        radius: Notifications.silent ? Styling.radius(-4) : Styling.radius(0)

                        readonly property color dndItem: Notifications.silent ? itemColor : Styling.srItem("overprimary")

                        Text {
                            anchors.centerIn: parent
                            text: Notifications.silent ? Icons.bellZ : Icons.bell
                            textFormat: Text.RichText
                            font.family: Icons.font
                            font.pixelSize: Styling.fontSize(4)
                            color: dndToggle.dndItem
                        }

                        MouseArea {
                            id: dndHover
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: Notifications.silent = !Notifications.silent
                        }
                    }

                    StyledRect {
                        id: clearButton
                        variant: broomHover.pressed ? "error" : (broomHover.containsMouse ? "focus" : "internalbg")
                        Layout.preferredWidth: 32
                        Layout.fillHeight: true
                        radius: Styling.radius(0)

                        readonly property color clearItem: broomHover.pressed ? itemColor : Styling.srItem("overerror")

                        Text {
                            anchors.centerIn: parent
                            text: Icons.broom
                            textFormat: Text.RichText
                            font.family: Icons.font
                            font.pixelSize: Styling.fontSize(4)
                            color: clearButton.clearItem
                        }

                        MouseArea {
                            id: broomHover
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: discardAllWithAnimation()
                        }
                    }
                }

                ClippingRectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "transparent"
                    radius: Styling.radius(0)

                    Flickable {
                        anchors.fill: parent
                        contentWidth: width
                        contentHeight: notificationList.contentHeight
                        clip: true

                        ListView {
                            id: notificationList
                            width: parent.width
                            height: contentHeight
                            spacing: 4
                            model: Notifications.appNameList
                            interactive: false
                            cacheBuffer: 200
                            reuseItems: true

                            delegate: NotificationGroup {
                                required property int index
                                required property string modelData
                                width: notificationList.width
                                notificationGroup: Notifications.groupsByAppName[modelData]
                                expanded: false
                                popup: false
                            }
                        }
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 16
                visible: Notifications.appNameList.length === 0

                Image {
                    mipmap: true
                    source: Qt.resolvedUrl("../../../../assets/ambxst+/ambxst+-logo.svg")
                    opacity: 0.25
                    sourceSize.width: 64
                    sourceSize.height: 64
                    fillMode: Image.PreserveAspectFit
                    anchors.horizontalCenter: parent.horizontalCenter
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        brightness: 1.0
                        colorization: 1.0
                        colorizationColor: Styling.srItem("pane")
                    }
                }
            }
        }
    }
}
