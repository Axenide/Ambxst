import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.globals
import qs.modules.services
import qs.config

Rectangle {
    id: root

    property string searchText: GlobalStates.launcherSearchText
    property bool showResults: searchText.length > 0
    property int selectedIndex: GlobalStates.launcherSelectedIndex
    signal itemSelected

    function clearSearch() {
        GlobalStates.clearLauncherState();
        searchInput.forceActiveFocus();
    }

    function focusSearchInput() {
        searchInput.forceActiveFocus();
    }

    implicitWidth: 500
    implicitHeight: mainLayout.implicitHeight
    color: "transparent"

    Behavior on height {
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
        Rectangle {
            id: searchInputContainer
            Layout.fillWidth: true
            implicitHeight: 48
            color: Colors.adapter.surfaceContainerHighest
            radius: Config.roundness > 0 ? Config.roundness + 4 : 0
            border.color: searchInput.activeFocus ? Colors.adapter.primary : Colors.adapter.outline
            border.width: 0

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                Text {
                    text: ""
                    font.family: Styling.defaultFont
                    font.pixelSize: 20
                    color: Colors.adapter.primary
                }

                TextField {
                    id: searchInput
                    Layout.fillWidth: true
                    text: GlobalStates.launcherSearchText
                    placeholderText: "Search applications..."
                    placeholderTextColor: Colors.adapter.outline
                    font.family: Styling.defaultFont
                    font.pixelSize: 14
                    color: Colors.adapter.overBackground
                    background: null

                    onTextChanged: {
                        GlobalStates.launcherSearchText = text;
                        root.searchText = text;
                        // Auto-highlight first app when text is entered
                        if (text.length > 0) {
                            GlobalStates.launcherSelectedIndex = 0;
                            root.selectedIndex = 0;
                            resultsList.currentIndex = 0;
                        } else {
                            GlobalStates.launcherSelectedIndex = -1;
                            root.selectedIndex = -1;
                            resultsList.currentIndex = -1;
                        }
                    }

                    onAccepted: {
                        if (root.selectedIndex >= 0 && root.selectedIndex < resultsList.count) {
                            let selectedApp = resultsList.model[root.selectedIndex];
                            if (selectedApp) {
                                selectedApp.execute();
                                root.itemSelected();
                            }
                        }
                    }

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            root.itemSelected();
                        } else if (event.key === Qt.Key_Down) {
                            if (resultsList.count > 0) {
                                if (root.selectedIndex < resultsList.count - 1) {
                                    GlobalStates.launcherSelectedIndex++;
                                    root.selectedIndex++;
                                    resultsList.currentIndex = root.selectedIndex;
                                } else if (root.selectedIndex === -1) {
                                    // When no search text and nothing selected, start at first item
                                    GlobalStates.launcherSelectedIndex = 0;
                                    root.selectedIndex = 0;
                                    resultsList.currentIndex = 0;
                                }
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            if (root.selectedIndex > 0) {
                                GlobalStates.launcherSelectedIndex--;
                                root.selectedIndex--;
                                resultsList.currentIndex = root.selectedIndex;
                            } else if (root.selectedIndex === 0 && root.searchText.length === 0) {
                                // When no search text, allow going back to no selection
                                GlobalStates.launcherSelectedIndex = -1;
                                root.selectedIndex = -1;
                                resultsList.currentIndex = -1;
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_PageDown) {
                            if (resultsList.count > 0) {
                                let visibleItems = Math.floor(resultsList.height / 48);
                                let newIndex = Math.min(root.selectedIndex + visibleItems, resultsList.count - 1);
                                if (root.selectedIndex === -1) {
                                    newIndex = Math.min(visibleItems - 1, resultsList.count - 1);
                                }
                                GlobalStates.launcherSelectedIndex = newIndex;
                                root.selectedIndex = newIndex;
                                resultsList.currentIndex = root.selectedIndex;
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_PageUp) {
                            if (resultsList.count > 0) {
                                let visibleItems = Math.floor(resultsList.height / 48);
                                let newIndex = Math.max(root.selectedIndex - visibleItems, 0);
                                if (root.selectedIndex === -1) {
                                    newIndex = Math.max(resultsList.count - visibleItems, 0);
                                }
                                GlobalStates.launcherSelectedIndex = newIndex;
                                root.selectedIndex = newIndex;
                                resultsList.currentIndex = root.selectedIndex;
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Home) {
                            if (resultsList.count > 0) {
                                GlobalStates.launcherSelectedIndex = 0;
                                root.selectedIndex = 0;
                                resultsList.currentIndex = 0;
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_End) {
                            if (resultsList.count > 0) {
                                GlobalStates.launcherSelectedIndex = resultsList.count - 1;
                                root.selectedIndex = resultsList.count - 1;
                                resultsList.currentIndex = root.selectedIndex;
                            }
                            event.accepted = true;
                        }
                    }
                }
            }
        }

        // Results list
        ListView {
            id: resultsList
            Layout.fillWidth: true
            Layout.preferredHeight: 5 * 48
            visible: true
            clip: true

            model: root.searchText.length > 0 ? AppSearch.fuzzyQuery(root.searchText) : AppSearch.getAllApps()
            currentIndex: root.selectedIndex

            // Sync currentIndex with selectedIndex
            onCurrentIndexChanged: {
                if (currentIndex !== root.selectedIndex) {
                    GlobalStates.launcherSelectedIndex = currentIndex;
                    root.selectedIndex = currentIndex;
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

                    onEntered: {
                        GlobalStates.launcherSelectedIndex = index;
                        root.selectedIndex = index;
                        resultsList.currentIndex = index;
                    }
                    onClicked: {
                        modelData.execute();
                        root.itemSelected();
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 12

                    Image {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        source: "image://icon/" + modelData.icon
                        fillMode: Image.PreserveAspectFit

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.color: Colors.adapter.outline
                            border.width: parent.status === Image.Error ? 1 : 0
                            radius: 4

                            Text {
                                anchors.centerIn: parent
                                text: "?"
                                visible: parent.parent.status === Image.Error
                                color: Colors.adapter.overBackground
                                font.family: Styling.defaultFont
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: modelData.name
                        color: Colors.adapter.overBackground
                        font.family: Styling.defaultFont
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                    }
                }
            }

            highlight: Rectangle {
                color: Colors.adapter.primary
                opacity: 0.2
                radius: Config.roundness > 0 ? Config.roundness + 4 : 0
                visible: root.selectedIndex >= 0
            }

            highlightMoveDuration: 150
            highlightMoveVelocity: -1
        }
    }

    Component.onCompleted: {
        // Only focus the input, don't clear the search on component creation
        // This allows state to persist when moving between monitors
        Qt.callLater(() => {
            focusSearchInput();
        });
    }
}
