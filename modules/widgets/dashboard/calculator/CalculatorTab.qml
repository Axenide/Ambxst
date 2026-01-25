import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.components
import qs.modules.globals
import qs.modules.services
import qs.config

Item {
    id: root
    focus: true

    // Prefix support
    property string prefixIcon: Icons.calculate
    signal backspaceOnEmpty

    property int leftPanelWidth: 0

    property string searchText: ""
    property string mathResult: ""
    property var history: []
    
    // Model for the ListView
    ListModel { id: resultsModel }

    function focusSearchInput() { searchInput.focusInput(); }

    // History management
    function loadHistory() {
        historyProcess.command = ["bash", "-c", "cat " + Quickshell.dataDir + "/calc_history.json 2>/dev/null || echo '[]'"];
        historyProcess.running = true;
    }

    function saveHistory() {
        var jsonData = JSON.stringify(history);
        saveProcess.command = ["bash", "-c", "echo '" + jsonData.replace(/'/g, "'\\''") + "' > " + Quickshell.dataDir + "/calc_history.json"];
        saveProcess.running = true;
    }

    function addToHistory(expression, result) {
        // Remove duplicate if exists
        history = history.filter(item => item.expression !== expression);
        // Add to top
        history.unshift({ expression: expression, result: result, timestamp: Date.now() });
        // Limit to 50
        if (history.length > 50) history = history.slice(0, 50);
        saveHistory();
        updateModel();
    }

    function updateModel() {
        resultsModel.clear();
        
        // Add current calculation result if any
        if (searchText.trim() !== "" && mathResult !== "") {
            resultsModel.append({
                type: "result",
                expression: searchText,
                result: mathResult,
                icon: "calculate"
            });
        }

        // Add history
        for (var i = 0; i < history.length; i++) {
             if (searchText === "" || history[i].expression.includes(searchText) || history[i].result.includes(searchText)) {
                 resultsModel.append({
                    type: "history",
                    expression: history[i].expression,
                    result: history[i].result,
                    icon: "history"
                 });
             }
        }

        // Auto-select first item
        if (resultsModel.count > 0) {
            resultList.currentIndex = 0;
        } else {
            resultList.currentIndex = -1;
        }
    }

    Process {
        id: mathProc
        property list<string> baseCommand: ["qalc", "-t"]
        function calculateExpression(expression) {
            if (expression.trim() === "") {
                root.mathResult = "";
                updateModel();
                return;
            }
            mathProc.command = baseCommand.concat(expression);
            mathProc.running = true;
        }
        stdout: SplitParser {
            onRead: data => {
                root.mathResult = data.trim();
                updateModel();
            }
        }
    }
    
    // Timer to debounce calculation
    Timer {
        id: calcTimer
        interval: 100 // Fast response
        repeat: false
        onTriggered: {
            mathProc.calculateExpression(root.searchText);
        }
    }

    onSearchTextChanged: {
        calcTimer.restart();
    }

    Process {
        id: historyProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    history = JSON.parse(text.trim());
                    updateModel();
                } catch (e) { history = []; }
            }
        }
    }

    Process { id: saveProcess }

    Component.onCompleted: {
        loadHistory();
        Qt.callLater(() => focusSearchInput());
    }

    Item {
        id: mainLayout
        anchors.fill: parent

        Row {
            id: searchRow
            width: parent.width
            height: 48
            anchors.top: parent.top
            spacing: 8

            SearchInput {
                id: searchInput
                width: parent.width
                height: 48
                text: root.searchText
                placeholderText: "Calculate..."
                prefixIcon: root.prefixIcon

                onSearchTextChanged: text => root.searchText = text
                onBackspaceOnEmpty: root.backspaceOnEmpty()
                onAccepted: {
                    if (resultList.count > 0 && resultList.currentIndex >= 0) {
                        let item = resultsModel.get(resultList.currentIndex);
                        if (item.type === "result") {
                            root.addToHistory(item.expression, item.result);
                            Visibilities.setActiveModule("");
                            ClipboardService.copy(item.result);
                        } else {
                            Visibilities.setActiveModule("");
                            ClipboardService.copy(item.result);
                        }
                    }
                }
                
                onDownPressed: {
                    if (resultList.count > 0) {
                        resultList.currentIndex = Math.min(resultList.currentIndex + 1, resultList.count - 1);
                    }
                }
                
                onUpPressed: {
                    if (resultList.count > 0) {
                        resultList.currentIndex = Math.max(resultList.currentIndex - 1, 0);
                    }
                }
            }
        }

        ListView {
            id: resultList
            width: parent.width
            anchors.top: searchRow.bottom
            anchors.bottom: parent.bottom
            anchors.topMargin: 8
            clip: true
            model: resultsModel
            spacing: 4
            currentIndex: -1

            highlight: StyledRect {
                variant: "primary"
                radius: Styling.radius(4)
                visible: resultList.currentIndex >= 0
                z: -1
                
                Behavior on opacity { NumberAnimation { duration: 150 } }
                Behavior on y { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            }
            highlightFollowsCurrentItem: true
            highlightMoveDuration: 150

            delegate: Rectangle {
                id: delegateRoot
                width: resultList.width
                height: 48
                color: "transparent"
                radius: Styling.radius(4)
                
                property bool isHovered: false
                property bool isSelected: ListView.isCurrentItem
                property color dynamicTextColor: (isHovered || isSelected) ? Colors.overPrimary : Colors.overBackground

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: {
                        parent.isHovered = true;
                        resultList.currentIndex = index;
                    }
                    onExited: parent.isHovered = false
                    onClicked: {
                        ClipboardService.copy(model.result);
                        Visibilities.setActiveModule("");
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 12
                    
                    // Icon container
                    Item {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        
                        Text {
                            anchors.centerIn: parent
                            text: model.icon === "calculate" ? Icons.calculate : Icons.history
                            font.family: Icons.font
                            font.pixelSize: 20
                            color: delegateRoot.dynamicTextColor
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: model.expression
                            font.family: Config.theme.font
                            font.pixelSize: Config.theme.fontSize * 0.9
                            color: delegateRoot.dynamicTextColor
                            opacity: 0.7
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: "= " + model.result
                            font.family: Config.theme.font
                            font.weight: Font.Bold
                            font.pixelSize: Config.theme.fontSize
                            color: delegateRoot.dynamicTextColor
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
