import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: wallpaper

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "quickshell:wallpaper"

    color: "transparent"

    Image {
        id: wallpaperImage
        anchors.fill: parent
        source: "file://" + Quickshell.env("HOME") + "/.current.wall"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false

        onStatusChanged: {
            if (status === Image.Error) {
                console.warn("Wallpaper: Failed to load image from ~/.current.wall")
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        visible: wallpaperImage.status !== Image.Ready
        z: -1
    }
}