import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.modules.theme
import qs.modules.components
import qs.modules.globals
import qs.modules.services
import qs.config
import "calendar"

Rectangle {
    id: root
    color: "transparent"
    implicitWidth: 600
    implicitHeight: 750

    property int leftPanelWidth: 0
    property int calDay: 0
    property int calMonth: 0
    property int calYear: 0

    function resetCalendarState() {
        calDay = 0;
        calMonth = 0;
        calYear = 0;
        calendarWidget.clearSelection();
    }

    Connections {
        target: GlobalStates
        function onDashboardOpenChanged() {
            if (!GlobalStates.dashboardOpen)
                resetCalendarState();
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 8

        FullPlayer {
            Layout.preferredWidth: 216
            Layout.fillHeight: true
        }

        // Widgets column
        ClippingRectangle {
            id: widgetsContainer
            Layout.preferredWidth: controlButtonsContainer.implicitWidth
            Layout.fillHeight: true
            radius: Styling.radius(4)
            color: "transparent"

            property bool circularControlDragging: false

            Flickable {
                id: widgetsFlickable
                anchors.fill: parent
                contentWidth: width
                contentHeight: columnLayout.implicitHeight
                clip: true
                interactive: !widgetsContainer.circularControlDragging

                ColumnLayout {
                    id: columnLayout
                    width: parent.width
                    spacing: 8

                    // Control buttons - 5 buttons wrapped in StyledRect pane > internalbg
                    QuickControls {
                        id: controlButtonsContainer
                    }

                    Calendar {
                        id: calendarWidget
                        Layout.fillWidth: true
                        Layout.preferredHeight: width
                        onOpenCalendarSettings: {
                            GlobalStates.settingsWindowVisible = true;
                            Qt.callLater(() => { GlobalStates.settingsCurrentTab = 9; });
                        }
                        onDaySelected: (d, m, y) => {
                            calDay = d;
                            calMonth = m;
                            calYear = y;
                        }
                    }

                    // Today's events panel
                    StyledRect {
                        id: todayEventsPanel
                        visible: CalendarService.hasAccounts && allEvents.length > 0
                        variant: "pane"
                        radius: Styling.radius(4)
                        Layout.fillWidth: true
                        implicitHeight: todayEventsCol.implicitHeight + 16

                        property var allEvents: CalendarService.todayEvents()
                        property var upcomingEvents: {
                            const now = new Date();
                            return allEvents.filter(ev => {
                                if (ev.allDay) return true;
                                try { return new Date(ev.end || ev.start) >= now; } catch(e) { return true; }
                            });
                        }
                        property var pastEvents: {
                            const now = new Date();
                            return allEvents.filter(ev => {
                                if (ev.allDay) return false;
                                try { return new Date(ev.end || ev.start) < now; } catch(e) { return false; }
                            });
                        }

                        Connections {
                            target: CalendarService
                            function onEventsChanged() { todayEventsPanel.allEvents = CalendarService.todayEvents(); }
                        }

                        component EventRow: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 8
                            Rectangle {
                                width: 3; height: 32; radius: 2
                                color: CalendarService.calendarColor(modelData.calendarId)
                                Layout.alignment: Qt.AlignVCenter
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.title || "Untitled"
                                    font.family: Config.defaultFont
                                    font.pixelSize: Styling.fontSize(-2)
                                    font.weight: Font.Medium
                                    color: Colors.overSurface
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: {
                                        if (modelData.allDay) return "All day";
                                        const s = modelData.start || "";
                                        const e = modelData.end || "";
                                        const st = s.includes("T") ? s.split("T")[1].substring(0,5) : "";
                                        const et = e.includes("T") ? e.split("T")[1].substring(0,5) : "";
                                        return st + (et ? " – " + et : "");
                                    }
                                    font.family: Config.defaultFont
                                    font.pixelSize: Styling.fontSize(-3)
                                    color: Colors.outline
                                }
                            }
                        }

                        ColumnLayout {
                            id: todayEventsCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 8
                            spacing: 4

                            // Upcoming section
                            Text {
                                visible: todayEventsPanel.upcomingEvents.length > 0
                                text: "Upcoming"
                                font.family: Config.defaultFont
                                font.pixelSize: Styling.fontSize(-3)
                                font.weight: Font.Medium
                                color: Colors.outline
                                Layout.topMargin: 2
                            }

                            Repeater {
                                model: todayEventsPanel.upcomingEvents
                                delegate: EventRow {}
                            }

                            // Past section
                            Text {
                                visible: todayEventsPanel.pastEvents.length > 0
                                text: "Past"
                                font.family: Config.defaultFont
                                font.pixelSize: Styling.fontSize(-3)
                                font.weight: Font.Medium
                                color: Colors.outline
                                Layout.topMargin: todayEventsPanel.upcomingEvents.length > 0 ? 4 : 2
                                opacity: 0.6
                            }

                            Repeater {
                                model: todayEventsPanel.pastEvents
                                delegate: Item {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    implicitHeight: pastRow.implicitHeight
                                    opacity: 0.5
                                    EventRow {
                                        id: pastRow
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        modelData: parent.modelData
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Notification / Event detail area
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            NotificationHistory {
                anchors.fill: parent
                opacity: root.calDay === 0 ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation { duration: Config.animDuration / 2; easing.type: Easing.OutCubic }
                }
            }

            EventDetailPanel {
                anchors.fill: parent
                opacity: root.calDay > 0 ? 1 : 0
                visible: opacity > 0
                day: root.calDay
                month: root.calMonth
                year: root.calYear
                onClosed: { root.calDay = 0; calendarWidget.clearSelection(); }
                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation { duration: Config.animDuration / 2; easing.type: Easing.OutCubic }
                }
            }
        }

        // Circular controls column
        ColumnLayout {
            Layout.fillHeight: true
            spacing: 8

            property bool circularControlDragging: false

            // Brightness slider - vertical
            ColumnLayout {
                id: brightnessContainer
                Layout.fillHeight: true
                Layout.minimumHeight: 100
                spacing: 8

                // Icon container with sync animation
                Item {
                    id: iconContainer
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    Layout.alignment: Qt.AlignHCenter

                    property bool showingSyncFeedback: false

                    StyledRect {
                        id: iconRect
                        radius: Styling.radius(4)
                        variant: {
                            if (iconMouseArea.containsMouse && Brightness.syncBrightness)
                                return "primaryfocus";
                            if (Brightness.syncBrightness)
                                return "primary";
                            if (iconMouseArea.containsMouse)
                                return "focus";
                            return "pane";
                        }
                        anchors.fill: parent

                        Behavior on variant {
                            enabled: Config.animDuration > 0
                        }

                        Text {
                            id: brightnessIcon
                            anchors.centerIn: parent
                            text: iconContainer.showingSyncFeedback ? Icons.sync : Icons.sun
                            font.family: Icons.font
                            font.pixelSize: 18
                            color: Brightness.syncBrightness ? Styling.srItem("primary") : Colors.overBackground
                            rotation: iconContainer.showingSyncFeedback ? syncIconRotation : brightnessIconRotation
                            scale: iconContainer.showingSyncFeedback ? 1 : brightnessIconScale
                            opacity: iconOpacity

                            property real brightnessIconRotation: 0
                            property real brightnessIconScale: 1
                            property real iconOpacity: 1
                            property real syncIconRotation: 0

                            Behavior on text {
                                enabled: Config.animDuration > 0
                            }

                            Behavior on color {
                                enabled: Config.animDuration > 0
                                ColorAnimation {
                                    duration: Config.animDuration / 2
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Behavior on opacity {
                                enabled: Config.animDuration > 0
                                NumberAnimation {
                                    duration: 150
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Behavior on rotation {
                                enabled: Config.animDuration > 0
                                NumberAnimation {
                                    duration: 400
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Behavior on scale {
                                enabled: Config.animDuration > 0
                                NumberAnimation {
                                    duration: 400
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        MouseArea {
                            id: iconMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                let wasActive = Brightness.syncBrightness;
                                Brightness.syncBrightness = !Brightness.syncBrightness;

                                // Only show sync feedback animation when activating
                                if (Brightness.syncBrightness) {
                                    // Show sync icon instantly and start rotation
                                    iconContainer.showingSyncFeedback = true;
                                    brightnessIcon.iconOpacity = 1;
                                    brightnessIcon.syncIconRotation = 0;
                                    brightnessIcon.syncIconRotation = 360;

                                    // Hold sync icon
                                    syncHoldTimer.start();
                                }
                            }
                            onWheel: wheel => {
                                if (wheel.angleDelta.y > 0) {
                                    brightnessSlider.value = Math.min(1, brightnessSlider.value + 0.1);
                                } else {
                                    brightnessSlider.value = Math.max(0, brightnessSlider.value - 0.1);
                                }
                            }
                        }

                        Timer {
                            id: syncHoldTimer
                            interval: 600
                            onTriggered: {
                                brightnessIcon.iconOpacity = 0;
                                syncFadeOutTimer.start();
                            }
                        }

                        Timer {
                            id: syncFadeOutTimer
                            interval: 150
                            onTriggered: {
                                iconContainer.showingSyncFeedback = false;
                                brightnessIcon.iconOpacity = 1;
                                brightnessIcon.syncIconRotation = 0; // Reset rotation
                            }
                        }
                    }
                }

                // Slider
                Item {
                    Layout.preferredWidth: 48
                    Layout.fillHeight: true
                    Layout.alignment: Qt.AlignHCenter

                    StyledSlider {
                        id: brightnessSlider
                        anchors.fill: parent
                        anchors.margins: 0
                        vertical: true
                        smoothDrag: true
                        value: brightnessValue
                        resizeParent: false
                        wavy: false
                        scroll: true
                        iconClickable: false
                        sliderVisible: true
                        iconPos: "start"
                        icon: ""
                        progressColor: Styling.srItem("overprimary")

                        property real brightnessValue: 0
                        property var currentMonitor: {
                            if (Brightness.monitors.length > 0) {
                                let focusedName = AxctlService.focusedMonitor?.name ?? "";
                                let found = null;
                                for (let i = 0; i < Brightness.monitors.length; i++) {
                                    let mon = Brightness.monitors[i];
                                    if (mon && mon.screen && mon.screen.name === focusedName) {
                                        found = mon;
                                        break;
                                    }
                                }
                                return found || Brightness.monitors[0];
                            }
                            return null;
                        }

                        Component.onCompleted: {
                            if (currentMonitor && currentMonitor.ready) {
                                brightnessValue = currentMonitor.brightness;
                                brightnessIcon.brightnessIconRotation = (brightnessValue / 1.0) * 180;
                                brightnessIcon.brightnessIconScale = 0.8 + (brightnessValue / 1.0) * 0.2;
                            }
                        }

                        onValueChanged: {
                            brightnessValue = value;
                            brightnessIcon.brightnessIconRotation = (value / 1.0) * 180;
                            brightnessIcon.brightnessIconScale = 0.8 + (value / 1.0) * 0.2;

                            if (Brightness.syncBrightness) {
                                // Sync all monitors
                                for (let i = 0; i < Brightness.monitors.length; i++) {
                                    let mon = Brightness.monitors[i];
                                    if (mon && mon.ready) {
                                        mon.setBrightness(value);
                                    }
                                }
                            } else {
                                // Only current monitor
                                if (currentMonitor && currentMonitor.ready) {
                                    currentMonitor.setBrightness(value);
                                }
                            }
                        }

                        onIsDraggingChanged: {
                            brightnessContainer.parent.circularControlDragging = isDragging;
                        }

                        Connections {
                            target: brightnessSlider.currentMonitor
                            ignoreUnknownSignals: true
                            function onBrightnessChanged() {
                                if (brightnessSlider.currentMonitor && brightnessSlider.currentMonitor.ready && !brightnessSlider.isDragging) {
                                    brightnessSlider.brightnessValue = brightnessSlider.currentMonitor.brightness;
                                    brightnessIcon.brightnessIconRotation = (brightnessSlider.brightnessValue / 1.0) * 180;
                                    brightnessIcon.brightnessIconScale = 0.8 + (brightnessSlider.brightnessValue / 1.0) * 0.2;
                                }
                            }
                            function onReadyChanged() {
                                if (brightnessSlider.currentMonitor && brightnessSlider.currentMonitor.ready) {
                                    brightnessSlider.brightnessValue = brightnessSlider.currentMonitor.brightness;
                                    brightnessIcon.brightnessIconRotation = (brightnessSlider.brightnessValue / 1.0) * 180;
                                    brightnessIcon.brightnessIconScale = 0.8 + (brightnessSlider.brightnessValue / 1.0) * 0.2;
                                }
                            }
                        }
                    }
                }
            }

            CircularControl {
                id: volumeControl
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                icon: {
                    if (Audio.sink?.audio?.muted)
                        return Icons.speakerSlash;
                    const vol = Audio.sink?.audio?.volume ?? 0;
                    if (vol < 0.01)
                        return Icons.speakerX;
                    if (vol < 0.19)
                        return Icons.speakerNone;
                    if (vol < 0.49)
                        return Icons.speakerLow;
                    return Icons.speakerHigh;
                }
                value: Audio.sink?.audio?.volume ?? 0
                accentColor: Audio.sink?.audio?.muted ? Colors.outline : Styling.srItem("overprimary")
                isToggleable: true
                isToggled: !(Audio.sink?.audio?.muted ?? false)

                onControlValueChanged: newValue => {
                    if (Audio.sink?.audio) {
                        Audio.sink.audio.volume = newValue;
                    }
                }

                onDraggingChanged: isDragging => {
                    parent.circularControlDragging = isDragging;
                }

                onToggled: {
                    if (Audio.sink?.audio) {
                        Audio.sink.audio.muted = !Audio.sink.audio.muted;
                    }
                }
            }

            CircularControl {
                id: micControl
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                icon: Audio.source?.audio?.muted ? Icons.micSlash : Icons.mic
                value: Audio.source?.audio?.volume ?? 0
                accentColor: Audio.source?.audio?.muted ? Colors.outline : Styling.srItem("overprimary")
                isToggleable: true
                isToggled: !(Audio.source?.audio?.muted ?? false)

                onControlValueChanged: newValue => {
                    if (Audio.source?.audio) {
                        Audio.source.audio.volume = newValue;
                    }
                }

                onDraggingChanged: isDragging => {
                    parent.circularControlDragging = isDragging;
                }

                onToggled: {
                    if (Audio.source?.audio) {
                        Audio.source.audio.muted = !Audio.source.audio.muted;
                    }
                }
            }
        }
    }
}
