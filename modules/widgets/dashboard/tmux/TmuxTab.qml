import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.components
import qs.modules.globals
import qs.modules.services
import qs.config

Item {
    id: root
    focus: true

    property string prefixIcon: ""
    signal backspaceOnEmpty

    property int leftPanelWidth: 0

    property string searchText: ""
    property bool showResults: searchText.length > 0
    property int selectedIndex: -1
    property var tmuxSessions: []
    property var filteredSessions: []

    // List model
    ListModel {
        id: sessionsModel
    }

    // Delete mode state
    property bool deleteMode: false
    property string sessionToDelete: ""
    property int originalSelectedIndex: -1
    property int deleteButtonIndex: 0 // 0 = cancel, 1 = confirm

    // Rename mode state
    property bool renameMode: false
    property string sessionToRename: ""
    property string newSessionName: ""
    property int renameSelectedIndex: -1
    property int renameButtonIndex: 0 // 0 = cancel, 1 = confirm
    property string pendingRenamedSession: "" // Track session to select after rename

    // Options menu state (expandable list)
    property int expandedItemIndex: -1
    property int selectedOptionIndex: 0
    property bool keyboardNavigation: false
    property bool isFiltering: false

    // Session preview state
    property var sessionWindows: []
    property var sessionPanes: []
    property bool loadingSessionInfo: false

    onExpandedItemIndexChanged:
    // Close expanded options when selection changes to a different item is handled in onSelectedIndexChanged
    {}

    // Refresh tmux sessions when tab becomes visible
    onVisibleChanged: {
        if (visible) {
            refreshTmuxSessions();
        }
    }

    function adjustScrollForExpandedItem(index) {
        if (index < 0 || index >= sessionsModel.count)
            return;

        // Calculate Y position of the item
        var itemY = 0;
        for (var i = 0; i < index; i++) {
            itemY += 48; // All items before are collapsed (base height)
        }

        // Calculate expanded item height - always 3 options (Open, Rename, Quit)
        var listHeight = 36 * 3;
        var expandedHeight = 48 + 4 + listHeight + 8;

        // Calculate max valid scroll position
        var maxContentY = Math.max(0, resultsList.contentHeight - resultsList.height);

        // Current viewport bounds
        var viewportTop = resultsList.contentY;
        var viewportBottom = viewportTop + resultsList.height;

        // Only scroll if item is not fully visible
        var itemBottom = itemY + expandedHeight;

        if (itemY < viewportTop) {
            // Item top is above viewport - scroll up to show it
            resultsList.contentY = itemY;
        } else if (itemBottom > viewportBottom) {
            // Item bottom is below viewport - scroll down to show it
            resultsList.contentY = Math.min(itemBottom - resultsList.height, maxContentY);
        }
    // Otherwise, item is already fully visible - no scroll needed
    }

    onSelectedIndexChanged: {
        if (selectedIndex === -1 && resultsList.count > 0) {
            resultsList.positionViewAtIndex(0, ListView.Beginning);
        }

        // Close expanded options when selection changes to a different item
        if (expandedItemIndex >= 0 && selectedIndex !== expandedItemIndex) {
            expandedItemIndex = -1;
            selectedOptionIndex = 0;
            keyboardNavigation = false;
        }

        // Load session info when selection changes
        if (selectedIndex >= 0 && selectedIndex < filteredSessions.length) {
            let session = filteredSessions[selectedIndex];
            if (session && !session.isCreateButton && !session.isCreateSpecificButton) {
                loadSessionInfo(session.name);
            } else {
                sessionWindows = [];
                sessionPanes = [];
            }
        } else {
            sessionWindows = [];
            sessionPanes = [];
        }
    }

    onSearchTextChanged: {
        updateFilteredSessions();
    }

    function clearSearch() {
        searchText = "";
        selectedIndex = -1;
        searchInput.focusInput();
        updateFilteredSessions();
    }

    function focusSearchInput() {
        searchInput.focusInput();
    }

    function cancelDeleteModeFromExternal() {
        if (deleteMode) {
            console.log("DEBUG: Canceling delete mode from external source (tab change)");
            cancelDeleteMode();
        }
        if (renameMode) {
            console.log("DEBUG: Canceling rename mode from external source (tab change)");
            cancelRenameMode();
        }
    }

    function updateFilteredSessions() {
        var newFilteredSessions = [];

        var createButtonText = "Create new session";
        var isCreateSpecific = false;
        var sessionNameToCreate = "";

        if (searchText.length === 0) {
            newFilteredSessions = tmuxSessions.slice(); // Copia del array
        } else {
            newFilteredSessions = tmuxSessions.filter(function (session) {
                return session.name.toLowerCase().includes(searchText.toLowerCase());
            });

            let exactMatch = tmuxSessions.find(function (session) {
                return session.name.toLowerCase() === searchText.toLowerCase();
            });

            if (!exactMatch && searchText.length > 0) {
                createButtonText = `Create session "${searchText}"`;
                isCreateSpecific = true;
                sessionNameToCreate = searchText;
            }
        }

        if (!deleteMode && !renameMode) {
            newFilteredSessions.unshift({
                name: createButtonText,
                isCreateButton: !isCreateSpecific,
                isCreateSpecificButton: isCreateSpecific,
                sessionNameToCreate: sessionNameToCreate,
                icon: "terminal"
            });
        }

        filteredSessions = newFilteredSessions;
        resultsList.enableScrollAnimation = false;
        resultsList.contentY = 0;

        sessionsModel.clear();
        for (var i = 0; i < newFilteredSessions.length; i++) {
            var session = newFilteredSessions[i];
            var sessionId = (session.isCreateButton || session.isCreateSpecificButton) ? "__create__" : session.name;

            sessionsModel.append({
                sessionId: sessionId,
                sessionData: session
            });
        }

        Qt.callLater(() => {
            resultsList.enableScrollAnimation = true;
        });

        if (!deleteMode && !renameMode) {
            if (searchText.length > 0 && newFilteredSessions.length > 0) {
                selectedIndex = 0;
                resultsList.currentIndex = 0;
            } else if (searchText.length === 0) {
                selectedIndex = -1;
                resultsList.currentIndex = -1;
            }
        }

        if (pendingRenamedSession !== "") {
            for (let i = 0; i < newFilteredSessions.length; i++) {
                if (newFilteredSessions[i].name === pendingRenamedSession) {
                    selectedIndex = i;
                    resultsList.currentIndex = i;
                    pendingRenamedSession = "";
                    break;
                }
            }
            if (pendingRenamedSession !== "") {
                pendingRenamedSession = "";
            }
        }
    }

    function enterDeleteMode(sessionName) {
        originalSelectedIndex = selectedIndex;
        deleteMode = true;
        sessionToDelete = sessionName;
        deleteButtonIndex = 0;
        root.forceActiveFocus();
    }

    function cancelDeleteMode() {
        deleteMode = false;
        sessionToDelete = "";
        deleteButtonIndex = 0;
        searchInput.focusInput();
        updateFilteredSessions();
        selectedIndex = originalSelectedIndex;
        resultsList.currentIndex = originalSelectedIndex;
        originalSelectedIndex = -1;
    }

    function confirmDeleteSession() {
        killProcess.command = ["tmux", "kill-session", "-t", sessionToDelete];
        killProcess.running = true;
        cancelDeleteMode();
    }

    function enterRenameMode(sessionName) {
        renameSelectedIndex = selectedIndex;
        renameMode = true;
        sessionToRename = sessionName;
        newSessionName = sessionName;
        renameButtonIndex = 1;
        root.forceActiveFocus();
        Qt.callLater(() => {});
    }

    function cancelRenameMode() {
        renameMode = false;
        sessionToRename = "";
        newSessionName = "";
        renameButtonIndex = 1;
        if (pendingRenamedSession === "") {
            searchInput.focusInput();
            updateFilteredSessions();
            selectedIndex = renameSelectedIndex;
            resultsList.currentIndex = renameSelectedIndex;
        } else {
            searchInput.focusInput();
        }
        renameSelectedIndex = -1;
    }

    function confirmRenameSession() {
        if (newSessionName.trim() !== "" && newSessionName !== sessionToRename) {
            renameProcess.command = ["tmux", "rename-session", "-t", sessionToRename, newSessionName.trim()];
            renameProcess.running = true;
        } else {
            cancelRenameMode();
        }
    }

    function refreshTmuxSessions() {
        tmuxProcess.running = true;
    }

    function loadSessionInfo(sessionName) {
        if (!sessionName)
            return;
        loadingSessionInfo = true;
        sessionWindows = [];
        sessionPanes = [];

        // Get windows for this session
        windowsProcess.command = ["tmux", "list-windows", "-t", sessionName, "-F", "#{window_index}:#{window_name}:#{window_active}"];
        windowsProcess.running = true;

        // Get panes layout and info: pane_index, width, height, top, left, active, command
        panesProcess.command = ["tmux", "list-panes", "-t", sessionName, "-F", "#{pane_index}:#{pane_width}:#{pane_height}:#{pane_top}:#{pane_left}:#{pane_active}:#{pane_current_command}"];
        panesProcess.running = true;
    }

    function stripAnsiCodes(text) {
        // Remove ANSI escape sequences (CSI sequences)
        return text.replace(/\x1b\[[0-9;]*[a-zA-Z]/g, '').replace(/\x1b\][0-9;]*;[^\x07]*\x07/g, '').replace(/\x1b[=>]/g, '');
    }

    function createTmuxSession(sessionName) {
        if (sessionName) {
            createProcess.command = ["bash", "-c", `cd "$HOME" && setsid kitty -e tmux new -s "${sessionName}" < /dev/null > /dev/null 2>&1 &`];
        } else {
            createProcess.command = ["bash", "-c", `cd "$HOME" && setsid kitty -e tmux < /dev/null > /dev/null 2>&1 &`];
        }
        createProcess.running = true;
        // Cerrar el dashboard
        Visibilities.setActiveModule("");
    }

    function attachToSession(sessionName) {
        attachProcess.command = ["bash", "-c", `cd "$HOME" && setsid kitty -e tmux attach-session -t "${sessionName}" < /dev/null > /dev/null 2>&1 &`];
        attachProcess.running = true;
    }

    function switchToWindow(sessionName, windowIndex) {
        if (!sessionName || windowIndex === undefined)
            return;
        switchWindowProcess.command = ["tmux", "select-window", "-t", `${sessionName}:${windowIndex}`];
        switchWindowProcess.running = true;
    }

    function focusPane(sessionName, paneIndex) {
        if (!sessionName || paneIndex === undefined)
            return;
        focusPaneProcess.command = ["tmux", "select-pane", "-t", `${sessionName}.${paneIndex}`];
        focusPaneProcess.running = true;
    }

    implicitWidth: 400
    implicitHeight: 392

    MouseArea {
        anchors.fill: parent
        enabled: root.deleteMode || root.renameMode
        z: -10

        onClicked: {
            if (root.deleteMode) {
                root.cancelDeleteMode();
            } else if (root.renameMode) {
                root.cancelRenameMode();
            }
        }
    }

    Behavior on height {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutQuart
        }
    }

    Process {
        id: tmuxProcess
        command: ["tmux", "list-sessions", "-F", "#{session_name}"]
        running: false

        stdout: StdioCollector {
            id: tmuxCollector
            waitForEnd: true

            onStreamFinished: {
                let sessions = [];
                let lines = text.trim().split('\n');
                for (let line of lines) {
                    if (line.trim().length > 0) {
                        sessions.push({
                            name: line.trim(),
                            isCreateButton: false,
                            icon: "terminal"
                        });
                    }
                }
                root.tmuxSessions = sessions;
                root.updateFilteredSessions();
            }
        }

        onExited: function (exitCode) {
            if (exitCode !== 0) {
                root.tmuxSessions = [];
                root.updateFilteredSessions();
            }
        }
    }

    Process {
        id: createProcess
        running: false

        onExited: function (code) {
            if (code === 0) {
                root.refreshTmuxSessions();
            }
        }
    }

    Process {
        id: attachProcess
        running: false

        onStarted: function () {
            // Cerrar el dashboard
            Visibilities.setActiveModule("");
        }
    }

    Process {
        id: killProcess
        running: false

        onExited: function (code) {
            if (code === 0) {
                // Sesión eliminada exitosamente, refrescar la lista
                root.refreshTmuxSessions();
            }
        }
    }

    Process {
        id: renameProcess
        running: false

        onExited: function (code) {
            if (code === 0) {
                // Sesión renombrada exitosamente, marcar para seleccionar después del refresh
                root.pendingRenamedSession = root.newSessionName;
                root.refreshTmuxSessions();
            }
            root.cancelRenameMode();
        }
    }

    Process {
        id: windowsProcess
        running: false

        stdout: StdioCollector {
            id: windowsCollector
            waitForEnd: true

            onStreamFinished: {
                let windows = [];
                let lines = text.trim().split('\n');
                for (let line of lines) {
                    if (line.trim().length > 0) {
                        let parts = line.split(':');
                        if (parts.length >= 3) {
                            windows.push({
                                index: parts[0],
                                name: parts[1],
                                active: parts[2] === '1'
                            });
                        }
                    }
                }
                root.sessionWindows = windows;
            }
        }
    }

    Process {
        id: panesProcess
        running: false

        stdout: StdioCollector {
            id: panesCollector
            waitForEnd: true

            onStreamFinished: {
                let panes = [];
                let lines = text.trim().split('\n');

                // First pass: collect all pane data and find max dimensions
                let maxWidth = 0;
                let maxHeight = 0;

                for (let line of lines) {
                    if (line.trim().length > 0) {
                        let parts = line.split(':');
                        if (parts.length >= 7) {
                            let width = parseInt(parts[1]);
                            let height = parseInt(parts[2]);
                            let top = parseInt(parts[3]);
                            let left = parseInt(parts[4]);

                            maxWidth = Math.max(maxWidth, left + width);
                            maxHeight = Math.max(maxHeight, top + height);

                            panes.push({
                                index: parts[0],
                                width: width,
                                height: height,
                                top: top,
                                left: left,
                                active: parts[5] === '1',
                                command: parts[6]
                            });
                        }
                    }
                }

                // Store total dimensions and panes
                for (let pane of panes) {
                    pane.totalWidth = maxWidth;
                    pane.totalHeight = maxHeight;
                }

                root.sessionPanes = panes;
                root.loadingSessionInfo = false;
            }
        }

        onExited: function (code) {
            if (code !== 0) {
                root.sessionPanes = [];
                root.loadingSessionInfo = false;
            }
        }
    }

    Process {
        id: switchWindowProcess
        running: false

        onExited: function (code) {
            if (code === 0) {
                // Refresh session info to update active window
                let currentSession = root.selectedIndex >= 0 && root.selectedIndex < root.filteredSessions.length ? root.filteredSessions[root.selectedIndex] : null;
                if (currentSession && !currentSession.isCreateButton && !currentSession.isCreateSpecificButton) {
                    root.loadSessionInfo(currentSession.name);
                }
            }
        }
    }

    Process {
        id: focusPaneProcess
        running: false

        onExited: function (code) {
            if (code === 0) {
                // Refresh session info to update active pane
                let currentSession = root.selectedIndex >= 0 && root.selectedIndex < root.filteredSessions.length ? root.filteredSessions[root.selectedIndex] : null;
                if (currentSession && !currentSession.isCreateButton && !currentSession.isCreateSpecificButton) {
                    root.loadSessionInfo(currentSession.name);
                }
            }
        }
    }

    RowLayout {
        id: mainLayout
        anchors.fill: parent
        spacing: 8

        // Columna izquierda: Search + Lista
        Item {
            Layout.preferredWidth: root.leftPanelWidth
            Layout.fillHeight: true

            // Search input
            SearchInput {
                id: searchInput
                width: parent.width
                height: 48
                anchors.top: parent.top
                text: root.searchText
                placeholderText: "Search or create tmux session..."
                iconText: ""
                prefixIcon: root.prefixIcon

                onSearchTextChanged: text => {
                    root.searchText = text;
                }

                onBackspaceOnEmpty: {
                    root.backspaceOnEmpty();
                }

                onAccepted: {
                    if (root.deleteMode) {
                        root.cancelDeleteMode();
                    } else if (root.expandedItemIndex >= 0) {
                        // Execute selected option when menu is expanded
                        let session = root.filteredSessions[root.expandedItemIndex];
                        if (session && !session.isCreateButton && !session.isCreateSpecificButton) {
                            // Build options array (Open, Rename, Quit)
                            let options = [function () {
                                    root.attachToSession(session.name);
                                }, function () {
                                    root.enterRenameMode(session.name);
                                    root.expandedItemIndex = -1;
                                }, function () {
                                    root.enterDeleteMode(session.name);
                                    root.expandedItemIndex = -1;
                                }];

                            if (root.selectedOptionIndex >= 0 && root.selectedOptionIndex < options.length) {
                                options[root.selectedOptionIndex]();
                            }
                        }
                    } else {
                        if (root.selectedIndex >= 0 && root.selectedIndex < resultsList.count) {
                            let selectedSession = root.filteredSessions[root.selectedIndex];
                            if (selectedSession) {
                                if (selectedSession.isCreateSpecificButton) {
                                    root.createTmuxSession(selectedSession.sessionNameToCreate);
                                } else if (selectedSession.isCreateButton) {
                                    root.createTmuxSession();
                                } else {
                                    root.attachToSession(selectedSession.name);
                                }
                            }
                        } else {
                            console.log("DEBUG: No action taken - selectedIndex:", root.selectedIndex, "count:", resultsList.count);
                        }
                    }
                }

                onShiftAccepted: {
                    if (!root.deleteMode && !root.renameMode) {
                        if (root.selectedIndex >= 0 && root.selectedIndex < resultsList.count) {
                            let selectedSession = root.filteredSessions[root.selectedIndex];
                            if (selectedSession && !selectedSession.isCreateButton && !selectedSession.isCreateSpecificButton) {
                                // Toggle expanded state
                                if (root.expandedItemIndex === root.selectedIndex) {
                                    root.expandedItemIndex = -1;
                                    root.selectedOptionIndex = 0;
                                    root.keyboardNavigation = false;
                                } else {
                                    root.expandedItemIndex = root.selectedIndex;
                                    root.selectedOptionIndex = 0;
                                    root.keyboardNavigation = true;
                                }
                            }
                        }
                    }
                }

                onCtrlRPressed: {
                    if (!root.deleteMode && !root.renameMode && root.selectedIndex >= 0 && root.selectedIndex < resultsList.count) {
                        let selectedSession = root.filteredSessions[root.selectedIndex];
                        if (selectedSession && !selectedSession.isCreateButton && !selectedSession.isCreateSpecificButton) {
                            root.enterRenameMode(selectedSession.name);
                        }
                    }
                }

                onEscapePressed: {
                    if (root.expandedItemIndex >= 0) {
                        root.expandedItemIndex = -1;
                        root.selectedOptionIndex = 0;
                        root.keyboardNavigation = false;
                    } else if (!root.deleteMode && !root.renameMode) {
                        Visibilities.setActiveModule("");
                    }
                }

                onDownPressed: {
                    if (root.expandedItemIndex >= 0) {
                        // Navigate options when menu is expanded - always 3 options
                        if (root.selectedOptionIndex < 2) {
                            root.selectedOptionIndex++;
                            root.keyboardNavigation = true;
                        }
                    } else if (!root.deleteMode && !root.renameMode && resultsList.count > 0) {
                        if (root.selectedIndex === -1) {
                            root.selectedIndex = 0;
                            resultsList.currentIndex = 0;
                        } else if (root.selectedIndex < resultsList.count - 1) {
                            root.selectedIndex++;
                            resultsList.currentIndex = root.selectedIndex;
                        }
                    }
                }

                onUpPressed: {
                    if (root.expandedItemIndex >= 0) {
                        // Navigate options when menu is expanded
                        if (root.selectedOptionIndex > 0) {
                            root.selectedOptionIndex--;
                            root.keyboardNavigation = true;
                        }
                    } else if (!root.deleteMode && !root.renameMode) {
                        if (root.selectedIndex > 0) {
                            root.selectedIndex--;
                            resultsList.currentIndex = root.selectedIndex;
                        } else if (root.selectedIndex === 0 && root.searchText.length === 0) {
                            root.selectedIndex = -1;
                            resultsList.currentIndex = -1;
                        }
                    }
                }

                onPageDownPressed: {
                    if (!root.deleteMode && !root.renameMode && resultsList.count > 0) {
                        let visibleItems = Math.floor(resultsList.height / 28);
                        let newIndex = Math.min(root.selectedIndex + visibleItems, resultsList.count - 1);
                        if (root.selectedIndex === -1) {
                            newIndex = Math.min(visibleItems - 1, resultsList.count - 1);
                        }
                        root.selectedIndex = newIndex;
                        resultsList.currentIndex = root.selectedIndex;
                    }
                }

                onPageUpPressed: {
                    if (!root.deleteMode && !root.renameMode && resultsList.count > 0) {
                        let visibleItems = Math.floor(resultsList.height / 28);
                        let newIndex = Math.max(root.selectedIndex - visibleItems, 0);
                        if (root.selectedIndex === -1) {
                            newIndex = Math.max(resultsList.count - visibleItems, 0);
                        }
                        root.selectedIndex = newIndex;
                        resultsList.currentIndex = root.selectedIndex;
                    }
                }

                onHomePressed: {
                    if (!root.deleteMode && !root.renameMode && resultsList.count > 0) {
                        root.selectedIndex = 0;
                        resultsList.currentIndex = 0;
                    }
                }

                onEndPressed: {
                    if (!root.deleteMode && !root.renameMode && resultsList.count > 0) {
                        root.selectedIndex = resultsList.count - 1;
                        resultsList.currentIndex = root.selectedIndex;
                    }
                }
            }

            ListView {
                id: resultsList
                width: parent.width
                anchors.top: searchInput.bottom
                anchors.bottom: parent.bottom
                anchors.topMargin: 8
                visible: true
                clip: true
                interactive: !root.deleteMode && !root.renameMode && root.expandedItemIndex === -1
                cacheBuffer: 96
                reuseItems: false

                // Propiedad para detectar si está en movimiento (drag o flick)
                property bool isScrolling: dragging || flicking

                model: sessionsModel
                currentIndex: root.selectedIndex

                property bool enableScrollAnimation: true

                Behavior on contentY {
                    enabled: Config.animDuration > 0 && resultsList.enableScrollAnimation && !resultsList.moving
                    NumberAnimation {
                        duration: Config.animDuration / 2
                        easing.type: Easing.OutCubic
                    }
                }

                onCurrentIndexChanged: {
                    if (currentIndex !== root.selectedIndex) {
                        root.selectedIndex = currentIndex;
                    }

                    // Manual smooth auto-scroll (accounting for variable height items)
                    if (currentIndex >= 0) {
                        var itemY = 0;
                        for (var i = 0; i < currentIndex && i < sessionsModel.count; i++) {
                            var itemHeight = 48;
                            if (i === root.expandedItemIndex && !root.deleteMode && !root.renameMode) {
                                var listHeight = 36 * 3; // Always 3 options
                                itemHeight = 48 + 4 + listHeight + 8;
                            }
                            itemY += itemHeight;
                        }

                        var currentItemHeight = 48;
                        if (currentIndex === root.expandedItemIndex && !root.deleteMode && !root.renameMode) {
                            var listHeight = 36 * 3;
                            currentItemHeight = 48 + 4 + listHeight + 8;
                        }

                        var viewportTop = resultsList.contentY;
                        var viewportBottom = viewportTop + resultsList.height;

                        if (itemY < viewportTop) {
                            // Item is above viewport, scroll up
                            resultsList.contentY = itemY;
                        } else if (itemY + currentItemHeight > viewportBottom) {
                            // Item is below viewport, scroll down
                            resultsList.contentY = itemY + currentItemHeight - resultsList.height;
                        }
                    }
                }

                delegate: Rectangle {
                    required property string sessionId
                    required property var sessionData
                    required property int index

                    property var modelData: sessionData

                    width: resultsList.width
                    height: {
                        let baseHeight = 48;
                        if (index === root.expandedItemIndex && !isInDeleteMode && !isInRenameMode) {
                            var listHeight = 36 * 3; // Always 3 options: Open, Rename, Quit
                            return baseHeight + 4 + listHeight + 8; // base + spacing + list + bottom margin
                        }
                        return baseHeight;
                    }
                    color: "transparent"
                    radius: 16

                    Behavior on y {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Config.animDuration / 2
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on height {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutQuart
                        }
                    }
                    clip: true

                    property bool isInDeleteMode: root.deleteMode && modelData.name === root.sessionToDelete
                    property bool isInRenameMode: root.renameMode && modelData.name === root.sessionToRename
                    property bool isExpanded: index === root.expandedItemIndex
                    property color textColor: {
                        if (isInDeleteMode) {
                            return Styling.srItem("error");
                        } else if (isInRenameMode) {
                            return Styling.srItem("secondary");
                        } else if (isExpanded) {
                            return Styling.srItem("pane");
                        } else if (root.selectedIndex === index) {
                            return Styling.srItem("primary");
                        } else {
                            return Colors.overSurface;
                        }
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: isExpanded ? 48 : parent.height
                        hoverEnabled: !resultsList.isScrolling
                        enabled: !isInDeleteMode && !isInRenameMode
                        acceptedButtons: Qt.LeftButton | Qt.RightButton

                        property real startX: 0
                        property real startY: 0
                        property bool isDragging: false
                        property bool longPressTriggered: false

                        onEntered: {
                            if (resultsList.isScrolling)
                                return;
                            if (!root.deleteMode && !root.renameMode && root.expandedItemIndex === -1) {
                                root.selectedIndex = index;
                                resultsList.currentIndex = index;
                            }
                        }

                        onClicked: mouse => {
                            if (mouse.button === Qt.LeftButton) {
                                if (root.deleteMode && modelData.name !== root.sessionToDelete) {
                                    root.cancelDeleteMode();
                                    return;
                                } else if (root.renameMode && modelData.name !== root.sessionToRename) {
                                    root.cancelRenameMode();
                                    return;
                                }

                                if (!root.deleteMode && !root.renameMode && !isExpanded) {
                                    if (modelData.isCreateSpecificButton) {
                                        root.createTmuxSession(modelData.sessionNameToCreate);
                                    } else if (modelData.isCreateButton) {
                                        root.createTmuxSession();
                                    } else {
                                        root.attachToSession(modelData.name);
                                    }
                                }
                            } else if (mouse.button === Qt.RightButton) {
                                if (root.deleteMode) {
                                    root.cancelDeleteMode();
                                    return;
                                } else if (root.renameMode) {
                                    root.cancelRenameMode();
                                    return;
                                }

                                if (!modelData.isCreateButton && !modelData.isCreateSpecificButton) {
                                    // Toggle expanded state instead of opening menu
                                    if (root.expandedItemIndex === index) {
                                        root.expandedItemIndex = -1;
                                        root.selectedOptionIndex = 0;
                                        root.keyboardNavigation = false;
                                        // Update selection to current hover position after closing
                                        root.selectedIndex = index;
                                        resultsList.currentIndex = index;
                                    } else {
                                        root.expandedItemIndex = index;
                                        root.selectedIndex = index;
                                        resultsList.currentIndex = index;
                                        root.selectedOptionIndex = 0;
                                        root.keyboardNavigation = false;
                                    }
                                }
                            }
                        }

                        onPressed: mouse => {
                            startX = mouse.x;
                            startY = mouse.y;
                            isDragging = false;
                            longPressTriggered = false;

                            if (mouse.button !== Qt.RightButton) {
                                longPressTimer.start();
                            }
                        }

                        onPositionChanged: mouse => {
                            if (pressed && mouse.button !== Qt.RightButton) {
                                let deltaX = mouse.x - startX;
                                let deltaY = mouse.y - startY;
                                let distance = Math.sqrt(deltaX * deltaX + deltaY * deltaY);

                                // Si se mueve más de 10 píxeles, considerar como arrastre
                                if (distance > 10) {
                                    isDragging = true;
                                    longPressTimer.stop();

                                    if (deltaX < -50 && Math.abs(deltaY) < 30 && !modelData.isCreateButton && !modelData.isCreateSpecificButton) {
                                        if (!longPressTriggered) {
                                            root.enterDeleteMode(modelData.name);
                                            longPressTriggered = true;
                                        }
                                    }
                                }
                            }
                        }

                        onReleased: mouse => {
                            longPressTimer.stop();
                            isDragging = false;
                            longPressTriggered = false;
                        }

                        Timer {
                            id: longPressTimer
                            interval: 800
                            repeat: false
                            onTriggered: {
                                if (!mouseArea.isDragging && !modelData.isCreateButton && !modelData.isCreateSpecificButton) {
                                    root.enterRenameMode(modelData.name);
                                    mouseArea.longPressTriggered = true;
                                }
                            }
                        }
                    }

                    // Expandable options list (similar to ClipboardTab)
                    RowLayout {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        anchors.bottomMargin: 8
                        spacing: 4
                        visible: isExpanded && !isInDeleteMode && !isInRenameMode
                        opacity: (isExpanded && !isInDeleteMode && !isInRenameMode) ? 1 : 0

                        Behavior on opacity {
                            enabled: Config.animDuration > 0
                            NumberAnimation {
                                duration: Config.animDuration
                                easing.type: Easing.OutQuart
                            }
                        }

                        ClippingRectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36 * 3 // Always 3 options
                            color: Colors.background
                            radius: Styling.radius(0)

                            Behavior on Layout.preferredHeight {
                                enabled: Config.animDuration > 0
                                NumberAnimation {
                                    duration: Config.animDuration
                                    easing.type: Easing.OutQuart
                                }
                            }

                            ListView {
                                id: optionsListView
                                anchors.fill: parent
                                clip: true
                                interactive: false
                                boundsBehavior: Flickable.StopAtBounds
                                model: [
                                    {
                                        text: "Open",
                                        icon: Icons.popOpen,
                                        highlightColor: Styling.srItem("overprimary"),
                                        textColor: Styling.srItem("primary"),
                                        action: function () {
                                            root.attachToSession(modelData.name);
                                        }
                                    },
                                    {
                                        text: "Rename",
                                        icon: Icons.edit,
                                        highlightColor: Colors.secondary,
                                        textColor: Styling.srItem("secondary"),
                                        action: function () {
                                            root.enterRenameMode(modelData.name);
                                            root.expandedItemIndex = -1;
                                        }
                                    },
                                    {
                                        text: "Quit",
                                        icon: Icons.alert,
                                        highlightColor: Colors.error,
                                        textColor: Styling.srItem("error"),
                                        action: function () {
                                            root.enterDeleteMode(modelData.name);
                                            root.expandedItemIndex = -1;
                                        }
                                    }
                                ]
                                currentIndex: root.selectedOptionIndex
                                highlightFollowsCurrentItem: true
                                highlightRangeMode: ListView.ApplyRange
                                preferredHighlightBegin: 0
                                preferredHighlightEnd: height

                                highlight: StyledRect {
                                    variant: {
                                        if (optionsListView.currentIndex >= 0 && optionsListView.currentIndex < optionsListView.count) {
                                            var item = optionsListView.model[optionsListView.currentIndex];
                                            if (item && item.highlightColor) {
                                                if (item.highlightColor === Colors.error)
                                                    return "error";
                                                if (item.highlightColor === Colors.secondary)
                                                    return "secondary";
                                                return "primary";
                                            }
                                        }
                                        return "primary";
                                    }
                                    radius: Styling.radius(0)
                                    visible: optionsListView.currentIndex >= 0
                                    z: -1

                                    Behavior on opacity {
                                        enabled: Config.animDuration > 0
                                        NumberAnimation {
                                            duration: Config.animDuration / 2
                                            easing.type: Easing.OutQuart
                                        }
                                    }
                                }

                                highlightMoveDuration: Config.animDuration > 0 ? Config.animDuration / 2 : 0
                                highlightMoveVelocity: -1
                                highlightResizeDuration: Config.animDuration / 2
                                highlightResizeVelocity: -1

                                delegate: Item {
                                    required property var modelData
                                    required property int index

                                    property alias itemData: delegateData.modelData

                                    QtObject {
                                        id: delegateData
                                        property var modelData: parent ? parent.modelData : null
                                    }

                                    width: optionsListView.width
                                    height: 36

                                    Rectangle {
                                        anchors.fill: parent
                                        color: "transparent"

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            spacing: 8

                                            Text {
                                                text: modelData && modelData.icon ? modelData.icon : ""
                                                font.family: Icons.font
                                                font.pixelSize: 14
                                                font.weight: Font.Bold
                                                textFormat: Text.RichText
                                                color: {
                                                    if (optionsListView.currentIndex === index && modelData && modelData.textColor) {
                                                        return modelData.textColor;
                                                    }
                                                    return Colors.overSurface;
                                                }

                                                Behavior on color {
                                                    enabled: Config.animDuration > 0
                                                    ColorAnimation {
                                                        duration: Config.animDuration / 2
                                                        easing.type: Easing.OutQuart
                                                    }
                                                }
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData && modelData.text ? modelData.text : ""
                                                font.family: Config.theme.font
                                                font.pixelSize: Config.theme.fontSize
                                                font.weight: optionsListView.currentIndex === index ? Font.Bold : Font.Normal
                                                color: {
                                                    if (optionsListView.currentIndex === index && modelData && modelData.textColor) {
                                                        return modelData.textColor;
                                                    }
                                                    return Colors.overSurface;
                                                }
                                                elide: Text.ElideRight
                                                maximumLineCount: 1

                                                Behavior on color {
                                                    enabled: Config.animDuration > 0
                                                    ColorAnimation {
                                                        duration: Config.animDuration / 2
                                                        easing.type: Easing.OutQuart
                                                    }
                                                }
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor

                                            onEntered: {
                                                optionsListView.currentIndex = index;
                                                root.selectedOptionIndex = index;
                                                root.keyboardNavigation = false;
                                            }

                                            onClicked: {
                                                if (modelData && modelData.action) {
                                                    modelData.action();
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: renameActionContainer
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.rightMargin: 8
                        anchors.topMargin: 8
                        width: 68
                        height: 32
                        color: "transparent"
                        opacity: isInRenameMode ? 1.0 : 0.0
                        visible: opacity > 0

                        transform: Translate {
                            x: isInRenameMode ? 0 : 80

                            Behavior on x {
                                enabled: Config.animDuration > 0
                                NumberAnimation {
                                    duration: Config.animDuration
                                    easing.type: Easing.OutQuart
                                }
                            }
                        }

                        Behavior on opacity {
                            enabled: Config.animDuration > 0
                            NumberAnimation {
                                duration: Config.animDuration / 2
                                easing.type: Easing.OutQuart
                            }
                        }

                        StyledRect {
                            id: renameHighlight
                            variant: "oversecondary"
                            radius: Styling.radius(-4)
                            visible: isInRenameMode
                            z: 0

                            property real activeButtonMargin: 2
                            property real idx1X: root.renameButtonIndex
                            property real idx2X: root.renameButtonIndex

                            x: {
                                let minX = Math.min(idx1X, idx2X) * 36 + activeButtonMargin; // 32 + 4 spacing
                                return minX;
                            }

                            y: activeButtonMargin

                            width: {
                                let stretchX = Math.abs(idx1X - idx2X) * 36 + 32 - activeButtonMargin * 2; // 32 + 4 spacing
                                return stretchX;
                            }

                            height: 32 - activeButtonMargin * 2

                            Behavior on idx1X {
                                enabled: Config.animDuration > 0
                                NumberAnimation {
                                    duration: Config.animDuration / 3
                                    easing.type: Easing.OutSine
                                }
                            }
                            Behavior on idx2X {
                                enabled: Config.animDuration > 0
                                NumberAnimation {
                                    duration: Config.animDuration
                                    easing.type: Easing.OutSine
                                }
                            }
                        }

                        Row {
                            id: renameActionButtons
                            anchors.fill: parent
                            spacing: 4

                            // Botón cancelar (cruz) para rename
                            Rectangle {
                                id: renameCancelButton
                                width: 32
                                height: 32
                                color: "transparent"
                                radius: 6
                                border.width: 0
                                border.color: Colors.outline
                                z: 1

                                property bool isHighlighted: root.renameButtonIndex === 0

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: root.cancelRenameMode()
                                    onEntered: {
                                        root.renameButtonIndex = 0;
                                    }
                                    onExited: parent.color = "transparent"
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: Icons.cancel
                                    color: renameCancelButton.isHighlighted ? Colors.overSecondaryContainer : Colors.overSecondary
                                    font.pixelSize: 14
                                    font.family: Icons.font
                                    textFormat: Text.RichText

                                    Behavior on color {
                                        enabled: Config.animDuration > 0
                                        ColorAnimation {
                                            duration: Config.animDuration / 2
                                            easing.type: Easing.OutQuart
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                id: renameConfirmButton
                                width: 32
                                height: 32
                                color: "transparent"
                                radius: 6
                                z: 1

                                property bool isHighlighted: root.renameButtonIndex === 1

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: root.confirmRenameSession()
                                    onEntered: {
                                        root.renameButtonIndex = 1;
                                    }
                                    onExited: parent.color = "transparent"
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: Icons.accept
                                    color: renameConfirmButton.isHighlighted ? Colors.overSecondaryContainer : Colors.overSecondary
                                    font.pixelSize: 14
                                    font.family: Icons.font
                                    textFormat: Text.RichText

                                    Behavior on color {
                                        enabled: Config.animDuration > 0
                                        ColorAnimation {
                                            duration: Config.animDuration / 2
                                            easing.type: Easing.OutQuart
                                        }
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        id: mainContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 8
                        anchors.rightMargin: isInRenameMode ? 84 : 8
                        height: 32
                        spacing: 8

                        Behavior on anchors.rightMargin {
                            enabled: Config.animDuration > 0
                            NumberAnimation {
                                duration: Config.animDuration
                                easing.type: Easing.OutQuart
                            }
                        }

                        StyledRect {
                            id: iconBackground
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            variant: {
                                if (isInDeleteMode) {
                                    return "overerror";
                                } else if (isInRenameMode) {
                                    return "oversecondary";
                                } else if (root.selectedIndex === index) {
                                    return "overprimary";
                                } else if (modelData.isCreateButton) {
                                    return "primary";
                                } else {
                                    return "common";
                                }
                            }
                            radius: Styling.radius(-4)

                            Text {
                                anchors.centerIn: parent
                                text: {
                                    if (isInDeleteMode) {
                                        return Icons.alert;
                                    } else if (isInRenameMode) {
                                        return Icons.edit;
                                    } else if (modelData.isCreateButton || modelData.isCreateSpecificButton) {
                                        return Icons.plus;
                                    } else {
                                        return Icons.terminalWindow;
                                    }
                                }
                                color: iconBackground.item
                                font.family: Icons.font
                                font.pixelSize: 16
                                textFormat: Text.RichText
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Loader {
                                Layout.fillWidth: true
                                sourceComponent: {
                                    if (root.renameMode && modelData.name === root.sessionToRename) {
                                        return renameTextInput;
                                    } else {
                                        return normalText;
                                    }
                                }
                            }

                            Component {
                                id: normalText
                                Text {
                                    text: {
                                        if (isInDeleteMode && !modelData.isCreateButton && !modelData.isCreateSpecificButton) {
                                            return `Quit "${root.sessionToDelete}"?`;
                                        } else {
                                            return modelData.name;
                                        }
                                    }
                                    color: textColor
                                    font.family: Config.theme.font
                                    font.pixelSize: Config.theme.fontSize
                                    font.weight: isInDeleteMode ? Font.Bold : (modelData.isCreateButton ? Font.Medium : Font.Bold)
                                    elide: Text.ElideRight
                                }
                            }

                            Component {
                                id: renameTextInput
                                TextField {
                                    text: root.newSessionName
                                    color: Colors.overSecondary
                                    selectionColor: Colors.overSecondary
                                    selectedTextColor: Colors.secondary
                                    font.family: Config.theme.font
                                    font.pixelSize: Config.theme.fontSize
                                    font.weight: Font.Bold
                                    background: Rectangle {
                                        color: "transparent"
                                        border.width: 0
                                    }
                                    selectByMouse: true

                                    onTextChanged: {
                                        root.newSessionName = text;
                                    }

                                    Component.onCompleted: {
                                        Qt.callLater(() => {
                                            forceActiveFocus();
                                            selectAll();
                                        });
                                    }

                                    Keys.onPressed: event => {
                                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                            root.confirmRenameSession();
                                            event.accepted = true;
                                        } else if (event.key === Qt.Key_Escape) {
                                            root.cancelRenameMode();
                                            event.accepted = true;
                                        } else if (event.key === Qt.Key_Left) {
                                            root.renameButtonIndex = 0;
                                            event.accepted = true;
                                        } else if (event.key === Qt.Key_Right) {
                                            root.renameButtonIndex = 1;
                                            event.accepted = true;
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: actionContainer
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.rightMargin: 8
                        anchors.topMargin: 8
                        width: 68
                        height: 32
                        color: "transparent"
                        opacity: isInDeleteMode ? 1.0 : 0.0
                        visible: opacity > 0

                        transform: Translate {
                            x: isInDeleteMode ? 0 : 80

                            Behavior on x {
                                enabled: Config.animDuration > 0
                                NumberAnimation {
                                    duration: Config.animDuration
                                    easing.type: Easing.OutQuart
                                }
                            }
                        }

                        Behavior on opacity {
                            enabled: Config.animDuration > 0
                            NumberAnimation {
                                duration: Config.animDuration / 2
                                easing.type: Easing.OutQuart
                            }
                        }

                        StyledRect {
                            id: deleteHighlight
                            variant: "overerror"
                            radius: Styling.radius(-4)
                            visible: isInDeleteMode
                            z: 0

                            property real activeButtonMargin: 2
                            property real idx1X: root.deleteButtonIndex
                            property real idx2X: root.deleteButtonIndex

                            x: {
                                let minX = Math.min(idx1X, idx2X) * 36 + activeButtonMargin; // 32 + 4 spacing
                                return minX;
                            }

                            y: activeButtonMargin

                            width: {
                                let stretchX = Math.abs(idx1X - idx2X) * 36 + 32 - activeButtonMargin * 2; // 32 + 4 spacing
                                return stretchX;
                            }

                            height: 32 - activeButtonMargin * 2

                            Behavior on idx1X {
                                enabled: Config.animDuration > 0
                                NumberAnimation {
                                    duration: Config.animDuration / 3
                                    easing.type: Easing.OutSine
                                }
                            }
                            Behavior on idx2X {
                                enabled: Config.animDuration > 0
                                NumberAnimation {
                                    duration: Config.animDuration
                                    easing.type: Easing.OutSine
                                }
                            }
                        }

                        Row {
                            id: actionButtons
                            anchors.fill: parent
                            spacing: 4

                            // Botón cancelar (cruz)
                            Rectangle {
                                id: cancelButton
                                width: 32
                                height: 32
                                color: "transparent"
                                radius: 6
                                border.width: 0
                                border.color: Colors.outline
                                z: 1

                                property bool isHighlighted: root.deleteButtonIndex === 0

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: root.cancelDeleteMode()
                                    onEntered: {
                                        root.deleteButtonIndex = 0;
                                    }
                                    onExited: parent.color = "transparent"
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: Icons.cancel
                                    color: cancelButton.isHighlighted ? Colors.overErrorContainer : Colors.overError
                                    font.pixelSize: 14
                                    font.family: Icons.font
                                    textFormat: Text.RichText

                                    Behavior on color {
                                        enabled: Config.animDuration > 0
                                        ColorAnimation {
                                            duration: Config.animDuration / 2
                                            easing.type: Easing.OutQuart
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                id: confirmButton
                                width: 32
                                height: 32
                                color: "transparent"
                                radius: 6
                                z: 1

                                property bool isHighlighted: root.deleteButtonIndex === 1

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: root.confirmDeleteSession()
                                    onEntered: {
                                        root.deleteButtonIndex = 1;
                                    }
                                    onExited: parent.color = "transparent"
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: Icons.accept
                                    color: confirmButton.isHighlighted ? Colors.overErrorContainer : Colors.overError
                                    font.pixelSize: 14
                                    font.family: Icons.font
                                    textFormat: Text.RichText

                                    Behavior on color {
                                        enabled: Config.animDuration > 0
                                        ColorAnimation {
                                            duration: Config.animDuration / 2
                                            easing.type: Easing.OutQuart
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                highlight: Item {
                    width: resultsList.width
                    height: {
                        let baseHeight = 48;
                        if (resultsList.currentIndex === root.expandedItemIndex && !root.deleteMode && !root.renameMode) {
                            var listHeight = 36 * 3;
                            return baseHeight + 4 + listHeight + 8;
                        }
                        return baseHeight;
                    }

                    // Calculate Y position based on index, accounting for expanded items
                    y: {
                        var yPos = 0;
                        for (var i = 0; i < resultsList.currentIndex && i < sessionsModel.count; i++) {
                            var itemData = sessionsModel.get(i).sessionData;
                            var itemHeight = 48;
                            if (i === root.expandedItemIndex && !root.deleteMode && !root.renameMode) {
                                var listHeight = 36 * 3;
                                itemHeight = 48 + 4 + listHeight + 8;
                            }
                            yPos += itemHeight;
                        }
                        return yPos;
                    }

                    Behavior on y {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Config.animDuration / 2
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on height {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutQuart
                        }
                    }

                    onHeightChanged: {
                        // Adjust scroll immediately when height changes due to expansion
                        if (root.expandedItemIndex >= 0 && height > 48) {
                            Qt.callLater(() => {
                                adjustScrollForExpandedItem(root.expandedItemIndex);
                            });
                        }
                    }

                    StyledRect {
                        anchors.fill: parent
                        anchors.topMargin: 0
                        anchors.bottomMargin: 0
                        variant: {
                            if (root.deleteMode) {
                                return "error";
                            } else if (root.renameMode) {
                                return "secondary";
                            } else if (root.expandedItemIndex >= 0 && root.selectedIndex === root.expandedItemIndex) {
                                return "pane";
                            } else {
                                return "primary";
                            }
                        }
                        radius: Styling.radius(4)
                        visible: root.selectedIndex >= 0

                        Behavior on color {
                            enabled: Config.animDuration > 0
                            ColorAnimation {
                                duration: Config.animDuration / 2
                                easing.type: Easing.OutQuart
                            }
                        }

                        Behavior on opacity {
                            enabled: Config.animDuration > 0
                            NumberAnimation {
                                duration: Config.animDuration / 2
                                easing.type: Easing.OutQuart
                            }
                        }
                    }
                }

                highlightFollowsCurrentItem: false

                MouseArea {
                    anchors.fill: parent
                    enabled: root.deleteMode || root.renameMode || root.expandedItemIndex >= 0
                    z: 1000
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    function isClickInsideActiveItem(mouseY) {
                        var activeIndex = -1;
                        var isExpanded = false;

                        if (root.deleteMode || root.renameMode) {
                            activeIndex = root.selectedIndex;
                            // In delete/rename mode, height is always base height (48)
                        } else if (root.expandedItemIndex >= 0) {
                            activeIndex = root.expandedItemIndex;
                            isExpanded = true;
                        }

                        if (activeIndex < 0)
                            return false;

                        // Calculate Y position of the item
                        // Since only one item can be expanded/active at a time, and it's the target,
                        // all preceding items must be collapsed (height 48)
                        var itemY = activeIndex * 48;

                        // Calculate item height
                        var itemHeight = 48;
                        if (isExpanded) {
                            // Always 3 options in TmuxTab
                            var listHeight = 36 * 3;
                            itemHeight = 48 + 4 + listHeight + 8;
                        }

                        var clickY = mouseY + resultsList.contentY;
                        return clickY >= itemY && clickY < itemY + itemHeight;
                    }

                    onClicked: mouse => {
                        if (root.deleteMode) {
                            if (!isClickInsideActiveItem(mouse.y)) {
                                root.cancelDeleteMode();
                            }
                            mouse.accepted = true;
                        } else if (root.renameMode) {
                            if (!isClickInsideActiveItem(mouse.y)) {
                                root.cancelRenameMode();
                            }
                            mouse.accepted = true;
                        } else if (root.expandedItemIndex >= 0) {
                            if (!isClickInsideActiveItem(mouse.y)) {
                                console.log("DEBUG: Clicked outside expanded item - closing options");
                                root.expandedItemIndex = -1;
                                root.selectedOptionIndex = 0;
                                root.keyboardNavigation = false;
                                mouse.accepted = true;
                            }
                        }
                    }

                    onPressed: mouse => {
                        if (isClickInsideActiveItem(mouse.y)) {
                            mouse.accepted = false;
                        } else {
                            mouse.accepted = true;
                        }
                    }

                    onReleased: mouse => {
                        if (isClickInsideActiveItem(mouse.y)) {
                            mouse.accepted = false;
                        } else {
                            mouse.accepted = true;
                        }
                    }
                }
            }
        }

        // Separator
        Rectangle {
            Layout.preferredWidth: 2
            Layout.fillHeight: true
            radius: Styling.radius(0)
            color: Colors.surface
        }

        // Preview panel
        Item {
            id: previewPanel
            Layout.fillWidth: true
            Layout.fillHeight: true

            property var currentSession: root.selectedIndex >= 0 && root.selectedIndex < root.filteredSessions.length ? root.filteredSessions[root.selectedIndex] : null

            // Content when session is selected
            Item {
                anchors.fill: parent
                visible: {
                    if (!previewPanel.currentSession)
                        return false;
                    if (previewPanel.currentSession.isCreateButton === true)
                        return false;
                    if (previewPanel.currentSession.isCreateSpecificButton === true)
                        return false;
                    return true;
                }

                // Panes layout preview (top section)
                Item {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: separator.top
                    anchors.bottomMargin: 8

                    Item {
                        anchors.fill: parent

                        // Calculate scale to maximize use of available space
                        property real totalWidth: root.sessionPanes.length > 0 ? root.sessionPanes[0].totalWidth || 1 : 1
                        property real totalHeight: root.sessionPanes.length > 0 ? root.sessionPanes[0].totalHeight || 1 : 1

                        // Use individual scales - stretch to fill
                        property real scaleX: width / totalWidth
                        property real scaleY: height / totalHeight

                        Repeater {
                            model: root.sessionPanes
                            delegate: StyledRect {
                                id: paneRect
                                required property var modelData
                                property bool hovered: false
                                variant: hovered ? "focus" : "pane"

                                x: Math.floor(modelData.left * parent.scaleX)
                                y: Math.floor(modelData.top * parent.scaleY)
                                width: Math.floor(modelData.width * parent.scaleX)
                                height: Math.floor(modelData.height * parent.scaleY)

                                radius: Styling.radius(-2)

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    onEntered: {
                                        paneRect.hovered = true;
                                    }

                                    onExited: {
                                        paneRect.hovered = false;
                                    }

                                    onClicked: {
                                        let currentSession = previewPanel.currentSession;
                                        if (currentSession && !currentSession.isCreateButton && !currentSession.isCreateSpecificButton) {
                                            root.focusPane(currentSession.name, modelData.index);
                                        }
                                    }

                                    onDoubleClicked: {
                                        let currentSession = previewPanel.currentSession;
                                        if (currentSession && !currentSession.isCreateButton && !currentSession.isCreateSpecificButton) {
                                            root.attachToSession(currentSession.name);
                                        }
                                    }
                                }

                                // Active border overlay
                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.width: modelData.active ? 2 : 0
                                    border.color: modelData.active ? Styling.srItem("overprimary") : "transparent"
                                    radius: paneRect.radius

                                    Behavior on border.width {
                                        enabled: Config.animDuration > 0
                                        NumberAnimation {
                                            duration: Config.animDuration / 2
                                            easing.type: Easing.OutQuart
                                        }
                                    }

                                    Behavior on border.color {
                                        enabled: Config.animDuration > 0
                                        ColorAnimation {
                                            duration: Config.animDuration / 2
                                            easing.type: Easing.OutQuart
                                        }
                                    }
                                }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    width: parent.width - 16

                                    // Command
                                    Text {
                                        width: parent.width
                                        text: modelData.command
                                        font.family: Config.theme.font
                                        font.pixelSize: Config.theme.fontSize
                                        font.weight: Font.Bold
                                        color: Colors.overSurfaceVariant
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideMiddle
                                        visible: parent.parent.height > 35

                                        Behavior on color {
                                            enabled: Config.animDuration > 0
                                            ColorAnimation {
                                                duration: Config.animDuration / 2
                                                easing.type: Easing.OutQuart
                                            }
                                        }
                                    }

                                    // Dimensions info
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.width + "×" + modelData.height
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-2)
                                        color: Colors.outline
                                        opacity: 0.7
                                        visible: parent.parent.height > 70

                                        Behavior on color {
                                            enabled: Config.animDuration > 0
                                            ColorAnimation {
                                                duration: Config.animDuration / 2
                                                easing.type: Easing.OutQuart
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Empty state for panes
                        Column {
                            anchors.centerIn: parent
                            spacing: 8
                            visible: root.sessionPanes.length === 0 && !root.loadingSessionInfo

                            Text {
                                text: Icons.terminalWindow
                                font.family: Icons.font
                                font.pixelSize: 32
                                color: Colors.outline
                                anchors.horizontalCenter: parent.horizontalCenter
                                textFormat: Text.RichText
                            }

                            Text {
                                text: "No panes to display"
                                font.family: Config.theme.font
                                font.pixelSize: Config.theme.fontSize
                                color: Colors.outline
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }

                        // Loading indicator
                        Rectangle {
                            anchors.fill: parent
                            color: Colors.background
                            visible: root.loadingSessionInfo

                            Row {
                                anchors.centerIn: parent
                                spacing: 12

                                Text {
                                    text: Icons.spinnerGap
                                    font.family: Icons.font
                                    font.pixelSize: 20
                                    color: Styling.srItem("overprimary")
                                    textFormat: Text.RichText

                                    RotationAnimator on rotation {
                                        from: 0
                                        to: 360
                                        duration: 1000
                                        loops: Animation.Infinite
                                        running: root.loadingSessionInfo
                                    }
                                }

                                Text {
                                    text: "Loading panes..."
                                    font.family: Config.theme.font
                                    font.pixelSize: Config.theme.fontSize
                                    color: Colors.outline
                                }
                            }
                        }
                    }
                }

                // Separator
                Rectangle {
                    id: separator
                    anchors.bottom: windowsSection.top
                    anchors.bottomMargin: 8
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 2
                    radius: Styling.radius(0)
                    color: Colors.surface
                }

                // Windows info section (bottom section)
                Item {
                    id: windowsSection
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 32

                    Flickable {
                        anchors.fill: parent
                        contentWidth: windowsRow.width
                        contentHeight: height
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        Row {
                            id: windowsRow
                            spacing: 4
                            height: parent.height

                            Repeater {
                                model: root.sessionWindows
                                delegate: StyledRect {
                                    id: windowRect
                                    required property var modelData
                                    property bool hovered: false
                                    variant: {
                                        if (modelData.active) {
                                            return hovered ? "primaryfocus" : "primary";
                                        } else {
                                            return hovered ? "focus" : "common";
                                        }
                                    }
                                    width: Math.ceil(windowText.width) + 16
                                    height: parent.height
                                    radius: Styling.radius(-4)

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor

                                        onEntered: {
                                            windowRect.hovered = true;
                                        }

                                        onExited: {
                                            windowRect.hovered = false;
                                        }

                                        onClicked: {
                                            let currentSession = previewPanel.currentSession;
                                            if (currentSession && !currentSession.isCreateButton && !currentSession.isCreateSpecificButton) {
                                                root.switchToWindow(currentSession.name, modelData.index);
                                            }
                                        }

                                        onDoubleClicked: {
                                            let currentSession = previewPanel.currentSession;
                                            if (currentSession && !currentSession.isCreateButton && !currentSession.isCreateSpecificButton) {
                                                root.attachToSession(currentSession.name);
                                            }
                                        }
                                    }

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 4

                                        Text {
                                            id: windowText
                                            text: modelData.index + ": " + modelData.name
                                            font.family: Config.theme.font
                                            font.pixelSize: Config.theme.fontSize
                                            font.weight: modelData.active ? Font.Bold : Font.Normal
                                            color: modelData.active ? Colors.overPrimary : Colors.overSurface

                                            Behavior on color {
                                                enabled: Config.animDuration > 0
                                                ColorAnimation {
                                                    duration: Config.animDuration / 2
                                                    easing.type: Easing.OutQuart
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Empty state
            Column {
                anchors.centerIn: parent
                spacing: 8
                visible: {
                    if (!previewPanel.currentSession)
                        return true;
                    if (previewPanel.currentSession.isCreateButton === true)
                        return true;
                    if (previewPanel.currentSession.isCreateSpecificButton === true)
                        return true;
                    return false;
                }

                Text {
                    text: Icons.terminalWindow
                    font.family: Icons.font
                    font.pixelSize: 48
                    color: Colors.surfaceBright
                    anchors.horizontalCenter: parent.horizontalCenter
                    textFormat: Text.RichText
                }

                Text {
                    text: "No session selected"
                    font.family: Config.theme.font
                    font.pixelSize: Config.theme.fontSize
                    font.weight: Font.Bold
                    color: Colors.overBackground
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "Select a session to preview"
                    font.family: Config.theme.font
                    font.pixelSize: Config.theme.fontSize
                    color: Colors.outline
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    Component.onCompleted: {
        refreshTmuxSessions();
        Qt.callLater(() => {
            focusSearchInput();
        });
    }

    Keys.onPressed: event => {
        if (root.deleteMode) {
            if (event.key === Qt.Key_Left) {
                root.deleteButtonIndex = 0;
                event.accepted = true;
            } else if (event.key === Qt.Key_Right) {
                root.deleteButtonIndex = 1;
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
                if (root.deleteButtonIndex === 0) {
                    root.cancelDeleteMode();
                } else {
                    root.confirmDeleteSession();
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                root.cancelDeleteMode();
                event.accepted = true;
            }
        } else if (root.renameMode) {
            if (event.key === Qt.Key_Left) {
                root.renameButtonIndex = 0;
                event.accepted = true;
            } else if (event.key === Qt.Key_Right) {
                root.renameButtonIndex = 1;
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
                if (root.renameButtonIndex === 0) {
                    root.cancelRenameMode();
                } else {
                    root.confirmRenameSession();
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                root.cancelRenameMode();
                event.accepted = true;
            }
        }
    }

    onDeleteModeChanged: {
        if (!deleteMode) {}
    }

    onRenameModeChanged: {
        if (!renameMode) {}
    }
}
