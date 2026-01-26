pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import qs.modules.components
import qs.modules.services
import qs.modules.theme
import "../../settings"
import qs.config

Rectangle {
    id: root
    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true
    color: "transparent"
    implicitWidth: 400
    implicitHeight: 300
    readonly property bool isRtl: I18n.isRtl

    property int currentSection: 0  // 0: Network, 1: Bluetooth, 2: Mixer, 3: Effects, 4: Theme, 5: Binds, 6: System, 7: Shell
    property string searchQuery: ""
    property var navigationHistory: []
    property int navigationDepth: 0
    property bool canGoBack: navigationDepth > 0
    property bool _suppressHistory: false
    property var _lastRoute: ({
            "section": 0,
            "subsection": ""
        })

    function _sectionLabel(sectionId) {
        for (let i = 0; i < sections.length; i++) {
            if (sections[i].section === sectionId)
                return sections[i].label;
        }
        return "Settings";
    }

    function _shellSectionLabel(sectionId) {
        switch (sectionId) {
        case "bar":
            return I18n.t("Bar");
        case "frame":
            return I18n.t("Frame");
        case "notch":
            return I18n.t("Notch");
        case "workspaces":
            return I18n.t("Workspaces");
        case "overview":
            return I18n.t("Overview");
        case "dock":
            return I18n.t("Dock");
        case "lockscreen":
            return I18n.t("Lockscreen");
        case "desktop":
            return I18n.t("Desktop");
        case "system":
            return I18n.t("System");
        default:
            return I18n.t("Ambxst");
        }
    }

    readonly property string currentTitle: {
        if (currentSection === 8 && shellPanel && shellPanel.currentSection !== "") {
            return _shellSectionLabel(shellPanel.currentSection);
        }
        return _sectionLabel(currentSection);
    }
    readonly property bool isInSubsection: currentSection === 8 && shellPanel && shellPanel.currentSection !== ""

    property var titlebarActions: []
    property bool titlebarShowToggle: false
    property bool titlebarToggleChecked: false
    property var titlebarToggleHandler: null
    property Component titlebarCustomComponent: null

    function _routesEqual(a, b) {
        if (!a || !b)
            return false;
        return a.section === b.section && (a.subsection || "") === (b.subsection || "");
    }

    function _currentRoute() {
        const subsection = (currentSection === 8 && shellPanel) ? (shellPanel.currentSection || "") : "";
        return {
            "section": currentSection,
            "subsection": subsection
        };
    }

    function _recordRouteChange() {
        if (_suppressHistory)
            return;
        const nextRoute = _currentRoute();
        if (_routesEqual(_lastRoute, nextRoute))
            return;

        if (nextRoute.section === 8) {
            if (_lastRoute.section === 8 && (_lastRoute.subsection || "") !== (nextRoute.subsection || "")) {
                navigationHistory.push(_lastRoute);
                navigationDepth = navigationHistory.length;
            } else if (_lastRoute.section !== 8) {
                navigationHistory = [];
                navigationDepth = 0;
            }
        } else {
            navigationHistory = [];
            navigationDepth = 0;
        }

        _lastRoute = nextRoute;
    }

    function navigateTo(section, subsection) {
        const nextSubsection = section === 8 ? (subsection ?? "") : "";
        const nextRoute = {
            "section": section,
            "subsection": nextSubsection
        };
        const currentRoute = _currentRoute();

        if (!_routesEqual(currentRoute, nextRoute)) {
            if (section === 8) {
                navigationHistory.push(currentRoute);
                navigationDepth = navigationHistory.length;
            } else {
                navigationHistory = [];
                navigationDepth = 0;
            }
        }

        _suppressHistory = true;
        currentSection = section;
        if (shellPanel) {
            if (section === 8) {
                shellPanel.currentSection = nextSubsection;
            } else if (shellPanel.currentSection !== "") {
                shellPanel.currentSection = "";
            }
        }
        _suppressHistory = false;
        _lastRoute = nextRoute;
    }

    function goBack() {
        if (currentSection === 8 && shellPanel && shellPanel.currentSection !== "") {
            if (navigationHistory.length > 0) {
                const previousRoute = navigationHistory.pop();
                navigationDepth = navigationHistory.length;
                _suppressHistory = true;
                currentSection = previousRoute.section;
                if (shellPanel) {
                    shellPanel.currentSection = previousRoute.section === 8 ? (previousRoute.subsection || "") : "";
                }
                _suppressHistory = false;
                _lastRoute = previousRoute;
            } else {
                _suppressHistory = true;
                shellPanel.currentSection = "";
                _suppressHistory = false;
                _lastRoute = _currentRoute();
            }
        }
    }

    function resetNavigation() {
        navigationHistory = [];
        navigationDepth = 0;
        _lastRoute = _currentRoute();
    }

    function updateTitlebarControls() {
        titlebarActions = [];
        titlebarShowToggle = false;
        titlebarToggleChecked = false;
        titlebarToggleHandler = null;
        titlebarCustomComponent = null;

        if (currentSection === 0) {
            titlebarShowToggle = Qt.binding(() => true);
            titlebarToggleChecked = Qt.binding(() => NetworkService.wifiStatus !== "disabled");
            titlebarToggleHandler = checked => {
                NetworkService.enableWifi(checked);
                if (checked) {
                    NetworkService.rescanWifi();
                }
            };
            titlebarActions = Qt.binding(() => ([
                {
                    icon: Icons.globe,
                    tooltip: I18n.t("Open captive portal"),
                    enabled: NetworkService.wifiStatus === "limited",
                    onClicked: function () {
                        NetworkService.openPublicWifiPortal();
                    }
                },
                {
                    icon: Icons.popOpen,
                    tooltip: I18n.t("Network settings"),
                    onClicked: function () {
                        Quickshell.execDetached(["nm-connection-editor"]);
                    }
                },
                {
                    icon: Icons.sync,
                    tooltip: I18n.t("Rescan networks"),
                    enabled: NetworkService.wifiEnabled,
                    loading: NetworkService.wifiScanning,
                    onClicked: function () {
                        NetworkService.rescanWifi();
                    }
                }
            ]));
        } else if (currentSection === 1) {
            titlebarShowToggle = Qt.binding(() => true);
            titlebarToggleChecked = Qt.binding(() => BluetoothService.enabled);
            titlebarToggleHandler = checked => {
                if (checked !== BluetoothService.enabled) {
                    BluetoothService.toggle();
                }
            };
        } else if (currentSection === 2) {
            titlebarCustomComponent = audioToggleComponent;
            titlebarActions = Qt.binding(() => ([
                {
                    icon: Audio.protectionEnabled ? Icons.shieldCheck : Icons.shield,
                    tooltip: Audio.protectionEnabled ? I18n.t("Volume protection enabled") : I18n.t("Volume protection disabled"),
                    onClicked: function () {
                        Audio.setProtectionEnabled(!Audio.protectionEnabled);
                    }
                },
                {
                    icon: Icons.popOpen,
                    tooltip: I18n.t("Open PipeWire Volume Control"),
                    onClicked: function () {
                        Quickshell.execDetached(["pwvucontrol"]);
                    }
                }
            ]));
        } else if (currentSection === 3) {
            titlebarShowToggle = Qt.binding(() => EasyEffectsService.available);
            titlebarToggleChecked = Qt.binding(() => !EasyEffectsService.bypassed);
            titlebarToggleHandler = checked => {
                if (checked !== !EasyEffectsService.bypassed) {
                    EasyEffectsService.setBypass(!checked);
                }
            };
            titlebarActions = Qt.binding(() => {
                if (!EasyEffectsService.available)
                    return [];
                return [
                    {
                        icon: Icons.popOpen,
                        tooltip: I18n.t("Open EasyEffects"),
                        onClicked: function () {
                            EasyEffectsService.openApp();
                        }
                    },
                    {
                        icon: Icons.sync,
                        tooltip: I18n.t("Refresh"),
                        onClicked: function () {
                            EasyEffectsService.refresh();
                        }
                    }
                ];
            });
        } else if (currentSection === 4) {
            titlebarActions = Qt.binding(() => {
                if (!themePanel || themePanel.currentSection === "")
                    return [];
                return [
                    {
                        icon: Icons.arrowLeft,
                        tooltip: I18n.t("Back"),
                        onClicked: function () {
                            themePanel.currentSection = "";
                        }
                    }
                ];
            });
        } else if (currentSection === 5) {
            titlebarActions = Qt.binding(() => ([
                {
                    icon: Icons.plus,
                    tooltip: I18n.t("Add keybind"),
                    onClicked: function () {
                        if (bindsPanel && bindsPanel.addNewBind) {
                            bindsPanel.addNewBind();
                        }
                    }
                },
                {
                    icon: Icons.sync,
                    tooltip: I18n.t("Reload binds"),
                    onClicked: function () {
                        Config.keybindsLoader.reload();
                    }
                }
            ]));
        } else if (currentSection === 7) {
            titlebarActions = Qt.binding(() => {
                if (!compositorPanel || compositorPanel.currentSection === "")
                    return [];
                return [
                    {
                        icon: Icons.arrowLeft,
                        tooltip: I18n.t("Back"),
                        onClicked: function () {
                            compositorPanel.currentSection = "";
                        }
                    }
                ];
            });
        }
    }

    function settingsPath(parts) {
        return parts.map(p => I18n.t(p)).join(" > ");
    }

    readonly property var sections: [
        { icon: Icons.wifiHigh, label: I18n.t("Network"), section: 0, isIcon: true },
        { icon: Icons.bluetooth, label: I18n.t("Bluetooth"), section: 1, isIcon: true },
        { icon: Icons.faders, label: I18n.t("Mixer"), section: 2, isIcon: true },
        { icon: Icons.waveform, label: I18n.t("Effects"), section: 3, isIcon: true },
        { icon: Icons.paintBrush, label: I18n.t("Theme"), section: 4, isIcon: true },
        { icon: Icons.keyboard, label: I18n.t("Binds"), section: 5, isIcon: true },
        { icon: Icons.circuitry, label: I18n.t("System"), section: 6, isIcon: true },
        { icon: Icons.compositor, label: I18n.t("Compositor"), section: 7, isIcon: true },
        { icon: Qt.resolvedUrl("../../../../assets/ambxst/ambxst-icon.svg"), label: I18n.t("Ambxst"), section: 8, isIcon: false }
    ]

    readonly property var filteredSections: {
        const query = searchQuery.trim().toLowerCase();
        if (query.length === 0)
            return sections;
        return sections.filter(item => item.label.toLowerCase().includes(query));
    }

    readonly property var searchEntries: [
        { title: I18n.t("Network"), path: I18n.t("Network"), section: 0 },
        { title: I18n.t("Bluetooth"), path: I18n.t("Bluetooth"), section: 1 },
        { title: I18n.t("Mixer"), path: I18n.t("Mixer"), section: 2 },
        { title: I18n.t("Effects"), path: I18n.t("Effects"), section: 3 },
        { title: I18n.t("Theme"), path: I18n.t("Theme"), section: 4 },
        { title: I18n.t("Binds"), path: I18n.t("Binds"), section: 5 },
        { title: I18n.t("System"), path: I18n.t("System"), section: 6 },
        { title: I18n.t("Compositor"), path: I18n.t("Compositor"), section: 7 },
        { title: I18n.t("Ambxst"), path: I18n.t("Ambxst"), section: 8 },
        { title: I18n.t("Language"), path: settingsPath(["System", "Language"]), section: 6 },

        { title: I18n.t("Bar Position"), path: settingsPath(["Ambxst", "Bar", "Position"]), section: 8, subsection: "bar", highlightKey: "bar.position" },
        { title: I18n.t("Launcher Icon"), path: settingsPath(["Ambxst", "Bar", "Launcher Icon"]), section: 8, subsection: "bar", highlightKey: "bar.launcherIcon" },
        { title: I18n.t("Launcher Icon Tint"), path: settingsPath(["Ambxst", "Bar", "Launcher Icon Tint"]), section: 8, subsection: "bar", highlightKey: "bar.launcherIconTint" },
        { title: I18n.t("Launcher Icon Full Tint"), path: settingsPath(["Ambxst", "Bar", "Launcher Icon Full Tint"]), section: 8, subsection: "bar", highlightKey: "bar.launcherIconFullTint" },
        { title: I18n.t("Launcher Icon Size"), path: settingsPath(["Ambxst", "Bar", "Launcher Icon Size"]), section: 8, subsection: "bar", highlightKey: "bar.launcherIconSize" },
        { title: I18n.t("Enable Firefox Player"), path: settingsPath(["Ambxst", "Bar", "Enable Firefox Player"]), section: 8, subsection: "bar", highlightKey: "bar.enableFirefoxPlayer" },
        { title: I18n.t("Show Bongo Cat"), path: settingsPath(["Ambxst", "Bar", "Show Bongo Cat"]), section: 8, subsection: "bar", highlightKey: "bar.showBongoCat" },
        { title: I18n.t("Pinned on Startup"), path: settingsPath(["Ambxst", "Bar", "Pinned on Startup"]), section: 8, subsection: "bar", highlightKey: "bar.pinnedOnStartup" },
        { title: I18n.t("Hover to Reveal"), path: settingsPath(["Ambxst", "Bar", "Hover to Reveal"]), section: 8, subsection: "bar", highlightKey: "bar.hoverToReveal" },
        { title: I18n.t("Hover Region Height"), path: settingsPath(["Ambxst", "Bar", "Hover Region Height"]), section: 8, subsection: "bar", highlightKey: "bar.hoverRegionHeight" },
        { title: I18n.t("Show Pin Button"), path: settingsPath(["Ambxst", "Bar", "Show Pin Button"]), section: 8, subsection: "bar", highlightKey: "bar.showPinButton" },
        { title: I18n.t("Available on Fullscreen"), path: settingsPath(["Ambxst", "Bar", "Available on Fullscreen"]), section: 8, subsection: "bar", highlightKey: "bar.availableOnFullscreen" },
        { title: I18n.t("Bar Screens"), path: settingsPath(["Ambxst", "Bar", "Screens"]), section: 8, subsection: "bar", highlightKey: "bar.screenList" },

        { title: I18n.t("Frame Enabled"), path: settingsPath(["Ambxst", "Frame", "Enabled"]), section: 8, subsection: "frame", highlightKey: "frame.enabled" },
        { title: I18n.t("Frame Thickness"), path: settingsPath(["Ambxst", "Frame", "Thickness"]), section: 8, subsection: "frame", highlightKey: "frame.thickness" },

        { title: I18n.t("Notch Theme"), path: settingsPath(["Ambxst", "Notch", "Theme"]), section: 8, subsection: "notch", highlightKey: "notch.theme" },
        { title: I18n.t("Notch Hover Region Height"), path: settingsPath(["Ambxst", "Notch", "Hover Region Height"]), section: 8, subsection: "notch", highlightKey: "notch.hoverRegionHeight" },

        { title: I18n.t("Workspaces Shown"), path: settingsPath(["Ambxst", "Workspaces", "Shown"]), section: 8, subsection: "workspaces", highlightKey: "workspaces.shown" },
        { title: I18n.t("Workspaces Show App Icons"), path: settingsPath(["Ambxst", "Workspaces", "Show App Icons"]), section: 8, subsection: "workspaces", highlightKey: "workspaces.showAppIcons" },
        { title: I18n.t("Workspaces Always Show Numbers"), path: settingsPath(["Ambxst", "Workspaces", "Always Show Numbers"]), section: 8, subsection: "workspaces", highlightKey: "workspaces.alwaysShowNumbers" },
        { title: I18n.t("Workspaces Show Numbers"), path: settingsPath(["Ambxst", "Workspaces", "Show Numbers"]), section: 8, subsection: "workspaces", highlightKey: "workspaces.showNumbers" },
        { title: I18n.t("Workspaces Dynamic"), path: settingsPath(["Ambxst", "Workspaces", "Dynamic"]), section: 8, subsection: "workspaces", highlightKey: "workspaces.dynamic" },

        { title: I18n.t("Overview Rows"), path: settingsPath(["Ambxst", "Overview", "Rows"]), section: 8, subsection: "overview", highlightKey: "overview.rows" },
        { title: I18n.t("Overview Columns"), path: settingsPath(["Ambxst", "Overview", "Columns"]), section: 8, subsection: "overview", highlightKey: "overview.columns" },
        { title: I18n.t("Overview Scale"), path: settingsPath(["Ambxst", "Overview", "Scale"]), section: 8, subsection: "overview", highlightKey: "overview.scale" },
        { title: I18n.t("Overview Workspace Spacing"), path: settingsPath(["Ambxst", "Overview", "Workspace Spacing"]), section: 8, subsection: "overview", highlightKey: "overview.workspaceSpacing" },

        { title: I18n.t("Dock Enabled"), path: settingsPath(["Ambxst", "Dock", "Enabled"]), section: 8, subsection: "dock", highlightKey: "dock.enabled" },
        { title: I18n.t("Dock Theme"), path: settingsPath(["Ambxst", "Dock", "Theme"]), section: 8, subsection: "dock", highlightKey: "dock.theme" },
        { title: I18n.t("Dock Position"), path: settingsPath(["Ambxst", "Dock", "Position"]), section: 8, subsection: "dock", highlightKey: "dock.position" },
        { title: I18n.t("Dock Height"), path: settingsPath(["Ambxst", "Dock", "Height"]), section: 8, subsection: "dock", highlightKey: "dock.height" },
        { title: I18n.t("Dock Icon Size"), path: settingsPath(["Ambxst", "Dock", "Icon Size"]), section: 8, subsection: "dock", highlightKey: "dock.iconSize" },
        { title: I18n.t("Dock Spacing"), path: settingsPath(["Ambxst", "Dock", "Spacing"]), section: 8, subsection: "dock", highlightKey: "dock.spacing" },
        { title: I18n.t("Dock Margin"), path: settingsPath(["Ambxst", "Dock", "Margin"]), section: 8, subsection: "dock", highlightKey: "dock.margin" },
        { title: I18n.t("Dock Hover Region Height"), path: settingsPath(["Ambxst", "Dock", "Hover Region Height"]), section: 8, subsection: "dock", highlightKey: "dock.hoverRegionHeight" },
        { title: I18n.t("Dock Pinned on Startup"), path: settingsPath(["Ambxst", "Dock", "Pinned on Startup"]), section: 8, subsection: "dock", highlightKey: "dock.pinnedOnStartup" },
        { title: I18n.t("Dock Hover to Reveal"), path: settingsPath(["Ambxst", "Dock", "Hover to Reveal"]), section: 8, subsection: "dock", highlightKey: "dock.hoverToReveal" },
        { title: I18n.t("Dock Available on Fullscreen"), path: settingsPath(["Ambxst", "Dock", "Available on Fullscreen"]), section: 8, subsection: "dock", highlightKey: "dock.availableOnFullscreen" },
        { title: I18n.t("Dock Show Running Indicators"), path: settingsPath(["Ambxst", "Dock", "Show Running Indicators"]), section: 8, subsection: "dock", highlightKey: "dock.showRunningIndicators" },
        { title: I18n.t("Dock Show Pin Button"), path: settingsPath(["Ambxst", "Dock", "Show Pin Button"]), section: 8, subsection: "dock", highlightKey: "dock.showPinButton" },
        { title: I18n.t("Dock Show Overview Button"), path: settingsPath(["Ambxst", "Dock", "Show Overview Button"]), section: 8, subsection: "dock", highlightKey: "dock.showOverviewButton" },
        { title: I18n.t("Dock Screens"), path: settingsPath(["Ambxst", "Dock", "Screens"]), section: 8, subsection: "dock", highlightKey: "dock.screenList" },

        { title: I18n.t("Lockscreen Position"), path: settingsPath(["Ambxst", "Lockscreen", "Position"]), section: 8, subsection: "lockscreen", highlightKey: "lockscreen.position" },

        { title: I18n.t("Desktop Enabled"), path: settingsPath(["Ambxst", "Desktop", "Enabled"]), section: 8, subsection: "desktop", highlightKey: "desktop.enabled" },
        { title: I18n.t("Desktop Icon Size"), path: settingsPath(["Ambxst", "Desktop", "Icon Size"]), section: 8, subsection: "desktop", highlightKey: "desktop.iconSize" },
        { title: I18n.t("Desktop Vertical Spacing"), path: settingsPath(["Ambxst", "Desktop", "Vertical Spacing"]), section: 8, subsection: "desktop", highlightKey: "desktop.spacingVertical" },
        { title: I18n.t("Desktop Text Color"), path: settingsPath(["Ambxst", "Desktop", "Text Color"]), section: 8, subsection: "desktop", highlightKey: "desktop.textColor" },

        { title: I18n.t("System OCR English"), path: settingsPath(["Ambxst", "System", "OCR English"]), section: 8, subsection: "system", highlightKey: "system.ocr.eng" },
        { title: I18n.t("System OCR Spanish"), path: settingsPath(["Ambxst", "System", "OCR Spanish"]), section: 8, subsection: "system", highlightKey: "system.ocr.spa" },
        { title: I18n.t("System OCR Latin"), path: settingsPath(["Ambxst", "System", "OCR Latin"]), section: 8, subsection: "system", highlightKey: "system.ocr.lat" },
        { title: I18n.t("System OCR Japanese"), path: settingsPath(["Ambxst", "System", "OCR Japanese"]), section: 8, subsection: "system", highlightKey: "system.ocr.jpn" },
        { title: I18n.t("System OCR Chinese (Simplified)"), path: settingsPath(["Ambxst", "System", "OCR Chinese (Simplified)"]), section: 8, subsection: "system", highlightKey: "system.ocr.chi_sim" },
        { title: I18n.t("System OCR Chinese (Traditional)"), path: settingsPath(["Ambxst", "System", "OCR Chinese (Traditional)"]), section: 8, subsection: "system", highlightKey: "system.ocr.chi_tra" },
        { title: I18n.t("System OCR Korean"), path: settingsPath(["Ambxst", "System", "OCR Korean"]), section: 8, subsection: "system", highlightKey: "system.ocr.kor" }
    ]

    readonly property var searchResults: {
        const query = searchQuery.trim().toLowerCase();
        if (query.length === 0)
            return [];
        return searchEntries.filter(entry => {
            return entry.title.toLowerCase().includes(query)
                || entry.path.toLowerCase().includes(query);
        });
    }

    function applySearchResult(entry) {
        root.navigateTo(entry.section, entry.subsection);
        if (entry.section === 8 && entry.highlightKey) {
            shellPanel.flashOption(entry.highlightKey);
        }
        searchInput.text = "";
    }

    function filteredIndexForSection(sectionId) {
        for (let i = 0; i < filteredSections.length; i++) {
            if (filteredSections[i].section === sectionId)
                return i;
        }
        return -1;
    }

    GridLayout {
        anchors.fill: parent
        columns: 2
        rowSpacing: 8
        columnSpacing: 8
        layoutDirection: root.isRtl ? Qt.RightToLeft : Qt.LeftToRight

        StyledRect {
            id: userInfoPanel
            variant: "common"
            radius: Styling.radius(-6)
            Layout.row: 0
            Layout.column: root.isRtl ? 1 : 0
            Layout.preferredWidth: 200
            Layout.maximumWidth: 200
            Layout.preferredHeight: userInfoContent.implicitHeight + 16
            Layout.fillWidth: false

            SettingsUserInfo {
                id: userInfoContent
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                anchors.topMargin: 6
                anchors.bottomMargin: 6
            }
        }

        // Sidebar container with background
        StyledRect {
            id: sidebarContainer
            variant: "common"
            Layout.row: 1
            Layout.column: root.isRtl ? 1 : 0
            Layout.preferredWidth: 200
            Layout.maximumWidth: 200
            Layout.fillHeight: true
            Layout.fillWidth: false
            LayoutMirroring.enabled: I18n.isRtl
            LayoutMirroring.childrenInherit: true

            Flickable {
                id: sidebarFlickable
                anchors.fill: parent
                anchors.margins: 4
                contentWidth: width
                contentHeight: sidebar.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                // Sliding highlight behind tabs
                StyledRect {
                    id: tabHighlight
                    variant: "focus"
                    width: parent.width
                    height: 40
                    radius: Styling.radius(-6)
                    z: 0

                    readonly property int tabHeight: 40
                    readonly property int tabSpacing: 4
                    readonly property int topOffset: searchBoxContainer.height + sidebar.spacing

                    x: 0
                    readonly property int filteredIndex: root.filteredIndexForSection(root.currentSection)
                    visible: filteredIndex >= 0
                    y: filteredIndex >= 0 ? topOffset + filteredIndex * (tabHeight + tabSpacing) : topOffset

                    Behavior on y {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Config.animDuration / 2
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Column {
                    id: sidebar
                    width: parent.width
                    spacing: 4
                    z: 1

                    StyledRect {
                        id: searchBoxContainer
                        variant: "common"
                        radius: Styling.radius(-6)
                        width: parent.width
                        height: 40

                        TextField {
                            id: searchInput
                            anchors.fill: parent
                            anchors.margins: 8
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(0)
                            color: Colors.overBackground
                            placeholderText: I18n.t("Search settings...")
                            placeholderTextColor: Colors.overSurfaceVariant
                            selectByMouse: true
                            background: null
                            horizontalAlignment: I18n.isRtl ? Text.AlignRight : Text.AlignLeft
                            onTextChanged: root.searchQuery = text

                            Keys.onEscapePressed: {
                                if (text.length > 0) {
                                    text = "";
                                    event.accepted = true;
                                }
                            }
                        }
                    }

                    Repeater {
                        model: root.filteredSections

                        delegate: Button {
                            id: sidebarButton
                            required property var modelData
                            required property int index

                            width: sidebar.width
                            height: 40
                            flat: true
                            hoverEnabled: true

                            property bool isActive: root.currentSection === sidebarButton.modelData.section

                            background: Rectangle {
                                color: "transparent"
                            }

                            contentItem: Row {
                                LayoutMirroring.enabled: I18n.isRtl
                                LayoutMirroring.childrenInherit: true
                                spacing: 8

                                // Icon on the left (font icon)
                                Text {
                                    id: iconText
                                    text: sidebarButton.modelData.isIcon ? sidebarButton.modelData.icon : ""
                                    font.family: Icons.font
                                    font.pixelSize: 20
                                    color: sidebarButton.isActive ? Styling.srItem("overprimary") : Styling.srItem("common")
                                    anchors.verticalCenter: parent.verticalCenter
                                    leftPadding: I18n.isRtl ? 0 : 10
                                    rightPadding: I18n.isRtl ? 10 : 0
                                    visible: sidebarButton.modelData.isIcon

                                    Behavior on color {
                                        enabled: Config.animDuration > 0
                                        ColorAnimation {
                                            duration: Config.animDuration
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }

                                // SVG icon
                                Item {
                                    width: 30
                                    height: 20
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: !sidebarButton.modelData.isIcon

                                    Image {
                                        id: svgIcon
                                        width: 20
                                        height: 20
                                        anchors.centerIn: parent
                                        anchors.horizontalCenterOffset: I18n.isRtl ? -5 : 5
                                        source: !sidebarButton.modelData.isIcon ? sidebarButton.modelData.icon : ""
                                        sourceSize: Qt.size(width * 2, height * 2)
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                        asynchronous: true
                                        layer.enabled: true
                                        layer.effect: MultiEffect {
                                            brightness: 1.0
                                            colorization: 1.0
                                            colorizationColor: sidebarButton.isActive ? Styling.srItem("overprimary") : Styling.srItem("common")
                                        }
                                    }
                                }

                                // Text
                                Text {
                                    text: sidebarButton.modelData.label
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(0)
                                    font.weight: sidebarButton.isActive ? Font.Bold : Font.Normal
                                    color: sidebarButton.isActive ? Styling.srItem("overprimary") : Styling.srItem("common")
                                    anchors.verticalCenter: parent.verticalCenter
                                    horizontalAlignment: I18n.isRtl ? Text.AlignRight : Text.AlignLeft

                                    Behavior on color {
                                        enabled: Config.animDuration > 0
                                        ColorAnimation {
                                            duration: Config.animDuration
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }
                            }

                            onClicked: root.navigateTo(sidebarButton.modelData.section)
                        }
                    }

                    Item {
                        id: searchResultsSidebar
                        width: parent.width
                        visible: root.searchResults.length > 0
                        height: searchResultsSidebar.visible ? searchResultsList.implicitHeight : 0

                        Column {
                            anchors.fill: parent
                            spacing: 6

                            Text {
                                text: I18n.t("Results ({0})", "Results ({0})", [root.searchResults.length])
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                color: Colors.overSurfaceVariant
                                leftPadding: I18n.isRtl ? 0 : 6
                                rightPadding: I18n.isRtl ? 6 : 0
                                horizontalAlignment: I18n.isRtl ? Text.AlignRight : Text.AlignLeft
                            }

                            ListView {
                                id: searchResultsList
                                width: parent.width
                                implicitHeight: Math.min(contentHeight, 280)
                                model: root.searchResults
                                spacing: 6
                                clip: true

                                delegate: Button {
                                    required property var modelData
                                    width: parent.width
                                    height: 56
                                    flat: true
                                    hoverEnabled: true
                                    leftPadding: I18n.isRtl ? 10 : 10
                                    rightPadding: I18n.isRtl ? 10 : 10
                                    LayoutMirroring.enabled: I18n.isRtl
                                    LayoutMirroring.childrenInherit: true

                                    background: Rectangle {
                                        color: parent.hovered ? Colors.surfaceContainerHigh : Colors.surfaceContainer
                                        radius: Styling.radius(-2)
                                    }

                                    contentItem: ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 2

                                        Text {
                                            text: modelData.title
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(0)
                                            font.weight: Font.Medium
                                            color: Colors.overBackground
                                            elide: Text.ElideRight
                                            horizontalAlignment: I18n.isRtl ? Text.AlignRight : Text.AlignLeft
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            text: modelData.path
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(-1)
                                            color: Colors.overSurfaceVariant
                                            elide: Text.ElideRight
                                            horizontalAlignment: I18n.isRtl ? Text.AlignRight : Text.AlignLeft
                                            Layout.fillWidth: true
                                        }
                                    }

                                    onClicked: root.applySearchResult(modelData)
                                }
                            }
                        }
                    }
                }

                // Scroll wheel navigation between sections
                WheelHandler {
                    enabled: sidebarFlickable.contentHeight <= sidebarFlickable.height
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        const filteredIndex = root.filteredIndexForSection(root.currentSection);
                        if (filteredIndex < 0)
                            return;
                        if (event.angleDelta.y > 0 && filteredIndex > 0) {
                            root.navigateTo(root.filteredSections[filteredIndex - 1].section);
                        } else if (event.angleDelta.y < 0 && filteredIndex < root.filteredSections.length - 1) {
                            root.navigateTo(root.filteredSections[filteredIndex + 1].section);
                        }
                    }
                }
            }
        }

        // Content area with animated transitions
        Item {
            id: contentArea
            Layout.row: 0
            Layout.column: root.isRtl ? 0 : 1
            Layout.rowSpan: 2
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            property int previousSection: 0
            readonly property int maxContentWidth: 480

            // Track section changes for animation direction
            onVisibleChanged: {
                if (visible) {
                    contentArea.previousSection = root.currentSection;
                }
            }

            Connections {
                target: root
                function onCurrentSectionChanged() {
                    contentArea.previousSection = root.currentSection;
                }
            }

            // WiFi Panel
            WifiPanel {
                id: wifiPanel
                anchors.fill: parent
                maxContentWidth: contentArea.maxContentWidth
                visible: opacity > 0
                opacity: root.currentSection === 0 ? 1 : 0

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutCubic
                    }
                }

                transform: Translate {
                    y: root.currentSection === 0 ? 0 : (root.currentSection > 0 ? -20 : 20)

                    Behavior on y {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }

            // Bluetooth Panel
            BluetoothPanel {
                id: bluetoothPanel
                anchors.fill: parent
                maxContentWidth: contentArea.maxContentWidth
                visible: opacity > 0
                opacity: root.currentSection === 1 ? 1 : 0

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutCubic
                    }
                }

                transform: Translate {
                    y: root.currentSection === 1 ? 0 : (root.currentSection > 1 ? -20 : 20)

                    Behavior on y {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }

            // Audio Mixer Panel
            AudioMixerPanel {
                id: audioPanel
                anchors.fill: parent
                maxContentWidth: contentArea.maxContentWidth
                visible: opacity > 0
                opacity: root.currentSection === 2 ? 1 : 0

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutCubic
                    }
                }

                transform: Translate {
                    y: root.currentSection === 2 ? 0 : (root.currentSection > 2 ? -20 : 20)

                    Behavior on y {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }

            // EasyEffects Panel
            EasyEffectsPanel {
                id: effectsPanel
                anchors.fill: parent
                maxContentWidth: contentArea.maxContentWidth
                visible: opacity > 0
                opacity: root.currentSection === 3 ? 1 : 0

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutCubic
                    }
                }

                transform: Translate {
                    y: root.currentSection === 3 ? 0 : (root.currentSection > 3 ? -20 : 20)

                    Behavior on y {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }

            // Theme Panel
            ThemePanel {
                id: themePanel
                anchors.fill: parent
                maxContentWidth: contentArea.maxContentWidth
                visible: opacity > 0
                opacity: root.currentSection === 4 ? 1 : 0

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutCubic
                    }
                }

                transform: Translate {
                    y: root.currentSection === 4 ? 0 : (root.currentSection > 4 ? -20 : 20)

                    Behavior on y {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }

            // Binds Panel
            BindsPanel {
                id: bindsPanel
                anchors.fill: parent
                maxContentWidth: contentArea.maxContentWidth
                visible: opacity > 0
                opacity: root.currentSection === 5 ? 1 : 0

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutCubic
                    }
                }

                transform: Translate {
                    y: root.currentSection === 5 ? 0 : (root.currentSection > 5 ? -20 : 20)

                    Behavior on y {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }

            // System Panel
            SystemPanel {
                id: systemPanel
                anchors.fill: parent
                maxContentWidth: contentArea.maxContentWidth
                visible: opacity > 0
                opacity: root.currentSection === 6 ? 1 : 0

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutCubic
                    }
                }

                transform: Translate {
                    y: root.currentSection === 6 ? 0 : (root.currentSection > 6 ? -20 : 20)

                    Behavior on y {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }

            // Compositor Panel
            CompositorPanel {
                id: compositorPanel
                anchors.fill: parent
                maxContentWidth: contentArea.maxContentWidth
                visible: opacity > 0
                opacity: root.currentSection === 7 ? 1 : 0

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutCubic
                    }
                }

                transform: Translate {
                    y: root.currentSection === 7 ? 0 : (root.currentSection > 7 ? -20 : 20)

                    Behavior on y {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }

            // Shell Panel
            ShellPanel {
                id: shellPanel
                anchors.fill: parent
                maxContentWidth: contentArea.maxContentWidth
                visible: opacity > 0
                opacity: root.currentSection === 8 ? 1 : 0

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutCubic
                    }
                }

                transform: Translate {
                    y: root.currentSection === 8 ? 0 : (root.currentSection > 8 ? -20 : 20)

                    Behavior on y {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }

        }
    }

    Component.onCompleted: {
        resetNavigation();
        updateTitlebarControls();
    }

    Connections {
        target: shellPanel
        function onCurrentSectionChanged() {
            root._recordRouteChange();
            root.updateTitlebarControls();
        }
    }

    onCurrentSectionChanged: {
        _recordRouteChange();
        updateTitlebarControls();
    }

    Component {
        id: audioToggleComponent
        RowLayout {
            spacing: 4

            StyledRect {
                id: outputBtn
                property bool isSelected: audioPanel ? audioPanel.showOutput : true
                property bool isHovered: false
                
                variant: isSelected ? "primary" : (isHovered ? "focus" : "common")
                Layout.preferredHeight: 28
                Layout.preferredWidth: outputContent.width + 20
                radius: isSelected ? Styling.radius(-4) : Styling.radius(0)
                
                Row {
                    id: outputContent
                    anchors.centerIn: parent
                    spacing: 6
                    
                    Text {
                        text: Icons.speakerHigh
                        font.family: Icons.font
                        font.pixelSize: 12
                        color: outputBtn.item
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    
                    Text {
                        text: I18n.t("Output")
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-2)
                        font.weight: Font.Medium
                        color: outputBtn.item
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: outputBtn.isHovered = true
                    onExited: outputBtn.isHovered = false
                    onClicked: {
                        if (audioPanel)
                            audioPanel.showOutput = true;
                    }
                }
            }

            StyledRect {
                id: inputBtn
                property bool isSelected: audioPanel ? !audioPanel.showOutput : false
                property bool isHovered: false
                
                variant: isSelected ? "primary" : (isHovered ? "focus" : "common")
                Layout.preferredHeight: 28
                Layout.preferredWidth: inputContent.width + 20
                radius: isSelected ? Styling.radius(-4) : Styling.radius(0)
                
                Row {
                    id: inputContent
                    anchors.centerIn: parent
                    spacing: 6
                    
                    Text {
                        text: Icons.mic
                        font.family: Icons.font
                        font.pixelSize: 12
                        color: inputBtn.item
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    
                    Text {
                        text: I18n.t("Input")
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-2)
                        font.weight: Font.Medium
                        color: inputBtn.item
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: inputBtn.isHovered = true
                    onExited: inputBtn.isHovered = false
                    onClicked: {
                        if (audioPanel)
                            audioPanel.showOutput = false;
                    }
                }
            }
        }
    }

}
