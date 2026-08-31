pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.config
import qs.modules.components
import qs.modules.services
import qs.modules.theme

Item {
    id: root

    property int maxContentWidth: 760
    property string searchQuery: ""
    property string sortMode: "name"
    property string selectedId: ""
    property string removeArmedId: ""

    readonly property int contentWidth: Math.min(width, maxContentWidth)
    readonly property var filteredMods: {
        const query = root.searchQuery.trim().toLowerCase();
        const items = (ModsService.mods ?? []).filter(mod => {
            if (!query)
                return true;
            return (mod.name ?? "").toLowerCase().includes(query)
                || (mod.id ?? "").toLowerCase().includes(query)
                || (mod.description ?? "").toLowerCase().includes(query);
        });
        return items.slice().sort((a, b) => {
            if (root.sortMode === "loadOrder")
                return (a.order ?? 0) - (b.order ?? 0);
            if (root.sortMode === "state" && !!a.enabled !== !!b.enabled)
                return a.enabled ? -1 : 1;
            return (a.name ?? a.id).localeCompare(b.name ?? b.id);
        });
    }
    readonly property var selectedMod: {
        const mods = ModsService.mods ?? [];
        for (let i = 0; i < mods.length; i++) {
            if (mods[i].id === root.selectedId)
                return mods[i];
        }
        return mods.length > 0 ? mods[0] : null;
    }

    onSelectedModChanged: {
        if (selectedMod && selectedId !== selectedMod.id) {
            selectedId = selectedMod.id;
            return;
        }
        ModsService.loadSettings(selectedMod?.id ?? "");
        removeArmedId = "";
    }

    Component.onCompleted: ModsService.refresh()

    Connections {
        target: ModsService
        function onInstalled(source) {
            if (sourceInput.text.trim() === source)
                sourceInput.text = "";
        }
    }

    component ActionButton: Button {
        id: action
        property bool primary: false
        property bool destructive: false

        implicitHeight: 36
        leftPadding: 12
        rightPadding: 12
        enabled: !ModsService.busy

        background: StyledRect {
            variant: action.primary ? "primary" : ((action.hovered || action.activeFocus || action.down) ? "focus" : "common")
            radius: Styling.radius(-2)
            enableShadow: false
        }

        contentItem: Text {
            text: action.text
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            font.weight: action.primary ? Font.DemiBold : Font.Medium
            color: action.destructive ? Colors.error : action.primary ? Styling.srItem("primary") : Colors.overBackground
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    ColumnLayout {
        width: root.contentWidth
        height: parent.height
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 8

        PanelTitlebar {
            title: "Mods"
            statusText: ModsService.busy ? "Working…" : ""
            actions: [
                {
                    icon: Icons.arrowCounterClockwise,
                    tooltip: "Refresh mod state",
                    enabled: !ModsService.busy,
                    onClicked: function () { ModsService.refresh(); }
                }
            ]

            ActionButton {
                text: "Rebuild"
                onClicked: ModsService.rebuild()
            }
        }

        StyledRect {
            visible: !ModsService.generationCurrent || ModsService.restartRequired
                || ModsService.errorMessage !== "" || ModsService.statusMessage !== ""
            Layout.fillWidth: true
            Layout.preferredHeight: statusRow.implicitHeight + 16
            variant: ModsService.errorMessage !== "" || !ModsService.generationCurrent ? "focus" : "common"
            radius: Styling.radius(-2)
            enableShadow: false

            RowLayout {
                id: statusRow
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                Text {
                    text: ModsService.errorMessage !== "" || !ModsService.generationCurrent
                        ? Icons.alert : (ModsService.restartRequired ? Icons.arrowCounterClockwise : Icons.accept)
                    font.family: Icons.font
                    font.pixelSize: 16
                    color: ModsService.errorMessage !== "" || !ModsService.generationCurrent ? Colors.error : Colors.overBackground
                }

                Text {
                    Layout.fillWidth: true
                    text: ModsService.errorMessage !== "" ? ModsService.errorMessage
                        : !ModsService.generationCurrent ? "Rebuild required: " + ModsService.generationError
                        : ModsService.restartRequired ? "Restart Ambxst to load the active generation."
                        : ModsService.statusMessage
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    color: ModsService.errorMessage !== "" || !ModsService.generationCurrent ? Colors.error : Colors.overBackground
                    wrapMode: Text.Wrap
                }

                ActionButton {
                    visible: !ModsService.generationCurrent
                    text: "Rebuild"
                    primary: true
                    onClicked: ModsService.rebuild()
                }

                ActionButton {
                    visible: ModsService.restartRequired
                    text: "Restart now"
                    primary: true
                    onClicked: ModsService.restart()
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Text {
                text: "Package source"
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                font.weight: Font.Medium
                color: Colors.overBackground
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                TextField {
                    id: sourceInput
                    Layout.fillWidth: true
                    implicitHeight: 40
                    placeholderText: "Local directory, package archive, or Git URL"
                    color: Colors.overBackground
                    placeholderTextColor: Colors.outline
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    selectByMouse: true
                    enabled: !ModsService.busy
                    Accessible.name: "Package source"
                    Accessible.description: "Local directory, package archive, or Git URL"

                    background: StyledRect {
                        variant: sourceInput.activeFocus ? "focus" : "common"
                        radius: Styling.radius(-2)
                        enableShadow: false
                    }

                    onAccepted: {
                        const source = text.trim();
                        if (source !== "") {
                            ModsService.install(source);
                        }
                    }
                }

                ActionButton {
                    text: "Install"
                    primary: true
                    enabled: !ModsService.busy && sourceInput.text.trim() !== ""
                    onClicked: {
                        ModsService.install(sourceInput.text.trim());
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: "Packages run with your user permissions. Install code only from sources you trust."
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            color: Colors.outline
            wrapMode: Text.Wrap
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: root.width >= 680 ? 2 : 1
            columnSpacing: 8
            rowSpacing: 8

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 300
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    SearchInput {
                        Layout.fillWidth: true
                        placeholderText: "Search installed mods…"
                        clearOnEscape: true
                        onSearchTextChanged: text => root.searchQuery = text
                    }

                    ActionButton {
                        text: root.sortMode === "name" ? "Sort: Name"
                            : root.sortMode === "state" ? "Sort: State"
                            : "Sort: Load order"
                        onClicked: root.sortMode = root.sortMode === "name" ? "state"
                            : root.sortMode === "state" ? "loadOrder"
                            : "name"
                    }
                }

                StyledRect {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    variant: "pane"
                    radius: Styling.radius(0)

                    Text {
                        visible: ModsService.loaded && root.filteredMods.length === 0
                        anchors.centerIn: parent
                        width: Math.min(parent.width - 32, 260)
                        text: ModsService.mods.length === 0
                            ? "No mods are installed. Add a package source above."
                            : "No installed mods match this search."
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        color: Colors.outline
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                    }

                    Flickable {
                        anchors.fill: parent
                        anchors.margins: 6
                        contentHeight: modList.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                        }

                        ColumnLayout {
                            id: modList
                            width: parent.width
                            spacing: 4

                            Repeater {
                                model: root.filteredMods

                                delegate: StyledRect {
                                    id: modRow
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 58
                                    variant: root.selectedMod?.id === modelData.id ? "primary"
                                        : (rowMouse.containsMouse || activeFocus ? "focus" : "common")
                                    radius: Styling.radius(-2)
                                    enableShadow: false
                                    activeFocusOnTab: true
                                    Accessible.role: Accessible.ListItem
                                    Accessible.name: modelData.name + ", " + (modelData.enabled ? "enabled" : "disabled")
                                    Accessible.onPressAction: root.selectedId = modelData.id

                                    Keys.onReturnPressed: root.selectedId = modelData.id
                                    Keys.onEnterPressed: root.selectedId = modelData.id
                                    Keys.onSpacePressed: root.selectedId = modelData.id

                                    DropArea {
                                        anchors.fill: parent
                                        keys: ["ambxstMod"]
                                        enabled: root.sortMode === "loadOrder" && root.searchQuery === ""
                                        property int loadOrder: modRow.modelData.order

                                        StyledRect {
                                            anchors.fill: parent
                                            visible: parent.containsDrag
                                            variant: "focus"
                                            radius: Styling.radius(-2)
                                            enableShadow: false
                                        }
                                    }

                                    MouseArea {
                                        id: rowMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            modRow.forceActiveFocus();
                                            root.selectedId = modRow.modelData.id;
                                        }
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 8
                                        spacing: 8

                                        Text {
                                            visible: root.sortMode === "loadOrder" && root.searchQuery === ""
                                            text: Icons.dotsNine
                                            font.family: Icons.font
                                            font.pixelSize: 17
                                            color: modRow.item
                                            opacity: reorderDrag.active ? 1 : 0.65
                                            Accessible.role: Accessible.Button
                                            Accessible.name: "Drag to change load order"

                                            DragHandler {
                                                id: reorderDrag
                                                target: dragPreview
                                                xAxis.enabled: false
                                                enabled: !ModsService.busy
                                                onActiveChanged: {
                                                    if (active) {
                                                        dragPreview.x = modRow.x;
                                                        dragPreview.y = modRow.y;
                                                        return;
                                                    }
                                                    const target = dragPreview.Drag.target;
                                                    if (target && target.loadOrder !== undefined
                                                            && target.loadOrder !== modRow.modelData.order)
                                                        ModsService.moveTo(modRow.modelData.id, target.loadOrder);
                                                    dragPreview.Drag.drop();
                                                }
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 1

                                            Text {
                                                Layout.fillWidth: true
                                                text: modRow.modelData.name
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(-1)
                                                font.weight: Font.DemiBold
                                                color: modRow.item
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: (modRow.modelData.version || "Unknown version") + " · "
                                                    + (!modRow.modelData.valid ? "Package error"
                                                    : !modRow.modelData.compatible ? "Incompatible"
                                                    : modRow.modelData.enabled ? "Enabled" : "Disabled")
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(-2)
                                                color: modRow.item
                                                opacity: 0.72
                                                elide: Text.ElideRight
                                            }
                                        }

                                        ActionButton {
                                            text: modRow.modelData.enabled ? "Disable" : "Enable"
                                            primary: !modRow.modelData.enabled
                                            enabled: !ModsService.busy && (modRow.modelData.enabled
                                                || (modRow.modelData.valid && modRow.modelData.compatible))
                                            onClicked: {
                                                root.selectedId = modRow.modelData.id;
                                                ModsService.setEnabled(modRow.modelData.id, !modRow.modelData.enabled);
                                            }
                                        }
                                    }

                                    Item {
                                        id: dragPreview
                                        parent: modList
                                        width: modRow.width
                                        height: modRow.height
                                        visible: reorderDrag.active
                                        z: 100

                                        StyledRect {
                                            anchors.fill: parent
                                            variant: "primary"
                                            radius: Styling.radius(-2)

                                            Text {
                                                anchors.fill: parent
                                                anchors.margins: 10
                                                text: modRow.modelData.name
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(-1)
                                                font.weight: Font.DemiBold
                                                color: parent.item
                                                verticalAlignment: Text.AlignVCenter
                                                elide: Text.ElideRight
                                            }
                                        }

                                        Drag.active: reorderDrag.active
                                        Drag.source: modRow
                                        Drag.hotSpot.x: width / 2
                                        Drag.hotSpot.y: height / 2
                                        Drag.keys: ["ambxstMod"]
                                    }
                                }
                            }
                        }
                    }
                }
            }

            StyledRect {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 420
                Layout.minimumHeight: root.width >= 680 ? 0 : 260
                variant: "pane"
                radius: Styling.radius(0)

                Text {
                    visible: !root.selectedMod
                    anchors.centerIn: parent
                    text: "Select a mod to inspect its package details."
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    color: Colors.outline
                }

                Flickable {
                    visible: !!root.selectedMod
                    anchors.fill: parent
                    anchors.margins: 14
                    contentHeight: details.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }

                    ColumnLayout {
                        id: details
                        width: parent.width
                        spacing: 8

                        Text {
                            Layout.fillWidth: true
                            text: root.selectedMod?.name ?? ""
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(1)
                            font.weight: Font.DemiBold
                            color: Colors.overBackground
                            wrapMode: Text.Wrap
                        }

                        Text {
                            Layout.fillWidth: true
                            text: (root.selectedMod?.id ?? "") + " · " + (root.selectedMod?.version ?? "")
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            color: Colors.outline
                            wrapMode: Text.WrapAnywhere
                        }

                        Text {
                            visible: (root.selectedMod?.author ?? "") !== ""
                                || (root.selectedMod?.license ?? "") !== ""
                            Layout.fillWidth: true
                            text: [root.selectedMod?.author ?? "", root.selectedMod?.license ?? ""]
                                .filter(value => value !== "").join(" · ")
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            color: Colors.outline
                            wrapMode: Text.Wrap
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.selectedMod?.description ?? ""
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            color: Colors.overBackground
                            wrapMode: Text.Wrap
                        }

                        Text {
                            visible: (root.selectedMod?.error ?? "") !== ""
                                || (root.selectedMod?.compatibilityError ?? "") !== ""
                            Layout.fillWidth: true
                            text: "Package status\n" + (root.selectedMod?.error
                                || root.selectedMod?.compatibilityError || "Unknown error")
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            color: Colors.error
                            wrapMode: Text.WrapAnywhere
                        }

                        Separator { Layout.fillWidth: true }

                        Text {
                            Layout.fillWidth: true
                            text: "Source\n" + (root.selectedMod?.source ?? "Unknown")
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            color: Colors.overBackground
                            wrapMode: Text.WrapAnywhere
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: (root.selectedMod?.revision ?? "") !== ""
                            text: "Revision\n" + (root.selectedMod?.revision ?? "")
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            color: Colors.overBackground
                            wrapMode: Text.WrapAnywhere
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Affected files\n" + ((root.selectedMod?.affectedFiles ?? []).join("\n") || "None")
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            color: Colors.overBackground
                            wrapMode: Text.WrapAnywhere
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                Layout.fillWidth: true
                                text: "Load order " + String((root.selectedMod?.order ?? 0) + 1)
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-2)
                                color: Colors.overBackground
                            }

                            ActionButton {
                                text: "Move up"
                                enabled: !ModsService.busy && (root.selectedMod?.order ?? 0) > 0
                                onClicked: ModsService.move(root.selectedMod.id, -1)
                            }

                            ActionButton {
                                text: "Move down"
                                enabled: !ModsService.busy && (root.selectedMod?.order ?? 0) < ModsService.mods.length - 1
                                onClicked: ModsService.move(root.selectedMod.id, 1)
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: (root.selectedMod?.permissions ?? []).length > 0
                            text: "Declared permissions\n" + (root.selectedMod?.permissions ?? []).join(", ")
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            color: Colors.overBackground
                            wrapMode: Text.Wrap
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: (root.selectedMod?.dependencies ?? []).length > 0
                                || (root.selectedMod?.commands ?? []).length > 0
                            text: "Requirements\n" + (root.selectedMod?.dependencies ?? [])
                                .concat(root.selectedMod?.commands ?? []).join(", ")
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            color: Colors.overBackground
                            wrapMode: Text.WrapAnywhere
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: (root.selectedMod?.conflicts ?? []).length > 0
                            text: "Conflicts\n" + (root.selectedMod?.conflicts ?? []).join(", ")
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            color: Colors.overBackground
                            wrapMode: Text.WrapAnywhere
                        }

                        ColumnLayout {
                            visible: root.selectedMod?.hasSettings ?? false
                            Layout.fillWidth: true
                            spacing: 6

                            Separator { Layout.fillWidth: true }

                            Text {
                                text: "Settings"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                font.weight: Font.DemiBold
                                color: Colors.overBackground
                            }

                            Text {
                                visible: ModsService.settingsBusy
                                text: "Loading settings…"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-2)
                                color: Colors.outline
                            }

                            Repeater {
                                model: ModsService.settingsFields

                                delegate: ColumnLayout {
                                    id: settingRow
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 3

                                    function saveTextValue(text) {
                                        let value = text;
                                        if (settingRow.modelData.type === "integer")
                                            value = parseInt(text, 10);
                                        else if (settingRow.modelData.type === "number")
                                            value = parseFloat(text);
                                        if (typeof value === "number" && !Number.isFinite(value)) {
                                            ModsService.errorMessage = "Enter a valid number.";
                                            return;
                                        }
                                        ModsService.setSetting(root.selectedMod.id, settingRow.modelData.key, value);
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 1

                                            Text {
                                                Layout.fillWidth: true
                                                text: settingRow.modelData.label
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(-1)
                                                font.weight: Font.Medium
                                                color: Colors.overBackground
                                                wrapMode: Text.Wrap
                                            }

                                            Text {
                                                visible: (settingRow.modelData.description ?? "") !== ""
                                                Layout.fillWidth: true
                                                text: settingRow.modelData.description ?? ""
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(-2)
                                                color: Colors.outline
                                                wrapMode: Text.Wrap
                                            }
                                        }

                                        ActionButton {
                                            visible: settingRow.modelData.type === "boolean"
                                            text: ModsService.settingsValues[settingRow.modelData.key] ? "On" : "Off"
                                            primary: !!ModsService.settingsValues[settingRow.modelData.key]
                                            onClicked: ModsService.setSetting(
                                                root.selectedMod.id,
                                                settingRow.modelData.key,
                                                !ModsService.settingsValues[settingRow.modelData.key]
                                            )
                                        }

                                        ActionButton {
                                            visible: settingRow.modelData.type === "enum"
                                            text: {
                                                const options = settingRow.modelData.options ?? [];
                                                const value = ModsService.settingsValues[settingRow.modelData.key];
                                                for (let i = 0; i < options.length; i++) {
                                                    if (options[i].value === value)
                                                        return options[i].label;
                                                }
                                                return String(value ?? "Select");
                                            }
                                            onClicked: {
                                                const options = settingRow.modelData.options ?? [];
                                                if (options.length === 0)
                                                    return;
                                                const value = ModsService.settingsValues[settingRow.modelData.key];
                                                let index = options.findIndex(option => option.value === value);
                                                index = (index + 1) % options.length;
                                                ModsService.setSetting(root.selectedMod.id, settingRow.modelData.key, options[index].value);
                                            }
                                        }
                                    }

                                    RowLayout {
                                        visible: settingRow.modelData.type === "string"
                                            || settingRow.modelData.type === "integer"
                                            || settingRow.modelData.type === "number"
                                        Layout.fillWidth: true
                                        spacing: 6

                                        TextField {
                                            id: settingInput
                                            Layout.fillWidth: true
                                            implicitHeight: 36
                                            text: parent.visible ? String(ModsService.settingsValues[settingRow.modelData.key] ?? "") : ""
                                            color: Colors.overBackground
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(-1)
                                            selectByMouse: true
                                            inputMethodHints: settingRow.modelData.type === "string" ? Qt.ImhNone : Qt.ImhFormattedNumbersOnly
                                            Accessible.name: settingRow.modelData.label
                                            Accessible.description: settingRow.modelData.description ?? ""
                                            background: StyledRect {
                                                variant: settingInput.activeFocus ? "focus" : "common"
                                                radius: Styling.radius(-2)
                                                enableShadow: false
                                            }
                                            onAccepted: settingRow.saveTextValue(text)
                                        }

                                        ActionButton {
                                            text: "Save"
                                            enabled: !ModsService.busy && !ModsService.settingsBusy
                                            onClicked: settingRow.saveTextValue(settingInput.text)
                                        }
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            ActionButton {
                                text: "Update"
                                onClicked: ModsService.update(root.selectedMod.id, root.selectedMod.enabled)
                            }

                            Item { Layout.fillWidth: true }

                            ActionButton {
                                text: root.removeArmedId === root.selectedMod?.id ? "Confirm remove" : "Remove"
                                destructive: true
                                onClicked: {
                                    if (root.removeArmedId !== root.selectedMod.id) {
                                        root.removeArmedId = root.selectedMod.id;
                                        return;
                                    }
                                    ModsService.remove(root.selectedMod.id, root.selectedMod.enabled);
                                    root.removeArmedId = "";
                                }
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: "Base " + (ModsService.baseVersion || "unknown")
                    + (ModsService.baseRevision ? " · " + ModsService.baseRevision.substring(0, 12) : "")
                    + " · Active " + (ModsService.activeGeneration || "base")
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                color: Colors.outline
                elide: Text.ElideMiddle
            }

            ActionButton {
                visible: ModsService.previousGeneration !== ""
                text: "Rollback"
                onClicked: ModsService.rollback()
            }
        }
    }
}
