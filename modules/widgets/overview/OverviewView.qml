import QtQuick
import qs.modules.widgets.overview
import qs.modules.services
import qs.modules.globals
import qs.config

Item {
    id: root
    property var currentScreen

    // Detect if we're in scrolling layout mode
    readonly property bool isScrollingLayout: GlobalStates.hyprlandLayout === "scrolling"

    implicitWidth: overviewLoader.item ? overviewLoader.item.implicitWidth : 400
    implicitHeight: overviewLoader.item ? overviewLoader.item.implicitHeight : 300

    // Expose flickable and scrollbar needs for scrolling mode
    readonly property var flickable: isScrollingLayout && overviewLoader.item ? overviewLoader.item.flickable : null
    readonly property bool needsScrollbar: isScrollingLayout && overviewLoader.item ? overviewLoader.item.needsScrollbar : false

    // Manual scrolling state - passed through to ScrollingOverview
    property bool isManualScrolling: false
    onIsManualScrollingChanged: {
        if (isScrollingLayout && overviewLoader.item) {
            overviewLoader.item.isManualScrolling = isManualScrolling;
        }
    }

    Behavior on implicitWidth {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutQuart
        }
    }

    Behavior on implicitHeight {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutQuart
        }
    }

    // Dynamic loader for the appropriate overview component
    Loader {
        id: overviewLoader
        anchors.centerIn: parent
        active: true
        
        sourceComponent: isScrollingLayout ? scrollingOverviewComponent : standardOverviewComponent
    }

    // Standard grid overview
    Component {
        id: standardOverviewComponent
        Overview {
            currentScreen: root.currentScreen

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    Visibilities.setActiveModule("");
                    event.accepted = true;
                }
            }

            Component.onCompleted: {
                forceActiveFocus();
            }
        }
    }

    // Scrolling tape overview
    Component {
        id: scrollingOverviewComponent
        ScrollingOverview {
            currentScreen: root.currentScreen

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    Visibilities.setActiveModule("");
                    event.accepted = true;
                }
            }

            Component.onCompleted: {
                forceActiveFocus();
            }
        }
    }

    // Expose search-related properties for parent components (read from child)
    readonly property var matchingWindows: overviewLoader.item ? overviewLoader.item.matchingWindows : []
    readonly property int selectedMatchIndex: overviewLoader.item ? overviewLoader.item.selectedMatchIndex : 0

    // Search query - writable, synced to child
    property string searchQuery: ""
    onSearchQueryChanged: {
        if (overviewLoader.item) {
            overviewLoader.item.searchQuery = searchQuery;
        }
    }

    function resetSearch() {
        searchQuery = "";
        if (overviewLoader.item && overviewLoader.item.resetSearch) {
            overviewLoader.item.resetSearch();
        }
    }

    function navigateToSelectedWindow() {
        if (overviewLoader.item && overviewLoader.item.navigateToSelectedWindow) {
            overviewLoader.item.navigateToSelectedWindow();
        }
    }

    function selectNextMatch() {
        if (overviewLoader.item && overviewLoader.item.selectNextMatch) {
            overviewLoader.item.selectNextMatch();
        }
    }

    function selectPrevMatch() {
        if (overviewLoader.item && overviewLoader.item.selectPrevMatch) {
            overviewLoader.item.selectPrevMatch();
        }
    }
}
