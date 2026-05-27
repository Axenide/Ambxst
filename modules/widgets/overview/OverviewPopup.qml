import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.modules.globals
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config
import "."

PanelWindow {
    id: overviewPopup

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "ambxst:overview"
    WlrLayershell.keyboardFocus: overviewOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Get this screen's visibility state
    readonly property var screenVisibilities: Visibilities.getForScreen(screen.name)
    readonly property bool overviewOpen: screenVisibilities ? screenVisibilities.overview : false

    visible: overviewOpen
    exclusionMode: ExclusionMode.Ignore

    // Mask to capture input on the entire window when open
    mask: Region {
        item: overviewOpen ? fullMask : emptyMask
    }

    // Full screen mask when open
    Item {
        id: fullMask
        anchors.fill: parent
    }

    // Empty mask when hidden
    Item {
        id: emptyMask
        width: 0
        height: 0
    }

    FocusGrab {
        id: focusGrab
        windows: [overviewPopup]
        active: overviewOpen

        onCleared: {
            // Use Qt.callLater to avoid potential race conditions
            Qt.callLater(() => {
                if (overviewOpen) {
                    Visibilities.setActiveModule("");
                }
            });
        }
    }

    // Semi-transparent backdrop — fully transparent (no scrim)
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: "transparent"
        opacity: 0

        MouseArea {
            anchors.fill: parent
            onClicked: {
                Visibilities.setActiveModule("");
            }
        }
    }

    // Fullscreen overview — covers entire screen, no search bar
    Item {
        id: mainContainer
        anchors.fill: parent
        anchors.margins: 16

        opacity: overviewOpen ? 1 : 0
        scale: overviewOpen ? 1 : 0.95

        Behavior on opacity {
            enabled: Anim.animationsEnabled
            NumberAnimation {
                duration: Anim.standardNormal
                easing.type: Anim.easing("standard").type
                easing.bezierCurve: Anim.easing("standard").bezierCurve
            }
        }

        Behavior on scale {
            enabled: Anim.animationsEnabled
            NumberAnimation {
                duration: Anim.emphasizedLarge
                easing.type: Anim.easing("emphasized").type
                easing.bezierCurve: Anim.easing("emphasized").bezierCurve
            }
        }

        // Overview grid — fills available space
        Item {
            id: overviewContainer
            anchors.fill: parent

            // Loader for Overview
            Loader {
                id: overviewLoader
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                active: overviewOpen
                asynchronous: true

                sourceComponent: Component {
                    OverviewView {
                        currentScreen: overviewPopup.screen
                    }
                }

                onLoaded: {
                    console.log("OverviewView loaded asynchronously");
                }

                onActiveChanged: {
                    if (!active && item) {
                        item.destroy();
                        console.log("OverviewView resources released");
                    }
                }
            }
        }
    }

    // Ensure focus when overview opens
    onOverviewOpenChanged: {
        if (overviewOpen) {
            Qt.callLater(() => {
                if (overviewLoader.item && overviewLoader.item.resetSearch) {
                    overviewLoader.item.resetSearch();
                }
            });
        }
    }
}
