pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import QtQuick.Effects
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.globals
import "SettingsCrawler.js" as SettingsCrawler

Rectangle {
    id: root
    color: "transparent"
    implicitWidth: 400
    implicitHeight: 300
    // 0: Network, 1: Bluetooth, 2: Mixer, 3: AI, 4: Effects, 5: Theme, 6: Binds, 7: System, 8: Compositor, 9: Shell

    property int currentSection: 0
    property int selectedIndex: GlobalStates.settingsCurrentTab
    property string searchQuery: ""

    onFilteredSectionsChanged: selectedIndex = 0

    // Timer to restore focus after panel transitions
    Timer {
        id: focusRestoreTimer
        interval: 50
        onTriggered: searchInput.focusInput()
    }

    onSelectedIndexChanged: {
        GlobalStates.settingsCurrentTab = selectedIndex;
        if (filteredSections && selectedIndex >= 0 && selectedIndex < filteredSections.length) {
            const item = filteredSections[selectedIndex];
            root.currentSection = item.section;
            // Automatically show subsection preview when navigating search results
            root.dispatchSubSection(item.section, item.subSection);
            root.scrollSidebarToSelection();
            // Use timer to ensure focus is restored AFTER any panel focus-stealing
            focusRestoreTimer.restart();
        }
    }

    Connections {
        target: GlobalStates
        function onSettingsCurrentTabChanged() {
            if (root.selectedIndex !== GlobalStates.settingsCurrentTab) {
                root.selectedIndex = GlobalStates.settingsCurrentTab;
            }
        }
    }

    // Focus the search input (called from parent Dashboard)
    function focusSearchInput() {
        searchInput.focusInput();
    }

    SettingsIndex {
        id: searchIndex
    }

    // ─── Dynamic Settings Indexer (deferred to avoid startup lag) ───
    Item {
        id: settingsIndexer
        visible: false

        property int currentPanelIndex: 0
        property var aggregatedItems: []
        property bool isIndexing: false

        Loader {
            id: indexerLoader
            active: settingsIndexer.isIndexing
            asynchronous: true
            source: settingsIndexer.isIndexing && settingsIndexer.currentPanelIndex < contentArea.panelComponents.length
                ? contentArea.panelComponents[settingsIndexer.currentPanelIndex].component
                : ""

            onStatusChanged: {
                if (status === Loader.Ready && item) {
                    const sectionId = contentArea.panelComponents[settingsIndexer.currentPanelIndex].section;
                    const newItems = SettingsCrawler.crawl(item, sectionId);
                    settingsIndexer.aggregatedItems = settingsIndexer.aggregatedItems.concat(newItems);
                    settingsIndexer.currentPanelIndex++;
                } else if (status === Loader.Error) {
                    console.warn("Failed to load panel for indexing:", source);
                    settingsIndexer.currentPanelIndex++;
                }
            }
        }

        onCurrentPanelIndexChanged: {
            if (currentPanelIndex >= contentArea.panelComponents.length && isIndexing) {
                isIndexing = false;
                searchIndex.addDynamicItems(aggregatedItems);
            }
        }

        // Delay indexing until the UI has fully settled after open
        Timer {
            id: indexingTimer
            interval: 2500
            onTriggered: {
                // Only start if the window is still visible (user hasn't closed it)
                if (root.visible) {
                    settingsIndexer.isIndexing = true;
                }
            }
        }

        Component.onCompleted: {
            indexingTimer.start();
        }
    }

    // Store pending subsection to apply when panel loads
    property string pendingSubSection: ""

    function dispatchSubSection(sectionId, subSectionId) {
        if (!subSectionId || subSectionId === "")
            return;

        // Panels that support subsections: Theme(5), System(7), Compositor(8), Shell(9)
        if (sectionId === 5 || sectionId === 7 || sectionId === 8 || sectionId === 9) {
            if (panelLoader.item && panelLoader.status === Loader.Ready) {
                panelLoader.item.currentSection = subSectionId;
            } else {
                pendingSubSection = subSectionId;
            }
        }
    }

    // Scroll sidebar to ensure visible selection
    function scrollSidebarToSelection() {
        if (sidebarFlickable.height <= 0)
            return;

        const tabHeight = 48;
        const tabSpacing = 0;
        const itemY = root.selectedIndex * (tabHeight + tabSpacing);

        if (itemY < sidebarFlickable.contentY) {
            sidebarFlickable.contentY = itemY;
        } else if (itemY + tabHeight > sidebarFlickable.contentY + sidebarFlickable.height) {
            sidebarFlickable.contentY = itemY + tabHeight - sidebarFlickable.height;
        }
    }

    // ─── High-performance fuzzy matching ───
    // Returns boolean (fast path for filter checks)
    function fuzzyMatch(query, target) {
        if (query.length === 0) return true;
        if (target.length === 0) return false;
        const lowerQuery = query.toLowerCase();
        const lowerTarget = target.toLowerCase();
        let qi = 0;
        // Micro-opt: cache length, use while loop, avoid bounds checks on each iteration
        const qLen = lowerQuery.length, tLen = lowerTarget.length;
        for (let i = 0; i < tLen && qi < qLen; i++) {
            if (lowerTarget.charCodeAt(i) === lowerQuery.charCodeAt(qi)) {
                qi++;
            }
        }
        return qi === qLen;
    }

    // Returns integer score (higher = better match)
    function fuzzyScore(query, target) {
        if (query.length === 0) return 0;
        if (target.length === 0) return -1;
        const lowerQuery = query.toLowerCase();
        const lowerTarget = target.toLowerCase();
        const qLen = lowerQuery.length, tLen = lowerTarget.length;

        // Fast path: exact substring match → high score
        if (lowerTarget.indexOf(lowerQuery) !== -1)
            return 1000 + (100 - tLen);

        // Fuzzy scoring with character codes for speed
        let qi = 0, score = 0, consec = 0, maxConsec = 0;
        for (let i = 0; i < tLen && qi < qLen; i++) {
            const tc = lowerTarget.charCodeAt(i);
            if (tc === lowerQuery.charCodeAt(qi)) {
                qi++;
                consec++;
                if (consec > maxConsec) maxConsec = consec;
                // Bonus for match at word boundary
                if (i === 0 || tc < 97 || tc > 122) { // non-lowercase = boundary
                    score += 10;
                }
            } else {
                consec = 0;
            }
        }
        return qi === qLen ? score + maxConsec * 5 : -1;
    }

    // Original sections model
    readonly property var sectionModel: [
        {
            icon: Icons.wifiHigh,
            label: "Network",
            section: 0,
            isIcon: true
        },
        {
            icon: Icons.bluetooth,
            label: "Bluetooth",
            section: 1,
            isIcon: true
        },
        {
            icon: Icons.faders,
            label: "Mixer",
            section: 2,
            isIcon: true
        },
        {
            icon: Icons.robot,
            label: "AI",
            section: 3,
            isIcon: true
        },
        {
            icon: Icons.waveform,
            label: "Effects",
            section: 4,
            isIcon: true
        },
        {
            icon: Icons.paintBrush,
            label: "Theme",
            section: 5,
            isIcon: true
        },
        {
            icon: Icons.keyboard,
            label: "Binds",
            section: 6,
            isIcon: true
        },
        {
            icon: Icons.circuitry,
            label: "System",
            section: 7,
            isIcon: true
        },
        {
            icon: Icons.compositor,
            label: "Compositor",
            section: 8,
            isIcon: true
        },
        {
            icon: Qt.resolvedUrl("../../../../assets/nothingless/nothingless-icon.svg"),
            label: "NothingLess",
            section: 9,
            isIcon: false
        }
    ]

    // Filtered sections based on search query
    readonly property var filteredSections: {
        if (searchQuery.length === 0)
            return sectionModel;

        const query = searchQuery.toLowerCase();
        const items = searchIndex.items;
        const results = [];

        // Single pass filter + map, avoid .filter().map() churn
        for (let i = 0; i < items.length; i++) {
            const item = items[i];
            if (!fuzzyMatch(query, item.label) && !(item.keywords && item.keywords.indexOf(query) !== -1))
                continue;

            const sectionMeta = sectionModel.find(s => s.section === item.section) || {};
            results.push({
                label: item.label,
                section: item.section,
                subSection: item.subSection || "",
                subLabel: item.subLabel || "",
                icon: sectionMeta.icon || item.icon,
                isIcon: sectionMeta.isIcon !== undefined ? sectionMeta.isIcon : (item.isIcon !== undefined ? item.isIcon : true),
                score: fuzzyScore(query, item.label)
            });
        }

        // Sort results by score descending
        results.sort((a, b) => b.score - a.score);
        return results;
    }

    // Find the index of current section in filtered list
    function getFilteredIndex(sectionId) {
        const fLen = filteredSections.length;
        for (let i = 0; i < fLen; i++) {
            if (filteredSections[i].section === sectionId)
                return i;
        }
        return -1;
    }

    RowLayout {
        anchors.fill: parent
        spacing: 8

        // Sidebar area: search + list
        ColumnLayout {
            Layout.preferredWidth: 200
            Layout.maximumWidth: 200
            Layout.fillHeight: true
            spacing: 4

            // Search input (separate from panel list)
            SearchInput {
                id: searchInput
                Layout.fillWidth: true
                placeholderText: "Search..."
                clearOnEscape: true

                onSearchTextChanged: text => {
                    root.searchQuery = text;
                }
                // ESC to escape dashboard
                onEscapePressed: {
                    searchInput.focus = false;
                    root.forceActiveFocus();
                }

                onAccepted: {
                    // If single result, select it; if multiple, select top one
                    if (root.filteredSections.length > 0) {
                        const item = root.filteredSections[root.selectedIndex];
                        root.currentSection = item.section;
                        root.dispatchSubSection(item.section, item.subSection);
                    }
                }

                onDownPressed: {
                    if (root.selectedIndex < root.filteredSections.length - 1) {
                        root.selectedIndex++;
                    } else {
                        root.selectedIndex = 0;
                    }
                }

                onUpPressed: {
                    if (root.selectedIndex > 0) {
                        root.selectedIndex--;
                    } else {
                        root.selectedIndex = root.filteredSections.length - 1;
                    }
                }
            }

            // Sidebar container with background
            StyledRect {
                id: sidebarContainer
                variant: "common"
                Layout.fillWidth: true
                Layout.fillHeight: true

                Flickable {
                    id: sidebarFlickable
                    anchors.fill: parent
                    anchors.margins: 4
                    contentWidth: width
                    contentHeight: sidebar.height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Behavior on contentY {
                        enabled: Config.animDuration > 0 && !sidebarFlickable.moving
                        NumberAnimation {
                            duration: Config.animDuration / 2
                            easing.type: Easing.OutCubic
                        }
                    }

                    // Sliding highlight behind tabs
                    StyledRect {
                        id: tabHighlight
                        variant: "focus"
                        width: parent.width
                        height: 48
                        radius: Styling.radius(-6)
                        z: 0

                        readonly property int tabHeight: 48
                        readonly property int tabSpacing: 0

                        x: 0
                        y: {
                            const idx = root.selectedIndex;
                            return idx >= 0 ? idx * (tabHeight + tabSpacing) : 0;
                        }
                        visible: root.selectedIndex >= 0 && root.selectedIndex < root.filteredSections.length

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
                        spacing: 0
                        z: 1

                        Repeater {
                            model: root.filteredSections

                            delegate: Button {
                                id: sidebarButton
                                required property var modelData
                                required property int index

                                width: sidebar.width
                                height: 48
                                flat: true
                                hoverEnabled: true

                                readonly property bool isActive: index === root.selectedIndex

                                background: Rectangle {
                                    color: "transparent"
                                }

                                contentItem: Row {
                                    spacing: 8

                                    // Icon on the left (font icon)
                                    Text {
                                        id: iconText
                                        text: sidebarButton.modelData.isIcon ? sidebarButton.modelData.icon : ""
                                        font.family: Icons.font
                                        font.pixelSize: 20
                                        color: sidebarButton.isActive ? Styling.srItem("primary") : Styling.srItem("common")
                                        anchors.verticalCenter: parent.verticalCenter
                                        leftPadding: 10
                                        visible: sidebarButton.modelData.isIcon && (root.searchQuery.length === 0 || !sidebarButton.modelData.subSection)

                                        Behavior on color {
                                            enabled: Config.animDuration > 0
                                            ColorAnimation {
                                                duration: Config.animDuration
                                                easing.type: Easing.OutCubic
                                            }
                                        }
                                    }

                                    // SVG icon (layer removed — same visual via icon font or direct colorization)
                                    Item {
                                        width: 30
                                        height: 20
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: !sidebarButton.modelData.isIcon && (root.searchQuery.length === 0 || !sidebarButton.modelData.subSection)

                                        Image {
                                            id: svgIcon
                                            width: 20
                                            height: 20
                                            anchors.centerIn: parent
                                            anchors.horizontalCenterOffset: 5
                                            source: !sidebarButton.modelData.isIcon ? sidebarButton.modelData.icon : ""
                                            sourceSize: Qt.size(width * 2, height * 2)
                                            fillMode: Image.PreserveAspectFit
                                            smooth: true
                                            asynchronous: true
                                            layer.enabled: true
                                            layer.samplerName: "source"
                                            layer.effect: MultiEffect {
                                                brightness: 1.0
                                                colorization: 1.0
                                                colorizationColor: sidebarButton.isActive ? Styling.srItem("primary") : Styling.srItem("common")
                                            }
                                        }
                                    }

                                    // Text
                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter

                                        Text {
                                            text: sidebarButton.modelData.label
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(0)
                                            font.weight: sidebarButton.isActive ? Font.Bold : Font.Normal
                                            color: sidebarButton.isActive ? Styling.srItem("primary") : Styling.srItem("common")

                                            Behavior on color {
                                                enabled: Config.animDuration > 0
                                                ColorAnimation {
                                                    duration: Config.animDuration
                                                    easing.type: Easing.OutCubic
                                                }
                                            }
                                        }

                                        Text {
                                            visible: !!sidebarButton.modelData.subLabel
                                            text: sidebarButton.modelData.subLabel || ""
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(-2)
                                            color: Colors.overSurfaceVariant
                                        }
                                    }
                                }

                                onClicked: {
                                    root.selectedIndex = index;
                                    // currentSection updates via binding on selectedIndex
                                    root.dispatchSubSection(sidebarButton.modelData.section, sidebarButton.modelData.subSection);
                                }
                            }
                        }
                    }

                    // Scroll wheel navigation between sections
                    WheelHandler {
                        enabled: sidebarFlickable.contentHeight <= sidebarFlickable.height
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: event => {
                            if (event.angleDelta.y > 0 && root.selectedIndex > 0) {
                                root.selectedIndex--;
                            } else if (event.angleDelta.y < 0 && root.selectedIndex < root.filteredSections.length - 1) {
                                root.selectedIndex++;
                            }
                        }
                    }
                }
            }
        }

        // Content area with animated transitions
        Item {
            id: contentArea
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

            // Panel definitions for Loader
            readonly property var panelComponents: [
                {
                    component: "WifiPanel.qml",
                    section: 0
                },
                {
                    component: "BluetoothPanel.qml",
                    section: 1
                },
                {
                    component: "AudioMixerPanel.qml",
                    section: 2
                },
                {
                    component: "../../config/AiPanel.qml",
                    section: 3
                },
                {
                    component: "EasyEffectsPanel.qml",
                    section: 4
                },
                {
                    component: "ThemePanel.qml",
                    section: 5
                },
                {
                    component: "BindsPanel.qml",
                    section: 6
                },
                {
                    component: "SystemPanel.qml",
                    section: 7
                },
                {
                    component: "CompositorPanel.qml",
                    section: 8
                },
                {
                    component: "ShellPanel.qml",
                    section: 9
                }
            ]

            // Lazy-loaded panel using Loader
            Loader {
                id: panelLoader
                anchors.fill: parent
                asynchronous: true
                source: contentArea.panelComponents[root.currentSection]?.component ?? ""

                // Fade in animation
                opacity: status === Loader.Ready ? 1 : 0
                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutCubic
                    }
                }

                onLoaded: {
                    if (item) {
                        item.maxContentWidth = contentArea.maxContentWidth;
                        // Apply pending subsection if any
                        if (root.pendingSubSection !== "" && item.currentSection !== undefined) {
                            item.currentSection = root.pendingSubSection;
                            root.pendingSubSection = "";
                        }
                    }
                }
            }
        }
    }
}
