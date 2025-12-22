import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Widgets
import qs.modules.theme
import qs.config
import qs.modules.services
import qs.modules.components

Popup {
    id: root
    
    width: 400
    // Height: Header (48) + Spacing (12) + List (5 * 48 = 240) + Padding (8*2)
    height: contentItem.implicitHeight + padding * 2
    padding: 16
    
    // Center in parent
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2
    
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    
    onOpened: {
        searchInput.focusInput();
        updateFilteredModels();
    }

    // Initialize fetching if empty (e.g. first run)
    Component.onCompleted: {
        if (Ai.models.length === 0) {
            Ai.fetchAvailableModels();
        }
    }

    property int selectedIndex: -1  // Start with no selection like App Launcher
    property var filteredModels: []
    
    function updateFilteredModels() {
        let text = searchInput.text.toLowerCase();
        let allModels = [];
        for(let i=0; i<Ai.models.length; i++) {
            allModels.push(Ai.models[i]);
        }
        
        if (text.trim() === "") {
            filteredModels = allModels;
        } else {
            filteredModels = allModels.filter(m => 
                m.name.toLowerCase().includes(text) || 
                m.api_format.toLowerCase().includes(text) ||
                m.model.toLowerCase().includes(text)
            );
        }
        
        // Reset selection if out of bounds
        if (selectedIndex >= filteredModels.length) {
            selectedIndex = Math.max(0, filteredModels.length - 1);
        }
        
        // Reset selection to -1 (no selection) when filter changes
        selectedIndex = -1;
        modelList.currentIndex = -1;
    }

    background: StyledRect {
        variant: "popup"
        radius: Styling.radius(20)
    }
    
    contentItem: ColumnLayout {
        spacing: 12
        
        // Search Header
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            spacing: 8
            
            SearchInput {
                id: searchInput
                Layout.fillWidth: true
                placeholderText: "Search models..."
                iconText: "" // Removed icon as requested
                
                onSearchTextChanged: text => {
                    root.updateFilteredModels();
                }
                
                onDownPressed: {
                    if (root.filteredModels.length > 0) {
                        if (root.selectedIndex < root.filteredModels.length - 1) {
                            root.selectedIndex++;
                        } else if (root.selectedIndex === -1) {
                            root.selectedIndex = 0;
                        }
                        modelList.currentIndex = root.selectedIndex;
                    }
                }
                
                onUpPressed: {
                    if (root.selectedIndex > 0) {
                        root.selectedIndex--;
                        modelList.currentIndex = root.selectedIndex;
                    } else if (root.selectedIndex === -1 && root.filteredModels.length > 0) {
                        root.selectedIndex = root.filteredModels.length - 1;
                        modelList.currentIndex = root.selectedIndex;
                    }
                }
                
                onAccepted: {
                    if (root.filteredModels.length > 0 && root.selectedIndex >= 0) {
                         let m = root.filteredModels[root.selectedIndex];
                         Ai.setModel(m.name);
                         root.close();
                    }
                }
                
                onEscapePressed: {
                    root.close();
                }
            }
            
            // Refresh Button (Icon only)
            // Refresh Button (Interactive)
            Button {
                id: refreshBtn
                
                property bool confirming: false
                
                // Reset state when focus is lost
                onActiveFocusChanged: {
                    if (!activeFocus && confirming) {
                        confirming = false;
                    }
                }
                
                Layout.preferredWidth: confirming ? 112 : 48
                Layout.preferredHeight: 48
                
                Behavior on Layout.preferredWidth {
                    enabled: Config.animDuration > 0
                    NumberAnimation { duration: Config.animDuration; easing.type: Easing.OutCubic }
                }
                
                flat: true
                padding: 0
                
                // Allow focus via Tab
                activeFocusOnTab: true
                
                contentItem: RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8
                    
                    // Icon (Left Aligned)
                    Item {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        Layout.alignment: Qt.AlignVCenter
                        
                        Text {
                            anchors.centerIn: parent
                            text: Ai.fetchingModels ? Icons.circleNotch : (refreshBtn.confirming ? Icons.sync : Icons.arrowCounterClockwise)
                            font.family: Icons.font
                            font.pixelSize: 20
                            color: refreshBtn.confirming ? Config.resolveColor(Config.theme.srPrimary.itemColor) : Colors.primary
                            
                            RotationAnimation on rotation {
                                loops: Animation.Infinite
                                from: 0; to: 360
                                duration: 1000
                                running: Ai.fetchingModels
                                onRunningChanged: {
                                    if (!running) {
                                        parent.rotation = 0;
                                    }
                                }
                            }
                            
                            Behavior on color {
                                enabled: Config.animDuration > 0
                                ColorAnimation { duration: Config.animDuration / 2 }
                            }
                        }
                    }
                    
                    // Text Reveal (Right)
                    Text {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        verticalAlignment: Text.AlignVCenter
                        text: "Refresh?"
                        font.family: Config.theme.font
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        color: Config.resolveColor(Config.theme.srPrimary.itemColor)
                        
                        opacity: refreshBtn.confirming ? 1 : 0
                        visible: opacity > 0
                        
                        Behavior on opacity {
                            enabled: Config.animDuration > 0
                            NumberAnimation { duration: Config.animDuration / 2 }
                        }
                    }
                }
                
                background: StyledRect {
                    variant: parent.confirming ? "primary" : (parent.hovered || parent.activeFocus ? "focus" : "pane")
                    radius: Styling.radius(4)
                    
                    Behavior on color {
                        enabled: Config.animDuration > 0
                        ColorAnimation { duration: Config.animDuration / 2 }
                    }
                }
                
                onClicked: {
                    if (!confirming) {
                        confirming = true;
                    } else {
                        Ai.fetchAvailableModels();
                        confirming = false;
                    }
                }
                
                Keys.onReturnPressed: clicked()
                Keys.onEnterPressed: clicked()
                Keys.onEscapePressed: {
                    event.accepted = true;
                    // Focus back to search (losing focus will auto-collapse confirming state)
                    searchInput.focusInput();
                }
            }
        }
        
        // Model List
        ListView {
            id: modelList
            Layout.fillWidth: true
            // Limit height to 5 items (5 * 48 = 240)
            Layout.preferredHeight: Math.min(contentHeight, 240)
            clip: true
            
            model: root.filteredModels
            
            property bool enableScrollAnimation: true
            
            Behavior on contentY {
                enabled: Config.animDuration > 0 && modelList.enableScrollAnimation && !modelList.moving
                NumberAnimation {
                    duration: Config.animDuration / 2
                    easing.type: Easing.OutCubic
                }
            }
            
            // Handle smooth auto-scroll on index change
            onCurrentIndexChanged: {
                if (currentIndex >= 0) {
                    let itemY = currentIndex * 48;
                    let itemHeight = 48;
                    let viewportTop = contentY;
                    let viewportBottom = viewportTop + height;
                    
                    if (itemY < viewportTop) {
                        // Item above viewport, scroll up
                        contentY = itemY;
                    } else if (itemY + itemHeight > viewportBottom) {
                        // Item below viewport, scroll down
                        contentY = itemY + itemHeight - height;
                    }
                }
            }
            
            // Highlight component - matches App Launcher pattern
            highlight: Item {
                width: modelList.width
                height: 48
                
                // Calculate Y position based on index (all items have same height)
                y: modelList.currentIndex >= 0 ? modelList.currentIndex * 48 : 0
                
                Behavior on y {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration / 2
                        easing.type: Easing.OutCubic
                    }
                }
                
                StyledRect {
                    anchors.fill: parent
                    variant: "primary"
                    radius: Styling.radius(4)
                    visible: modelList.currentIndex >= 0
                }
            }
            highlightFollowsCurrentItem: false
            
            delegate: Button {
                id: delegateBtn
                width: modelList.width
                height: 48
                flat: true
                leftPadding: 8
                rightPadding: 8
                
                // Controlled by ListView's currentIndex via root.selectedIndex
                property bool isSelected: ListView.isCurrentItem
                property bool isActiveModel: Ai.currentModel.name === modelData.name

                contentItem: RowLayout {
                    anchors.fill: parent
                    spacing: 12
                    
                    // Icon
                    Item {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        Layout.alignment: Qt.AlignVCenter
                        
                        Text {
                            anchors.centerIn: parent
                            text: {
                                switch(modelData.icon) {
                                    case "sparkles": return Icons.sparkle;
                                    case "openai": return Icons.lightning;
                                    case "wind": return Icons.sparkle; 
                                    default: return Icons.robot;
                                }
                            }
                            font.family: Icons.font
                            font.pixelSize: 20
                            // Logic: Text becomes white (overPrimary) when selected (because highlight is primary), 
                            // otherwise uses standard colors.
                            color: delegateBtn.isSelected ? Config.resolveColor(Config.theme.srPrimary.itemColor) : (delegateBtn.isActiveModel ? Colors.primary : Colors.overSurface)
                            
                            Behavior on color {
                                enabled: Config.animDuration > 0
                                ColorAnimation { duration: Config.animDuration / 2; easing.type: Easing.OutCubic }
                            }
                        }
                    }
                    
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2
                        
                        Text {
                            text: modelData.name
                            color: delegateBtn.isSelected ? Config.resolveColor(Config.theme.srPrimary.itemColor) : (delegateBtn.isActiveModel ? Colors.primary : Colors.overBackground)
                            font.family: Config.theme.font
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            
                            Behavior on color {
                                enabled: Config.animDuration > 0
                                ColorAnimation { duration: Config.animDuration / 2; easing.type: Easing.OutCubic }
                            }
                        }
                        
                        Text {
                            // Show provider and model ID
                            text: modelData.api_format.toUpperCase() + " • " + modelData.model
                            color: delegateBtn.isSelected ? Config.resolveColor(Config.theme.srPrimary.itemColor) : Colors.outline
                            font.family: Config.theme.font
                            font.pixelSize: 11
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            
                            Behavior on color {
                                enabled: Config.animDuration > 0
                                ColorAnimation { duration: Config.animDuration / 2; easing.type: Easing.OutCubic }
                            }
                        }
                    }
                    
                    // Active Check
                    Text {
                        text: Icons.accept
                        font.family: Icons.font
                        font.pixelSize: 16
                        Layout.alignment: Qt.AlignVCenter
                        // On primary highlight, color should be readable. srPrimary itemColor usually contrasts well.
                        color: delegateBtn.isSelected ? Config.resolveColor(Config.theme.srPrimary.itemColor) : Colors.primary
                        visible: delegateBtn.isActiveModel
                        
                        Behavior on color {
                            enabled: Config.animDuration > 0
                            ColorAnimation { duration: Config.animDuration / 2; easing.type: Easing.OutCubic }
                        }
                    }
                }
                
                background: Item {
                   // Background handled by ListView highlight
                   // We keep this empty or transparent
                }
                
                onClicked: {
                    Ai.setModel(modelData.name);
                    root.close();
                }
                
                // Mouse hover updates selection
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: {
                        root.selectedIndex = index;
                        modelList.currentIndex = index;
                    }
                    propagateComposedEvents: true
                    onClicked: mouse => mouse.accepted = false // Pass to Button
                }
            }
        }
    }
}
