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

    property string prefixText: ""
    signal backspaceOnEmpty()

    property string searchText: ""
    property bool showResults: searchText.length > 0
    property int selectedIndex: -1
    property var tmuxSessions: []
    property alias filteredSessions: listModel.sessions

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

    // Options menu state
    property bool optionsMenuOpen: false
    property int menuItemIndex: -1
    property bool menuJustClosed: false
    
    // Session preview state
    property var sessionWindows: []
    property var sessionPanes: []
    property bool loadingSessionInfo: false

    QtObject {
        id: listModel
        property var sessions: []

        function updateSessions(newSessions) {
            sessions = newSessions;
        }
    }

    onSelectedIndexChanged: {
        if (selectedIndex === -1 && resultsList.count > 0) {
            resultsList.positionViewAtIndex(0, ListView.Beginning);
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
                newFilteredSessions.push({
                    name: `Create session "${searchText}"`,
                    isCreateSpecificButton: true,
                    sessionNameToCreate: searchText,
                    icon: "terminal"
                });
            }
        }

        if (searchText.length === 0 && !deleteMode && !renameMode) {
            newFilteredSessions.push({
                name: "Create new session",
                isCreateButton: true,
                icon: "terminal"
            });
        }

        listModel.updateSessions(newFilteredSessions);

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
        Qt.callLater(() => {
        });
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
        if (!sessionName) return;
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
        return text.replace(/\x1b\[[0-9;]*[a-zA-Z]/g, '')
                   .replace(/\x1b\][0-9;]*;[^\x07]*\x07/g, '')
                   .replace(/\x1b[=>]/g, '');
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
        if (!sessionName || windowIndex === undefined) return;
        switchWindowProcess.command = ["tmux", "select-window", "-t", `${sessionName}:${windowIndex}`];
        switchWindowProcess.running = true;
    }
    
    function focusPane(sessionName, paneIndex) {
        if (!sessionName || paneIndex === undefined) return;
        focusPaneProcess.command = ["tmux", "select-pane", "-t", `${sessionName}.${paneIndex}`];
        focusPaneProcess.running = true;
    }

    implicitWidth: 400
    implicitHeight: 7 * 48 + 56

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

    Row {
        id: mainLayout
        anchors.fill: parent
        spacing: 8

        // Columna izquierda: Search + Lista
        Column {
            width: {
                var remainingWidth = parent.width - parent.spacing * 2 - 2; // Total - separators - separator width
                var gridRows = 3;
                var gridColumns = 5;
                var wallpaperHeight = (parent.height + 4 * 2) / gridRows;
                var rightPanelWidth = (wallpaperHeight * gridColumns) - 8;
                return remainingWidth - rightPanelWidth;
            }
            height: parent.height
            spacing: 8

        // Search input
        SearchInput {
            id: searchInput
            width: parent.width
            text: root.searchText
            placeholderText: "Search or create tmux session..."
            iconText: ""
            prefixText: root.prefixText

            onSearchTextChanged: text => {
                root.searchText = text;
            }

            onBackspaceOnEmpty: {
                root.backspaceOnEmpty();
            }

            onAccepted: {
                if (root.deleteMode) {
                    root.cancelDeleteMode();
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
                if (!root.deleteMode && root.selectedIndex >= 0 && root.selectedIndex < resultsList.count) {
                    let selectedSession = root.filteredSessions[root.selectedIndex];
                    if (selectedSession && !selectedSession.isCreateButton && !selectedSession.isCreateSpecificButton) {
                        root.enterDeleteMode(selectedSession.name);
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
                if (!root.deleteMode && !root.renameMode) {
                    Visibilities.setActiveModule("");
                }
                // Si estamos en modo eliminar o renombrar, no hacer nada aquí
                // El handler global del root se encargará
            }

            onDownPressed: {
                if (!root.deleteMode && !root.renameMode && resultsList.count > 0) {
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
                if (!root.deleteMode && !root.renameMode) {
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
            height: parent.height - searchInput.height - parent.spacing
            visible: true
            clip: true
            interactive: !root.deleteMode && !root.renameMode && !root.optionsMenuOpen
            cacheBuffer: 96
            reuseItems: true

            model: root.filteredSessions
            currentIndex: root.selectedIndex

            onCurrentIndexChanged: {
                if (currentIndex !== root.selectedIndex) {
                    root.selectedIndex = currentIndex;
                }
            }

            delegate: Rectangle {
                required property var modelData
                required property int index

                width: resultsList.width
                height: 48
                color: "transparent"
                radius: 16
                clip: true

                property bool isInDeleteMode: root.deleteMode && modelData.name === root.sessionToDelete
                property bool isInRenameMode: root.renameMode && modelData.name === root.sessionToRename

                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !isInDeleteMode && !isInRenameMode && !root.optionsMenuOpen
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    property real startX: 0
                    property real startY: 0
                    property bool isDragging: false
                    property bool longPressTriggered: false

                    onEntered: {
                        if (!root.deleteMode && !root.renameMode && !root.optionsMenuOpen) {
                            root.selectedIndex = index;
                            resultsList.currentIndex = index;
                        }
                    }

                    onClicked: mouse => {
                        if (root.menuJustClosed) {
                            return;
                        }

                        if (mouse.button === Qt.LeftButton) {
                            if (root.deleteMode && modelData.name !== root.sessionToDelete) {
                                root.cancelDeleteMode();
                                return;
                            } else if (root.renameMode && modelData.name !== root.sessionToRename) {
                                root.cancelRenameMode();
                                return;
                            }

                            if (!root.deleteMode && !root.renameMode) {
                                if (modelData.isCreateSpecificButton) {
                                    root.createTmuxSession(modelData.sessionNameToCreate);
                                } else if (modelData.isCreateButton) {
                                    root.createTmuxSession();
                                } else {
                                    root.attachToSession(modelData.name);
                                }
                            }
                        } else if (mouse.button === Qt.RightButton) {
                            if (root.deleteMode || root.renameMode) {
                                if (root.deleteMode) {
                                    root.cancelDeleteMode();
                                } else if (root.renameMode) {
                                    root.cancelRenameMode();
                                }
                                return;
                            }

                            if (!modelData.isCreateButton && !modelData.isCreateSpecificButton) {
                                root.menuItemIndex = index;
                                root.optionsMenuOpen = true;
                                contextMenu.popup(mouse.x, mouse.y);
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

                    OptionsMenu {
                    id: contextMenu

                    onClosed: {
                        root.optionsMenuOpen = false;
                        root.menuItemIndex = -1;
                        root.menuJustClosed = true;
                        menuClosedTimer.start();
                    }

                    Timer {
                        id: menuClosedTimer
                        interval: 100
                        repeat: false
                        onTriggered: {
                            root.menuJustClosed = false;
                        }
                    }

                    items: [
                        {
                            text: "Rename",
                            icon: Icons.edit,
                            highlightColor: Colors.secondary,
                            textColor: Colors.overSecondary,
                            onTriggered: function () {
                                root.enterRenameMode(modelData.name);
                            }
                        },
                        {
                            text: "Quit",
                            icon: Icons.alert,
                            highlightColor: Colors.errorContainer,
                            textColor: Colors.error,
                            onTriggered: function () {
                                root.enterDeleteMode(modelData.name);
                            }
                        }
                    ]
                    }

                    Rectangle {
                        id: renameActionContainer
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: 8
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

                        Rectangle {
                        id: renameHighlight
                        color: Colors.overSecondary
                        radius: Config.roundness > 0 ? Math.max(Config.roundness - 4, 0) : 0
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
                                color: renameCancelButton.isHighlighted ? Colors.secondary : Colors.overSecondary
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
                                color: renameConfirmButton.isHighlighted ? Colors.secondary : Colors.overSecondary
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
                        anchors.fill: parent
                        anchors.margins: 8
                        anchors.rightMargin: isInRenameMode ? 84 : 8
                        spacing: 8

                        Behavior on anchors.rightMargin {
                            enabled: Config.animDuration > 0
                            NumberAnimation {
                                duration: Config.animDuration
                                easing.type: Easing.OutQuart
                            }
                        }

                        Rectangle {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        color: {
                            if (isInDeleteMode) {
                                return Colors.overError;
                            } else if (isInRenameMode) {
                                return Colors.overSecondary;
                            } else if (root.selectedIndex === index) {
                                return Colors.overPrimary;
                            } else if (modelData.isCreateButton) {
                                return Colors.primary;
                            } else {
                                return Colors.surface;
                            }
                        }
                        radius: Config.roundness > 0 ? Math.max(Config.roundness - 4, 0) : 0

                        Behavior on color {
                            enabled: Config.animDuration > 0
                            ColorAnimation {
                                duration: Config.animDuration / 2
                                easing.type: Easing.OutQuart
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: {
                                if (isInDeleteMode) {
                                    return Icons.alert;
                                } else if (isInRenameMode) {
                                    return Icons.edit;
                                } else if (modelData.isCreateButton || modelData.isCreateSpecificButton) {
                                    return Icons.add;
                                } else {
                                    return Icons.terminalWindow;
                                }
                            }
                            color: {
                                if (isInDeleteMode) {
                                    return Colors.error;
                                } else if (isInRenameMode) {
                                    return Colors.secondary;
                                } else if (root.selectedIndex === index) {
                                    return Colors.primary;
                                } else if (modelData.isCreateButton) {
                                    return Colors.background;
                                } else {
                                    return Colors.overSurface;
                                }
                            }
                            font.family: Icons.font
                            font.pixelSize: 16
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
                                color: isInDeleteMode ? Colors.overError : (root.selectedIndex === index ? Colors.overPrimary : Colors.overBackground)
                                font.family: Config.theme.font
                                font.pixelSize: Config.theme.fontSize
                                font.weight: isInDeleteMode ? Font.Bold : (modelData.isCreateButton ? Font.Medium : Font.Bold)
                                elide: Text.ElideRight

                                Behavior on color {
                                    enabled: Config.animDuration > 0
                                    ColorAnimation {
                                        duration: Config.animDuration / 2
                                        easing.type: Easing.OutQuart
                                    }
                                }
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
                                    }
                                }
                            }
                        }
                    }
                    }

                    Rectangle {
                        id: actionContainer
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: 8
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

                        Rectangle {
                        id: deleteHighlight
                        color: Colors.overError
                        radius: Config.roundness > 0 ? Math.max(Config.roundness - 4, 0) : 0
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
                                color: cancelButton.isHighlighted ? Colors.error : Colors.overError
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
                                color: confirmButton.isHighlighted ? Colors.error : Colors.overError
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

            highlight: Rectangle {
                color: {
                    if (root.deleteMode) {
                        return Colors.error;
                    } else if (root.renameMode) {
                        return Colors.secondary;
                    } else {
                        return Colors.primary;
                    }
                }
                radius: Config.roundness > 0 ? Config.roundness + 4 : 0
                visible: root.selectedIndex >= 0 && (root.optionsMenuOpen ? root.selectedIndex === root.menuItemIndex : true)

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

             highlightMoveDuration: Config.animDuration > 0 ? Config.animDuration / 2 : 0
             highlightMoveVelocity: -1

             MouseArea {
                 anchors.fill: parent
                 enabled: root.deleteMode || root.renameMode
                 z: 1000

                 onClicked: {
                     if (root.deleteMode) {
                         root.cancelDeleteMode();
                     } else if (root.renameMode) {
                         root.cancelRenameMode();
                     }
                 }
             }
         }
        }

        // Separator
        Rectangle {
            width: 2
            height: parent.height
            radius: Config.roundness
            color: Colors.surface
        }

        // Preview panel
        Item {
            id: previewPanel
            width: {
                var gridRows = 3;
                var gridColumns = 5;
                var wallpaperHeight = (parent.height + 4 * 2) / gridRows;
                return (wallpaperHeight * gridColumns) - 8;
            }
            height: parent.height

            property var currentSession: root.selectedIndex >= 0 && root.selectedIndex < root.filteredSessions.length ? root.filteredSessions[root.selectedIndex] : null

            // Content when session is selected
            Item {
                anchors.fill: parent
                visible: {
                    if (!previewPanel.currentSession) return false;
                    if (previewPanel.currentSession.isCreateButton === true) return false;
                    if (previewPanel.currentSession.isCreateSpecificButton === true) return false;
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
                            delegate: Rectangle {
                                required property var modelData
                                
                                x: modelData.left * parent.scaleX
                                y: modelData.top * parent.scaleY
                                width: modelData.width * parent.scaleX
                                height: modelData.height * parent.scaleY
                                
                                color: Colors.surface
                                border.width: modelData.active ? 2 : 0
                                border.color: modelData.active ? Colors.primary : "transparent"
                                radius: Config.roundness > 0 ? Math.max(Config.roundness - 2, 0) : 0

                                Behavior on color {
                                    enabled: Config.animDuration > 0
                                    ColorAnimation {
                                        duration: Config.animDuration / 2
                                        easing.type: Easing.OutQuart
                                    }
                                }
                                
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
                                
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    
                                    onEntered: {
                                        parent.color = Colors.surfaceBright;
                                    }
                                    
                                    onExited: {
                                        parent.color = Colors.surface;
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
                                        color: Colors.overSurface
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
                                        font.pixelSize: Math.max(8, Config.theme.fontSize - 2)
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
                                    color: Colors.primary
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
                    radius: Config.roundness
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
                                delegate: Rectangle {
                                    required property var modelData
                                    width: windowText.width + 16
                                    height: parent.height
                                    color: modelData.active ? Colors.primary : Colors.surface
                                    radius: Config.roundness > 0 ? Math.max(Config.roundness - 4, 0) : 0

                                    Behavior on color {
                                        enabled: Config.animDuration > 0
                                        ColorAnimation {
                                            duration: Config.animDuration / 2
                                            easing.type: Easing.OutQuart
                                        }
                                    }
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        
                                        onEntered: {
                                            if (!modelData.active) {
                                                parent.color = Colors.surfaceBright;
                                            }
                                        }
                                        
                                        onExited: {
                                            parent.color = modelData.active ? Colors.primary : Colors.surface;
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
                    if (!previewPanel.currentSession) return true;
                    if (previewPanel.currentSession.isCreateButton === true) return true;
                    if (previewPanel.currentSession.isCreateSpecificButton === true) return true;
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
                if (!deleteMode) {
                }
            }

            onRenameModeChanged: {
                if (!renameMode) {
                }
            }
}
