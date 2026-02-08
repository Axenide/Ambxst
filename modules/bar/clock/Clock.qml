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
    
    property real radius: 0
    property real startRadius: radius
    property real endRadius: radius

    // Popup visibility state
    property bool popupOpen: clockPopup.isOpen

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

        topLeftRadius: root.vertical ? root.startRadius : root.startRadius
        topRightRadius: root.vertical ? root.startRadius : root.endRadius
        bottomLeftRadius: root.vertical ? root.endRadius : root.startRadius
        bottomRightRadius: root.vertical ? root.endRadius : root.endRadius

        implicitWidth: vertical ? 36 : rowLayout.implicitWidth + 24
        implicitHeight: vertical ? columnLayout.implicitHeight + 24 : 36

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

        RowLayout {
            id: rowLayout
            visible: !root.vertical
            anchors.centerIn: parent
            spacing: 8

            Text {
                id: dayDisplay
                text: root.weatherAvailable ? WeatherService.weatherSymbol : root.currentDayAbbrev
                color: root.popupOpen ? buttonBg.item : Colors.overBackground
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
                color: root.popupOpen ? buttonBg.item : Colors.overBackground
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
                color: root.popupOpen ? buttonBg.item : Colors.overBackground
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
                color: root.popupOpen ? buttonBg.item : Colors.overBackground
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
                color: root.popupOpen ? buttonBg.item : Colors.overBackground
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
        variant: "transparent"
        popupPadding: 0

        contentWidth: popupColumn.width
        contentHeight: popupColumn.height

        onIsOpenChanged: {
            if (isOpen && !WeatherService.dataAvailable) {
                WeatherService.updateWeather();
            }
        }

        // Main popup column
        Column {
            id: popupColumn
            spacing: 4

            // Mini weekly calendar
            StyledRect {
                id: calendarWrapper
                variant: "popup"
                radius: Styling.radius(8)
                enableShadow: false
                width: 300 + 16 // Match popupWrapper width
                height: calendarContent.height + 32

                property date currentDate: new Date()
                property int currentDayOfWeek: (currentDate.getDay() + 6) % 7  // Monday = 0
                property int currentDayOfMonth: currentDate.getDate()

                // Get the Monday of the current week
                function getWeekStart(date) {
                    var d = new Date(date);
                    var day = d.getDay();
                    var diff = d.getDate() - day + (day === 0 ? -6 : 1);
                    return new Date(d.setDate(diff));
                }

                property date weekStart: getWeekStart(currentDate)

                // Update date every minute
                Timer {
                    interval: 60000
                    running: !SuspendManager.isSuspending
                    repeat: true
                    onTriggered: calendarWrapper.currentDate = new Date()
                }

                Column {
                    id: calendarContent
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 16
                    spacing: 4

                    // Helper function to capitalize first letter
                    function capitalizeMonth(date) {
                        var month = date.toLocaleDateString(Qt.locale(), "MMMM");
                        return month.charAt(0).toUpperCase() + month.slice(1);
                    }

                    // Header row: Month and events count
                    Item {
                        width: daysRow.width
                        height: monthText.height

                        Text {
                            id: monthText
                            anchors.left: parent.left
                            anchors.leftMargin: 4
                            text: calendarContent.capitalizeMonth(calendarWrapper.currentDate)
                            color: Colors.outline
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(0)
                            font.weight: Font.Medium
                        }

                        // Placeholder for events count (future feature)
                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            text: ""
                            color: Colors.outline
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            visible: text !== ""
                        }
                    }

                    // Days of week row
                    Row {
                        id: daysRow
                        spacing: 4

                        Repeater {
                            model: 7

                            Column {
                                id: dayColumn
                                required property int index
                                spacing: 2
                                width: 36

                                // Get the date for this day of the week
                                property date dayDate: {
                                    var d = new Date(calendarWrapper.weekStart);
                                    d.setDate(d.getDate() + index);
                                    return d;
                                }
                                property bool isToday: index === calendarWrapper.currentDayOfWeek

                                // Day abbreviation from locale
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: {
                                        var dayName = dayColumn.dayDate.toLocaleDateString(Qt.locale(), "ddd");
                                        // Capitalize first letter and limit to 2 chars
                                        return (dayName.charAt(0).toUpperCase() + dayName.slice(1, 2)).replace(".", "");
                                    }
                                    color: Colors.overBackground
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(0)
                                    font.weight: Font.Medium
                                }

                                // Day number with circle for current day
                                Item {
                                    width: 28
                                    height: 28
                                    anchors.horizontalCenter: parent.horizontalCenter

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 28
                                        height: 28
                                        radius: Styling.radius(0)
                                        color: Styling.srItem("overprimary")
                                        visible: dayColumn.isToday
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: dayColumn.dayDate.getDate()
                                        color: dayColumn.isToday ? Colors.background : Colors.overBackground
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(0)
                                        font.weight: dayColumn.isToday ? Font.Bold : Font.Normal
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Weather Wrapper StyledRect
            StyledRect {
                id: popupWrapper
                variant: "popup"
                radius: Styling.radius(8)
                enableShadow: false
                width: popupContent.width + 16
                height: popupContent.height + 16
                visible: WeatherService.dataAvailable

                // Content container
                Column {
                    id: popupContent
                    anchors.centerIn: parent
                    spacing: 4

                    // Weather widget with sun arc
                    WeatherWidget {
                        id: weatherWidget
                        width: 300
                        height: 140
                        showDebugControls: true
                        animationsEnabled: clockPopup.isOpen
                    }

                    // 7-day forecast panel (below weather widget)
                    Item {
                        id: forecastPanel
                        width: weatherWidget.width
                        height: WeatherService.dataAvailable && WeatherService.forecast.length > 0 ? forecastContent.implicitHeight : 0
                        clip: true
                        visible: height > 0

                        StyledRect {
                            id: forecastContent
                            variant: "pane"
                            anchors.fill: parent
                            implicitHeight: forecastRow.implicitHeight + 16

                            Row {
                                id: forecastRow
                                anchors.centerIn: parent
                                spacing: 4

                                Repeater {
                                    model: WeatherService.forecast.slice(0, 5)

                                    Row {
                                        id: forecastDayRow
                                        required property var modelData
                                        required property int index
                                        spacing: 4

                                        Column {
                                            id: forecastDay
                                            spacing: 2
                                            width: (weatherWidget.width - 16 - (4 * 4) - (4 * 6)) / 5

                                            // Day name
                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: forecastDayRow.modelData.dayName
                                                color: Colors.overBackground
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(0)
                                                font.weight: Font.Medium
                                            }

                                            // Weather emoji
                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: forecastDayRow.modelData.emoji
                                                font.pixelSize: Styling.fontSize(4)
                                            }

                                            // Max temperature
                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: (Math.round(forecastDayRow.modelData.maxTemp) >= 0 ? "+" : "") + Math.round(forecastDayRow.modelData.maxTemp) + "\u00B0"
                                                color: Colors.overBackground
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(0)
                                                font.weight: Font.Bold
                                            }

                                            // Min temperature
                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: (Math.round(forecastDayRow.modelData.minTemp) >= 0 ? "+" : "") + Math.round(forecastDayRow.modelData.minTemp) + "\u00B0"
                                                color: Colors.outline
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(0)
                                                font.weight: Font.Normal
                                            }
                                        }

                                        // Separator between days (not after last)
                                        Separator {
                                            vert: true
                                            visible: forecastDayRow.index < 4
                                            anchors.verticalCenter: parent.verticalCenter
                                            height: forecastDay.height - 16
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Debug panel (below weather widget)
                    Item {
                        id: debugPanel
                        width: weatherWidget.width
                        height: WeatherService.debugMode ? debugContent.implicitHeight : 0
                        clip: true
                        visible: height > 0

                        ColumnLayout {
                            id: debugContent
                            anchors.fill: parent
                            spacing: 4

                            // Time slider pane
                            StyledRect {
                                variant: "pane"
                                Layout.fillWidth: true
                                Layout.preferredHeight: 36

                                StyledSlider {
                                    id: sliderContent
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    icon: Icons.clock
                                    value: WeatherService.debugHour / 24
                                    tooltipText: {
                                        var hour = Math.floor(WeatherService.debugHour);
                                        var minutes = Math.round((WeatherService.debugHour - hour) * 60);
                                        return hour.toString().padStart(2, '0') + ":" + minutes.toString().padStart(2, '0');
                                    }
                                    onValueChanged: WeatherService.debugHour = value * 24
                                }
                            }

                            // Weather type selector pane
                            StyledRect {
                                id: weatherSelector
                                variant: "pane"
                                Layout.fillWidth: true
                                Layout.preferredHeight: 64 + 8

                                readonly property int buttonPadding: 4
                                readonly property int buttonSpacing: 2

                                readonly property var weatherTypes: [
                                    {
                                        code: 0,
                                        icon: "☀️",
                                        name: "Clear"
                                    },
                                    {
                                        code: 1,
                                        icon: "🌤️",
                                        name: "Mainly clear"
                                    },
                                    {
                                        code: 2,
                                        icon: "⛅",
                                        name: "Partly cloudy"
                                    },
                                    {
                                        code: 3,
                                        icon: "☁️",
                                        name: "Overcast"
                                    },
                                    {
                                        code: 45,
                                        icon: "🌫️",
                                        name: "Fog"
                                    },
                                    {
                                        code: 51,
                                        icon: "🌦️",
                                        name: "Drizzle"
                                    },
                                    {
                                        code: 61,
                                        icon: "🌧️",
                                        name: "Rain"
                                    },
                                    {
                                        code: 65,
                                        icon: "🌧️",
                                        name: "Heavy rain"
                                    },
                                    {
                                        code: 71,
                                        icon: "❄️",
                                        name: "Snow"
                                    },
                                    {
                                        code: 75,
                                        icon: "❄️",
                                        name: "Heavy snow"
                                    },
                                    {
                                        code: 95,
                                        icon: "⛈️",
                                        name: "Thunder"
                                    },
                                    {
                                        code: 96,
                                        icon: "🌩️",
                                        name: "Hail"
                                    }
                                ]

                                readonly property int columns: 6
                                readonly property int rows: Math.ceil(weatherTypes.length / columns)

                                Grid {
                                    id: weatherButtonsGrid
                                    anchors.fill: parent
                                    anchors.margins: weatherSelector.buttonPadding
                                    columns: weatherSelector.columns
                                    rowSpacing: weatherSelector.buttonSpacing
                                    columnSpacing: weatherSelector.buttonSpacing

                                    Repeater {
                                        model: weatherSelector.weatherTypes

                                        delegate: StyledRect {
                                            id: weatherBtn
                                            required property var modelData
                                            required property int index

                                            readonly property bool isSelected: WeatherService.debugWeatherCode === modelData.code
                                            readonly property int row: Math.floor(index / weatherSelector.columns)
                                            readonly property int col: index % weatherSelector.columns
                                            readonly property bool isFirstCol: col === 0
                                            readonly property bool isLastCol: col === weatherSelector.columns - 1
                                            readonly property bool isFirstRow: row === 0
                                            readonly property bool isLastRow: row === weatherSelector.rows - 1
                                            property bool buttonHovered: false

                                            readonly property real defaultRadius: Styling.radius(0)
                                            readonly property real selectedRadius: Styling.radius(0) / 2

                                            readonly property real gridWidth: weatherButtonsGrid.width
                                            readonly property real gridHeight: weatherButtonsGrid.height

                                            variant: isSelected ? "primary" : (buttonHovered ? "focus" : "internalbg")
                                            enableShadow: false
                                            width: (gridWidth - (weatherSelector.columns - 1) * weatherSelector.buttonSpacing) / weatherSelector.columns
                                            height: (gridHeight - (weatherSelector.rows - 1) * weatherSelector.buttonSpacing) / weatherSelector.rows

                                            topLeftRadius: isSelected ? (isFirstCol && isFirstRow ? defaultRadius : selectedRadius) : defaultRadius
                                            topRightRadius: isSelected ? (isLastCol && isFirstRow ? defaultRadius : selectedRadius) : defaultRadius
                                            bottomLeftRadius: isSelected ? (isFirstCol && isLastRow ? defaultRadius : selectedRadius) : defaultRadius
                                            bottomRightRadius: isSelected ? (isLastCol && isLastRow ? defaultRadius : selectedRadius) : defaultRadius

                                            Text {
                                                anchors.centerIn: parent
                                                text: weatherBtn.modelData.icon
                                                font.pixelSize: 14
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onEntered: weatherBtn.buttonHovered = true
                                                onExited: weatherBtn.buttonHovered = false
                                                onClicked: WeatherService.debugWeatherCode = weatherBtn.modelData.code
                                            }

                                            StyledToolTip {
                                                visible: weatherBtn.buttonHovered
                                                tooltipText: weatherBtn.modelData.name
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Pomodoro Wrapper StyledRect
            StyledRect {
                id: pomodoroWrapper
                variant: "popup"
                radius: Styling.radius(8)
                enableShadow: false
                width: 300 + 16 // Match weather popup width
                height: pomodoroWidget.height + 16

                Pomodoro {
                    id: pomodoroWidget
                    anchors.centerIn: parent
                    width: 300
                    onRequestPopupOpen: clockPopup.open()
                }
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
        running: !SuspendManager.isSuspending
        repeat: true
        onTriggered: {
            var now = new Date();
            var format = Config.bar.use12hFormat ? "h:mm ap" : "hh:mm";
            var formatted = Qt.formatDateTime(now, format);
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
        var format = Config.bar.use12hFormat ? "h:mm ap" : "hh:mm";
        var formatted = Qt.formatDateTime(now, format);
        var parts = formatted.split(":");
        root.currentTime = formatted;
        root.currentHours = parts[0];
        root.currentMinutes = parts[1];
        updateDay();
    }
}
