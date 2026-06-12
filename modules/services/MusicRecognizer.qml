pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/*!
    MusicRecognizer.qml — Music recognition via SongRec (Shazam CLI).

    Records audio from the default microphone and identifies the song
    using Shazam's fingerprinting algorithm (via songrec).

    Usage:
        MusicRecognizer.identify()
        // Result via onIdentificationComplete signal

    Requires: songrec (https://github.com/marin-m/SongRec)
*/
Singleton {
    id: root

    signal identificationComplete(string title, string artist, string album, string coverUrl)
    signal identificationError(string error)
    signal listeningStarted()
    signal listeningStopped()

    property bool isListening: false
    property bool isAvailable: false

    property Process _checkProcess: Process {
        command: ["sh", "-c", "command -v songrec"]
        running: true
        onExited: (code) => {
            root.isAvailable = code === 0;
            if (!root.isAvailable) {
                console.warn("MusicRecognizer: songrec not found. Install with: yay -S songrec");
            }
        }
    }

    function identify() {
        if (!root.isAvailable) {
            root.identificationError("songrec not installed");
            return;
        }

        root.isListening = true;
        root.listeningStarted();

        // songrec listens for ~5 seconds, then identifies
        identifyProcess.running = true;
    }

    property Process identifyProcess: Process {
        running: false
        command: ["songrec", "listen"] // Records + identifies in one step

        stdout: SplitParser {
            onRead: (data) => {
                if (!data) return;
                try {
                    // songrec outputs JSON with song info
                    const result = JSON.parse(data);
                    if (result && result.track) {
                        root.identificationComplete(
                            result.track.title || "Unknown",
                            result.track.artist || "Unknown",
                            result.track.album || "",
                            result.track.cover || ""
                        );
                    } else if (result && result.error) {
                        root.identificationError(result.error);
                    }
                } catch (e) {
                    // Try to parse plain text output
                    const lines = data.trim().split("\n");
                    if (lines.length >= 2) {
                        root.identificationComplete(lines[0], lines[1], "", "");
                    } else {
                        root.identificationError("Could not identify song");
                    }
                }
            }
        }

        onExited: {
            root.isListening = false;
            root.listeningStopped();
        }
    }

    function cancel() {
        if (root.isListening) {
            identifyProcess.running = false;
            root.isListening = false;
            root.listeningStopped();
        }
    }
}
