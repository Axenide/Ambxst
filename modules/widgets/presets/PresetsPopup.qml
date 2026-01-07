import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.modules.globals
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config
import qs.modules.widgets.presets

PanelWindow {
    id: presetsPopup

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // Get this screen's visibility state
    readonly property var screenVisibilities: Visibilities.getForScreen(screen.name)
    readonly property bool presetsOpen: screenVisibilities ? screenVisibilities.presets : false

    visible: presetsOpen
    exclusionMode: ExclusionMode.Ignore

    // Mask to capture input on the entire window when open
    mask: Region {
        item: presetsOpen ? fullMask : emptyMask
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

    HyprlandFocusGrab {
        id: focusGrab
        windows: [presetsPopup]
        active: presetsOpen

        onCleared: {
            // Use Qt.callLater to avoid potential race conditions
            Qt.callLater(() => {
                if (presetsOpen) {
                    Visibilities.setActiveModule("");
                }
            });
        }
    }

    // Semi-transparent backdrop
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: Colors.scrim
        opacity: presetsOpen ? 0.5 : 0

        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutQuart
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                Visibilities.setActiveModule("");
            }
        }
    }

    // Main content column (search + presets)
    Item {
        id: mainContainer
        anchors.centerIn: parent
        width: presetsContainer.width + (scrollbarContainer.visible ? scrollbarContainer.width + 8 : 0)
        height: presetsContainer.height

        opacity: presetsOpen ? 1 : 0
        scale: presetsOpen ? 1 : 0.9

        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutQuart
            }
        }

        Behavior on scale {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutBack
                easing.overshoot: 1.2
            }
        }

        // Presets container
        Item {
            id: presetsContainer
            anchors.centerIn: parent
            width: presetsLoader.item ? presetsLoader.item.implicitWidth + 48 : 400
            height: presetsLoader.item ? presetsLoader.item.implicitHeight + 48 : 300

            // Background panel
            StyledRect {
                id: presetsBackground
                variant: "bg"
                anchors.fill: parent
                radius: Styling.radius(20)

                layer.enabled: true
                layer.effect: Shadow {}
            }

            // Loader for PresetsTab
            Loader {
                id: presetsLoader
                anchors.centerIn: parent
                active: presetsOpen

                sourceComponent: PresetsTab {}
            }
        }

        // External scrollbar (if needed)
        StyledRect {
            id: scrollbarContainer
            visible: presetsLoader.item && presetsLoader.item.needsScrollbar
            variant: "bg"
            anchors.left: presetsContainer.right
            anchors.leftMargin: 8
            anchors.verticalCenter: presetsContainer.verticalCenter
            width: 32
            height: Math.max(presetsContainer.height * 0.6, 200)
            radius: Styling.radius(0)

            layer.enabled: true
            layer.effect: Shadow {}

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: wheel => {
                    if (presetsLoader.item && presetsLoader.item.flickable) {
                        const flickable = presetsLoader.item.flickable;
                        const delta = wheel.angleDelta.y > 0 ? -150 : 150;
                        flickable.contentY = Math.max(0, Math.min(flickable.contentY + delta, flickable.contentHeight - flickable.height));
                    }
                }
            }

            ScrollBar {
                id: externalScrollBar
                anchors.centerIn: parent
                height: parent.height - 16
                width: 12
                orientation: Qt.Vertical
                policy: ScrollBar.AlwaysOn

                position: presetsLoader.item && presetsLoader.item.flickable ? presetsLoader.item.flickable.visibleArea.yPosition : 0
                size: presetsLoader.item && presetsLoader.item.flickable ? presetsLoader.item.flickable.visibleArea.heightRatio : 1

                // Notify flickable when manually scrolling
                onActiveChanged: {
                    if (presetsLoader.item) {
                        presetsLoader.item.isManualScrolling = active;
                    }
                }

                onPositionChanged: {
                    if (active && presetsLoader.item && presetsLoader.item.flickable) {
                        presetsLoader.item.flickable.contentY = position * presetsLoader.item.flickable.contentHeight;
                    }
                }

                contentItem: Rectangle {
                    implicitWidth: 12
                    radius: Styling.radius(-10)
                    color: externalScrollBar.pressed ? Styling.srItem("overprimary") : (externalScrollBar.hovered ? Qt.lighter(Styling.srItem("overprimary"), 1.2) : Styling.srItem("overprimary"))

                    Behavior on color {
                        enabled: Config.animDuration > 0
                        ColorAnimation {
                            duration: Config.animDuration / 2
                        }
                    }
                }

                background: Rectangle {
                    implicitWidth: 12
                    radius: Styling.radius(-10)
                    color: Colors.surfaceContainer
                    opacity: 0.3
                }
            }
        }
    }

    // Ensure focus when presets opens
    onPresetsOpenChanged: {
        if (presetsOpen) {
            Qt.callLater(() => {
                if (presetsLoader.item) {
                    presetsLoader.item.resetSearch();
                    presetsLoader.item.focusSearchInput();
                }
            });
        }
    }
}
