import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.modules.theme
import qs.modules.components
import qs.modules.globals
import qs.modules.services
import qs.config

Rectangle {
    id: root
    focus: true

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

    signal itemSelected

    // Model para hacer la lista observable
    QtObject {
        id: listModel
        property var sessions: []

        function updateSessions(newSessions) {
            sessions = newSessions;
            console.log("DEBUG: listModel updated with", sessions.length, "sessions");
        }
    }

    onSelectedIndexChanged: {
        if (selectedIndex === -1 && resultsList.count > 0) {
            resultsList.positionViewAtIndex(0, ListView.Beginning);
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
        console.log("DEBUG: updateFilteredSessions called. searchText:", searchText, "tmuxSessions.length:", tmuxSessions.length);

        var newFilteredSessions = [];

        // Filtrar sesiones que coincidan con el texto de búsqueda (sin considerar deleteMode aquí)
        if (searchText.length === 0) {
            newFilteredSessions = tmuxSessions.slice(); // Copia del array
        } else {
            newFilteredSessions = tmuxSessions.filter(function (session) {
                return session.name.toLowerCase().includes(searchText.toLowerCase());
            });

            // Verificar si existe una sesión con el nombre exacto
            let exactMatch = tmuxSessions.find(function (session) {
                return session.name.toLowerCase() === searchText.toLowerCase();
            });

            // Si no hay coincidencia exacta y hay texto de búsqueda, agregar opción para crear la sesión específica
            if (!exactMatch && searchText.length > 0) {
                newFilteredSessions.push({
                    name: `Create session "${searchText}"`,
                    isCreateSpecificButton: true,
                    sessionNameToCreate: searchText,
                    icon: "terminal"
                });
            }
        }

        console.log("DEBUG: newFilteredSessions after filter:", newFilteredSessions.length);

        // Solo agregar el botón "Create new session" cuando NO hay texto de búsqueda y NO estamos en modo eliminar o renombrar
        if (searchText.length === 0 && !deleteMode && !renameMode) {
            newFilteredSessions.push({
                name: "Create new session",
                isCreateButton: true,
                icon: "terminal"
            });
        }

        console.log("DEBUG: newFilteredSessions after adding create button:", newFilteredSessions.length);

        // Actualizar el modelo
        listModel.updateSessions(newFilteredSessions);

        // Auto-highlight first item when text is entered, pero NO en modo eliminar o renombrar
        if (!deleteMode && !renameMode) {
            if (searchText.length > 0 && newFilteredSessions.length > 0) {
                selectedIndex = 0;
                resultsList.currentIndex = 0;
            } else if (searchText.length === 0) {
                selectedIndex = -1;
                resultsList.currentIndex = -1;
            }
        }

        console.log("DEBUG: Final selectedIndex:", selectedIndex, "resultsList will have count:", newFilteredSessions.length);

        // Check if we need to select a pending renamed session
        if (pendingRenamedSession !== "") {
            console.log("DEBUG: Looking for pending renamed session:", pendingRenamedSession);
            for (let i = 0; i < newFilteredSessions.length; i++) {
                if (newFilteredSessions[i].name === pendingRenamedSession) {
                    console.log("DEBUG: Found renamed session at index:", i);
                    selectedIndex = i;
                    resultsList.currentIndex = i;
                    pendingRenamedSession = ""; // Clear the pending selection
                    break;
                }
            }
            // If we didn't find it, clear the pending selection anyway
            if (pendingRenamedSession !== "") {
                console.log("DEBUG: Renamed session not found, clearing pending selection");
                pendingRenamedSession = "";
            }
        }
    }

    function enterDeleteMode(sessionName) {
        console.log("DEBUG: Entering delete mode for session:", sessionName);
        originalSelectedIndex = selectedIndex; // Store the current index
        deleteMode = true;
        sessionToDelete = sessionName;
        deleteButtonIndex = 0; // Start with cancel button selected
        // Quitar focus del SearchInput para que el componente root pueda capturar teclas
        root.forceActiveFocus();
    // No necesito llamar updateFilteredSessions porque el delegate se actualiza automáticamente
    }

    function cancelDeleteMode() {
        console.log("DEBUG: Canceling delete mode");
        deleteMode = false;
        sessionToDelete = "";
        deleteButtonIndex = 0;
        // Devolver focus al SearchInput
        searchInput.focusInput();
        updateFilteredSessions();
        // Restore the original selectedIndex
        selectedIndex = originalSelectedIndex;
        resultsList.currentIndex = originalSelectedIndex;
        originalSelectedIndex = -1;
    }

    function confirmDeleteSession() {
        console.log("DEBUG: Confirming delete for session:", sessionToDelete);
        killProcess.command = ["tmux", "kill-session", "-t", sessionToDelete];
        killProcess.running = true;
        cancelDeleteMode();
    }

    function enterRenameMode(sessionName) {
        console.log("DEBUG: Entering rename mode for session:", sessionName);
        renameSelectedIndex = selectedIndex; // Store the current index
        renameMode = true;
        sessionToRename = sessionName;
        newSessionName = sessionName; // Start with the current name
        renameButtonIndex = 1; // Start with accept button selected
        // Quitar focus del SearchInput para que el componente root pueda capturar teclas
        root.forceActiveFocus();
        // Force focus to the TextInput after the loader switches components
        Qt.callLater(() => {
            console.log("DEBUG: Attempting to find and focus rename TextInput");
        // The TextInput's Component.onCompleted will handle the actual focusing
        });
    }

    function cancelRenameMode() {
        console.log("DEBUG: Canceling rename mode");
        renameMode = false;
        sessionToRename = "";
        newSessionName = "";
        renameButtonIndex = 1;
        // Only clear pending selection if we're not waiting for a rename result
        if (pendingRenamedSession === "") {
            // Devolver focus al SearchInput
            searchInput.focusInput();
            updateFilteredSessions();
            // Restore the original selectedIndex
            selectedIndex = renameSelectedIndex;
            resultsList.currentIndex = renameSelectedIndex;
        } else {
            // If we have a pending renamed session, just restore focus but don't update selection
            searchInput.focusInput();
        }
        renameSelectedIndex = -1;
    }

    function confirmRenameSession() {
        console.log("DEBUG: Confirming rename for session:", sessionToRename, "to:", newSessionName);
        if (newSessionName.trim() !== "" && newSessionName !== sessionToRename) {
            renameProcess.command = ["tmux", "rename-session", "-t", sessionToRename, newSessionName.trim()];
            renameProcess.running = true;
        } else {
            // Si no hay cambios, solo cancelar
            cancelRenameMode();
        }
    }

    function refreshTmuxSessions() {
        tmuxProcess.running = true;
    }

    function createTmuxSession(sessionName) {
        if (sessionName) {
            // Crear la sesión con nombre específico en el directorio home
            createProcess.command = ["bash", "-c", `cd "$HOME" && kitty -e tmux new -s "${sessionName}" & disown`];
        } else {
            // Crear sesión sin nombre en el directorio home
            createProcess.command = ["bash", "-c", `cd "$HOME" && kitty -e tmux & disown`];
        }
        createProcess.running = true;
        root.itemSelected(); // Cerrar el notch
    }

    function attachToSession(sessionName) {
        // Ejecutar terminal con tmux attach de forma independiente (detached) desde home
        attachProcess.command = ["bash", "-c", `cd "$HOME" && kitty -e tmux attach-session -t "${sessionName}" & disown`];
        attachProcess.running = true;
    }

    implicitWidth: 400
    implicitHeight: mainLayout.implicitHeight
    color: "transparent"

    Behavior on height {
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutQuart
        }
    }

    // Proceso para obtener lista de sesiones de tmux
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
                // No hay sesiones o tmux no está disponible
                root.tmuxSessions = [];
                root.updateFilteredSessions();
            }
        }
    }

    // Proceso para crear nuevas sesiones
    Process {
        id: createProcess
        running: false

        onExited: function (code) {
            if (code === 0) {
                // Sesión creada exitosamente, refrescar la lista
                root.refreshTmuxSessions();
            }
        }
    }

    // Proceso para abrir terminal con tmux attach
    Process {
        id: attachProcess
        running: false

        onStarted: function () {
            root.itemSelected();
        }
    }

    // Proceso para eliminar sesiones de tmux
    Process {
        id: killProcess
        running: false

        onExited: function (code) {
            console.log("DEBUG: Kill session completed with code:", code);
            if (code === 0) {
                // Sesión eliminada exitosamente, refrescar la lista
                root.refreshTmuxSessions();
            }
        }
    }

    // Proceso para renombrar sesiones de tmux
    Process {
        id: renameProcess
        running: false

        onExited: function (code) {
            console.log("DEBUG: Rename session completed with code:", code);
            if (code === 0) {
                // Sesión renombrada exitosamente, marcar para seleccionar después del refresh
                root.pendingRenamedSession = root.newSessionName;
                root.refreshTmuxSessions();
            }
            root.cancelRenameMode();
        }
    }

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        spacing: 8

        // Search input
        SearchInput {
            id: searchInput
            Layout.fillWidth: true
            text: root.searchText
            placeholderText: "Search or create tmux session..."
            iconText: ""

            onSearchTextChanged: text => {
                root.searchText = text;
            }

            onAccepted: {
                if (root.deleteMode) {
                    // En modo eliminar, Enter equivale a "N" (no eliminar)
                    console.log("DEBUG: Enter in delete mode - canceling");
                    root.cancelDeleteMode();
                } else {
                    console.log("DEBUG: Enter pressed! searchText:", root.searchText, "selectedIndex:", root.selectedIndex, "resultsList.count:", resultsList.count);

                    if (root.selectedIndex >= 0 && root.selectedIndex < resultsList.count) {
                        let selectedSession = root.filteredSessions[root.selectedIndex];
                        console.log("DEBUG: Selected session:", selectedSession);
                        if (selectedSession) {
                            if (selectedSession.isCreateSpecificButton) {
                                console.log("DEBUG: Creating specific session:", selectedSession.sessionNameToCreate);
                                root.createTmuxSession(selectedSession.sessionNameToCreate);
                            } else if (selectedSession.isCreateButton) {
                                console.log("DEBUG: Creating new session via create button");
                                root.createTmuxSession();
                            } else {
                                console.log("DEBUG: Attaching to existing session:", selectedSession.name);
                                root.attachToSession(selectedSession.name);
                            }
                        }
                    } else {
                        console.log("DEBUG: No action taken - selectedIndex:", root.selectedIndex, "count:", resultsList.count);
                    }
                }
            }

            onShiftAccepted: {
                console.log("DEBUG: Shift+Enter pressed! selectedIndex:", root.selectedIndex, "deleteMode:", root.deleteMode);

                if (!root.deleteMode && root.selectedIndex >= 0 && root.selectedIndex < resultsList.count) {
                    let selectedSession = root.filteredSessions[root.selectedIndex];
                    console.log("DEBUG: Selected session for deletion:", selectedSession);
                    if (selectedSession && !selectedSession.isCreateButton && !selectedSession.isCreateSpecificButton) {
                        // Solo permitir eliminar sesiones reales, no botones de crear
                        root.enterDeleteMode(selectedSession.name);
                    }
                }
            }

            onCtrlRPressed: {
                console.log("DEBUG: Ctrl+R pressed! selectedIndex:", root.selectedIndex, "deleteMode:", root.deleteMode, "renameMode:", root.renameMode);

                if (!root.deleteMode && !root.renameMode && root.selectedIndex >= 0 && root.selectedIndex < resultsList.count) {
                    let selectedSession = root.filteredSessions[root.selectedIndex];
                    console.log("DEBUG: Selected session for renaming:", selectedSession);
                    if (selectedSession && !selectedSession.isCreateButton && !selectedSession.isCreateSpecificButton) {
                        // Solo permitir renombrar sesiones reales, no botones de crear
                        root.enterRenameMode(selectedSession.name);
                    }
                }
            }

            onEscapePressed: {
                if (!root.deleteMode && !root.renameMode) {
                    // Solo cerrar el notch si NO estamos en modo eliminar o renombrar
                    root.itemSelected();
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
                    let visibleItems = Math.floor(resultsList.height / 48);
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
                    let visibleItems = Math.floor(resultsList.height / 48);
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

        // Results list
        ListView {
            id: resultsList
            Layout.fillWidth: true
            Layout.preferredHeight: 5 * 48
            visible: true
            clip: true

            model: root.filteredSessions
            currentIndex: root.selectedIndex

            // Sync currentIndex with selectedIndex
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

                // Gestos táctiles y mouse
                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !isInDeleteMode && !isInRenameMode
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    // Variables para gestos táctiles
                    property real startX: 0
                    property real startY: 0
                    property bool isDragging: false
                    property bool longPressTriggered: false

                    onEntered: {
                        // Solo cambiar la selección si no estamos en modo delete o rename
                        if (!root.deleteMode && !root.renameMode) {
                            root.selectedIndex = index;
                            resultsList.currentIndex = index;
                        }
                    }

                    onPressed: mouse => {
                        startX = mouse.x;
                        startY = mouse.y;
                        isDragging = false;
                        longPressTriggered = false;
                        longPressTimer.start();
                    }

                    onPositionChanged: mouse => {
                        if (pressed) {
                            let deltaX = mouse.x - startX;
                            let deltaY = mouse.y - startY;
                            let distance = Math.sqrt(deltaX * deltaX + deltaY * deltaY);

                            // Si se mueve más de 10 píxeles, considerar como arrastre
                            if (distance > 10) {
                                isDragging = true;
                                longPressTimer.stop();

                                // Detectar swipe hacia la izquierda para quit (solo sesiones reales)
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

                        if (!isDragging && !longPressTriggered) {
                            // Click normal
                            if (mouse.button === Qt.LeftButton) {
                                if (modelData.isCreateSpecificButton) {
                                    root.createTmuxSession(modelData.sessionNameToCreate);
                                } else if (modelData.isCreateButton) {
                                    root.createTmuxSession();
                                } else {
                                    root.attachToSession(modelData.name);
                                }
                            } else if (mouse.button === Qt.RightButton) {
                                // Click derecho - mostrar menú contextual (solo para sesiones reales)
                                if (!modelData.isCreateButton && !modelData.isCreateSpecificButton) {
                                    contextMenu.popup();
                                }
                            }
                        }

                        isDragging = false;
                        longPressTriggered = false;
                    }

                    // Timer para long press
                    Timer {
                        id: longPressTimer
                        interval: 800 // 800ms para activar long press
                        repeat: false
                        onTriggered: {
                            // Long press activado - entrar en modo rename (solo sesiones reales)
                            if (!mouseArea.isDragging && !modelData.isCreateButton && !modelData.isCreateSpecificButton) {
                                root.enterRenameMode(modelData.name);
                                mouseArea.longPressTriggered = true;
                            }
                        }
                    }
                }

                // Menú contextual
                Rectangle {
                    id: contextMenu
                    width: 120
                    height: menuColumn.implicitHeight + 16
                    color: Colors.adapter.surface
                    radius: Config.roundness > 8 ? Config.roundness - 8 : 0
                    border.width: 1
                    border.color: Colors.adapter.outline
                    visible: false
                    z: 1000

                    // Posicionar el menú cerca del cursor
                    property real targetX: 0
                    property real targetY: 0

                    function popup() {
                        // Posicionar el menú en el centro del item
                        x = parent.width / 2 - width / 2;
                        y = parent.height + 8;
                        visible = true;
                        menuFadeIn.start();
                    }

                    function hide() {
                        visible = false;
                    }

                    // Animación de aparición
                    PropertyAnimation {
                        id: menuFadeIn
                        target: contextMenu
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: Config.animDuration / 2
                        easing.type: Easing.OutQuart
                    }

                    Column {
                        id: menuColumn
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 4

                        // Opción Rename
                        Rectangle {
                            width: parent.width
                            height: 32
                            color: renameMouseArea.containsMouse ? Colors.adapter.surfaceVariant : "transparent"
                            radius: 4

                            Row {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 8
                                spacing: 8

                                Text {
                                    text: Icons.terminal
                                    color: Colors.adapter.overSurface
                                    font.family: Icons.font
                                    font.pixelSize: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: "Rename"
                                    color: Colors.adapter.overSurface
                                    font.family: Config.theme.font
                                    font.pixelSize: Config.theme.fontSize
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: renameMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    contextMenu.hide();
                                    root.enterRenameMode(modelData.name);
                                }
                            }
                        }

                        // Opción Quit
                        Rectangle {
                            width: parent.width
                            height: 32
                            color: quitMouseArea.containsMouse ? Colors.adapter.errorContainer : "transparent"
                            radius: 4

                            Row {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 8
                                spacing: 8

                                Text {
                                    text: Icons.alert
                                    color: quitMouseArea.containsMouse ? Colors.adapter.error : Colors.adapter.overSurface
                                    font.family: Icons.font
                                    font.pixelSize: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: "Quit"
                                    color: quitMouseArea.containsMouse ? Colors.adapter.error : Colors.adapter.overSurface
                                    font.family: Config.theme.font
                                    font.pixelSize: Config.theme.fontSize
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: quitMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    contextMenu.hide();
                                    root.enterDeleteMode(modelData.name);
                                }
                            }
                        }
                    }
                }

                // Botones de acción para rename que aparecen desde la derecha
                Rectangle {
                    id: renameActionContainer
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: 8
                    width: 68 // 32 + 4 + 32
                    height: 32
                    color: "transparent"
                    opacity: isInRenameMode ? 1.0 : 0.0
                    visible: opacity > 0

                    transform: Translate {
                        x: isInRenameMode ? 0 : 80

                        Behavior on x {
                            NumberAnimation {
                                duration: Config.animDuration
                                easing.type: Easing.OutQuart
                            }
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Config.animDuration / 2
                            easing.type: Easing.OutQuart
                        }
                    }

                    // Highlight elástico que se estira entre botones para rename
                    Rectangle {
                        id: renameHighlight
                        color: Colors.adapter.overPrimary
                        radius: Config.roundness > 4 ? Config.roundness - 4 : 0
                        visible: isInRenameMode
                        z: 0

                        property real activeButtonMargin: 2
                        property real idx1X: root.renameButtonIndex
                        property real idx2X: root.renameButtonIndex

                        // Posición y tamaño con efecto elástico
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
                            NumberAnimation {
                                duration: Config.animDuration / 3
                                easing.type: Easing.OutSine
                            }
                        }
                        Behavior on idx2X {
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
                            border.color: Colors.adapter.outline
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
                                color: renameCancelButton.isHighlighted ? Colors.adapter.secondary : Colors.adapter.overSecondary
                                font.pixelSize: 14
                                font.family: Icons.font

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Config.animDuration / 2
                                        easing.type: Easing.OutQuart
                                    }
                                }
                            }
                        }

                        // Botón confirmar (check) para rename
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
                                color: renameConfirmButton.isHighlighted ? Colors.adapter.secondary : Colors.adapter.overSecondary
                                font.pixelSize: 14
                                font.family: Icons.font

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Config.animDuration / 2
                                        easing.type: Easing.OutQuart
                                    }
                                }
                            }
                        }
                    }
                }

                // Overlay para cerrar el menú al hacer click fuera
                MouseArea {
                    anchors.fill: parent
                    visible: contextMenu.visible
                    z: 999
                    onClicked: contextMenu.hide()
                }

                // Contenido principal que permanece fijo
                RowLayout {
                    id: mainContent
                    anchors.fill: parent
                    anchors.margins: 8
                    anchors.rightMargin: isInRenameMode ? 84 : 8 // 68 (ancho botones) + 16 (padding extra)
                    spacing: 12

                    Behavior on anchors.rightMargin {
                        NumberAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutQuart
                        }
                    }

                    // Icono
                    Rectangle {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        color: {
                            if (isInDeleteMode) {
                                return Colors.adapter.overError;
                            } else if (isInRenameMode) {
                                return Colors.adapter.overSecondary;
                            } else if (root.selectedIndex === index) {
                                return Colors.adapter.overPrimary;
                            } else if (modelData.isCreateButton) {
                                return Colors.adapter.primary;
                            } else {
                                return Colors.surface;
                            }
                        }
                        radius: Config.roundness > 4 ? Config.roundness - 4 : 0

                        Behavior on color {
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
                                    return Colors.adapter.error;
                                } else if (isInRenameMode) {
                                    return Colors.adapter.secondary;
                                } else if (root.selectedIndex === index) {
                                    return Colors.adapter.primary;
                                } else if (modelData.isCreateButton) {
                                    return Colors.background;
                                } else {
                                    return Colors.adapter.overSurface;
                                }
                            }
                            font.family: Icons.font
                            font.pixelSize: 16

                            Behavior on color {
                                ColorAnimation {
                                    duration: Config.animDuration / 2
                                    easing.type: Easing.OutQuart
                                }
                            }
                        }
                    }

                    // Texto
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        // Texto principal - Alternar entre Text y TextInput basado en modo renombrar
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

                        // Componente para texto normal
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
                                color: isInDeleteMode ? Colors.adapter.overError : (root.selectedIndex === index ? Colors.adapter.overPrimary : Colors.adapter.overBackground)
                                font.family: Config.theme.font
                                font.pixelSize: Config.theme.fontSize
                                font.weight: isInDeleteMode ? Font.Bold : (modelData.isCreateButton ? Font.Medium : Font.Bold)
                                elide: Text.ElideRight

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Config.animDuration / 2
                                        easing.type: Easing.OutQuart
                                    }
                                }
                            }
                        }

                        // Componente para campo de renombrar
                        Component {
                            id: renameTextInput
                            TextField {
                                text: root.newSessionName
                                color: Colors.adapter.overSecondary
                                selectionColor: Colors.adapter.overSecondary
                                selectedTextColor: Colors.adapter.secondary
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
                                    // Use Qt.callLater to ensure the component is fully loaded before focusing
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

                // Botones de acción que aparecen desde la derecha
                Rectangle {
                    id: actionContainer
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: 8
                    width: 68 // 32 + 4 + 32
                    height: 32
                    color: "transparent"
                    opacity: isInDeleteMode ? 1.0 : 0.0
                    visible: opacity > 0

                    transform: Translate {
                        x: isInDeleteMode ? 0 : 80

                        Behavior on x {
                            NumberAnimation {
                                duration: Config.animDuration
                                easing.type: Easing.OutQuart
                            }
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Config.animDuration / 2
                            easing.type: Easing.OutQuart
                        }
                    }

                    // Highlight elástico que se estira entre botones
                    Rectangle {
                        id: deleteHighlight
                        color: Colors.adapter.overError
                        radius: Config.roundness > 4 ? Config.roundness - 4 : 0
                        visible: isInDeleteMode
                        z: 0

                        property real activeButtonMargin: 2
                        property real idx1X: root.deleteButtonIndex
                        property real idx2X: root.deleteButtonIndex

                        // Posición y tamaño con efecto elástico
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
                            NumberAnimation {
                                duration: Config.animDuration / 3
                                easing.type: Easing.OutSine
                            }
                        }
                        Behavior on idx2X {
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
                            border.color: Colors.adapter.outline
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
                                color: cancelButton.isHighlighted ? Colors.adapter.error : Colors.adapter.overError
                                font.pixelSize: 14
                                font.family: Icons.font

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Config.animDuration / 2
                                        easing.type: Easing.OutQuart
                                    }
                                }
                            }
                        }

                        // Botón confirmar (check)
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
                                color: confirmButton.isHighlighted ? Colors.adapter.error : Colors.adapter.overError
                                font.pixelSize: 14
                                font.family: Icons.font

                                Behavior on color {
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
                        return Colors.adapter.error;
                    } else if (root.renameMode) {
                        return Colors.adapter.secondary;
                    } else {
                        return Colors.adapter.primary;
                    }
                }
                radius: Config.roundness > 0 ? Config.roundness + 4 : 0
                visible: root.selectedIndex >= 0

                Behavior on color {
                    ColorAnimation {
                        duration: Config.animDuration / 2
                        easing.type: Easing.OutQuart
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Config.animDuration / 2
                        easing.type: Easing.OutQuart
                    }
                }
            }

            highlightMoveDuration: Config.animDuration / 2
            highlightMoveVelocity: -1
        }
    }

    Component.onCompleted: {
        // Cargar sesiones de tmux al inicializar
        refreshTmuxSessions();
        Qt.callLater(() => {
            focusSearchInput();
        });
    }

    // Handler de teclas global para manejar navegación en modo eliminar y renombrar
    Keys.onPressed: event => {
        if (root.deleteMode) {
            if (event.key === Qt.Key_Left) {
                root.deleteButtonIndex = 0; // Cancelar (cruz)
                event.accepted = true;
            } else if (event.key === Qt.Key_Right) {
                root.deleteButtonIndex = 1; // Confirmar (check)
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
                // Ejecutar acción del botón seleccionado
                if (root.deleteButtonIndex === 0) {
                    console.log("DEBUG: Enter/Space pressed - canceling delete");
                    root.cancelDeleteMode();
                } else {
                    console.log("DEBUG: Enter/Space pressed - confirming delete");
                    root.confirmDeleteSession();
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                console.log("DEBUG: Escape pressed in delete mode - canceling without closing notch");
                root.cancelDeleteMode();
                event.accepted = true;
            }
        } else if (root.renameMode) {
            // En modo renombrar, manejar navegación entre botones y acciones
            if (event.key === Qt.Key_Left) {
                root.renameButtonIndex = 0; // Cancelar (cruz)
                event.accepted = true;
            } else if (event.key === Qt.Key_Right) {
                root.renameButtonIndex = 1; // Confirmar (check)
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
                // Ejecutar acción del botón seleccionado
                if (root.renameButtonIndex === 0) {
                    console.log("DEBUG: Enter/Space pressed - canceling rename");
                    root.cancelRenameMode();
                } else {
                    console.log("DEBUG: Enter/Space pressed - confirming rename");
                    root.confirmRenameSession();
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                console.log("DEBUG: Escape pressed in rename mode - canceling rename");
                root.cancelRenameMode();
                event.accepted = true;
            }
        }
    }

    // Monitor cambios en deleteMode para cancelar al cambiar tabs
    onDeleteModeChanged: {
        if (!deleteMode) {
            console.log("DEBUG: Delete mode ended");
        }
    }

    // Monitor cambios en renameMode
    onRenameModeChanged: {
        if (!renameMode) {
            console.log("DEBUG: Rename mode ended");
        }
    }
}
