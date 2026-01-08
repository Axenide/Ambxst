pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import qs.modules.theme
import qs.modules.components
import qs.config

Item {
    id: root

    property int maxContentWidth: 480
    readonly property int contentWidth: Math.min(width, maxContentWidth)
    readonly property real sideMargin: (width - contentWidth) / 2

    // Current category being viewed
    property string currentCategory: "ambxst"

    // Process for unbinding keybinds
    Process {
        id: unbindProcess
    }

    // Function to unbind a specific keybind (supports both old and new format)
    function unbindKeybind(bind) {
        if (!bind)
            return;

        // Check if new format with keys[]
        if (bind.keys && bind.keys.length > 0) {
            for (let k = 0; k < bind.keys.length; k++) {
                const keyObj = bind.keys[k];
                const mods = keyObj.modifiers && keyObj.modifiers.length > 0 ? keyObj.modifiers.join(" ") : "";
                const key = keyObj.key || "";
                const command = `hyprctl keyword unbind ${mods},${key}`;
                console.log("BindsPanel: Unbinding keybind:", command);
                unbindProcess.command = ["sh", "-c", command];
                unbindProcess.running = true;
            }
        } else {
            // Old format fallback
            const mods = bind.modifiers && bind.modifiers.length > 0 ? bind.modifiers.join(" ") : "";
            const key = bind.key || "";
            const command = `hyprctl keyword unbind ${mods},${key}`;
            console.log("BindsPanel: Unbinding keybind:", command);
            unbindProcess.command = ["sh", "-c", command];
            unbindProcess.running = true;
        }
    }

    // Edit mode state
    property bool editMode: false
    property int editingIndex: -1
    property var editingBind: null
    property bool isEditingAmbxst: false
    property bool isCreatingNew: false

    // Edit form state - new format with keys[] and actions[]
    property string editName: ""
    property var editKeys: []  // Array of { modifiers: [], key: "" }
    property var editActions: []  // Array of { dispatcher: "", argument: "", flags: "", compositor: { type: "", layouts: [] } }
    property int currentKeyPage: 0  // Current key page index
    property int currentActionPage: 0  // Current action page index

    // Current key being edited (derived from editKeys[currentKeyPage])
    property var editModifiers: editKeys.length > currentKeyPage ? (editKeys[currentKeyPage].modifiers || []) : []
    property string editKey: editKeys.length > currentKeyPage ? (editKeys[currentKeyPage].key || "") : ""

    // Current action being edited (derived from editActions[currentActionPage])
    property string editDispatcher: editActions.length > currentActionPage ? (editActions[currentActionPage].dispatcher || "") : ""
    property string editArgument: editActions.length > currentActionPage ? (editActions[currentActionPage].argument || "") : ""
    property string editFlags: editActions.length > currentActionPage ? (editActions[currentActionPage].flags || "") : ""
    property var editCompositor: editActions.length > currentActionPage ? (editActions[currentActionPage].compositor || {
            "type": "hyprland",
            "layouts": []
        }) : {
        "type": "hyprland",
        "layouts": []
    }

    readonly property var availableModifiers: ["SUPER", "SHIFT", "CTRL", "ALT"]
    readonly property var availableLayouts: ["dwindle", "master", "scrolling"]

    // Helper to update current key in editKeys array
    function updateCurrentKey(modifiers, key) {
        if (editKeys.length <= currentKeyPage)
            return;
        let newKeys = [];
        for (let i = 0; i < editKeys.length; i++) {
            if (i === currentKeyPage) {
                newKeys.push({
                    "modifiers": modifiers,
                    "key": key
                });
            } else {
                newKeys.push(editKeys[i]);
            }
        }
        editKeys = newKeys;
    }

    // Helper to update current action in editActions array
    function updateCurrentAction(dispatcher, argument, flags, compositor) {
        if (editActions.length <= currentActionPage)
            return;
        let newActions = [];
        for (let i = 0; i < editActions.length; i++) {
            if (i === currentActionPage) {
                newActions.push({
                    "dispatcher": dispatcher,
                    "argument": argument,
                    "flags": flags,
                    "compositor": compositor
                });
            } else {
                newActions.push(editActions[i]);
            }
        }
        editActions = newActions;
    }

    // Helper to check if a layout is selected for current action
    function hasLayout(layout) {
        const comp = root.editCompositor;
        if (!comp || !comp.layouts || comp.layouts.length === 0)
            return false;
        return comp.layouts.indexOf(layout) !== -1;
    }

    // Helper to toggle a layout for current action
    function toggleLayout(layout) {
        if (root.editActions.length <= root.currentActionPage)
            return;

        const currentAction = root.editActions[root.currentActionPage];
        let comp = currentAction.compositor || {
            "type": "hyprland",
            "layouts": []
        };
        let layouts = comp.layouts ? comp.layouts.slice() : [];

        const idx = layouts.indexOf(layout);
        if (idx !== -1) {
            layouts.splice(idx, 1);
        } else {
            layouts.push(layout);
        }

        updateCurrentAction(currentAction.dispatcher || "", currentAction.argument || "", currentAction.flags || "", {
            "type": "hyprland",
            "layouts": layouts
        });
    }

    // Add a new key page
    function addKeyPage() {
        let newKeys = editKeys.slice();
        newKeys.push({
            "modifiers": ["SUPER"],
            "key": ""
        });
        editKeys = newKeys;
        currentKeyPage = newKeys.length - 1;
    }

    // Remove current key page
    function removeKeyPage() {
        if (editKeys.length <= 1)
            return;
        let newKeys = [];
        for (let i = 0; i < editKeys.length; i++) {
            if (i !== currentKeyPage) {
                newKeys.push(editKeys[i]);
            }
        }
        editKeys = newKeys;
        if (currentKeyPage >= newKeys.length) {
            currentKeyPage = newKeys.length - 1;
        }
    }

    // Add a new action page
    function addActionPage() {
        let newActions = editActions.slice();
        newActions.push({
            "dispatcher": "",
            "argument": "",
            "flags": "",
            "compositor": {
                "type": "hyprland",
                "layouts": []
            }
        });
        editActions = newActions;
        currentActionPage = newActions.length - 1;
    }

    // Remove current action page
    function removeActionPage() {
        if (editActions.length <= 1)
            return;
        let newActions = [];
        for (let i = 0; i < editActions.length; i++) {
            if (i !== currentActionPage) {
                newActions.push(editActions[i]);
            }
        }
        editActions = newActions;
        if (currentActionPage >= newActions.length) {
            currentActionPage = newActions.length - 1;
        }
    }

    function openEditDialog(bind, index, isAmbxst) {
        root.editingIndex = index;
        root.editingBind = bind;
        root.isEditingAmbxst = isAmbxst;

        // Initialize edit form state
        if (isAmbxst) {
            // Ambxst binds still use old format (single key)
            const bindData = bind.bind;
            root.editName = "";
            root.editKeys = [
                {
                    "modifiers": bindData.modifiers ? bindData.modifiers.slice() : [],
                    "key": bindData.key || ""
                }
            ];
            root.editActions = [
                {
                    "dispatcher": bindData.dispatcher || "",
                    "argument": bindData.argument || "",
                    "flags": ""
                }
            ];
        } else {
            // Custom binds use new format
            root.editName = bind.name || "";
            // Handle both old and new format
            if (bind.keys && bind.actions) {
                // New format
                root.editKeys = JSON.parse(JSON.stringify(bind.keys));
                root.editActions = JSON.parse(JSON.stringify(bind.actions));
            } else {
                // Old format fallback
                root.editKeys = [
                    {
                        "modifiers": bind.modifiers ? bind.modifiers.slice() : [],
                        "key": bind.key || ""
                    }
                ];
                root.editActions = [
                    {
                        "dispatcher": bind.dispatcher || "",
                        "argument": bind.argument || "",
                        "flags": bind.flags || ""
                    }
                ];
            }
        }

        // Reset pager positions
        root.currentKeyPage = 0;
        root.currentActionPage = 0;

        // Reset edit flickable scroll position
        editFlickable.contentY = 0;

        root.editMode = true;
    }

    function closeEditDialog() {
        root.editMode = false;
        root.isCreatingNew = false;
        root.currentKeyPage = 0;
        root.currentActionPage = 0;
    }

    function hasModifier(mod) {
        const currentMods = root.editKeys.length > root.currentKeyPage ? (root.editKeys[root.currentKeyPage].modifiers || []) : [];
        return currentMods.indexOf(mod) !== -1;
    }

    function toggleModifier(mod) {
        if (root.editKeys.length <= root.currentKeyPage)
            return;

        let currentMods = root.editKeys[root.currentKeyPage].modifiers || [];
        let newMods = [];
        let found = false;
        for (let i = 0; i < currentMods.length; i++) {
            if (currentMods[i] === mod) {
                found = true;
            } else {
                newMods.push(currentMods[i]);
            }
        }
        if (!found) {
            newMods.push(mod);
        }
        updateCurrentKey(newMods, root.editKeys[root.currentKeyPage].key || "");
    }

    function saveEdit() {
        if (root.isEditingAmbxst) {
            // Save ambxst bind (still uses old format internally)
            const path = root.editingBind.path.split(".");
            // path = ["ambxst", "dashboard"|"system", "bindName"]
            const section = path[1];
            const bindName = path[2];

            const adapter = Config.keybindsLoader.adapter;
            if (adapter && adapter.ambxst && adapter.ambxst[section] && adapter.ambxst[section][bindName]) {
                // Use first key for ambxst binds
                const firstKey = root.editKeys.length > 0 ? root.editKeys[0] : {
                    modifiers: [],
                    key: ""
                };
                adapter.ambxst[section][bindName].modifiers = firstKey.modifiers || [];
                adapter.ambxst[section][bindName].key = firstKey.key || "";
                // dispatcher and argument are fixed for ambxst binds
            }
        } else if (root.isCreatingNew) {
            // Create new custom bind with new format
            const customBinds = Config.keybindsLoader.adapter.custom || [];
            let newBinds = customBinds.slice();
            const newBind = {
                "name": root.editName,
                "keys": root.editKeys,
                "actions": root.editActions,
                "enabled": true
            };
            newBinds.push(newBind);
            Config.keybindsLoader.adapter.custom = newBinds;
        } else {
            // Update existing custom bind with new format
            const customBinds = Config.keybindsLoader.adapter.custom;
            if (customBinds && customBinds[root.editingIndex]) {
                let newBinds = [];
                for (let i = 0; i < customBinds.length; i++) {
                    if (i === root.editingIndex) {
                        let updatedBind = {
                            "name": root.editName,
                            "keys": root.editKeys,
                            "actions": root.editActions,
                            "enabled": customBinds[i].enabled !== false
                        };
                        newBinds.push(updatedBind);
                    } else {
                        newBinds.push(customBinds[i]);
                    }
                }
                Config.keybindsLoader.adapter.custom = newBinds;
            }
        }

        root.editMode = false;
        root.isCreatingNew = false;
        root.currentKeyPage = 0;
        root.currentActionPage = 0;
    }

    readonly property var categories: [
        {
            id: "ambxst",
            label: "Ambxst",
            icon: Icons.widgets
        },
        {
            id: "custom",
            label: "Custom",
            icon: Icons.gear
        }
    ]

    function formatModifiers(modifiers) {
        if (!modifiers || modifiers.length === 0)
            return "";
        return modifiers.join(" + ");
    }

    function formatSingleKey(keyObj) {
        const mods = formatModifiers(keyObj.modifiers);
        return mods ? mods + " + " + keyObj.key : keyObj.key;
    }

    function formatKeybind(bind) {
        // Check if new format with keys[]
        if (bind.keys && bind.keys.length > 0) {
            let formatted = [];
            for (let i = 0; i < bind.keys.length; i++) {
                formatted.push(formatSingleKey(bind.keys[i]));
            }
            return formatted.join(", ");
        }
        // Old format fallback
        const mods = formatModifiers(bind.modifiers);
        return mods ? mods + " + " + bind.key : bind.key;
    }

    // Get ambxst binds as a flat list
    function getAmbxstBinds() {
        const adapter = Config.keybindsLoader.adapter;
        if (!adapter || !adapter.ambxst)
            return [];

        const binds = [];
        const ambxst = adapter.ambxst;

        // Dashboard binds
        if (ambxst.dashboard) {
            const dashboardKeys = ["widgets", "clipboard", "emoji", "tmux", "kanban", "wallpapers", "assistant", "notes"];
            for (const key of dashboardKeys) {
                if (ambxst.dashboard[key]) {
                    binds.push({
                        category: "Dashboard",
                        name: key.charAt(0).toUpperCase() + key.slice(1),
                        path: "ambxst.dashboard." + key,
                        bind: ambxst.dashboard[key]
                    });
                }
            }
        }

        // System binds
        if (ambxst.system) {
            const systemKeys = ["overview", "powermenu", "config", "lockscreen", "tools", "screenshot"];
            for (const key of systemKeys) {
                if (ambxst.system[key]) {
                    binds.push({
                        category: "System",
                        name: key.charAt(0).toUpperCase() + key.slice(1),
                        path: "ambxst.system." + key,
                        bind: ambxst.system[key]
                    });
                }
            }
        }

        return binds;
    }

    // Get custom binds
    function getCustomBinds() {
        const adapter = Config.keybindsLoader.adapter;
        if (!adapter || !adapter.custom)
            return [];
        return adapter.custom;
    }

    // Add a new custom bind
    function addNewBind() {
        const newBind = {
            "name": "",
            "keys": [
                {
                    "modifiers": ["SUPER"],
                    "key": ""
                }
            ],
            "actions": [
                {
                    "dispatcher": "",
                    "argument": "",
                    "flags": "",
                    "compositor": {
                        "type": "hyprland",
                        "layouts": []
                    }
                }
            ],
            "enabled": true
        };

        // Switch to custom category
        root.currentCategory = "custom";

        // Scroll to bottom after a brief delay to let the UI update
        scrollToBottomTimer.start();

        // Open edit dialog for the new bind (mark as creating new)
        root.isCreatingNew = true;
        root.openEditDialog(newBind, -1, false);
    }

    // Delete a custom bind
    function deleteBind(index) {
        const customBinds = Config.keybindsLoader.adapter.custom;
        if (!customBinds || index < 0 || index >= customBinds.length)
            return;

        // Get the bind to delete and unbind it first
        const bindToDelete = customBinds[index];
        unbindKeybind(bindToDelete);

        let newBinds = [];
        for (let i = 0; i < customBinds.length; i++) {
            if (i !== index) {
                newBinds.push(customBinds[i]);
            }
        }
        Config.keybindsLoader.adapter.custom = newBinds;
        root.editMode = false;
    }

    Timer {
        id: scrollToBottomTimer
        interval: 50
        onTriggered: {
            mainFlickable.contentY = mainFlickable.contentHeight - mainFlickable.height;
        }
    }

    // Fixed header area (titlebar + category selector)
    ColumnLayout {
        id: fixedHeader
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 8
        z: 10

        // Horizontal slide + fade animation
        opacity: root.editMode ? 0 : 1
        transform: Translate {
            x: root.editMode ? -30 : 0

            Behavior on x {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 2
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

        // Header
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: titlebar.height

            PanelTitlebar {
                id: titlebar
                width: root.contentWidth
                anchors.horizontalCenter: parent.horizontalCenter
                title: "Keybinds"
                statusText: ""

                actions: [
                    {
                        icon: Icons.plus,
                        tooltip: "Add keybind",
                        onClicked: function () {
                            root.addNewBind();
                        }
                    },
                    {
                        icon: Icons.sync,
                        tooltip: "Reload binds",
                        onClicked: function () {
                            Config.keybindsLoader.reload();
                        }
                    }
                ]
            }
        }

        // Category selector
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: categoryRow.height

            Row {
                id: categoryRow
                width: root.contentWidth
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 4

                Repeater {
                    model: root.categories

                    delegate: StyledRect {
                        id: categoryTag
                        required property var modelData
                        required property int index

                        property bool isSelected: root.currentCategory === modelData.id
                        property bool isHovered: false

                        variant: isSelected ? "primary" : (isHovered ? "focus" : "common")
                        enableShadow: true
                        width: categoryContent.width + 32
                        height: 36
                        radius: Styling.radius(-2)

                        Row {
                            id: categoryContent
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: categoryTag.modelData.icon
                                font.family: Icons.font
                                font.pixelSize: 14
                                color: categoryTag.item
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: categoryTag.modelData.label
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(0)
                                font.weight: categoryTag.isSelected ? Font.Bold : Font.Normal
                                color: categoryTag.item
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: categoryTag.isHovered = true
                            onExited: categoryTag.isHovered = false
                            onClicked: root.currentCategory = categoryTag.modelData.id
                        }
                    }
                }
            }
        }
    }

    // Scrollable content area
    Flickable {
        id: mainFlickable
        anchors.top: fixedHeader.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: 8
        contentHeight: contentColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: !root.editMode

        // Horizontal slide + fade animation
        opacity: root.editMode ? 0 : 1
        transform: Translate {
            x: root.editMode ? -30 : 0

            Behavior on x {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 2
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

        // Content area
        ColumnLayout {
            id: contentColumn
            width: root.contentWidth
            x: root.sideMargin
            spacing: 4

            // Ambxst binds view
            Repeater {
                id: ambxstRepeater
                model: root.currentCategory === "ambxst" ? root.getAmbxstBinds() : []

                delegate: BindItem {
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    bindName: modelData.name
                    keybindText: root.formatKeybind(modelData.bind)
                    dispatcher: modelData.bind.dispatcher
                    argument: modelData.bind.argument || ""
                    isAmbxst: true

                    onEditRequested: {
                        root.openEditDialog(modelData, index, true);
                    }
                }
            }

            // Custom binds view
            Repeater {
                id: customRepeater
                model: root.currentCategory === "custom" ? root.getCustomBinds() : []

                delegate: BindItem {
                    required property var modelData
                    required property int index

                    // Helper to get first action's dispatcher/argument
                    readonly property string firstDispatcher: modelData.actions && modelData.actions.length > 0 ? (modelData.actions[0].dispatcher || "") : (modelData.dispatcher || "")
                    readonly property string firstArgument: modelData.actions && modelData.actions.length > 0 ? (modelData.actions[0].argument || "") : (modelData.argument || "")

                    // Helper to get unique layouts from all actions
                    function getUniqueLayouts() {
                        if (!modelData.actions || modelData.actions.length === 0)
                            return [];
                        let allLayouts = [];
                        for (let i = 0; i < modelData.actions.length; i++) {
                            const action = modelData.actions[i];
                            if (action.compositor && action.compositor.layouts) {
                                for (let j = 0; j < action.compositor.layouts.length; j++) {
                                    const layout = action.compositor.layouts[j];
                                    if (allLayouts.indexOf(layout) === -1) {
                                        allLayouts.push(layout);
                                    }
                                }
                            }
                        }
                        return allLayouts;
                    }

                    Layout.fillWidth: true
                    customName: modelData.name || ""
                    bindName: firstDispatcher
                    keybindText: root.formatKeybind(modelData)
                    dispatcher: firstDispatcher
                    argument: firstArgument
                    isEnabled: modelData.enabled !== false
                    isAmbxst: false
                    layouts: getUniqueLayouts()

                    onToggleEnabled: {
                        const customBinds = Config.keybindsLoader.adapter.custom;
                        if (customBinds && customBinds[index]) {
                            let newBinds = [];
                            for (let i = 0; i < customBinds.length; i++) {
                                if (i === index) {
                                    let updatedBind = JSON.parse(JSON.stringify(customBinds[i]));
                                    updatedBind.enabled = !isEnabled;
                                    newBinds.push(updatedBind);
                                } else {
                                    newBinds.push(customBinds[i]);
                                }
                            }
                            Config.keybindsLoader.adapter.custom = newBinds;
                        }
                    }

                    onEditRequested: {
                        root.openEditDialog(modelData, index, false);
                    }
                }
            }

            // Empty state
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 20
                visible: (root.currentCategory === "ambxst" && ambxstRepeater.count === 0) || (root.currentCategory === "custom" && customRepeater.count === 0)
                text: root.currentCategory === "ambxst" ? "No Ambxst binds configured" : "No custom binds configured"
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(0)
                color: Colors.overSurfaceVariant
            }
        }
    }

    // Edit view (shown when editMode is true) - slides in from right
    Item {
        id: editContainer
        anchors.fill: parent
        clip: true
        z: 100  // Ensure it's above everything else

        // Horizontal slide + fade animation (enters from right)
        opacity: root.editMode ? 1 : 0
        visible: opacity > 0
        transform: Translate {
            x: root.editMode ? 0 : 30

            Behavior on x {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 2
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

        // Block interaction with elements behind when active
        MouseArea {
            anchors.fill: parent
            enabled: root.editMode
            hoverEnabled: true
            acceptedButtons: Qt.AllButtons
            propagateComposedEvents: false
            onPressed: event => event.accepted = true
            onReleased: event => event.accepted = true
            onClicked: event => event.accepted = true
            onWheel: event => event.accepted = true
        }

        Flickable {
            id: editFlickable
            anchors.fill: parent
            contentHeight: editContent.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: editContent
                width: editFlickable.width
                spacing: 8

                // Header with back button
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: editTitlebar.height

                    RowLayout {
                        id: editTitlebar
                        width: root.contentWidth
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 8

                        // Back button
                        StyledRect {
                            id: backButton
                            variant: backButtonArea.containsMouse ? "focus" : "common"
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36
                            radius: Styling.radius(-2)

                            Text {
                                anchors.centerIn: parent
                                text: Icons.caretLeft
                                font.family: Icons.font
                                font.pixelSize: 16
                                color: backButton.item
                            }

                            MouseArea {
                                id: backButtonArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.closeEditDialog()
                            }
                        }

                        // Title
                        Text {
                            text: root.isCreatingNew ? "New Keybind" : "Edit Keybind"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(0)
                            font.weight: Font.Medium
                            color: Colors.overBackground
                            Layout.fillWidth: true
                        }

                        // Delete button (only for existing custom binds)
                        StyledRect {
                            id: deleteButton
                            visible: !root.isEditingAmbxst && !root.isCreatingNew
                            variant: deleteButtonArea.containsMouse ? "focus" : "common"
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36
                            radius: Styling.radius(-2)

                            Text {
                                anchors.centerIn: parent
                                text: Icons.trash
                                font.family: Icons.font
                                font.pixelSize: 16
                                color: Colors.error
                            }

                            MouseArea {
                                id: deleteButtonArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.deleteBind(root.editingIndex)
                            }

                            StyledToolTip {
                                visible: deleteButtonArea.containsMouse
                                tooltipText: "Delete keybind"
                            }
                        }

                        // Save button
                        StyledRect {
                            id: saveButton
                            variant: saveButtonArea.containsMouse ? "primaryfocus" : "primary"
                            Layout.preferredWidth: saveButtonContent.width + 24
                            Layout.preferredHeight: 36
                            radius: Styling.radius(-2)

                            Row {
                                id: saveButtonContent
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    text: Icons.accept
                                    font.family: Icons.font
                                    font.pixelSize: 14
                                    color: saveButton.item
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: "Save"
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(0)
                                    font.weight: Font.Medium
                                    color: saveButton.item
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: saveButtonArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.saveEdit()
                            }
                        }
                    }
                }

                // Edit form content
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: formColumn.implicitHeight

                    ColumnLayout {
                        id: formColumn
                        width: root.contentWidth
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 16

                        // Custom name input (only for custom binds)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            visible: !root.isEditingAmbxst

                            Text {
                                text: "Name (optional)"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                font.weight: Font.Medium
                                color: Colors.overSurfaceVariant
                            }

                            StyledRect {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 44
                                variant: nameInput.activeFocus ? "focus" : "common"
                                radius: Styling.radius(-2)

                                TextInput {
                                    id: nameInput
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    text: root.editName
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(0)
                                    color: Colors.overBackground
                                    verticalAlignment: Text.AlignVCenter
                                    selectByMouse: true
                                    onTextChanged: root.editName = text

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: !nameInput.text && !nameInput.activeFocus
                                        text: "e.g. Open Terminal, Switch to Workspace 1..."
                                        font: nameInput.font
                                        color: Colors.overSurfaceVariant
                                    }
                                }
                            }
                        }

                        // Bind name/info (for ambxst binds only)
                        Text {
                            visible: root.isEditingAmbxst && root.editingBind !== null
                            text: root.editingBind ? (root.editingBind.name || "") : ""
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(1)
                            font.weight: Font.Medium
                            color: Colors.overBackground
                        }

                        // Preview at top - shows all keys for current bind
                        StyledRect {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 56
                            variant: "common"
                            radius: Styling.radius(-2)

                            Text {
                                anchors.centerIn: parent
                                text: {
                                    if (root.editKeys.length === 0)
                                        return "?";
                                    let formatted = [];
                                    for (let i = 0; i < root.editKeys.length; i++) {
                                        const k = root.editKeys[i];
                                        const mods = root.formatModifiers(k.modifiers);
                                        const key = k.key || "?";
                                        formatted.push(mods ? mods + " + " + key : key);
                                    }
                                    return formatted.join(", ");
                                }
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(root.editKeys.length > 2 ? 0 : 2)
                                font.weight: Font.Bold
                                color: Styling.srItem("overprimary")
                                elide: Text.ElideRight
                                width: parent.width - 24
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }

                        // =====================
                        // KEYS SECTION
                        // =====================
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            // Keys section header with pager controls
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: "Key Combination"
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-1)
                                    font.weight: Font.Medium
                                    color: Colors.overSurfaceVariant
                                    Layout.fillWidth: true
                                }

                                // Page indicator
                                Text {
                                    visible: root.editKeys.length > 1
                                    text: (root.currentKeyPage + 1) + " / " + root.editKeys.length
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-1)
                                    color: Colors.overSurfaceVariant
                                }

                                // Remove key button
                                StyledRect {
                                    id: removeKeyBtn
                                    visible: root.editKeys.length > 1 && !root.isEditingAmbxst
                                    variant: removeKeyBtnArea.containsMouse ? "focus" : "common"
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    radius: Styling.radius(-4)

                                    Text {
                                        anchors.centerIn: parent
                                        text: Icons.trash
                                        font.family: Icons.font
                                        font.pixelSize: 12
                                        color: Colors.error
                                    }

                                    MouseArea {
                                        id: removeKeyBtnArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.removeKeyPage()
                                    }

                                    StyledToolTip {
                                        visible: removeKeyBtnArea.containsMouse
                                        tooltipText: "Remove this key"
                                    }
                                }

                                // Previous key button
                                StyledRect {
                                    id: prevKeyBtn
                                    visible: root.editKeys.length > 1
                                    variant: prevKeyBtnArea.containsMouse ? "focus" : "common"
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    radius: Styling.radius(-4)
                                    opacity: root.currentKeyPage > 0 ? 1 : 0.3

                                    Text {
                                        anchors.centerIn: parent
                                        text: Icons.caretLeft
                                        font.family: Icons.font
                                        font.pixelSize: 12
                                        color: prevKeyBtn.item
                                    }

                                    MouseArea {
                                        id: prevKeyBtnArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: root.currentKeyPage > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: {
                                            if (root.currentKeyPage > 0) {
                                                root.currentKeyPage--;
                                            }
                                        }
                                    }
                                }

                                // Next key button
                                StyledRect {
                                    id: nextKeyBtn
                                    visible: root.editKeys.length > 1
                                    variant: nextKeyBtnArea.containsMouse ? "focus" : "common"
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    radius: Styling.radius(-4)
                                    opacity: root.currentKeyPage < root.editKeys.length - 1 ? 1 : 0.3

                                    Text {
                                        anchors.centerIn: parent
                                        text: Icons.caretRight
                                        font.family: Icons.font
                                        font.pixelSize: 12
                                        color: nextKeyBtn.item
                                    }

                                    MouseArea {
                                        id: nextKeyBtnArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: root.currentKeyPage < root.editKeys.length - 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: {
                                            if (root.currentKeyPage < root.editKeys.length - 1) {
                                                root.currentKeyPage++;
                                            }
                                        }
                                    }
                                }

                                // Add key button
                                StyledRect {
                                    id: addKeyBtn
                                    visible: !root.isEditingAmbxst
                                    variant: addKeyBtnArea.containsMouse ? "primaryfocus" : "primary"
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    radius: Styling.radius(-4)

                                    Text {
                                        anchors.centerIn: parent
                                        text: Icons.plus
                                        font.family: Icons.font
                                        font.pixelSize: 12
                                        color: addKeyBtn.item
                                    }

                                    MouseArea {
                                        id: addKeyBtnArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.addKeyPage()
                                    }

                                    StyledToolTip {
                                        visible: addKeyBtnArea.containsMouse
                                        tooltipText: "Add another key"
                                    }
                                }
                            }

                            // Modifiers
                            Flow {
                                Layout.fillWidth: true
                                spacing: 8

                                Repeater {
                                    model: root.availableModifiers

                                    delegate: StyledRect {
                                        id: modTag
                                        required property string modelData
                                        required property int index

                                        property bool isSelected: root.hasModifier(modelData)
                                        property bool isHovered: false

                                        variant: isSelected ? "primary" : (isHovered ? "focus" : "common")
                                        width: modLabel.width + 32
                                        height: 40
                                        radius: Styling.radius(-2)

                                        Text {
                                            id: modLabel
                                            anchors.centerIn: parent
                                            text: modTag.modelData
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(0)
                                            font.weight: modTag.isSelected ? Font.Bold : Font.Normal
                                            color: modTag.item
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onEntered: modTag.isHovered = true
                                            onExited: modTag.isHovered = false
                                            onClicked: root.toggleModifier(modTag.modelData)
                                        }
                                    }
                                }
                            }

                            // Key input
                            StyledRect {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 44
                                variant: keyInput.activeFocus ? "focus" : "common"
                                radius: Styling.radius(-2)

                                TextInput {
                                    id: keyInput
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    text: root.editKey
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(0)
                                    color: Colors.overBackground
                                    verticalAlignment: Text.AlignVCenter
                                    selectByMouse: true
                                    onTextChanged: {
                                        if (root.editKeys.length > root.currentKeyPage) {
                                            root.updateCurrentKey(root.editKeys[root.currentKeyPage].modifiers || [], text);
                                        }
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: !keyInput.text && !keyInput.activeFocus
                                        text: "e.g. R, TAB, ESCAPE, mouse:272..."
                                        font: keyInput.font
                                        color: Colors.overSurfaceVariant
                                    }
                                }
                            }
                        }

                        // =====================
                        // ACTIONS SECTION (only for custom binds)
                        // =====================
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            visible: !root.isEditingAmbxst

                            // Actions section header with pager controls
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: "Action"
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-1)
                                    font.weight: Font.Medium
                                    color: Colors.overSurfaceVariant
                                    Layout.fillWidth: true
                                }

                                // Page indicator
                                Text {
                                    visible: root.editActions.length > 1
                                    text: (root.currentActionPage + 1) + " / " + root.editActions.length
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-1)
                                    color: Colors.overSurfaceVariant
                                }

                                // Remove action button
                                StyledRect {
                                    id: removeActionBtn
                                    visible: root.editActions.length > 1
                                    variant: removeActionBtnArea.containsMouse ? "focus" : "common"
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    radius: Styling.radius(-4)

                                    Text {
                                        anchors.centerIn: parent
                                        text: Icons.trash
                                        font.family: Icons.font
                                        font.pixelSize: 12
                                        color: Colors.error
                                    }

                                    MouseArea {
                                        id: removeActionBtnArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.removeActionPage()
                                    }

                                    StyledToolTip {
                                        visible: removeActionBtnArea.containsMouse
                                        tooltipText: "Remove this action"
                                    }
                                }

                                // Previous action button
                                StyledRect {
                                    id: prevActionBtn
                                    visible: root.editActions.length > 1
                                    variant: prevActionBtnArea.containsMouse ? "focus" : "common"
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    radius: Styling.radius(-4)
                                    opacity: root.currentActionPage > 0 ? 1 : 0.3

                                    Text {
                                        anchors.centerIn: parent
                                        text: Icons.caretLeft
                                        font.family: Icons.font
                                        font.pixelSize: 12
                                        color: prevActionBtn.item
                                    }

                                    MouseArea {
                                        id: prevActionBtnArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: root.currentActionPage > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: {
                                            if (root.currentActionPage > 0) {
                                                root.currentActionPage--;
                                            }
                                        }
                                    }
                                }

                                // Next action button
                                StyledRect {
                                    id: nextActionBtn
                                    visible: root.editActions.length > 1
                                    variant: nextActionBtnArea.containsMouse ? "focus" : "common"
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    radius: Styling.radius(-4)
                                    opacity: root.currentActionPage < root.editActions.length - 1 ? 1 : 0.3

                                    Text {
                                        anchors.centerIn: parent
                                        text: Icons.caretRight
                                        font.family: Icons.font
                                        font.pixelSize: 12
                                        color: nextActionBtn.item
                                    }

                                    MouseArea {
                                        id: nextActionBtnArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: root.currentActionPage < root.editActions.length - 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: {
                                            if (root.currentActionPage < root.editActions.length - 1) {
                                                root.currentActionPage++;
                                            }
                                        }
                                    }
                                }

                                // Add action button
                                StyledRect {
                                    id: addActionBtn
                                    variant: addActionBtnArea.containsMouse ? "primaryfocus" : "primary"
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    radius: Styling.radius(-4)

                                    Text {
                                        anchors.centerIn: parent
                                        text: Icons.plus
                                        font.family: Icons.font
                                        font.pixelSize: 12
                                        color: addActionBtn.item
                                    }

                                    MouseArea {
                                        id: addActionBtnArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.addActionPage()
                                    }

                                    StyledToolTip {
                                        visible: addActionBtnArea.containsMouse
                                        tooltipText: "Add another action"
                                    }
                                }
                            }

                            // Dispatcher input
                            StyledRect {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 44
                                variant: dispatcherInput.activeFocus ? "focus" : "common"
                                radius: Styling.radius(-2)

                                TextInput {
                                    id: dispatcherInput
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    text: root.editDispatcher
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(0)
                                    color: Colors.overBackground
                                    verticalAlignment: Text.AlignVCenter
                                    selectByMouse: true
                                    onTextChanged: {
                                        if (root.editActions.length > root.currentActionPage) {
                                            const currentAction = root.editActions[root.currentActionPage];
                                            root.updateCurrentAction(text, currentAction.argument || "", currentAction.flags || "", currentAction.compositor || {
                                                "type": "hyprland",
                                                "layouts": []
                                            });
                                        }
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: !dispatcherInput.text && !dispatcherInput.activeFocus
                                        text: "e.g. exec, workspace, killactive..."
                                        font: dispatcherInput.font
                                        color: Colors.overSurfaceVariant
                                    }
                                }
                            }

                            // Argument input
                            Text {
                                text: "Argument"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                font.weight: Font.Medium
                                color: Colors.overSurfaceVariant
                                Layout.topMargin: 4
                            }

                            StyledRect {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 44
                                variant: argumentInput.activeFocus ? "focus" : "common"
                                radius: Styling.radius(-2)

                                TextInput {
                                    id: argumentInput
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    text: root.editArgument
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(0)
                                    color: Colors.overBackground
                                    verticalAlignment: Text.AlignVCenter
                                    selectByMouse: true
                                    onTextChanged: {
                                        if (root.editActions.length > root.currentActionPage) {
                                            const currentAction = root.editActions[root.currentActionPage];
                                            root.updateCurrentAction(currentAction.dispatcher || "", text, currentAction.flags || "", currentAction.compositor || {
                                                "type": "hyprland",
                                                "layouts": []
                                            });
                                        }
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: !argumentInput.text && !argumentInput.activeFocus
                                        text: "e.g. kitty, 1, playerctl play-pause..."
                                        font: argumentInput.font
                                        color: Colors.overSurfaceVariant
                                    }
                                }
                            }

                            // Flags input
                            Text {
                                text: "Flags (optional)"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                font.weight: Font.Medium
                                color: Colors.overSurfaceVariant
                                Layout.topMargin: 4
                            }

                            StyledRect {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 44
                                variant: flagsInput.activeFocus ? "focus" : "common"
                                radius: Styling.radius(-2)

                                TextInput {
                                    id: flagsInput
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    text: root.editFlags
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(0)
                                    color: Colors.overBackground
                                    verticalAlignment: Text.AlignVCenter
                                    selectByMouse: true
                                    onTextChanged: {
                                        if (root.editActions.length > root.currentActionPage) {
                                            const currentAction = root.editActions[root.currentActionPage];
                                            root.updateCurrentAction(currentAction.dispatcher || "", currentAction.argument || "", text, currentAction.compositor || {
                                                "type": "hyprland",
                                                "layouts": []
                                            });
                                        }
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: !flagsInput.text && !flagsInput.activeFocus
                                        text: "e.g. m, l, e, le..."
                                        font: flagsInput.font
                                        color: Colors.overSurfaceVariant
                                    }
                                }
                            }

                            Text {
                                text: "l=locked, e=repeat, m=mouse, r=release"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-2)
                                color: Colors.overSurfaceVariant
                            }

                            // =====================
                            // LAYOUT SELECTOR (for Hyprland)
                            // =====================
                            Text {
                                text: "Layouts (Hyprland)"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                font.weight: Font.Medium
                                color: Colors.overSurfaceVariant
                                Layout.topMargin: 8
                            }

                            Text {
                                text: "Leave all unselected to work in all layouts"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-2)
                                color: Colors.overSurfaceVariant
                                Layout.topMargin: -4
                            }

                            Flow {
                                Layout.fillWidth: true
                                spacing: 8

                                Repeater {
                                    model: root.availableLayouts

                                    delegate: StyledRect {
                                        id: layoutTag
                                        required property string modelData
                                        required property int index

                                        property bool isSelected: root.hasLayout(modelData)
                                        property bool isHovered: false

                                        variant: isSelected ? "primary" : (isHovered ? "focus" : "common")
                                        width: layoutContent.width + 24 + (isSelected ? layoutCheckIcon.width + 4 : 0)
                                        height: 36
                                        radius: Styling.radius(-2)

                                        Behavior on width {
                                            enabled: (Config.animDuration ?? 0) > 0
                                            NumberAnimation {
                                                duration: (Config.animDuration ?? 0) / 3
                                                easing.type: Easing.OutCubic
                                            }
                                        }

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: layoutTag.isSelected ? 4 : 0

                                            Item {
                                                width: layoutCheckIcon.visible ? layoutCheckIcon.width : 0
                                                height: layoutCheckIcon.height
                                                clip: true

                                                Text {
                                                    id: layoutCheckIcon
                                                    text: Icons.accept
                                                    font.family: Icons.font
                                                    font.pixelSize: 14
                                                    color: layoutTag.item
                                                    visible: layoutTag.isSelected
                                                    opacity: layoutTag.isSelected ? 1 : 0

                                                    Behavior on opacity {
                                                        enabled: (Config.animDuration ?? 0) > 0
                                                        NumberAnimation {
                                                            duration: (Config.animDuration ?? 0) / 3
                                                            easing.type: Easing.OutCubic
                                                        }
                                                    }
                                                }

                                                Behavior on width {
                                                    enabled: (Config.animDuration ?? 0) > 0
                                                    NumberAnimation {
                                                        duration: (Config.animDuration ?? 0) / 3
                                                        easing.type: Easing.OutCubic
                                                    }
                                                }
                                            }

                                            Text {
                                                id: layoutContent
                                                text: layoutTag.modelData.charAt(0).toUpperCase() + layoutTag.modelData.slice(1)
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(0)
                                                font.weight: layoutTag.isSelected ? Font.Bold : Font.Normal
                                                color: layoutTag.item
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onEntered: layoutTag.isHovered = true
                                            onExited: layoutTag.isHovered = false
                                            onClicked: root.toggleLayout(layoutTag.modelData)
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

    // BindItem component
    component BindItem: StyledRect {
        id: bindItem

        property string customName: ""  // User-friendly name, if set shows only this
        property string bindName: ""
        property string keybindText: ""
        property string dispatcher: ""
        property string argument: ""
        property bool isEnabled: true
        property bool isAmbxst: true
        property bool isHovered: false
        property var layouts: []  // Layouts this bind is restricted to (empty = all layouts)

        // Computed display values
        readonly property bool hasCustomName: customName !== ""
        readonly property string displayName: hasCustomName ? customName : bindName
        readonly property string displaySubtitle: hasCustomName ? "" : (argument || dispatcher)
        readonly property bool hasLayoutRestriction: layouts && layouts.length > 0
        readonly property var displayLayouts: hasLayoutRestriction ? layouts : ["dwindle", "master", "scrolling"]

        signal editRequested
        signal toggleEnabled

        variant: isHovered ? "focus" : "common"
        height: 56
        radius: Styling.radius(-2)
        enableShadow: true
        opacity: isEnabled ? 1 : 0.5

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            anchors.topMargin: 8
            anchors.bottomMargin: 8
            spacing: 12

            // Checkbox for custom binds (styled like OLED Mode)
            Item {
                id: checkboxItem
                visible: !bindItem.isAmbxst
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32

                Item {
                    anchors.fill: parent

                    Rectangle {
                        anchors.fill: parent
                        radius: Styling.radius(-4)
                        color: Colors.background
                        visible: !bindItem.isEnabled
                    }

                    StyledRect {
                        variant: "primary"
                        anchors.fill: parent
                        radius: Styling.radius(-4)
                        visible: bindItem.isEnabled
                        opacity: bindItem.isEnabled ? 1.0 : 0.0

                        Behavior on opacity {
                            enabled: Config.animDuration > 0
                            NumberAnimation {
                                duration: Config.animDuration / 2
                                easing.type: Easing.OutQuart
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: Icons.accept
                            color: Styling.srItem("primary")
                            font.family: Icons.font
                            font.pixelSize: 16
                            scale: bindItem.isEnabled ? 1.0 : 0.0

                            Behavior on scale {
                                enabled: Config.animDuration > 0
                                NumberAnimation {
                                    duration: Config.animDuration / 2
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 1.5
                                }
                            }
                        }
                    }
                }
            }

            // Info column - what the bind does
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: bindItem.displayName
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(0)
                    font.weight: Font.Medium
                    color: bindItem.item
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: bindItem.displaySubtitle
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-2)
                        color: Colors.overSurfaceVariant
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        visible: text !== ""
                    }

                    // Layout indicator
                    Row {
                        visible: !bindItem.isAmbxst
                        spacing: 4
                        Layout.alignment: Qt.AlignVCenter

                        Repeater {
                            model: bindItem.displayLayouts

                            delegate: Rectangle {
                                id: layoutBadge
                                required property string modelData
                                property bool isHovered: false
                                width: layoutBadgeText.width + 8
                                height: 16
                                radius: 4
                                color: Styling.srItem("overprimary")
                                opacity: isHovered ? 1.0 : 0.8

                                Text {
                                    id: layoutBadgeText
                                    anchors.centerIn: parent
                                    text: layoutBadge.modelData.charAt(0).toUpperCase()
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-3)
                                    font.weight: Font.Bold
                                    color: Styling.srItem("primary")
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: layoutBadge.isHovered = true
                                    onExited: layoutBadge.isHovered = false
                                }

                                StyledToolTip {
                                    visible: layoutBadge.isHovered
                                    tooltipText: layoutBadge.modelData.charAt(0).toUpperCase() + layoutBadge.modelData.slice(1) + " layout"
                                }
                            }
                        }
                    }
                }
            }

            // Keybind display at the end
            StyledRect {
                variant: "internalbg"
                Layout.preferredWidth: keybindLabel.width + 24
                Layout.preferredHeight: 28
                radius: Styling.radius(-4)

                Text {
                    id: keybindLabel
                    anchors.centerIn: parent
                    text: bindItem.keybindText
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    font.weight: Font.Medium
                    color: Styling.srItem("overprimary")
                }
            }
        }

        // Click anywhere to edit (but not on checkbox)
        MouseArea {
            id: editClickArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: bindItem.isHovered = true
            onExited: bindItem.isHovered = false
            onClicked: bindItem.editRequested()
        }

        // Checkbox MouseArea needs to be on top
        MouseArea {
            id: checkboxClickArea
            visible: !bindItem.isAmbxst
            x: 12
            y: (parent.height - 32) / 2
            width: 32
            height: 32
            z: 1
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onEntered: bindItem.isHovered = true
            onExited: bindItem.isHovered = false
            onClicked: mouse => {
                bindItem.toggleEnabled();
                mouse.accepted = true;
            }
        }
    }
}
