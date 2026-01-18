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

    property string searchText: ""
    property int selectedIndex: -1
    property var presets: []
    property var filteredPresets: []

    // Active preset (from persistent storage)
    readonly property string activePreset: PresetsService.activePreset

    // Available config files
    readonly property var availableConfigFiles: ["ai.js", "bar.js", "desktop.js", "dock.js", "hyprland.js", "lockscreen.js", "notch.js", "overview.js", "performance.js", "prefix.js", "theme.js", "weather.js", "workspaces.js"]

    // List model
    ListModel {
        id: presetsModel
    }

    // Delete mode state
    property bool deleteMode: false
    property string presetToDelete: ""
    property int originalSelectedIndex: -1
    property int deleteButtonIndex: 0 // 0 = cancel, 1 = confirm

    // Rename mode state
    property bool renameMode: false
    property string presetToRename: ""
    property string newPresetName: ""
    property int renameSelectedIndex: -1
    property int renameButtonIndex: 0 // 0 = cancel, 1 = confirm
    property string pendingRenamedPreset: ""

    // Update mode state
    property bool updateMode: false
    property string presetToUpdate: ""
    property var selectedConfigFiles: []
    property int updateSelectedIndex: -1

    // Options menu state (expandable list)
    property int expandedItemIndex: -1
    property int selectedOptionIndex: 0
    property bool keyboardNavigation: false

    property alias flickable: resultsList
    property bool needsScrollbar: resultsList.contentHeight > resultsList.height

    // Helper function to get options for a preset
    function getPresetOptions(preset) {
        if (!preset) return [];

        var options = [];
        
        if (preset.authorUrl && preset.authorUrl !== "") {
            options.push({
                text: "Visit Author",
                icon: Icons.globe,
                highlightColor: Colors.primary,
                textColor: Styling.srItem("primary"),
                action: function () {
                    Qt.openUrlExternally(preset.authorUrl);
                }
            });
        }

        if (!preset.isOfficial) {
            options.push({
                text: "Rename",
                icon: Icons.edit,
                highlightColor: Colors.secondary,
                textColor: Styling.srItem("secondary"),
                action: function () {
                    root.enterRenameMode(preset.name);
                    root.expandedItemIndex = -1;
                }
            });
        }

        options.push({
            text: "Update",
            icon: Icons.arrowCounterClockwise,
            highlightColor: Colors.tertiary,
            textColor: Styling.srItem("tertiary"),
            action: function () {
                root.enterUpdateMode(preset.name);
                root.expandedItemIndex = -1;
            }
        });

        if (!preset.isOfficial) {
            options.push({
                text: "Delete",
                icon: Icons.trash,
                highlightColor: Colors.error,
                textColor: Styling.srItem("error"),
                action: function () {
                    root.enterDeleteMode(preset.name);
                    root.expandedItemIndex = -1;
                }
            });
        }

        return options;
    }

    onExpandedItemIndexChanged: {}

    function adjustScrollForExpandedItem(index) {
        if (index < 0 || index >= presetsModel.count)
            return;

        var itemY = 0;
        for (var i = 0; i < index; i++) {
            itemY += 48;
        }
        
        // Calculate height based on options
        let presetItem = presetsModel.get(index);
        let optionsCount = 3; // default
        if (presetItem && presetItem.presetData) {
            optionsCount = getPresetOptions(presetItem.presetData).length;
        }

        var listHeight = 36 * optionsCount;
        var expandedHeight = 48 + 4 + listHeight + 8;

        var maxContentY = Math.max(0, resultsList.contentHeight - resultsList.height);
        var viewportTop = resultsList.contentY;
        var viewportBottom = viewportTop + resultsList.height;
        var itemBottom = itemY + expandedHeight;

        if (itemY < viewportTop) {
            resultsList.contentY = itemY;
        } else if (itemBottom > viewportBottom) {
            resultsList.contentY = Math.min(itemBottom - resultsList.height, maxContentY);
        }
    }

    onSelectedIndexChanged: {
        if (selectedIndex === -1 && resultsList.count > 0) {
            resultsList.positionViewAtIndex(0, ListView.Beginning);
        }

        if (expandedItemIndex >= 0 && selectedIndex !== expandedItemIndex) {
            expandedItemIndex = -1;
            selectedOptionIndex = 0;
            keyboardNavigation = false;
        }
    }

    onSearchTextChanged: {
        updateFilteredPresets();
    }

    function resetSearch() {
        searchText = "";
        selectedIndex = -1;
        deleteMode = false;
        renameMode = false;
        updateMode = false;
        expandedItemIndex = -1;
        searchInput.focusInput();
        updateFilteredPresets();
    }

    function focusSearchInput() {
        searchInput.focusInput();
    }

    function cancelModesFromExternal() {
        if (deleteMode)
            cancelDeleteMode();
        if (renameMode)
            cancelRenameMode();
        if (updateMode)
            cancelUpdateMode();
    }

    function updateFilteredPresets() {
        var newFilteredPresets = [];
        var createButtonText = "Create new preset";
        var isCreateSpecific = false;
        var presetNameToCreate = "";

        if (searchText.length === 0) {
            newFilteredPresets = presets.slice();
        } else {
            newFilteredPresets = presets.filter(function (preset) {
                return preset.name.toLowerCase().includes(searchText.toLowerCase());
            });

            let exactMatch = presets.find(function (preset) {
                return preset.name.toLowerCase() === searchText.toLowerCase();
            });

            if (!exactMatch && searchText.length > 0) {
                createButtonText = `Create preset "${searchText}"`;
                isCreateSpecific = true;
                presetNameToCreate = searchText;
            }
        }

        if (!deleteMode && !renameMode && !updateMode) {
            newFilteredPresets.unshift({
                name: createButtonText,
                isCreateButton: !isCreateSpecific,
                isCreateSpecificButton: isCreateSpecific,
                presetNameToCreate: presetNameToCreate,
                configFiles: [],
                icon: "plus",
                isOfficial: false
            });
        }

        filteredPresets = newFilteredPresets;
        resultsList.enableScrollAnimation = false;
        resultsList.contentY = 0;

        presetsModel.clear();
        for (var i = 0; i < newFilteredPresets.length; i++) {
            var preset = newFilteredPresets[i];
            var presetId = (preset.isCreateButton || preset.isCreateSpecificButton) ? "__create__" : preset.name;

            presetsModel.append({
                presetId: presetId,
                presetData: preset
            });
        }

        Qt.callLater(() => {
            resultsList.enableScrollAnimation = true;
        });

        if (!deleteMode && !renameMode && !updateMode) {
            if (searchText.length > 0 && newFilteredPresets.length > 0) {
                selectedIndex = 0;
                resultsList.currentIndex = 0;
            } else if (searchText.length === 0) {
                selectedIndex = -1;
                resultsList.currentIndex = -1;
            }
        }

        if (pendingRenamedPreset !== "") {
            for (let i = 0; i < newFilteredPresets.length; i++) {
                if (newFilteredPresets[i].name === pendingRenamedPreset) {
                    selectedIndex = i;
                    resultsList.currentIndex = i;
                    pendingRenamedPreset = "";
                    break;
                }
            }
            if (pendingRenamedPreset !== "") {
                pendingRenamedPreset = "";
            }
        }
    }

    // Delete mode functions
    function enterDeleteMode(presetName) {
        originalSelectedIndex = selectedIndex;
        deleteMode = true;
        presetToDelete = presetName;
        deleteButtonIndex = 0;
        root.forceActiveFocus();
    }

    function cancelDeleteMode() {
        deleteMode = false;
        presetToDelete = "";
        deleteButtonIndex = 0;
        searchInput.focusInput();
        updateFilteredPresets();
        selectedIndex = originalSelectedIndex;
        resultsList.currentIndex = originalSelectedIndex;
        originalSelectedIndex = -1;
    }

    function confirmDeletePreset() {
        PresetsService.deletePreset(presetToDelete);
        cancelDeleteMode();
    }

    // Rename mode functions
    function enterRenameMode(presetName) {
        renameSelectedIndex = selectedIndex;
        renameMode = true;
        presetToRename = presetName;
        newPresetName = presetName;
        renameButtonIndex = 1;
        root.forceActiveFocus();
    }

    function cancelRenameMode() {
        renameMode = false;
        presetToRename = "";
        newPresetName = "";
        renameButtonIndex = 1;
        if (pendingRenamedPreset === "") {
            searchInput.focusInput();
            updateFilteredPresets();
            selectedIndex = renameSelectedIndex;
            resultsList.currentIndex = renameSelectedIndex;
        } else {
            searchInput.focusInput();
        }
        renameSelectedIndex = -1;
    }

    function confirmRenamePreset() {
        if (newPresetName.trim() !== "" && newPresetName !== presetToRename) {
            pendingRenamedPreset = newPresetName.trim();
            PresetsService.renamePreset(presetToRename, newPresetName.trim());
        }
        cancelRenameMode();
    }

    // Update mode functions
    function enterUpdateMode(presetName) {
        updateSelectedIndex = selectedIndex;
        updateMode = true;
        presetToUpdate = presetName;

        // Pre-select the config files that are already in this preset
        const preset = presets.find(p => p.name === presetName);
        if (preset) {
            selectedConfigFiles = preset.configFiles.slice();
        } else {
            selectedConfigFiles = [];
        }
        root.forceActiveFocus();
    }

    function cancelUpdateMode() {
        updateMode = false;
        presetToUpdate = "";
        selectedConfigFiles = [];
        searchInput.focusInput();
        updateFilteredPresets();
        selectedIndex = updateSelectedIndex;
        resultsList.currentIndex = updateSelectedIndex;
        updateSelectedIndex = -1;
    }

    function confirmUpdatePreset() {
        if (selectedConfigFiles.length > 0) {
            PresetsService.updatePreset(presetToUpdate, selectedConfigFiles);
        }
        cancelUpdateMode();
    }

    // Create preset functions
    function createPreset(presetName) {
        if (presetName && presetName.trim() !== "") {
            // For create, select all config files by default
            PresetsService.savePreset(presetName.trim(), availableConfigFiles);
        }
        Visibilities.setActiveModule("");
    }

    function loadPreset(presetName) {
        PresetsService.loadPreset(presetName);
        Visibilities.setActiveModule("");
    }

    Connections {
        target: PresetsService
        function onPresetsUpdated() {
            root.presets = PresetsService.presets;
            updateFilteredPresets();
        }
    }

    Component.onCompleted: {
        root.presets = PresetsService.presets;
        updateFilteredPresets();
    }

    implicitWidth: 400
    implicitHeight: 7 * 48 + 56

    MouseArea {
        anchors.fill: parent
        enabled: root.deleteMode || root.renameMode || root.updateMode
        z: -10

        onClicked: {
            if (root.deleteMode) {
                root.cancelDeleteMode();
            } else if (root.renameMode) {
                root.cancelRenameMode();
            } else if (root.updateMode) {
                root.cancelUpdateMode();
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

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        // Search Input
        SearchInput {
            id: searchInput
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            text: root.searchText
            placeholderText: "Search or create preset..."

            onSearchTextChanged: text => {
                root.searchText = text;
            }

            onAccepted: {
                if (root.deleteMode) {
                    root.cancelDeleteMode();
                } else if (root.expandedItemIndex >= 0) {
                    let preset = root.filteredPresets[root.expandedItemIndex];
                    if (preset && !preset.isCreateButton && !preset.isCreateSpecificButton) {
                        let options = root.getPresetOptions(preset);

                        if (root.selectedOptionIndex >= 0 && root.selectedOptionIndex < options.length) {
                            options[root.selectedOptionIndex].action();
                        }
                    }
                } else {
                    if (root.selectedIndex >= 0 && root.selectedIndex < resultsList.count) {
                        let selectedPreset = root.filteredPresets[root.selectedIndex];
                        if (selectedPreset) {
                            if (selectedPreset.isCreateSpecificButton) {
                                root.createPreset(selectedPreset.presetNameToCreate);
                            } else if (selectedPreset.isCreateButton) {
                                // Generic create - use search text if any
                                root.createPreset(root.searchText || "New Preset");
                            } else {
                                root.loadPreset(selectedPreset.name);
                            }
                        }
                    }
                }
            }

            onShiftAccepted: {
                if (!root.deleteMode && !root.renameMode && !root.updateMode) {
                    if (root.selectedIndex >= 0 && root.selectedIndex < resultsList.count) {
                        let selectedPreset = root.filteredPresets[root.selectedIndex];
                        if (selectedPreset && !selectedPreset.isCreateButton && !selectedPreset.isCreateSpecificButton) {
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
                } else if (!root.deleteMode && !root.renameMode && !root.updateMode) {
                    Visibilities.setActiveModule("");
                }
            }

            onDownPressed: {
                if (root.expandedItemIndex >= 0) {
                    if (root.selectedOptionIndex < 2) {
                        root.selectedOptionIndex++;
                        root.keyboardNavigation = true;
                    }
                } else if (!root.deleteMode && !root.renameMode && !root.updateMode && resultsList.count > 0) {
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
                    if (root.selectedOptionIndex > 0) {
                        root.selectedOptionIndex--;
                        root.keyboardNavigation = true;
                    }
                } else if (!root.deleteMode && !root.renameMode && !root.updateMode) {
                    if (root.selectedIndex > 0) {
                        root.selectedIndex--;
                        resultsList.currentIndex = root.selectedIndex;
                    } else if (root.selectedIndex === 0 && root.searchText.length === 0) {
                        root.selectedIndex = -1;
                        resultsList.currentIndex = -1;
                    }
                }
            }
        }

        // List View
        ListView {
            id: resultsList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            interactive: !root.deleteMode && !root.renameMode && !root.updateMode && root.expandedItemIndex === -1
            cacheBuffer: 96
            reuseItems: false

            property bool isScrolling: dragging || flicking
            property bool enableScrollAnimation: true

            model: presetsModel
            currentIndex: root.selectedIndex

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

                if (currentIndex >= 0) {
                    var itemY = 0;
                    for (var i = 0; i < currentIndex && i < presetsModel.count; i++) {
                        var itemHeight = 48;
                        if (i === root.expandedItemIndex && !root.deleteMode && !root.renameMode && !root.updateMode) {
                            let pItem = presetsModel.get(i);
                            let optCount = pItem && pItem.presetData ? root.getPresetOptions(pItem.presetData).length : 3;
                            var listHeight = 36 * optCount;
                            itemHeight = 48 + 4 + listHeight + 8;
                        }
                        itemY += itemHeight;
                    }

                    var currentItemHeight = 48;
                    if (currentIndex === root.expandedItemIndex && !root.deleteMode && !root.renameMode && !root.updateMode) {
                        let pItem = presetsModel.get(currentIndex);
                        let optCount = pItem && pItem.presetData ? root.getPresetOptions(pItem.presetData).length : 3;
                        var listHeight = 36 * optCount;
                        currentItemHeight = 48 + 4 + listHeight + 8;
                    }

                    var viewportTop = resultsList.contentY;
                    var viewportBottom = viewportTop + resultsList.height;

                    if (itemY < viewportTop) {
                        resultsList.contentY = itemY;
                    } else if (itemY + currentItemHeight > viewportBottom) {
                        resultsList.contentY = itemY + currentItemHeight - resultsList.height;
                    }
                }
            }


            delegate: Rectangle {
                required property string presetId
                required property var presetData
                required property int index

                property var modelData: presetData

                width: resultsList.width
                height: {
                    let baseHeight = 48;
                    if (index === root.expandedItemIndex && !isInDeleteMode && !isInRenameMode && !isInUpdateMode) {
                        let options = root.getPresetOptions(modelData);
                        var listHeight = 36 * options.length;
                        return baseHeight + 4 + listHeight + 8;
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

                property bool isInDeleteMode: root.deleteMode && modelData.name === root.presetToDelete
                property bool isInRenameMode: root.renameMode && modelData.name === root.presetToRename
                property bool isInUpdateMode: root.updateMode && modelData.name === root.presetToUpdate
                property bool isExpanded: index === root.expandedItemIndex
                property bool isActive: (!modelData.isCreateButton && !modelData.isCreateSpecificButton) ? (modelData.name === root.activePreset) : false
                property color textColor: {
                    if (isInDeleteMode) {
                        return Styling.srItem("error");
                    } else if (isInRenameMode) {
                        return Styling.srItem("secondary");
                    } else if (isInUpdateMode) {
                        return Styling.srItem("tertiary");
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
                    enabled: !isInDeleteMode && !isInRenameMode && !isInUpdateMode
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    onEntered: {
                        if (resultsList.isScrolling)
                            return;
                        if (!root.deleteMode && !root.renameMode && !root.updateMode && root.expandedItemIndex === -1) {
                            root.selectedIndex = index;
                            resultsList.currentIndex = index;
                        }
                    }

                    onClicked: mouse => {
                        if (mouse.button === Qt.LeftButton) {
                            if (root.deleteMode && modelData.name !== root.presetToDelete) {
                                root.cancelDeleteMode();
                                return;
                            } else if (root.renameMode && modelData.name !== root.presetToRename) {
                                root.cancelRenameMode();
                                return;
                            } else if (root.updateMode && modelData.name !== root.presetToUpdate) {
                                root.cancelUpdateMode();
                                return;
                            }

                            if (!root.deleteMode && !root.renameMode && !root.updateMode && !isExpanded) {
                                if (modelData.isCreateSpecificButton) {
                                    root.createPreset(modelData.presetNameToCreate);
                                } else if (modelData.isCreateButton) {
                                    root.createPreset(root.searchText || "New Preset");
                                } else {
                                    root.loadPreset(modelData.name);
                                }
                            }
                        } else if (mouse.button === Qt.RightButton) {
                            if (root.deleteMode) {
                                root.cancelDeleteMode();
                                return;
                            } else if (root.renameMode) {
                                root.cancelRenameMode();
                                return;
                            } else if (root.updateMode) {
                                root.cancelUpdateMode();
                                return;
                            }

                            if (!modelData.isCreateButton && !modelData.isCreateSpecificButton) {
                                if (root.expandedItemIndex === index) {
                                    root.expandedItemIndex = -1;
                                    root.selectedOptionIndex = 0;
                                    root.keyboardNavigation = false;
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
                    visible: isExpanded && !isInDeleteMode && !isInRenameMode && !isInUpdateMode
                    opacity: (isExpanded && !isInDeleteMode && !isInRenameMode && !isInUpdateMode) ? 1 : 0

                    Behavior on opacity {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutQuart
                        }
                    }

                    ClippingRectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36 * optionsListView.count
                        color: Colors.background
                        radius: Styling.radius(0)

                        ListView {
                            id: optionsListView
                            anchors.fill: parent
                            clip: true
                            interactive: false
                            boundsBehavior: Flickable.StopAtBounds
                            model: root.getPresetOptions(modelData)
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
                                            if (item.highlightColor === Colors.tertiary)
                                                return "tertiary";
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

                // Rename action buttons
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

                        x: Math.min(idx1X, idx2X) * 36 + activeButtonMargin
                        y: activeButtonMargin
                        width: Math.abs(idx1X - idx2X) * 36 + 32 - activeButtonMargin * 2
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
                        anchors.fill: parent
                        spacing: 4

                        Rectangle {
                            id: renameCancelButton
                            width: 32
                            height: 32
                            color: "transparent"
                            radius: 6
                            z: 1
                            property bool isHighlighted: root.renameButtonIndex === 0

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.cancelRenameMode()
                                onEntered: root.renameButtonIndex = 0
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
                                onClicked: root.confirmRenamePreset()
                                onEntered: root.renameButtonIndex = 1
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

                // Delete action buttons
                Rectangle {
                    id: deleteActionContainer
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

                        x: Math.min(idx1X, idx2X) * 36 + activeButtonMargin
                        y: activeButtonMargin
                        width: Math.abs(idx1X - idx2X) * 36 + 32 - activeButtonMargin * 2
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
                        anchors.fill: parent
                        spacing: 4

                        Rectangle {
                            id: deleteCancelButton
                            width: 32
                            height: 32
                            color: "transparent"
                            radius: 6
                            z: 1
                            property bool isHighlighted: root.deleteButtonIndex === 0

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.cancelDeleteMode()
                                onEntered: root.deleteButtonIndex = 0
                            }

                            Text {
                                anchors.centerIn: parent
                                text: Icons.cancel
                                color: deleteCancelButton.isHighlighted ? Colors.overErrorContainer : Colors.overError
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
                            id: deleteConfirmButton
                            width: 32
                            height: 32
                            color: "transparent"
                            radius: 6
                            z: 1
                            property bool isHighlighted: root.deleteButtonIndex === 1

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.confirmDeletePreset()
                                onEntered: root.deleteButtonIndex = 1
                            }

                            Text {
                                anchors.centerIn: parent
                                text: Icons.accept
                                color: deleteConfirmButton.isHighlighted ? Colors.overErrorContainer : Colors.overError
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

                // Main content row
                RowLayout {
                    id: mainContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 8
                    anchors.rightMargin: isInRenameMode || isInDeleteMode ? 84 : 8
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
                            if (isInDeleteMode)
                                return "overerror";
                            if (isInRenameMode)
                                return "oversecondary";
                            if (isInUpdateMode)
                                return "overtertiary";
                            if (root.selectedIndex === index)
                                return "overprimary";
                            if (modelData.isCreateButton || modelData.isCreateSpecificButton)
                                return "primary";
                            return "common";
                        }
                        radius: Styling.radius(-4)

                        Text {
                            anchors.centerIn: parent
                            text: {
                                if (isInDeleteMode)
                                    return Icons.alert;
                                if (isInRenameMode)
                                    return Icons.edit;
                                if (isInUpdateMode)
                                    return Icons.arrowCounterClockwise;
                                if (modelData.isCreateButton || modelData.isCreateSpecificButton)
                                    return Icons.plus;
                                if (isActive)
                                    return Icons.accept;
                                return Icons.magicWand;
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
                                if (root.renameMode && modelData.name === root.presetToRename) {
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
                                            return `Delete "${root.presetToDelete}"?`;
                                        } else if (isInUpdateMode && !modelData.isCreateButton && !modelData.isCreateSpecificButton) {
                                            return `Update "${root.presetToUpdate}"`;
                                        } else {
                                            return modelData.name;
                                        }
                                    }
                                    color: textColor
                                    font.family: Config.theme.font
                                    font.pixelSize: Config.theme.fontSize
                                    font.weight: isInDeleteMode || isActive ? Font.Bold : (modelData.isCreateButton ? Font.Medium : Font.Bold)
                                    elide: Text.ElideRight
                                }
                        }

                        Component {
                            id: renameTextInput
                            TextField {
                                text: root.newPresetName
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
                                    root.newPresetName = text;
                                }

                                Component.onCompleted: {
                                    Qt.callLater(() => {
                                        forceActiveFocus();
                                        selectAll();
                                    });
                                }

                                Keys.onPressed: event => {
                                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                        root.confirmRenamePreset();
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

                        // Subtitle
                        Text {
                            visible: !isInRenameMode && !isInUpdateMode
                            text: {
                                if (modelData.isCreateButton || modelData.isCreateSpecificButton) {
                                    return "Tap to create";
                                }
                                return modelData.author ? modelData.author : "Unknown";
                            }
                            color: root.selectedIndex === index ? Styling.srItem("primary") : Colors.outline
                            opacity: 0.7
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                        }
                    }

                        // Official badge
                        StyledRect {
                            visible: modelData.isOfficial && !modelData.isCreateButton && !modelData.isCreateSpecificButton && !isInDeleteMode && !isInRenameMode && !isInUpdateMode
                            Layout.preferredHeight: 20
                            Layout.preferredWidth: 65
                            variant: "pane"
                            radius: 10

                            Text {
                                anchors.centerIn: parent
                                text: "OFFICIAL"
                                font.family: Config.theme.font
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                color: Styling.srItem("pane")
                            }
                        }

                        // Active badge
                        StyledRect {
                        id: activeBadge
                        visible: isActive && !modelData.isCreateButton && !modelData.isCreateSpecificButton && !isInDeleteMode && !isInRenameMode && !isInUpdateMode
                        Layout.preferredHeight: 20
                        Layout.preferredWidth: 60
                        variant: root.selectedIndex === index ? "overprimary" : "primary"
                        radius: 10

                        Text {
                            anchors.centerIn: parent
                            text: "ACTIVE"
                            font.family: Config.theme.font
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            color: root.selectedIndex === index ? activeBadge.item : Styling.srItem("primary")
                        }
                    }
                }
            }

            highlight: Item {
                width: resultsList.width
                height: {
                    let baseHeight = 48;
                    if (resultsList.currentIndex === root.expandedItemIndex && !root.deleteMode && !root.renameMode && !root.updateMode) {
                        let pItem = presetsModel.get(resultsList.currentIndex);
                        let optCount = pItem && pItem.presetData ? root.getPresetOptions(pItem.presetData).length : 3;
                        var listHeight = 36 * optCount;
                        return baseHeight + 4 + listHeight + 8;
                    }
                    return baseHeight;
                }

                y: {
                    var yPos = 0;
                    for (var i = 0; i < resultsList.currentIndex && i < presetsModel.count; i++) {
                        var itemHeight = 48;
                        if (i === root.expandedItemIndex && !root.deleteMode && !root.renameMode && !root.updateMode) {
                            let pItem = presetsModel.get(i);
                            let optCount = pItem && pItem.presetData ? root.getPresetOptions(pItem.presetData).length : 3;
                            var listHeight = 36 * optCount;
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
                            adjustScrollForExpandedItem(root.expandedItemIndex);
                        });
                    }
                }

                StyledRect {
                    anchors.fill: parent
                    variant: {
                        if (root.deleteMode)
                            return "error";
                        if (root.renameMode)
                            return "secondary";
                        if (root.updateMode)
                            return "tertiary";
                        if (root.expandedItemIndex >= 0 && root.selectedIndex === root.expandedItemIndex)
                            return "pane";
                        return "primary";
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

            MouseArea {
                anchors.fill: parent
                enabled: root.deleteMode || root.renameMode || root.updateMode || root.expandedItemIndex >= 0
                z: 1000
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                function isClickInsideActiveItem(mouseY) {
                    var activeIndex = -1;
                    var isExpanded = false;

                    if (root.deleteMode || root.renameMode || root.updateMode) {
                        activeIndex = root.selectedIndex;
                    } else if (root.expandedItemIndex >= 0) {
                        activeIndex = root.expandedItemIndex;
                        isExpanded = true;
                    }

                    if (activeIndex < 0)
                        return false;

                    var itemY = activeIndex * 48;
                    // Correct Y calculation requires summing previous heights, as they are variable
                    if (activeIndex > 0) {
                         // This simple calculation (activeIndex * 48) is WRONG when items have variable heights.
                         // However, since only ONE item can be expanded at a time:
                         // 1. If the expanded item is BEFORE activeIndex, activeIndex will be pushed down.
                         // 2. If the expanded item IS activeIndex, its top is normal (unless pushed by previous).
                         
                         // Re-calculate itemY correctly:
                         itemY = 0;
                         for (var i = 0; i < activeIndex; i++) {
                             var h = 48;
                             if (i === root.expandedItemIndex) { // logic for expanded item
                                 let pItem = presetsModel.get(i);
                                 let optCount = pItem && pItem.presetData ? root.getPresetOptions(pItem.presetData).length : 3;
                                 var lHeight = 36 * optCount;
                                 h = 48 + 4 + lHeight + 8;
                             }
                             itemY += h;
                         }
                    }

                    var itemHeight = 48;
                    if (isExpanded) {
                        let pItem = presetsModel.get(activeIndex);
                        let optCount = pItem && pItem.presetData ? root.getPresetOptions(pItem.presetData).length : 3;
                        var listHeight = 36 * optCount;
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
                    } else if (root.updateMode) {
                        if (!isClickInsideActiveItem(mouse.y)) {
                            root.cancelUpdateMode();
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
        }
    }

    // Update Mode Overlay
    Rectangle {
        id: updateOverlay
        anchors.fill: parent
        color: Colors.background
        visible: updateMode
        radius: 20

        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                StyledRect {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    variant: "overtertiary"
                    radius: Styling.radius(-4)

                    Text {
                        anchors.centerIn: parent
                        text: Icons.arrowCounterClockwise
                        font.family: Icons.font
                        font.pixelSize: 16
                        color: Styling.srItem("overtertiary")
                    }
                }

                Text {
                    text: `Update "${root.presetToUpdate}"`
                    font.family: Config.theme.font
                    font.pixelSize: Config.theme.fontSize + 2
                    font.weight: Font.Bold
                    color: Colors.overSurface
                    Layout.fillWidth: true
                }
            }

            Text {
                text: "Select config files to update:"
                color: Colors.outline
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
            }

            // File Selection Grid
            GridLayout {
                columns: 2
                Layout.fillWidth: true
                Layout.fillHeight: true
                columnSpacing: 8
                rowSpacing: 4

                Repeater {
                    model: availableConfigFiles
                    delegate: Item {
                        id: fileDelegate
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28

                        property string fileName: modelData ? modelData : ""
                        property bool checked: root.selectedConfigFiles.includes(fileName)

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (fileDelegate.checked) {
                                    root.selectedConfigFiles = root.selectedConfigFiles.filter(f => f !== fileDelegate.fileName);
                                } else {
                                    let list = root.selectedConfigFiles.slice();
                                    list.push(fileDelegate.fileName);
                                    root.selectedConfigFiles = list;
                                }
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            spacing: 8

                            StyledRect {
                                Layout.preferredWidth: 18
                                Layout.preferredHeight: 18
                                variant: fileDelegate.checked ? "tertiary" : "pane"
                                radius: 4
                                border.width: fileDelegate.checked ? 0 : 1
                                border.color: Colors.outline

                                Text {
                                    anchors.centerIn: parent
                                    text: Icons.accept
                                    font.family: Icons.font
                                    visible: fileDelegate.checked
                                    color: Styling.srItem("tertiary")
                                    font.pixelSize: 12
                                }
                            }

                            Text {
                                text: fileDelegate.fileName
                                color: fileDelegate.checked ? Colors.overSurface : Colors.outline
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }

            // Buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                StyledRect {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    variant: "pane"
                    radius: 4

                    Text {
                        anchors.centerIn: parent
                        text: "Cancel"
                        color: Colors.overSurface
                        font.family: Config.theme.font
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.cancelUpdateMode()
                    }
                }

                StyledRect {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    variant: "tertiary"
                    radius: 4
                    opacity: root.selectedConfigFiles.length > 0 ? 1 : 0.5

                    Text {
                        anchors.centerIn: parent
                        text: `Update (${root.selectedConfigFiles.length})`
                        color: Styling.srItem("tertiary")
                        font.family: Config.theme.font
                        font.weight: Font.Bold
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        enabled: parent.opacity === 1
                        onClicked: root.confirmUpdatePreset()
                    }
                }
            }
        }
    }
}
