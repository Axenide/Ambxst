import QtQuick
import Quickshell
import Quickshell.Wayland
import "."
import "../globals"

PanelWindow {
    id: screenCorners

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "quickshell:screenCorners"
    mask: Region {
        item: null
    }

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    RoundCorner {
        id: topLeft
        size: GlobalStates.roundness > 0 ? GlobalStates.roundness + 4 : 0
        anchors.left: parent.left
        anchors.top: parent.top
        corner: RoundCorner.CornerEnum.TopLeft
    }

    RoundCorner {
        id: topRight
        size: GlobalStates.roundness > 0 ? GlobalStates.roundness + 4 : 0
        anchors.right: parent.right
        anchors.top: parent.top
        corner: RoundCorner.CornerEnum.TopRight
    }

    RoundCorner {
        id: bottomLeft
        size: GlobalStates.roundness > 0 ? GlobalStates.roundness + 4 : 0
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        corner: RoundCorner.CornerEnum.BottomLeft
    }

    RoundCorner {
        id: bottomRight
        size: GlobalStates.roundness > 0 ? GlobalStates.roundness + 4 : 0
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        corner: RoundCorner.CornerEnum.BottomRight
    }
}
