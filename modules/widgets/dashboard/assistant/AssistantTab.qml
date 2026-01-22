import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Widgets
import qs.modules.theme
import qs.config
import qs.modules.components
import qs.modules.services
import Quickshell
import Quickshell.Io

Item {
    id: root
    implicitWidth: 800
    implicitHeight: 600

    property bool sidebarExpanded: false
    property real sidebarWidth: 250
    property var slashCommands: [
        {
            name: "model",
            description: "Switch AI model"
        },
        {
            name: "help",
            description: "Show help"
        },
        {
            name: "new",
            description: "Start new chat"
        },
        {
            name: "key",
            description: "Set API key"
        },
        {
            name: "prompt",
            description: "Set system prompt"
        }
    ]

    // Focus Input function for external calls (Dashboard)
    function focusSearchInput() {
        inputField.forceActiveFocus();
    }

    // Auto-focus when tab becomes visible
    onVisibleChanged: {
        if (visible) {
            // Use a small timer to ensure layout is ready
            Qt.callLater(() => {
                focusSearchInput();
            });
        }
    }

    // Sidebar Animation
    Behavior on sidebarExpanded {
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutCubic
        }
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
                NumberAnimation {
                    duration: Config.animDuration
                    easing.type: Easing.OutCubic
                }
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
                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 200
                                    }
                                }
                                Layout.fillWidth: true
                            }
                        }

                        background: StyledRect {
                            variant: "focus"
                            radius: root.sidebarExpanded ? Styling.radius(4) : Styling.radius(-4)
                            opacity: parent.hovered ? 1 : 0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Config.animDuration / 4
                                }
                            }
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
                                    color: Styling.srItem("overprimary")
                                }
                            }

                            Text {
                                text: "New Chat"
                                color: Colors.overSurface
                                font.family: Config.theme.font
                                font.pixelSize: 14
                                visible: root.sidebarExpanded
                                opacity: root.sidebarExpanded ? 1 : 0
                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 200
                                    }
                                }
                                Layout.fillWidth: true
                            }
                        }

                        background: StyledRect {
                            variant: "focus"
                            radius: root.sidebarExpanded ? Styling.radius(4) : Styling.radius(-4)
                            opacity: parent.hovered ? 1 : 0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Config.animDuration / 4
                                }
                            }
                        }

                        onClicked: {
                            Ai.createNewChat();
                            if (root.sidebarExpanded && root.implicitWidth < 800)
                                root.sidebarExpanded = false;
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

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 200
                            }
                        }

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
                                    color: Ai.currentChatId === modelData.id ? Styling.srItem("overprimary") : Colors.overSurface
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

                    Item {
                        Layout.fillHeight: true
                        visible: !root.sidebarExpanded
                    } // Spacer when contracted

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
                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 200
                                    }
                                }
                                Layout.fillWidth: true
                            }
                        }

                        background: StyledRect {
                            variant: "focus"
                            radius: root.sidebarExpanded ? Styling.radius(4) : Styling.radius(-4)
                            opacity: parent.hovered ? 1 : 0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Config.animDuration / 4
                                }
                            }
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
            id: mainChatArea
            Layout.fillWidth: true
            Layout.fillHeight: true

            property int retryIndex: -1 // Track which message is being retried
            property string username: ""

            Process {
                running: true
                command: ["whoami"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let user = text.trim();
                        if (user) {
                            mainChatArea.username = user.charAt(0).toUpperCase() + user.slice(1);
                        }
                    }
                }
            }
            property bool isWelcome: Ai.currentChat.length === 0

            // Welcome Screen
            ColumnLayout {
                anchors.centerIn: parent
                // Offset slightly up to make room for centered input
                anchors.verticalCenterOffset: -50
                visible: mainChatArea.isWelcome
                spacing: 8

                Text {
                    text: "Hello, <font color='" + Styling.srItem("overprimary") + "'>" + mainChatArea.username + "</font>."
                    font.family: Config.theme.font
                    font.pixelSize: 32
                    font.weight: Font.Bold
                    textFormat: Text.StyledText
                    Layout.alignment: Qt.AlignHCenter
                    color: Colors.overBackground
                }

                // Simplified Gradient Text using standard coloring for now to avoid complexity without LinearGradient check

            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 8

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    height: 40

                    // Hamburger menu moved to sidebar

                    Text {
                        text: Ai.currentModel ? Ai.currentModel.name : ""
                        color: Colors.overBackground
                        font.family: Config.theme.font
                        font.pixelSize: 16
                        font.weight: Font.Bold
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    visible: false // Moved to typing indicator in footer
                }

                // Messages
                ListView {
                    id: chatView
                    visible: !mainChatArea.isWelcome
                    cacheBuffer: 1000
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: Ai.currentChat
                    spacing: 16
                    displayMarginBeginning: 40
                    displayMarginEnd: 40

                    // Add bottom margin to avoid input overlap
                    // Default height of input is around 48-150, plus margins. Safety buffer 180.
                    bottomMargin: mainChatArea.isWelcome ? 0 : inputContainer.height

                    // Auto scroll to bottom
                    onCountChanged: {
                        Qt.callLater(() => {
                            positionViewAtEnd();
                        });
                    }

                    delegate: Item {
                        id: messageDelegate
                        required property var modelData
                        required property int index

                        property bool isUser: modelData.role === "user"
                        property bool isSystem: modelData.role === "system" || modelData.role === "function"
                        property bool isEditing: false
                        property bool retryMode: false // Toggle for retry UI

                        width: ListView.view.width
                        height: bubbleArea.height + 8

                        Row {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: 10
                            layoutDirection: (isUser && !isSystem) ? Qt.RightToLeft : Qt.LeftToRight
                            spacing: 12

                            // Icon
                            Item {
                                width: 32
                                height: 32
                                visible: !isSystem

                                // Assistant Icon (Robot)
                                StyledRect {
                                    anchors.fill: parent
                                    radius: Styling.radius(16)
                                    variant: "primary"
                                    visible: !isUser

                                    Text {
                                        anchors.centerIn: parent
                                        text: Icons.robot
                                        font.family: Icons.font
                                        color: Colors.overPrimary
                                        font.pixelSize: 20
                                    }
                                }

                                // User Icon (Image from ~/.face.icon)
                                ClippingRectangle {
                                    anchors.fill: parent
                                    radius: Styling.radius(16)
                                    color: Colors.surfaceDim
                                    visible: isUser

                                    Image {
                                        anchors.fill: parent
                                        source: "file://" + Quickshell.env("HOME") + "/.face.icon"
                                        fillMode: Image.PreserveAspectCrop
                                        // Fallback if image fails loading
                                        onStatusChanged: {
                                            if (status === Image.Error) {
                                                source = ""; // Clear to show fallback text below
                                            }
                                        }

                                        // Fallback text if image missing
                                        Text {
                                            anchors.centerIn: parent
                                            text: Icons.user
                                            font.family: Icons.font
                                            color: Colors.overPrimary
                                            visible: parent.status !== Image.Ready
                                        }
                                    }
                                }
                            }

                            // Bubble Area (Full Width Hover)
                            MouseArea {
                                id: bubbleArea
                                width: parent.width
                                height: Math.max(bubble.height, 32) + (modelIndicator.visible ? modelIndicator.implicitHeight + 4 : 0)
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton // Passthrough clicks unless explicitly handled

                                // Action Buttons (Visible on Hover, outside bubble)
                                Row {
                                    anchors.verticalCenter: bubble.verticalCenter
                                    // Make buttons appear to the side of the bubble
                                    anchors.left: isUser ? undefined : bubble.right
                                    anchors.right: isUser ? bubble.left : undefined
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 4
                                    visible: bubbleArea.containsMouse || messageDelegate.isEditing

                                    // Edit (User & Assistant)
                                    Button {
                                        width: 24
                                        height: 24
                                        flat: true
                                        padding: 0
                                        visible: !isSystem

                                        property bool isHovered: hovered

                                        contentItem: Text {
                                            text: messageDelegate.isEditing ? Icons.accept : Icons.edit
                                            font.family: Icons.font
                                            color: parent.down ? Colors.overPrimary : (parent.isHovered ? Colors.overSurface : Colors.overSurface)
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        background: StyledRect {
                                            variant: parent.down ? "primary" : (parent.isHovered ? "focus" : "common")
                                            radius: Styling.radius(4)
                                        }

                                        onClicked: {
                                            if (messageDelegate.isEditing) {
                                                Ai.updateMessage(index, bubbleContentText.text);
                                                messageDelegate.isEditing = false;
                                            } else {
                                                messageDelegate.isEditing = true;
                                                bubbleContentText.forceActiveFocus();
                                                bubbleContentText.cursorPosition = bubbleContentText.text.length;
                                            }
                                        }
                                    }
                                    // Copy
                                    Button {
                                        width: 24
                                        height: 24
                                        flat: true
                                        padding: 0
                                        visible: !messageDelegate.isEditing

                                        property bool isHovered: hovered

                                        contentItem: Text {
                                            text: Icons.copy
                                            font.family: Icons.font
                                            color: parent.down ? Colors.overPrimary : (parent.isHovered ? Colors.overSurface : Colors.overSurface)
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        background: StyledRect {
                                            variant: parent.down ? "primary" : (parent.isHovered ? "focus" : "common")
                                            radius: Styling.radius(4)
                                        }

                                        onClicked: {
                                            let p = Qt.createQmlObject('import Quickshell; import Quickshell.Io; Process { command: ["wl-copy", "' + modelData.content.replace(/"/g, '\\"') + '"] }', parent);
                                            p.running = true;
                                        }
                                    }

                                    // Regenerate (Assistant only)
                                    Button {
                                        visible: !isUser && !isSystem && !messageDelegate.isEditing
                                        width: 24
                                        height: 24
                                        flat: true
                                        padding: 0

                                        property bool isHovered: hovered

                                        contentItem: Text {
                                            text: Icons.arrowCounterClockwise
                                            font.family: Icons.font
                                            color: parent.down ? Colors.overPrimary : (parent.isHovered ? Colors.overSurface : Colors.overSurface)
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        background: StyledRect {
                                            variant: parent.down ? "primary" : (parent.isHovered ? "focus" : "common")
                                            radius: Styling.radius(4)
                                        }

                                        onClicked: {
                                            Ai.regenerateResponse(index);
                                        }
                                    }
                                }

                                StyledRect {
                                    id: bubble
                                    width: Math.min(Math.max(bubbleContent.implicitWidth + 32, 100), chatView.width * (isSystem ? 0.9 : 0.7))
                                    height: bubbleContent.implicitHeight + 24

                                    // Align bubble based on user/assistant
                                    anchors.right: isUser ? parent.right : undefined
                                    anchors.left: isUser ? undefined : parent.left

                                    variant: isSystem ? "surface" : (isUser ? "primaryContainer" : "surfaceVariant")
                                    radius: Styling.radius(4)
                                    border.width: isSystem || messageDelegate.isEditing ? 1 : 0
                                    border.color: messageDelegate.isEditing ? Styling.srItem("overprimary") : Colors.surfaceDim

                                    ColumnLayout {
                                        id: bubbleContent
                                        anchors.centerIn: parent
                                        width: parent.width - 32
                                        spacing: 8

                                        // Formatted View (Text + Code Blocks)
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            visible: !messageDelegate.isEditing && !bubbleContentText.visible
                                            spacing: 8

                                            Repeater {
                                                model: {
                                                    let txt = modelData.content || "";
                                                    let parts = [];
                                                    let regex = /```(\w*)\n([\s\S]*?)```/g;
                                                    let lastIndex = 0;
                                                    let match;
                                                    while ((match = regex.exec(txt)) !== null) {
                                                        if (match.index > lastIndex) {
                                                            parts.push({
                                                                type: "text",
                                                                content: txt.substring(lastIndex, match.index),
                                                                language: ""
                                                            });
                                                        }
                                                        parts.push({
                                                            type: "code",
                                                            content: match[2].trim(),
                                                            language: match[1] || "text"
                                                        });
                                                        lastIndex = regex.lastIndex;
                                                    }
                                                    if (lastIndex < txt.length) {
                                                        parts.push({
                                                            type: "text",
                                                            content: txt.substring(lastIndex),
                                                            language: ""
                                                        });
                                                    }
                                                    return parts;
                                                }

                                                delegate: Loader {
                                                    Layout.fillWidth: true
                                                    sourceComponent: modelData.type === 'code' ? codeComponent : textComponent

                                                    property var segment: modelData

                                                    Component {
                                                        id: textComponent
                                                        TextEdit {
                                                            width: bubbleContent.width
                                                            text: segment.content
                                                            textFormat: Text.MarkdownText
                                                            color: isSystem ? Colors.outline : (isUser ? Colors.overPrimaryContainer : Colors.overSurfaceVariant)
                                                            font.family: Config.theme.font
                                                            font.pixelSize: 14
                                                            wrapMode: Text.Wrap
                                                            readOnly: true
                                                            selectByMouse: true

                                                            // Handle links if needed
                                                            onLinkActivated: link => Qt.openUrlExternally(link)
                                                        }
                                                    }

                                                    Component {
                                                        id: codeComponent
                                                        CodeBlock {
                                                            width: bubbleContent.width
                                                            code: segment.content
                                                            language: segment.language
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        // Edit Mode / Raw Text
                                        TextEdit {
                                            id: bubbleContentText
                                            Layout.fillWidth: true
                                            text: modelData.content || ""
                                            textFormat: Text.PlainText // Raw text for editing
                                            color: isSystem ? Colors.outline : (isUser ? Colors.overPrimaryContainer : Colors.overSurfaceVariant)
                                            font.family: Config.theme.font
                                            font.pixelSize: 14
                                            wrapMode: Text.Wrap
                                            readOnly: !messageDelegate.isEditing
                                            selectByMouse: true
                                            visible: messageDelegate.isEditing
                                        }

                                        // Function Call Block
                                        ColumnLayout {
                                            visible: modelData.functionCall !== undefined
                                            Layout.fillWidth: true
                                            spacing: 4

                                            Rectangle {
                                                Layout.fillWidth: true
                                                height: 1
                                                color: Colors.outline
                                                opacity: 0.2
                                            }

                                            Text {
                                                text: "Run Command"
                                                color: Styling.srItem("overprimary")
                                                font.family: Config.theme.font
                                                font.weight: Font.Bold
                                                font.pixelSize: 12
                                            }

                                            StyledRect {
                                                Layout.fillWidth: true
                                                variant: "surface"
                                                color: Colors.surface // Ensure dark bg for code
                                                radius: Styling.radius(4)

                                                TextEdit {
                                                    padding: 8
                                                    width: parent.width
                                                    text: modelData.functionCall ? modelData.functionCall.args.command : ""
                                                    font.family: "Monospace"
                                                    color: Colors.overSurface
                                                    readOnly: true
                                                    wrapMode: Text.WrapAnywhere
                                                }
                                            }

                                            // Action Buttons
                                            RowLayout {
                                                visible: modelData.functionPending === true
                                                Layout.alignment: Qt.AlignRight
                                                spacing: 8

                                                Button {
                                                    text: "Reject"
                                                    highlighted: true
                                                    flat: true
                                                    onClicked: Ai.rejectCommand(index)

                                                    background: StyledRect {
                                                        variant: "error"
                                                        opacity: parent.hovered ? 0.8 : 0.5
                                                        radius: Styling.radius(4)
                                                    }
                                                    contentItem: Text {
                                                        text: parent.text
                                                        color: Colors.overError
                                                        font.family: Config.theme.font
                                                        horizontalAlignment: Text.AlignHCenter
                                                        verticalAlignment: Text.AlignVCenter
                                                    }
                                                }

                                                Button {
                                                    text: "Approve"
                                                    highlighted: true
                                                    flat: true
                                                    onClicked: Ai.approveCommand(index)

                                                    background: StyledRect {
                                                        variant: "primary"
                                                        opacity: parent.hovered ? 1 : 0.8
                                                        radius: Styling.radius(4)
                                                    }
                                                    contentItem: Text {
                                                        text: parent.text
                                                        color: Colors.overPrimary
                                                        font.family: Config.theme.font
                                                        horizontalAlignment: Text.AlignHCenter
                                                        verticalAlignment: Text.AlignVCenter
                                                    }
                                                }
                                            }

                                            Text {
                                                visible: modelData.functionApproved === true
                                                text: "Command Approved"
                                                color: Colors.success
                                                font.pixelSize: 12
                                            }

                                            Text {
                                                visible: modelData.functionApproved === false && !modelData.functionPending
                                                text: "Command Rejected"
                                                color: Colors.error
                                                font.pixelSize: 12
                                            }
                                        }
                                    }
                                }

                                // Model Indicator (Assistant Only)
                                Text {
                                    id: modelIndicator
                                    visible: !isUser && !isSystem && (modelData.model ? true : false)
                                    text: retryMode ? "Retry with another model " + Icons.caretRight : (modelData.model || "")
                                    color: Colors.outline
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-2)
                                    font.weight: Font.Medium

                                    anchors.top: bubble.bottom
                                    anchors.topMargin: 4
                                    anchors.left: bubble.left
                                    anchors.leftMargin: 4

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (retryMode) {
                                                mainChatArea.retryIndex = index;
                                                modelSelector.open();
                                                retryMode = false;
                                            } else {
                                                retryMode = true;
                                                retryTimer.start();
                                            }
                                        }
                                    }

                                    Timer {
                                        id: retryTimer
                                        interval: 5000
                                        onTriggered: retryMode = false
                                    }
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
                                    width: 8
                                    height: 8
                                    radius: 4
                                    color: Styling.srItem("overprimary")
                                    opacity: 0.5

                                    SequentialAnimation on opacity {
                                        loops: Animation.Infinite
                                        running: Ai.isLoading

                                        PauseAnimation {
                                            duration: index * 200
                                        }
                                        PropertyAnimation {
                                            to: 1
                                            duration: 400
                                        }
                                        PropertyAnimation {
                                            to: 0.5
                                            duration: 400
                                        }
                                        PauseAnimation {
                                            duration: 400 - (index * 200)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // The original Input Area was here, now it's moved outside this ColumnLayout
            }

            // Model Selection Popup
            ModelSelectorPopup {
                id: modelSelector
                parent: mainChatArea

                onModelSelected: {
                    if (mainChatArea.retryIndex > -1) {
                        Ai.regenerateResponse(mainChatArea.retryIndex);
                        mainChatArea.retryIndex = -1;
                    }
                }
            }

            Connections {
                target: Ai
                function onModelSelectionRequested() {
                    modelSelector.open();
                }
            }

            // Input Area (Floating)
            Item {
                id: inputContainer
                height: Math.min(150, Math.max(48, inputField.contentHeight + 24))

                // State-based anchors
                anchors.bottom: parent.bottom
                // Calculate center position for bottom margin: (parent height / 2) - (input height / 2)
                property real centerMargin: (parent.height / 2) - (height / 2)
                anchors.bottomMargin: mainChatArea.isWelcome ? centerMargin : 20
                anchors.horizontalCenter: parent.horizontalCenter

                // Keep width compact as requested (600px max)
                width: Math.min(600, parent.width - 40)

                Behavior on anchors.bottomMargin {
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutCubic
                    }
                }

                StyledRect {
                    anchors.fill: parent
                    variant: "pane"
                    radius: Styling.radius(4) // Constant radius as requested
                    enableShadow: true

                    // Suggestions Popup
                    Popup {
                        id: suggestionsPopup
                        parent: inputContainer
                        y: -height - 8
                        x: 0
                        width: parent.width
                        // Limit height to 3 items if welcome (approx 40px*3=120) or 5 items if chat active (200)
                        height: Math.min(suggestionsList.contentHeight, mainChatArea.isWelcome ? 120 : 200)
                        padding: 0
                        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                        visible: inputField.text.startsWith("/") && suggestionsModel.count > 0

                        background: StyledRect {
                            variant: "popup"
                            radius: Styling.radius(8)
                            enableShadow: true
                        }

                        function selectNext() {
                            suggestionsList.currentIndex = (suggestionsList.currentIndex + 1) % suggestionsModel.count;
                        }

                        function selectPrevious() {
                            suggestionsList.currentIndex = (suggestionsList.currentIndex - 1 + suggestionsModel.count) % suggestionsModel.count;
                        }

                        function executeSelection() {
                            if (suggestionsList.currentIndex >= 0 && suggestionsList.currentIndex < suggestionsModel.count) {
                                let item = suggestionsModel.get(suggestionsList.currentIndex);
                                inputField.text = "/" + item.name + " ";
                                inputField.cursorPosition = inputField.text.length;
                                inputField.forceActiveFocus();
                            }
                        }

                        ListView {
                            id: suggestionsList
                            anchors.fill: parent
                            clip: true
                            model: ListModel {
                                id: suggestionsModel
                            }
                            highlight: Rectangle {
                                color: Colors.surface
                                opacity: 0.5
                            }
                            highlightMoveDuration: 0

                            delegate: Button {
                                width: suggestionsList.width
                                height: 40
                                flat: true
                                highlighted: ListView.isCurrentItem

                                contentItem: RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 8

                                    Text {
                                        text: "/" + model.name
                                        font.family: Config.theme.font
                                        font.weight: Font.Bold
                                        color: highlighted ? Styling.srItem("overprimary") : Colors.overSurface
                                    }

                                    Text {
                                        text: model.description
                                        font.family: Config.theme.font
                                        color: highlighted ? Colors.overSurface : Colors.surfaceDim
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }
                                }

                                background: Rectangle {
                                    color: (parent.highlighted || parent.hovered) ? Colors.surfaceBright : "transparent"
                                }

                                onClicked: {
                                    suggestionsList.currentIndex = index;
                                    suggestionsPopup.executeSelection();
                                }
                            }
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16 // Balanced padding

                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            TextArea {
                                id: inputField
                                placeholderText: mainChatArea.isWelcome ? "Ask AI or type /help..." : "Message AI..."
                                placeholderTextColor: Colors.outline
                                font.pixelSize: 14
                                color: Colors.overBackground
                                wrapMode: TextEdit.Wrap

                                onTextChanged: {
                                    if (text.startsWith("/")) {
                                        const query = text.substring(1).toLowerCase();
                                        suggestionsModel.clear();
                                        root.slashCommands.forEach(cmd => {
                                            if (cmd.name.startsWith(query)) {
                                                suggestionsModel.append(cmd);
                                            }
                                        });
                                    } else {
                                        suggestionsModel.clear();
                                    }
                                }

                                background: null

                                Keys.onPressed: event => {
                                    if (suggestionsPopup.visible) {
                                        if (event.key === Qt.Key_Up) {
                                            suggestionsPopup.selectPrevious();
                                            event.accepted = true;
                                            return;
                                        } else if (event.key === Qt.Key_Down) {
                                            suggestionsPopup.selectNext();
                                            event.accepted = true;
                                            return;
                                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Tab) {
                                            suggestionsPopup.executeSelection();
                                            event.accepted = true;
                                            return;
                                        }
                                    }
                                    // Regular return behavior
                                    if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ShiftModifier)) {
                                        if (text.trim().length > 0) {
                                            Ai.sendMessage(text.trim());
                                            text = "";
                                        }
                                        event.accepted = true;
                                    }
                                }

                                Component.onCompleted: forceActiveFocus()
                            }
                        }

                        Button {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            flat: true
                            visible: inputField.text.length > 0

                            contentItem: Text {
                                text: Icons.paperPlane
                                font.family: Icons.font
                                font.pixelSize: 20
                                color: Styling.srItem("overprimary")
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            background: Rectangle {
                                color: parent.hovered ? Colors.surfaceBright : "transparent"
                                radius: 16
                            }

                            onClicked: {
                                if (inputField.text.trim().length > 0) {
                                    Ai.sendMessage(inputField.text.trim());
                                    inputField.text = "";
                                }
                            }
                        }
                    }
                }
            }

            // Model Name Indicator (Below Input, Welcome Screen Only)
            Text {
                anchors.top: inputContainer.bottom
                anchors.topMargin: 8
                anchors.horizontalCenter: inputContainer.horizontalCenter

                text: Ai.currentModel ? Ai.currentModel.name : ""
                color: Colors.outline
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                font.weight: Font.Medium

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4 // Increase touch area slightly
                    cursorShape: Qt.PointingHandCursor
                    onClicked: modelSelector.open()
                }

                visible: mainChatArea.isWelcome

                Behavior on opacity {
                    NumberAnimation {
                        duration: 200
                    }
                }
                opacity: visible ? 1 : 0
            }
        }
    }
}
