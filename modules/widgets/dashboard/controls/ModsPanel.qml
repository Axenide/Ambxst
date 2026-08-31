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

    readonly property bool i18nActive: (ModsService.mods ?? []).some(mod =>
        mod.id === "community.i18n" && mod.enabled)
    readonly property var fallbackText: ({
        "common.off": "Off",
        "common.on": "On",
        "common.save": "Save",
        "mods.active": "Active",
        "mods.affected_files": "Affected files",
        "mods.base": "Base",
        "mods.confirm_remove": "Confirm remove",
        "mods.conflicts": "Conflicts",
        "mods.dependency_disabled": "Disabled",
        "mods.dependency_missing": "Missing",
        "mods.dependency_ready": "Ready",
        "mods.disable": "Disable",
        "mods.disabled": "Disabled",
        "mods.drag_order": "Drag to change load order",
        "mods.empty": "No mods are installed. Add a package source above.",
        "mods.enable": "Enable",
        "mods.enabled": "Enabled",
        "mods.incompatible": "Incompatible",
        "mods.install": "Install",
        "mods.install_dependencies": "Install required mods",
        "mods.invalid_number": "Enter a valid number.",
        "mods.load_order": "Load order %1",
        "mods.loading_settings": "Loading settings…",
        "mods.move_down": "Move down",
        "mods.move_up": "Move up",
        "mods.no_matches": "No installed mods match this search.",
        "mods.none": "None",
        "mods.package_error": "Package error",
        "mods.package_source": "Package source",
        "mods.package_status": "Package status",
        "mods.permissions": "Declared permissions",
        "mods.rebuild": "Rebuild",
        "mods.rebuild_required": "Rebuild required: %1",
        "mods.refresh": "Refresh mod state",
        "mods.remove": "Remove",
        "mods.required_mods": "Required mods",
        "mods.restart_now": "Restart now",
        "mods.restart_required": "Restart Ambxst to load the active generation.",
        "mods.revision": "Revision",
        "mods.rollback": "Rollback",
        "mods.search": "Search installed mods…",
        "mods.select": "Select",
        "mods.select_hint": "Select a mod to inspect its package details.",
        "mods.settings": "Settings",
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
        "mods.update": "Update",
        "mods.working": "Working…"
    })

    function tr(key, argument) {
        if (root.i18nActive) {
            try {
                if (typeof I18n !== "undefined" && typeof I18n.t === "function")
                    return I18n.t(key, argument);
            } catch (error) {
                // The English fallback keeps Mods available if the translator is unavailable.
            }
        }
        const fallback = root.fallbackText[key] ?? key;
        return argument === undefined ? fallback : fallback.replace("%1", String(argument));
    }

    function dependenciesReady(mod) {
        return (mod?.dependencyState ?? []).every(dependency => dependency.enabled);
    }

    readonly property int contentWidth: Math.max(0, Math.min(width - horizontalMargin * 2, maxContentWidth))
    readonly property bool wideLayout: contentWidth >= 900
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

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Text {
                text: root.tr("mods.package_source")
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
                        if (source !== "") {
                            ModsService.install(source);
                        }
                    }
                }

                ActionButton {
                    text: root.tr("mods.install")
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
            text: root.tr("mods.trust_warning")
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            color: Colors.outline
            wrapMode: Text.Wrap
        }

        GridLayout {
            id: managerGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: root.wideLayout && root.hasInstalledMods ? 2 : 1
            columnSpacing: 12
            rowSpacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: root.wideLayout || !root.hasInstalledMods
                Layout.preferredWidth: root.wideLayout && root.hasInstalledMods ? 380 : managerGrid.width
                Layout.preferredHeight: root.wideLayout || !root.hasInstalledMods ? 0 : 280
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    SearchInput {
                        Layout.fillWidth: true
                        placeholderText: root.tr("mods.search")
                        clearOnEscape: true
                        onSearchTextChanged: text => root.searchQuery = text
                    }

                    ActionButton {
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
                    Layout.fillHeight: true
                    Layout.minimumHeight: root.hasInstalledMods ? 180 : 260
                    variant: "pane"
                    radius: Styling.radius(0)

                    ColumnLayout {
                        visible: ModsService.loaded && root.filteredMods.length === 0
                        anchors.centerIn: parent
                        width: Math.min(parent.width - 48, 440)
                        spacing: 10

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: Icons.plug
                            font.family: Icons.font
                            font.pixelSize: 30
                            color: Colors.outline
                        }

                        Text {
                            Layout.fillWidth: true
                            text: ModsService.mods.length === 0
                                ? root.tr("mods.empty")
                                : root.tr("mods.no_matches")
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(0)
                            color: Colors.outline
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                        }
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
                                    Accessible.name: modelData.name + ", " + (modelData.enabled
                                        ? root.tr("mods.enabled") : root.tr("mods.disabled"))
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
                                                text: (modRow.modelData.version || root.tr("mods.unknown_version")) + " · "
                                                    + (!modRow.modelData.valid ? root.tr("mods.package_error")
                                                    : !modRow.modelData.compatible ? root.tr("mods.incompatible")
                                                    : modRow.modelData.enabled ? root.tr("mods.enabled") : root.tr("mods.disabled"))
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(-2)
                                                color: modRow.item
                                                opacity: 0.72
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
                                                ModsService.setEnabled(modRow.modelData.id, !modRow.modelData.enabled);
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
                visible: root.hasInstalledMods
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: root.wideLayout ? 720 : managerGrid.width
                Layout.minimumHeight: 320
                variant: "pane"
                radius: Styling.radius(0)

                Text {
                    visible: !root.selectedMod
                    anchors.centerIn: parent
                    text: root.tr("mods.select_hint")
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
                            text: root.tr("mods.package_status") + "\n" + (root.selectedMod?.error
                                || root.selectedMod?.compatibilityError || root.tr("mods.unknown_error"))
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            color: Colors.error
                            wrapMode: Text.WrapAnywhere
                        }

                        Separator { Layout.fillWidth: true }

                        Text {
                            Layout.fillWidth: true
                            text: root.tr("mods.source") + "\n" + (root.selectedMod?.source ?? root.tr("mods.unknown"))
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            color: Colors.overBackground
                            wrapMode: Text.WrapAnywhere
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: (root.selectedMod?.revision ?? "") !== ""
                            text: root.tr("mods.revision") + "\n" + (root.selectedMod?.revision ?? "")
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            color: Colors.overBackground
                            wrapMode: Text.WrapAnywhere
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.tr("mods.affected_files") + "\n"
                                + ((root.selectedMod?.affectedFiles ?? []).join("\n") || root.tr("mods.none"))
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
                                text: root.tr("mods.load_order", String((root.selectedMod?.order ?? 0) + 1))
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-2)
                                color: Colors.overBackground
                            }

                            ActionButton {
                                text: root.tr("mods.move_up")
                                enabled: !ModsService.busy && (root.selectedMod?.order ?? 0) > 0
                                onClicked: ModsService.move(root.selectedMod.id, -1)
                            }

                            ActionButton {
                                text: root.tr("mods.move_down")
                                enabled: !ModsService.busy && (root.selectedMod?.order ?? 0) < ModsService.mods.length - 1
                                onClicked: ModsService.move(root.selectedMod.id, 1)
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: (root.selectedMod?.permissions ?? []).length > 0
                            text: root.tr("mods.permissions") + "\n" + (root.selectedMod?.permissions ?? []).join(", ")
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            color: Colors.overBackground
                            wrapMode: Text.Wrap
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: (root.selectedMod?.dependencyState ?? []).length > 0
                            spacing: 4

                            Text {
                                text: root.tr("mods.required_mods")
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-2)
                                font.weight: Font.DemiBold
                                color: Colors.overBackground
                            }

                            Repeater {
                                model: root.selectedMod?.dependencyState ?? []

                                delegate: RowLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.id
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-2)
                                        color: Colors.overBackground
                                        elide: Text.ElideMiddle
                                    }

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
                                visible: !root.dependenciesReady(root.selectedMod)
                                text: root.tr("mods.install_dependencies")
                                primary: true
                                enabled: !ModsService.busy
                                onClicked: ModsService.installDependencies(root.selectedMod.id)
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: (root.selectedMod?.commands ?? []).length > 0
                            text: root.tr("mods.requirements") + "\n" + (root.selectedMod?.commands ?? []).join(", ")
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            color: Colors.overBackground
                            wrapMode: Text.WrapAnywhere
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: (root.selectedMod?.conflicts ?? []).length > 0
                            text: root.tr("mods.conflicts") + "\n" + (root.selectedMod?.conflicts ?? []).join(", ")
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
                                            text: root.tr("common.save")
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
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: root.tr("mods.base") + " " + (ModsService.baseVersion || root.tr("mods.unknown"))
                    + (ModsService.baseRevision ? " · " + ModsService.baseRevision.substring(0, 12) : "")
                    + " · " + root.tr("mods.active") + " " + (ModsService.activeGeneration || "base")
                font.family: Config.theme.font
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
