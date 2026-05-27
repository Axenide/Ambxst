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
        property string tooltip: ScreenRecorder.isRecording ? "Stop Recording" : "Screen Recorder"
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
            icon: Icons.google,
            tooltip: "Google Lens",
            command: ""
        },
        {
            icon: GlobalStates.mirrorWindowVisible ? Icons.webcamSlash : Icons.webcam,
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

    Process {
        id: openFolderProc
        // Usamos nohup para desvincular el proceso de visualización de carpetas
        command: ["bash", "-c", "nohup xdg-open \"$0\" > /dev/null 2>&1 &"]
    }

    onActionTriggered: action => {
        console.log("Tools action triggered:", action.tooltip);

        if (action.tooltip === "Screenshot") {
            Screenshot.initialize();
            GlobalStates.screenshotToolVisible = true;
            root.itemSelected();
        } else if (action.tooltip === "Screen Recorder") {
            ScreenRecorder.initialize();
            GlobalStates.screenRecordToolVisible = true;
            root.itemSelected();
        } else if (action.tooltip === "Stop Recording") {
            ScreenRecorder.toggleRecording();
            root.itemSelected();
        } else if (action.tooltip === "Open Screenshots") {
            // Usamos xdg-user-dir en el comando bash para respetar las rutas del sistema
            var cmd = "dir=\"$(xdg-user-dir PICTURES)/Screenshots\"; mkdir -p \"$dir\"; nohup xdg-open \"$dir\" > /dev/null 2>&1 &";
            
            openFolderProc.command = ["bash", "-c", cmd];
            openFolderProc.running = true;
            
            root.itemSelected();
        } else if (action.tooltip === "Open Recordings") {
            // Usamos xdg-user-dir para videos, manteniendo la subcarpeta Recordings
            var cmd = "dir=\"$(xdg-user-dir VIDEOS)/Recordings\"; mkdir -p \"$dir\"; nohup xdg-open \"$dir\" > /dev/null 2>&1 &";
            
            openFolderProc.command = ["bash", "-c", cmd];
            openFolderProc.running = true;
            
             root.itemSelected();
        } else if (action.tooltip === "Color Picker") {
            var scriptPath = Qt.resolvedUrl("../../../scripts/colorpicker.py").toString().replace("file://", "");
            // Run detached so it survives when the menu closes
            colorPickerProc.command = ["bash", "-c", "nohup python3 \"" + scriptPath + "\" > /dev/null 2>&1 &"];
            colorPickerProc.running = true;
            root.itemSelected();
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
            root.itemSelected();
        } else if (action.tooltip === "QR Code") {
            var scriptPath = Qt.resolvedUrl("../../../scripts/qr_scan.sh").toString().replace("file://", "");
            qrProc.command = ["bash", "-c", "nohup \"" + scriptPath + "\" > /dev/null 2>&1 &"];
            qrProc.running = true;
            root.itemSelected();
        } else if (action.tooltip === "Google Lens") {
            Screenshot.captureMode = "lens";
            GlobalStates.screenshotToolVisible = true;
            root.itemSelected();
        } else if (action.tooltip === "Mirror") {
            GlobalStates.mirrorWindowVisible = !GlobalStates.mirrorWindowVisible;
        }
    }
}
