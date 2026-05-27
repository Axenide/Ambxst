import QtQuick
import QtMultimedia
import Quickshell

SoundEffect {
    id: alarmSound
    source: Quickshell.shellDir + "/assets/sound/polite-warning-tone.wav"
    
    signal stopAlarmRequested()
    
    property bool alarmActive: false
    property bool autoStart: false
    
    onPlayingChanged: {
        if (!playing && alarmActive && autoStart) {
            stopAlarmRequested();
        }
    }
}
