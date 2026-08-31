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

    property int maxContentWidth: 1240
    property int horizontalMargin: 20
    property string searchQuery: ""
    property string sortMode: "name"
    property string selectedId: ""
    property string removeArmedId: ""
    property bool filesExpanded: false

    // Pending action awaiting the trust confirmation. "" means no prompt.
    property string confirmKind: ""
    property string confirmSource: ""
    property var confirmMod: null

    readonly property bool i18nActive: (ModsService.mods ?? []).some(mod =>
        mod.id === "community.i18n" && mod.enabled)
    readonly property var fallbackText: ({
        "common.cancel": "Cancel",
        "common.off": "Off",
        "common.on": "On",
        "common.save": "Save",
        "mods.active": "Active",
        "mods.affected_files": "Affected files",
        "mods.author": "Author",
        "mods.base": "Base",
        "mods.confirm_enable_body": "Enabling rebuilds the shell with this package's source changes. Its code then runs with your user permissions, like the rest of Ambxst. Read the patch and check who wrote it first.",
        "mods.confirm_enable_title": "Do you trust this mod?",
        "mods.confirm_install_body": "Installing downloads the package and leaves it disabled. Nothing from it runs until you enable it, which is the moment to have read the code.",
        "mods.confirm_install_title": "Install from this source?",
        "mods.confirm_remove": "Confirm remove",
        "mods.conflicts": "Conflicts",
        "mods.dependency_disabled": "Disabled",
        "mods.dependency_missing": "Missing",
        "mods.dependency_ready": "Ready",
        "mods.disable": "Disable",
        "mods.disabled": "Disabled",
        "mods.drag_order": "Drag to change load order",
        "mods.empty": "No mods installed yet. Paste a package source above.",
        "mods.enable": "Enable",
        "mods.enabled": "Enabled",
        "mods.hide_files": "Hide",
        "mods.homepage": "Mod page",
        "mods.incompatible": "Incompatible",
        "mods.install": "Install",
        "mods.install_dependencies": "Install required mods",
        "mods.installed_count": "Installed · %1",
        "mods.invalid_number": "Enter a valid number.",
        "mods.license": "License",
        "mods.load_order": "Load order",
        "mods.loading_settings": "Loading settings…",
        "mods.move_down": "Move down",
        "mods.move_up": "Move up",
        "mods.no_matches": "No installed mods match this search.",
        "mods.none": "None",
        "mods.open_link": "Open",
        "mods.package_error": "Package error",
        "mods.package_source": "Package source",
        "mods.package_status": "Package status",
        "mods.permissions": "Declared permissions",
        "mods.rebuild": "Rebuild",
        "mods.rebuild_required": "Rebuild required: %1",
        "mods.refresh": "Refresh mod state",
        "mods.remove": "Remove",
        "mods.required_mods": "Required mods",
        "mods.requirements": "Required commands",
        "mods.restart_now": "Restart now",
        "mods.restart_required": "Restart Ambxst to load the active generation.",
        "mods.revision": "Revision",
        "mods.rollback": "Rollback",
        "mods.search": "Search installed mods…",
        "mods.select": "Select",
        "mods.select_hint": "Select a mod to inspect its package details.",
        "mods.settings": "Settings",
        "mods.show_files": "Show %1",
        "mods.sort_load_order": "Sort: Load order",
        "mods.sort_name": "Sort: Name",
        "mods.sort_state": "Sort: State",
        "mods.source": "Source",
        "mods.source_placeholder": "Local directory, package archive, or Git URL",
        "mods.status_dependencies_installed": "Required mods installed and enabled.",
        "mods.status_disabled": "Mod disabled.",
        "mods.status_enabled": "Mod enabled.",
        "mods.status_installed": "Mod installed in the disabled state.",
        "mods.status_order_updated": "Load order updated.",
        "mods.status_rebuilt": "Generation rebuilt.",
        "mods.status_removed": "Mod removed.",
        "mods.status_rolled_back": "Previous generation restored.",
        "mods.status_setting_saved": "Setting saved.",
        "mods.status_updated": "Mod updated.",
        "mods.title": "Mods",
        "mods.trust_warning": "Packages run with your user permissions. Install code only from sources you trust.",
        "mods.unknown": "Unknown",
        "mods.unknown_error": "Unknown error",
        "mods.unknown_version": "Unknown version",
        "mods.unknown_fields": "Manifest keys this Ambxst does not know: %1",
        "mods.untested_base": "%1. You can still enable it.",
        "mods.update": "Update",
        "mods.working": "Working…"
    })

    function tr(key, argument) {
        const fallback = root.fallbackText[key] ?? key;
        if (root.i18nActive) {
            try {
                if (typeof I18n !== "undefined" && typeof I18n.t === "function") {
                    // Ask only for keys the translator actually carries. A mod
                    // built against an older panel would otherwise answer every
                    // key with a humanised guess, which reads worse than the
                    // English string shipped right here.
                    const strings = I18n.strings ?? ({});
                    const base = I18n.fallback ?? ({});
                    if (strings[key] !== undefined || base[key] !== undefined)
                        return argument === undefined ? I18n.t(key) : I18n.t(key, argument);
                }
            } catch (error) {
                // The English fallback keeps Mods available if the translator is unavailable.
            }
        }
        return argument === undefined ? fallback : fallback.replace("%1", String(argument));
    }

    function dependenciesReady(mod) {
        return (mod?.dependencyState ?? []).every(dependency => dependency.enabled);
    }

    function stateLabel(mod) {
        if (!mod)
            return "";
        if (!mod.valid)
            return root.tr("mods.package_error");
        if (!mod.compatible)
            return root.tr("mods.incompatible");
        return mod.enabled ? root.tr("mods.enabled") : root.tr("mods.disabled");
    }

    function stateColor(mod) {
        if (!mod || !mod.valid || !mod.compatible)
            return Colors.error;
        if (mod.untested)
            return Colors.warning;
        return mod.enabled ? Colors.primary : Colors.outline;
    }

    function askConfirm(kind, mod, source) {
        root.confirmKind = kind;
        root.confirmMod = mod ?? null;
        root.confirmSource = source ?? "";
    }

    function closeConfirm() {
        root.confirmKind = "";
        root.confirmMod = null;
        root.confirmSource = "";
    }

    function runConfirmed() {
        const kind = root.confirmKind;
        const mod = root.confirmMod;
        const source = root.confirmSource;
        root.closeConfirm();
        if (kind === "install")
            ModsService.install(source);
        else if (kind === "enable" && mod)
            ModsService.setEnabled(mod.id, true);
    }

    readonly property int contentWidth: Math.max(0, Math.min(width - horizontalMargin * 2, maxContentWidth))
    readonly property bool hasInstalledMods: (ModsService.mods ?? []).length > 0
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
    // Derived from selectedMod instead of written back into selectedId; that
    // write-back is what made the selection bind to itself in a loop.
    readonly property string effectiveId: root.selectedMod?.id ?? ""

    onEffectiveIdChanged: {
        ModsService.loadSettings(root.effectiveId);
        root.removeArmedId = "";
        root.filesExpanded = false;
    }

    Component.onCompleted: ModsService.refresh()

    // The daemon clears the restart flag when a new generation survives its
    // health window, and the panel can already be open at that moment. This
    // re-reads only while that banner is on screen and stops with it.
    Timer {
        interval: 5000
        repeat: true
        running: root.visible && ModsService.restartRequired && !ModsService.busy
        onTriggered: ModsService.refresh()
    }

    // The daemon clears the restart flag once a new generation survives its
    // health window. Re-reading on show keeps the banner from outliving it.
    onVisibleChanged: {
        if (visible)
            ModsService.refresh();
    }

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

        implicitHeight: 34
        leftPadding: 14
        rightPadding: 14
        enabled: !ModsService.busy
        opacity: enabled ? 1 : 0.45

        background: StyledRect {
            // "common" resolves to the same surface as the card behind it, so a
            // resting secondary button used to read as plain text. "focus" is
            // one step brighter and keeps the control visible on both grounds.
            variant: action.primary
                ? ((action.hovered || action.down) ? "primaryfocus" : "primary")
                : ((action.hovered || action.down || action.activeFocus)
                    ? (action.destructive ? "error" : "secondary") : "focus")
            radius: Styling.radius(-2)
            enableShadow: false
        }

        contentItem: Text {
            text: action.text
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            font.weight: action.primary ? Font.DemiBold : Font.Medium
            color: action.primary ? Styling.srItem("primary")
                : action.destructive && !action.hovered ? Colors.error
                : Colors.overBackground
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
    }

    // One label/value line. The label column has a fixed width so a stack of
    // these reads as a table instead of loose paragraphs.
    component MetaRow: RowLayout {
        id: meta
        property string label: ""
        property string value: ""
        property bool mono: false
        default property alias trailing: trailingSlot.data

        Layout.fillWidth: true
        spacing: 10

        Text {
            Layout.preferredWidth: 118
            Layout.alignment: Qt.AlignTop
            text: meta.label
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            color: Colors.outline
            wrapMode: Text.Wrap
        }

        Text {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            visible: meta.value !== ""
            text: meta.value
            font.family: meta.mono ? Config.theme.monoFont : Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            color: Colors.overBackground
            wrapMode: Text.WrapAnywhere
        }

        RowLayout {
            id: trailingSlot
            Layout.alignment: Qt.AlignVCenter
            spacing: 6
        }
    }

    Flickable {
        id: mainFlickable
        anchors.fill: parent
        contentHeight: mainColumn.implicitHeight + 8
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: root.confirmKind === ""

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        ColumnLayout {
            id: mainColumn
            width: root.contentWidth
            x: Math.max(0, (mainFlickable.width - width) / 2)
            spacing: 10

            PanelTitlebar {
                title: root.tr("mods.title")
                statusText: ModsService.busy ? root.tr("mods.working") : ""
                actions: [
                    {
                        icon: Icons.arrowCounterClockwise,
                        tooltip: root.tr("mods.refresh"),
                        enabled: !ModsService.busy,
                        onClicked: function () { ModsService.refresh(); }
                    }
                ]

                ActionButton {
                    text: root.tr("mods.rebuild")
                    onClicked: ModsService.rebuild()
                }
            }

            StyledRect {
                visible: !ModsService.generationCurrent || ModsService.restartRequired
                    || ModsService.errorMessage !== "" || ModsService.statusMessage !== ""
                    || ModsService.statusMessageKey !== ""
                Layout.fillWidth: true
                Layout.preferredHeight: statusRow.implicitHeight + 18
                variant: ModsService.errorMessage !== "" || !ModsService.generationCurrent ? "focus" : "common"
                radius: Styling.radius(-2)
                enableShadow: false

                RowLayout {
                    id: statusRow
                    anchors.fill: parent
                    anchors.margins: 9
                    spacing: 10

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: ModsService.errorMessage !== "" || !ModsService.generationCurrent
                            ? Icons.alert : (ModsService.restartRequired ? Icons.arrowCounterClockwise : Icons.accept)
                        font.family: Icons.font
                        font.pixelSize: 16
                        color: ModsService.errorMessage !== "" || !ModsService.generationCurrent ? Colors.error : Colors.overBackground
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        text: ModsService.errorMessage !== "" ? ModsService.errorMessage
                            : !ModsService.generationCurrent ? root.tr("mods.rebuild_required", ModsService.generationError)
                            : ModsService.restartRequired ? root.tr("mods.restart_required")
                            : ModsService.statusMessageKey !== "" ? root.tr(ModsService.statusMessageKey)
                            : ModsService.statusMessage
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        color: ModsService.errorMessage !== "" || !ModsService.generationCurrent ? Colors.error : Colors.overBackground
                        wrapMode: Text.Wrap
                    }

                    ActionButton {
                        visible: !ModsService.generationCurrent
                        text: root.tr("mods.rebuild")
                        primary: true
                        onClicked: ModsService.rebuild()
                    }

                    ActionButton {
                        visible: ModsService.restartRequired
                        text: root.tr("mods.restart_now")
                        primary: true
                        onClicked: ModsService.restart()
                    }
                }
            }

            StyledRect {
                Layout.fillWidth: true
                Layout.preferredHeight: installColumn.implicitHeight + 28
                variant: "pane"
                radius: Styling.radius(0)

                ColumnLayout {
                    id: installColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 14
                    spacing: 8

                    Text {
                        text: root.tr("mods.package_source")
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        font.weight: Font.DemiBold
                        color: Colors.overBackground
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        TextField {
                            id: sourceInput
                            Layout.fillWidth: true
                            implicitHeight: 38
                            placeholderText: root.tr("mods.source_placeholder")
                            color: Colors.overBackground
                            placeholderTextColor: Colors.outline
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            selectByMouse: true
                            enabled: !ModsService.busy
                            Accessible.name: root.tr("mods.package_source")
                            Accessible.description: root.tr("mods.source_placeholder")

                            background: StyledRect {
                                variant: sourceInput.activeFocus ? "focus" : "common"
                                radius: Styling.radius(-2)
                                enableShadow: false
                            }

                            onAccepted: {
                                const source = text.trim();
                                if (source !== "")
                                    root.askConfirm("install", null, source);
                            }
                        }

                        ActionButton {
                            text: root.tr("mods.install")
                            primary: true
                            enabled: !ModsService.busy && sourceInput.text.trim() !== ""
                            onClicked: root.askConfirm("install", null, sourceInput.text.trim())
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.tr("mods.trust_warning")
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-2)
                        color: Colors.outline
                        wrapMode: Text.Wrap
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2
                spacing: 8

                Text {
                    text: root.tr("mods.installed_count", String((ModsService.mods ?? []).length))
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    font.weight: Font.DemiBold
                    color: Colors.overBackground
                }

                Item { Layout.fillWidth: true }

                SearchInput {
                    Layout.preferredWidth: 220
                    visible: root.hasInstalledMods
                    placeholderText: root.tr("mods.search")
                    clearOnEscape: true
                    onSearchTextChanged: text => root.searchQuery = text
                }

                ActionButton {
                    visible: root.hasInstalledMods
                    text: root.sortMode === "name" ? root.tr("mods.sort_name")
                        : root.sortMode === "state" ? root.tr("mods.sort_state")
                        : root.tr("mods.sort_load_order")
                    onClicked: root.sortMode = root.sortMode === "name" ? "state"
                        : root.sortMode === "state" ? "loadOrder"
                        : "name"
                }
            }

            StyledRect {
                Layout.fillWidth: true
                Layout.preferredHeight: root.filteredMods.length > 0
                    ? modList.implicitHeight + 16
                    : emptyState.implicitHeight + 48
                variant: "pane"
                radius: Styling.radius(0)

                ColumnLayout {
                    id: emptyState
                    visible: ModsService.loaded && root.filteredMods.length === 0
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 48, 420)
                    spacing: 10

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Icons.plug
                        font.family: Icons.font
                        font.pixelSize: 28
                        color: Colors.outline
                    }

                    Text {
                        Layout.fillWidth: true
                        text: (ModsService.mods ?? []).length === 0
                            ? root.tr("mods.empty")
                            : root.tr("mods.no_matches")
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        color: Colors.outline
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                    }
                }

                ColumnLayout {
                    id: modList
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 8
                    spacing: 4

                    Repeater {
                        model: root.filteredMods

                        delegate: StyledRect {
                            id: modRow
                            required property var modelData
                            readonly property bool current: root.effectiveId === modelData.id

                            Layout.fillWidth: true
                            Layout.preferredHeight: 54
                            variant: modRow.current ? "primary"
                                : (rowMouse.containsMouse || activeFocus ? "focus" : "common")
                            radius: Styling.radius(-2)
                            enableShadow: false
                            activeFocusOnTab: true
                            Accessible.role: Accessible.ListItem
                            Accessible.name: modelData.name + ", " + root.stateLabel(modelData)
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
                                spacing: 10

                                Text {
                                    visible: root.sortMode === "loadOrder" && root.searchQuery === ""
                                    text: Icons.dotsNine
                                    font.family: Icons.font
                                    font.pixelSize: 17
                                    color: modRow.item
                                    opacity: reorderDrag.active ? 1 : 0.6
                                    Accessible.role: Accessible.Button
                                    Accessible.name: root.tr("mods.drag_order")

                                    DragHandler {
                                        id: reorderDrag
                                        target: dragPreview
                                        xAxis.enabled: false
                                        enabled: !ModsService.busy
                                        onActiveChanged: {
                                            if (active) {
                                                const point = modRow.mapToItem(dragPreview.parent, 0, 0);
                                                dragPreview.x = point.x;
                                                dragPreview.y = point.y;
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

                                // Status rail: the state is readable before any text is.
                                Rectangle {
                                    Layout.alignment: Qt.AlignVCenter
                                    implicitWidth: 6
                                    implicitHeight: 6
                                    radius: 3
                                    color: modRow.current ? modRow.item : root.stateColor(modRow.modelData)
                                    opacity: modRow.modelData.enabled || !modRow.modelData.valid ? 1 : 0.55
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
                                        text: (modRow.modelData.version || root.tr("mods.unknown_version"))
                                            + " · " + root.stateLabel(modRow.modelData)
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-2)
                                        color: modRow.item
                                        opacity: 0.7
                                        elide: Text.ElideRight
                                    }
                                }

                                ActionButton {
                                    text: modRow.modelData.enabled ? root.tr("mods.disable") : root.tr("mods.enable")
                                    primary: !modRow.modelData.enabled
                                    enabled: !ModsService.busy && (modRow.modelData.enabled
                                        || (modRow.modelData.valid && modRow.modelData.compatible
                                            && root.dependenciesReady(modRow.modelData)))
                                    onClicked: {
                                        root.selectedId = modRow.modelData.id;
                                        if (modRow.modelData.enabled) {
                                            ModsService.setEnabled(modRow.modelData.id, false);
                                            return;
                                        }
                                        root.askConfirm("enable", modRow.modelData, modRow.modelData.source ?? "");
                                    }
                                }
                            }

                            Item {
                                id: dragPreview
                                parent: modList.parent
                                width: modRow.width
                                height: modRow.height
                                visible: reorderDrag.active
                                z: 100

                                StyledRect {
                                    id: dragPreviewSurface
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
                                        color: dragPreviewSurface.item
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

            StyledRect {
                visible: root.hasInstalledMods && !!root.selectedMod
                Layout.fillWidth: true
                Layout.preferredHeight: details.implicitHeight + 28
                variant: "pane"
                radius: Styling.radius(0)

                ColumnLayout {
                    id: details
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 14
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: root.selectedMod?.name ?? ""
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(1)
                                font.weight: Font.DemiBold
                                color: Colors.overBackground
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: (root.selectedMod?.id ?? "") + " · " + (root.selectedMod?.version ?? "")
                                font.family: Config.theme.monoFont
                                font.pixelSize: Styling.fontSize(-2)
                                color: Colors.outline
                                elide: Text.ElideRight
                            }
                        }

                        StyledRect {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: stateChip.implicitWidth + 20
                            implicitHeight: 24
                            variant: "focus"
                            radius: Styling.radius(-2)
                            enableShadow: false

                            Text {
                                id: stateChip
                                anchors.centerIn: parent
                                text: root.stateLabel(root.selectedMod)
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-2)
                                font.weight: Font.Medium
                                color: root.stateColor(root.selectedMod)
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: (root.selectedMod?.description ?? "") !== ""
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
                        text: root.tr("mods.package_status") + ": " + (root.selectedMod?.error
                            || root.selectedMod?.compatibilityError || root.tr("mods.unknown_error"))
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-2)
                        color: Colors.error
                        wrapMode: Text.WrapAnywhere
                    }

                    Text {
                        visible: (root.selectedMod?.untestedMessage ?? "") !== ""
                        Layout.fillWidth: true
                        text: root.tr("mods.untested_base", root.selectedMod?.untestedMessage ?? "")
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-2)
                        color: Colors.warning
                        wrapMode: Text.Wrap
                    }

                    Text {
                        visible: (root.selectedMod?.unknownFields ?? []).length > 0
                        Layout.fillWidth: true
                        text: root.tr("mods.unknown_fields", (root.selectedMod?.unknownFields ?? []).join(", "))
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-2)
                        color: Colors.warning
                        wrapMode: Text.Wrap
                    }

                    Separator { Layout.fillWidth: true }

                    MetaRow {
                        visible: (root.selectedMod?.author ?? "") !== ""
                        label: root.tr("mods.author")
                        value: root.selectedMod?.author ?? ""

                        ActionButton {
                            visible: (root.selectedMod?.authorUrl ?? "") !== ""
                            text: root.tr("mods.open_link")
                            onClicked: Qt.openUrlExternally(root.selectedMod.authorUrl)
                        }
                    }

                    MetaRow {
                        visible: (root.selectedMod?.license ?? "") !== ""
                        label: root.tr("mods.license")
                        value: root.selectedMod?.license ?? ""
                    }

                    MetaRow {
                        label: root.tr("mods.source")
                        value: root.selectedMod?.source ?? root.tr("mods.unknown")
                        mono: true

                        ActionButton {
                            visible: (root.selectedMod?.source ?? "").startsWith("http")
                            text: root.tr("mods.open_link")
                            onClicked: Qt.openUrlExternally(root.selectedMod.source)
                        }
                    }

                    MetaRow {
                        visible: (root.selectedMod?.homepage ?? "") !== ""
                        label: root.tr("mods.homepage")
                        value: root.selectedMod?.homepage ?? ""
                        mono: true

                        ActionButton {
                            text: root.tr("mods.open_link")
                            onClicked: Qt.openUrlExternally(root.selectedMod.homepage)
                        }
                    }

                    MetaRow {
                        visible: (root.selectedMod?.revision ?? "") !== ""
                        label: root.tr("mods.revision")
                        value: (root.selectedMod?.revision ?? "").substring(0, 12)
                        mono: true
                    }

                    MetaRow {
                        label: root.tr("mods.load_order")
                        value: String((root.selectedMod?.order ?? 0) + 1)

                        ActionButton {
                            text: root.tr("mods.move_up")
                            enabled: !ModsService.busy && (root.selectedMod?.order ?? 0) > 0
                            onClicked: ModsService.move(root.selectedMod.id, -1)
                        }

                        ActionButton {
                            text: root.tr("mods.move_down")
                            enabled: !ModsService.busy
                                && (root.selectedMod?.order ?? 0) < (ModsService.mods ?? []).length - 1
                            onClicked: ModsService.move(root.selectedMod.id, 1)
                        }
                    }

                    MetaRow {
                        visible: (root.selectedMod?.permissions ?? []).length > 0
                        label: root.tr("mods.permissions")
                        value: (root.selectedMod?.permissions ?? []).join(", ")
                    }

                    MetaRow {
                        visible: (root.selectedMod?.commands ?? []).length > 0
                        label: root.tr("mods.requirements")
                        value: (root.selectedMod?.commands ?? []).join(", ")
                        mono: true
                    }

                    MetaRow {
                        visible: (root.selectedMod?.conflicts ?? []).length > 0
                        label: root.tr("mods.conflicts")
                        value: (root.selectedMod?.conflicts ?? []).join(", ")
                        mono: true
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: (root.selectedMod?.dependencyState ?? []).length > 0
                        spacing: 4

                        Repeater {
                            model: root.selectedMod?.dependencyState ?? []

                            delegate: MetaRow {
                                required property var modelData
                                required property int index
                                label: index === 0 ? root.tr("mods.required_mods") : ""
                                value: modelData.id
                                mono: true

                                Text {
                                    text: modelData.enabled ? root.tr("mods.dependency_ready")
                                        : modelData.installed ? root.tr("mods.dependency_disabled")
                                        : root.tr("mods.dependency_missing")
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-2)
                                    font.weight: Font.Medium
                                    color: modelData.enabled ? Colors.success : Colors.warning
                                }
                            }
                        }

                        ActionButton {
                            Layout.leftMargin: 128
                            visible: !root.dependenciesReady(root.selectedMod)
                            text: root.tr("mods.install_dependencies")
                            primary: true
                            enabled: !ModsService.busy
                            onClicked: ModsService.installDependencies(root.selectedMod.id)
                        }
                    }

                    MetaRow {
                        label: root.tr("mods.affected_files")
                        value: (root.selectedMod?.affectedFiles ?? []).length === 0 ? root.tr("mods.none") : ""

                        ActionButton {
                            visible: (root.selectedMod?.affectedFiles ?? []).length > 0
                            text: root.filesExpanded ? root.tr("mods.hide_files")
                                : root.tr("mods.show_files", String((root.selectedMod?.affectedFiles ?? []).length))
                            onClicked: root.filesExpanded = !root.filesExpanded
                        }
                    }

                    StyledRect {
                        visible: root.filesExpanded && (root.selectedMod?.affectedFiles ?? []).length > 0
                        Layout.fillWidth: true
                        Layout.leftMargin: 128
                        Layout.preferredHeight: fileList.implicitHeight + 16
                        variant: "common"
                        radius: Styling.radius(-2)
                        enableShadow: false

                        ColumnLayout {
                            id: fileList
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 8
                            spacing: 2

                            Repeater {
                                model: root.selectedMod?.affectedFiles ?? []

                                delegate: Text {
                                    required property string modelData
                                    Layout.fillWidth: true
                                    text: modelData
                                    font.family: Config.theme.monoFont
                                    font.pixelSize: Styling.fontSize(-2)
                                    color: Colors.overBackground
                                    elide: Text.ElideLeft
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        visible: root.selectedMod?.hasSettings ?? false
                        Layout.fillWidth: true
                        spacing: 6

                        Separator { Layout.fillWidth: true }

                        Text {
                            text: root.tr("mods.settings")
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: Font.DemiBold
                            color: Colors.overBackground
                        }

                        Text {
                            visible: ModsService.settingsBusy
                            text: root.tr("mods.loading_settings")
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
                                        ModsService.errorMessage = root.tr("mods.invalid_number");
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
                                        text: ModsService.settingsValues[settingRow.modelData.key]
                                            ? root.tr("common.on") : root.tr("common.off")
                                        primary: !!ModsService.settingsValues[settingRow.modelData.key]
                                        enabled: !ModsService.busy && !ModsService.settingsBusy
                                        onClicked: ModsService.setSetting(root.selectedMod.id,
                                            settingRow.modelData.key,
                                            !ModsService.settingsValues[settingRow.modelData.key])
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
                                            return String(value ?? root.tr("mods.select"));
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
                                        implicitHeight: 34
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
                                        text: root.tr("common.save")
                                        enabled: !ModsService.busy && !ModsService.settingsBusy
                                        onClicked: settingRow.saveTextValue(settingInput.text)
                                    }
                                }
                            }
                        }
                    }

                    Separator { Layout.fillWidth: true }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        ActionButton {
                            text: root.selectedMod?.enabled ? root.tr("mods.disable") : root.tr("mods.enable")
                            primary: !root.selectedMod?.enabled
                            enabled: !ModsService.busy && (root.selectedMod?.enabled
                                || (root.selectedMod?.valid && root.selectedMod?.compatible
                                    && root.dependenciesReady(root.selectedMod)))
                            onClicked: {
                                if (root.selectedMod.enabled) {
                                    ModsService.setEnabled(root.selectedMod.id, false);
                                    return;
                                }
                                root.askConfirm("enable", root.selectedMod, root.selectedMod.source ?? "");
                            }
                        }

                        ActionButton {
                            text: root.tr("mods.update")
                            onClicked: ModsService.update(root.selectedMod.id, root.selectedMod.enabled)
                        }

                        Item { Layout.fillWidth: true }

                        ActionButton {
                            text: root.removeArmedId === root.selectedMod?.id
                                ? root.tr("mods.confirm_remove") : root.tr("mods.remove")
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

            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 4
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: root.tr("mods.base") + " " + (ModsService.baseVersion || root.tr("mods.unknown"))
                        + (ModsService.baseRevision ? " · " + ModsService.baseRevision.substring(0, 12) : "")
                        + " · " + root.tr("mods.active") + " " + (ModsService.activeGeneration || "base")
                    font.family: Config.theme.monoFont
                    font.pixelSize: Styling.fontSize(-2)
                    color: Colors.outline
                    elide: Text.ElideMiddle
                }

                ActionButton {
                    visible: ModsService.previousGeneration !== ""
                    text: root.tr("mods.rollback")
                    onClicked: ModsService.rollback()
                }
            }
        }
    }

    // Trust prompt. Installing and enabling both bring somebody else's code
    // into the shell, so both say whose code it is before it happens.
    Item {
        anchors.fill: parent
        visible: root.confirmKind !== ""
        z: 50

        Rectangle {
            anchors.fill: parent
            color: Colors.scrim
            opacity: 0.55

            MouseArea {
                anchors.fill: parent
                onClicked: root.closeConfirm()
            }
        }

        StyledRect {
            anchors.centerIn: parent
            width: Math.min(root.width - 48, 460)
            height: confirmColumn.implicitHeight + 36
            variant: "popup"
            radius: Styling.radius(1)

            MouseArea {
                anchors.fill: parent
            }

            ColumnLayout {
                id: confirmColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 18
                spacing: 10

                Text {
                    Layout.fillWidth: true
                    text: root.confirmKind === "enable"
                        ? root.tr("mods.confirm_enable_title")
                        : root.tr("mods.confirm_install_title")
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(1)
                    font.weight: Font.DemiBold
                    color: Colors.overBackground
                    wrapMode: Text.Wrap
                }

                Text {
                    Layout.fillWidth: true
                    text: root.confirmKind === "enable"
                        ? root.tr("mods.confirm_enable_body")
                        : root.tr("mods.confirm_install_body")
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    color: Colors.overBackground
                    wrapMode: Text.Wrap
                }

                Separator { Layout.fillWidth: true }

                MetaRow {
                    visible: (root.confirmMod?.author ?? "") !== ""
                    label: root.tr("mods.author")
                    value: root.confirmMod?.author ?? ""

                    ActionButton {
                        visible: (root.confirmMod?.authorUrl ?? "") !== ""
                        text: root.tr("mods.open_link")
                        onClicked: Qt.openUrlExternally(root.confirmMod.authorUrl)
                    }
                }

                MetaRow {
                    visible: (root.confirmMod?.license ?? "") !== ""
                    label: root.tr("mods.license")
                    value: root.confirmMod?.license ?? ""
                }

                MetaRow {
                    visible: root.confirmSource !== ""
                    label: root.tr("mods.source")
                    value: root.confirmSource
                    mono: true

                    ActionButton {
                        visible: root.confirmSource.startsWith("http")
                        text: root.tr("mods.open_link")
                        onClicked: Qt.openUrlExternally(root.confirmSource)
                    }
                }

                MetaRow {
                    visible: (root.confirmMod?.homepage ?? "") !== ""
                    label: root.tr("mods.homepage")
                    value: root.confirmMod?.homepage ?? ""
                    mono: true

                    ActionButton {
                        text: root.tr("mods.open_link")
                        onClicked: Qt.openUrlExternally(root.confirmMod.homepage)
                    }
                }

                MetaRow {
                    visible: (root.confirmMod?.permissions ?? []).length > 0
                    label: root.tr("mods.permissions")
                    value: (root.confirmMod?.permissions ?? []).join(", ")
                }

                MetaRow {
                    visible: (root.confirmMod?.affectedFiles ?? []).length > 0
                    label: root.tr("mods.affected_files")
                    value: String((root.confirmMod?.affectedFiles ?? []).length)
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 8

                    Item { Layout.fillWidth: true }

                    ActionButton {
                        text: root.tr("common.cancel")
                        onClicked: root.closeConfirm()
                    }

                    ActionButton {
                        text: root.confirmKind === "enable" ? root.tr("mods.enable") : root.tr("mods.install")
                        primary: true
                        onClicked: root.runConfirmed()
                    }
                }
            }
        }
    }
}
