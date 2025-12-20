pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import "../../widgets/dashboard/widgets"

Item {
    id: root

    property string currentTime: ""
    property string currentDayAbbrev: ""
    property string currentHours: ""
    property string currentMinutes: ""
    property string currentFullDate: ""

    required property var bar
    property bool vertical: bar.orientation === "vertical"
    property bool isHovered: false
    property bool layerEnabled: true

    // Popup visibility state
    property bool popupOpen: clockPopup.isOpen

    // Weather availability
    readonly property bool weatherAvailable: WeatherService.dataAvailable

    Layout.preferredWidth: vertical ? 36 : buttonBg.implicitWidth
    Layout.preferredHeight: vertical ? buttonBg.implicitHeight : 36

    HoverHandler {
        onHoveredChanged: root.isHovered = hovered
    }

    // Main button
    StyledRect {
        id: buttonBg
        variant: root.popupOpen ? "primary" : "bg"
        anchors.fill: parent
        enableShadow: root.layerEnabled

        implicitWidth: vertical ? 36 : rowLayout.implicitWidth + 24
        implicitHeight: vertical ? columnLayout.implicitHeight + 24 : 36

        Rectangle {
            anchors.fill: parent
            color: Colors.primary
            opacity: root.popupOpen ? 0 : (root.isHovered ? 0.25 : 0)
            radius: parent.radius ?? 0

            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 2
                }
            }
        }

        RowLayout {
            id: rowLayout
            visible: !root.vertical
            anchors.centerIn: parent
            spacing: 8

            Text {
                id: dayDisplay
                text: root.weatherAvailable ? WeatherService.weatherSymbol : root.currentDayAbbrev
                color: root.popupOpen ? buttonBg.itemColor : Colors.overBackground
                font.pixelSize: root.weatherAvailable ? 16 : Config.theme.fontSize
                font.family: root.weatherAvailable ? Config.theme.font : Config.theme.font
                font.bold: !root.weatherAvailable
            }

            Separator {
                id: separator
                vert: true
            }

            Text {
                id: timeDisplay
                text: root.currentTime
                color: root.popupOpen ? buttonBg.itemColor : Colors.overBackground
                font.pixelSize: Config.theme.fontSize
                font.family: Config.theme.font
                font.bold: true
            }
        }

        ColumnLayout {
            id: columnLayout
            visible: root.vertical
            anchors.centerIn: parent
            spacing: 4
            Layout.alignment: Qt.AlignHCenter

            Text {
                id: dayDisplayV
                text: root.weatherAvailable ? WeatherService.weatherSymbol : root.currentDayAbbrev
                color: root.popupOpen ? buttonBg.itemColor : Colors.overBackground
                font.pixelSize: root.weatherAvailable ? 16 : Config.theme.fontSize
                font.family: Config.theme.font
                font.bold: !root.weatherAvailable
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.NoWrap
                Layout.alignment: Qt.AlignHCenter
            }

            Separator {
                id: separatorV
                vert: false
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                id: hoursDisplayV
                text: root.currentHours
                color: root.popupOpen ? buttonBg.itemColor : Colors.overBackground
                font.pixelSize: Config.theme.fontSize
                font.family: Config.theme.font
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.NoWrap
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                id: minutesDisplayV
                text: root.currentMinutes
                color: root.popupOpen ? buttonBg.itemColor : Colors.overBackground
                font.pixelSize: Config.theme.fontSize
                font.family: Config.theme.font
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.NoWrap
                Layout.alignment: Qt.AlignHCenter
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: false
            cursorShape: Qt.PointingHandCursor
            onClicked: clockPopup.toggle()
        }
    }

    // Clock & Weather popup
    BarPopup {
        id: clockPopup
        anchorItem: buttonBg
        bar: root.bar
        visualMargin: 8
        popupPadding: 0

        contentWidth: 300
        contentHeight: 100

        onIsOpenChanged: {
            if (isOpen && !WeatherService.dataAvailable) {
                WeatherService.updateWeather();
            }
        }

        // Weather widget with sun arc
        Item {
            id: popupContent
            anchors.fill: parent
            anchors.margins: Config.theme.srPopup.border[1]

            WeatherWidget {
                anchors.fill: parent
                cornerRadius: Styling.radius(4 - Config.theme.srPopup.border[1])
                showDebugControls: true
            }
        }
    }

    function scheduleNextDayUpdate() {
        var now = new Date();
        var next = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1, 0, 0, 1);
        var ms = next - now;
        dayUpdateTimer.interval = ms;
        dayUpdateTimer.start();
    }

    function updateDay() {
        var now = new Date();
        var day = Qt.formatDateTime(now, Qt.locale(), "ddd");
        root.currentDayAbbrev = day.slice(0, 3).charAt(0).toUpperCase() + day.slice(1, 3);
        root.currentFullDate = Qt.formatDateTime(now, Qt.locale(), "dddd, MMMM d, yyyy");
        scheduleNextDayUpdate();
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            var now = new Date();
            var formatted = Qt.formatDateTime(now, "hh:mm");
            var parts = formatted.split(":");
            root.currentTime = formatted;
            root.currentHours = parts[0];
            root.currentMinutes = parts[1];
        }
    }

    Timer {
        id: dayUpdateTimer
        repeat: false
        running: false
        onTriggered: updateDay()
    }

    Component.onCompleted: {
        var now = new Date();
        var formatted = Qt.formatDateTime(now, "hh:mm");
        var parts = formatted.split(":");
        root.currentTime = formatted;
        root.currentHours = parts[0];
        root.currentMinutes = parts[1];
        updateDay();
    }
}
