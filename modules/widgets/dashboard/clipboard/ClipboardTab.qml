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
import "clipboard_utils.js" as ClipboardUtils

Item {
    id: root
    focus: true

    // Prefix support
    property string prefixIcon: ""
    signal backspaceOnEmpty

    property int leftPanelWidth: 0

    Keys.onEscapePressed: {
        if (root.deleteMode) {
            root.cancelDeleteMode();
        } else if (root.aliasMode) {
            root.cancelAliasMode();
        } else {
            // Cerrar el dashboard
            Visibilities.setActiveModule("");
        }
    }

    property string searchText: ""
    property bool showResults: searchText.length > 0
    property int selectedIndex: -1
    property var allItems: []
    property bool hasNavigatedFromSearch: false

    // List model
    ListModel {
        id: itemsModel
    }
    property bool clearButtonFocused: false
    property bool clearButtonConfirmState: false
    property bool anyItemDragging: false

    // Delete mode state
    property bool deleteMode: false
    property string itemToDelete: ""
    property int originalSelectedIndex: -1
    property int deleteButtonIndex: 0

    // Alias mode state
    property bool aliasMode: false
    property string itemToAlias: ""
    property string newAlias: ""
    property int aliasSelectedIndex: -1
    property int aliasButtonIndex: 0

    // Track item to restore selection after operations
    property string pendingItemIdToSelect: ""

    // Options menu state (expandable list)
    property int expandedItemIndex: -1
    property int selectedOptionIndex: 0
    property bool keyboardNavigation: false

    onExpandedItemIndexChanged:
    // Close expanded options when selection changes to a different item is handled in onSelectedIndexChanged
    {}

    function adjustScrollForExpandedItem(index) {
        if (index < 0 || index >= itemsModel.count)
            return;

        // Calculate Y position of the item
        var itemY = 0;
        for (var i = 0; i < index; i++) {
            itemY += 48; // All items before are collapsed (base height)
        }

        // Calculate expanded item height
        var itemData = itemsModel.get(index).itemData;
        var optionsCount = 4;
        if (itemData.isFile || itemData.isImage || ClipboardUtils.isUrl(itemData.preview)) {
            optionsCount++;
        }
        var listHeight = 36 * Math.min(3, optionsCount);
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

    property int previewImageSize: 200

    // Track the item ID for which we have loaded content/preview
    // This ensures we never show data from a different item
    property string currentItemId: ""
    property string currentFullContent: ""
    property bool loadingLinkPreview: false
    property int linkPreviewCacheRevision: 0  // Increments when cache updates, triggers favicon rebinding

    // Get the currently selected item (convenience property)
    readonly property var currentSelectedItem: {
        if (selectedIndex < 0 || selectedIndex >= allItems.length)
            return null;
        return allItems[selectedIndex];
    }

    // Check if the loaded content matches the currently selected item
    readonly property bool contentMatchesSelection: {
        if (!currentSelectedItem)
            return false;
        return currentItemId === currentSelectedItem.id;
    }

    // Safe accessor for full content - returns content only if it matches selection
    // Falls back to item.preview if content not yet loaded
    readonly property string safeCurrentContent: {
        if (!currentSelectedItem)
            return "";
        if (contentMatchesSelection && currentFullContent)
            return currentFullContent;
        return currentSelectedItem.preview || "";
    }

    // Get link preview data for the currently selected item from cache
    // Only returns data if we have confirmed the content is for this item
    property var linkPreviewData: {
        var _rev = linkPreviewCacheRevision;  // Depend on cache revision for reactivity

        // Must have a selected item
        if (!currentSelectedItem)
            return null;

        // Must be a text item (not image or file)
        if (currentSelectedItem.isImage || currentSelectedItem.isFile)
            return null;

        // Determine the URL to look up
        var urlToLookup = "";

        // If we have loaded content for THIS item, use it
        if (contentMatchesSelection && currentFullContent) {
            urlToLookup = currentFullContent.trim();
        } else {
            // Otherwise, try item.preview but ONLY if it looks like a complete URL
            // (not truncated - doesn't end with "...")
            var preview = currentSelectedItem.preview || "";
            if (preview && !preview.endsWith("...")) {
                urlToLookup = preview.trim();
            }
        }

        if (!urlToLookup || !ClipboardUtils.isUrl(urlToLookup))
            return null;

        return ClipboardService.linkPreviewCache[urlToLookup] || null;
    }

    // Helper function to get file path from URI
    function getFilePathFromUri(content) {
        if (!content || !content.startsWith("file://"))
            return "";
        return decodeURIComponent(content.substring(7).trim());
    }

    // Helper function to check if file is an image
    function isImageFile(filePath) {
        if (!filePath)
            return false;
        var ext = filePath.split('.').pop().toLowerCase();
        return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg', 'ico'].indexOf(ext) !== -1;
    }

    // Helper function to get icon for item
    function getIconForItem(item) {
        if (!item)
            return Icons.clip;

        // Check if it's a URL (for favicon)
        if (!item.isImage && !item.isFile) {
            var content = item.preview || "";
            if (ClipboardUtils.isUrl(content)) {
                return "link"; // Special marker for URL
            }
        }

        // Default icons
        if (item.isImage)
            return Icons.image;
        if (item.isFile)
            return Icons.file;
        return Icons.clip;
    }

    // Helper function to get favicon URL for item
    // First checks the linkPreviewCache for the best favicon, then uses Google service (PNG) to avoid ICO decode errors
    function getFaviconUrl(item) {
        if (!item || item.isImage || item.isFile)
            return "";
        var content = item.preview || "";
        if (!ClipboardUtils.isUrl(content))
            return "";

        // Check if we have cached link preview data with a favicon
        var trimmedUrl = content.trim();
        var cachedData = ClipboardService.linkPreviewCache[trimmedUrl];
        if (cachedData && cachedData.favicon) {
            return cachedData.favicon;
        }

        // Prefer Google service (PNG) over direct .ico to avoid Qt decode warnings
        return ClipboardUtils.getFaviconFallbackUrl(content);
    }

    // Helper function to get fallback favicon URL (Direct .ico as backup)
    function getFaviconFallbackUrl(item) {
        if (!item || item.isImage || item.isFile)
            return "";
        var content = item.preview || "";
        return ClipboardUtils.getFaviconUrl(content);
    }

    // Helper function to get usable favicon from link preview data
    function getUsableFavicon(faviconUrl) {
        return faviconUrl || "";
    }

    // Helper function to get fallback favicon for link preview
    function getUsableFaviconFallback(originalUrl) {
        return ClipboardUtils.getFaviconFallbackUrl(originalUrl);
    }

    implicitWidth: 400
    implicitHeight: 7 * 48 + 56

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
    }

    onSearchTextChanged: {
        updateFilteredItems();
    }

    function clearSearch() {
        searchText = "";
        selectedIndex = -1;
        hasNavigatedFromSearch = false;
        clearButtonFocused = false;
        clearButtonConfirmState = false;
        searchInput.focusInput();
        updateFilteredItems();
    }

    function resetClearButton() {
        clearButtonConfirmState = false;
    }

    function cancelDeleteModeFromExternal() {
        if (deleteMode) {
            cancelDeleteMode();
        }
        if (aliasMode) {
            cancelAliasMode();
        }
    }

    function enterDeleteMode(itemId) {
        originalSelectedIndex = selectedIndex;
        deleteMode = true;
        itemToDelete = itemId;
        deleteButtonIndex = 0;
        root.forceActiveFocus();
    }

    function cancelDeleteMode() {
        deleteMode = false;
        itemToDelete = "";
        deleteButtonIndex = 0;
        searchInput.focusInput();
        updateFilteredItems();
        selectedIndex = originalSelectedIndex;
        resultsList.currentIndex = originalSelectedIndex;
        originalSelectedIndex = -1;
    }

    function confirmDeleteItem() {
        ClipboardService.deleteItem(itemToDelete);

        deleteMode = false;
        itemToDelete = "";
        deleteButtonIndex = 0;
        originalSelectedIndex = -1;
        selectedIndex = -1;
        hasNavigatedFromSearch = false;

        refreshClipboardHistory();
        searchInput.focusInput();
    }

    function enterAliasMode(itemId) {
        aliasSelectedIndex = selectedIndex;
        aliasMode = true;
        itemToAlias = itemId;

        // Find current alias
        for (var i = 0; i < allItems.length; i++) {
            if (allItems[i].id === itemId) {
                newAlias = allItems[i].alias || allItems[i].preview;
                break;
            }
        }

        aliasButtonIndex = 1;
        root.forceActiveFocus();
    }

    function cancelAliasMode() {
        aliasMode = false;
        itemToAlias = "";
        newAlias = "";
        aliasButtonIndex = 0;
        searchInput.focusInput();
        updateFilteredItems();
        selectedIndex = aliasSelectedIndex;
        resultsList.currentIndex = aliasSelectedIndex;
        aliasSelectedIndex = -1;
    }

    function confirmAliasItem() {
        // Find the original preview to compare
        var originalPreview = "";
        for (var i = 0; i < allItems.length; i++) {
            if (allItems[i].id === itemToAlias) {
                originalPreview = allItems[i].preview;
                break;
            }
        }

        // Mark this item to be selected after refresh
        pendingItemIdToSelect = itemToAlias;

        // Only set alias if different from original preview
        if (newAlias.trim() !== "" && newAlias.trim() !== originalPreview) {
            ClipboardService.setAlias(itemToAlias, newAlias.trim());
        } else if (newAlias.trim() === originalPreview || newAlias.trim() === "") {
            // Clear alias if set back to original or empty
            ClipboardService.setAlias(itemToAlias, "");
        }

        aliasMode = false;
        itemToAlias = "";
        newAlias = "";
        aliasButtonIndex = 0;
        aliasSelectedIndex = -1;
        searchInput.focusInput();
    }

    function clearClipboardHistory() {
        ClipboardService.clear();
        clearButtonConfirmState = false;
        clearButtonFocused = false;
        searchInput.focusInput();
    }

    function focusSearchInput() {
        searchInput.focusInput();
    }

    function updateFilteredItems() {
        // Capture current selection to restore it if possible (handling double updates)
        var currentIdToKeep = "";
        if (selectedIndex >= 0 && selectedIndex < allItems.length) {
            currentIdToKeep = allItems[selectedIndex].id;
        }

        var newItems = [];

        for (var i = 0; i < ClipboardService.items.length; i++) {
            var item = ClipboardService.items[i];
            var content = item.preview || "";
            var alias = item.alias || "";

            // Search in both content and alias
            if (searchText.length === 0 || content.toLowerCase().includes(searchText.toLowerCase()) || alias.toLowerCase().includes(searchText.toLowerCase())) {
                newItems.push(item);
            }
        }

        allItems = newItems;
        // Don't reset scroll or animation state here to prevent jumps during rapid updates

        // Smart sync itemsModel to minimize delegate destruction/creation
        var modelIndex = 0;
        var newIndex = 0;

        while (newIndex < newItems.length) {
            var newItem = newItems[newIndex];
            var newItemId = newItem.id;

            if (modelIndex < itemsModel.count) {
                var currentModelItem = itemsModel.get(modelIndex);

                if (currentModelItem.itemId === newItemId) {
                    // Match found: update data if needed and advance
                    if (currentModelItem.itemData !== newItem) {
                        itemsModel.set(modelIndex, {
                            itemData: newItem
                        });
                    }
                    modelIndex++;
                    newIndex++;
                } else {
                    // Mismatch: check if newItem exists later (move) or is new (insert)
                    var foundLaterIndex = -1;
                    // Limit lookahead to avoid performance hit on large lists, though clipboard is usually small
                    for (var j = modelIndex + 1; j < itemsModel.count; j++) {
                        if (itemsModel.get(j).itemId === newItemId) {
                            foundLaterIndex = j;
                            break;
                        }
                    }

                    if (foundLaterIndex !== -1) {
                        // Found later: move it here
                        itemsModel.move(foundLaterIndex, modelIndex, 1);
                        itemsModel.set(modelIndex, {
                            itemData: newItem
                        });
                        modelIndex++;
                        newIndex++;
                    } else {
                        // Not found later: insert here
                        itemsModel.insert(modelIndex, {
                            itemId: newItemId,
                            itemData: newItem
                        });
                        modelIndex++;
                        newIndex++;
                    }
                }
            } else {
                // End of model: append
                itemsModel.append({
                    itemId: newItemId,
                    itemData: newItem
                });
                modelIndex++;
                newIndex++;
            }
        }

        // Remove excess items at the end
        if (modelIndex < itemsModel.count) {
            var itemsToRemove = itemsModel.count - modelIndex;
            itemsModel.remove(modelIndex, itemsToRemove);
        }

        // Only trigger later scroll animation enable if strictly needed,
        // but since we aren't clearing, we might not need to toggle it at all.

        // If we have a pending item to select (after pin/alias operations), find it
        if (pendingItemIdToSelect !== "") {
            for (var i = 0; i < newItems.length; i++) {
                if (newItems[i].id === pendingItemIdToSelect) {
                    selectedIndex = i;
                    resultsList.currentIndex = i;
                    pendingItemIdToSelect = "";
                    return;
                }
            }
            // If not found, clear the pending selection
            pendingItemIdToSelect = "";
        }

        // Try to maintain current selection if no pending item was forced
        if (currentIdToKeep !== "") {
            for (var i = 0; i < newItems.length; i++) {
                if (newItems[i].id === currentIdToKeep) {
                    selectedIndex = i;
                    resultsList.currentIndex = i;
                    return;
                }
            }
        }

        // Default behavior when no pending item
        if (searchText.length > 0 && allItems.length > 0) {
            // Only force selection to 0 if we were previously unselected or invalid
            if (selectedIndex < 0 || selectedIndex >= allItems.length) {
                selectedIndex = 0;
                resultsList.currentIndex = 0;
            }
        } else if (searchText.length === 0) {
            // When clearing search, only reset if we haven't navigated or if list is empty
            if (!hasNavigatedFromSearch || allItems.length === 0) {
                selectedIndex = -1;
                resultsList.currentIndex = -1;
            } else {
                // Keep current selection valid, or default to first item
                if (selectedIndex >= allItems.length) {
                    selectedIndex = Math.max(0, allItems.length - 1);
                    resultsList.currentIndex = selectedIndex;
                } else if (selectedIndex < 0 && allItems.length > 0) {
                    selectedIndex = 0;
                    resultsList.currentIndex = 0;
                }
            }
        }
    }

    function onDownPressed() {
        if (!root.hasNavigatedFromSearch) {
            root.hasNavigatedFromSearch = true;
            if (resultsList.count > 0) {
                if (root.selectedIndex === -1) {
                    root.selectedIndex = 0;
                    resultsList.currentIndex = 0;
                }
            }
        } else {
            if (resultsList.count > 0 && root.selectedIndex >= 0) {
                if (root.selectedIndex < resultsList.count - 1) {
                    root.selectedIndex++;
                    resultsList.currentIndex = root.selectedIndex;
                }
            }
        }
    }

    function onUpPressed() {
        if (root.selectedIndex > 0) {
            root.selectedIndex--;
            resultsList.currentIndex = root.selectedIndex;
        } else if (root.selectedIndex === 0) {
            root.selectedIndex = -1;
            root.hasNavigatedFromSearch = false;
            resultsList.currentIndex = -1;
        }
    }

    function refreshClipboardHistory() {
        ClipboardService.list();
    }

    function copyToClipboard(itemId) {
        // Find the item to determine its type
        for (var i = 0; i < root.allItems.length; i++) {
            if (root.allItems[i].id === itemId) {
                var item = root.allItems[i];
                if (item.isImage && item.binaryPath) {
                    // Copy image with correct MIME type
                    copyProcess.command = ["sh", "-c", "cat '" + item.binaryPath + "' | wl-copy --type '" + item.mime + "'"];
                } else if (item.isFile) {
                    // Copy file URI with text/uri-list MIME type, removing carriage returns
                    copyProcess.command = ["sh", "-c", "sqlite3 '" + ClipboardService.dbPath + "' \"SELECT full_content FROM clipboard_items WHERE id = " + itemId + ";\" | tr -d '\\r' | wl-copy --type text/uri-list"];
                } else {
                    // Copy text as plain text
                    copyProcess.command = ["sh", "-c", "sqlite3 '" + ClipboardService.dbPath + "' \"SELECT full_content FROM clipboard_items WHERE id = " + itemId + ";\" | wl-copy"];
                }
                copyProcess.running = true;
                break;
            }
        }
    }

    // Signal to request opening an item
    signal requestOpenItem(string itemId, var items, string currentContent, var filePathGetter, var urlChecker)

    function openItem(itemId) {
        requestOpenItem(itemId, root.allItems, root.safeCurrentContent, getFilePathFromUri, ClipboardUtils.isUrl);
    }

    // MouseArea global para detectar clicks en cualquier espacio vacío
    MouseArea {
        anchors.fill: parent
        enabled: root.deleteMode
        z: -10

        onClicked: {
            if (root.deleteMode) {
                root.cancelDeleteMode();
            }
        }
    }

    // Conexiones al servicio
    Connections {
        target: ClipboardService
        function onListCompleted() {
            updateFilteredItems();
        }
    }

    // Conexión para cargar imágenes cuando cambia la selección
    Connections {
        target: root
        function onSelectedIndexChanged() {
            // Reset content state when selection changes
            // Setting currentItemId to "" ensures linkPreviewData won't use stale content
            root.currentItemId = "";
            root.currentFullContent = "";
            root.loadingLinkPreview = false;

            if (root.selectedIndex >= 0 && root.selectedIndex < root.allItems.length) {
                let item = root.allItems[root.selectedIndex];
                if (item.isImage && !ClipboardService.getImageData(item.id)) {
                    ClipboardService.decodeToDataUrl(item.id, item.mime);
                } else if (!item.isImage) {
                    // Obtener contenido completo para texto
                    ClipboardService.getFullContent(item.id);
                }
            }
        }
    }

    // Conexión para recibir el contenido completo
    Connections {
        target: ClipboardService
        function onFullContentRetrieved(itemId, content) {
            // Only update if this is for the currently selected item
            if (root.currentSelectedItem && root.currentSelectedItem.id === itemId) {
                // Set both the item ID and content atomically
                root.currentItemId = itemId;
                root.currentFullContent = content;

                // Si es una URL, obtener preview
                if (ClipboardUtils.isUrl(content)) {
                    root.loadingLinkPreview = true;
                    ClipboardService.fetchLinkPreview(content.trim(), itemId);
                }
            }
        }

        function onLinkPreviewFetched(url, metadata, requestItemId) {
            // Increment cache revision to trigger rebinding of linkPreviewData and favicons
            root.linkPreviewCacheRevision++;

            // Only clear loading state if this response is for the currently selected item
            if (root.currentSelectedItem && root.currentSelectedItem.id === requestItemId) {
                root.loadingLinkPreview = false;
            }
        }
    }

    // Proceso para copiar al portapapeles
    Process {
        id: copyProcess
        running: false

        onExited: function (code) {
        // No cerrar el dashboard después de copiar
        // if (code === 0) {
        //     root.itemSelected();
        // }
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

            // Barra de búsqueda con botón de limpiar
            Row {
                id: searchRow
                width: parent.width
                height: 48
                anchors.top: parent.top
                spacing: 8

                SearchInput {
                    id: searchInput
                    width: parent.width - clearButton.width - parent.spacing
                    height: parent.height
                    text: root.searchText
                    placeholderText: "Search in clipboard..."
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
                            let item = root.allItems[root.expandedItemIndex];
                            if (item) {
                                // Build options array dynamically
                                let options = [function () {
                                        root.copyToClipboard(item.id);
                                        Visibilities.setActiveModule("");
                                    }];

                                // Add Open if applicable
                                if (item.isFile || item.isImage || ClipboardUtils.isUrl(item.preview)) {
                                    options.push(function () {
                                        root.openItem(item.id);
                                    });
                                }

                                options.push(function () {
                                    root.pendingItemIdToSelect = item.id;
                                    ClipboardService.togglePin(item.id);
                                    root.expandedItemIndex = -1;
                                }, function () {
                                    root.enterAliasMode(item.id);
                                    root.expandedItemIndex = -1;
                                }, function () {
                                    root.enterDeleteMode(item.id);
                                    root.expandedItemIndex = -1;
                                });

                                if (root.selectedOptionIndex >= 0 && root.selectedOptionIndex < options.length) {
                                    options[root.selectedOptionIndex]();
                                }
                            }
                        } else {
                            if (root.selectedIndex >= 0 && root.selectedIndex < root.allItems.length) {
                                let selectedItem = root.allItems[root.selectedIndex];
                                if (selectedItem && !root.deleteMode) {
                                    root.copyToClipboard(selectedItem.id);
                                    Visibilities.setActiveModule("");
                                }
                            }
                        }
                    }

                    onShiftAccepted: {
                        if (!root.deleteMode && !root.aliasMode) {
                            if (root.selectedIndex >= 0 && root.selectedIndex < root.allItems.length) {
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

                    onCtrlRPressed: {
                        if (!root.deleteMode && !root.aliasMode && root.selectedIndex >= 0 && root.selectedIndex < root.allItems.length) {
                            let selectedItem = root.allItems[root.selectedIndex];
                            if (selectedItem && !selectedItem.isCreateButton) {
                                root.enterAliasMode(selectedItem.id);
                            }
                        }
                    }

                    onCtrlPPressed: {
                        if (!root.deleteMode && !root.aliasMode && root.selectedIndex >= 0 && root.selectedIndex < root.allItems.length) {
                            let selectedItem = root.allItems[root.selectedIndex];
                            if (selectedItem) {
                                root.pendingItemIdToSelect = selectedItem.id;
                                ClipboardService.togglePin(selectedItem.id);
                            }
                        }
                    }

                    onCtrlUpPressed: {
                        if (!root.deleteMode && !root.aliasMode && root.selectedIndex >= 0 && root.selectedIndex < root.allItems.length) {
                            let selectedItem = root.allItems[root.selectedIndex];
                            if (selectedItem) {
                                root.pendingItemIdToSelect = selectedItem.id;
                                ClipboardService.moveItemUp(selectedItem.id);
                            }
                        }
                    }

                    onCtrlDownPressed: {
                        if (!root.deleteMode && !root.aliasMode && root.selectedIndex >= 0 && root.selectedIndex < root.allItems.length) {
                            let selectedItem = root.allItems[root.selectedIndex];
                            if (selectedItem) {
                                root.pendingItemIdToSelect = selectedItem.id;
                                ClipboardService.moveItemDown(selectedItem.id);
                            }
                        }
                    }

                    onEscapePressed: {
                        if (root.expandedItemIndex >= 0) {
                            root.expandedItemIndex = -1;
                            root.selectedOptionIndex = 0;
                            root.keyboardNavigation = false;
                        } else if (!root.deleteMode) {
                            Visibilities.setActiveModule("");
                        }
                    }

                    onDownPressed: {
                        if (root.expandedItemIndex >= 0) {
                            // Navigate options when menu is expanded - get dynamic count
                            let item = root.allItems[root.expandedItemIndex];
                            if (item) {
                                let maxOptions = 4; // Base: Copy, Pin, Alias, Delete
                                if (item.isFile || item.isImage || ClipboardUtils.isUrl(item.preview)) {
                                    maxOptions++; // Add Open
                                }
                                if (root.selectedOptionIndex < maxOptions - 1) {
                                    root.selectedOptionIndex++;
                                    root.keyboardNavigation = true;
                                }
                            }
                        } else {
                            root.onDownPressed();
                        }
                    }

                    onUpPressed: {
                        if (root.expandedItemIndex >= 0) {
                            // Navigate options when menu is expanded
                            if (root.selectedOptionIndex > 0) {
                                root.selectedOptionIndex--;
                                root.keyboardNavigation = true;
                            }
                            // Stay on first option if already at index 0
                        } else {
                            root.onUpPressed();
                        }
                    }
                }

                // Botón de limpiar historial
                StyledRect {
                    id: clearButton
                    width: root.clearButtonConfirmState ? 120 : 48
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
                                root.clearClipboardHistory();
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
                            text: root.clearButtonConfirmState ? Icons.alert : Icons.trash
                            textFormat: Text.RichText
                            font.family: Icons.font
                            font.pixelSize: 20
                            color: root.clearButtonConfirmState ? clearButton.item : Styling.styledRectItem("overprimary")
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        Text {
                            width: parent.width - 32 - parent.spacing
                            height: parent.height
                            text: "Clear all?"
                            font.family: Config.theme.font
                            font.weight: Font.Bold
                            font.pixelSize: Config.theme.fontSize
                            color: clearButton.item
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
                                root.clearClipboardHistory();
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

            // Lista del clipboard
            Item {
                width: parent.width
                anchors.top: searchRow.bottom
                anchors.bottom: parent.bottom
                anchors.topMargin: 8

                ListView {
                    id: resultsList
                    anchors.fill: parent
                    visible: ClipboardService.items.length > 0
                    clip: true
                    interactive: !root.deleteMode && root.expandedItemIndex === -1
                    cacheBuffer: 96
                    reuseItems: false
                    boundsBehavior: Flickable.StopAtBounds

                    // Propiedad para detectar si está en movimiento (drag o flick)
                    property bool isScrolling: dragging || flicking

                    model: itemsModel
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

                        // Manual smooth auto-scroll (simplified for variable height items)
                        if (currentIndex >= 0) {
                            var itemY = 0;
                            for (var i = 0; i < currentIndex && i < itemsModel.count; i++) {
                                var itemData = itemsModel.get(i).itemData;
                                var itemHeight = 48;
                                if (i === root.expandedItemIndex && !root.deleteMode && !root.aliasMode) {
                                    var optionsCount = 4;
                                    if (itemData.isFile || itemData.isImage || ClipboardUtils.isUrl(itemData.preview)) {
                                        optionsCount++;
                                    }
                                    var listHeight = 36 * Math.min(3, optionsCount);
                                    itemHeight = 48 + 4 + listHeight + 8;
                                }
                                itemY += itemHeight;
                            }

                            var currentItemHeight = 48;
                            if (currentIndex === root.expandedItemIndex && !root.deleteMode && !root.aliasMode && currentIndex < itemsModel.count) {
                                var itemData = itemsModel.get(currentIndex).itemData;
                                var optionsCount = 4;
                                if (itemData.isFile || itemData.isImage || ClipboardUtils.isUrl(itemData.preview)) {
                                    optionsCount++;
                                }
                                var listHeight = 36 * Math.min(3, optionsCount);
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

                    highlight: Item {
                        width: resultsList.width
                        height: {
                            let baseHeight = 48;
                            if (resultsList.currentIndex === root.expandedItemIndex && !root.deleteMode && !root.aliasMode) {
                                var itemData = itemsModel.get(resultsList.currentIndex).itemData;
                                var optionsCount = 4;
                                if (itemData.isFile || itemData.isImage || ClipboardUtils.isUrl(itemData.preview)) {
                                    optionsCount++;
                                }
                                var listHeight = 36 * Math.min(3, optionsCount);
                                return baseHeight + 4 + listHeight + 8;
                            }
                            return baseHeight;
                        }

                        // Calculate Y position based on index, not item position
                        y: {
                            var yPos = 0;
                            for (var i = 0; i < resultsList.currentIndex && i < itemsModel.count; i++) {
                                var itemHeight = 48;
                                if (i === root.expandedItemIndex && !root.deleteMode && !root.aliasMode) {
                                    var itemData = itemsModel.get(i).itemData;
                                    var optionsCount = 4;
                                    if (itemData.isFile || itemData.isImage || ClipboardUtils.isUrl(itemData.preview)) {
                                        optionsCount++;
                                    }
                                    var listHeight = 36 * Math.min(3, optionsCount);
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
                            if (root.expandedItemIndex >= 0 && height > 48) {
                                Qt.callLater(() => {
                                    root.adjustScrollForExpandedItem(root.expandedItemIndex);
                                });
                            }
                        }

                        StyledRect {
                            anchors.fill: parent
                            variant: {
                                if (root.deleteMode) {
                                    return "error";
                                } else if (root.aliasMode) {
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
                        }
                    }

                    highlightFollowsCurrentItem: false

                    delegate: Rectangle {
                        required property string itemId
                        required property var itemData
                        required property int index

                        property var modelData: itemData

                        width: resultsList.width
                        height: {
                            let baseHeight = 48;
                            if (index === root.expandedItemIndex && !isInDeleteMode && !isInAliasMode) {
                                var optionsCount = 4; // Base: Copy, Pin, Alias, Delete
                                if (modelData.isFile || modelData.isImage || ClipboardUtils.isUrl(modelData.preview)) {
                                    optionsCount++; // Add Open
                                }
                                var listHeight = 36 * Math.min(3, optionsCount);
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

                        property bool isInDeleteMode: root.deleteMode && modelData.id === root.itemToDelete
                        property bool isInAliasMode: root.aliasMode && modelData.id === root.itemToAlias
                        property bool isSelected: root.selectedIndex === index
                        property bool isExpanded: index === root.expandedItemIndex
                        property bool isDraggingForReorder: false
                        property color textColor: {
                            if (isInDeleteMode) {
                                return Styling.styledRectItem("error");
                            } else if (isExpanded) {
                                return Styling.styledRectItem("pane");
                            } else if (isSelected) {
                                return Styling.styledRectItem("primary");
                            } else {
                                return Colors.overSurface;
                            }
                        }
                        property string displayText: {
                            if (isInDeleteMode) {
                                let preview = modelData.alias || modelData.preview || "";
                                // Replace newlines with spaces for single-line display
                                preview = preview.replace(/\n/g, ' ').replace(/\r/g, '');
                                return "Delete \"" + preview.substring(0, 20) + (preview.length > 20 ? '...' : '') + "\"?";
                            } else if (modelData.isImage) {
                                return modelData.alias || "Image";
                            } else {
                                let preview = modelData.alias || modelData.preview || "";
                                // Replace newlines with spaces for single-line display
                                return preview.replace(/\n/g, ' ').replace(/\r/g, '');
                            }
                        }

                        MouseArea {
                            id: mouseArea
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            height: isExpanded ? 48 : parent.height
                            hoverEnabled: !isDraggingForReorder && !resultsList.isScrolling
                            enabled: !root.deleteMode && !root.aliasMode
                            acceptedButtons: Qt.LeftButton | Qt.RightButton

                            property real startX: 0
                            property real startY: 0
                            property bool isDragging: false
                            property bool longPressTriggered: false
                            property bool isVerticalDrag: false

                            onEntered: {
                                // Don't change selection if there's an expanded menu open or dragging or scrolling
                                if (!root.deleteMode && root.expandedItemIndex === -1 && !isDraggingForReorder && !resultsList.isScrolling) {
                                    root.selectedIndex = index;
                                    resultsList.currentIndex = index;
                                }
                            }

                            onClicked: mouse => {
                                if (mouse.button === Qt.LeftButton && !isInDeleteMode) {
                                    if (root.deleteMode && modelData.id !== root.itemToDelete) {
                                        root.cancelDeleteMode();
                                        return;
                                    }

                                    if (!root.deleteMode && !isExpanded) {
                                        root.copyToClipboard(modelData.id);
                                        Visibilities.setActiveModule("");
                                    }
                                } else if (mouse.button === Qt.RightButton) {
                                    if (root.deleteMode) {
                                        root.cancelDeleteMode();
                                        return;
                                    }

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

                            onPressed: mouse => {
                                startX = mouse.x;
                                startY = mouse.y;
                                isDragging = false;
                                longPressTriggered = false;
                                isVerticalDrag = false;

                                if (mouse.button !== Qt.RightButton) {
                                    longPressTimer.start();
                                }
                            }

                            onPositionChanged: mouse => {
                                if (pressed && mouse.button !== Qt.RightButton) {
                                    let deltaX = mouse.x - startX;
                                    let deltaY = mouse.y - startY;
                                    let distance = Math.sqrt(deltaX * deltaX + deltaY * deltaY);

                                    if (distance > 10) {
                                        isDragging = true;
                                        longPressTimer.stop();

                                        // Determine drag direction: horizontal (delete) or vertical (reorder)
                                        if (!isVerticalDrag && Math.abs(deltaX) > Math.abs(deltaY)) {
                                            // Horizontal drag for delete
                                            if (deltaX < -50 && Math.abs(deltaY) < 30) {
                                                if (!longPressTriggered) {
                                                    root.enterDeleteMode(modelData.id);
                                                    longPressTriggered = true;
                                                }
                                            }
                                        } else if (Math.abs(deltaY) > Math.abs(deltaX)) {
                                            // Vertical drag for reorder
                                            isVerticalDrag = true;
                                            isDraggingForReorder = true;
                                            root.anyItemDragging = true;

                                            // Calculate target index based on drag position
                                            let itemHeight = 48;
                                            let targetIndex = index;

                                            if (deltaY > itemHeight / 2 && index < root.allItems.length - 1) {
                                                // Check if next item has same pinned status
                                                let nextItem = root.allItems[index + 1];
                                                if (nextItem && nextItem.pinned === modelData.pinned) {
                                                    targetIndex = index + 1;
                                                }
                                            } else if (deltaY < -itemHeight / 2 && index > 0) {
                                                // Check if previous item has same pinned status
                                                let prevItem = root.allItems[index - 1];
                                                if (prevItem && prevItem.pinned === modelData.pinned) {
                                                    targetIndex = index - 1;
                                                }
                                            }

                                            // Visual feedback could be added here
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
                                        let minX = Math.min(idx1X, idx2X) * 36 + activeButtonMargin;
                                        return minX;
                                    }

                                    y: activeButtonMargin

                                    width: {
                                        let stretchX = Math.abs(idx1X - idx2X) * 36 + 32 - activeButtonMargin * 2;
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
                                            onClicked: root.confirmDeleteItem()
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

                            // Alias mode action buttons
                            Rectangle {
                                width: 76
                                height: 36
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                color: "transparent"
                                radius: 6
                                opacity: isInAliasMode ? 1.0 : 0.0
                                visible: opacity > 0

                                transform: Translate {
                                    x: isInAliasMode ? 0 : 80

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
                                    id: aliasHighlight
                                    variant: "oversecondary"
                                    radius: Styling.radius(-4)
                                    visible: isInAliasMode
                                    z: 0

                                    property real activeButtonMargin: 2
                                    property real idx1X: root.aliasButtonIndex
                                    property real idx2X: root.aliasButtonIndex

                                    x: {
                                        let minX = Math.min(idx1X, idx2X) * 36 + activeButtonMargin;
                                        return minX;
                                    }

                                    y: activeButtonMargin

                                    width: {
                                        let stretchX = Math.abs(idx1X - idx2X) * 36 + 32 - activeButtonMargin * 2;
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
                                    id: aliasActionButtons
                                    anchors.fill: parent
                                    spacing: 4

                                    Rectangle {
                                        id: aliasCancelButton
                                        width: 32
                                        height: 32
                                        color: "transparent"
                                        radius: 6
                                        z: 1

                                        property bool isHighlighted: root.aliasButtonIndex === 0

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: root.cancelAliasMode()
                                            onEntered: {
                                                root.aliasButtonIndex = 0;
                                            }
                                            onExited: parent.color = "transparent"
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: Icons.cancel
                                            color: aliasCancelButton.isHighlighted ? Colors.overSecondaryContainer : Colors.overSecondary
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
                                        id: aliasConfirmButton
                                        width: 32
                                        height: 32
                                        color: "transparent"
                                        radius: 6
                                        z: 1

                                        property bool isHighlighted: root.aliasButtonIndex === 1

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: root.confirmAliasItem()
                                            onEntered: {
                                                root.aliasButtonIndex = 1;
                                            }
                                            onExited: parent.color = "transparent"
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: Icons.accept
                                            color: aliasConfirmButton.isHighlighted ? Colors.overSecondaryContainer : Colors.overSecondary
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

                            onReleased: mouse => {
                                longPressTimer.stop();

                                // Handle reorder on release if vertical drag occurred
                                if (isVerticalDrag && isDraggingForReorder) {
                                    let deltaY = mouse.y - startY;
                                    let itemHeight = 48;

                                    if (Math.abs(deltaY) > itemHeight / 2) {
                                        if (deltaY > 0 && index < root.allItems.length - 1) {
                                            // Dragged down
                                            let nextItem = root.allItems[index + 1];
                                            if (nextItem && nextItem.pinned === modelData.pinned) {
                                                root.pendingItemIdToSelect = modelData.id;
                                                ClipboardService.moveItemDown(modelData.id);
                                            }
                                        } else if (deltaY < 0 && index > 0) {
                                            // Dragged up
                                            let prevItem = root.allItems[index - 1];
                                            if (prevItem && prevItem.pinned === modelData.pinned) {
                                                root.pendingItemIdToSelect = modelData.id;
                                                ClipboardService.moveItemUp(modelData.id);
                                            }
                                        }
                                    }
                                }

                                isDragging = false;
                                longPressTriggered = false;
                                isVerticalDrag = false;
                                isDraggingForReorder = false;
                                root.anyItemDragging = false;
                            }

                            Timer {
                                id: longPressTimer
                                interval: 800
                                repeat: false
                                onTriggered: {
                                    if (!mouseArea.isDragging) {
                                        root.copyToClipboard(modelData.id);
                                        Visibilities.setActiveModule("");
                                        mouseArea.longPressTriggered = true;
                                    }
                                }
                            }
                        }

                        // Expandable options list (similar to SchemeSelector/FullPlayer)
                        RowLayout {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            anchors.bottomMargin: 8
                            spacing: 4
                            visible: isExpanded && !isInDeleteMode && !isInAliasMode
                            opacity: (isExpanded && !isInDeleteMode && !isInAliasMode) ? 1 : 0

                            Behavior on opacity {
                                enabled: Config.animDuration > 0
                                NumberAnimation {
                                    duration: Config.animDuration
                                    easing.type: Easing.OutQuart
                                }
                            }

                            ClippingRectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: {
                                    var count = 4; // Copy, Pin, Alias, Delete
                                    if (modelData.isFile || ClipboardUtils.isUrl(modelData.preview)) {
                                        count++; // Add Open
                                    }
                                    return 36 * Math.min(3, count);
                                }
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
                                    interactive: true
                                    boundsBehavior: Flickable.StopAtBounds

                                    // Propiedad para detectar si está en movimiento
                                    property bool isScrolling: dragging || flicking

                                    model: {
                                        var options = [
                                            {
                                                text: "Copy",
                                                icon: Icons.copy,
                                                highlightColor: Styling.styledRectItem("overprimary"),
                                                textColor: Styling.styledRectItem("primary"),
                                                action: function () {
                                                    root.copyToClipboard(modelData.id);
                                                    Visibilities.setActiveModule("");
                                                }
                                            }
                                        ];

                                        // Add Open option for files, images, and URLs
                                        if (modelData.isFile || modelData.isImage || ClipboardUtils.isUrl(modelData.preview)) {
                                            options.push({
                                                text: "Open",
                                                icon: Icons.popOpen,
                                                highlightColor: Styling.styledRectItem("overprimary"),
                                                textColor: Styling.styledRectItem("primary"),
                                                action: function () {
                                                    root.openItem(modelData.id);
                                                }
                                            });
                                        }

                                        options.push({
                                            text: modelData.pinned ? "Unpin" : "Pin",
                                            icon: modelData.pinned ? Icons.unpin : Icons.pin,
                                            highlightColor: Styling.styledRectItem("overprimary"),
                                            textColor: Styling.styledRectItem("primary"),
                                            action: function () {
                                                root.pendingItemIdToSelect = modelData.id;
                                                ClipboardService.togglePin(modelData.id);
                                                root.expandedItemIndex = -1;
                                            }
                                        }, {
                                            text: "Alias",
                                            icon: Icons.edit,
                                            highlightColor: Colors.secondary,
                                            textColor: Styling.styledRectItem("secondary"),
                                            action: function () {
                                                root.enterAliasMode(modelData.id);
                                                root.expandedItemIndex = -1;
                                            }
                                        }, {
                                            text: "Delete",
                                            icon: Icons.trash,
                                            highlightColor: Colors.error,
                                            textColor: Styling.styledRectItem("error"),
                                            action: function () {
                                                root.enterDeleteMode(modelData.id);
                                                root.expandedItemIndex = -1;
                                            }
                                        });

                                        return options;
                                    }
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
                                                hoverEnabled: !optionsListView.isScrolling
                                                cursorShape: Qt.PointingHandCursor

                                                onEntered: {
                                                    if (optionsListView.isScrolling)
                                                        return;
                                                    optionsListView.currentIndex = index;
                                                    root.selectedOptionIndex = index;
                                                    root.keyboardNavigation = false;
                                                }

                                                onClicked: {
                                                    if (optionsListView.isScrolling)
                                                        return;
                                                    if (modelData && modelData.action) {
                                                        modelData.action();
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // MouseArea to handle wheel events for scrolling
                                MouseArea {
                                    anchors.fill: parent
                                    propagateComposedEvents: true
                                    acceptedButtons: Qt.NoButton

                                    onWheel: wheel => {
                                        if (optionsListView.contentHeight > optionsListView.height) {
                                            const delta = wheel.angleDelta.y;
                                            optionsListView.contentY = Math.max(0, Math.min(optionsListView.contentHeight - optionsListView.height, optionsListView.contentY - delta));
                                            wheel.accepted = true;
                                        } else {
                                            wheel.accepted = false;
                                        }
                                    }
                                }
                            }

                            ScrollBar {
                                Layout.preferredWidth: 8
                                Layout.preferredHeight: {
                                    var count = 4;
                                    if (modelData.isFile || modelData.isImage || ClipboardUtils.isUrl(modelData.preview)) {
                                        count++;
                                    }
                                    var listHeight = 36 * Math.min(3, count);
                                    return Math.max(0, listHeight - 32);
                                }
                                Layout.alignment: Qt.AlignVCenter
                                orientation: Qt.Vertical
                                visible: {
                                    var count = 4;
                                    if (modelData.isFile || modelData.isImage || ClipboardUtils.isUrl(modelData.preview)) {
                                        count++;
                                    }
                                    return count > 3;
                                }

                                position: optionsListView.contentY / optionsListView.contentHeight
                                size: optionsListView.height / optionsListView.contentHeight

                                background: Rectangle {
                                    color: Colors.background
                                    radius: Styling.radius(0)
                                }

                                contentItem: Rectangle {
                                    color: Styling.styledRectItem("overprimary")
                                    radius: Styling.radius(0)
                                }

                                property bool scrollBarPressed: false

                                onPressedChanged: {
                                    scrollBarPressed = pressed;
                                }

                                onPositionChanged: {
                                    if (scrollBarPressed && optionsListView.contentHeight > optionsListView.height) {
                                        optionsListView.contentY = position * optionsListView.contentHeight;
                                    }
                                }
                            }
                        }

                        RowLayout {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 8
                            anchors.rightMargin: {
                                if (isInDeleteMode)
                                    return 84;
                                if (isInAliasMode)
                                    return 84;
                                return 8;
                            }
                            height: 32
                            spacing: 8

                            Behavior on anchors.rightMargin {
                                enabled: Config.animDuration > 0
                                NumberAnimation {
                                    duration: Config.animDuration
                                    easing.type: Easing.OutQuart
                                }
                            }

                            Item {
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
                                Layout.alignment: Qt.AlignTop

                                StyledRect {
                                    id: iconBackground
                                    anchors.fill: parent
                                    visible: !faviconImage.visible
                                    variant: {
                                        if (isInDeleteMode) {
                                            return "overerror";
                                        } else if (isInAliasMode) {
                                            return "oversecondary";
                                        } else if (isExpanded) {
                                            return "primary";
                                        } else if (isSelected) {
                                            return "overprimary";
                                        } else {
                                            return "common";
                                        }
                                    }
                                    radius: Styling.radius(-4)

                                    property string iconType: {
                                        if (isInDeleteMode) {
                                            return "trash";
                                        } else if (isInAliasMode) {
                                            return "edit";
                                        }
                                        return root.getIconForItem(modelData);
                                    }

                                    property string faviconUrl: {
                                        // Depend on cache revision to rebind when new previews are fetched
                                        var _rev = root.linkPreviewCacheRevision;
                                        if (iconType !== "link")
                                            return "";
                                        var url = root.getFaviconUrl(modelData);
                                        return (url && url !== "") ? url : "";
                                    }

                                    property string faviconFallbackUrl: {
                                        if (iconType !== "link")
                                            return "";
                                        return root.getFaviconFallbackUrl(modelData);
                                    }

                                    property bool faviconLoaded: false
                                    property bool triedFallback: false

                                    // Update favicon when URL changes (e.g., from cache update)
                                    onFaviconUrlChanged: {
                                        if (faviconUrl !== "" && faviconUrl !== faviconImage.source) {
                                            faviconLoaded = false;
                                            triedFallback = false;
                                            faviconImage.source = faviconUrl;
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: (iconBackground.iconType !== "link") || (iconBackground.iconType === "link" && !iconBackground.faviconLoaded)
                                        text: {
                                            if (isInDeleteMode) {
                                                return Icons.trash;
                                            } else if (isInAliasMode) {
                                                return Icons.edit;
                                            }
                                            var iconStr = iconBackground.iconType;
                                            // Fallback to Icons object
                                            if (iconStr === "image")
                                                return Icons.image;
                                            if (iconStr === "file")
                                                return Icons.file;
                                            if (iconStr === "link")
                                                return Icons.globe; // Fallback for URLs (failed favicon or no favicon)
                                            return Icons.clip;
                                        }
                                        color: iconBackground.item
                                        font.family: Icons.font
                                        font.pixelSize: 16
                                        textFormat: Text.RichText
                                    }
                                }

                                // Favicon for URLs (now outside StyledRect for independent sizing/background)
                                Image {
                                    id: faviconImage
                                    anchors.fill: parent
                                    sourceSize.width: 32
                                    sourceSize.height: 32
                                    visible: iconBackground.iconType === "link" && iconBackground.faviconLoaded && status === Image.Ready
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    cache: true

                                    onStatusChanged: {
                                        if (status === Image.Ready) {
                                            iconBackground.faviconLoaded = true;
                                        } else if (status === Image.Error) {
                                            // Try fallback URL if not already tried
                                            if (!iconBackground.triedFallback && iconBackground.faviconFallbackUrl !== "") {
                                                iconBackground.triedFallback = true;
                                                faviconImage.source = iconBackground.faviconFallbackUrl;
                                            } else {
                                                iconBackground.faviconLoaded = false;
                                            }
                                        } else if (status === Image.Null || status === Image.Loading) {
                                            iconBackground.faviconLoaded = false;
                                        }
                                    }
                                }

                                Timer {
                                    id: faviconLoader
                                    interval: 1
                                    running: iconBackground.iconType === "link" && iconBackground.faviconUrl !== "" && faviconImage.source === ""
                                    onTriggered: {
                                        if (iconBackground.faviconUrl !== "") {
                                            iconBackground.triedFallback = false;
                                            faviconImage.source = iconBackground.faviconUrl;
                                        }
                                    }
                                }

                                // Pin indicator badge (outside StyledRect to avoid clipping)
                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.topMargin: -2
                                    anchors.rightMargin: -2
                                    width: 14
                                    height: 14
                                    radius: 7
                                    visible: modelData.pinned && !isInDeleteMode && !isInAliasMode
                                    color: Styling.styledRectItem("overprimary")

                                    Text {
                                        anchors.centerIn: parent
                                        text: Icons.pin
                                        font.family: Icons.font
                                        font.pixelSize: 8
                                        color: Colors.overPrimary
                                        textFormat: Text.RichText
                                    }
                                }
                            }

                            Column {
                                Layout.fillWidth: true
                                spacing: 0

                                Loader {
                                    width: parent.width
                                    sourceComponent: {
                                        if (root.aliasMode && modelData.id === root.itemToAlias) {
                                            return aliasTextInput;
                                        } else {
                                            return normalText;
                                        }
                                    }
                                }

                                Component {
                                    id: normalText
                                    Text {
                                        width: parent.width
                                        text: displayText
                                        color: textColor
                                        font.family: Config.theme.font
                                        font.pixelSize: Config.theme.fontSize
                                        font.weight: Font.Bold
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                        wrapMode: Text.NoWrap
                                    }
                                }

                                Component {
                                    id: aliasTextInput
                                    TextField {
                                        text: root.newAlias
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
                                            root.newAlias = text;
                                        }

                                        Component.onCompleted: {
                                            Qt.callLater(() => {
                                                forceActiveFocus();
                                                selectAll();
                                            });
                                        }

                                        Keys.onPressed: event => {
                                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                                root.confirmAliasItem();
                                                event.accepted = true;
                                            } else if (event.key === Qt.Key_Escape) {
                                                root.cancelAliasMode();
                                                event.accepted = true;
                                            } else if (event.key === Qt.Key_Left) {
                                                root.aliasButtonIndex = 0;
                                                event.accepted = true;
                                            } else if (event.key === Qt.Key_Right) {
                                                root.aliasButtonIndex = 1;
                                                event.accepted = true;
                                            }
                                        }
                                    }
                                }

                                Text {
                                    width: parent.width
                                    text: {
                                        if (!modelData.createdAt)
                                            return "";
                                        var date = new Date(modelData.createdAt);
                                        var now = new Date();
                                        var diffMs = now - date;
                                        var diffSecs = Math.floor(diffMs / 1000);
                                        var diffMins = Math.floor(diffSecs / 60);
                                        var diffHours = Math.floor(diffMins / 60);
                                        var diffDays = Math.floor(diffHours / 24);

                                        if (diffMins < 1)
                                            return "Just now";
                                        if (diffMins < 60)
                                            return diffMins + " min ago";
                                        if (diffHours < 24)
                                            return diffHours + " hour" + (diffHours > 1 ? "s" : "") + " ago";
                                        if (diffDays < 7)
                                            return diffDays + " day" + (diffDays > 1 ? "s" : "") + " ago";

                                        return Qt.formatDateTime(date, "MMM dd, yyyy");
                                    }
                                    color: {
                                        if (isInDeleteMode) {
                                            return Colors.overError;
                                        } else if (isExpanded) {
                                            return Colors.overBackground;
                                        } else if (isSelected) {
                                            return Styling.styledRectItem("primary");
                                        } else {
                                            return Colors.outline;
                                        }
                                    }
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-2)
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                    wrapMode: Text.NoWrap
                                    opacity: 0.8

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

                MouseArea {
                    anchors.fill: resultsList
                    enabled: root.deleteMode || root.expandedItemIndex >= 0
                    z: 1000
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    function isClickInsideActiveItem(mouseY) {
                        var activeIndex = -1;
                        var isExpanded = false;

                        if (root.deleteMode || root.aliasMode) {
                            activeIndex = root.selectedIndex;
                            // In delete/alias mode, height is always base height (48)
                        } else if (root.expandedItemIndex >= 0) {
                            activeIndex = root.expandedItemIndex;
                            isExpanded = true;
                        }

                        if (activeIndex < 0)
                            return false;

                        // Calculate Y position of the item
                        var itemY = activeIndex * 48;

                        // Calculate item height
                        var itemHeight = 48;
                        if (isExpanded) {
                            var itemData = itemsModel.get(activeIndex).itemData;
                            var optionsCount = 4;
                            if (itemData.isFile || itemData.isImage || ClipboardUtils.isUrl(itemData.preview)) {
                                optionsCount++;
                            }
                            var listHeight = 36 * Math.min(3, optionsCount);
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
                        } else if (root.expandedItemIndex >= 0) {
                            if (!isClickInsideActiveItem(mouse.y)) {
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

                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    visible: ClipboardService.items.length === 0

                    Text {
                        text: Icons.clipboard
                        font.family: Icons.font
                        font.pixelSize: 48
                        color: Colors.surfaceBright
                        anchors.horizontalCenter: parent.horizontalCenter
                        textFormat: Text.RichText
                    }

                    Text {
                        text: "No clipboard history"
                        font.family: Config.theme.font
                        font.pixelSize: Config.theme.fontSize
                        font.weight: Font.Bold
                        color: Colors.overBackground
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        text: "Copy something to get started"
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-2)
                        color: Colors.outline
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
        }

        Separator {
            vert: true
        }

        // Preview panel (toda la altura, resto del ancho)
        Item {
            id: previewPanel
            Layout.fillWidth: true
            Layout.fillHeight: true

            property var currentItem: root.selectedIndex >= 0 && root.selectedIndex < root.allItems.length ? root.allItems[root.selectedIndex] : null

            // Content when item is selected
            Item {
                anchors.fill: parent
                visible: previewPanel.currentItem

                // Preview area
                Item {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: separator.top
                    anchors.bottomMargin: 8

                    // Preview para imagen estática
                    Image {
                        id: previewImage
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectFit
                        visible: previewPanel.currentItem && (previewPanel.currentItem.isImage || isImageFile) && !isGifImage
                        source: {
                            if (previewPanel.currentItem) {
                                if (previewPanel.currentItem.isImage && !isGifImage) {
                                    ClipboardService.revision;
                                    return ClipboardService.getImageData(previewPanel.currentItem.id);
                                } else if (isImageFile && !isGifImage) {
                                    var content = root.safeCurrentContent;
                                    var filePath = root.getFilePathFromUri(content);
                                    return filePath ? "file://" + filePath : "";
                                }
                            }
                            return "";
                        }
                        clip: true
                        cache: false
                        asynchronous: true

                        property bool isImageFile: {
                            if (!previewPanel.currentItem || !previewPanel.currentItem.isFile)
                                return false;
                            var content = root.safeCurrentContent;
                            var filePath = root.getFilePathFromUri(content);
                            return root.isImageFile(filePath);
                        }

                        property bool isGifImage: {
                            if (!previewPanel.currentItem)
                                return false;
                            // Check direct image mime type
                            if (previewPanel.currentItem.mime === "image/gif")
                                return true;
                            // Check file extension for text/uri-list
                            if (previewPanel.currentItem.isFile) {
                                var content = root.safeCurrentContent;
                                var filePath = root.getFilePathFromUri(content);
                                if (filePath) {
                                    var ext = filePath.split('.').pop().toLowerCase();
                                    return ext === "gif";
                                }
                            }
                            return false;
                        }
                    }

                    // Preview para GIF animado
                    AnimatedImage {
                        id: previewGif
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectFit
                        visible: previewPanel.currentItem && (previewPanel.currentItem.isImage || isImageFile) && isGifImage
                        source: {
                            if (previewPanel.currentItem && isGifImage) {
                                if (previewPanel.currentItem.isImage) {
                                    ClipboardService.revision;
                                    return ClipboardService.getImageData(previewPanel.currentItem.id);
                                } else if (isImageFile) {
                                    var content = root.safeCurrentContent;
                                    var filePath = root.getFilePathFromUri(content);
                                    return filePath ? "file://" + filePath : "";
                                }
                            }
                            return "";
                        }
                        clip: true
                        cache: false
                        asynchronous: true
                        playing: true

                        property bool isImageFile: {
                            if (!previewPanel.currentItem || !previewPanel.currentItem.isFile)
                                return false;
                            var content = root.safeCurrentContent;
                            var filePath = root.getFilePathFromUri(content);
                            return root.isImageFile(filePath);
                        }

                        property bool isGifImage: {
                            if (!previewPanel.currentItem)
                                return false;
                            // Check direct image mime type
                            if (previewPanel.currentItem.mime === "image/gif")
                                return true;
                            // Check file extension for text/uri-list
                            if (previewPanel.currentItem.isFile) {
                                var content = root.safeCurrentContent;
                                var filePath = root.getFilePathFromUri(content);
                                if (filePath) {
                                    var ext = filePath.split('.').pop().toLowerCase();
                                    return ext === "gif";
                                }
                            }
                            return false;
                        }
                    }

                    // Placeholder cuando la imagen no está lista
                    Rectangle {
                        anchors.centerIn: parent
                        width: 120
                        height: 120
                        color: Colors.surfaceBright
                        radius: Styling.radius(4)
                        visible: {
                            if (!previewPanel.currentItem)
                                return false;
                            var isImg = previewPanel.currentItem.isImage || previewImage.isImageFile || previewGif.isImageFile;
                            if (!isImg)
                                return false;

                            if (previewImage.visible) {
                                return previewImage.status !== Image.Ready;
                            } else if (previewGif.visible) {
                                return previewGif.status !== AnimatedImage.Ready;
                            }
                            return false;
                        }

                        Text {
                            anchors.centerIn: parent
                            text: Icons.image
                            textFormat: Text.RichText
                            font.family: Icons.font
                            font.pixelSize: 48
                            color: Styling.styledRectItem("overprimary")
                        }
                    }

                    // Preview para texto con scroll
                    Flickable {
                        anchors.fill: parent
                        visible: previewPanel.currentItem && !previewPanel.currentItem.isImage && !previewPanel.currentItem.isFile
                        clip: true
                        contentWidth: width
                        contentHeight: textPreviewColumn.height
                        boundsBehavior: Flickable.StopAtBounds

                        Column {
                            id: textPreviewColumn
                            width: parent.width
                            spacing: 12

                            // Link embed preview (Discord-style)
                            Rectangle {
                                width: parent.width
                                height: {
                                    // For videos (YouTube), use a larger layout
                                    if (root.linkPreviewData && root.linkPreviewData.type === 'video' && root.linkPreviewData.image) {
                                        return videoEmbedContent.height + 24;
                                    }
                                    return linkEmbedContent.height + 24;
                                }
                                visible: root.linkPreviewData && !root.linkPreviewData.error && (root.linkPreviewData.title || root.linkPreviewData.description || root.linkPreviewData.image)
                                color: linkPreviewMouseArea.containsMouse ? Colors.surfaceBright : Colors.surface

                                // Rounded corners only on the right side
                                topLeftRadius: 0
                                topRightRadius: Config.roundness > 0 ? Config.roundness + 4 : 0
                                bottomLeftRadius: 0
                                bottomRightRadius: Config.roundness > 0 ? Config.roundness + 4 : 0

                                Behavior on color {
                                    enabled: Config.animDuration > 0
                                    ColorAnimation {
                                        duration: Config.animDuration / 2
                                        easing.type: Easing.OutQuart
                                    }
                                }

                                MouseArea {
                                    id: linkPreviewMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        if (root.safeCurrentContent) {
                                            Qt.openUrlExternally(root.safeCurrentContent.trim());
                                        }
                                    }
                                }

                                // Left accent bar
                                Rectangle {
                                    x: 0
                                    y: 0
                                    width: 4
                                    height: parent.height
                                    color: Styling.styledRectItem("overprimary")

                                    // Rounded corners only on the left side
                                    topLeftRadius: Config.roundness > 0 ? Config.roundness + 4 : 0
                                    topRightRadius: 0
                                    bottomLeftRadius: Config.roundness > 0 ? Config.roundness + 4 : 0
                                    bottomRightRadius: 0
                                }

                                // Video embed layout (YouTube, etc.)
                                Column {
                                    id: videoEmbedContent
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 12
                                    anchors.leftMargin: 16
                                    spacing: 10
                                    visible: root.linkPreviewData && root.linkPreviewData.type === 'video'

                                    // Site name with favicon
                                    Row {
                                        width: parent.width
                                        spacing: 8
                                        visible: root.linkPreviewData && root.linkPreviewData.site_name

                                        Item {
                                            width: 16
                                            height: 16
                                            visible: videoFaviconPrimary.status === Image.Ready || videoFaviconFallback.status === Image.Ready

                                            property bool triedFallback: false

                                            Image {
                                                id: videoFaviconPrimary
                                                anchors.fill: parent
                                                sourceSize.width: 40
                                                sourceSize.height: 40
                                                source: root.linkPreviewData && root.linkPreviewData.favicon ? root.getUsableFavicon(root.linkPreviewData.favicon) : ""
                                                fillMode: Image.PreserveAspectFit
                                                asynchronous: true
                                                cache: true
                                                visible: status === Image.Ready

                                                onStatusChanged: {
                                                    if (status === Image.Error && !parent.triedFallback) {
                                                        parent.triedFallback = true;
                                                    }
                                                }
                                            }

                                            Image {
                                                id: videoFaviconFallback
                                                anchors.fill: parent
                                                sourceSize.width: 40
                                                sourceSize.height: 40
                                                source: parent.triedFallback && root.safeCurrentContent ? root.getUsableFaviconFallback(root.safeCurrentContent) : ""
                                                fillMode: Image.PreserveAspectFit
                                                asynchronous: true
                                                cache: true
                                                visible: parent.triedFallback && status === Image.Ready && videoFaviconPrimary.status !== Image.Ready
                                            }
                                        }

                                        Text {
                                            text: root.linkPreviewData ? root.linkPreviewData.site_name : ""
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(-2)
                                            font.weight: Font.Medium
                                            color: Colors.outline
                                            elide: Text.ElideRight
                                            width: parent.width - 24
                                        }
                                    }

                                    // Video thumbnail with play overlay
                                    ClippingRectangle {
                                        id: videoThumbnailContainer
                                        width: parent.width
                                        height: width * 9 / 16  // 16:9 aspect ratio
                                        color: Colors.surfaceBright
                                        radius: Styling.radius(-4)
                                        visible: root.linkPreviewData && root.linkPreviewData.image

                                        Image {
                                            id: videoThumbnail
                                            anchors.fill: parent
                                            source: root.linkPreviewData && root.linkPreviewData.image ? root.linkPreviewData.image : ""
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            cache: true
                                            smooth: true

                                            // Dark overlay
                                            Rectangle {
                                                anchors.fill: parent
                                                color: "#40000000"
                                                radius: videoThumbnailContainer.radius
                                            }

                                            // Play button overlay
                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: 60
                                                height: 60
                                                radius: 30
                                                color: Styling.styledRectItem("overprimary")
                                                opacity: 0.9

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: Icons.play
                                                    font.family: Icons.font
                                                    font.pixelSize: 28
                                                    color: Colors.overPrimary
                                                    textFormat: Text.RichText
                                                }
                                            }

                                            // Loading indicator
                                            Rectangle {
                                                id: imageLoadingRect
                                                anchors.fill: parent
                                                color: Colors.surfaceBright
                                                radius: videoThumbnailContainer.radius
                                                visible: parent.status === Image.Loading

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: Icons.spinnerGap
                                                    font.family: Icons.font
                                                    font.pixelSize: 32
                                                    color: Styling.styledRectItem("overprimary")
                                                    textFormat: Text.RichText

                                                    RotationAnimator on rotation {
                                                        from: 0
                                                        to: 360
                                                        duration: 1000
                                                        loops: Animation.Infinite
                                                        running: imageLoadingRect.visible
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Title
                                    Text {
                                        width: parent.width
                                        text: root.linkPreviewData && root.linkPreviewData.title ? root.linkPreviewData.title : ""
                                        font.family: Config.theme.font
                                        font.pixelSize: Config.theme.fontSize + 1
                                        font.weight: Font.Bold
                                        color: Colors.overBackground
                                        wrapMode: Text.Wrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                        visible: text.length > 0
                                    }

                                    // Author/Description
                                    Text {
                                        width: parent.width
                                        text: root.linkPreviewData && root.linkPreviewData.description ? root.linkPreviewData.description : ""
                                        font.family: Config.theme.font
                                        font.pixelSize: Config.theme.fontSize
                                        color: Colors.outline
                                        wrapMode: Text.Wrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                        visible: text.length > 0
                                    }
                                }

                                // Regular link embed layout
                                Row {
                                    id: linkEmbedContent
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 12
                                    anchors.leftMargin: 16
                                    spacing: 12
                                    visible: !root.linkPreviewData || root.linkPreviewData.type !== 'video'

                                    // Text content column
                                    Column {
                                        width: root.linkPreviewData && root.linkPreviewData.image ? parent.width - 100 - parent.spacing : parent.width
                                        spacing: 6

                                        // Site name with favicon
                                        Row {
                                            width: parent.width
                                            spacing: 8
                                            visible: root.linkPreviewData && root.linkPreviewData.site_name

                                            Item {
                                                width: 16
                                                height: 16
                                                visible: linkFaviconPrimary.status === Image.Ready || linkFaviconFallback.status === Image.Ready

                                                property bool triedFallback: false

                                                Image {
                                                    id: linkFaviconPrimary
                                                    anchors.fill: parent
                                                    sourceSize.width: 40
                                                    sourceSize.height: 40
                                                    source: root.linkPreviewData && root.linkPreviewData.favicon ? root.getUsableFavicon(root.linkPreviewData.favicon) : ""
                                                    fillMode: Image.PreserveAspectFit
                                                    asynchronous: true
                                                    cache: true
                                                    visible: status === Image.Ready

                                                    onStatusChanged: {
                                                        if (status === Image.Error && !parent.triedFallback) {
                                                            parent.triedFallback = true;
                                                        }
                                                    }
                                                }

                                                Image {
                                                    id: linkFaviconFallback
                                                    anchors.fill: parent
                                                    sourceSize.width: 40
                                                    sourceSize.height: 40
                                                    source: parent.triedFallback && root.safeCurrentContent ? root.getUsableFaviconFallback(root.safeCurrentContent) : ""
                                                    fillMode: Image.PreserveAspectFit
                                                    asynchronous: true
                                                    cache: true
                                                    visible: parent.triedFallback && status === Image.Ready && linkFaviconPrimary.status !== Image.Ready
                                                }
                                            }

                                            Text {
                                                text: root.linkPreviewData ? root.linkPreviewData.site_name : ""
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(-2)
                                                font.weight: Font.Medium
                                                color: Colors.outline
                                                elide: Text.ElideRight
                                                width: parent.width - 24
                                            }
                                        }

                                        // Title
                                        Text {
                                            width: parent.width
                                            text: root.linkPreviewData && root.linkPreviewData.title ? root.linkPreviewData.title : ""
                                            font.family: Config.theme.font
                                            font.pixelSize: Config.theme.fontSize + 1
                                            font.weight: Font.Bold
                                            color: Colors.overBackground
                                            wrapMode: Text.Wrap
                                            maximumLineCount: 2
                                            elide: Text.ElideRight
                                            visible: text.length > 0
                                        }

                                        // Description
                                        Text {
                                            width: parent.width
                                            text: root.linkPreviewData && root.linkPreviewData.description ? root.linkPreviewData.description : ""
                                            font.family: Config.theme.font
                                            font.pixelSize: Config.theme.fontSize
                                            color: Colors.outline
                                            wrapMode: Text.Wrap
                                            maximumLineCount: 3
                                            elide: Text.ElideRight
                                            visible: text.length > 0
                                        }
                                    }

                                    // Preview image (thumbnail)
                                    Rectangle {
                                        id: linkThumbnailContainer
                                        width: 100
                                        height: 100
                                        color: Colors.surfaceBright
                                        radius: Styling.radius(-4)
                                        visible: root.linkPreviewData && root.linkPreviewData.image
                                        anchors.verticalCenter: parent.verticalCenter

                                        Image {
                                            anchors.fill: parent
                                            source: root.linkPreviewData && root.linkPreviewData.image ? root.linkPreviewData.image : ""
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            cache: true
                                            smooth: true

                                            Rectangle {
                                                anchors.fill: parent
                                                color: Colors.surfaceBright
                                                radius: linkThumbnailContainer.radius
                                                visible: parent.status === Image.Loading

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: Icons.spinnerGap
                                                    font.family: Icons.font
                                                    font.pixelSize: 24
                                                    color: Styling.styledRectItem("overprimary")
                                                    textFormat: Text.RichText
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Loading indicator for link preview
                            Rectangle {
                                id: linkPreviewLoadingRect
                                width: parent.width
                                height: 60
                                visible: root.loadingLinkPreview && previewPanel.currentItem && ClipboardUtils.isUrl(root.safeCurrentContent)
                                color: Colors.surface
                                radius: Styling.radius(4)

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 12

                                    Text {
                                        text: Icons.spinnerGap
                                        font.family: Icons.font
                                        font.pixelSize: 20
                                        color: Styling.styledRectItem("overprimary")
                                        textFormat: Text.RichText

                                        RotationAnimator on rotation {
                                            from: 0
                                            to: 360
                                            duration: 1000
                                            loops: Animation.Infinite
                                            running: linkPreviewLoadingRect.visible
                                        }
                                    }

                                    Text {
                                        text: "Loading preview..."
                                        font.family: Config.theme.font
                                        font.pixelSize: Config.theme.fontSize
                                        color: Colors.outline
                                    }
                                }
                            }

                            // URL preview with favicon (fallback when no embed available)
                            Item {
                                width: parent.width
                                height: urlPreview.visible ? 60 : 0
                                visible: previewPanel.currentItem && ClipboardUtils.isUrl(root.safeCurrentContent) && !root.loadingLinkPreview && (!root.linkPreviewData || (!root.linkPreviewData.title && !root.linkPreviewData.description && !root.linkPreviewData.image))

                                Rectangle {
                                    id: urlPreview
                                    anchors.centerIn: parent
                                    width: parent.width
                                    height: 60
                                    color: urlPreviewMouseArea.containsMouse ? Colors.surfaceBright : Colors.surface
                                    radius: Styling.radius(4)

                                    Behavior on color {
                                        enabled: Config.animDuration > 0
                                        ColorAnimation {
                                            duration: Config.animDuration / 2
                                            easing.type: Easing.OutQuart
                                        }
                                    }

                                    MouseArea {
                                        id: urlPreviewMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor

                                        onClicked: {
                                            if (previewPanel.currentItem) {
                                                root.openItem(previewPanel.currentItem.id);
                                            }
                                        }
                                    }

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 12

                                        // Favicon or fallback icon
                                        Rectangle {
                                            width: 36
                                            height: 36
                                            color: Colors.surfaceBright
                                            radius: Styling.radius(-4)

                                            Image {
                                                id: previewFavicon
                                                anchors.centerIn: parent
                                                width: 24
                                                height: 24
                                                visible: previewPanel.currentItem !== null && status === Image.Ready
                                                fillMode: Image.PreserveAspectFit
                                                asynchronous: true
                                                cache: true

                                                property bool triedFallback: false
                                                property string primarySource: {
                                                    if (!previewPanel.currentItem)
                                                        return "";
                                                    // Use Google service (PNG) as primary to avoid ICO decode errors
                                                    return ClipboardUtils.getFaviconFallbackUrl(root.safeCurrentContent);
                                                }

                                                source: primarySource

                                                onPrimarySourceChanged: {
                                                    triedFallback = false;
                                                    source = primarySource;
                                                }

                                                onStatusChanged: {
                                                    if (status === Image.Error) {
                                                        if (!triedFallback) {
                                                            triedFallback = true;
                                                            var content = root.safeCurrentContent;
                                                            // Fallback to direct .ico if Google fails
                                                            source = ClipboardUtils.getFaviconUrl(content);
                                                        }
                                                    }
                                                }
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                visible: !previewFavicon.visible
                                                text: Icons.globe
                                                font.family: Icons.font
                                                font.pixelSize: 20
                                                color: Styling.styledRectItem("overprimary")
                                                textFormat: Text.RichText
                                            }
                                        }

                                        Column {
                                            width: parent.width - 48 - parent.spacing
                                            height: parent.height
                                            spacing: 4

                                            Text {
                                                text: "Link"
                                                font.family: Config.theme.font
                                                font.pixelSize: Config.theme.fontSize - 1
                                                font.weight: Font.Medium
                                                color: Colors.outline
                                            }

                                            Text {
                                                text: {
                                                    if (!previewPanel.currentItem)
                                                        return "";
                                                    var url = root.safeCurrentContent;
                                                    try {
                                                        var urlObj = new URL(url.trim());
                                                        return urlObj.hostname;
                                                    } catch (e) {
                                                        return url.substring(0, 40) + (url.length > 40 ? "..." : "");
                                                    }
                                                }
                                                font.family: Config.theme.font
                                                font.pixelSize: Config.theme.fontSize
                                                font.weight: Font.Bold
                                                color: Colors.overBackground
                                                elide: Text.ElideRight
                                                width: parent.width
                                            }
                                        }
                                    }
                                }
                            }

                            Text {
                                id: previewText
                                text: root.safeCurrentContent
                                font.family: Config.theme.font
                                font.pixelSize: Config.theme.fontSize
                                color: Colors.overBackground
                                wrapMode: Text.Wrap
                                width: parent.width
                                textFormat: Text.PlainText
                            }
                        }

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                        }
                    }

                    // Preview para archivos (text/uri-list) - solo no-imágenes
                    Item {
                        anchors.fill: parent
                        visible: previewPanel.currentItem && previewPanel.currentItem.isFile && !isImage

                        property string filePath: {
                            if (!previewPanel.currentItem)
                                return "";
                            var content = root.safeCurrentContent;
                            return root.getFilePathFromUri(content);
                        }

                        property bool isImage: root.isImageFile(filePath)

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (previewPanel.currentItem) {
                                    root.openItem(previewPanel.currentItem.id);
                                }
                            }
                        }

                        // Preview genérico para archivos no-imagen
                        Column {
                            anchors.centerIn: parent
                            spacing: 16

                            Rectangle {
                                width: 120
                                height: 120
                                color: Colors.surfaceBright
                                radius: Styling.radius(4)
                                anchors.horizontalCenter: parent.horizontalCenter

                                Text {
                                    anchors.centerIn: parent
                                    text: Icons.file
                                    textFormat: Text.RichText
                                    font.family: Icons.font
                                    font.pixelSize: 48
                                    color: Styling.styledRectItem("overprimary")
                                }
                            }

                            Column {
                                width: previewPanel.width - 16
                                spacing: 8
                                anchors.horizontalCenter: parent.horizontalCenter

                                Text {
                                    text: {
                                        if (!previewPanel.currentItem)
                                            return "";
                                        var content = root.safeCurrentContent;
                                        if (content.startsWith("file://")) {
                                            var filePath = content.substring(7).trim();
                                            var fileName = filePath.split('/').pop();
                                            // Decode URL encoding (e.g., %20 -> space)
                                            return decodeURIComponent(fileName);
                                        }
                                        return content;
                                    }
                                    font.family: Config.theme.font
                                    font.pixelSize: Config.theme.fontSize + 2
                                    font.weight: Font.Bold
                                    color: Colors.overBackground
                                    horizontalAlignment: Text.AlignHCenter
                                    width: parent.width
                                    wrapMode: Text.Wrap
                                }

                                Text {
                                    text: {
                                        if (!previewPanel.currentItem)
                                            return "";
                                        var content = root.safeCurrentContent;
                                        if (content.startsWith("file://")) {
                                            var filePath = content.substring(7).trim();
                                            var parts = filePath.split('/');
                                            parts.pop(); // Remove filename
                                            // Decode each part of the path
                                            var decodedParts = parts.map(function (part) {
                                                return decodeURIComponent(part);
                                            });
                                            return decodedParts.join('/');
                                        }
                                        return "";
                                    }
                                    font.family: Config.theme.font
                                    font.pixelSize: Config.theme.fontSize - 1
                                    color: Colors.outline
                                    horizontalAlignment: Text.AlignHCenter
                                    width: parent.width
                                    wrapMode: Text.Wrap
                                    elide: Text.ElideMiddle
                                }
                            }
                        }
                    }
                }

                // Separator
                Separator {
                    id: separator
                    anchors.bottom: metadataSection.top
                    anchors.bottomMargin: 8
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 2
                    vert: false
                }

                // Metadata section
                Item {
                    id: metadataSection
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 80

                    Row {
                        anchors.fill: parent
                        spacing: 8

                        Column {
                            width: {
                                // Always reserve space for buttons if there's an item
                                return parent.width - (previewPanel.currentItem ? 36 + 8 : 0);
                            }
                            height: parent.height
                            spacing: 4

                            // Row 1: MIME and Size
                            Row {
                                width: parent.width
                                spacing: 16

                                Column {
                                    width: (parent.width - parent.spacing) / 2
                                    spacing: 2

                                    Text {
                                        text: "MIME Type"
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-2)
                                        font.weight: Font.Medium
                                        color: Colors.outline
                                    }

                                    Text {
                                        text: previewPanel.currentItem ? previewPanel.currentItem.mime : ""
                                        font.family: Config.theme.font
                                        font.pixelSize: Config.theme.fontSize
                                        font.weight: Font.Normal
                                        color: Colors.overBackground
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }
                                }

                                Column {
                                    width: (parent.width - parent.spacing) / 2
                                    spacing: 2

                                    Text {
                                        text: "Size"
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-2)
                                        font.weight: Font.Medium
                                        color: Colors.outline
                                    }

                                    Text {
                                        text: {
                                            if (!previewPanel.currentItem)
                                                return "";
                                            var bytes = previewPanel.currentItem.size || 0;
                                            if (bytes < 1024)
                                                return bytes + " B";
                                            if (bytes < 1024 * 1024)
                                                return (bytes / 1024).toFixed(1) + " KB";
                                            return (bytes / (1024 * 1024)).toFixed(1) + " MB";
                                        }
                                        font.family: Config.theme.font
                                        font.pixelSize: Config.theme.fontSize
                                        font.weight: Font.Normal
                                        color: Colors.overBackground
                                    }
                                }
                            }

                            // Row 2: Date and Checksum
                            Row {
                                width: parent.width
                                spacing: 16

                                Column {
                                    width: (parent.width - parent.spacing) / 2
                                    spacing: 2

                                    Text {
                                        text: "Date"
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-2)
                                        font.weight: Font.Medium
                                        color: Colors.outline
                                    }

                                    Text {
                                        text: {
                                            if (!previewPanel.currentItem || !previewPanel.currentItem.createdAt)
                                                return "Unknown";
                                            var date = new Date(previewPanel.currentItem.createdAt);
                                            return Qt.formatDateTime(date, "MMM dd, yyyy hh:mm:ss AP");
                                        }
                                        font.family: Config.theme.font
                                        font.pixelSize: Config.theme.fontSize
                                        font.weight: Font.Normal
                                        color: Colors.overBackground
                                    }
                                }

                                Column {
                                    width: (parent.width - parent.spacing) / 2
                                    spacing: 2

                                    Text {
                                        text: "Checksum"
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-2)
                                        font.weight: Font.Medium
                                        color: Colors.outline
                                    }

                                    Text {
                                        text: {
                                            if (!previewPanel.currentItem || !previewPanel.currentItem.hash)
                                                return "N/A";
                                            var hash = previewPanel.currentItem.hash;
                                            // Show first 8 and last 8 characters
                                            if (hash.length > 16) {
                                                return hash.substring(0, 8) + "..." + hash.substring(hash.length - 8);
                                            }
                                            return hash;
                                        }
                                        font.family: Config.theme.font
                                        font.pixelSize: Config.theme.fontSize
                                        font.weight: Font.Normal
                                        color: Colors.overBackground
                                        elide: Text.ElideMiddle
                                        width: parent.width
                                    }
                                }
                            }
                        }

                        // Action buttons column (Open and Drag)
                        Column {
                            width: 36
                            height: parent.height
                            spacing: 4
                            visible: previewPanel.currentItem !== null

                            // Open button (for files, images, and URLs)
                            StyledRect {
                                width: height
                                height: 36
                                variant: metadataOpenButtonMouseArea.containsMouse ? "focus" : "common"
                                color: metadataOpenButtonMouseArea.containsMouse ? Colors.surfaceBright : Colors.surface
                                radius: Styling.radius(0)
                                visible: {
                                    if (!previewPanel.currentItem)
                                        return false;
                                    var item = previewPanel.currentItem;
                                    return item.isFile || item.isImage || ClipboardUtils.isUrl(root.safeCurrentContent);
                                }

                                Behavior on color {
                                    enabled: Config.animDuration > 0
                                    ColorAnimation {
                                        duration: Config.animDuration / 2
                                        easing.type: Easing.OutQuart
                                    }
                                }

                                MouseArea {
                                    id: metadataOpenButtonMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        if (previewPanel.currentItem) {
                                            root.openItem(previewPanel.currentItem.id);
                                        }
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: Icons.popOpen
                                    font.family: Icons.font
                                    font.pixelSize: 20
                                    color: metadataOpenButtonMouseArea.containsMouse ? Styling.styledRectItem("overprimary") : Colors.overBackground
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

                            // Drag button
                            StyledRect {
                                id: dragButton
                                width: height
                                height: 36
                                variant: metadataDragArea.containsMouse ? "focus" : "common"
                                color: metadataDragArea.containsMouse ? Colors.surfaceBright : Colors.surface
                                radius: Styling.radius(0)

                                Behavior on color {
                                    enabled: Config.animDuration > 0
                                    ColorAnimation {
                                        duration: Config.animDuration / 2
                                        easing.type: Easing.OutQuart
                                    }
                                }

                                // Invisible drag target
                                Item {
                                    id: dragTarget

                                    // Drag properties on the invisible item
                                    Drag.active: metadataDragArea.drag.active
                                    Drag.dragType: Drag.Automatic
                                    Drag.supportedActions: Qt.CopyAction
                                    Drag.mimeData: {
                                        if (!previewPanel.currentItem)
                                            return {};

                                        var item = previewPanel.currentItem;
                                        var content = root.safeCurrentContent.trim();

                                        if (item.isFile) {
                                            // File: send as URI list
                                            return {
                                                "text/uri-list": content
                                            };
                                        } else if (item.isImage && item.binaryPath) {
                                            // Image from clipboard: send as file URI
                                            return {
                                                "text/uri-list": "file://" + item.binaryPath
                                            };
                                        } else {
                                            // Text: send as plain text
                                            return {
                                                "text/plain": content
                                            };
                                        }
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: Icons.handGrab
                                    font.family: Icons.font
                                    font.pixelSize: 20
                                    color: metadataDragArea.containsMouse ? Styling.styledRectItem("overprimary") : Colors.overBackground
                                    textFormat: Text.RichText

                                    Behavior on color {
                                        enabled: Config.animDuration > 0
                                        ColorAnimation {
                                            duration: Config.animDuration / 2
                                            easing.type: Easing.OutQuart
                                        }
                                    }
                                }

                                MouseArea {
                                    id: metadataDragArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.OpenHandCursor
                                    drag.target: dragTarget
                                }
                            }
                        }
                    }
                }
            }

            // Placeholder cuando no hay nada seleccionado
            Column {
                anchors.centerIn: parent
                spacing: 16
                visible: !previewPanel.currentItem

                Text {
                    text: Icons.cactus
                    font.family: Icons.font
                    font.pixelSize: 48
                    color: Colors.surfaceBright
                    anchors.horizontalCenter: parent.horizontalCenter
                    textFormat: Text.RichText
                }
            }
        }
    }

    // Handler de teclas global para manejar navegación en modo eliminar y alias
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
                    root.confirmDeleteItem();
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                root.cancelDeleteMode();
                event.accepted = true;
            }
        } else if (root.aliasMode) {
            if (event.key === Qt.Key_Left) {
                root.aliasButtonIndex = 0;
                event.accepted = true;
            } else if (event.key === Qt.Key_Right) {
                root.aliasButtonIndex = 1;
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
                if (root.aliasButtonIndex === 0) {
                    root.cancelAliasMode();
                } else {
                    root.confirmAliasItem();
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                root.cancelAliasMode();
                event.accepted = true;
            }
        }
    }

    Component.onCompleted: {
        refreshClipboardHistory();
        Qt.callLater(() => {
            focusSearchInput();
        });
    }
}
