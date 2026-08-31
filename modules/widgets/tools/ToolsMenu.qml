import QtQuick
import qs.modules.components
import qs.modules.theme
import qs.modules.globals
import Quickshell.Io

import qs.modules.services

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
            Screenshot.initialize();
            var shotsDir = Screenshot.screenshotsDir !== "" ? Screenshot.screenshotsDir : Quickshell.env("HOME") + "/Pictures/Screenshots";
            openFolderProc.command = ["bash", "-c", "nohup xdg-open \"$0\" > /dev/null 2>&1 &", shotsDir];
            openFolderProc.running = true;

            root.itemSelected();
        } else if (action.tooltip === "Open Recordings") {
            ScreenRecorder.initialize();
            var recsDir = ScreenRecorder.videosDir !== "" ? ScreenRecorder.videosDir : Quickshell.env("HOME") + "/Videos/Recordings";
            openFolderProc.command = ["bash", "-c", "nohup xdg-open \"$0\" > /dev/null 2>&1 &", recsDir];
            openFolderProc.running = true;

             root.itemSelected();
        } else if (action.tooltip === "Color Picker") {
            // Run detached so it survives when the menu closes
            colorPickerProc.command = ["bash", "-c", "nohup ambxst colorpicker > /dev/null 2>&1 &"];
            colorPickerProc.running = true;
            root.itemSelected();
        } else if (action.tooltip === "OCR") {
            Screenshot.initialize();
            Screenshot.captureMode = "ocr";
            GlobalStates.screenshotToolVisible = true;
            root.itemSelected();
        } else if (action.tooltip === "QR Code") {
            Screenshot.initialize();
            Screenshot.captureMode = "qr";
            GlobalStates.screenshotToolVisible = true;
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
