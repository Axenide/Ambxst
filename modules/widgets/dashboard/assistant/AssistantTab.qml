import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.config
import qs.modules.components
import qs.modules.services

Item {
    id: root
    implicitWidth: 800
    implicitHeight: 600
    
    // State
    property bool sidebarExpanded: false
    property real sidebarWidth: 250
    
    // Sidebar Animation
    Behavior on sidebarExpanded {
        NumberAnimation { duration: Config.animDuration; easing.type: Easing.OutCubic }
    }
    
    RowLayout {
        anchors.fill: parent
        spacing: 0
        
        // ============================================
        // SIDEBAR
        // ============================================
        Item {
            id: sidebar
            Layout.fillHeight: true
            Layout.preferredWidth: root.sidebarExpanded ? root.sidebarWidth : 56
            Layout.maximumWidth: root.sidebarWidth
            Layout.minimumWidth: 56
            clip: true
            
            Behavior on Layout.preferredWidth {
                NumberAnimation { duration: Config.animDuration; easing.type: Easing.OutCubic }
            }
            
            StyledRect {
                anchors.fill: parent
                anchors.margins: 4
                variant: "pane"
                radius: root.sidebarExpanded ? Styling.radius(8) : Styling.radius(0)
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 4

                    // Toggle Button
                    Button {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        flat: true
                        leftPadding: 0
                        rightPadding: 0
                        
                        contentItem: RowLayout {
                            anchors.fill: parent
                            spacing: 0
                            
                            Item {
                                Layout.preferredWidth: 40
                                Layout.fillHeight: true
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: Icons.list
                                    font.family: Icons.font
                                    font.pixelSize: 18
                                    color: Colors.overSurface
                                }
                            }
                            
                            Text {
                                text: "Menu"
                                color: Colors.overSurface
                                font.family: Config.theme.font
                                font.pixelSize: 14
                                visible: root.sidebarExpanded
                                opacity: root.sidebarExpanded ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 200 } }
                                Layout.fillWidth: true
                            }
                        }
                        
                        background: StyledRect {
                            variant: "focus"
                            radius: root.sidebarExpanded ? Styling.radius(4) : Styling.radius(-4)
                            opacity: parent.hovered ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Config.animDuration / 4 } }
                        }
                        
                        onClicked: root.sidebarExpanded = !root.sidebarExpanded
                    }

                    // New Chat
                    Button {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        flat: true
                        leftPadding: 0
                        rightPadding: 0
                        
                        contentItem: RowLayout {
                            anchors.fill: parent
                            spacing: 0
                            
                            Item {
                                Layout.preferredWidth: 40
                                Layout.fillHeight: true
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: Icons.edit
                                    font.family: Icons.font
                                    font.pixelSize: 18
                                    color: Colors.primary
                                }
                            }
                            
                            Text {
                                text: "New Chat"
                                color: Colors.overSurface
                                font.family: Config.theme.font
                                font.pixelSize: 14
                                visible: root.sidebarExpanded
                                opacity: root.sidebarExpanded ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 200 } }
                                Layout.fillWidth: true
                            }
                        }
                        
                        background: StyledRect {
                            variant: "focus"
                            radius: root.sidebarExpanded ? Styling.radius(4) : Styling.radius(-4)
                            opacity: parent.hovered ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Config.animDuration / 4 } }
                        }
                        
                        onClicked: {
                            Ai.createNewChat();
                            if (root.sidebarExpanded && root.implicitWidth < 800) root.sidebarExpanded = false; 
                        }
                    }
                    
                    Separator {
                        Layout.fillWidth: true
                        vert: false
                        visible: root.sidebarExpanded
                    }
                    
                    // History List (Visible only when expanded)
                    ListView {
                        id: historyList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        visible: root.sidebarExpanded
                        opacity: root.sidebarExpanded ? 1 : 0
                        
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                        
                        model: Ai.chatHistory
                        spacing: 4
                        
                        delegate: Button {
                            width: historyList.width
                            height: 36
                            flat: true
                            
                            contentItem: RowLayout {
                                anchors.fill: parent
                                spacing: 4
                                
                                Text {
                                    text: {
                                        let date = new Date(parseInt(modelData.id));
                                        return date.toLocaleString(Qt.locale(), "MM-dd hh:mm");
                                    }
                                    color: Ai.currentChatId === modelData.id ? Colors.primary : Colors.overSurface
                                    font.family: Config.theme.font
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    Layout.leftMargin: 8
                                    verticalAlignment: Text.AlignVCenter
                                }
                                
                                Button {
                                    visible: parent.parent.hovered
                                    flat: true
                                    Layout.preferredWidth: 24
                                    Layout.preferredHeight: 24
                                    Layout.rightMargin: 4
                                    
                                    contentItem: Text {
                                        text: Icons.trash
                                        font.family: Icons.font
                                        color: parent.hovered ? Colors.error : Colors.surfaceDim
                                        font.pixelSize: 12
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    
                                    background: null
                                    onClicked: Ai.deleteChat(modelData.id)
                                }
                            }
                            
                            background: StyledRect {
                                variant: Ai.currentChatId === modelData.id ? "focus" : "transparent"
                                radius: Styling.radius(4)
                                border.width: 0 
                            }
                            
                            onClicked: {
                                Ai.loadChat(modelData.id);
                            }
                        }
                    }

                    Item { Layout.fillHeight: true; visible: !root.sidebarExpanded } // Spacer when contracted

                     // Settings (Bottom)
                    Button {
                        Layout.alignment: Qt.AlignBottom
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        flat: true
                        leftPadding: 0
                        rightPadding: 0
                        
                        contentItem: RowLayout {
                            anchors.fill: parent
                            spacing: 0
                            
                            Item {
                                Layout.preferredWidth: 40
                                Layout.fillHeight: true
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: Icons.dotsThree
                                    font.family: Icons.font
                                    font.pixelSize: 18
                                    color: Colors.overSurface
                                }
                            }
                            
                            Text {
                                text: "Settings"
                                color: Colors.overSurface
                                font.family: Config.theme.font
                                font.pixelSize: 14
                                visible: root.sidebarExpanded
                                opacity: root.sidebarExpanded ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 200 } }
                                Layout.fillWidth: true
                            }
                        }
                        
                        background: StyledRect {
                            variant: "focus"
                            radius: root.sidebarExpanded ? Styling.radius(4) : Styling.radius(-4)
                            opacity: parent.hovered ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Config.animDuration / 4 } }
                        }
                        
                        // onClicked: openSettings() // Future
                    }
                }
            }
        }
        
        // ============================================
        // MAIN CHAT AREA
        // ============================================
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            
            ColumnLayout {
                anchors.fill: parent
                spacing: 8
                
                // Header
                RowLayout {
                    Layout.fillWidth: true
                    height: 40
                    
                // Hamburger menu moved to sidebar

                    
                    Text {
                        text: Ai.currentModel.name
                        color: Colors.overBackground
                        font.family: Config.theme.font
                        font.pixelSize: 16
                        font.weight: Font.Bold
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                        visible: false // Moved to typing indicator in footer
                }
                
                // Messages
                ListView {
                    id: chatView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: Ai.currentChat
                    spacing: 16
                    displayMarginBeginning: 40
                    displayMarginEnd: 40
                    
                    // Auto scroll to bottom
                    onCountChanged: {
                        Qt.callLater(() => {
                            positionViewAtEnd();
                        });
                    }
                    
                    delegate: Item {
                        width: chatView.width
                        height: bubble.height + 20
                        
                        property bool isUser: modelData.role === "user"
                        property bool isSystem: modelData.role === "system"
                        
                        Row {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: 10
                            layoutDirection: (isUser && !isSystem) ? Qt.RightToLeft : Qt.LeftToRight
                            spacing: 12
                            
                            // Icon
                            Rectangle {
                                width: 32
                                height: 32
                                radius: 16
                                color: isSystem ? Colors.surfaceDim : (isUser ? Colors.primary : Colors.secondary)
                                visible: !isSystem
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: isUser ? Icons.user : Icons.assistant
                                    font.family: Icons.font
                                    color: isUser ? Colors.overPrimary : Colors.overSecondary
                                }
                            }
                            
                            // Bubble
                            StyledRect {
                                id: bubble
                                variant: isSystem ? "surface" : (isUser ? "primaryContainer" : "surfaceVariant")
                                radius: Styling.radius(12)
                                border.width: isSystem ? 1 : 0
                                border.color: Colors.surfaceDim
                                
                                // Auto-sizing logic
                                width: Math.min(Math.max(msgContent.implicitWidth + 24, 100), chatView.width * (isSystem ? 0.9 : 0.7))
                                height: msgContent.implicitHeight + 24
                                
                                TextEdit {
                                    id: msgContent
                                    anchors.centerIn: parent
                                    width: parent.width - 24
                                    text: modelData.content
                                    textFormat: Text.MarkdownText
                                    color: isSystem ? Colors.outline : (isUser ? Colors.overPrimaryContainer : Colors.overSurfaceVariant)
                                    font.family: Config.theme.font
                                    font.pixelSize: 14
                                    wrapMode: Text.Wrap
                                    readOnly: true
                                    selectByMouse: true
                                    
                                    // Markdown styling overrides if needed could go here
                                }
                            }
                        }
                    }
                    
                    footer: Item {
                        width: chatView.width
                        height: 40
                        visible: Ai.isLoading
                        
                        Row {
                            anchors.centerIn: parent
                            spacing: 4
                            
                            Repeater {
                                model: 3
                                Rectangle {
                                    width: 8; height: 8; radius: 4
                                    color: Colors.primary
                                    opacity: 0.5
                                    
                                    SequentialAnimation on opacity {
                                        loops: Animation.Infinite
                                        running: Ai.isLoading
                                        PropertyAnimation { to: 1; duration: 400 }
                                        PropertyAnimation { to: 0.5; duration: 400 }
                                        PauseAnimation { duration: 200 }
                                    }
                                    
                                    // Stagger animations
                                    Component.onCompleted: {
                                        if (index === 1) animation.startDelay = 200
                                        if (index === 2) animation.startDelay = 400
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Input Area
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(150, Math.max(48, inputField.contentHeight + 24))
                    Layout.margins: 10
                    
                    StyledRect {
                        anchors.fill: parent
                        variant: "pane"
                        radius: Styling.radius(4)
                        enableShadow: true
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            anchors.leftMargin: 16
                            anchors.rightMargin: 8
                            
                            ScrollView {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                
                                TextArea {
                                    id: inputField
                                    placeholderText: "Ask AI or type /help..."
                                    placeholderTextColor: Colors.outline
                                    color: Colors.overBackground
                                    font.family: Config.theme.font
                                    font.pixelSize: 15
                                    wrapMode: Text.Wrap
                                    background: null
                                    selectByMouse: true
                                    verticalAlignment: Text.AlignVCenter
                                    
                                    Keys.onPressed: event => {
                                        if (event.key === Qt.Key_Return && !(event.modifiers & Qt.ShiftModifier)) {
                                            event.accepted = true;
                                            if (inputField.text.trim() !== "") {
                                                Ai.sendMessage(inputField.text);
                                                inputField.text = "";
                                            }
                                        }
                                        // History navigation could go here (up/down)
                                    }
                                }
                            }
                            
                            Button {
                                Layout.alignment: Qt.AlignBottom
                                flat: true
                                width: 44
                                height: 44
                                enabled: !Ai.isLoading && inputField.text.trim() !== ""
                                
                                contentItem: Text {
                                    text: Icons.arrowRight
                                    font.family: Icons.font
                                    font.pixelSize: 20
                                    color: enabled ? Colors.primary : Colors.surfaceDim
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                
                                background: Rectangle {
                                    color: parent.hovered && enabled ? Colors.surfaceBright : "transparent"
                                    radius: 22
                                }
                                
                                onClicked: {
                                    Ai.sendMessage(inputField.text);
                                    inputField.text = "";
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}