pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.globals
import qs.config

Item {
    id: root

    property int maxContentWidth: 480
    readonly property int contentWidth: Math.min(width, maxContentWidth)
    readonly property real sideMargin: (width - contentWidth) / 2

    property string currentSection: ""

    // I18n helper — returns English fallback when I18n is unavailable or key missing
    function tr(key, fallback) {
        try {
            const val = I18n.t(key);
            return (val && val !== key) ? val : fallback;
        } catch (e) {
            return fallback;
        }
    }

    component SectionButton: StyledRect {
        id: sectionBtn
        required property string text
        required property string sectionId

        property bool isHovered: false

        variant: isHovered ? "focus" : "pane"
        Layout.fillWidth: true
        Layout.preferredHeight: 56
        radius: Styling.radius(0)

        RowLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 16

            Text {
                text: sectionBtn.text
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(0)
                font.bold: true
                color: Colors.overBackground
                Layout.fillWidth: true
            }

            Text {
                text: Icons.caretRight
                font.family: Icons.font
                font.pixelSize: 20
                color: Colors.overSurfaceVariant
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: sectionBtn.isHovered = true
            onExited: sectionBtn.isHovered = false
            onClicked: root.currentSection = sectionBtn.sectionId
        }
    }

    // Option selector — same visual style as ShellPanel/CompositorPanel
    component SelectorRow: RowLayout {
        id: selectorRow
        property var options: []   // [{ label: string, value: string }]
        property string value: ""
        signal valueSelected(string newValue)

        Layout.fillWidth: true
        spacing: 4

        Repeater {
            model: selectorRow.options

            delegate: StyledRect {
                id: optBtn
                required property var modelData
                required property int index

                readonly property bool isSelected: optBtn.modelData.value === selectorRow.value
                property bool isHovered: false

                variant: isSelected ? "primary" : (isHovered ? "focus" : "common")
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: Styling.radius(0)

                Text {
                    anchors.centerIn: parent
                    text: optBtn.modelData.label
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(0)
                    font.weight: optBtn.isSelected ? Font.DemiBold : Font.Normal
                    color: optBtn.item
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: optBtn.isHovered = true
                    onExited: optBtn.isHovered = false
                    onClicked: selectorRow.valueSelected(optBtn.modelData.value)
                }
            }
        }
    }

    // Main content
    Flickable {
        id: mainFlickable
        anchors.fill: parent
        contentHeight: mainColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: mainColumn
            width: mainFlickable.width
            spacing: 8

            // Header wrapper
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: titlebar.height

                PanelTitlebar {
                    id: titlebar
                    width: root.contentWidth
                    anchors.horizontalCenter: parent.horizontalCenter
                    title: root.currentSection === "" ? "System" : (root.currentSection === "system" ? "System Resources" : (root.currentSection.charAt(0).toUpperCase() + root.currentSection.slice(1)))
                    statusText: {
                        if (root.currentSection === "system") {
                            if (systemSection.savedSuccess)
                                return root.tr("system.resources.saved", "Saved");
                            if (systemSection.hasChanges)
                                return root.tr("system.resources.unsaved", "Unsaved changes");
                        }
                        return "";
                    }
                    statusColor: systemSection.savedSuccess ? Colors.green : Styling.srItem("overprimary")

                    actions: {
                        let acts = [];
                        if (root.currentSection !== "") {
                            acts.push({
                                icon: Icons.arrowLeft,
                                tooltip: "Back",
                                onClicked: function () { root.currentSection = ""; }
                            });
                        }
                        if (root.currentSection === "system" && systemSection.hasChanges) {
                            acts.push({
                                icon: Icons.accept,
                                tooltip: root.tr("settings.save", "Save"),
                                onClicked: function () { systemSection.saveToConfig(); }
                            });
                        }
                        return acts;
                    }
                }
            }

            // Content wrapper - centered
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: contentColumn.implicitHeight

                ColumnLayout {
                    id: contentColumn
                    width: root.contentWidth
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 16

                    // ═══════════════════════════════════════════════════════════════
                    // MENU SECTION
                    // ═══════════════════════════════════════════════════════════════
                    ColumnLayout {
                        visible: root.currentSection === ""
                        Layout.fillWidth: true
                        spacing: 8

                        SectionButton {
                            text: "Prefixes"
                            sectionId: "prefixes"
                        }
                        SectionButton {
                            text: "Weather"
                            sectionId: "weather"
                        }
                        SectionButton {
                            text: "Performance"
                            sectionId: "performance"
                        }
                        SectionButton {
                            text: "System Resources"
                            sectionId: "system"
                        }
                        SectionButton {
                            text: "Idle"
                            sectionId: "idle"
                        }
                    }

                    // =====================
                    // PREFIX SECTION
                    // =====================
                    ColumnLayout {
                        visible: root.currentSection === "prefixes"
                        property string settingsSection: "prefixes"
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "Prefixes"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: Font.Medium
                            color: Colors.overSurfaceVariant
                            Layout.bottomMargin: -4
                        }

                        Text {
                            text: "Keyboard shortcuts for quick actions in launcher"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            color: Colors.overSurfaceVariant
                            opacity: 0.7
                        }

                        // Clipboard prefix
                        PrefixRow {
                            Layout.fillWidth: true
                            label: "Clipboard"
                            prefixValue: Config.prefix.clipboard
                            onPrefixEdited: newValue => {
                                Config.prefix.clipboard = newValue;
                            }
                        }

                        // Emoji prefix
                        PrefixRow {
                            Layout.fillWidth: true
                            label: "Emoji"
                            prefixValue: Config.prefix.emoji
                            onPrefixEdited: newValue => {
                                Config.prefix.emoji = newValue;
                            }
                        }

                        // Tmux prefix
                        PrefixRow {
                            Layout.fillWidth: true
                            label: "Tmux"
                            prefixValue: Config.prefix.tmux
                            onPrefixEdited: newValue => {
                                Config.prefix.tmux = newValue;
                            }
                        }

                        // Wallpapers prefix
                        PrefixRow {
                            Layout.fillWidth: true
                            label: "Wallpapers"
                            prefixValue: Config.prefix.wallpapers
                            onPrefixEdited: newValue => {
                                Config.prefix.wallpapers = newValue;
                            }
                        }

                        // Notes prefix
                        PrefixRow {
                            Layout.fillWidth: true
                            label: "Notes"
                            prefixValue: Config.prefix.notes
                            onPrefixEdited: newValue => {
                                Config.prefix.notes = newValue;
                            }
                        }
                    }

                    // =====================
                    // WEATHER SECTION
                    // =====================
                    ColumnLayout {
                        visible: root.currentSection === "weather"
                        property string settingsSection: "weather"
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "Weather"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: Font.Medium
                            color: Colors.overSurfaceVariant
                            Layout.bottomMargin: -4
                        }

                        // Location
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "Location"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(0)
                                color: Colors.overBackground
                                Layout.preferredWidth: 100
                            }

                            StyledRect {
                                variant: "common"
                                Layout.fillWidth: true
                                Layout.preferredHeight: 36
                                radius: Styling.radius(-2)

                                TextInput {
                                    id: locationInput
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(0)
                                    color: Colors.overBackground
                                    selectByMouse: true
                                    clip: true
                                    verticalAlignment: TextInput.AlignVCenter

                                    readonly property string configValue: Config.weather.location

                                    onConfigValueChanged: {
                                        if (text !== configValue) {
                                            text = configValue;
                                        }
                                    }

                                    Component.onCompleted: text = configValue

                                    onEditingFinished: {
                                        if (text !== Config.weather.location) {
                                            Config.weather.location = text.trim();
                                        }
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: !locationInput.text && !locationInput.activeFocus
                                        text: "e.g. Buenos Aires, Tokyo..."
                                        font: locationInput.font
                                        color: Colors.overSurfaceVariant
                                    }
                                }
                            }
                        }

                        // Unit selector
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "Unit"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(0)
                                color: Colors.overBackground
                                Layout.preferredWidth: 100
                            }

                            Row {
                                spacing: 8

                                Repeater {
                                    model: [
                                        {
                                            id: "C",
                                            label: "Celsius"
                                        },
                                        {
                                            id: "F",
                                            label: "Fahrenheit"
                                        }
                                    ]

                                    delegate: StyledRect {
                                        id: unitButton
                                        required property var modelData
                                        required property int index

                                        property bool isSelected: Config.weather.unit === modelData.id
                                        property bool isHovered: false

                                        variant: isSelected ? "primary" : (isHovered ? "focus" : "common")
                                        width: unitLabel.width + 24
                                        height: 36
                                        radius: Styling.radius(-2)

                                        Text {
                                            id: unitLabel
                                            anchors.centerIn: parent
                                            text: unitButton.modelData.label
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(0)
                                            font.weight: unitButton.isSelected ? Font.Bold : Font.Normal
                                            color: unitButton.item
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onEntered: unitButton.isHovered = true
                                            onExited: unitButton.isHovered = false
                                            onClicked: Config.weather.unit = unitButton.modelData.id
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // =====================
                    // PERFORMANCE SECTION
                    // =====================
                    ColumnLayout {
                        visible: root.currentSection === "performance"
                        property string settingsSection: "performance"
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "Performance"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: Font.Medium
                            color: Colors.overSurfaceVariant
                            Layout.bottomMargin: -4
                        }

                        Text {
                            text: "Toggle visual effects to improve performance"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            color: Colors.overSurfaceVariant
                            opacity: 0.7
                        }

                        // Blur Transition toggle
                        ToggleRow {
                            Layout.fillWidth: true
                            label: "Blur Transition"
                            description: "Animated blur when opening panels"
                            checked: Config.performance.blurTransition
                            onToggled: checked => {
                                Config.performance.blurTransition = checked;
                            }
                        }

                        // Window Preview toggle
                        ToggleRow {
                            Layout.fillWidth: true
                            label: "Window Preview"
                            description: "Show window thumbnails in overview"
                            checked: Config.performance.windowPreview
                            onToggled: checked => {
                                Config.performance.windowPreview = checked;
                            }
                        }

                        // Wavy Line toggle
                        ToggleRow {
                            Layout.fillWidth: true
                            label: "Wavy Line"
                            description: "Animated wavy line effect"
                            checked: Config.performance.wavyLine
                            onToggled: checked => {
                                Config.performance.wavyLine = checked;
                            }
                        }

                        // Rotate Cover Art toggle
                        ToggleRow {
                            Layout.fillWidth: true
                            label: "Disable Cover Art Rotation"
                            description: "Stop the vinyl disc from spinning"
                            checked: !Config.performance.rotateCoverArt
                            onToggled: checked => {
                                Config.performance.rotateCoverArt = !checked;
                            }
                        }
                    }

                    // =====================
                    // SYSTEM SECTION
                    // =====================
                    ColumnLayout {
                        id: systemSection
                        visible: root.currentSection === "system"
                        Layout.fillWidth: true
                        spacing: 8

                        // ── Pending state ─────────────────────────────────────
                        property bool resEnabled: true
                        property string resLocation: "dashboard"
                        property string resBarSide: "left"
                        property bool resShowCpu: true
                        property bool resShowRam: true
                        property bool resShowGpu: true
                        property bool resShowDisk: true
                        property bool savedSuccess: false

                        property bool hasChanges: {
                            const res = Config.system.resources;
                            if (!res) return false;
                            if ((res.enabled !== false) !== resEnabled) return true;
                            if ((res.location || "dashboard") !== resLocation) return true;
                            if ((res.barSide || "left") !== resBarSide) return true;
                            const show = res.show;
                            if ((show ? show.cpu !== false : true) !== resShowCpu) return true;
                            if ((show ? show.ram !== false : true) !== resShowRam) return true;
                            if ((show ? show.gpu !== false : true) !== resShowGpu) return true;
                            if ((show ? show.disk !== false : true) !== resShowDisk) return true;
                            return false;
                        }

                        function resetToConfig() {
                            const res = Config.system.resources;
                            if (!res) return;
                            resEnabled = res.enabled !== false;
                            resLocation = res.location || "dashboard";
                            resBarSide = res.barSide || "left";
                            const show = res.show;
                            resShowCpu = show ? show.cpu !== false : true;
                            resShowRam = show ? show.ram !== false : true;
                            resShowGpu = show ? show.gpu !== false : true;
                            resShowDisk = show ? show.disk !== false : true;
                        }

                        function saveToConfig() {
                            const res = Config.system.resources;
                            if (!res) return;
                            res.enabled = resEnabled;
                            res.location = resLocation;
                            res.barSide = resBarSide;
                            if (res.show) {
                                res.show.cpu = resShowCpu;
                                res.show.ram = resShowRam;
                                res.show.gpu = resShowGpu;
                                res.show.disk = resShowDisk;
                            }
                            savedSuccess = true;
                            savedTimer.restart();
                        }

                        Component.onCompleted: resetToConfig()
                        onVisibleChanged: if (visible) resetToConfig()

                        Timer {
                            id: savedTimer
                            interval: 2000
                            onTriggered: systemSection.savedSuccess = false
                        }

                        // ── Global enable toggle ──────────────────────────────
                        ToggleRow {
                            Layout.fillWidth: true
                            label: root.tr("system.resources.enabled", "Enable Resource Monitor")
                            checked: systemSection.resEnabled
                            onToggled: checked => { systemSection.resEnabled = checked; }
                        }

                        // ── Settings (dimmed when monitor is disabled) ─────────
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            enabled: systemSection.resEnabled
                            opacity: systemSection.resEnabled ? 1.0 : 0.4

                            Behavior on opacity {
                                enabled: Config.animDuration > 0
                                NumberAnimation { duration: Config.animDuration / 2 }
                            }

                            Text {
                                text: "System Resources"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                font.weight: Font.Medium
                                color: Colors.overSurfaceVariant
                                Layout.bottomMargin: -4
                            }

                            Text {
                                text: root.tr("system.resources.description", "Configure resource display and monitored disks")
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-2)
                                color: Colors.overSurfaceVariant
                                opacity: 0.7
                            }

                            // ── Display Location ──────────────────────────────
                            Text {
                                text: root.tr("system.resources.location", "Display Location")
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                font.weight: Font.Medium
                                color: Colors.overSurfaceVariant
                                Layout.topMargin: 4
                                Layout.bottomMargin: -4
                            }

                            SelectorRow {
                                options: [
                                    { label: root.tr("system.resources.location_dashboard", "Dashboard"), value: "dashboard" },
                                    { label: root.tr("system.resources.location_bar", "Bar"),             value: "bar" },
                                    { label: root.tr("system.resources.location_both", "Both"),           value: "both" }
                                ]
                                value: systemSection.resLocation
                                onValueSelected: newValue => { systemSection.resLocation = newValue; }
                            }

                            // ── Bar Side (visible only when location includes bar) ───
                            Text {
                                visible: systemSection.resLocation === "bar" || systemSection.resLocation === "both"
                                text: root.tr("system.resources.bar_side", "Bar Position")
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                font.weight: Font.Medium
                                color: Colors.overSurfaceVariant
                                Layout.topMargin: 4
                                Layout.bottomMargin: -4
                            }

                            SelectorRow {
                                visible: systemSection.resLocation === "bar" || systemSection.resLocation === "both"
                                options: [
                                    { label: root.tr("system.resources.bar_side_left", "Left"),  value: "left" },
                                    { label: root.tr("system.resources.bar_side_right", "Right"), value: "right" }
                                ]
                                value: systemSection.resBarSide
                                onValueSelected: newValue => { systemSection.resBarSide = newValue; }
                            }

                            // ── Visible Items ─────────────────────────────────
                            Text {
                                text: root.tr("system.resources.show_items", "Visible Items")
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                font.weight: Font.Medium
                                color: Colors.overSurfaceVariant
                                Layout.topMargin: 4
                                Layout.bottomMargin: -4
                            }

                            ToggleRow {
                                Layout.fillWidth: true
                                label: root.tr("system.resources.show_cpu", "CPU")
                                checked: systemSection.resShowCpu
                                onToggled: checked => { systemSection.resShowCpu = checked; }
                            }

                            ToggleRow {
                                Layout.fillWidth: true
                                label: root.tr("system.resources.show_ram", "RAM")
                                checked: systemSection.resShowRam
                                onToggled: checked => { systemSection.resShowRam = checked; }
                            }

                            ToggleRow {
                                Layout.fillWidth: true
                                label: root.tr("system.resources.show_gpu", "GPU")
                                checked: systemSection.resShowGpu
                                onToggled: checked => { systemSection.resShowGpu = checked; }
                            }

                            ToggleRow {
                                Layout.fillWidth: true
                                label: root.tr("system.resources.show_disk", "Disk")
                                checked: systemSection.resShowDisk
                                onToggled: checked => { systemSection.resShowDisk = checked; }
                            }

                            // ── Monitored Disks ───────────────────────────────
                            Text {
                                text: root.tr("system.resources.disks_title", "Monitored Disks")
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                font.weight: Font.Medium
                                color: Colors.overSurfaceVariant
                                Layout.topMargin: 4
                                Layout.bottomMargin: -4
                            }

                            // Disks list
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Repeater {
                                    id: disksRepeater
                                    model: Config.system.disks

                                    delegate: RowLayout {
                                        id: diskRow
                                        required property string modelData
                                        required property int index

                                        Layout.fillWidth: true
                                        spacing: 8

                                        StyledRect {
                                            variant: "common"
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 36
                                            radius: Styling.radius(-2)

                                            TextInput {
                                                id: diskInput
                                                anchors.fill: parent
                                                anchors.margins: 8
                                                font.family: Config.theme.monoFont
                                                font.pixelSize: Styling.monoFontSize(0)
                                                color: Colors.overBackground
                                                selectByMouse: true
                                                clip: true
                                                verticalAlignment: TextInput.AlignVCenter
                                                text: diskRow.modelData

                                                onEditingFinished: {
                                                    if (text.trim() !== diskRow.modelData) {
                                                        let newDisks = Config.system.disks.slice();
                                                        newDisks[diskRow.index] = text.trim();
                                                        Config.system.disks = newDisks;
                                                    }
                                                }

                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    visible: !diskInput.text && !diskInput.activeFocus
                                                    text: "e.g. /, /home..."
                                                    font: diskInput.font
                                                    color: Colors.overSurfaceVariant
                                                }
                                            }
                                        }

                                        // Remove button
                                        StyledRect {
                                            id: removeDiskButton
                                            variant: removeDiskArea.containsMouse ? "focus" : "common"
                                            Layout.preferredWidth: 36
                                            Layout.preferredHeight: 36
                                            radius: Styling.radius(-2)
                                            visible: disksRepeater.count > 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: Icons.trash
                                                font.family: Icons.font
                                                font.pixelSize: 14
                                                color: Colors.error
                                            }

                                            MouseArea {
                                                id: removeDiskArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    let newDisks = Config.system.disks.slice();
                                                    newDisks.splice(diskRow.index, 1);
                                                    Config.system.disks = newDisks;
                                                }
                                            }

                                            StyledToolTip {
                                                visible: removeDiskArea.containsMouse
                                                tooltipText: "Remove disk"
                                            }
                                        }
                                    }
                                }

                                // Add disk button
                                StyledRect {
                                    id: addDiskButton
                                    variant: addDiskArea.containsMouse ? "primaryfocus" : "primary"
                                    Layout.preferredWidth: addDiskContent.width + 24
                                    Layout.preferredHeight: 36
                                    radius: Styling.radius(-2)

                                    Row {
                                        id: addDiskContent
                                        anchors.centerIn: parent
                                        spacing: 6

                                        Text {
                                            text: Icons.plus
                                            font.family: Icons.font
                                            font.pixelSize: 14
                                            color: addDiskButton.item
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: "Add Disk"
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(0)
                                            color: addDiskButton.item
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    MouseArea {
                                        id: addDiskArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            let newDisks = Config.system.disks.slice();
                                            newDisks.push("/");
                                            Config.system.disks = newDisks;
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // =====================
                    // IDLE SECTION
                    // =====================
                    ColumnLayout {
                        visible: root.currentSection === "idle"
                        property string settingsSection: "idle"
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "Idle"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: Font.Medium
                            color: Colors.overSurfaceVariant
                            Layout.bottomMargin: -4
                        }

                        TextInputRow {
                            label: "Lock Cmd"
                            value: Config.system.idle.general.lock_cmd ?? ""
                            placeholder: "Command to lock screen"
                            onValueEdited: newValue => {
                                if (newValue !== Config.system.idle.general.lock_cmd) {
                                    GlobalStates.markShellChanged();
                                    Config.system.idle.general.lock_cmd = newValue;
                                }
                            }
                        }

                        TextInputRow {
                            label: "Before Sleep"
                            value: Config.system.idle.general.before_sleep_cmd ?? ""
                            placeholder: "Command before sleep"
                            onValueEdited: newValue => {
                                if (newValue !== Config.system.idle.general.before_sleep_cmd) {
                                    GlobalStates.markShellChanged();
                                    Config.system.idle.general.before_sleep_cmd = newValue;
                                }
                            }
                        }

                        TextInputRow {
                            label: "After Sleep"
                            value: Config.system.idle.general.after_sleep_cmd ?? ""
                            placeholder: "Command after sleep"
                            onValueEdited: newValue => {
                                if (newValue !== Config.system.idle.general.after_sleep_cmd) {
                                    GlobalStates.markShellChanged();
                                    Config.system.idle.general.after_sleep_cmd = newValue;
                                }
                            }
                        }

                        Text {
                            text: "Listeners"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(0)
                            color: Colors.overBackground
                            Layout.topMargin: 8
                        }

                        Repeater {
                            model: Config.system.idle.listeners

                            delegate: ColumnLayout {
                                required property var modelData
                                required property int index

                                Layout.fillWidth: true
                                spacing: 4
                                Layout.bottomMargin: 8

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 1
                                    color: Colors.surfaceBright
                                    visible: index > 0
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: "Listener " + (index + 1)
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-1)
                                        font.bold: true
                                        color: Styling.srItem("overprimary")
                                    }
                                    Item {
                                        Layout.fillWidth: true
                                    }

                                    StyledRect {
                                        id: deleteListenerBtn
                                        variant: "error"
                                        Layout.preferredWidth: 24
                                        Layout.preferredHeight: 24
                                        radius: Styling.radius(-2)

                                        Text {
                                            anchors.centerIn: parent
                                            text: Icons.trash
                                            font.family: Icons.font
                                            color: deleteListenerBtn.item
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                // Create a copy of the list to ensure change detection
                                                var list = [];
                                                for (var i = 0; i < Config.system.idle.listeners.length; i++)
                                                    list.push(Config.system.idle.listeners[i]);
                                                list.splice(index, 1);
                                                Config.system.idle.listeners = list;
                                                GlobalStates.markShellChanged();
                                            }
                                        }
                                    }
                                }

                                NumberInputRow {
                                    label: "Timeout (s)"
                                    value: modelData.timeout || 0
                                    minValue: 1
                                    maxValue: 7200
                                    onValueEdited: val => {
                                        var list = [];
                                        for (var i = 0; i < Config.system.idle.listeners.length; i++)
                                            list.push(Config.system.idle.listeners[i]);
                                        list[index].timeout = val;
                                        Config.system.idle.listeners = list;
                                        GlobalStates.markShellChanged();
                                    }
                                }

                                TextInputRow {
                                    label: "On Timeout"
                                    value: modelData.onTimeout || ""
                                    onValueEdited: val => {
                                        var list = [];
                                        for (var i = 0; i < Config.system.idle.listeners.length; i++)
                                            list.push(Config.system.idle.listeners[i]);
                                        list[index].onTimeout = val;
                                        Config.system.idle.listeners = list;
                                        GlobalStates.markShellChanged();
                                    }
                                }

                                TextInputRow {
                                    label: "On Resume"
                                    value: modelData.onResume || ""
                                    onValueEdited: val => {
                                        var list = [];
                                        for (var i = 0; i < Config.system.idle.listeners.length; i++)
                                            list.push(Config.system.idle.listeners[i]);
                                        list[index].onResume = val;
                                        Config.system.idle.listeners = list;
                                        GlobalStates.markShellChanged();
                                    }
                                }
                            }
                        }

                        StyledRect {
                            id: addListenerBtn
                            variant: "common"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            radius: Styling.radius(-2)

                            Text {
                                anchors.centerIn: parent
                                text: "Add Listener"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(0)
                                font.bold: true
                                color: addListenerBtn.item
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var list = [];
                                    if (Config.system.idle.listeners) {
                                        for (var i = 0; i < Config.system.idle.listeners.length; i++)
                                            list.push(Config.system.idle.listeners[i]);
                                    }
                                    list.push({
                                        "timeout": 60,
                                        "onTimeout": "",
                                        "onResume": ""
                                    });
                                    Config.system.idle.listeners = list;
                                    GlobalStates.markShellChanged();
                                }
                            }
                        }
                    }

                    // Bottom spacing
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 16
                    }
                }
            }
        }
    }

    // =====================
    // HELPER COMPONENTS
    // =====================

    // Inline component for number input rows
    component NumberInputRow: RowLayout {
        id: numberInputRowRoot
        property string label: ""
        property int value: 0
        property int minValue: 0
        property int maxValue: 100
        property string suffix: ""
        signal valueEdited(int newValue)

        Layout.fillWidth: true
        spacing: 8

        Text {
            text: numberInputRowRoot.label
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(0)
            color: Colors.overBackground
            Layout.fillWidth: true
        }

        StyledRect {
            variant: "common"
            Layout.preferredWidth: 60
            Layout.preferredHeight: 32
            radius: Styling.radius(-2)

            TextInput {
                id: numberTextInput
                anchors.fill: parent
                anchors.margins: 8
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(0)
                color: Colors.overBackground
                selectByMouse: true
                clip: true
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter
                validator: IntValidator {
                    bottom: numberInputRowRoot.minValue
                    top: numberInputRowRoot.maxValue
                }

                // Sync text when external value changes
                readonly property int configValue: numberInputRowRoot.value
                onConfigValueChanged: {
                    if (!activeFocus && text !== configValue.toString()) {
                        text = configValue.toString();
                    }
                }
                Component.onCompleted: text = configValue.toString()

                onEditingFinished: {
                    let newVal = parseInt(text);
                    if (!isNaN(newVal)) {
                        newVal = Math.max(numberInputRowRoot.minValue, Math.min(numberInputRowRoot.maxValue, newVal));
                        numberInputRowRoot.valueEdited(newVal);
                    }
                }
            }
        }

        Text {
            text: numberInputRowRoot.suffix
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(0)
            color: Colors.overSurfaceVariant
            visible: suffix !== ""
        }
    }

    // Inline component for text input rows
    component TextInputRow: RowLayout {
        id: textInputRowRoot
        property string label: ""
        property string value: ""
        property string placeholder: ""
        signal valueEdited(string newValue)

        Layout.fillWidth: true
        spacing: 8

        Text {
            text: textInputRowRoot.label
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(0)
            color: Colors.overBackground
            Layout.preferredWidth: 100
        }

        StyledRect {
            variant: "common"
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            radius: Styling.radius(-2)

            TextInput {
                id: textInputField
                anchors.fill: parent
                anchors.margins: 8
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(0)
                color: Colors.overBackground
                selectByMouse: true
                clip: true
                verticalAlignment: TextInput.AlignVCenter

                // Sync text when external value changes
                readonly property string configValue: textInputRowRoot.value
                onConfigValueChanged: {
                    if (!activeFocus && text !== configValue) {
                        text = configValue;
                    }
                }
                Component.onCompleted: text = configValue

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: textInputRowRoot.placeholder
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(0)
                    color: Colors.overSurfaceVariant
                    visible: textInputField.text === ""
                }

                onEditingFinished: {
                    textInputRowRoot.valueEdited(text);
                }
            }
        }
    }

    // PrefixRow component for prefix inputs
    component PrefixRow: RowLayout {
        id: prefixRow
        property string label: ""
        property string prefixValue: ""
        signal prefixEdited(string newValue)

        spacing: 8

        Text {
            text: prefixRow.label
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(0)
            color: Colors.overBackground
            Layout.preferredWidth: 100
        }

        StyledRect {
            variant: "common"
            Layout.preferredWidth: 80
            Layout.preferredHeight: 36
            radius: Styling.radius(-2)

            TextInput {
                id: prefixInput
                anchors.fill: parent
                anchors.margins: 8
                font.family: Config.theme.monoFont
                font.pixelSize: Styling.monoFontSize(0)
                color: Colors.overBackground
                selectByMouse: true
                clip: true
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter
                text: prefixRow.prefixValue
                maximumLength: 4

                onEditingFinished: {
                    if (text !== prefixRow.prefixValue && text.trim() !== "") {
                        prefixRow.prefixEdited(text.trim());
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
        }
    }

    // ToggleRow component for boolean toggles
    component ToggleRow: RowLayout {
        property string label: ""
        property string description: ""
        property bool checked: false
        signal toggled(bool checked)

        spacing: 8

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                text: label
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(0)
                color: Colors.overBackground
            }

            Text {
                visible: description !== ""
                text: description
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                color: Colors.overSurfaceVariant
                opacity: 0.7
            }
        }

        // Checkbox styled like in BindsPanel
        Item {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32

            Rectangle {
                anchors.fill: parent
                radius: Styling.radius(-4)
                color: Colors.background
                visible: !checked
            }

            StyledRect {
                variant: "primary"
                anchors.fill: parent
                radius: Styling.radius(-4)
                visible: checked
                opacity: checked ? 1.0 : 0.0

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
                    scale: checked ? 1.0 : 0.0

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

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: toggled(!checked)
            }
        }
    }
}
