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
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

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

    HyprlandFocusGrab {
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

    // Semi-transparent backdrop
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: Colors.scrim
        opacity: overviewOpen ? 0.5 : 0

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

    // Main content column (search + overview)
    Item {
        id: mainContainer
        anchors.centerIn: parent
        width: Math.max(searchContainer.width, overviewContainer.width + (scrollbarContainer.visible ? scrollbarContainer.width + 8 : 0))
        height: searchContainer.height + 8 + overviewContainer.height

        opacity: overviewOpen ? 1 : 0
        scale: overviewOpen ? 1 : 0.9

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

        // Search input container
        StyledRect {
            id: searchContainer
            variant: "bg"
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(400, overviewContainer.width)
            height: 80
            radius: Styling.radius(24)

            layer.enabled: true
            layer.effect: Shadow {}

            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 8

                // Icon container
                Rectangle {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    Layout.alignment: Qt.AlignVCenter
                    color: "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: Icons.overview
                        font.family: Icons.font
                        font.pixelSize: 24
                        color: Styling.srItem("overprimary")
                    }
                }

                // Search input
                SearchInput {
                    id: searchInput
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    Layout.alignment: Qt.AlignVCenter

                    variant: "common"
                    placeholderText: qsTr("Search windows...")
                    handleTabNavigation: true
                    clearOnEscape: false

                    // Match counter suffix
                    Text {
                        id: matchCounter
                        visible: overviewLoader.item && overviewLoader.item.searchQuery.length > 0
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            if (!overviewLoader.item)
                                return "0";
                            const matches = overviewLoader.item.matchingWindows.length;
                            if (matches > 0) {
                                return `${overviewLoader.item.selectedMatchIndex + 1}/${matches}`;
                            }
                            return "0";
                        }
                        font.family: Config.theme.font
                        font.pixelSize: Config.theme.fontSize - 2
                        color: (overviewLoader.item && overviewLoader.item.matchingWindows.length > 0) ? Styling.srItem("overprimary") : Colors.error
                        opacity: 0.8
                    }

                    onSearchTextChanged: text => {
                        if (overviewLoader.item) {
                            overviewLoader.item.searchQuery = text;
                        }
                    }

                    onAccepted: {
                        if (overviewLoader.item) {
                            overviewLoader.item.navigateToSelectedWindow();
                        }
                    }

                    onTabPressed: {
                        if (overviewLoader.item) {
                            overviewLoader.item.selectNextMatch();
                        }
                    }

                    onShiftTabPressed: {
                        if (overviewLoader.item) {
                            overviewLoader.item.selectPrevMatch();
                        }
                    }

                    onDownPressed: {
                        if (overviewLoader.item) {
                            overviewLoader.item.selectNextMatch();
                        }
                    }

                    onUpPressed: {
                        if (overviewLoader.item) {
                            overviewLoader.item.selectPrevMatch();
                        }
                    }

                    onEscapePressed: {
                        if (searchInput.text.length > 0) {
                            searchInput.clear();
                            if (overviewLoader.item) {
                                overviewLoader.item.searchQuery = "";
                            }
                        } else {
                            Visibilities.setActiveModule("");
                        }
                    }

                    onLeftPressed: {
                        if (searchInput.text.length === 0) {
                            Hyprland.dispatch("workspace r-1");
                        } else if (overviewLoader.item) {
                            overviewLoader.item.selectPrevMatch();
                        }
                    }

                    onRightPressed: {
                        if (searchInput.text.length === 0) {
                            Hyprland.dispatch("workspace r+1");
                        } else if (overviewLoader.item) {
                            overviewLoader.item.selectNextMatch();
                        }
                    }
                }
            }
        }

        // Overview container
        Item {
            id: overviewContainer
            anchors.top: searchContainer.bottom
            anchors.topMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            width: overviewLoader.item ? overviewLoader.item.implicitWidth + 48 : 400
            height: overviewLoader.item ? overviewLoader.item.implicitHeight + 48 : 300

            // Background panel
            StyledRect {
                id: overviewBackground
                variant: "bg"
                anchors.fill: parent
                radius: Styling.radius(20)

                layer.enabled: true
                layer.effect: Shadow {}
            }

            // Loader for Overview to prevent issues during destruction
            Loader {
                id: overviewLoader
                anchors.centerIn: parent
                active: overviewOpen

                sourceComponent: OverviewView {
                    currentScreen: overviewPopup.screen
                }
            }
        }

        // External scrollbar for scrolling mode (to the right of overview)
        StyledRect {
            id: scrollbarContainer
            visible: overviewLoader.item && overviewLoader.item.needsScrollbar
            variant: "bg"
            anchors.left: overviewContainer.right
            anchors.leftMargin: 8
            anchors.verticalCenter: overviewContainer.verticalCenter
            width: 32
            height: Math.max(overviewContainer.height * 0.6, 200)
            radius: Styling.radius(0)

            layer.enabled: true
            layer.effect: Shadow {}

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: wheel => {
                    if (overviewLoader.item && overviewLoader.item.flickable) {
                        const flickable = overviewLoader.item.flickable;
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

                position: overviewLoader.item && overviewLoader.item.flickable ? overviewLoader.item.flickable.visibleArea.yPosition : 0
                size: overviewLoader.item && overviewLoader.item.flickable ? overviewLoader.item.flickable.visibleArea.heightRatio : 1

                // Notify flickable when manually scrolling to disable animation
                onActiveChanged: {
                    if (overviewLoader.item) {
                        overviewLoader.item.isManualScrolling = active;
                    }
                }

                onPositionChanged: {
                    if (active && overviewLoader.item && overviewLoader.item.flickable) {
                        overviewLoader.item.flickable.contentY = position * overviewLoader.item.flickable.contentHeight;
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

    // Ensure focus when overview opens
    onOverviewOpenChanged: {
        if (overviewOpen) {
            Qt.callLater(() => {
                searchInput.clear();
                if (overviewLoader.item) {
                    overviewLoader.item.resetSearch();
                }
                searchInput.focusInput();
            });
        }
    }
}
