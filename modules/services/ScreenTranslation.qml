pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/*!
    ScreenTranslation.qml — Screen translation service.

    Translates selected text or screenshots using translate-shell (CLI)
    with fallback to Google Translate API via curl.

    Usage:
        ScreenTranslation.translateText("Hello world", "es")
        ScreenTranslation.translateRegion(x, y, w, h, "en")

    Returns result via onTranslationComplete signal.
*/
Singleton {
    id: root

    signal translationComplete(string text, string fromLang, string toLang)
    signal translationError(string error)

    /*! Translate text using translate-shell. Falls back to Google API. */
    function translateText(text, toLang, fromLang) {
        if (!text || text.trim() === "") return;

        if (root._hasTranslateShell) {
            var args = ["translate", "-t", toLang];
            if (fromLang) {
                args.push("-f", fromLang);
            }
            args.push(text);
            translateShellProcess.command = args;
            translateShellProcess.running = true;
        } else {
            // Fallback: Google Translate API via curl
            googleTranslateProcess.command = [
                "curl", "-s",
                "https://translate.googleapis.com/translate_a/single?client=gtx&sl=" +
                (fromLang || "auto") + "&tl=" + toLang + "&dt=t&q=" +
                encodeURIComponent(text)
            ];
            googleTranslateProcess.running = true;
        }
    }

    /*! OCR and translate a screen region (requires tesseract). */
    function translateRegion(x, y, w, h, toLang) {
        ocrAndTranslateProcess.command = [
            "sh", "-c",
            "grim -g '" + x + "," + y + " " + w + "x" + h + "' - | tesseract stdin stdout 2>/dev/null | head -100"
        ];
        ocrAndTranslateProcess.running = true;
        _pendingTargetLang = toLang;
    }

    property string _pendingTargetLang: "en"

    property bool _hasTranslateShell: false

    function hasTranslateShell() {
        return root._hasTranslateShell;
    }

    // Check for translate-shell availability
    property Process _checkProcess: Process {
        command: ["sh", "-c", "command -v trans || command -v translate"]
        running: true
        onExited: (code) => {
            root._hasTranslateShell = code === 0;
        }
    }

    // translate-shell process
    property Process translateShellProcess: Process {
        running: false
        stdout: SplitParser {
            onRead: (data) => {
                if (data) {
                    root.translationComplete(data.trim(), "auto", "");
                }
            }
        }
    }

    // Google Translate API fallback
    property Process googleTranslateProcess: Process {
        running: false
        stdout: SplitParser {
            onRead: (data) => {
                try {
                    const result = JSON.parse(data);
                    if (result && result[0]) {
                        const translated = result[0].map(s => s[0]).filter(s => s).join("");
                        root.translationComplete(translated, result[2] || "auto", "");
                    }
                } catch (e) {
                    root.translationError("Failed to parse translation response");
                }
            }
        }
    }

    // OCR + translate
    property Process ocrAndTranslateProcess: Process {
        running: false
        stdout: SplitParser {
            onRead: (data) => {
                if (data) {
                    const text = data.trim();
                    if (text) {
                        root.translateText(text, root._pendingTargetLang);
                    } else {
                        root.translationError("No text found in region");
                    }
                }
            }
        }
    }
}
