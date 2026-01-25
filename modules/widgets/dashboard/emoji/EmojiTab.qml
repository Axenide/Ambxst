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

    property int leftPanelWidth: 0

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

    // Skin tone support
    property var skinTones: [
        {
            name: "Light",
            modifier: "🏻",
            emoji: "👋🏻"
        },
        {
            name: "Medium-Light",
            modifier: "🏼",
            emoji: "👋🏼"
        },
        {
            name: "Medium",
            modifier: "🏽",
            emoji: "👋🏽"
        },
        {
            name: "Medium-Dark",
            modifier: "🏾",
            emoji: "👋🏾"
        },
        {
            name: "Dark",
            modifier: "🏿",
            emoji: "👋🏿"
        }
    ]

    // Options menu state (expandable list)
    property int expandedItemIndex: -1
    property int selectedOptionIndex: 0
    property bool keyboardNavigation: false

    function getSkinToneName(modifier) {
        for (var i = 0; i < skinTones.length; i++) {
            if (skinTones[i].modifier === modifier) {
                return skinTones[i].name.toLowerCase();
            }
        }
        return "default";
    }

    ListModel {
        id: emojisModel
    }

    ListModel {
        id: recentModel
    }

    function adjustScrollForExpandedItem(index) {
        if (index < 0 || index >= emojisModel.count)
            return;

        // Calculate Y position of the item
        var itemY = 0;
        for (var i = 0; i < index && i < emojisModel.count; i++) {
            var h = 48;
            if (i === root.expandedItemIndex) {
                var item = emojisModel.get(i);
                if (item) {
                    var itemData = item.emojiData;
                    if (itemData && itemData.skin_tone_support) {
                        var optionsCount = root.skinTones.length;
                        var listHeight = 36 * Math.min(3, optionsCount);
                        h = 48 + 4 + listHeight + 8;
                    }
                }
            }
            itemY += h;
        }

        // Calculate expanded item height
        var currentItemHeight = 48;
        var item = emojisModel.get(index);
        if (item) {
            var itemData = item.emojiData;
            if (itemData && itemData.skin_tone_support) {
                var optionsCount = root.skinTones.length;
                var listHeight = 36 * Math.min(3, optionsCount);
                currentItemHeight = 48 + 4 + listHeight + 8;
            }
        }

        // Calculate max valid scroll position
        var maxContentY = Math.max(0, emojiList.contentHeight - emojiList.height);

        // Current viewport bounds
        var viewportTop = emojiList.contentY;
        var viewportBottom = viewportTop + emojiList.height;

        // Only scroll if item is not fully visible
        var itemBottom = itemY + currentItemHeight;

        if (itemY < viewportTop) {
            // Item top is above viewport - scroll up to show it
            emojiList.contentY = itemY;
        } else if (itemBottom > viewportBottom) {
            // Item bottom is below viewport - scroll down to show it
            emojiList.contentY = Math.min(itemBottom - emojiList.height, maxContentY);
        }
    }

    onSelectedIndexChanged: {
        if (selectedIndex === -1 && emojiList.count > 0) {
            emojiList.positionViewAtIndex(0, ListView.Beginning);
        }

        // Close expanded options when selection changes to a different item
        if (expandedItemIndex >= 0 && selectedIndex !== expandedItemIndex) {
            expandedItemIndex = -1;
            selectedOptionIndex = 0;
            keyboardNavigation = false;
        }
    }

    onExpandedItemIndexChanged: {
        // Close expanded options when selection changes to a different item is handled in onSelectedIndexChanged
    }

    onSearchTextChanged: {
        performSearch();
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

        loadInitialEmojis();
        emojiList.enableScrollAnimation = false;
        emojiList.contentY = 0;
        Qt.callLater(() => {
            emojiList.enableScrollAnimation = true;
        });
    }

    function resetClearButton() {
        clearButtonConfirmState = false;
    }

    function clearRecentEmojis() {
        recentEmojis = [];
        saveRecentEmojis();
        updateRecentModel();
        clearButtonConfirmState = false;
        clearButtonFocused = false;
        searchInput.focusInput();
    }

    function focusSearchInput() {
        searchInput.focusInput();
    }

    function performSearch() {
        if (searchText.length === 0) {
            loadInitialEmojis();
            selectedIndex = -1;
            selectedRecentIndex = -1;
            emojiList.contentY = 0;
            return;
        }

        updateFilteredEmojis();
    }

    function updateFilteredEmojis() {
        var filtered = [];
        var searchLower = searchText.toLowerCase();

        if (searchText.length > 0) {
            for (var i = 0; i < emojiData.length; i++) {
                var emoji = emojiData[i];
                var emojiText = emoji.emoji;
                var searchTerms = emoji.search;
                var name = emoji.name;
                var slug = emoji.slug;
                var group = emoji.group;

                if (emojiText.includes(searchText) || searchTerms.toLowerCase().includes(searchLower) || name.toLowerCase().includes(searchLower) || slug.toLowerCase().includes(searchLower) || group.toLowerCase().includes(searchLower)) {
                    filtered.push(emoji);
                }
            }
        }

        filteredEmojis = filtered;
        emojiList.enableScrollAnimation = false;
        emojiList.contentY = 0;

        emojisModel.clear();
        for (var i = 0; i < filtered.length; i++) {
            emojisModel.append({
                emojiId: filtered[i].search,
                emojiData: filtered[i]
            });
        }

        Qt.callLater(() => {
            emojiList.enableScrollAnimation = true;
        });

        if (searchText.length > 0 && filteredEmojis.length > 0 && !isRecentFocused) {
            selectedIndex = 0;
            emojiList.currentIndex = 0;
        } else if (searchText.length === 0 && !hasNavigatedFromSearch) {
            selectedIndex = -1;
            selectedRecentIndex = -1;
        }
    }

    function updateRecentModel() {
        recentModel.clear();
        for (var i = 0; i < recentEmojis.length; i++) {
            recentModel.append({
                emojiId: recentEmojis[i].search,
                emojiData: recentEmojis[i]
            });
        }
    }

    function loadEmojiData() {
        emojiProcess.command = ["bash", "-c", "cat " + Qt.resolvedUrl("../../../../assets/emojis.json").toString().replace("file://", "")];
        emojiProcess.running = true;
    }

    function loadInitialEmojis() {
        var initial = [];
        for (var i = 0; i < Math.min(50, emojiData.length); i++) {
            initial.push(emojiData[i]);
        }

        emojisModel.clear();
        for (var i = 0; i < initial.length; i++) {
            emojisModel.append({
                emojiId: initial[i].search,
                emojiData: initial[i]
            });
        }

        filteredEmojis = initial;
    }

    function loadRecentEmojis() {
        recentProcess.command = ["bash", "-c", "cat " + Quickshell.dataDir + "/emojis.json 2>/dev/null || echo '[]'"];
        recentProcess.running = true;
    }

    function saveRecentEmojis() {
        var jsonData = JSON.stringify(recentEmojis, null, 2);
        saveProcess.command = ["bash", "-c", "echo '" + jsonData.replace(/'/g, "'\\''") + "' > " + Quickshell.dataDir + "/emojis.json"];
        saveProcess.running = true;
    }

    function addToRecent(emoji) {
        recentEmojis = recentEmojis.filter(function (item) {
            return item.emoji !== emoji.emoji;
        });

        emoji.usage = (emoji.usage || 0) + 1;
        emoji.lastUsed = Date.now();
        recentEmojis.unshift(emoji);

        if (recentEmojis.length > 50) {
            recentEmojis = recentEmojis.slice(0, 50);
        }

        recentEmojis.sort(function (a, b) {
            if (a.usage !== b.usage) {
                return b.usage - a.usage;
            }
            return b.lastUsed - a.lastUsed;
        });

        updateRecentModel();
        saveRecentEmojis();
    }

    function copyEmoji(emoji, skinToneModifier) {
        var emojiToCopy = emoji.emoji;
        if (skinToneModifier && skinToneModifier !== "") {
            emojiToCopy = emoji.emoji + skinToneModifier;
        }

        // Create emoji object with skin tone applied for recent storage
        var emojiForRecent = {
            emoji: emojiToCopy,
            name: emoji.name + (skinToneModifier ? " (" + getSkinToneName(skinToneModifier) + ")" : ""),
            slug: emoji.slug,
            group: emoji.group,
            search: emoji.name + " " + emoji.slug + (skinToneModifier ? " " + getSkinToneName(skinToneModifier) : ""),
            skin_tone_support: emoji.skin_tone_support
        };

        root.addToRecent(emojiForRecent);
        Visibilities.setActiveModule("");
        ClipboardService.copyAndTypeEmoji(emojiToCopy);
    }

    function onDownPressed() {
        if (!hasNavigatedFromSearch && !isRecentFocused) {
            hasNavigatedFromSearch = true;
            if (filteredEmojis.length > 0) {
                isRecentFocused = false;
                selectedRecentIndex = -1;
                recentList.currentIndex = -1;
            }
        }

        if (!isRecentFocused && emojiList.count > 0) {
            if (selectedIndex === -1) {
                selectedIndex = 0;
                emojiList.currentIndex = 0;
            } else if (selectedIndex < emojiList.count - 1) {
                selectedIndex++;
                emojiList.currentIndex = selectedIndex;
            }
        } else if (isRecentFocused && recentEmojis.length > 0) {
            if (selectedRecentIndex === -1) {
                selectedRecentIndex = 0;
                recentList.currentIndex = 0;
                lastSelectedRecentIndex = 0;
            } else if (selectedRecentIndex < recentEmojis.length - 1) {
                selectedRecentIndex++;
                recentList.currentIndex = selectedRecentIndex;
                lastSelectedRecentIndex = selectedRecentIndex;
            }
        }
    }

    function onUpPressed() {
        if (isRecentFocused) {
            if (selectedRecentIndex > 0) {
                selectedRecentIndex--;
                recentList.currentIndex = selectedRecentIndex;
                lastSelectedRecentIndex = selectedRecentIndex;
            } else if (selectedRecentIndex === 0) {
                isRecentFocused = false;
                selectedRecentIndex = -1;
                recentList.currentIndex = -1;
                hasNavigatedFromSearch = false;
            }
        } else if (selectedIndex > 0) {
            selectedIndex--;
            emojiList.currentIndex = selectedIndex;
        } else if (selectedIndex === 0) {
            selectedIndex = -1;
            emojiList.currentIndex = -1;
            hasNavigatedFromSearch = false;
        }
    }

    function onLeftPressed() {
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

    implicitWidth: 480
    implicitHeight: 296
    color: "transparent"

    Behavior on height {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutQuart
        }
    }

    Process {
        id: emojiProcess
        running: false

        stdout: StdioCollector {
            waitForEnd: true

            onStreamFinished: {
                try {
                    var jsonData = JSON.parse(text.trim());
                    var data = [];
                    for (var emoji in jsonData) {
                        if (jsonData.hasOwnProperty(emoji)) {
                            var emojiInfo = jsonData[emoji];
                            data.push({
                                emoji: emoji,
                                name: emojiInfo.name,
                                slug: emojiInfo.slug,
                                group: emojiInfo.group,
                                search: emojiInfo.name + " " + emojiInfo.slug,
                                skin_tone_support: emojiInfo.skin_tone_support || false
                            });
                        }
                    }
                    emojiData = data;
                    loadInitialEmojis();
                } catch (e) {
                    console.error("Failed to parse emojis.json:", e);
                    emojiData = [];
                    loadInitialEmojis();
                }
            }
        }
    }

    Process {
        id: recentProcess
        running: false

        stdout: StdioCollector {
            waitForEnd: true

            onStreamFinished: {
                try {
                    recentEmojis = JSON.parse(text.trim());
                    updateRecentModel();
                } catch (e) {
                    recentEmojis = [];
                    updateRecentModel();
                }
            }
        }
    }

    Process {
        id: saveProcess
        running: false
    }

    Item {
        id: mainLayout
        anchors.fill: parent

        RowLayout {
            anchors.fill: parent
            spacing: 8

            Item {
                Layout.preferredWidth: root.leftPanelWidth
                Layout.fillHeight: true

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
                        placeholderText: "Search emojis..."
                        prefixIcon: root.prefixIcon

                        onSearchTextChanged: text => {
                            root.searchText = text;
                        }

                        onBackspaceOnEmpty: {
                            root.backspaceOnEmpty();
                        }

                        onAccepted: {
                            if (root.expandedItemIndex >= 0) {
                                // Execute selected option when menu is expanded
                                let emoji = root.filteredEmojis[root.expandedItemIndex];
                                if (emoji) {
                                    var skinTone = root.skinTones[root.selectedOptionIndex];
                                    if (skinTone) {
                                        root.copyEmoji(emoji, skinTone.modifier);
                                    }
                                }
                            } else if (isRecentFocused && selectedRecentIndex >= 0 && selectedRecentIndex < recentEmojis.length) {
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

                        onShiftAccepted: {
                            if (!root.deleteMode && !root.aliasMode) {
                                if (root.selectedIndex >= 0 && root.selectedIndex < root.filteredEmojis.length) {
                                    var selectedEmoji = root.filteredEmojis[root.selectedIndex];
                                    if (selectedEmoji && selectedEmoji.skin_tone_support) {
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

                        onEscapePressed: {
                            if (root.expandedItemIndex >= 0) {
                                root.expandedItemIndex = -1;
                                root.selectedOptionIndex = 0;
                                root.keyboardNavigation = false;
                            } else if (root.searchText.length === 0) {
                                Visibilities.setActiveModule("");
                            } else {
                                root.clearSearch();
                            }
                        }

                        onDownPressed: {
                            if (root.expandedItemIndex >= 0) {
                                // Navigate options when menu is expanded
                                var emoji = root.filteredEmojis[root.expandedItemIndex];
                                if (emoji && emoji.skin_tone_support) {
                                    var maxOptions = root.skinTones.length;
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

                        onLeftPressed: {
                            root.onLeftPressed();
                        }

                        onRightPressed: {
                            root.onRightPressed();
                        }
                    }

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
                                color: root.clearButtonConfirmState ? clearButton.item : Styling.srItem("overprimary")
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

                ListView {
                    id: emojiList
                    width: parent.width
                    anchors.top: searchRow.bottom
                    anchors.bottom: parent.bottom
                    anchors.topMargin: 8
                    anchors.bottomMargin: 0
                    clip: true

                    cacheBuffer: 96
                    reuseItems: false

                    model: emojisModel
                    currentIndex: root.selectedIndex

                    property bool enableScrollAnimation: true

                    Behavior on contentY {
                        enabled: Config.animDuration > 0 && emojiList.enableScrollAnimation && !emojiList.moving
                        NumberAnimation {
                            duration: Config.animDuration / 2
                            easing.type: Easing.OutCubic
                        }
                    }

                    onCurrentIndexChanged: {
                        if (currentIndex !== root.selectedIndex && !root.isRecentFocused) {
                            root.selectedIndex = currentIndex;
                        }

                        if (currentIndex >= 0 && !root.isRecentFocused) {
                            var itemY = 0;
                            for (var i = 0; i < currentIndex && i < emojisModel.count; i++) {
                                var itemHeight = 48;
                                if (i === root.expandedItemIndex && !root.deleteMode && !root.aliasMode) {
                                    var item = emojisModel.get(i);
                                    if (item) {
                                        var itemData = item.emojiData;
                                        if (itemData && itemData.skin_tone_support) {
                                            var optionsCount = root.skinTones.length;
                                            var listHeight = 36 * Math.min(3, optionsCount);
                                            itemHeight = 48 + 4 + listHeight + 8;
                                        }
                                    }
                                }
                                itemY += itemHeight;
                            }

                            var currentItemHeight = 48;
                            if (currentIndex === root.expandedItemIndex && !root.deleteMode && !root.aliasMode && currentIndex < emojisModel.count) {
                                var item = emojisModel.get(currentIndex);
                                if (item) {
                                    var itemData = item.emojiData;
                                    if (itemData && itemData.skin_tone_support) {
                                        var optionsCount = root.skinTones.length;
                                        var listHeight = 36 * Math.min(3, optionsCount);
                                        currentItemHeight = 48 + 4 + listHeight + 8;
                                    }
                                }
                            }

                            var viewportTop = emojiList.contentY;
                            var viewportBottom = viewportTop + emojiList.height;

                            if (itemY < viewportTop) {
                                emojiList.contentY = itemY;
                            } else if (itemY + currentItemHeight > viewportBottom) {
                                emojiList.contentY = itemY + currentItemHeight - emojiList.height;
                            }
                        }
                    }

                    delegate: Rectangle {
                        required property string emojiId
                        required property var emojiData
                        required property int index

                        property var modelData: emojiData

                        width: emojiList.width
                        height: {
                            let baseHeight = 48;
                            if (index === root.expandedItemIndex && !root.deleteMode && !root.aliasMode && modelData.skin_tone_support) {
                                var optionsCount = root.skinTones.length;
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

                        property color textColor: {
                            if (root.selectedIndex === index && !root.isRecentFocused) {
                                if (root.expandedItemIndex === index) {
                                    return Styling.srItem("pane");
                                }
                                return Styling.srItem("primary");
                            } else {
                                return Colors.overSurface;
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            preventStealing: false
                            propagateComposedEvents: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton

                            onEntered: {
                                if (root.isRecentFocused) {
                                    root.isRecentFocused = false;
                                    root.selectedRecentIndex = -1;
                                    recentList.currentIndex = -1;
                                }
                                root.selectedIndex = index;
                                emojiList.currentIndex = index;
                            }

                            onClicked: mouse => {
                                if (mouse.button === Qt.LeftButton) {
                                    if (modelData.skin_tone_support) {
                                        // For emojis with skin tone support, expand options on left click
                                        if (root.expandedItemIndex === index) {
                                            root.expandedItemIndex = -1;
                                            root.selectedOptionIndex = 0;
                                            root.keyboardNavigation = false;
                                            // Update selection to current hover position after closing
                                            root.selectedIndex = index;
                                            emojiList.currentIndex = index;
                                        } else {
                                            root.expandedItemIndex = index;
                                            root.selectedIndex = index;
                                            emojiList.currentIndex = index;
                                            root.selectedOptionIndex = 0;
                                            root.keyboardNavigation = false;
                                        }
                                    } else {
                                        // For regular emojis, copy directly
                                        root.copyEmoji(modelData);
                                    }
                                } else if (mouse.button === Qt.RightButton) {
                                    if (modelData.skin_tone_support) {
                                        // Toggle expanded state for skin tone selection
                                        if (root.expandedItemIndex === index) {
                                            root.expandedItemIndex = -1;
                                            root.selectedOptionIndex = 0;
                                            root.keyboardNavigation = false;
                                            // Update selection to current hover position after closing
                                            root.selectedIndex = index;
                                            emojiList.currentIndex = index;
                                        } else {
                                            root.expandedItemIndex = index;
                                            root.selectedIndex = index;
                                            emojiList.currentIndex = index;
                                            root.selectedOptionIndex = 0;
                                            root.keyboardNavigation = false;
                                        }
                                    }
                                }
                            }
                        }

                        Row {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 8
                            height: 32
                            spacing: 8

                            StyledRect {
                                id: emojiIconBackground
                                width: emojiIcon.implicitWidth + 6
                                height: 32
                                radius: Styling.radius(-4)
                                variant: root.selectedIndex === index && !root.isRecentFocused ? "overprimary" : "common"

                                Text {
                                    id: emojiIcon
                                    anchors.centerIn: parent
                                    color: emojiIconBackground.item
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

                        // Expandable options list (for skin tones)
                        RowLayout {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            anchors.bottomMargin: 8
                            spacing: 4
                            visible: index === root.expandedItemIndex && !root.deleteMode && !root.aliasMode && modelData.skin_tone_support
                            opacity: (index === root.expandedItemIndex && !root.deleteMode && !root.aliasMode && modelData.skin_tone_support) ? 1 : 0

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
                                    var optionsCount = root.skinTones.length;
                                    return 36 * Math.min(3, optionsCount);
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
                                    id: skinToneOptionsListView
                                    anchors.fill: parent
                                    clip: true
                                    interactive: true
                                    boundsBehavior: Flickable.StopAtBounds
                                    model: {
                                        var options = [];
                                        for (var i = 0; i < root.skinTones.length; i++) {
                                            options.push({
                                                text: root.skinTones[i].name,
                                                emoji: modelData.emoji + root.skinTones[i].modifier,
                                                modifier: root.skinTones[i].modifier
                                            });
                                        }
                                        return options;
                                    }
                                    currentIndex: root.selectedOptionIndex
                                    highlightFollowsCurrentItem: true
                                    highlightRangeMode: ListView.ApplyRange
                                    preferredHighlightBegin: 0
                                    preferredHighlightEnd: height

                                    highlight: StyledRect {
                                        variant: "primary"
                                        radius: Styling.radius(0)
                                        visible: skinToneOptionsListView.currentIndex >= 0
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

                                        width: skinToneOptionsListView.width
                                        height: 36

                                        Rectangle {
                                            anchors.fill: parent
                                            color: "transparent"

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.margins: 8
                                                spacing: 8

                                                Text {
                                                    text: modelData.emoji
                                                    font.pixelSize: 20
                                                    horizontalAlignment: Text.AlignHCenter
                                                    verticalAlignment: Text.AlignVCenter
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: modelData.text
                                                    font.family: Config.theme.font
                                                    font.pixelSize: Config.theme.fontSize
                                                    font.weight: skinToneOptionsListView.currentIndex === index ? Font.Bold : Font.Normal
                                                    color: {
                                                        if (skinToneOptionsListView.currentIndex === index) {
                                                            return Styling.srItem("primary");
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
                                                    skinToneOptionsListView.currentIndex = index;
                                                    root.selectedOptionIndex = index;
                                                    root.keyboardNavigation = false;
                                                }

                                                onClicked: {
                                                    if (modelData) {
                                                        root.copyEmoji(root.filteredEmojis[root.expandedItemIndex], modelData.modifier);
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
                                        if (skinToneOptionsListView.contentHeight > skinToneOptionsListView.height) {
                                            const delta = wheel.angleDelta.y;
                                            skinToneOptionsListView.contentY = Math.max(0, Math.min(skinToneOptionsListView.contentHeight - skinToneOptionsListView.height, skinToneOptionsListView.contentY - delta));
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
                                    var optionsCount = root.skinTones.length;
                                    var listHeight = 36 * Math.min(3, optionsCount);
                                    return Math.max(0, listHeight - 32);
                                }
                                Layout.alignment: Qt.AlignVCenter
                                orientation: Qt.Vertical
                                visible: {
                                    var optionsCount = root.skinTones.length;
                                    return optionsCount > 3;
                                }

                                position: skinToneOptionsListView.contentY / skinToneOptionsListView.contentHeight
                                size: skinToneOptionsListView.height / skinToneOptionsListView.contentHeight

                                background: Rectangle {
                                    color: Colors.background
                                    radius: Styling.radius(0)
                                }

                                contentItem: Rectangle {
                                    color: Styling.srItem("overprimary")
                                    radius: Styling.radius(0)
                                }

                                property bool scrollBarPressed: false

                                onPressedChanged: {
                                    scrollBarPressed = pressed;
                                }

                                onPositionChanged: {
                                    if (scrollBarPressed && skinToneOptionsListView.contentHeight > skinToneOptionsListView.height) {
                                        skinToneOptionsListView.contentY = position * skinToneOptionsListView.contentHeight;
                                    }
                                }
                            }
                        }
                    }

                    highlight: Item {
                        width: emojiList.width
                        height: {
                            let baseHeight = 48;
                            if (emojiList.currentIndex === root.expandedItemIndex && emojiList.currentIndex >= 0 && emojiList.currentIndex < emojisModel.count) {
                                var item = emojisModel.get(emojiList.currentIndex);
                                if (item) {
                                    var itemData = item.emojiData;
                                    if (itemData && itemData.skin_tone_support) {
                                        var optionsCount = root.skinTones.length;
                                        var listHeight = 36 * Math.min(3, optionsCount);
                                        return baseHeight + 4 + listHeight + 8;
                                    }
                                }
                            }
                            return baseHeight;
                        }

                        // Calculate Y position based on index, not item position
                        y: {
                            var yPos = 0;
                            for (var i = 0; i < emojiList.currentIndex && i < emojisModel.count; i++) {
                                var itemHeight = 48;
                                if (i === root.expandedItemIndex) {
                                    var itemData = emojisModel.get(i).emojiData;
                                    if (itemData && itemData.skin_tone_support) {
                                        var optionsCount = root.skinTones.length;
                                        var listHeight = 36 * Math.min(3, optionsCount);
                                        itemHeight = 48 + 4 + listHeight + 8;
                                    }
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
                            variant: {
                                if (root.expandedItemIndex >= 0 && root.selectedIndex === root.expandedItemIndex) {
                                    return "pane";
                                } else {
                                    return "primary";
                                }
                            }
                            radius: Styling.radius(4)
                            visible: root.selectedIndex >= 0 && !root.isRecentFocused

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
                }
            }

            Rectangle {
                Layout.preferredWidth: 2
                Layout.fillHeight: true
                radius: Styling.radius(0)
                color: Colors.surface
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Item {
                    anchors.fill: parent
                    visible: recentEmojis.length > 0 && searchText.length === 0

                    ListView {
                        id: recentList
                        anchors.fill: parent
                        orientation: ListView.Vertical
                        spacing: 0
                        clip: true
                        cacheBuffer: 96
                        reuseItems: false

                        model: recentModel
                        currentIndex: root.selectedRecentIndex

                        property bool enableScrollAnimation: true

                        Behavior on contentY {
                            enabled: Config.animDuration > 0 && recentList.enableScrollAnimation && !recentList.moving
                            NumberAnimation {
                                duration: Config.animDuration / 2
                                easing.type: Easing.OutCubic
                            }
                        }

                        onCurrentIndexChanged: {
                            if (currentIndex !== root.selectedRecentIndex && root.isRecentFocused) {
                                root.selectedRecentIndex = currentIndex;
                                root.lastSelectedRecentIndex = currentIndex;
                            }

                            if (currentIndex >= 0 && root.isRecentFocused) {
                                var itemY = currentIndex * 48;
                                var viewportTop = recentList.contentY;
                                var viewportBottom = viewportTop + recentList.height;

                                if (itemY < viewportTop) {
                                    recentList.contentY = itemY;
                                } else if (itemY + 48 > viewportBottom) {
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
                            radius: Styling.radius(-4)

                            property color textColor: {
                                if (root.selectedRecentIndex === index && root.isRecentFocused) {
                                    return Styling.srItem("primary");
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
                                    radius: Styling.radius(-4)
                                    variant: root.selectedRecentIndex === index && root.isRecentFocused ? "overprimary" : "common"

                                    Text {
                                        id: recentEmojiIcon
                                        anchors.centerIn: parent
                                        color: recentEmojiIconBackground.item
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
                                radius: Styling.radius(4)
                                visible: root.isRecentFocused
                            }
                        }

                        highlightFollowsCurrentItem: false
                    }
                }

                Item {
                    anchors.fill: parent
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

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: {
            focusSearchInput();
        }
    }
}
