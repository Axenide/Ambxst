pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

Item {
    id: root
    implicitHeight: content.implicitHeight + 24
    width: 300

    // --- State & Logic ---
    property bool isRunning: false
    property bool isWorkSession: true
    property bool alarmActive: false
    
    // --- IPC & Notifications ---
    IpcHandler {
        target: "pomodoro"
        function check() {
            root.requestPopupOpen();
        }
        function stop() {
            root.stopAlarm();
            root.isRunning = false;
        }
    }

    signal requestPopupOpen()

    Process {
        id: notifyProcess
        stdout: StdioCollector { id: notifyStdout }
        onExited: (exitCode) => {
            let action = notifyStdout.text.trim();
            if (action === "check") {
                root.requestPopupOpen();
            } else if (action === "stop") {
                root.stopAlarm();
                root.isRunning = false;
            }
        }
    }
    
    // Internal countdown state
    property int timeLeft: Config.system.pomodoro.workTime
    property int totalTime: Config.system.pomodoro.workTime
    property real visualProgress: 1.0

    readonly property var spotifyPlayer: {
        for (let player of MprisController.filteredPlayers) {
            if (player.dbusName.toLowerCase().includes("spotify")) {
                return player;
            }
        }
        return null;
    }

    function updateSpotify() {
        if (!Config.system.pomodoro.syncSpotify || !root.spotifyPlayer) return;
        
        let spotify = root.spotifyPlayer;
        if (root.isRunning && root.isWorkSession) {
            if (!spotify.isPlaying && spotify.canPlay) spotify.play();
        } else {
            if (spotify.isPlaying && spotify.canPause) spotify.pause();
        }
    }

    onIsRunningChanged: updateSpotify()
    onIsWorkSessionChanged: updateSpotify()
    
    Connections {
        target: Config.system.pomodoro
        function onSyncSpotifyChanged() {
            root.updateSpotify();
        }
    }

    readonly property bool isResuming: !isRunning && !alarmActive && timeLeft > 0 && 
                                      timeLeft < (isWorkSession ? Config.system.pomodoro.workTime : Config.system.pomodoro.restTime)

    function toggleTimer() {
        if (alarmActive) {
            stopAlarm();
            nextSession();
            return;
        }
        
        if (!isRunning) {
            let configTime = isWorkSession ? Config.system.pomodoro.workTime : Config.system.pomodoro.restTime;
            // If we are at the beginning of a session, ensure totalTime is synced
            if (timeLeft === configTime) {
                totalTime = timeLeft;
            }
            isRunning = true;
        } else {
            isRunning = false;
        }
    }

    // Smooth progress animation
    NumberAnimation {
        id: progressAnim
        target: root
        property: "visualProgress"
        from: root.totalTime > 0 ? root.timeLeft / root.totalTime : 0
        to: 0
        duration: root.timeLeft * 1000
        running: root.isRunning && root.timeLeft > 0
    }

    // Reset visual progress when not running and time is adjusted
    onTimeLeftChanged: {
        if (!isRunning && !alarmActive) {
            visualProgress = totalTime > 0 ? timeLeft / totalTime : 0;
        }
    }

    function resetTimer() {
        stopAlarm();
        isRunning = false;
        isWorkSession = true;
        timeLeft = Config.system.pomodoro.workTime;
        totalTime = timeLeft;
        visualProgress = 1.0;
    }

    function startAlarm() {
        let finishedSession = isWorkSession ? "Work" : "Rest";
        isRunning = false;
        alarmActive = true;
        visualProgress = 0; // Ensure it's exactly 0
        
        if (alarmSoundLoader.item) {
            alarmSoundLoader.item.loops = Config.system.pomodoro.autoStart ? 2 : 255; // Infinite approx
            // Play alarm if going to rest (Work finished) OR if spotify sync is disabled/spotify not found
            if (root.isWorkSession || !(Config.system.pomodoro.syncSpotify && root.spotifyPlayer)) {
                alarmSoundLoader.active = true;
                alarmSoundLoader.item.play();
            } else if (Config.system.pomodoro.autoStart) {
                // If no sound and auto, clear alarm state immediately
                alarmActive = false;
            }
        } else {
            alarmSoundLoader.active = true;
        }

        if (Config.system.pomodoro.autoStart) {
            nextSession();
        }

        // Prepare notification command before running
        let cmd = [
            "notify-send",
            "-a", "Pomodoro",
            "Pomodoro",
            finishedSession + " session finished!"
        ];
        
        // Add wait and actions ONLY if notify-send supports them (most modern ones do)
        // Note: Removing --wait can help if the process hangs
        cmd.splice(1, 0, "--wait", "--action=check=Check", "--action=stop=Stop");
        
        notifyProcess.command = cmd;
        notifyProcess.running = true;
    }

    function stopAlarm() {
        if (alarmSoundLoader.item) {
            alarmSoundLoader.item.stop();
        }
        alarmActive = false;
    }

    function nextSession() {
        isWorkSession = !isWorkSession;
        timeLeft = isWorkSession ? Config.system.pomodoro.workTime : Config.system.pomodoro.restTime;
        totalTime = timeLeft;
        visualProgress = 1.0;
        if (Config.system.pomodoro.autoStart) {
            isRunning = true;
        }
    }

    Loader {
        id: alarmSoundLoader
        active: false
        source: "PomodoroSound.qml"
        onLoaded: {
            item.alarmActive = Qt.binding(() => root.alarmActive);
            item.autoStart = Qt.binding(() => Config.system.pomodoro.autoStart);
            item.stopAlarmRequested.connect(root.stopAlarm);
            
            item.loops = Config.system.pomodoro.autoStart ? 2 : 255;
            if (root.alarmActive && (root.isWorkSession || !(Config.system.pomodoro.syncSpotify && root.spotifyPlayer))) {
                item.play();
            } else if (Config.system.pomodoro.autoStart && root.alarmActive) {
                root.alarmActive = false;
            }
        }
    }

    Timer {
        id: countdownTimer
        interval: 1000
        running: root.isRunning && root.timeLeft > 0
        repeat: true
        onTriggered: {
            if (root.timeLeft > 0) {
                root.timeLeft--;
                if (root.timeLeft === 0) {
                    startAlarm();
                }
            }
        }
    }

    // --- UI Layout ---
    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        // Top Row: Small Configs
        RowLayout {
            Layout.fillWidth: true
            
            StyledRect {
                variant: "common"
                Layout.preferredHeight: 28
                Layout.preferredWidth: 110
                radius: Styling.radius(-4)
                
                Text {
                    anchors.centerIn: parent
                    text: root.isWorkSession ? "Work Session" : "Rest Session"
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    font.weight: Font.Bold
                    color: mouseAreaToggle.containsMouse ? Styling.srItem("overprimary") : Colors.overBackground
                }
                
                MouseArea {
                    id: mouseAreaToggle
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: !root.isRunning && !root.alarmActive
                    onClicked: {
                        root.isWorkSession = !root.isWorkSession;
                        let configTime = root.isWorkSession ? Config.system.pomodoro.workTime : Config.system.pomodoro.restTime;
                        root.timeLeft = configTime;
                        root.totalTime = configTime;
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Reset
            StyledRect {
                variant: "common"
                implicitWidth: 28; implicitHeight: 28
                radius: Styling.radius(-4)
                Text {
                    anchors.centerIn: parent
                    text: Icons.arrowCounterClockwise
                    font.family: Icons.font; font.pixelSize: 14
                    color: Colors.overBackground
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.resetTimer()
                }
            }
        }

        // Stack-like view for Timer Inputs
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            clip: true

            ColumnLayout {
                id: timerInputs
                anchors.centerIn: parent
                spacing: 4

                RowLayout {
                    spacing: 4
                    Layout.alignment: Qt.AlignHCenter
                    
                    TimerInput {
                        id: minIn
                        value: Math.floor(root.timeLeft / 60)
                        onValueUpdated: val => {
                            let newSeconds = (val * 60) + (root.timeLeft % 60);
                            root.timeLeft = newSeconds;
                            if (!root.isRunning) {
                                root.totalTime = newSeconds;
                                if (root.isWorkSession) Config.system.pomodoro.workTime = newSeconds;
                                else Config.system.pomodoro.restTime = newSeconds;
                            }
                        }
                    }
                    
                    Text {
                        text: ":"
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(8)
                        font.weight: Font.Bold
                        color: root.alarmActive ? Styling.srItem("overprimary") : Colors.overBackground
                        Layout.topMargin: -6
                    }
                    
                    TimerInput {
                        id: secIn
                        value: root.timeLeft % 60
                        onValueUpdated: val => {
                            let newSeconds = (Math.floor(root.timeLeft / 60) * 60) + val;
                            root.timeLeft = newSeconds;
                            if (!root.isRunning) {
                                root.totalTime = newSeconds;
                                if (root.isWorkSession) Config.system.pomodoro.workTime = newSeconds;
                                else Config.system.pomodoro.restTime = newSeconds;
                            }
                        }
                    }
                }
            }

            // Inverse Progress Bar
            StyledRect {
                variant: "common"
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                height: 4
                width: 180
                radius: 2
                opacity: root.isRunning || root.alarmActive || root.visualProgress < 1.0 ? 1.0 : 0.3
                
                Rectangle {
                    height: parent.height
                    width: root.visualProgress * parent.width
                    radius: parent.radius
                    color: Styling.srItem("overprimary")
                }
            }
        }

        // Quick Adjust & Start
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ControlBtn {
                text: "-1m"
                onClicked: {
                    if (root.timeLeft >= 60) {
                        root.timeLeft -= 60;
                        if (!root.isRunning) {
                            root.totalTime = root.timeLeft;
                            if (root.isWorkSession) Config.system.pomodoro.workTime = root.timeLeft;
                            else Config.system.pomodoro.restTime = root.timeLeft;
                        }
                    }
                }
            }

            StyledRect {
                id: playBtn
                variant: root.alarmActive ? "primary" : (root.isRunning ? "focus" : "common")
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                radius: Styling.radius(0)
                
                Text {
                    anchors.centerIn: parent
                    text: root.alarmActive ? "STOP ALARM" : (root.isRunning ? "PAUSE" : (root.isResuming ? "RESUME" : "START " + (root.isWorkSession ? "WORK" : "REST")))
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(0)
                    font.weight: Font.Black
                    font.letterSpacing: 1
                    color: playBtn.item
                }
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.toggleTimer()
                }
            }

            ControlBtn {
                text: "+1m"
                onClicked: {
                    root.timeLeft += 60;
                    if (!root.isRunning) {
                        root.totalTime = root.timeLeft;
                        if (root.isWorkSession) Config.system.pomodoro.workTime = root.timeLeft;
                        else Config.system.pomodoro.restTime = root.timeLeft;
                    }
                }
            }
        }

        // Settings Row
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 20

            // Auto Toggle
            RowLayout {
                spacing: 8
                Text {
                    text: "Auto"
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    color: Colors.outline
                }
                Item {
                    Layout.preferredWidth: 36; Layout.preferredHeight: 20
                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: Config.system.pomodoro.autoStart ? Styling.srItem("overprimary") : Colors.surfaceBright
                        opacity: Config.system.pomodoro.autoStart ? 1.0 : 0.4
                        Rectangle {
                            x: Config.system.pomodoro.autoStart ? parent.width - 18 : 2
                            y: 2; width: 16; height: 16; radius: 8
                            color: Colors.background
                            Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutQuart } }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: Config.system.pomodoro.autoStart = !Config.system.pomodoro.autoStart
                    }
                }
            }

            // Sync Spotify Toggle
            RowLayout {
                spacing: 8
                Text {
                    text: "Sync Spotify"
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    color: Colors.outline
                }
                Item {
                    Layout.preferredWidth: 36; Layout.preferredHeight: 20
                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: Config.system.pomodoro.syncSpotify ? Styling.srItem("overprimary") : Colors.surfaceBright
                        opacity: Config.system.pomodoro.syncSpotify ? 1.0 : 0.4
                        Rectangle {
                            x: Config.system.pomodoro.syncSpotify ? parent.width - 18 : 2
                            y: 2; width: 16; height: 16; radius: 8
                            color: Colors.background
                            Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutQuart } }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: Config.system.pomodoro.syncSpotify = !Config.system.pomodoro.syncSpotify
                    }
                }
            }
        }
    }

    // --- Sub-components ---
    component TimerInput: TextField {
        id: tIn
        property int value: 0
        signal valueUpdated(int newValue)
        
        text: value.toString().padStart(2, '0')
        onActiveFocusChanged: if (!activeFocus) text = value.toString().padStart(2, '0')
        
        font.family: Config.theme.monoFont
        font.pixelSize: Styling.fontSize(8)
        font.weight: Font.Bold
        color: root.alarmActive ? (Math.floor(Date.now() / 500) % 2 === 0 ? Styling.srItem("overprimary") : Colors.overBackground) : Colors.overBackground
        
        background: Item {}
        padding: 0; leftPadding: 0; rightPadding: 0
        horizontalAlignment: TextInput.AlignHCenter
        maximumLength: 2
        validator: IntValidator { bottom: 0; top: 99 }
        selectByMouse: true
        
        onTextEdited: {
            let v = parseInt(text);
            if (!isNaN(v)) {
                tIn.valueUpdated(v);
            }
        }
        
        onEditingFinished: {
            let v = parseInt(text) || 0;
            tIn.valueUpdated(v);
            text = v.toString().padStart(2, '0');
        }
        
        Layout.preferredWidth: 60
        
        Timer {
            interval: 500
            running: root.alarmActive
            repeat: true
            onTriggered: tIn.update()
        }
    }

    component ControlBtn: StyledRect {
        id: cBtn
        property string text: ""
        signal clicked()
        
        variant: "common"
        implicitWidth: 44; implicitHeight: 40
        radius: Styling.radius(-4)
        
        Text {
            anchors.centerIn: parent
            text: cBtn.text
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            color: mouseA.containsMouse ? Styling.srItem("overprimary") : Colors.overBackground
        }
        
        MouseArea {
            id: mouseA
            anchors.fill: parent
            hoverEnabled: true
            onClicked: cBtn.clicked()
        }
    }
}
