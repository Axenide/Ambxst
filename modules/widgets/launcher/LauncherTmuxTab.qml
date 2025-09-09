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
            // Crear la sesión con nombre específico
            createProcess.command = ["bash", "-c", `kitty -e tmux new -s "${sessionName}" & disown`];
        } else {
            // Crear sesión sin nombre (tmux se encarga del nombre automático)
            createProcess.command = ["bash", "-c", `kitty -e tmux & disown`];
        }
        createProcess.running = true;
        root.itemSelected(); // Cerrar el notch
    }

    function attachToSession(sessionName) {
        // Ejecutar terminal con tmux attach de forma independiente (detached)
        attachProcess.command = ["bash", "-c", `kitty -e tmux attach-session -t "${sessionName}" & disown`];
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

                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !isInDeleteMode

                    onEntered: {
                        root.selectedIndex = index;
                        resultsList.currentIndex = index;
                    }
                    onClicked: {
                        if (modelData.isCreateSpecificButton) {
                            root.createTmuxSession(modelData.sessionNameToCreate);
                        } else if (modelData.isCreateButton) {
                            root.createTmuxSession();
                        } else {
                            root.attachToSession(modelData.name);
                        }
                    }
                }

                // Contenido principal que permanece fijo
                RowLayout {
                    id: mainContent
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 12

                    // Icono
                    Rectangle {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        color: {
                            if (isInDeleteMode) {
                                return Colors.adapter.overError;
                            } else if (modelData.isCreateButton) {
                                return Colors.adapter.primary;
                            } else {
                                return Colors.adapter.surface;
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
                                } else if (modelData.isCreateButton || modelData.isCreateSpecificButton) {
                                    return Icons.add;
                                } else {
                                    return Icons.terminalWindow;
                                }
                            }
                            color: {
                                if (isInDeleteMode) {
                                    return Colors.adapter.error;
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
                                color: isInDeleteMode ? Colors.adapter.overError : Colors.adapter.overBackground
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
                                color: Colors.adapter.overBackground
                                selectionColor: Colors.adapter.primary
                                selectedTextColor: Colors.adapter.overPrimary
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
                    width: 76 // 32 + 12 + 32 (mismo spacing que el layout principal)
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
                            let minX = Math.min(idx1X, idx2X) * 44 + activeButtonMargin; // 32 + 12 spacing
                            return minX;
                        }

                        y: activeButtonMargin

                        width: {
                            let stretchX = Math.abs(idx1X - idx2X) * 44 + 32 - activeButtonMargin * 2; // 32 + 12 spacing
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
                        spacing: 12

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
                                    parent.color = Colors.adapter.surfaceVariant;
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
                                    parent.color = Qt.darker(Colors.adapter.error, 1.1);
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
                        return Colors.adapter.primary;
                    } else {
                        return Colors.adapter.primary;
                    }
                }
                opacity: root.deleteMode ? 1.0 : 0.2
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
            // En modo renombrar, solo manejar Escape para cancelar (Enter es manejado por el TextInput)
            if (event.key === Qt.Key_Escape) {
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
