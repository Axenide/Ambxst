import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.globals
import qs.config
import "../clipboard"
import "../emoji"
import "../tmux"
import "../wallpapers"
import "calendar"

Rectangle {
    color: "transparent"
    implicitWidth: 600
    implicitHeight: 300

    property int currentTab: GlobalStates.widgetsTabCurrentIndex  // 0=launcher, 1=clip, 2=emoji, 3=tmux, 4=wall
    property bool prefixDisabled: false  // Flag to prevent re-activation after backspace

    // Sync with GlobalStates
    onCurrentTabChanged: {
        GlobalStates.widgetsTabCurrentIndex = currentTab;
    }

    // Function to focus app search when tab becomes active
    function focusAppSearch() {
        Qt.callLater(() => {
            if (currentTab === 0) {
                appLauncher.focusSearchInput();
            } else {
                let currentItem = internalStack.itemAt(currentTab);
                if (currentItem && currentItem.focusSearchInput) {
                    currentItem.focusSearchInput();
                }
            }
        });
    }

    // Expose this for Dashboard compatibility
    function focusSearchInput() {
        focusAppSearch();
    }

    // Handle prefix detection in launcher
    function detectPrefix(text) {
        let clipPrefix = Config.prefix.clipboard + " ";
        let emojiPrefix = Config.prefix.emoji + " ";
        let tmuxPrefix = Config.prefix.tmux + " ";
        let wallPrefix = Config.prefix.wallpapers + " ";

        // If prefix was manually disabled, don't re-enable until conditions are met
        if (prefixDisabled) {
            // Only re-enable prefix if user deletes the prefix text or adds valid content
            if (text === clipPrefix || text === emojiPrefix || text === tmuxPrefix || text === wallPrefix) {
                // Still at exact prefix - keep disabled
                return 0;
            } else if (!text.startsWith(clipPrefix) && !text.startsWith(emojiPrefix) && !text.startsWith(tmuxPrefix) && !text.startsWith(wallPrefix)) {
                // User deleted the prefix - re-enable detection
                prefixDisabled = false;
                return 0;
            } else {
                // User typed something after the prefix but it's still disabled
                return 0;
            }
        }

        // Normal prefix detection - only activate if exactly "prefix " (nothing after)
        if (text === clipPrefix) {
            return 1;
        } else if (text === emojiPrefix) {
            return 2;
        } else if (text === tmuxPrefix) {
            return 3;
        } else if (text === wallPrefix) {
            return 4;
        }
        return 0;
    }

    RowLayout {
        anchors.fill: parent
        spacing: 8

        // App Launcher - shown only when currentTab === 0
        Rectangle {
            id: appLauncher
            Layout.preferredWidth: LayoutMetrics.calculateLeftPanelWidth(parent.width, parent.height, parent.spacing)
            Layout.fillHeight: true
            visible: currentTab === 0
            color: "transparent"

            property string searchText: GlobalStates.launcherSearchText
            property bool showResults: searchText.length > 0
            property int selectedIndex: GlobalStates.launcherSelectedIndex
            property bool optionsMenuOpen: false
            property int menuItemIndex: -1
            property bool menuJustClosed: false

            onSearchTextChanged: {
                // Detect prefix and switch tab if needed
                let detectedTab = detectPrefix(searchText);
                if (detectedTab !== currentTab) {
                    if (detectedTab === 0) {
                        // Return to launcher
                        currentTab = 0;
                        prefixDisabled = false;
                        Qt.callLater(() => {
                            appLauncher.focusSearchInput();
                        });
                    } else {
                        // Switch to prefix tab
                        currentTab = detectedTab;

                        // Extract the text after the prefix
                        let prefixLength = 0;
                        if (searchText.startsWith(Config.prefix.clipboard + " "))
                            prefixLength = Config.prefix.clipboard.length + 1;
                        else if (searchText.startsWith(Config.prefix.emoji + " "))
                            prefixLength = Config.prefix.emoji.length + 1;
                        else if (searchText.startsWith(Config.prefix.tmux + " "))
                            prefixLength = Config.prefix.tmux.length + 1;
                        else if (searchText.startsWith(Config.prefix.wallpapers + " "))
                            prefixLength = Config.prefix.wallpapers.length + 1;

                        let remainingText = searchText.substring(prefixLength);

                        // Wait for loader to be ready and then focus
                        Qt.callLater(() => {
                            let targetItem = null;
                            let targetLoader = null;

                            if (detectedTab === 1) {
                                targetLoader = clipboardLoader;
                            } else if (detectedTab === 2) {
                                targetLoader = emojiLoader;
                            } else if (detectedTab === 3) {
                                targetLoader = tmuxLoader;
                            } else if (detectedTab === 4) {
                                targetLoader = wallpapersLoader;
                            }

                            // If loader is ready, use it immediately
                            if (targetLoader && targetLoader.item) {
                                targetItem = targetLoader.item;
                                // Set the search text in the new tab
                                if (targetItem.searchText !== undefined) {
                                    targetItem.searchText = remainingText;
                                }
                                // Focus the search input
                                if (targetItem.focusSearchInput) {
                                    targetItem.focusSearchInput();
                                }
                            }
                            // Otherwise, the onLoaded handler will take care of focusing
                        });
                    }
                }
            }

            onSelectedIndexChanged: {
                if (selectedIndex === -1 && resultsList.count > 0) {
                    resultsList.positionViewAtIndex(0, ListView.Beginning);
                }
            }

            function clearSearch() {
                GlobalStates.clearLauncherState();
                searchInput.focusInput();
            }

            function focusSearchInput() {
                searchInput.focusInput();
            }

            Behavior on height {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration
                    easing.type: Easing.OutQuart
                }
            }

            ColumnLayout {
                id: mainLayout
                anchors.fill: parent
                spacing: 8

                // Search input
                SearchInput {
                    id: searchInput
                    Layout.fillWidth: true
                    text: GlobalStates.launcherSearchText
                    placeholderText: "Search applications..."
                    iconText: ""

                    onSearchTextChanged: text => {
                        GlobalStates.launcherSearchText = text;
                        appLauncher.searchText = text;
                        if (text.length > 0) {
                            GlobalStates.launcherSelectedIndex = 0;
                            appLauncher.selectedIndex = 0;
                            resultsList.currentIndex = 0;
                        } else {
                            GlobalStates.launcherSelectedIndex = -1;
                            appLauncher.selectedIndex = -1;
                            resultsList.currentIndex = -1;
                        }
                    }

                    onAccepted: {
                        if (appLauncher.selectedIndex >= 0 && appLauncher.selectedIndex < resultsList.count) {
                            let selectedApp = resultsList.model[appLauncher.selectedIndex];
                            if (selectedApp) {
                                selectedApp.execute();
                                Visibilities.setActiveModule("");
                            }
                        }
                    }

                    onEscapePressed: {
                        Visibilities.setActiveModule("");
                    }

                    onDownPressed: {
                        if (resultsList.count > 0) {
                            if (appLauncher.selectedIndex === -1) {
                                GlobalStates.launcherSelectedIndex = 0;
                                appLauncher.selectedIndex = 0;
                                resultsList.currentIndex = 0;
                            } else if (appLauncher.selectedIndex < resultsList.count - 1) {
                                GlobalStates.launcherSelectedIndex++;
                                appLauncher.selectedIndex++;
                                resultsList.currentIndex = appLauncher.selectedIndex;
                            }
                        }
                    }

                    onUpPressed: {
                        if (appLauncher.selectedIndex > 0) {
                            GlobalStates.launcherSelectedIndex--;
                            appLauncher.selectedIndex--;
                            resultsList.currentIndex = appLauncher.selectedIndex;
                        } else if (appLauncher.selectedIndex === 0 && appLauncher.searchText.length === 0) {
                            GlobalStates.launcherSelectedIndex = -1;
                            appLauncher.selectedIndex = -1;
                            resultsList.currentIndex = -1;
                        }
                    }

                    onPageDownPressed: {
                        if (resultsList.count > 0) {
                            let visibleItems = Math.floor(resultsList.height / 48);
                            let newIndex = Math.min(appLauncher.selectedIndex + visibleItems, resultsList.count - 1);
                            if (appLauncher.selectedIndex === -1) {
                                newIndex = Math.min(visibleItems - 1, resultsList.count - 1);
                            }
                            GlobalStates.launcherSelectedIndex = newIndex;
                            appLauncher.selectedIndex = newIndex;
                            resultsList.currentIndex = appLauncher.selectedIndex;
                        }
                    }

                    onPageUpPressed: {
                        if (resultsList.count > 0) {
                            let visibleItems = Math.floor(resultsList.height / 48);
                            let newIndex = Math.max(appLauncher.selectedIndex - visibleItems, 0);
                            if (appLauncher.selectedIndex === -1) {
                                newIndex = Math.max(resultsList.count - visibleItems, 0);
                            }
                            GlobalStates.launcherSelectedIndex = newIndex;
                            appLauncher.selectedIndex = newIndex;
                            resultsList.currentIndex = appLauncher.selectedIndex;
                        }
                    }

                    onHomePressed: {
                        if (resultsList.count > 0) {
                            GlobalStates.launcherSelectedIndex = 0;
                            appLauncher.selectedIndex = 0;
                            resultsList.currentIndex = 0;
                        }
                    }

                    onEndPressed: {
                        if (resultsList.count > 0) {
                            GlobalStates.launcherSelectedIndex = resultsList.count - 1;
                            appLauncher.selectedIndex = resultsList.count - 1;
                            resultsList.currentIndex = appLauncher.selectedIndex;
                        }
                    }
                }

                // Results list
                ListView {
                    id: resultsList
                    Layout.fillWidth: true
                    Layout.preferredHeight: 7 * 48
                    visible: true
                    clip: true
                    interactive: !appLauncher.optionsMenuOpen
                    cacheBuffer: 96
                    reuseItems: true

                    model: appLauncher.searchText.length > 0 ? AppSearch.fuzzyQuery(appLauncher.searchText) : AppSearch.getAllApps()
                    currentIndex: appLauncher.selectedIndex

                    onCurrentIndexChanged: {
                        if (currentIndex !== appLauncher.selectedIndex) {
                            GlobalStates.launcherSelectedIndex = currentIndex;
                            appLauncher.selectedIndex = currentIndex;
                        }
                    }

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        width: resultsList.width
                        height: 48
                        color: "transparent"
                        radius: 16

                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton

                            onEntered: {
                                if (!appLauncher.optionsMenuOpen) {
                                    GlobalStates.launcherSelectedIndex = index;
                                    appLauncher.selectedIndex = index;
                                    resultsList.currentIndex = index;
                                }
                            }
                            onClicked: mouse => {
                                if (appLauncher.menuJustClosed) {
                                    return;
                                }

                                if (mouse.button === Qt.LeftButton) {
                                    modelData.execute();
                                    Visibilities.setActiveModule("");
                                } else if (mouse.button === Qt.RightButton) {
                                    appLauncher.menuItemIndex = index;
                                    appLauncher.optionsMenuOpen = true;
                                    contextMenu.popup(mouse.x, mouse.y);
                                }
                            }

                            OptionsMenu {
                                id: contextMenu

                                onClosed: {
                                    appLauncher.optionsMenuOpen = false;
                                    appLauncher.menuItemIndex = -1;
                                    appLauncher.menuJustClosed = true;
                                    menuClosedTimer.start();
                                }

                                Timer {
                                    id: menuClosedTimer
                                    interval: 100
                                    repeat: false
                                    onTriggered: {
                                        appLauncher.menuJustClosed = false;
                                    }
                                }

                                items: [
                                    {
                                        text: "Launch",
                                        icon: Icons.launch,
                                        highlightColor: Colors.primary,
                                        textColor: Colors.overPrimary,
                                        onTriggered: function () {
                                            modelData.execute();
                                            Visibilities.setActiveModule("");
                                        }
                                    },
                                    {
                                        text: "Create Shortcut",
                                        icon: Icons.shortcut,
                                        highlightColor: Colors.secondary,
                                        textColor: Colors.overSecondary,
                                        onTriggered: function () {
                                            let desktopDir = Quickshell.env("XDG_DESKTOP_DIR") || Quickshell.env("HOME") + "/Desktop";
                                            let timestamp = Date.now();
                                            let fileName = modelData.id + "-" + timestamp + ".desktop";
                                            let filePath = desktopDir + "/" + fileName;

                                            let desktopContent = "[Desktop Entry]\n" + "Version=1.0\n" + "Type=Application\n" + "Name=" + modelData.name + "\n" + "Exec=" + modelData.execString + "\n" + "Icon=" + modelData.icon + "\n" + (modelData.comment ? "Comment=" + modelData.comment + "\n" : "") + (modelData.categories.length > 0 ? "Categories=" + modelData.categories.join(";") + ";\n" : "") + (modelData.runInTerminal ? "Terminal=true\n" : "Terminal=false\n");

                                            let writeCmd = "printf '%s' '" + desktopContent.replace(/'/g, "'\\''") + "' > \"" + filePath + "\" && chmod 755 \"" + filePath + "\" && gio set \"" + filePath + "\" metadata::trusted true";
                                            copyProcess.command = ["sh", "-c", writeCmd];
                                            copyProcess.running = true;
                                        }
                                    }
                                ]
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 12

                            Loader {
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
                                sourceComponent: Config.tintIcons ? tintedIconComponent : normalIconComponent
                            }

                            Component {
                                id: normalIconComponent
                                Image {
                                    id: appIcon
                                    source: "image://icon/" + modelData.icon
                                    fillMode: Image.PreserveAspectFit

                                    Rectangle {
                                        anchors.fill: parent
                                        color: "transparent"
                                        border.color: Colors.outline
                                        border.width: parent.status === Image.Error ? 1 : 0
                                        radius: 4

                                        Text {
                                            anchors.centerIn: parent
                                            text: "?"
                                            visible: parent.parent.status === Image.Error
                                            color: Colors.overBackground
                                            font.family: Config.theme.font
                                        }
                                    }
                                }
                            }

                            Component {
                                id: tintedIconComponent
                                Tinted {
                                    sourceItem: Image {
                                        source: "image://icon/" + modelData.icon
                                        fillMode: Image.PreserveAspectFit
                                    }
                                }
                            }

                            Column {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    width: parent.width
                                    text: modelData.name
                                    color: appLauncher.selectedIndex === index ? Colors.overPrimary : Colors.overBackground
                                    font.family: Config.theme.font
                                    font.pixelSize: Config.theme.fontSize
                                    font.weight: Font.Bold
                                    elide: Text.ElideRight

                                    Behavior on color {
                                        enabled: Config.animDuration > 0
                                        ColorAnimation {
                                            duration: Config.animDuration / 2
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }

                                Text {
                                    width: parent.width
                                    text: modelData.comment || ""
                                    color: appLauncher.selectedIndex === index ? Colors.overPrimary : Colors.outline
                                    font.family: Config.theme.font
                                    font.pixelSize: Math.max(8, Config.theme.fontSize - 2)
                                    elide: Text.ElideRight
                                    visible: text !== ""

                                    Behavior on color {
                                        enabled: Config.animDuration > 0
                                        ColorAnimation {
                                            duration: Config.animDuration / 2
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }
                            }
                        }
                    }

                    highlight: Rectangle {
                        color: Colors.primary
                        radius: Config.roundness > 0 ? Config.roundness + 4 : 0
                        visible: appLauncher.selectedIndex >= 0 && (appLauncher.optionsMenuOpen ? appLauncher.selectedIndex === appLauncher.menuItemIndex : true)
                    }

                    highlightMoveDuration: Config.animDuration > 0 ? Config.animDuration / 2 : 0
                    highlightMoveVelocity: -1
                }
            }

            Component.onCompleted: {
                focusSearchInput();
            }

            Process {
                id: copyProcess
                running: false

                onExited: function (code) {}
            }
        }

        // StackLayout for other tabs (clipboard, emoji, tmux, wallpapers)
        StackLayout {
            id: internalStack
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: currentTab !== 0
            currentIndex: currentTab - 1  // Subtract 1 because launcher is now separate

            // Tab 1: Clipboard (with prefix from config)
            Loader {
                id: clipboardLoader
                active: currentTab === 1
                sourceComponent: Component {
                    ClipboardTab {
                        prefixIcon: Icons.clipboard
                        onBackspaceOnEmpty: {
                            // Return to launcher with prefix text + space
                            prefixDisabled = true;
                            currentTab = 0;
                            GlobalStates.launcherSearchText = Config.prefix.clipboard + " ";
                            appLauncher.focusSearchInput();
                        }
                        onRequestOpenItem: (itemId, items, currentContent, filePathGetter, urlChecker) => {
                            console.log("DEBUG: Received requestOpenItem signal for:", itemId);
                            openItemInternal(itemId, items, currentContent, filePathGetter, urlChecker);
                        }
                    }
                }
                onLoaded: {
                    if (currentTab === 1 && item && item.focusSearchInput) {
                        Qt.callLater(() => item.focusSearchInput());
                    }
                }
            }

            // Tab 2: Emoji (with prefix from config)
            Loader {
                id: emojiLoader
                active: currentTab === 2
                sourceComponent: Component {
                    EmojiTab {
                        prefixIcon: Icons.emoji
                        onBackspaceOnEmpty: {
                            prefixDisabled = true;
                            currentTab = 0;
                            GlobalStates.launcherSearchText = Config.prefix.emoji + " ";
                            appLauncher.focusSearchInput();
                        }
                    }
                }
                onLoaded: {
                    if (currentTab === 2 && item && item.focusSearchInput) {
                        Qt.callLater(() => item.focusSearchInput());
                    }
                }
            }

            // Tab 3: Tmux (with prefix from config)
            Loader {
                id: tmuxLoader
                active: currentTab === 3
                sourceComponent: Component {
                    TmuxTab {
                        prefixIcon: Icons.terminal
                        onBackspaceOnEmpty: {
                            prefixDisabled = true;
                            currentTab = 0;
                            GlobalStates.launcherSearchText = Config.prefix.tmux + " ";
                            appLauncher.focusSearchInput();
                        }
                    }
                }
                onLoaded: {
                    if (currentTab === 3 && item && item.focusSearchInput) {
                        Qt.callLater(() => item.focusSearchInput());
                    }
                }
            }

            // Tab 4: Wallpapers (with prefix from config)
            Loader {
                id: wallpapersLoader
                active: currentTab === 4
                sourceComponent: Component {
                    WallpapersTab {
                        prefixIcon: Icons.wallpapers
                        onBackspaceOnEmpty: {
                            prefixDisabled = true;
                            currentTab = 0;
                            GlobalStates.launcherSearchText = Config.prefix.wallpapers + " ";
                            appLauncher.focusSearchInput();
                        }
                    }
                }
                onLoaded: {
                    if (currentTab === 4 && item && item.focusSearchInput) {
                        Qt.callLater(() => item.focusSearchInput());
                    }
                }
            }
        }

        // Separator (only visible when in launcher tab)
        Separator {
            Layout.preferredWidth: 2
            Layout.fillHeight: true
            vert: true
            gradient: null
            color: Colors.surface
            visible: currentTab === 0
        }

        // Widgets column (only visible when in launcher tab)
        ClippingRectangle {
            id: widgetsContainer
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Config.roundness > 0 ? Config.roundness + 4 : 0
            color: "transparent"
            visible: currentTab === 0

            property bool circularControlDragging: false

            Flickable {
                id: widgetsFlickable
                anchors.fill: parent
                contentWidth: width
                contentHeight: columnLayout.implicitHeight
                clip: true
                interactive: !widgetsContainer.circularControlDragging

                ColumnLayout {
                    id: columnLayout
                    width: parent.width
                    spacing: 8

                    // Control Buttons Row
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        spacing: 4
                        
                        Item { Layout.fillWidth: true }

                        ControlButton {
                            Layout.preferredWidth: 48
                            Layout.preferredHeight: 48
                            iconName: {
                                if (!NetworkService.wifiEnabled) return Icons.wifiOff;
                                const strength = NetworkService.signalStrength;
                                if (strength === 0) return Icons.wifiHigh;
                                if (strength < 25) return Icons.wifiNone;
                                if (strength < 50) return Icons.wifiLow;
                                if (strength < 75) return Icons.wifiMedium;
                                return Icons.wifiHigh;
                            }
                            isActive: NetworkService.wifiEnabled
                            tooltipText: NetworkService.wifiEnabled ? "Wi-Fi: On" : "Wi-Fi: Off"
                            onClicked: NetworkService.toggleWifi()
                        }

                        ControlButton {
                            Layout.preferredWidth: 48
                            Layout.preferredHeight: 48
                            iconName: {
                                if (!BluetoothService.enabled) return Icons.bluetoothOff;
                                if (BluetoothService.connected) return Icons.bluetoothConnected;
                                return Icons.bluetooth;
                            }
                            isActive: BluetoothService.enabled
                            tooltipText: {
                                if (!BluetoothService.enabled) return "Bluetooth: Off";
                                if (BluetoothService.connected) return "Bluetooth: Connected";
                                return "Bluetooth: On";
                            }
                            onClicked: BluetoothService.toggle()
                        }

                        ControlButton {
                            Layout.preferredWidth: 48
                            Layout.preferredHeight: 48
                            iconName: Icons.nightLight
                            isActive: NightLightService.active
                            tooltipText: NightLightService.active ? "Night Light: On" : "Night Light: Off"
                            onClicked: NightLightService.toggle()
                        }

                        ControlButton {
                            Layout.preferredWidth: 48
                            Layout.preferredHeight: 48
                            iconName: Icons.caffeine
                            isActive: CaffeineService.inhibit
                            tooltipText: CaffeineService.inhibit ? "Caffeine: On" : "Caffeine: Off"
                            onClicked: CaffeineService.toggleInhibit()
                        }

                        ControlButton {
                            Layout.preferredWidth: 48
                            Layout.preferredHeight: 48
                            iconName: Icons.gameMode
                            isActive: GameModeService.toggled
                            tooltipText: GameModeService.toggled ? "Game Mode: On" : "Game Mode: Off"
                            onClicked: GameModeService.toggle()
                        }
                        
                        Item { Layout.fillWidth: true }
                    }

                    // Circular Controls Row
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        spacing: 4

                        Item { Layout.fillWidth: true }

                        CircularControl {
                            id: brightnessControl
                            Layout.preferredWidth: 48
                            Layout.preferredHeight: 48
                            icon: Icons.sun
                            value: brightnessValue
                            accentColor: Colors.primary
                            isToggleable: false
                            isToggled: true
                            enableIconRotation: true
                            iconRotation: (value / 1.0) * 180

                            property real brightnessValue: 0
                            property var currentMonitor: {
                                if (Brightness.monitors.length > 0) {
                                    let focusedName = Hyprland.focusedMonitor?.name ?? "";
                                    let found = null;
                                    for (let i = 0; i < Brightness.monitors.length; i++) {
                                        let mon = Brightness.monitors[i];
                                        if (mon && mon.screen && mon.screen.name === focusedName) {
                                            found = mon;
                                            break;
                                        }
                                    }
                                    return found || Brightness.monitors[0];
                                }
                                return null;
                            }

                            Component.onCompleted: {
                                if (currentMonitor && currentMonitor.ready) {
                                    brightnessValue = currentMonitor.brightness;
                                }
                            }

                            onControlValueChanged: newValue => {
                                brightnessValue = newValue;
                                if (currentMonitor && currentMonitor.ready) {
                                    currentMonitor.setBrightness(newValue);
                                }
                            }

                            onDraggingChanged: isDragging => {
                                widgetsContainer.circularControlDragging = isDragging;
                            }

                            Connections {
                                target: brightnessControl.currentMonitor
                                ignoreUnknownSignals: true
                                function onBrightnessChanged() {
                                    if (brightnessControl.currentMonitor && brightnessControl.currentMonitor.ready) {
                                        brightnessControl.brightnessValue = brightnessControl.currentMonitor.brightness;
                                    }
                                }
                                function onReadyChanged() {
                                    if (brightnessControl.currentMonitor && brightnessControl.currentMonitor.ready) {
                                        brightnessControl.brightnessValue = brightnessControl.currentMonitor.brightness;
                                    }
                                }
                            }
                        }

                        CircularControl {
                            id: volumeControl
                            Layout.preferredWidth: 48
                            Layout.preferredHeight: 48
                            icon: {
                                if (Audio.sink?.audio?.muted)
                                    return Icons.speakerSlash;
                                const vol = Audio.sink?.audio?.volume ?? 0;
                                if (vol < 0.01)
                                    return Icons.speakerX;
                                if (vol < 0.19)
                                    return Icons.speakerNone;
                                if (vol < 0.49)
                                    return Icons.speakerLow;
                                return Icons.speakerHigh;
                            }
                            value: Audio.sink?.audio?.volume ?? 0
                            accentColor: Audio.sink?.audio?.muted ? Colors.outline : Colors.primary
                            isToggleable: true
                            isToggled: !(Audio.sink?.audio?.muted ?? false)

                            onControlValueChanged: newValue => {
                                if (Audio.sink?.audio) {
                                    Audio.sink.audio.volume = newValue;
                                }
                            }

                            onDraggingChanged: isDragging => {
                                widgetsContainer.circularControlDragging = isDragging;
                            }

                            onToggled: {
                                if (Audio.sink?.audio) {
                                    Audio.sink.audio.muted = !Audio.sink.audio.muted;
                                }
                            }
                        }

                        CircularControl {
                            id: micControl
                            Layout.preferredWidth: 48
                            Layout.preferredHeight: 48
                            icon: Audio.source?.audio?.muted ? Icons.micSlash : Icons.mic
                            value: Audio.source?.audio?.volume ?? 0
                            accentColor: Audio.source?.audio?.muted ? Colors.outline : Colors.primary
                            isToggleable: true
                            isToggled: !(Audio.source?.audio?.muted ?? false)

                            onControlValueChanged: newValue => {
                                if (Audio.source?.audio) {
                                    Audio.source.audio.volume = newValue;
                                }
                            }

                            onDraggingChanged: isDragging => {
                                widgetsContainer.circularControlDragging = isDragging;
                            }

                            onToggled: {
                                if (Audio.source?.audio) {
                                    Audio.source.audio.muted = !Audio.source.audio.muted;
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }

                    FullPlayer {
                        Layout.fillWidth: true
                    }

                    Calendar {
                        Layout.fillWidth: true
                        Layout.preferredHeight: width
                    }

                    PaneRect {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 150
                    }
                }
            }
        }

        // Notification History (only visible when in launcher tab)
        NotificationHistory {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: currentTab === 0
        }
    }

    Component.onCompleted: {
        Qt.callLater(focusAppSearch);
    }

    // Global process for opening files/URLs - persists even when tabs change
    Process {
        id: globalOpenProcess
        running: false

        onStarted: function () {
            console.log("DEBUG: globalOpenProcess started with command:", globalOpenProcess.command);
        }
        
        onExited: function (code, status) {
            if (code === 0) {
                console.log("DEBUG: globalOpenProcess completed successfully");
            } else {
                console.warn("DEBUG: globalOpenProcess failed with exit code:", code, "status:", status);
            }
        }
    }

    // Internal function to open items - called by signal handlers
    function openItemInternal(itemId, items, currentContent, getFilePathFromUri, isUrl) {
        console.log("DEBUG: WidgetsTab.openItemInternal called for itemId:", itemId);
        for (var i = 0; i < items.length; i++) {
            if (items[i].id === itemId) {
                var item = items[i];
                var content = currentContent || item.preview;
                console.log("DEBUG: item found - isFile:", item.isFile, "isImage:", item.isImage, "content:", content);

                if (item.isFile) {
                    var filePath = getFilePathFromUri(content);
                    console.log("DEBUG: Opening file with path:", filePath);
                    if (filePath) {
                        globalOpenProcess.command = ["xdg-open", filePath];
                        globalOpenProcess.running = true;
                    }
                } else if (item.isImage && item.binaryPath) {
                    console.log("DEBUG: Opening image with binaryPath:", item.binaryPath);
                    globalOpenProcess.command = ["xdg-open", item.binaryPath];
                    globalOpenProcess.running = true;
                } else if (isUrl(content)) {
                    console.log("DEBUG: Opening URL:", content.trim());
                    globalOpenProcess.command = ["xdg-open", content.trim()];
                    globalOpenProcess.running = true;
                } else {
                    console.warn("DEBUG: Item does not match any openable type");
                }
                break;
            }
        }
    }
}
