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
        property string tooltip: ScreenRecorder.isRecording ? I18n.t("tools.screenrecord_stop") : I18n.t("tools.screenrecord_start")
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
            tooltip: I18n.t("tools.screenshot"),
            command: ""
        },
        {
            icon: Icons.screenshots,
            tooltip: I18n.t("tools.screenshot_directory"),
            command: ""
        },
        {
            type: "separator"
        },
        recordAction,
        {
            icon: Icons.recordings,
            tooltip: I18n.t("tools.screenrecord_directory"),
            command: ""
        },
        {
            type: "separator"
        },
        {
            icon: Icons.picker,
            tooltip: I18n.t("tools.color_picker"),
            command: ""
        },
        {
            icon: Icons.textT,
            tooltip: I18n.t("tools.ocr"),
            command: ""
        },
        {
            icon: Icons.qrCode,
            tooltip: I18n.t("tools.qr"),
            command: ""
        },
        {
            icon: Icons.google,
            tooltip: I18n.t("tools.google_lens"),
            command: ""
        },
        {
            icon: GlobalStates.mirrorWindowVisible ? Icons.webcamSlash : Icons.webcam,
            tooltip: I18n.t("tools.mirror"),
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

        if (action.tooltip === I18n.t("tools.screenshot")) {
            Screenshot.initialize();
            GlobalStates.screenshotToolVisible = true;
            root.itemSelected();
        } else if (action.tooltip === I18n.t("tools.screenrecord_start")) {
            ScreenRecorder.initialize();
            GlobalStates.screenRecordToolVisible = true;
            root.itemSelected();
        } else if (action.tooltip === I18n.t("tools.screenrecord_stop")) {
            ScreenRecorder.toggleRecording();
            root.itemSelected();
        } else if (action.tooltip === I18n.t("tools.screenshot_directory")) {
            Screenshot.initialize();
            var shotsDir = Screenshot.screenshotsDir !== "" ? Screenshot.screenshotsDir : Quickshell.env("HOME") + "/Pictures/Screenshots";
            openFolderProc.command = ["bash", "-c", "nohup xdg-open \"$0\" > /dev/null 2>&1 &", shotsDir];
            openFolderProc.running = true;

            root.itemSelected();
        } else if (action.tooltip === I18n.t("tools.screenrecord_directory")) {
            ScreenRecorder.initialize();
            var recsDir = ScreenRecorder.videosDir !== "" ? ScreenRecorder.videosDir : Quickshell.env("HOME") + "/Videos/Recordings";
            openFolderProc.command = ["bash", "-c", "nohup xdg-open \"$0\" > /dev/null 2>&1 &", recsDir];
            openFolderProc.running = true;

             root.itemSelected();
        } else if (action.tooltip === I18n.t("tools.color_picker")) {
            // Run detached so it survives when the menu closes
            colorPickerProc.command = ["bash", "-c", "nohup ambxst colorpicker > /dev/null 2>&1 &"];
            colorPickerProc.running = true;
            root.itemSelected();
        } else if (action.tooltip === I18n.t("tools.ocr")) {
            Screenshot.initialize();
            Screenshot.captureMode = "ocr";
            GlobalStates.screenshotToolVisible = true;
            root.itemSelected();
        } else if (action.tooltip === I18n.t("tools.qr")) {
            Screenshot.initialize();
            Screenshot.captureMode = "qr";
            GlobalStates.screenshotToolVisible = true;
            root.itemSelected();
        } else if (action.tooltip === I18n.t("tools.google_lens")) {
            Screenshot.captureMode = "lens";
            GlobalStates.screenshotToolVisible = true;
            root.itemSelected();
        } else if (action.tooltip === I18n.t("tools.mirror")) {
            GlobalStates.mirrorWindowVisible = !GlobalStates.mirrorWindowVisible;
        }
    }
}
