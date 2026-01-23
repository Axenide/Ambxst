import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import qs.modules.theme
import qs.modules.components
import qs.modules.globals
import qs.modules.services
import qs.config
import "../clipboard"
import "../emoji"
import "../tmux"
import "../notes"
import "calendar"

Rectangle {
    color: "transparent"
    implicitWidth: 600
    implicitHeight: 750

    property int leftPanelWidth: 0

    property int currentTab: GlobalStates.widgetsTabCurrentIndex  // 0=launcher, 1=clip, 2=emoji, 3=tmux, 4=notes
    property bool prefixDisabled: false  // Flag to prevent re-activation after backspace

    // Sync with GlobalStates
    onCurrentTabChanged: {
        GlobalStates.widgetsTabCurrentIndex = currentTab;
    }

    // Function to focus app search when tab becomes active
    function focusAppSearch() {
        Qt.callLater(() => {
            if (currentTab === 0) {
                appLauncher.focusSearchInput();
            } else {
                // Fix: Access the Loader from StackLayout (index = currentTab - 1)
                // and call focusSearchInput on the loaded item, not the Loader itself
                let loader = internalStack.itemAt(currentTab - 1);
                if (loader && loader.item && loader.item.focusSearchInput) {
                    loader.item.focusSearchInput();
                }
            }
        });
    }

    // Expose this for Dashboard compatibility
    function focusSearchInput() {
        focusAppSearch();
    }

    // Handle prefix detection in launcher
    function detectPrefix(text) {
        let clipPrefix = Config.prefix.clipboard + " ";
        let emojiPrefix = Config.prefix.emoji + " ";
        let tmuxPrefix = Config.prefix.tmux + " ";
        let notesPrefix = Config.prefix.notes + " ";

        // If prefix was manually disabled, don't re-enable until conditions are met
        if (prefixDisabled) {
            // Only re-enable prefix if user deletes the prefix text or adds valid content
            if (text === clipPrefix || text === emojiPrefix || text === tmuxPrefix || text === notesPrefix) {
                // Still at exact prefix - keep disabled
                return 0;
            } else if (!text.startsWith(clipPrefix) && !text.startsWith(emojiPrefix) && !text.startsWith(tmuxPrefix) && !text.startsWith(notesPrefix)) {
                // User deleted the prefix - re-enable detection
                prefixDisabled = false;
                return 0;
            } else {
                // User typed something after the prefix but it's still disabled
                return 0;
            }
        }

        // Normal prefix detection - only activate if exactly "prefix " (nothing after)
        if (text === clipPrefix) {
            return 1;
        } else if (text === emojiPrefix) {
            return 2;
        } else if (text === tmuxPrefix) {
            return 3;
        } else if (text === notesPrefix) {
            return 4;
        }
        return 0;
    }

    RowLayout {
        anchors.fill: parent
        spacing: 8

        // App Launcher - shown only when currentTab === 0
        Rectangle {
            id: appLauncher
            Layout.preferredWidth: root.leftPanelWidth
            Layout.fillHeight: true
            visible: currentTab === 0
            color: "transparent"

            property string searchText: GlobalStates.launcherSearchText
            property bool showResults: searchText.length > 0
            property int selectedIndex: GlobalStates.launcherSelectedIndex

            // Options menu state (expandable list)
            property int expandedItemIndex: -1
            property int selectedOptionIndex: 0
            property bool keyboardNavigation: false

            // Animated model for smooth filtering
            property var filteredApps: []
            property var appsById: ({})

            // Incremental loading state
            property var pendingApps: []
            property int loadedCount: 0
            property int batchSize: 10

            Timer {
                id: incrementalLoader
                interval: 100 // Run as fast as possible without blocking
                repeat: true
                running: false
                onTriggered: {
                    if (appLauncher.loadedCount >= appLauncher.pendingApps.length || appLauncher.batchSize <= 0) {
                        running = false;
                        return;
                    }

                    let endIndex = Math.min(appLauncher.loadedCount + appLauncher.batchSize, appLauncher.pendingApps.length);
                    for (let i = appLauncher.loadedCount; i < endIndex; i++) {
                        let app = appLauncher.pendingApps[i];
                        appsModel.append({
                            appId: app.id,
                            appName: app.name,
                            appIcon: app.icon,
                            appComment: app.comment,
                            appExecString: app.execString,
                            appCategories: app.categories,
                            appRunInTerminal: app.runInTerminal
                        });
                    }
                    appLauncher.loadedCount = endIndex;
                }
            }

            function updateFilteredApps() {
                if (searchText.length > 0) {
                    filteredApps = AppSearch.fuzzyQuery(searchText);
                } else {
                    filteredApps = AppSearch.getAllApps();
                }
            }

            onFilteredAppsChanged: {
                resultsList.enableScrollAnimation = false;
                resultsList.contentY = 0;
                updateAppsModel();
                Qt.callLater(() => {
                    resultsList.enableScrollAnimation = true;
                });
            }

            function updateAppsModel() {
                // Stop any existing loading
                incrementalLoader.stop();
                
                let newApps = filteredApps;
                appLauncher.pendingApps = newApps;

                // Build apps by ID map for execution
                appsById = {};
                for (let i = 0; i < newApps.length; i++) {
                    appsById[newApps[i].id] = newApps[i];
                }

                appsModel.clear();
                
                // Load first batch immediately for instant feedback
                let initialBatch = Math.min(appLauncher.batchSize, newApps.length);
                for (let i = 0; i < initialBatch; i++) {
                    let app = newApps[i];
                    appsModel.append({
                        appId: app.id,
                        appName: app.name,
                        appIcon: app.icon,
                        appComment: app.comment,
                        appExecString: app.execString,
                        appCategories: app.categories,
                        appRunInTerminal: app.runInTerminal
                    });
                }
                
                appLauncher.loadedCount = initialBatch;
                
                // Schedule rest if needed
                if (appLauncher.loadedCount < newApps.length) {
                    incrementalLoader.start();
                }
            }

            function executeApp(appId) {
                let app = appsById[appId];
                if (app && app.execute) {
                    app.execute();
                    // Record usage for sorting priority
                    UsageTracker.recordUsage(appId);
                }
            }

            ListModel {
                id: appsModel
            }

            Component.onCompleted: {
                // Defer initial load to allow dashboard animation to start smoothly
                initialLoadTimer.start();
                
                // Re-update when UsageTracker finishes loading
                UsageTracker.usageDataReady.connect(function() {
                    AppSearch.invalidateCache();
                    if (appLauncher.visible) {
                         appLauncher.updateFilteredApps();
                    }
                });
            }

            Timer {
                id: initialLoadTimer
                interval: 100
                repeat: false
                onTriggered: {
                    appLauncher.updateFilteredApps();
                    appLauncher.updateAppsModel();
                    appLauncher.focusSearchInput();
                }
            }

            onSearchTextChanged: {
                updateFilteredApps();
                // Detect prefix and switch tab if needed
                let detectedTab = detectPrefix(searchText);
                if (detectedTab !== currentTab) {
                    if (detectedTab === 0) {
                        // Return to launcher
                        currentTab = 0;
                        prefixDisabled = false;
                        Qt.callLater(() => {
                            appLauncher.focusSearchInput();
                        });
                    } else {
                        // Switch to prefix tab
                        currentTab = detectedTab;

                        // Extract the text after the prefix
                        let prefixLength = 0;
                        if (searchText.startsWith(Config.prefix.clipboard + " "))
                            prefixLength = Config.prefix.clipboard.length + 1;
                        else if (searchText.startsWith(Config.prefix.emoji + " "))
                            prefixLength = Config.prefix.emoji.length + 1;
                        else if (searchText.startsWith(Config.prefix.tmux + " "))
                            prefixLength = Config.prefix.tmux.length + 1;
                        else if (searchText.startsWith(Config.prefix.notes + " "))
                            prefixLength = Config.prefix.notes.length + 1;

                        let remainingText = searchText.substring(prefixLength);

                        // Wait for loader to be ready and then focus
                        Qt.callLater(() => {
                            let targetItem = null;
                            let targetLoader = null;

                            if (detectedTab === 1) {
                                targetLoader = clipboardLoader;
                            } else if (detectedTab === 2) {
                                targetLoader = emojiLoader;
                            } else if (detectedTab === 3) {
                                targetLoader = tmuxLoader;
                            } else if (detectedTab === 4) {
                                targetLoader = notesLoader;
                            }

                            // If loader is ready, use it immediately
                            if (targetLoader && targetLoader.item) {
                                targetItem = targetLoader.item;
                                // Set the search text in the new tab
                                if (targetItem.searchText !== undefined) {
                                    targetItem.searchText = remainingText;
                                }
                                // Focus the search input
                                if (targetItem.focusSearchInput) {
                                    targetItem.focusSearchInput();
                                }
                            }
                        // Otherwise, the onLoaded handler will take care of focusing
                        });
                    }
                }
            }

            onSelectedIndexChanged: {
                if (selectedIndex === -1 && resultsList.count > 0) {
                    resultsList.contentY = 0;
                }

                // Close expanded options when selection changes to a different item
                if (expandedItemIndex >= 0 && selectedIndex !== expandedItemIndex) {
                    expandedItemIndex = -1;
                    selectedOptionIndex = 0;
                    keyboardNavigation = false;
                }
            }

            function clearSearch() {
                GlobalStates.clearLauncherState();
                searchInput.focusInput();
            }

            function focusSearchInput() {
                searchInput.focusInput();
            }

            function adjustScrollForExpandedItem(index) {
                if (index < 0 || index >= appsModel.count)
                    return;

                // Calculate Y position of the item
                var itemY = 0;
                for (var i = 0; i < index; i++) {
                    itemY += 48; // All items before are collapsed (base height)
                }

                // Calculate expanded item height - always 3 options (Launch, Pin/Unpin, Create Shortcut)
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

            Behavior on height {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration
                    easing.type: Easing.OutQuart
                }
            }

            Item {
                id: mainLayout
                anchors.fill: parent

                // Search input
                SearchInput {
                    id: searchInput
                    width: parent.width
                    anchors.top: parent.top
                    text: GlobalStates.launcherSearchText
                    placeholderText: "Search applications..."
                    iconText: ""

                    onSearchTextChanged: text => {
                        GlobalStates.launcherSearchText = text;
                        appLauncher.searchText = text;

                        resultsList.enableScrollAnimation = false;

                        if (text.length > 0) {
                            GlobalStates.launcherSelectedIndex = 0;
                            appLauncher.selectedIndex = 0;
                            resultsList.currentIndex = 0;

                            resultsList.contentY = 0;
                        } else {
                            GlobalStates.launcherSelectedIndex = -1;
                            appLauncher.selectedIndex = -1;
                            resultsList.currentIndex = -1;

                            resultsList.contentY = 0;
                        }

                        Qt.callLater(() => {
                            resultsList.enableScrollAnimation = true;
                        });
                    }

                    onAccepted: {
                        if (appLauncher.expandedItemIndex >= 0) {
                            // Execute selected option when menu is expanded
                            let selectedApp = appsModel.get(appLauncher.expandedItemIndex);
                            if (selectedApp) {
                                // Build options array
                                let options = [function () {
                                        appLauncher.executeApp(selectedApp.appId);
                                        Visibilities.setActiveModule("");
                                    }, function () {
                                        // Pin/Unpin from dock
                                        TaskbarApps.togglePin(selectedApp.appId);
                                        appLauncher.expandedItemIndex = -1;
                                    }, function () {
                                        // Create shortcut
                                        let desktopDir = Quickshell.env("XDG_DESKTOP_DIR") || Quickshell.env("HOME") + "/Desktop";
                                        let timestamp = Date.now();
                                        let fileName = selectedApp.appId + "-" + timestamp + ".desktop";
                                        let filePath = desktopDir + "/" + fileName;

                                        let desktopContent = "[Desktop Entry]\n" + "Version=1.0\n" + "Type=Application\n" + "Name=" + selectedApp.appName + "\n" + "Exec=" + selectedApp.appExecString + "\n" + "Icon=" + selectedApp.appIcon + "\n" + (selectedApp.appComment ? "Comment=" + selectedApp.appComment + "\n" : "") + (selectedApp.appCategories.length > 0 ? "Categories=" + selectedApp.appCategories.join(";") + ";\n" : "") + (selectedApp.appRunInTerminal ? "Terminal=true\n" : "Terminal=false\n");

                                        let writeCmd = "printf '%s' '" + desktopContent.replace(/'/g, "'\\''") + "' > \"" + filePath + "\" && chmod 755 \"" + filePath + "\" && gio set \"" + filePath + "\" metadata::trusted true";
                                        copyProcess.command = ["sh", "-c", writeCmd];
                                        copyProcess.running = true;
                                        appLauncher.expandedItemIndex = -1;
                                    }];

                                if (appLauncher.selectedOptionIndex >= 0 && appLauncher.selectedOptionIndex < options.length) {
                                    options[appLauncher.selectedOptionIndex]();
                                }
                            }
                        } else {
                            if (appLauncher.selectedIndex >= 0 && appLauncher.selectedIndex < appsModel.count) {
                                let selectedApp = appsModel.get(appLauncher.selectedIndex);
                                if (selectedApp) {
                                    appLauncher.executeApp(selectedApp.appId);
                                    Visibilities.setActiveModule("");
                                }
                            }
                        }
                    }

                    onShiftAccepted: {
                        if (appLauncher.selectedIndex >= 0 && appLauncher.selectedIndex < resultsList.count) {
                            // Toggle expanded state
                            if (appLauncher.expandedItemIndex === appLauncher.selectedIndex) {
                                appLauncher.expandedItemIndex = -1;
                                appLauncher.selectedOptionIndex = 0;
                                appLauncher.keyboardNavigation = false;
                            } else {
                                appLauncher.expandedItemIndex = appLauncher.selectedIndex;
                                appLauncher.selectedOptionIndex = 0;
                                appLauncher.keyboardNavigation = true;
                            }
                        }
                    }

                    onEscapePressed: {
                        if (appLauncher.expandedItemIndex >= 0) {
                            appLauncher.expandedItemIndex = -1;
                            appLauncher.selectedOptionIndex = 0;
                            appLauncher.keyboardNavigation = false;
                        } else {
                            Visibilities.setActiveModule("");
                        }
                    }

                    onDownPressed: {
                        if (appLauncher.expandedItemIndex >= 0) {
                            // Navigate options when menu is expanded - always 3 options (Launch, Pin/Unpin, Create Shortcut)
                            if (appLauncher.selectedOptionIndex < 2) {
                                appLauncher.selectedOptionIndex++;
                                appLauncher.keyboardNavigation = true;
                            }
                        } else if (resultsList.count > 0) {
                            if (appLauncher.selectedIndex === -1) {
                                GlobalStates.launcherSelectedIndex = 0;
                                appLauncher.selectedIndex = 0;
                                resultsList.currentIndex = 0;
                            } else if (appLauncher.selectedIndex < resultsList.count - 1) {
                                GlobalStates.launcherSelectedIndex++;
                                appLauncher.selectedIndex++;
                                resultsList.currentIndex = appLauncher.selectedIndex;
                            }
                        }
                    }

                    onUpPressed: {
                        if (appLauncher.expandedItemIndex >= 0) {
                            // Navigate options when menu is expanded
                            if (appLauncher.selectedOptionIndex > 0) {
                                appLauncher.selectedOptionIndex--;
                                appLauncher.keyboardNavigation = true;
                            }
                        } else if (appLauncher.selectedIndex > 0) {
                            GlobalStates.launcherSelectedIndex--;
                            appLauncher.selectedIndex--;
                            resultsList.currentIndex = appLauncher.selectedIndex;
                        } else if (appLauncher.selectedIndex === 0 && appLauncher.searchText.length === 0) {
                            GlobalStates.launcherSelectedIndex = -1;
                            appLauncher.selectedIndex = -1;
                            resultsList.currentIndex = -1;
                        }
                    }

                    onPageDownPressed: {
                        if (resultsList.count > 0) {
                            let visibleItems = Math.floor(resultsList.height / 48);
                            let newIndex = Math.min(appLauncher.selectedIndex + visibleItems, resultsList.count - 1);
                            if (appLauncher.selectedIndex === -1) {
                                newIndex = Math.min(visibleItems - 1, resultsList.count - 1);
                            }
                            GlobalStates.launcherSelectedIndex = newIndex;
                            appLauncher.selectedIndex = newIndex;
                            resultsList.currentIndex = appLauncher.selectedIndex;
                        }
                    }

                    onPageUpPressed: {
                        if (resultsList.count > 0) {
                            let visibleItems = Math.floor(resultsList.height / 48);
                            let newIndex = Math.max(appLauncher.selectedIndex - visibleItems, 0);
                            if (appLauncher.selectedIndex === -1) {
                                newIndex = Math.max(resultsList.count - visibleItems, 0);
                            }
                            GlobalStates.launcherSelectedIndex = newIndex;
                            appLauncher.selectedIndex = newIndex;
                            resultsList.currentIndex = appLauncher.selectedIndex;
                        }
                    }

                    onHomePressed: {
                        if (resultsList.count > 0) {
                            GlobalStates.launcherSelectedIndex = 0;
                            appLauncher.selectedIndex = 0;
                            resultsList.currentIndex = 0;
                        }
                    }

                    onEndPressed: {
                        if (resultsList.count > 0) {
                            GlobalStates.launcherSelectedIndex = resultsList.count - 1;
                            appLauncher.selectedIndex = resultsList.count - 1;
                            resultsList.currentIndex = appLauncher.selectedIndex;
                        }
                    }
                }

                // Results list
                ListView {
                    id: resultsList
                    width: parent.width
                    anchors.top: searchInput.bottom
                    anchors.bottom: parent.bottom
                    anchors.topMargin: 8
                    visible: true

                    clip: true
                    interactive: appLauncher.expandedItemIndex === -1
                    cacheBuffer: 96
                    reuseItems: true

                    // Propiedad para detectar si está en movimiento (drag o flick)
                    property bool isScrolling: dragging || flicking

                    model: appsModel
                    currentIndex: appLauncher.selectedIndex

                    property bool enableScrollAnimation: true

                    Behavior on contentY {
                        enabled: Config.animDuration > 0 && resultsList.enableScrollAnimation && !resultsList.moving
                        NumberAnimation {
                            duration: Config.animDuration / 2
                            easing.type: Easing.OutCubic
                        }
                    }

                    onCurrentIndexChanged: {
                        if (currentIndex !== appLauncher.selectedIndex) {
                            GlobalStates.launcherSelectedIndex = currentIndex;
                            appLauncher.selectedIndex = currentIndex;
                        }

                        // Manual smooth auto-scroll accounting for variable height items
                        if (currentIndex >= 0) {
                            var itemY = 0;
                            for (var i = 0; i < currentIndex && i < appsModel.count; i++) {
                                var itemHeight = 48;
                                if (i === appLauncher.expandedItemIndex) {
                                    var listHeight = 36 * 3;
                                    itemHeight = 48 + 4 + listHeight + 8;
                                }
                                itemY += itemHeight;
                            }

                            var currentItemHeight = 48;
                            if (currentIndex === appLauncher.expandedItemIndex) {
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
                        required property string appId
                        required property string appName
                        required property string appIcon
                        required property string appComment
                        required property string appExecString
                        required property var appCategories
                        required property bool appRunInTerminal
                        required property int index

                        property bool isExpanded: index === appLauncher.expandedItemIndex

                        width: resultsList.width
                        height: {
                            let baseHeight = 48;
                            if (isExpanded) {
                                var listHeight = 36 * 3; // Always 3 options: Launch, Pin/Unpin, Create Shortcut
                                return baseHeight + 4 + listHeight + 8; // base + spacing + list + bottom margin
                            }
                            return baseHeight;
                        }
                        color: "transparent"
                        radius: 16

                        Behavior on height {
                            enabled: Config.animDuration > 0
                            NumberAnimation {
                                duration: Config.animDuration
                                easing.type: Easing.OutQuart
                            }
                        }

                        MouseArea {
                            id: mouseArea
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            height: isExpanded ? 48 : parent.height
                            hoverEnabled: !resultsList.isScrolling
                            acceptedButtons: Qt.LeftButton | Qt.RightButton

                            onEntered: {
                                if (resultsList.isScrolling)
                                    return;
                                if (appLauncher.expandedItemIndex === -1) {
                                    GlobalStates.launcherSelectedIndex = index;
                                    appLauncher.selectedIndex = index;
                                    resultsList.currentIndex = index;
                                }
                            }

                            onClicked: mouse => {
                                if (mouse.button === Qt.LeftButton) {
                                    if (!isExpanded) {
                                        appLauncher.executeApp(appId);
                                        Visibilities.setActiveModule("");
                                    }
                                } else if (mouse.button === Qt.RightButton) {
                                    // Toggle expanded state
                                    if (appLauncher.expandedItemIndex === index) {
                                        appLauncher.expandedItemIndex = -1;
                                        appLauncher.selectedOptionIndex = 0;
                                        appLauncher.keyboardNavigation = false;
                                        // Update selection to current hover position after closing
                                        GlobalStates.launcherSelectedIndex = index;
                                        appLauncher.selectedIndex = index;
                                        resultsList.currentIndex = index;
                                    } else {
                                        appLauncher.expandedItemIndex = index;
                                        GlobalStates.launcherSelectedIndex = index;
                                        appLauncher.selectedIndex = index;
                                        resultsList.currentIndex = index;
                                        appLauncher.selectedOptionIndex = 0;
                                        appLauncher.keyboardNavigation = false;
                                    }
                                }
                            }
                        }

                        // App content (icon and text)
                        RowLayout {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 8
                            height: 32
                            spacing: 12

                            // App icon
                            Item {
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32

                                Image {
                                    id: appIconImage
                                    anchors.fill: parent
                                    source: "image://icon/" + appIcon
                                    fillMode: Image.PreserveAspectFit
                                    visible: !Config.tintIcons
                                    
                                    onStatusChanged: {
                                        if (status === Image.Error) {
                                            source = "image://icon/image-missing";
                                        }
                                    }
                                }

                                Tinted {
                                    anchors.fill: parent
                                    visible: Config.tintIcons
                                    sourceItem: Image {
                                        id: tintedAppIcon
                                        source: "image://icon/" + appIcon
                                        fillMode: Image.PreserveAspectFit
                                        
                                        onStatusChanged: {
                                            if (status === Image.Error) {
                                                source = "image://icon/image-missing";
                                            }
                                        }
                                    }
                                }
                            }

                            Column {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    width: parent.width
                                    text: appName
                                    color: {
                                        if (isExpanded) {
                                            return Styling.srItem("pane");
                                        } else if (appLauncher.selectedIndex === index) {
                                            return Styling.srItem("primary");
                                        } else {
                                            return Colors.overBackground;
                                        }
                                    }
                                    font.family: Config.theme.font
                                    font.pixelSize: Config.theme.fontSize
                                    font.weight: Font.Bold
                                    elide: Text.ElideRight

                                    Behavior on color {
                                        enabled: Config.animDuration > 0
                                        ColorAnimation {
                                            duration: Config.animDuration / 2
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }

                                Text {
                                    width: parent.width
                                    text: appComment || ""
                                    color: {
                                        if (isExpanded) {
                                            return Styling.srItem("pane");
                                        } else if (appLauncher.selectedIndex === index) {
                                            return Styling.srItem("primary");
                                        } else {
                                            return Colors.outline;
                                        }
                                    }
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-2)
                                    elide: Text.ElideRight
                                    visible: text !== ""

                                    Behavior on color {
                                        enabled: Config.animDuration > 0
                                        ColorAnimation {
                                            duration: Config.animDuration / 2
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }
                            }
                        }

                        // Expandable options list
                        RowLayout {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            anchors.bottomMargin: 8
                            spacing: 4
                            visible: isExpanded
                            opacity: isExpanded ? 1 : 0

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

                                ListView {
                                    id: optionsListView
                                    anchors.fill: parent
                                    clip: true
                                    interactive: false
                                    boundsBehavior: Flickable.StopAtBounds
                                    model: [
                                        {
                                            text: "Launch",
                                            icon: Icons.launch,
                                            highlightColor: Styling.srItem("overprimary"),
                                            textColor: Styling.srItem("primary"),
                                            action: function () {
                                                appLauncher.executeApp(appId);
                                                Visibilities.setActiveModule("");
                                            }
                                        },
                                        {
                                            text: TaskbarApps.isPinned(appId) ? "Unpin from Dock" : "Pin to Dock",
                                            icon: TaskbarApps.isPinned(appId) ? Icons.unpin : Icons.pin,
                                            highlightColor: TaskbarApps.isPinned(appId) ? Colors.error : Colors.tertiary,
                                            textColor: TaskbarApps.isPinned(appId) ? Styling.srItem("error") : Styling.srItem("tertiary"),
                                            action: function () {
                                                TaskbarApps.togglePin(appId);
                                                appLauncher.expandedItemIndex = -1;
                                            }
                                        },
                                        {
                                            text: "Create Shortcut",
                                            icon: Icons.shortcut,
                                            highlightColor: Colors.secondary,
                                            textColor: Styling.srItem("secondary"),
                                            action: function () {
                                                let desktopDir = Quickshell.env("XDG_DESKTOP_DIR") || Quickshell.env("HOME") + "/Desktop";
                                                let timestamp = Date.now();
                                                let fileName = appId + "-" + timestamp + ".desktop";
                                                let filePath = desktopDir + "/" + fileName;

                                                let desktopContent = "[Desktop Entry]\n" + "Version=1.0\n" + "Type=Application\n" + "Name=" + appName + "\n" + "Exec=" + appExecString + "\n" + "Icon=" + appIcon + "\n" + (appComment ? "Comment=" + appComment + "\n" : "") + (appCategories.length > 0 ? "Categories=" + appCategories.join(";") + ";\n" : "") + (appRunInTerminal ? "Terminal=true\n" : "Terminal=false\n");

                                                let writeCmd = "printf '%s' '" + desktopContent.replace(/'/g, "'\\''") + "' > \"" + filePath + "\" && chmod 755 \"" + filePath + "\" && gio set \"" + filePath + "\" metadata::trusted true";
                                                copyProcess.command = ["sh", "-c", writeCmd];
                                                copyProcess.running = true;
                                                appLauncher.expandedItemIndex = -1;
                                            }
                                        }
                                    ]
                                    currentIndex: appLauncher.selectedOptionIndex
                                    highlightFollowsCurrentItem: true
                                    highlightRangeMode: ListView.ApplyRange
                                    preferredHighlightBegin: 0
                                    preferredHighlightEnd: height

                                    highlight: StyledRect {
                                        variant: {
                                            if (optionsListView.currentIndex >= 0 && optionsListView.currentIndex < optionsListView.count) {
                                                var item = optionsListView.model[optionsListView.currentIndex];
                                                if (item && item.highlightColor) {
                                                    if (item.highlightColor === Colors.secondary)
                                                        return "secondary";
                                                    if (item.highlightColor === Colors.tertiary)
                                                        return "tertiary";
                                                    if (item.highlightColor === Colors.error)
                                                        return "error";
                                                    return "primary";
                                                }
                                            }
                                            return "primary";
                                        }
                                        radius: Styling.radius(0)
                                        visible: optionsListView.currentIndex >= 0
                                        z: -1
                                    }

                                    highlightMoveDuration: Config.animDuration > 0 ? Config.animDuration / 2 : 0
                                    highlightMoveVelocity: -1
                                    highlightResizeDuration: Config.animDuration / 2
                                    highlightResizeVelocity: -1

                                    delegate: Item {
                                        required property var modelData
                                        required property int index

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
                                                    appLauncher.selectedOptionIndex = index;
                                                    appLauncher.keyboardNavigation = false;
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
                    }

                    highlight: Item {
                        width: resultsList.width
                        height: {
                            let baseHeight = 48;
                            if (resultsList.currentIndex === appLauncher.expandedItemIndex) {
                                var listHeight = 36 * 3; // Always 3 options
                                return baseHeight + 4 + listHeight + 8;
                            }
                            return baseHeight;
                        }

                        // Calculate Y position based on index, accounting for expanded items
                        y: {
                            var yPos = 0;
                            for (var i = 0; i < resultsList.currentIndex && i < appsModel.count; i++) {
                                var itemHeight = 48;
                                if (i === appLauncher.expandedItemIndex) {
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
                            if (appLauncher.expandedItemIndex >= 0 && height > 48) {
                                Qt.callLater(() => {
                                    appLauncher.adjustScrollForExpandedItem(appLauncher.expandedItemIndex);
                                });
                            }
                        }

                        StyledRect {
                            anchors.fill: parent
                            variant: {
                                if (appLauncher.expandedItemIndex >= 0 && appLauncher.selectedIndex === appLauncher.expandedItemIndex) {
                                    return "pane";
                                } else {
                                    return "primary";
                                }
                            }
                            radius: Styling.radius(4)
                            visible: appLauncher.selectedIndex >= 0
                        }
                    }

                    highlightFollowsCurrentItem: false
                }
            }

            Process {
                id: copyProcess
                running: false

                onExited: function (code) {}
            }
        }

        // StackLayout for other tabs (clipboard, emoji, tmux, notes)
        StackLayout {
            id: internalStack
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: currentTab !== 0
            currentIndex: currentTab - 1  // Subtract 1 because launcher is now separate

            // Tab 1: Clipboard (with prefix from config)
            Loader {
                id: clipboardLoader
                active: currentTab === 1 || item !== null
                sourceComponent: Component {
                    ClipboardTab {
                        leftPanelWidth: root.leftPanelWidth
                        prefixIcon: Icons.clipboard
                        onBackspaceOnEmpty: {
                            // Return to launcher with prefix text + space
                            prefixDisabled = true;
                            currentTab = 0;
                            GlobalStates.launcherSearchText = Config.prefix.clipboard + " ";
                            appLauncher.focusSearchInput();
                        }
                        onRequestOpenItem: (itemId, items, currentContent, filePathGetter, urlChecker) => {
                            console.log("DEBUG: Received requestOpenItem signal for:", itemId);
                            openItemInternal(itemId, items, currentContent, filePathGetter, urlChecker);
                        }
                    }
                }
                onLoaded: {
                    if (currentTab === 1 && item && item.focusSearchInput) {
                        Qt.callLater(() => item.focusSearchInput());
                    }
                }
            }

            // Tab 2: Emoji (with prefix from config)
            Loader {
                id: emojiLoader
                Layout.fillWidth: true
                Layout.fillHeight: true
                active: currentTab === 2 || item !== null
                sourceComponent: Component {
                    EmojiTab {
                        anchors.fill: parent
                        leftPanelWidth: root.leftPanelWidth
                        prefixIcon: Icons.emoji
                        onBackspaceOnEmpty: {
                            prefixDisabled = true;
                            currentTab = 0;
                            GlobalStates.launcherSearchText = Config.prefix.emoji + " ";
                            appLauncher.focusSearchInput();
                        }
                    }
                }
                onLoaded: {
                    if (currentTab === 2 && item && item.focusSearchInput) {
                        Qt.callLater(() => item.focusSearchInput());
                    }
                }
            }

            // Tab 3: Tmux (with prefix from config)
            Loader {
                id: tmuxLoader
                active: currentTab === 3 || item !== null
                sourceComponent: Component {
                    TmuxTab {
                        leftPanelWidth: root.leftPanelWidth
                        prefixIcon: Icons.terminal
                        onBackspaceOnEmpty: {
                            prefixDisabled = true;
                            currentTab = 0;
                            GlobalStates.launcherSearchText = Config.prefix.tmux + " ";
                            appLauncher.focusSearchInput();
                        }
                    }
                }
                onLoaded: {
                    if (currentTab === 3 && item && item.focusSearchInput) {
                        Qt.callLater(() => item.focusSearchInput());
                    }
                }
            }

            // Tab 4: Notes (with prefix from config)
            Loader {
                id: notesLoader
                Layout.fillWidth: true
                Layout.fillHeight: true
                active: currentTab === 4 || item !== null
                sourceComponent: Component {
                    NotesTab {
                        anchors.fill: parent
                        leftPanelWidth: root.leftPanelWidth
                        prefixIcon: Icons.note
                        onBackspaceOnEmpty: {
                            prefixDisabled = true;
                            currentTab = 0;
                            GlobalStates.launcherSearchText = Config.prefix.notes + " ";
                            appLauncher.focusSearchInput();
                        }
                    }
                }
                onLoaded: {
                    if (currentTab === 4 && item && item.focusSearchInput) {
                        Qt.callLater(() => item.focusSearchInput());
                    }
                }
            }
        }

        // Separator (only visible when in launcher tab)
        Separator {
            Layout.preferredWidth: 2
            Layout.fillHeight: true
            vert: true
            visible: currentTab === 0
        }

        // Widgets column (only visible when in launcher tab)
        ClippingRectangle {
            id: widgetsContainer
            Layout.preferredWidth: controlButtonsContainer.implicitWidth
            Layout.fillHeight: true
            radius: Styling.radius(4)
            color: "transparent"
            visible: currentTab === 0

            property bool circularControlDragging: false

            Flickable {
                id: widgetsFlickable
                anchors.fill: parent
                contentWidth: width
                contentHeight: columnLayout.implicitHeight
                clip: true
                interactive: !widgetsContainer.circularControlDragging

                ColumnLayout {
                    id: columnLayout
                    width: parent.width
                    spacing: 8

                    // Control buttons - 5 buttons wrapped in StyledRect pane > internalbg
                    StyledRect {
                        id: controlButtonsContainer
                        variant: "pane"
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: internalBgRect.implicitWidth + 8
                        implicitHeight: internalBgRect.implicitHeight + 8
                        radius: Styling.radius(4)

                        StyledRect {
                            id: internalBgRect
                            variant: "internalbg"
                            anchors.centerIn: parent
                            implicitWidth: buttonRow.implicitWidth + 8
                            implicitHeight: buttonRow.implicitHeight + 8
                            radius: Styling.radius(0)

                            RowLayout {
                                id: buttonRow
                                anchors.centerIn: parent
                                spacing: 4

                                ControlButton {
                                    Layout.preferredWidth: 48
                                    Layout.preferredHeight: 48
                                    iconName: {
                                        if (!NetworkService.wifiEnabled)
                                            return Icons.wifiOff;
                                        const strength = NetworkService.networkStrength;
                                        if (strength === 0)
                                            return Icons.wifiHigh;
                                        if (strength < 25)
                                            return Icons.wifiNone;
                                        if (strength < 50)
                                            return Icons.wifiLow;
                                        if (strength < 75)
                                            return Icons.wifiMedium;
                                        return Icons.wifiHigh;
                                    }
                                    isActive: NetworkService.wifiEnabled
                                    tooltipText: NetworkService.wifiEnabled ? "Wi-Fi: On" : "Wi-Fi: Off"
                                    onClicked: NetworkService.toggleWifi()
                                }

                                ControlButton {
                                    Layout.preferredWidth: 48
                                    Layout.preferredHeight: 48
                                    iconName: {
                                        if (!BluetoothService.enabled)
                                            return Icons.bluetoothOff;
                                        if (BluetoothService.connected)
                                            return Icons.bluetoothConnected;
                                        return Icons.bluetooth;
                                    }
                                    isActive: BluetoothService.enabled
                                    tooltipText: {
                                        if (!BluetoothService.enabled)
                                            return "Bluetooth: Off";
                                        if (BluetoothService.connected)
                                            return "Bluetooth: Connected";
                                        return "Bluetooth: On";
                                    }
                                    onClicked: BluetoothService.toggle()
                                }

                                ControlButton {
                                    Layout.preferredWidth: 48
                                    Layout.preferredHeight: 48
                                    iconName: Icons.nightLight
                                    isActive: NightLightService.active
                                    tooltipText: NightLightService.active ? "Night Light: On" : "Night Light: Off"
                                    onClicked: NightLightService.toggle()
                                }

                                ControlButton {
                                    Layout.preferredWidth: 48
                                    Layout.preferredHeight: 48
                                    iconName: Icons.caffeine
                                    isActive: CaffeineService.inhibit
                                    tooltipText: CaffeineService.inhibit ? "Caffeine: On" : "Caffeine: Off"
                                    onClicked: CaffeineService.toggleInhibit()
                                }

                                ControlButton {
                                    Layout.preferredWidth: 48
                                    Layout.preferredHeight: 48
                                    iconName: Icons.gameMode
                                    isActive: GameModeService.toggled
                                    tooltipText: GameModeService.toggled ? "Game Mode: On" : "Game Mode: Off"
                                    onClicked: GameModeService.toggle()
                                }
                            }
                        }
                    }

                    Loader {
                        Layout.fillWidth: true
                        // Estimate height: Margins(32) + TopRow(52) + Spacing(8) + BottomRow(~24) = 116
                        Layout.preferredHeight: status === Loader.Ready ? -1 : (MprisController.activePlayer ? 116 : 0)
                        asynchronous: true
                        visible: MprisController.activePlayer !== null
                        sourceComponent: Component {
                            FullPlayer { 
                                width: parent.width 
                            }
                        }
                    }

                    Loader {
                        Layout.fillWidth: true
                        Layout.preferredHeight: width
                        asynchronous: true
                        sourceComponent: Component {
                            Calendar { 
                                anchors.fill: parent 
                            }
                        }
                    }

                    StyledRect {
                        variant: "pane"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 150
                    }
                }
            }
        }

        // Notification History (only visible when in launcher tab)
        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: currentTab === 0
            asynchronous: true
            sourceComponent: Component {
                NotificationHistory {
                    anchors.fill: parent
                }
            }
        }

        // Circular controls column (only visible when in launcher tab)
        ColumnLayout {
            Layout.fillHeight: true
            spacing: 8
            visible: currentTab === 0

            property bool circularControlDragging: false

            // Brightness slider - vertical
            ColumnLayout {
                id: brightnessContainer
                Layout.fillHeight: true
                Layout.minimumHeight: 100
                spacing: 8

                // Icon container with sync animation
                Item {
                    id: iconContainer
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    Layout.alignment: Qt.AlignHCenter

                    property bool showingSyncFeedback: false

                    StyledRect {
                        id: iconRect
                        radius: Styling.radius(4)
                        variant: {
                            if (iconMouseArea.containsMouse && Brightness.syncBrightness)
                                return "primaryfocus";
                            if (Brightness.syncBrightness)
                                return "primary";
                            if (iconMouseArea.containsMouse)
                                return "focus";
                            return "pane";
                        }
                        anchors.fill: parent

                        Behavior on variant {
                            enabled: Config.animDuration > 0
                        }

                        Text {
                            id: brightnessIcon
                            anchors.centerIn: parent
                            text: iconContainer.showingSyncFeedback ? Icons.sync : Icons.sun
                            font.family: Icons.font
                            font.pixelSize: 18
                            color: Brightness.syncBrightness ? Styling.srItem("primary") : Colors.overBackground
                            rotation: iconContainer.showingSyncFeedback ? syncIconRotation : brightnessIconRotation
                            scale: iconContainer.showingSyncFeedback ? 1 : brightnessIconScale
                            opacity: iconOpacity

                            property real brightnessIconRotation: 0
                            property real brightnessIconScale: 1
                            property real iconOpacity: 1
                            property real syncIconRotation: 0

                            Behavior on text {
                                enabled: Config.animDuration > 0
                            }

                            Behavior on color {
                                enabled: Config.animDuration > 0
                                ColorAnimation {
                                    duration: Config.animDuration / 2
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Behavior on opacity {
                                enabled: Config.animDuration > 0
                                NumberAnimation {
                                    duration: 150
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Behavior on rotation {
                                enabled: Config.animDuration > 0
                                NumberAnimation {
                                    duration: 400
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Behavior on scale {
                                enabled: Config.animDuration > 0
                                NumberAnimation {
                                    duration: 400
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        MouseArea {
                            id: iconMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                let wasActive = Brightness.syncBrightness;
                                Brightness.syncBrightness = !Brightness.syncBrightness;

                                // Only show sync feedback animation when activating
                                if (Brightness.syncBrightness) {
                                    // Show sync icon instantly and start rotation
                                    iconContainer.showingSyncFeedback = true;
                                    brightnessIcon.iconOpacity = 1;
                                    brightnessIcon.syncIconRotation = 0;
                                    brightnessIcon.syncIconRotation = 360;

                                    // Hold sync icon
                                    syncHoldTimer.start();
                                }
                            }
                            onWheel: wheel => {
                                if (wheel.angleDelta.y > 0) {
                                    brightnessSlider.value = Math.min(1, brightnessSlider.value + 0.1);
                                } else {
                                    brightnessSlider.value = Math.max(0, brightnessSlider.value - 0.1);
                                }
                            }
                        }

                        Timer {
                            id: syncHoldTimer
                            interval: 600
                            onTriggered: {
                                brightnessIcon.iconOpacity = 0;
                                syncFadeOutTimer.start();
                            }
                        }

                        Timer {
                            id: syncFadeOutTimer
                            interval: 150
                            onTriggered: {
                                iconContainer.showingSyncFeedback = false;
                                brightnessIcon.iconOpacity = 1;
                                brightnessIcon.syncIconRotation = 0; // Reset rotation
                            }
                        }
                    }
                }

                // Slider
                Item {
                    Layout.preferredWidth: 48
                    Layout.fillHeight: true
                    Layout.alignment: Qt.AlignHCenter

                    StyledSlider {
                        id: brightnessSlider
                        anchors.fill: parent
                        anchors.margins: 0
                        vertical: true
                        smoothDrag: true
                        value: brightnessValue
                        resizeParent: false
                        wavy: false
                        scroll: true
                        iconClickable: false
                        sliderVisible: true
                        iconPos: "start"
                        icon: ""
                        progressColor: Styling.srItem("overprimary")

                        property real brightnessValue: 0
                        property var currentMonitor: {
                            if (Brightness.monitors.length > 0) {
                                let focusedName = Hyprland.focusedMonitor?.name ?? "";
                                let found = null;
                                for (let i = 0; i < Brightness.monitors.length; i++) {
                                    let mon = Brightness.monitors[i];
                                    if (mon && mon.screen && mon.screen.name === focusedName) {
                                        found = mon;
                                        break;
                                    }
                                }
                                return found || Brightness.monitors[0];
                            }
                            return null;
                        }

                        Component.onCompleted: {
                            if (currentMonitor && currentMonitor.ready) {
                                brightnessValue = currentMonitor.brightness;
                                brightnessIcon.brightnessIconRotation = (brightnessValue / 1.0) * 180;
                                brightnessIcon.brightnessIconScale = 0.8 + (brightnessValue / 1.0) * 0.2;
                            }
                        }

                        onValueChanged: {
                            brightnessValue = value;
                            brightnessIcon.brightnessIconRotation = (value / 1.0) * 180;
                            brightnessIcon.brightnessIconScale = 0.8 + (value / 1.0) * 0.2;

                            if (Brightness.syncBrightness) {
                                // Sync all monitors
                                for (let i = 0; i < Brightness.monitors.length; i++) {
                                    let mon = Brightness.monitors[i];
                                    if (mon && mon.ready) {
                                        mon.setBrightness(value);
                                    }
                                }
                            } else {
                                // Only current monitor
                                if (currentMonitor && currentMonitor.ready) {
                                    currentMonitor.setBrightness(value);
                                }
                            }
                        }

                        onIsDraggingChanged: {
                            brightnessContainer.parent.circularControlDragging = isDragging;
                        }

                        Connections {
                            target: brightnessSlider.currentMonitor
                            ignoreUnknownSignals: true
                            function onBrightnessChanged() {
                                if (brightnessSlider.currentMonitor && brightnessSlider.currentMonitor.ready && !brightnessSlider.isDragging) {
                                    brightnessSlider.brightnessValue = brightnessSlider.currentMonitor.brightness;
                                    brightnessIcon.brightnessIconRotation = (brightnessSlider.brightnessValue / 1.0) * 180;
                                    brightnessIcon.brightnessIconScale = 0.8 + (brightnessSlider.brightnessValue / 1.0) * 0.2;
                                }
                            }
                            function onReadyChanged() {
                                if (brightnessSlider.currentMonitor && brightnessSlider.currentMonitor.ready) {
                                    brightnessSlider.brightnessValue = brightnessSlider.currentMonitor.brightness;
                                    brightnessIcon.brightnessIconRotation = (brightnessSlider.brightnessValue / 1.0) * 180;
                                    brightnessIcon.brightnessIconScale = 0.8 + (brightnessSlider.brightnessValue / 1.0) * 0.2;
                                }
                            }
                        }
                    }
                }
            }

            CircularControl {
                id: volumeControl
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                icon: {
                    if (Audio.sink?.audio?.muted)
                        return Icons.speakerSlash;
                    const vol = Audio.sink?.audio?.volume ?? 0;
                    if (vol < 0.01)
                        return Icons.speakerX;
                    if (vol < 0.19)
                        return Icons.speakerNone;
                    if (vol < 0.49)
                        return Icons.speakerLow;
                    return Icons.speakerHigh;
                }
                value: Audio.sink?.audio?.volume ?? 0
                accentColor: Audio.sink?.audio?.muted ? Colors.outline : Styling.srItem("overprimary")
                isToggleable: true
                isToggled: !(Audio.sink?.audio?.muted ?? false)

                onControlValueChanged: newValue => {
                    if (Audio.sink?.audio) {
                        Audio.sink.audio.volume = newValue;
                    }
                }

                onDraggingChanged: isDragging => {
                    parent.circularControlDragging = isDragging;
                }

                onToggled: {
                    if (Audio.sink?.audio) {
                        Audio.sink.audio.muted = !Audio.sink.audio.muted;
                    }
                }
            }

            CircularControl {
                id: micControl
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                icon: Audio.source?.audio?.muted ? Icons.micSlash : Icons.mic
                value: Audio.source?.audio?.volume ?? 0
                accentColor: Audio.source?.audio?.muted ? Colors.outline : Styling.srItem("overprimary")
                isToggleable: true
                isToggled: !(Audio.source?.audio?.muted ?? false)

                onControlValueChanged: newValue => {
                    if (Audio.source?.audio) {
                        Audio.source.audio.volume = newValue;
                    }
                }

                onDraggingChanged: isDragging => {
                    parent.circularControlDragging = isDragging;
                }

                onToggled: {
                    if (Audio.source?.audio) {
                        Audio.source.audio.muted = !Audio.source.audio.muted;
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        Qt.callLater(focusAppSearch);
    }

    // Global process for opening files/URLs - persists even when tabs change
    Process {
        id: globalOpenProcess
        running: false

        onStarted: function () {
            console.log("DEBUG: globalOpenProcess started with command:", globalOpenProcess.command);
        }

        onExited: function (code, status) {
            if (code === 0) {
                console.log("DEBUG: globalOpenProcess completed successfully");
            } else {
                console.warn("DEBUG: globalOpenProcess failed with exit code:", code, "status:", status);
            }
        }
    }

    // Internal function to open items - called by signal handlers
    function openItemInternal(itemId, items, currentContent, getFilePathFromUri, isUrl) {
        console.log("DEBUG: WidgetsTab.openItemInternal called for itemId:", itemId);
        for (var i = 0; i < items.length; i++) {
            if (items[i].id === itemId) {
                var item = items[i];
                var content = currentContent || item.preview;
                console.log("DEBUG: item found - isFile:", item.isFile, "isImage:", item.isImage, "content:", content);

                if (item.isFile) {
                    var filePath = getFilePathFromUri(content);
                    console.log("DEBUG: Opening file with path:", filePath);
                    if (filePath) {
                        globalOpenProcess.command = ["xdg-open", filePath];
                        globalOpenProcess.running = true;
                    }
                } else if (item.isImage && item.binaryPath) {
                    console.log("DEBUG: Opening image with binaryPath:", item.binaryPath);
                    globalOpenProcess.command = ["xdg-open", item.binaryPath];
                    globalOpenProcess.running = true;
                } else if (isUrl(content)) {
                    console.log("DEBUG: Opening URL:", content.trim());
                    globalOpenProcess.command = ["xdg-open", content.trim()];
                    globalOpenProcess.running = true;
                } else {
                    console.warn("DEBUG: Item does not match any openable type");
                }
                break;
            }
        }
    }
}
