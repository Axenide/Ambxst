import QtQuick
import QtQuick.Effects
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

Rectangle {
    id: root
    focus: true

    // Prefix support
    property string prefixIcon: ""
    signal backspaceOnEmpty

    property string searchText: ""
    property bool showResults: searchText.length > 0
    property int selectedIndex: -1
    property int selectedRecentIndex: -1
    property int lastSelectedRecentIndex: -1
    property bool isRecentFocused: false
    property bool hasNavigatedFromSearch: false
    property bool clearButtonFocused: false
    property bool clearButtonConfirmState: false
    property var emojiData: []
    property var recentEmojis: []
    property var filteredEmojis: []
    
    // Performance optimization
    property int maxResults: 30
    property bool searchDebounceActive: false
    
    // Animated list models for smooth transitions
    ListModel {
        id: animatedEmojisModel
    }
    
    ListModel {
        id: animatedRecentModel
    }
    
    // Debounce timer for search
    Timer {
        id: searchDebounceTimer
        interval: 150
        repeat: false
        onTriggered: {
            searchDebounceActive = false;
            performSearch();
        }
    }

    onSelectedIndexChanged: {
        if (selectedIndex === -1 && emojiList.count > 0) {
            emojiList.positionViewAtIndex(0, ListView.Beginning);
        }
    }

    onSearchTextChanged: {
        // Debounce search for better performance
        searchDebounceActive = true;
        searchDebounceTimer.restart();
    }

    function clearSearch() {
        searchText = "";
        selectedIndex = -1;
        selectedRecentIndex = -1;
        lastSelectedRecentIndex = -1;
        isRecentFocused = false;
        hasNavigatedFromSearch = false;
        clearButtonFocused = false;
        clearButtonConfirmState = false;
        searchInput.focusInput();
        
        // Load initial emojis when clearing search
        loadInitialEmojis();
        emojiList.enableScrollAnimation = false;
        emojiList.contentY = 0;
        Qt.callLater(() => { emojiList.enableScrollAnimation = true; });
    }

    function resetClearButton() {
        clearButtonConfirmState = false;
    }

    function clearRecentEmojis() {
        recentEmojis = [];
        saveRecentEmojis();
        clearButtonConfirmState = false;
        clearButtonFocused = false;
        searchInput.focusInput();
    }

    function focusSearchInput() {
        searchInput.focusInput();
    }

    function performSearch() {
        // When search is empty, show initial 20 emojis
        if (searchText.length === 0) {
            loadInitialEmojis();
            selectedIndex = -1;
            selectedRecentIndex = -1;
            
            emojiList.enableScrollAnimation = false;
            emojiList.contentY = 0;
            Qt.callLater(() => { emojiList.enableScrollAnimation = true; });
            return;
        }
        
        updateFilteredEmojis();
    }

    function updateFilteredEmojis() {
        var filtered = [];
        var searchLower = searchText.toLowerCase();
        var resultCount = 0;

        // Only search when there's text, limit results for performance
        if (searchText.length > 0) {
            for (var i = 0; i < emojiData.length && resultCount < maxResults; i++) {
                var emoji = emojiData[i];
                var emojiText = emoji.emoji;
                var searchTerms = emoji.search;

                // Check if search text matches emoji or any search term
                if (emojiText.includes(searchText) || searchTerms.toLowerCase().includes(searchLower)) {
                    filtered.push(emoji);
                    resultCount++;
                }
            }
        }

        filteredEmojis = filtered;
        emojiList.enableScrollAnimation = false;
        emojiList.contentY = 0;
        updateAnimatedEmojisModel(filtered);

        if (searchText.length > 0 && filteredEmojis.length > 0 && !isRecentFocused) {
            selectedIndex = 0;
            emojiList.currentIndex = 0;
            Qt.callLater(() => { emojiList.enableScrollAnimation = true; });
        } else if (searchText.length === 0 && !hasNavigatedFromSearch) {
            selectedIndex = -1;
            selectedRecentIndex = -1;
            Qt.callLater(() => { emojiList.enableScrollAnimation = true; });
        }
    }

    // Update the animated emoji model with smooth transitions
    function updateAnimatedEmojisModel(newItems) {
        // If search is empty or too many results, just clear and batch insert
        if (newItems.length === 0) {
            animatedEmojisModel.clear();
            return;
        }
        
        // For initial population or complete refresh, use batch operations
        if (animatedEmojisModel.count === 0 || Math.abs(newItems.length - animatedEmojisModel.count) > 50) {
            animatedEmojisModel.clear();
            for (var i = 0; i < newItems.length; i++) {
                animatedEmojisModel.append({
                    emojiId: newItems[i].search,
                    emojiData: newItems[i]
                });
            }
            return;
        }
        
        // Create a unique ID for each emoji (using search term as ID)
        var newItemsById = {};
        for (var i = 0; i < newItems.length; i++) {
            newItemsById[newItems[i].search] = i;
        }

        // Create map of current items for faster lookup
        var currentItemsById = {};
        for (var i = 0; i < animatedEmojisModel.count; i++) {
            currentItemsById[animatedEmojisModel.get(i).emojiId] = i;
        }

        // Remove items that are no longer in the filtered list
        for (var i = animatedEmojisModel.count - 1; i >= 0; i--) {
            var item = animatedEmojisModel.get(i);
            if (!(item.emojiId in newItemsById)) {
                animatedEmojisModel.remove(i);
            }
        }

        // Add new items and reorder existing ones
        for (var i = 0; i < newItems.length; i++) {
            var newItem = newItems[i];
            var currentIndex = currentItemsById[newItem.search];

            if (currentIndex === undefined) {
                // Item doesn't exist, insert it
                animatedEmojisModel.insert(i, {
                    emojiId: newItem.search,
                    emojiData: newItem
                });
            } else if (currentIndex !== i) {
                // Item exists but in wrong position, move it
                animatedEmojisModel.move(currentIndex, i, 1);
            }
        }
    }

    // Update the animated recent model with smooth transitions
    function updateAnimatedRecentModel(newItems) {
        var newItemsById = {};
        for (var i = 0; i < newItems.length; i++) {
            newItemsById[newItems[i].search] = i;
        }

        for (var i = animatedRecentModel.count - 1; i >= 0; i--) {
            var item = animatedRecentModel.get(i);
            if (!(item.emojiId in newItemsById)) {
                animatedRecentModel.remove(i);
            }
        }

        for (var i = 0; i < newItems.length; i++) {
            var newItem = newItems[i];
            var currentIndex = -1;

            for (var j = 0; j < animatedRecentModel.count; j++) {
                if (animatedRecentModel.get(j).emojiId === newItem.search) {
                    currentIndex = j;
                    break;
                }
            }

            if (currentIndex === -1) {
                animatedRecentModel.insert(i, {
                    emojiId: newItem.search,
                    emojiData: newItem
                });
            } else if (currentIndex !== i) {
                animatedRecentModel.move(currentIndex, i, 1);
            }
        }
    }

    function loadEmojiData() {
        // Load emoji data from fuzzel-emoji.sh
        emojiProcess.command = ["bash", "-c", "sed '1,/^### DATA ###$/d' /home/adriano/Repos/Axenide/Ambxst/scripts/fuzzel-emoji.sh"];
        emojiProcess.running = true;
    }
    
    function loadInitialEmojis() {
        // Load first 20 emojis for initial display
        var initial = [];
        for (var i = 0; i < Math.min(20, emojiData.length); i++) {
            initial.push(emojiData[i]);
        }
        
        // Populate the model with initial emojis
        animatedEmojisModel.clear();
        for (var i = 0; i < initial.length; i++) {
            animatedEmojisModel.append({
                emojiId: initial[i].search,
                emojiData: initial[i]
            });
        }
        
        filteredEmojis = initial;
    }

    function loadRecentEmojis() {
        // Load recent emojis from JSON
        recentProcess.command = ["bash", "-c", "cat " + Quickshell.dataDir + "/emojis.json 2>/dev/null || echo '[]'"];
        recentProcess.running = true;
    }

    function saveRecentEmojis() {
        // Save recent emojis to JSON
        var jsonData = JSON.stringify(recentEmojis, null, 2);
        saveProcess.command = ["bash", "-c", "echo '" + jsonData.replace(/'/g, "'\\''") + "' > " + Quickshell.dataDir + "/emojis.json"];
        saveProcess.running = true;
    }

    function addToRecent(emoji) {
        // Remove if already exists
        recentEmojis = recentEmojis.filter(function (item) {
            return item.emoji !== emoji.emoji;
        });

        // Add to beginning with usage count
        emoji.usage = (emoji.usage || 0) + 1;
        emoji.lastUsed = Date.now();
        recentEmojis.unshift(emoji);

        // Keep only last 50
        if (recentEmojis.length > 50) {
            recentEmojis = recentEmojis.slice(0, 50);
        }

        // Sort by usage desc, then last used desc
        recentEmojis.sort(function (a, b) {
            if (a.usage !== b.usage) {
                return b.usage - a.usage;
            }
            return b.lastUsed - a.lastUsed;
        });

        updateAnimatedRecentModel(recentEmojis);
        saveRecentEmojis();
    }

    function copyEmoji(emoji) {
        // Guardar en recientes primero
        root.addToRecent(emoji);
        
        // Cerrar el dashboard
        Visibilities.setActiveModule("");
        
        // Usar el servicio de clipboard para copiar y escribir el emoji
        // El servicio persiste incluso cuando se cierra el dashboard
        ClipboardService.copyAndTypeEmoji(emoji.emoji);
    }

    function onDownPressed() {
        if (!hasNavigatedFromSearch) {
            // Primera vez presionando down desde search
            hasNavigatedFromSearch = true;
            if (filteredEmojis.length > 0) {
                // Ir directo a emojis (ya no priorizamos recientes)
                isRecentFocused = false;
                selectedRecentIndex = -1;
                recentList.currentIndex = -1;
                if (selectedIndex === -1) {
                    selectedIndex = 0;
                    emojiList.currentIndex = 0;
                }
            }
        } else {
            // Ya navegamos desde search, ahora navegamos dentro de la lista normal
            if (!isRecentFocused && emojiList.count > 0 && selectedIndex >= 0) {
                if (selectedIndex < emojiList.count - 1) {
                    selectedIndex++;
                    emojiList.currentIndex = selectedIndex;
                }
            } else if (isRecentFocused && recentEmojis.length > 0) {
                // Navegamos en la lista vertical de recientes
                if (selectedRecentIndex < recentEmojis.length - 1) {
                    selectedRecentIndex++;
                    recentList.currentIndex = selectedRecentIndex;
                    lastSelectedRecentIndex = selectedRecentIndex;
                }
            }
        }
    }

    function onUpPressed() {
        if (isRecentFocused) {
            // En lista de recientes
            if (selectedRecentIndex > 0) {
                selectedRecentIndex--;
                recentList.currentIndex = selectedRecentIndex;
                lastSelectedRecentIndex = selectedRecentIndex;
            } else if (selectedRecentIndex === 0) {
                // Volver al search
                isRecentFocused = false;
                selectedRecentIndex = -1;
                recentList.currentIndex = -1;
                hasNavigatedFromSearch = false;
            }
        } else if (selectedIndex > 0) {
            // Navigate within normal list
            selectedIndex--;
            emojiList.currentIndex = selectedIndex;
        } else if (selectedIndex === 0) {
            // Go back to search
            selectedIndex = -1;
            emojiList.currentIndex = -1;
            hasNavigatedFromSearch = false;
        }
    }

    function onLeftPressed() {
        // Cambiar foco a la lista normal si estamos en recientes
        if (isRecentFocused && recentEmojis.length > 0) {
            isRecentFocused = false;
            selectedRecentIndex = -1;
            recentList.currentIndex = -1;
            if (filteredEmojis.length > 0) {
                if (selectedIndex === -1) {
                    selectedIndex = 0;
                }
                emojiList.currentIndex = selectedIndex;
            }
        }
    }

    function onRightPressed() {
        // Cambiar foco a la lista de recientes si estamos en normal y hay recientes
        if (!isRecentFocused && recentEmojis.length > 0 && searchText.length === 0) {
            isRecentFocused = true;
            selectedIndex = -1;
            emojiList.currentIndex = -1;
            if (lastSelectedRecentIndex >= 0 && lastSelectedRecentIndex < recentEmojis.length) {
                selectedRecentIndex = lastSelectedRecentIndex;
            } else {
                selectedRecentIndex = 0;
                lastSelectedRecentIndex = selectedRecentIndex;
            }
            recentList.currentIndex = selectedRecentIndex;
        }
    }

    implicitWidth: 400
    implicitHeight: mainLayout.implicitHeight
    color: "transparent"

    Behavior on height {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutQuart
        }
    }

    // Load emoji data
    Process {
        id: emojiProcess
        running: false

        stdout: StdioCollector {
            waitForEnd: true

            onStreamFinished: {
                var lines = text.trim().split('\n');
                var data = [];
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (line.length > 0) {
                        var parts = line.split(' ');
                        if (parts.length >= 2) {
                            var emoji = parts[0];
                            var search = parts.slice(1).join(' ');
                            data.push({
                                emoji: emoji,
                                search: search
                            });
                        }
                    }
                }
                emojiData = data;
                
                // Load first 20 emojis by default for initial display
                loadInitialEmojis();
            }
        }

        onExited: function (code) {
            if (code !== 0) {}
        }
    }

    // Load recent emojis
    Process {
        id: recentProcess
        running: false

        stdout: StdioCollector {
            waitForEnd: true

            onStreamFinished: {
                try {
                    recentEmojis = JSON.parse(text.trim());
                    updateAnimatedRecentModel(recentEmojis);
                } catch (e) {
                    recentEmojis = [];
                    updateAnimatedRecentModel([]);
                }
            }
        }

        onExited: function (code) {
            if (code !== 0) {}
        }
    }

    // Save recent emojis
    Process {
        id: saveProcess
        running: false
    }

    Row {
        id: mainLayout
        anchors.fill: parent
        spacing: 8

        // Contenedor de listas de emojis (layout horizontal)
        Row {
            width: parent.width
            height: parent.height
            spacing: 8

            // Columna izquierda: Search + Lista normal de emojis
            Column {
                width: LayoutMetrics.calculateLeftPanelWidth(parent.width, parent.height, parent.spacing)
                height: parent.height
                spacing: 8

                // Barra de búsqueda con botón de limpiar
                Row {
                    width: parent.width
                    height: 48
                    spacing: 8

                    SearchInput {
                        id: searchInput
                        width: parent.width - clearButton.width - parent.spacing
                        height: parent.height
                        text: root.searchText
                        placeholderText: "Search emojis..."
                        prefixIcon: root.prefixIcon

                        onSearchTextChanged: text => {
                            root.searchText = text;
                        }

                        onBackspaceOnEmpty: {
                            root.backspaceOnEmpty();
                        }

                        onAccepted: {
                            if (isRecentFocused && selectedRecentIndex >= 0 && selectedRecentIndex < recentEmojis.length) {
                                var selectedEmoji = recentEmojis[selectedRecentIndex];
                                if (selectedEmoji) {
                                    root.copyEmoji(selectedEmoji);
                                }
                            } else if (!isRecentFocused && selectedIndex >= 0 && selectedIndex < filteredEmojis.length) {
                                var selectedEmoji = filteredEmojis[selectedIndex];
                                if (selectedEmoji) {
                                    root.copyEmoji(selectedEmoji);
                                }
                            }
                        }

                        onEscapePressed: {
                            if (root.searchText.length === 0) {
                                Visibilities.setActiveModule("");
                            } else {
                                root.clearSearch();
                            }
                        }

                        onDownPressed: {
                            root.onDownPressed();
                        }

                        onUpPressed: {
                            root.onUpPressed();
                        }

                        onLeftPressed: {
                            root.onLeftPressed();
                        }

                        onRightPressed: {
                            root.onRightPressed();
                        }
                    }

                    // Botón de limpiar recientes
                    StyledRect {
                        id: clearButton
                        width: root.clearButtonConfirmState ? 140 : 48
                        height: 48
                        radius: searchInput.radius
                        variant: {
                            if (root.clearButtonConfirmState) {
                                return "error";
                            } else if (root.clearButtonFocused || clearButtonMouseArea.containsMouse) {
                                return "focus";
                            } else {
                                return "pane";
                            }
                        }
                        focus: root.clearButtonFocused
                        activeFocusOnTab: true

                        Behavior on width {
                            enabled: Config.animDuration > 0
                            NumberAnimation {
                                duration: Config.animDuration
                                easing.type: Easing.OutQuart
                            }
                        }

                        onActiveFocusChanged: {
                            if (activeFocus) {
                                root.clearButtonFocused = true;
                            } else {
                                root.clearButtonFocused = false;
                                root.resetClearButton();
                            }
                        }

                        MouseArea {
                            id: clearButtonMouseArea
                            anchors.fill: parent
                            hoverEnabled: true

                            onClicked: {
                                if (root.clearButtonConfirmState) {
                                    root.clearRecentEmojis();
                                } else {
                                    root.clearButtonConfirmState = true;
                                }
                            }
                        }

                        Row {
                            id: clearButtonContent
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8

                            Text {
                                width: 32
                                height: parent.height
                                text: root.clearButtonConfirmState ? Icons.xeyes : Icons.broom
                                font.family: Icons.font
                                font.pixelSize: 20
                                color: root.clearButtonConfirmState ? clearButton.itemColor : Config.resolveColor(Config.theme.srOverPrimary.itemColor)
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                textFormat: Text.RichText
                            }

                            Text {
                                width: parent.width - 32 - parent.spacing
                                height: parent.height
                                text: "Clear recent?"
                                font.family: Config.theme.font
                                font.weight: Font.Bold
                                font.pixelSize: Config.theme.fontSize
                                color: clearButton.itemColor
                                opacity: root.clearButtonConfirmState ? 1.0 : 0.0
                                visible: opacity > 0
                                verticalAlignment: Text.AlignVCenter

                                Behavior on opacity {
                                    enabled: Config.animDuration > 0
                                    NumberAnimation {
                                        duration: Config.animDuration / 2
                                        easing.type: Easing.OutQuart
                                    }
                                }
                            }
                        }

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                if (root.clearButtonConfirmState) {
                                    root.clearRecentEmojis();
                                } else {
                                    root.clearButtonConfirmState = true;
                                }
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Escape) {
                                root.resetClearButton();
                                root.clearButtonFocused = false;
                                searchInput.focusInput();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier)) {
                                root.resetClearButton();
                                root.clearButtonFocused = false;
                                searchInput.focusInput();
                                event.accepted = true;
                            }
                        }
                    }
                }

                // Emoji list (7 filas)
                ListView {
                    id: emojiList
                    width: parent.width
                    height: 7 * 48
                    clip: true
                    cacheBuffer: 96
                    reuseItems: false

                    model: animatedEmojisModel
                    currentIndex: root.selectedIndex
                    
                     property bool enableScrollAnimation: true

                     // Smooth scroll animation
                     Behavior on contentY {
                         enabled: Config.animDuration > 0 && emojiList.enableScrollAnimation
                         NumberAnimation {
                             duration: Config.animDuration / 2
                             easing.type: Easing.OutCubic
                         }
                     }

                      // Smooth animations for filtering
                      displaced: Transition {
                          ParallelAnimation {
                              NumberAnimation {
                                  property: "y"
                                  duration: Config.animDuration > 0 ? Config.animDuration : 0
                                  easing.type: Easing.OutCubic
                              }
                              NumberAnimation {
                                  property: "opacity"
                                  to: 1
                                  duration: Config.animDuration > 0 ? Config.animDuration / 2 : 0
                                  easing.type: Easing.OutCubic
                              }
                          }
                      }

                     add: Transition {
                         ParallelAnimation {
                             NumberAnimation {
                                 property: "opacity"
                                 from: 0
                                 to: 1
                                 duration: Config.animDuration > 0 ? Config.animDuration / 2 : 0
                                 easing.type: Easing.OutCubic
                             }
                             NumberAnimation {
                                 property: "y"
                                 duration: Config.animDuration > 0 ? Config.animDuration : 0
                                 easing.type: Easing.OutCubic
                             }
                         }
                     }

                     remove: Transition {
                         SequentialAnimation {
                             PauseAnimation {
                                 duration: 50
                             }
                             ParallelAnimation {
                                 NumberAnimation {
                                     property: "opacity"
                                     to: 0
                                     duration: Config.animDuration > 0 ? Config.animDuration / 2 : 0
                                     easing.type: Easing.OutCubic
                                 }
                                 NumberAnimation {
                                     property: "height"
                                     to: 0
                                     duration: Config.animDuration > 0 ? Config.animDuration / 2 : 0
                                     easing.type: Easing.OutCubic
                                 }
                             }
                         }
                     }

                    onCurrentIndexChanged: {
                        if (currentIndex !== root.selectedIndex && !root.isRecentFocused) {
                            root.selectedIndex = currentIndex;
                        }
                        
                        // Manual smooth auto-scroll
                        if (currentIndex >= 0 && !root.isRecentFocused) {
                            var itemY = currentIndex * 48;
                            var viewportTop = emojiList.contentY;
                            var viewportBottom = viewportTop + emojiList.height;
                            
                            if (itemY < viewportTop) {
                                // Item is above viewport, scroll up
                                emojiList.contentY = itemY;
                            } else if (itemY + 48 > viewportBottom) {
                                // Item is below viewport, scroll down
                                emojiList.contentY = itemY + 48 - emojiList.height;
                            }
                        }
                    }

                    delegate: Rectangle {
                        required property string emojiId
                        required property var emojiData
                        required property int index

                        property var modelData: emojiData

                        width: emojiList.width
                        height: 48
                        color: "transparent"
                        radius: 16
                        
                        property color textColor: {
                            if (root.selectedIndex === index && !root.isRecentFocused) {
                                return Colors.overPrimary;
                            } else {
                                return Colors.overSurface;
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            preventStealing: false
                            propagateComposedEvents: true

                            onEntered: {
                                if (root.isRecentFocused) {
                                    root.isRecentFocused = false;
                                    root.selectedRecentIndex = -1;
                                    recentList.currentIndex = -1;
                                }
                                root.selectedIndex = index;
                                emojiList.currentIndex = index;
                            }

                            onClicked: {
                                root.copyEmoji(modelData);
                            }
                        }

                        Row {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8

                            StyledRect {
                                id: emojiIconBackground
                                width: emojiIcon.implicitWidth + 6 // Ancho variable basado en el emoji
                                height: 32
                                radius: Config.roundness > 0 ? Math.max(Config.roundness - 4, 0) : 0
                                variant: root.selectedIndex === index && !root.isRecentFocused ? "overprimary" : "common"

                                Text {
                                    id: emojiIcon
                                    anchors.centerIn: parent
                                    color: emojiIconBackground.itemColor
                                    text: modelData.emoji
                                    font.pixelSize: 24
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }

                            Text {
                                width: parent.width - emojiIcon.implicitWidth - 6 - parent.spacing - 16
                                height: parent.height
                                text: modelData.search
                                color: textColor
                                font.family: Config.theme.font
                                font.weight: Font.Bold
                                font.pixelSize: Config.theme.fontSize
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }

                    highlight: Item {
                        width: emojiList.width
                        height: 48
                        
                        // Calculate Y position based on index, not item position
                        y: emojiList.currentIndex * 48
                        
                        Behavior on y {
                            enabled: Config.animDuration > 0
                            NumberAnimation {
                                duration: Config.animDuration / 2
                                easing.type: Easing.OutCubic
                            }
                        }
                        
                        StyledRect {
                            anchors.fill: parent
                            variant: "primary"
                            radius: Config.roundness > 0 ? Config.roundness + 4 : 0
                            visible: root.selectedIndex >= 0 && !root.isRecentFocused
                        }
                    }

                    highlightFollowsCurrentItem: false
                }
                
                // Info text when results are limited
                Text {
                    width: parent.width
                    height: 20
                    visible: searchText.length > 0 && filteredEmojis.length >= maxResults
                    text: `Showing first ${maxResults} results - refine search for more`
                    color: Colors.outline
                    font.family: Config.theme.font
                    font.pixelSize: Math.max(8, Config.theme.fontSize - 3)
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    opacity: 0.7
                }
            }

            // Separator
            Rectangle {
                width: 2
                height: parent.height
                radius: Config.roundness
                color: Colors.surface
            }

            // Recent emojis vertical list
            Item {
                width: LayoutMetrics.calculateRightPanelWidth(parent.height)
                height: parent.height
                visible: recentEmojis.length > 0 && searchText.length === 0

                ListView {
                    id: recentList
                    anchors.fill: parent
                    orientation: ListView.Vertical
                    spacing: 0
                    clip: true
                    cacheBuffer: 96
                    reuseItems: false

                    model: animatedRecentModel
                    currentIndex: root.selectedRecentIndex
                    
                    // Smooth scroll animation
                    Behavior on contentY {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Config.animDuration / 2
                            easing.type: Easing.OutCubic
                        }
                    }

                    // Smooth animations for filtering
                    displaced: Transition {
                        NumberAnimation {
                            properties: "y"
                            duration: Config.animDuration > 0 ? Config.animDuration : 0
                            easing.type: Easing.OutCubic
                        }
                    }

                    add: Transition {
                        ParallelAnimation {
                            NumberAnimation {
                                property: "opacity"
                                from: 0
                                to: 1
                                duration: Config.animDuration > 0 ? Config.animDuration / 2 : 0
                                easing.type: Easing.OutCubic
                            }
                            NumberAnimation {
                                property: "y"
                                duration: Config.animDuration > 0 ? Config.animDuration : 0
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    remove: Transition {
                        SequentialAnimation {
                            PauseAnimation {
                                duration: 50
                            }
                            ParallelAnimation {
                                NumberAnimation {
                                    property: "opacity"
                                    to: 0
                                    duration: Config.animDuration > 0 ? Config.animDuration / 2 : 0
                                    easing.type: Easing.OutCubic
                                }
                                NumberAnimation {
                                    property: "height"
                                    to: 0
                                    duration: Config.animDuration > 0 ? Config.animDuration / 2 : 0
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }

                    onCurrentIndexChanged: {
                        if (currentIndex !== root.selectedRecentIndex && root.isRecentFocused) {
                            root.selectedRecentIndex = currentIndex;
                            root.lastSelectedRecentIndex = currentIndex;
                        }
                        
                        // Manual smooth auto-scroll
                        if (currentIndex >= 0 && root.isRecentFocused) {
                            var itemY = currentIndex * 48;
                            var viewportTop = recentList.contentY;
                            var viewportBottom = viewportTop + recentList.height;
                            
                            if (itemY < viewportTop) {
                                // Item is above viewport, scroll up
                                recentList.contentY = itemY;
                            } else if (itemY + 48 > viewportBottom) {
                                // Item is below viewport, scroll down
                                recentList.contentY = itemY + 48 - recentList.height;
                            }
                        }
                    }

                    delegate: Rectangle {
                        required property string emojiId
                        required property var emojiData
                        required property int index

                        property var modelData: emojiData

                        width: recentList.width
                        height: 48
                        color: "transparent"
                        radius: Config.roundness > 0 ? Math.max(Config.roundness - 4, 0) : 0
                        
                        property color textColor: {
                            if (root.selectedRecentIndex === index && root.isRecentFocused) {
                                return Colors.overPrimary;
                            } else {
                                return Colors.overSurface;
                            }
                        }

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
                            preventStealing: false
                            propagateComposedEvents: true

                            onEntered: {
                                if (!root.isRecentFocused) {
                                    root.isRecentFocused = true;
                                    root.selectedIndex = -1;
                                    emojiList.currentIndex = -1;
                                }
                                root.selectedRecentIndex = index;
                                root.lastSelectedRecentIndex = index;
                                recentList.currentIndex = index;
                            }

                            onClicked: {
                                root.copyEmoji(modelData);
                            }
                        }

                        Row {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8

                            StyledRect {
                                id: recentEmojiIconBackground
                                width: recentEmojiIcon.implicitWidth + 6
                                height: 32
                                radius: Config.roundness > 0 ? Math.max(Config.roundness - 4, 0) : 0
                                variant: root.selectedRecentIndex === index && root.isRecentFocused ? "overprimary" : "common"

                                Text {
                                    id: recentEmojiIcon
                                    anchors.centerIn: parent
                                    color: recentEmojiIconBackground.itemColor
                                    text: modelData.emoji
                                    font.pixelSize: 24
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }

                            Text {
                                width: parent.width - recentEmojiIcon.implicitWidth - 6 - parent.spacing - 16
                                height: parent.height
                                text: modelData.search
                                color: textColor
                                font.family: Config.theme.font
                                font.weight: Font.Bold
                                font.pixelSize: Config.theme.fontSize
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }

                    highlight: Item {
                        width: recentList.width
                        height: 48
                        
                        // Calculate Y position based on index, not item position
                        y: recentList.currentIndex * 48
                        
                        Behavior on y {
                            enabled: Config.animDuration > 0
                            NumberAnimation {
                                duration: Config.animDuration / 2
                                easing.type: Easing.OutCubic
                            }
                        }
                        
                        StyledRect {
                            anchors.fill: parent
                            variant: "primary"
                            radius: Config.roundness > 0 ? Config.roundness + 4 : 0
                            visible: root.isRecentFocused
                        }
                    }

                    highlightFollowsCurrentItem: false
                }
            }

            // Placeholder cuando no hay recientes
            Item {
                width: LayoutMetrics.calculateRightPanelWidth(parent.height)
                height: parent.height
                visible: recentEmojis.length === 0 && searchText.length === 0

                Column {
                    anchors.centerIn: parent
                    spacing: 12

                    Text {
                        text: Icons.countdown
                        font.family: Icons.font
                        font.pixelSize: 48
                        color: Colors.surfaceBright
                        anchors.horizontalCenter: parent.horizontalCenter
                        textFormat: Text.RichText
                    }

                    Text {
                        text: "No recent emojis"
                        font.family: Config.theme.font
                        font.pixelSize: Config.theme.fontSize
                        font.weight: Font.Bold
                        color: Colors.outline
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            Visibilities.setActiveModule("");
            event.accepted = true;
        }
    }

    Component.onCompleted: {
        loadEmojiData();
        loadRecentEmojis();
        Qt.callLater(() => {
            focusSearchInput();
        });
    }

    // MouseArea para mantener el contexto de focus
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: {
            focusSearchInput();
        }
    }
}
