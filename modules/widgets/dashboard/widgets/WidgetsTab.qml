import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.globals
import qs.config
import "calendar"

Rectangle {
    color: "transparent"
    implicitWidth: 600
    implicitHeight: 300

    // Function to focus app search when tab becomes active
    function focusAppSearch() {
        if (appLauncherItem && appLauncherItem.focusSearchInput) {
            appLauncherItem.focusSearchInput();
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 8

        // App Launcher (primera columna) - Inline desde LauncherAppsTab
        Rectangle {
            id: appLauncherItem
            Layout.fillWidth: true
            Layout.fillHeight: true

            property string searchText: GlobalStates.launcherSearchText
            property bool showResults: searchText.length > 0
            property int selectedIndex: GlobalStates.launcherSelectedIndex
            property bool optionsMenuOpen: false
            property int menuItemIndex: -1
            property bool menuJustClosed: false

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

            implicitWidth: 400
            implicitHeight: mainLayout.implicitHeight
            color: "transparent"

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
                        appLauncherItem.searchText = text;
                        if (text.length > 0) {
                            GlobalStates.launcherSelectedIndex = 0;
                            appLauncherItem.selectedIndex = 0;
                            resultsList.currentIndex = 0;
                        } else {
                            GlobalStates.launcherSelectedIndex = -1;
                            appLauncherItem.selectedIndex = -1;
                            resultsList.currentIndex = -1;
                        }
                    }

                    onAccepted: {
                        if (appLauncherItem.selectedIndex >= 0 && appLauncherItem.selectedIndex < resultsList.count) {
                            let selectedApp = resultsList.model[appLauncherItem.selectedIndex];
                            if (selectedApp) {
                                selectedApp.execute();
                                Visibilities.setActiveModule("");
                            }
                        }
                    }

                    onEscapePressed: {
                        // Cerrar el dashboard
                        Visibilities.setActiveModule("");
                    }

                    onDownPressed: {
                        if (resultsList.count > 0) {
                            if (appLauncherItem.selectedIndex === -1) {
                                GlobalStates.launcherSelectedIndex = 0;
                                appLauncherItem.selectedIndex = 0;
                                resultsList.currentIndex = 0;
                            } else if (appLauncherItem.selectedIndex < resultsList.count - 1) {
                                GlobalStates.launcherSelectedIndex++;
                                appLauncherItem.selectedIndex++;
                                resultsList.currentIndex = appLauncherItem.selectedIndex;
                            }
                        }
                    }

                    onUpPressed: {
                        if (appLauncherItem.selectedIndex > 0) {
                            GlobalStates.launcherSelectedIndex--;
                            appLauncherItem.selectedIndex--;
                            resultsList.currentIndex = appLauncherItem.selectedIndex;
                        } else if (appLauncherItem.selectedIndex === 0 && appLauncherItem.searchText.length === 0) {
                            GlobalStates.launcherSelectedIndex = -1;
                            appLauncherItem.selectedIndex = -1;
                            resultsList.currentIndex = -1;
                        }
                    }

                    onPageDownPressed: {
                        if (resultsList.count > 0) {
                            let visibleItems = Math.floor(resultsList.height / 48);
                            let newIndex = Math.min(appLauncherItem.selectedIndex + visibleItems, resultsList.count - 1);
                            if (appLauncherItem.selectedIndex === -1) {
                                newIndex = Math.min(visibleItems - 1, resultsList.count - 1);
                            }
                            GlobalStates.launcherSelectedIndex = newIndex;
                            appLauncherItem.selectedIndex = newIndex;
                            resultsList.currentIndex = appLauncherItem.selectedIndex;
                        }
                    }

                    onPageUpPressed: {
                        if (resultsList.count > 0) {
                            let visibleItems = Math.floor(resultsList.height / 48);
                            let newIndex = Math.max(appLauncherItem.selectedIndex - visibleItems, 0);
                            if (appLauncherItem.selectedIndex === -1) {
                                newIndex = Math.max(resultsList.count - visibleItems, 0);
                            }
                            GlobalStates.launcherSelectedIndex = newIndex;
                            appLauncherItem.selectedIndex = newIndex;
                            resultsList.currentIndex = appLauncherItem.selectedIndex;
                        }
                    }

                    onHomePressed: {
                        if (resultsList.count > 0) {
                            GlobalStates.launcherSelectedIndex = 0;
                            appLauncherItem.selectedIndex = 0;
                            resultsList.currentIndex = 0;
                        }
                    }

                    onEndPressed: {
                        if (resultsList.count > 0) {
                            GlobalStates.launcherSelectedIndex = resultsList.count - 1;
                            appLauncherItem.selectedIndex = resultsList.count - 1;
                            resultsList.currentIndex = appLauncherItem.selectedIndex;
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
                    interactive: !appLauncherItem.optionsMenuOpen
                    cacheBuffer: 96
                    reuseItems: true

                    model: appLauncherItem.searchText.length > 0 ? AppSearch.fuzzyQuery(appLauncherItem.searchText) : AppSearch.getAllApps()
                    currentIndex: appLauncherItem.selectedIndex

                    onCurrentIndexChanged: {
                        if (currentIndex !== appLauncherItem.selectedIndex) {
                            GlobalStates.launcherSelectedIndex = currentIndex;
                            appLauncherItem.selectedIndex = currentIndex;
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
                                if (!appLauncherItem.optionsMenuOpen) {
                                    GlobalStates.launcherSelectedIndex = index;
                                    appLauncherItem.selectedIndex = index;
                                    resultsList.currentIndex = index;
                                }
                            }
                            onClicked: mouse => {
                                if (appLauncherItem.menuJustClosed) {
                                    return;
                                }

                                if (mouse.button === Qt.LeftButton) {
                                    modelData.execute();
                                    Visibilities.setActiveModule("");
                                } else if (mouse.button === Qt.RightButton) {
                                    appLauncherItem.menuItemIndex = index;
                                    appLauncherItem.optionsMenuOpen = true;
                                    contextMenu.popup(mouse.x, mouse.y);
                                }
                            }

                            OptionsMenu {
                                id: contextMenu

                                onClosed: {
                                    appLauncherItem.optionsMenuOpen = false;
                                    appLauncherItem.menuItemIndex = -1;
                                    appLauncherItem.menuJustClosed = true;
                                    menuClosedTimer.start();
                                }

                                Timer {
                                    id: menuClosedTimer
                                    interval: 100
                                    repeat: false
                                    onTriggered: {
                                        appLauncherItem.menuJustClosed = false;
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
                                            
                                            let desktopContent = "[Desktop Entry]\n" +
                                                "Version=1.0\n" +
                                                "Type=Application\n" +
                                                "Name=" + modelData.name + "\n" +
                                                "Exec=" + modelData.execString + "\n" +
                                                "Icon=" + modelData.icon + "\n" +
                                                (modelData.comment ? "Comment=" + modelData.comment + "\n" : "") +
                                                (modelData.categories.length > 0 ? "Categories=" + modelData.categories.join(";") + ";\n" : "") +
                                                (modelData.runInTerminal ? "Terminal=true\n" : "Terminal=false\n");
                                            
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
                                    color: appLauncherItem.selectedIndex === index ? Colors.overPrimary : Colors.overBackground
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
                                    color: appLauncherItem.selectedIndex === index ? Colors.overPrimary : Colors.outline
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
                        visible: appLauncherItem.selectedIndex >= 0 && (appLauncherItem.optionsMenuOpen ? appLauncherItem.selectedIndex === appLauncherItem.menuItemIndex : true)
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

                onExited: function (code) {
                    // No cerrar el dashboard después de crear shortcut
                }
            }
        }

        // Separator
        Separator {
            Layout.preferredWidth: 2
            Layout.fillHeight: true
            vert: true
            gradient: null
            color: Colors.surface
        }

        ClippingRectangle {
            Layout.fillWidth: false
            Layout.preferredWidth: {
                var gridRows = 3;
                var gridColumns = 5;
                var wallpaperHeight = (parent.height + 4 * 2) / gridRows;
                return (wallpaperHeight * gridColumns) - 8;
            }
            Layout.fillHeight: true
            radius: Config.roundness > 0 ? Config.roundness + 4 : 0

            color: "transparent"

            Flickable {
                anchors.fill: parent
                contentWidth: width
                contentHeight: columnLayout.implicitHeight
                clip: true

                ColumnLayout {
                    id: columnLayout
                    width: parent.width
                    spacing: 8

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

        NotificationHistory {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }

    Component.onCompleted: {
        Qt.callLater(focusAppSearch);
    }
}
