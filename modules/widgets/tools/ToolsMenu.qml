import QtQuick
import qs.modules.components
import qs.modules.theme
import qs.modules.globals
import Quickshell.Io

import qs.modules.services
import qs.config

ActionGrid {
    id: root

    signal itemSelected

    QtObject {
        id: recordAction
        property string icon: ScreenRecorder.isRecording ? Icons.stop : Icons.recordScreen
        property string text: ScreenRecorder.isRecording ? ScreenRecorder.duration : ""
        property string tooltip: "Record Screen"
        property string command: ""
        property string variant: ScreenRecorder.isRecording ? "error" : "primary"
        property string type: "button"
    }

    layout: "row"
    buttonSize: 48
    iconSize: 20
    spacing: 8

    actions: [
        {
            icon: Icons.camera,
            tooltip: "Screenshot",
            command: ""
        },
        {
            icon: Icons.screenshots,
            tooltip: "Open Screenshots",
            command: ""
        },
        {
            type: "separator"
        },
        recordAction,
        {
            icon: Icons.recordings,
            tooltip: "Open Recordings",
            command: ""
        },
        {
            type: "separator"
        },
        {
            icon: Icons.picker,
            tooltip: "Color Picker",
            command: ""
        },
        {
            icon: Icons.textT,
            tooltip: "OCR",
            command: ""
        },
        {
            icon: Icons.qrCode,
            tooltip: "QR Code",
            command: ""
        },
        {
            icon: Icons.webcam,
            tooltip: "Mirror",
            command: ""
        }
    ]

    Process {
        id: colorPickerProc
    }

    Process {
        id: ocrProc
    }

    Process {
        id: qrProc
    }

    onActionTriggered: action => {
        console.log("Tools action triggered:", action.tooltip);

        if (action.tooltip === "Screenshot") {
            GlobalStates.screenshotToolVisible = true;
        } else if (action.tooltip === "Record Screen") {
            if (ScreenRecorder.isRecording) {
                ScreenRecorder.toggleRecording(); // Stops it
            } else {
                GlobalStates.screenRecordToolVisible = true;
            }
        } else if (action.tooltip === "Color Picker") {
            var scriptPath = Qt.resolvedUrl("../../../scripts/colorpicker.py").toString().replace("file://", "");
            // Run detached so it survives when the menu closes
            colorPickerProc.command = ["bash", "-c", "nohup python3 \"" + scriptPath + "\" > /dev/null 2>&1 &"];
            colorPickerProc.running = true;
        } else if (action.tooltip === "OCR") {
            var scriptPath = Qt.resolvedUrl("../../../scripts/ocr.sh").toString().replace("file://", "");
            
            // Build languages string from Config
            var ocrConfig = Config.system.ocr;
            var langs = [];
            
            if (ocrConfig) {
                if (ocrConfig.eng !== false) langs.push("eng"); // Default true
                if (ocrConfig.spa !== false) langs.push("spa"); // Default true
                if (ocrConfig.lat === true) langs.push("lat");
                if (ocrConfig.jpn === true) langs.push("jpn");
                if (ocrConfig.chi_sim === true) langs.push("chi_sim");
                if (ocrConfig.chi_tra === true) langs.push("chi_tra");
                if (ocrConfig.kor === true) langs.push("kor");
            } else {
                langs = ["eng", "spa"];
            }
            
            if (langs.length === 0) langs.push("eng");
            var langString = langs.join("+");

            ocrProc.command = ["bash", "-c", "nohup \"" + scriptPath + "\" \"" + langString + "\" > /dev/null 2>&1 &"];
            ocrProc.running = true;
        } else if (action.tooltip === "QR Code") {
            var scriptPath = Qt.resolvedUrl("../../../scripts/qr_scan.sh").toString().replace("file://", "");
            qrProc.command = ["bash", "-c", "nohup \"" + scriptPath + "\" > /dev/null 2>&1 &"];
            qrProc.running = true;
        } else if (action.tooltip === "Mirror") {
            GlobalStates.mirrorWindowVisible = !GlobalStates.mirrorWindowVisible;
        }

        root.itemSelected();
    }
}
