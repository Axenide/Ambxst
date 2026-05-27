pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.modules.theme

/*!
    DesktopWidgets.qml — Desktop overlay widgets.

    Shows a clock, date, and system info overlay on the desktop background.
    Uses WlrLayer.Background layer so widgets float above the wallpaper.

    Visibility controlled by Config.desktopWidgets.enabled.
*/
Item {
    id: root

    property bool enabled: Config.desktopWidgets && Config.desktopWidgets.enabled
    property bool _visible: false

    // Smooth entrance
    opacity: _visible ? 1 : 0
    Behavior on opacity {
        enabled: Anim.animationsEnabled
        NumberAnimation {
            duration: Anim.emphasizedLarge
            easing.type: Anim.easing("emphasized").type
            easing.bezierCurve: Anim.easing("emphasized").bezierCurve
        }
    }

    Component.onCompleted: Qt.callLater(() => root._visible = true)

    // Clock widget
    Item {
        id: clockWidget
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.08
        width: clockColumn.width + 80
        height: clockColumn.height + 40
        visible: root.enabled && Config.desktopWidgets && Config.desktopWidgets.showClock !== false

        ColumnLayout {
            id: clockColumn
            anchors.centerIn: parent
            spacing: 4

            Text {
                id: timeText
                text: new Date().toLocaleTimeString(Qt.locale(), Locale.ShortFormat)
                font.family: Config.theme.font || "Ndot"
                font.pixelSize: 64
                font.weight: Font.Light
                color: Qt.rgba(1, 1, 1, 0.6)
                horizontalAlignment: Text.AlignHCenter
                Layout.alignment: Qt.AlignHCenter

                Timer {
                    interval: 1000
                    running: root.enabled
                    repeat: true
                    onTriggered: {
                        timeText.text = new Date().toLocaleTimeString(Qt.locale(), Locale.ShortFormat);
                    }
                }
            }

            Text {
                id: dateText
                text: new Date().toLocaleDateString(Qt.locale(), Locale.LongFormat)
                font.family: Config.theme.font
                font.pixelSize: 18
                color: Qt.rgba(1, 1, 1, 0.4)
                horizontalAlignment: Text.AlignHCenter
                Layout.alignment: Qt.AlignHCenter

                Timer {
                    interval: 30000
                    running: root.enabled
                    repeat: true
                    onTriggered: {
                        dateText.text = new Date().toLocaleDateString(Qt.locale(), Locale.LongFormat);
                    }
                }
            }
        }
    }

    // Quick note / greeting
    Text {
        id: greetingText
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 40
        text: {
            const h = new Date().getHours();
            if (h < 12) return "Good morning";
            if (h < 18) return "Good afternoon";
            return "Good evening";
        }
        font.family: Config.theme.font
        font.pixelSize: 14
        color: Qt.rgba(1, 1, 1, 0.3)
        visible: root.enabled && Config.desktopWidgets && Config.desktopWidgets.showGreeting !== false
    }
}
