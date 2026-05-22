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
    property var recentEmojis: []
    property var filteredEmojis: []
    property real recentX: selectedRecentIndex >= 0 ? (selectedRecentIndex * 56) + 16 : 0
    property real recentContentX: 0
    property var emojiData: []
    // No behavior on recentX to avoid conflict with the highlight's own behavior
    readonly property bool isAtRecent: selectedIndex === 0 && emojisModel.count > 0 && emojisModel.get(0).isRecentContainer

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

    // Options menu state
    property int expandedItemIndex: -1
    property int selectedOptionIndex: 0
    property bool keyboardNavigation: false
    property bool clearButtonFocused: false
    property bool clearButtonConfirmState: false

    function getSkinToneName(modifier) {
        for (var i = 0; i < skinTones.length; i++) {
            if (skinTones[i].modifier === modifier)
                return skinTones[i].name.toLowerCase();
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
        var itemY = 0;
        for (var i = 0; i < index && i < emojisModel.count; i++) {
            var h = 48;
            if (i === root.expandedItemIndex) {
                var item = emojisModel.get(i);
                if (item && item.emojiData && item.emojiData.skin_tone_support) {
                    h = 48 + 4 + (36 * Math.min(3, root.skinTones.length)) + 8;
                }
            }
            itemY += h;
        }
        var currentItemHeight = 48;
        var item = emojisModel.get(index);
        if (item && item.emojiData && item.emojiData.skin_tone_support && index === root.expandedItemIndex) {
            currentItemHeight = 48 + 4 + (36 * Math.min(3, root.skinTones.length)) + 8;
        }
        var maxContentY = Math.max(0, emojiList.contentHeight - emojiList.height);
        var viewportTop = emojiList.contentY;
        var viewportBottom = viewportTop + emojiList.height;
        var itemBottom = itemY + currentItemHeight;

        if (itemY < viewportTop)
            emojiList.contentY = itemY;
        else if (itemBottom > viewportBottom)
            emojiList.contentY = Math.min(itemBottom - emojiList.height, maxContentY);
    }

    onSelectedIndexChanged: {
        if (selectedIndex === -1 && emojiList.count > 0) {
            emojiList.positionViewAtIndex(0, ListView.Beginning);
        }
        if (expandedItemIndex >= 0 && selectedIndex !== expandedItemIndex) {
            expandedItemIndex = -1;
            selectedOptionIndex = 0;
            keyboardNavigation = false;
        }

        // Reset horizontal focus when leaving recent container
        if (selectedIndex !== 0) {
            selectedRecentIndex = -1;
        } else if (selectedIndex === 0 && emojisModel.count > 0 && emojisModel.get(0).isRecentContainer) {
            if (selectedRecentIndex === -1 && recentEmojis.length > 0) {
                selectedRecentIndex = 0;
            }
        }
    }

    onSearchTextChanged: {
        recentContentX = 0;
        performSearch();
    }

    function clearSearch() {
        searchText = "";
        selectedIndex = -1;
        selectedRecentIndex = -1;
        clearButtonFocused = false;
        resetClearButton();
        searchInput.focusInput();
        loadInitialEmojis();
        emojiList.enableScrollAnimation = false;
        emojiList.contentY = 0;
        Qt.callLater(() => {
            emojiList.enableScrollAnimation = true;
        });
    }

    function clearRecentEmojis() {
        recentEmojis = [];
        saveRecentEmojis();
        updateRecentModel();
        loadInitialEmojis();
        clearButtonFocused = false;
        resetClearButton();
        searchInput.focusInput();
    }

    function focusSearchInput() {
        searchInput.focusInput();
    }

    function resetClearButton() {
        clearButtonConfirmState = false;
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
                if (emoji.emoji.includes(searchText) || emoji.search.toLowerCase().includes(searchLower) || emoji.name.toLowerCase().includes(searchLower) || emoji.slug.toLowerCase().includes(searchLower) || emoji.group.toLowerCase().includes(searchLower)) {
                    filtered.push(emoji);
                }
            }
        }
        filteredEmojis = filtered;
        emojisModel.clear();
        for (var i = 0; i < filtered.length; i++) {
            emojisModel.append({
                emojiId: filtered[i].search,
                emojiData: filtered[i],
                isRecentContainer: false
            });
        }
        if (searchText.length > 0 && filteredEmojis.length > 0) {
            selectedIndex = 0;
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
        emojisModel.clear();
        if (recentEmojis.length > 0 && searchText === "") {
            emojisModel.append({
                emojiId: "recent_container",
                emojiData: {},
                isRecentContainer: true
            });
        }
        var initial = [];
        for (var i = 0; i < Math.min(50, emojiData.length); i++) {
            var e = emojiData[i];
            emojisModel.append({
                emojiId: e.search,
                emojiData: e,
                isRecentContainer: false
            });
            initial.push(e);
        }
        filteredEmojis = initial;
    }

    function loadRecentEmojis() {
        // QUICKSHELL-GIT: recentProcess.command = ["bash", "-c", "cat " + Quickshell.cacheDir + "/emojis.json 2>/dev/null || echo '[]'"];
        recentProcess.command = ["bash", "-c", "cat " + Quickshell.env("HOME") + "/.cache/ambxst" + "/emojis.json 2>/dev/null || echo '[]'"];
        recentProcess.running = true;
    }

    function saveRecentEmojis() {
        var jsonData = JSON.stringify(recentEmojis, null, 2);
        // QUICKSHELL-GIT: saveProcess.command = ["bash", "-c", "echo '" + jsonData.replace(/'/g, "'\\''") + "' > " + Quickshell.cacheDir + "/emojis.json"];
        saveProcess.command = ["bash", "-c", "echo '" + jsonData.replace(/'/g, "'\\''") + "' > " + Quickshell.env("HOME") + "/.cache/ambxst" + "/emojis.json"];
        saveProcess.running = true;
    }

    function addToRecent(emoji) {
        recentEmojis = recentEmojis.filter(item => item.emoji !== emoji.emoji);
        emoji.usage = (emoji.usage || 0) + 1;
        emoji.lastUsed = Date.now();
        recentEmojis.unshift(emoji);
        if (recentEmojis.length > 50)
            recentEmojis = recentEmojis.slice(0, 50);
        recentEmojis.sort((a, b) => b.usage !== a.usage ? b.usage - a.usage : b.lastUsed - a.lastUsed);
        updateRecentModel();
        saveRecentEmojis();
    }

    function copyEmoji(emoji, skinToneModifier) {
        var emojiToCopy = emoji.emoji;
        if (skinToneModifier && skinToneModifier !== "")
            emojiToCopy = emoji.emoji + skinToneModifier;
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
        if (selectedIndex < emojisModel.count - 1) {
            selectedIndex++;
        }
    }

    function onUpPressed() {
        if (selectedIndex > 0) {
            selectedIndex--;
        } else {
            selectedIndex = -1;
        }
    }

    function onLeftPressed() {
        if (selectedIndex === 0 && emojisModel.count > 0 && emojisModel.get(0).isRecentContainer) {
            if (selectedRecentIndex > 0) {
                selectedRecentIndex--;
            }
        }
    }

    function onRightPressed() {
        if (selectedIndex === 0 && emojisModel.count > 0 && emojisModel.get(0).isRecentContainer) {
            if (selectedRecentIndex < recentEmojis.length - 1) {
                selectedRecentIndex++;
            }
        }
    }

    implicitWidth: 464 // 8 emojis (8 * 56) + padding (2 * 8)
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
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    var jsonData = JSON.parse(text.trim());
                    var data = [];
                    for (var emoji in jsonData) {
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
                    emojiData = data;
                    loadInitialEmojis();
                } catch (e) {
                    emojiData = [];
                    loadInitialEmojis();
                }
            }
        }
    }

    Process {
        id: recentProcess
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
    }

    Item {
        id: mainLayout
        anchors.fill: parent

        Row {
            id: searchRow
            width: parent.width
            height: 48
            anchors.top: parent.top
            spacing: 8

            SearchInput {
                id: searchInput
                width: parent.width - (clearButton.visible ? clearButton.width + parent.spacing : 0)
                height: 48
                text: root.searchText
                placeholderText: "Search emojis..."
                prefixIcon: root.prefixIcon

                onSearchTextChanged: text => root.searchText = text
                onBackspaceOnEmpty: root.backspaceOnEmpty()
                onAccepted: {
                    if (root.expandedItemIndex >= 0) {
                        let emoji = emojisModel.get(root.expandedItemIndex).emojiData;
                        var skinTone = root.skinTones[root.selectedOptionIndex];
                        if (skinTone)
                            root.copyEmoji(emoji, skinTone.modifier);
                    } else if (selectedIndex === 0 && emojisModel.count > 0 && emojisModel.get(0).isRecentContainer) {
                        if (selectedRecentIndex >= 0 && selectedRecentIndex < recentEmojis.length) {
                            root.copyEmoji(recentEmojis[selectedRecentIndex]);
                        }
                    } else if (selectedIndex >= 0 && selectedIndex < emojisModel.count) {
                        root.copyEmoji(emojisModel.get(selectedIndex).emojiData);
                    }
                }
                onShiftAccepted: {
                    if (selectedIndex >= 0 && selectedIndex < emojisModel.count) {
                        var item = emojisModel.get(selectedIndex);
                        if (!item.isRecentContainer && item.emojiData.skin_tone_support) {
                            if (root.expandedItemIndex === selectedIndex) {
                                root.expandedItemIndex = -1;
                                root.selectedOptionIndex = 0;
                                root.keyboardNavigation = false;
                            } else {
                                root.expandedItemIndex = selectedIndex;
                                root.selectedOptionIndex = 0;
                                root.keyboardNavigation = true;
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
                        var item = emojisModel.get(root.expandedItemIndex);
                        if (item.emojiData.skin_tone_support && root.selectedOptionIndex < root.skinTones.length - 1) {
                            root.selectedOptionIndex++;
                            root.keyboardNavigation = true;
                        }
                    } else
                        root.onDownPressed();
                }
                onUpPressed: {
                    if (root.expandedItemIndex >= 0) {
                        if (root.selectedOptionIndex > 0) {
                            root.selectedOptionIndex--;
                            root.keyboardNavigation = true;
                        }
                    } else
                        root.onUpPressed();
                }
                onLeftPressed: root.onLeftPressed()
                onRightPressed: root.onRightPressed()
            }

            StyledRect {
                id: clearButton
                width: root.clearButtonConfirmState ? 140 : 48
                height: 48
                radius: searchInput.radius
                variant: {
                    if (root.clearButtonConfirmState)
                        return "error";
                    else if (root.clearButtonFocused || clearButtonMouseArea.containsMouse)
                        return "focus";
                    else
                        return "pane";
                }
                visible: recentEmojis.length > 0 && searchText === ""
                activeFocusOnTab: true

                Behavior on width {
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
                        if (root.clearButtonConfirmState)
                            root.clearRecentEmojis();
                        else
                            root.clearButtonConfirmState = true;
                    }
                }
                Row {
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
                        text: "Clear recent?"
                        height: parent.height
                        font.family: Config.theme.font
                        font.weight: Font.Bold
                        font.pixelSize: Config.theme.fontSize
                        color: clearButton.item
                        opacity: root.clearButtonConfirmState ? 1.0 : 0.0
                        visible: opacity > 0
                        verticalAlignment: Text.AlignVCenter
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Config.animDuration / 2
                                easing.type: Easing.OutQuart
                            }
                        }
                    }
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (root.clearButtonConfirmState)
                            root.clearRecentEmojis();
                        else
                            root.clearButtonConfirmState = true;
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
            clip: true
            model: emojisModel
            currentIndex: root.selectedIndex
            spacing: 0
            property bool enableScrollAnimation: true

            Behavior on contentY {
                enabled: Config.animDuration > 0 && emojiList.enableScrollAnimation && !emojiList.moving
                NumberAnimation {
                    duration: Config.animDuration / 2
                    easing.type: Easing.OutCubic
                }
            }

            onCurrentIndexChanged: {
                if (currentIndex !== root.selectedIndex)
                    root.selectedIndex = currentIndex;
                if (currentIndex >= 0) {
                    var itemY = 0;
                    for (var i = 0; i < currentIndex && i < emojisModel.count; i++) {
                        var h = 48;
                        var item = emojisModel.get(i);
                        if (i === root.expandedItemIndex && item && item.emojiData && item.emojiData.skin_tone_support) {
                            h = 48 + 4 + (36 * Math.min(3, root.skinTones.length)) + 8;
                        }
                        itemY += h;
                    }
                    var currentItemHeight = 48;
                    if (currentIndex === root.expandedItemIndex && currentIndex < emojisModel.count) {
                        var item = emojisModel.get(currentIndex);
                        if (item && item.emojiData && item.emojiData.skin_tone_support) {
                            currentItemHeight = 48 + 4 + (36 * Math.min(3, root.skinTones.length)) + 8;
                        }
                    }
                    if (itemY < emojiList.contentY)
                        emojiList.contentY = itemY;
                    else if (itemY + currentItemHeight > emojiList.contentY + emojiList.height)
                        emojiList.contentY = itemY + currentItemHeight - emojiList.height;
                }
            }

            delegate: Rectangle {
                id: delegateRoot
                required property var emojiData
                required property bool isRecentContainer
                required property int index
                width: emojiList.width
                height: {
                    if (isRecentContainer)
                        return 48;
                    if (index === root.expandedItemIndex && emojiData.skin_tone_support) {
                        return 48 + 4 + (36 * Math.min(3, root.skinTones.length)) + 8;
                    }
                    return 48;
                }
                color: "transparent"

                Loader {
                    anchors.fill: parent
                    sourceComponent: isRecentContainer ? recentContainerComponent : normalEmojiComponent
                }

                Component {
                    id: recentContainerComponent
                    Item {
                        anchors.fill: parent
                        ListView {
                            id: horizontalRecent
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            orientation: ListView.Horizontal
                            spacing: 0
                            model: recentModel
                            currentIndex: root.selectedRecentIndex
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            // Drag support
                            interactive: true

                            property bool enableScrollAnimation: true

                            Behavior on contentX {
                                enabled: Config.animDuration > 0 && horizontalRecent.enableScrollAnimation && !horizontalRecent.moving
                                NumberAnimation {
                                    duration: Config.animDuration / 2
                                    easing.type: Easing.OutCubic
                                }
                            }

                            // Wheel support (Shift+Scroll)
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.NoButton
                                onWheel: wheel => {
                                    if (wheel.modifiers & Qt.ShiftModifier) {
                                        horizontalRecent.contentX = Math.max(0, Math.min(horizontalRecent.contentWidth - horizontalRecent.width, horizontalRecent.contentX - (wheel.angleDelta.y || wheel.angleDelta.x)));
                                        wheel.accepted = true;
                                    }
                                }
                            }

                            onCurrentIndexChanged: {
                                if (currentIndex !== root.selectedRecentIndex && root.selectedIndex === delegateRoot.index) {
                                    root.selectedRecentIndex = currentIndex;
                                }

                                if (currentIndex >= 0 && root.selectedIndex === delegateRoot.index) {
                                    var itemX = currentIndex * 56;
                                    var viewportLeft = horizontalRecent.contentX;
                                    var viewportRight = viewportLeft + horizontalRecent.width;

                                    if (itemX < viewportLeft) {
                                        horizontalRecent.contentX = itemX;
                                    } else if (itemX + 56 > viewportRight) {
                                        horizontalRecent.contentX = itemX + 56 - horizontalRecent.width;
                                    }
                                }
                            }

                            onContentXChanged: {
                                if (root.selectedIndex === delegateRoot.index) {
                                    root.recentContentX = contentX;
                                }
                            }

                            Binding {
                                target: root
                                property: "recentContentX"
                                value: horizontalRecent.contentX
                                when: root.selectedIndex === delegateRoot.index
                            }

                            delegate: Rectangle {
                                width: 56
                                height: 48
                                color: "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: model.emojiData.emoji
                                    font.pixelSize: 24
                                    color: Colors.overSurface
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: {
                                        root.selectedIndex = delegateRoot.index;
                                        root.selectedRecentIndex = model.index;
                                    }
                                    onClicked: root.copyEmoji(model.emojiData)
                                }
                            }
                        }
                    }
                }

                Component {
                    id: normalEmojiComponent
                    Item {
                        anchors.fill: parent
                        property bool isSelected: root.selectedIndex === index

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: {
                                root.selectedIndex = index;
                                root.selectedRecentIndex = -1;
                            }
                            onClicked: {
                                if (emojiData.skin_tone_support) {
                                    if (root.expandedItemIndex === index)
                                        root.expandedItemIndex = -1;
                                    else {
                                        root.expandedItemIndex = index;
                                        root.selectedOptionIndex = 0;
                                    }
                                } else
                                    root.copyEmoji(emojiData);
                            }
                        }

                        Row {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8
                            StyledRect {
                                id: iconBg
                                width: 32
                                height: 32
                                radius: Styling.radius(-4)
                                variant: isSelected && root.expandedItemIndex !== index ? "overprimary" : "common"
                                Text {
                                    anchors.centerIn: parent
                                    text: emojiData.emoji
                                    font.pixelSize: 24
                                    color: iconBg.item
                                }
                            }
                            Text {
                                width: parent.width - 40
                                height: parent.height
                                text: emojiData.search
                                color: isSelected ? (root.expandedItemIndex === index ? Colors.overSurface : Styling.srItem("primary")) : Colors.overSurface
                                font.family: Config.theme.font
                                font.weight: Font.Bold
                                font.pixelSize: Config.theme.fontSize
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        RowLayout {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 8
                            anchors.bottomMargin: 8
                            spacing: 4
                            visible: index === root.expandedItemIndex && emojiData.skin_tone_support
                            opacity: visible ? 1 : 0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Config.animDuration
                                    easing.type: Easing.OutQuart
                                }
                            }

                            ClippingRectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 36 * Math.min(3, root.skinTones.length)
                                color: Colors.background
                                radius: Styling.radius(0)
                                ListView {
                                    id: skinToneList
                                    anchors.fill: parent
                                    clip: true
                                    model: root.skinTones
                                    currentIndex: root.selectedOptionIndex
                                    highlight: StyledRect {
                                        variant: "primary"
                                        radius: Styling.radius(0)
                                        z: -1
                                    }
                                    delegate: Item {
                                        width: skinToneList.width
                                        height: 36
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            spacing: 8
                                            Text {
                                                text: emojiData.emoji + modelData.modifier
                                                font.pixelSize: 20
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.name
                                                font.family: Config.theme.font
                                                font.pixelSize: Config.theme.fontSize
                                                color: skinToneList.currentIndex === index ? Styling.srItem("primary") : Colors.overSurface
                                            }
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onEntered: {
                                                skinToneList.currentIndex = index;
                                                root.selectedOptionIndex = index;
                                            }
                                            onClicked: root.copyEmoji(emojiData, modelData.modifier)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            highlight: Item {
                id: listHighlight
                z: -1
                width: root.isAtRecent ? 40 : emojiList.width
                x: root.isAtRecent ? root.recentX - root.recentContentX : 0
                y: {
                    var yPos = 0;
                    for (var i = 0; i < emojiList.currentIndex && i < emojisModel.count; i++) {
                        var h = 48;
                        var item = emojisModel.get(i);
                        if (i === root.expandedItemIndex && item && item.emojiData && item.emojiData.skin_tone_support) {
                            h = 48 + 4 + (36 * Math.min(3, root.skinTones.length)) + 8;
                        }
                        yPos += h;
                    }
                    if (root.isAtRecent)
                        yPos += 4;
                    return yPos;
                }
                height: {
                    if (emojiList.currentIndex === -1)
                        return 0;
                    var item = emojisModel.get(emojiList.currentIndex);
                    if (item && item.isRecentContainer)
                        return 40;
                    if (item && item.emojiData && item.emojiData.skin_tone_support && emojiList.currentIndex === root.expandedItemIndex) {
                        return 48 + 4 + (36 * Math.min(3, root.skinTones.length)) + 8;
                    }
                    return 48;
                }

                Behavior on x {
                    enabled: Config.animDuration > 0 && !emojiList.moving
                    NumberAnimation {
                        duration: Config.animDuration / 2
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on y {
                    NumberAnimation {
                        duration: Config.animDuration / 2
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on width {
                    NumberAnimation {
                        duration: Config.animDuration / 2
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on height {
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                }

                StyledRect {
                    anchors.fill: parent
                    radius: Styling.radius(4)
                    variant: root.expandedItemIndex === emojiList.currentIndex ? "pane" : "primary"
                    visible: root.selectedIndex >= 0
                }
            }
            highlightFollowsCurrentItem: false
        }
    }

    Component.onCompleted: {
        loadEmojiData();
        loadRecentEmojis();
        Qt.callLater(() => focusSearchInput());
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: focusSearchInput()
    }
}
