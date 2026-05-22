import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Widgets
import qs.modules.theme
import qs.config
import qs.modules.components
import qs.modules.services
import qs.modules.globals
import Quickshell
import Quickshell.Io

Item {
    id: root
    anchors.fill: parent

    required property var targetScreen

    readonly property bool active: GlobalStates.assistantVisible && targetScreen.name === GlobalStates.assistantScreenName
    property alias hitbox: sidebarContainer
    property alias hasActiveFocus: inputField.activeFocus

    readonly property bool frameEnabled: (Config.bar?.frameEnabled ?? false)
    readonly property bool frameWrapped: frameEnabled && GlobalStates.assistantPinned
    readonly property int sidebarMargin: frameWrapped ? 0 : 4
    property bool wantsFocus: false
    property bool menuExpanded: false
    property real menuWidth: 250
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

    function focusSearchInput() {
        inputField.forceActiveFocus();
    }

    Connections {
        target: GlobalStates
        function onAssistantFocusRequested(wasAlreadyOpen) {
            if (targetScreen.name === GlobalStates.assistantScreenName) {
                Qt.callLater(() => {
                    if (wasAlreadyOpen) {
                        // It was already open. If it currently has focus, close it. Otherwise, regain focus.
                        if (root.active && root.wantsFocus && inputField.activeFocus) {
                            GlobalStates.hideAssistant();
                        } else {
                            root.wantsFocus = true;
                            focusSearchInput();
                        }
                    } else {
                        // It just opened. Just ensure it has focus.
                        root.wantsFocus = true;
                        focusSearchInput();
                    }
                });
            }
        }
    }

    onActiveChanged: {
        if (active) {
            root.wantsFocus = true;
            Qt.callLater(() => {
                focusSearchInput();
            });
        } else {
            root.wantsFocus = false;
        }
    }

    MouseArea {
        anchors.fill: parent
        propagateComposedEvents: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: mouse => {
            if (!root.wantsFocus)
                root.wantsFocus = true;
            mouse.accepted = false;
        }
    }

    MouseArea {
        id: resizeHandle
        width: 8
        height: sidebarContainer.height
        y: sidebarContainer.y
        visible: sidebarContainer.visible && root.active
        cursorShape: Qt.SplitHCursor
        preventStealing: true

        x: {
            if (GlobalStates.assistantPosition === "left")
                return sidebarContainer.x + sidebarContainer.width;
            return sidebarContainer.x - width;
        }

        property real pressMouseX: 0
        property int pressWidth: 0

        onPressed: {
            let mapped = mapToItem(root, mouseX, 0);
            pressMouseX = mapped.x;
            pressWidth = GlobalStates.assistantWidth;
        }

        onMouseXChanged: {
            if (!pressed)
                return;
            let mapped = mapToItem(root, mouseX, 0);
            let delta;
            if (GlobalStates.assistantPosition === "right")
                delta = pressMouseX - mapped.x;
            else
                delta = mapped.x - pressMouseX;
            GlobalStates.assistantWidth = Math.max(300, Math.min(800, pressWidth + delta));
        }

        onReleased: {
            Config.ai.sidebarWidth = GlobalStates.assistantWidth;
        }
    }

    Item {
        id: sidebarContainer
        width: GlobalStates.assistantWidth + root.sidebarMargin
        height: parent.height

        x: {
            if (GlobalStates.assistantPosition === "left")
                return root.active ? 0 : -(width);
            return root.active ? parent.width - width : parent.width;
        }

        visible: root.active || slideAnimation.running

        Behavior on x {
            NumberAnimation {
                id: slideAnimation
                duration: Config.animDuration
                easing.type: Easing.OutCubic
            }
        }

        StyledRect {
            anchors.fill: parent
            anchors.topMargin: root.sidebarMargin
            anchors.bottomMargin: root.sidebarMargin
            anchors.leftMargin: GlobalStates.assistantPosition === "left" ? root.sidebarMargin : 0
            anchors.rightMargin: GlobalStates.assistantPosition === "right" ? root.sidebarMargin : 0
            variant: root.frameWrapped ? "transparent" : "bg"

            radius: root.frameWrapped ? 0 : (variantConfig.radius !== undefined ? variantConfig.radius : Styling.radius(0))
            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8

                        Button {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            flat: true
                            padding: 0
                            contentItem: Text {
                                text: Icons.list
                                font.family: Icons.font
                                font.pixelSize: 16
                                color: root.menuExpanded ? Styling.srItem("overprimary") : Colors.overSurface
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: StyledRect {
                                variant: parent.hovered ? "focus" : "common"
                                radius: Styling.radius(4)
                                opacity: parent.hovered ? 1 : 0
                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Config.animDuration / 4
                                    }
                                }
                            }
                            onClicked: root.menuExpanded = !root.menuExpanded
                        }

                        Button {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            flat: true
                            padding: 0
                            contentItem: Text {
                                text: Icons.edit
                                font.family: Icons.font
                                font.pixelSize: 16
                                color: Colors.overSurface
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: StyledRect {
                                variant: parent.hovered ? "focus" : "common"
                                radius: Styling.radius(4)
                                opacity: parent.hovered ? 1 : 0
                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Config.animDuration / 4
                                    }
                                }
                            }
                            onClicked: {
                                Ai.createNewChat();
                                root.menuExpanded = false;
                            }
                        }

                        Button {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            flat: true
                            padding: 0

                            contentItem: Text {
                                text: Icons.pin
                                font.family: Icons.font
                                font.pixelSize: 16
                                color: GlobalStates.assistantPinned ? Styling.srItem("overprimary") : Colors.overSurface
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            background: StyledRect {
                                variant: parent.hovered ? "focus" : "common"
                                radius: Styling.radius(4)
                                opacity: parent.hovered ? 1 : 0

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Config.animDuration / 4
                                    }
                                }
                            }

                            onClicked: {
                                GlobalStates.assistantPinned = !GlobalStates.assistantPinned;
                                Config.ai.sidebarPinnedOnStartup = GlobalStates.assistantPinned;
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Button {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            flat: true
                            padding: 0

                            contentItem: Text {
                                text: GlobalStates.assistantPosition === "right" ? Icons.caretRight : Icons.caretLeft
                                font.family: Icons.font
                                font.pixelSize: 16
                                color: Colors.overSurface
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            background: StyledRect {
                                variant: parent.hovered ? "focus" : "common"
                                radius: Styling.radius(4)
                                opacity: parent.hovered ? 1 : 0

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Config.animDuration / 4
                                    }
                                }
                            }

                            onClicked: GlobalStates.hideAssistant()
                        }
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: Colors.outline
                        opacity: 0.15
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Item {
                        id: mainChatArea
                        anchors.fill: parent

                        property var pendingAttachments: []

                        function addAttachment(mimeType, base64Data, fileName) {
                            let list = pendingAttachments.slice();
                            list.push({
                                type: "image",
                                mimeType: mimeType,
                                base64: base64Data,
                                name: fileName
                            });
                            pendingAttachments = list;
                        }

                        function normalizeFilePath(path) {
                            let p = path ? path.trim() : "";
                            if (p.startsWith("file://"))
                                p = p.substring(7);
                            try {
                                p = decodeURIComponent(p);
                            } catch (e) {
                            }
                            return p;
                        }

                        function fileMimeForPath(path) {
                            let ext = path.split(".").pop().toLowerCase();
                            let mimeMap = {
                                png: "image/png",
                                jpg: "image/jpeg",
                                jpeg: "image/jpeg",
                                gif: "image/gif",
                                webp: "image/webp",
                                bmp: "image/bmp"
                            };
                            return mimeMap[ext] || "";
                        }

                        function addAttachmentFromFile(path) {
                            let filePath = normalizeFilePath(path);
                            if (!filePath)
                                return;
                            let mimeType = fileMimeForPath(filePath);
                            if (!mimeType) {
                                Ai.pushSystemMessage("Only image files are supported for attachments.");
                                return;
                            }
                            attachmentReadProcess.filePath = filePath;
                            attachmentReadProcess.mimeType = mimeType;
                            attachmentReadProcess.fileName = filePath.split("/").pop();
                            attachmentReadProcess.running = true;
                        }

                        function addAttachmentsFromUriList(text) {
                            let lines = text.split("\n");
                            for (let i = 0; i < lines.length; i++) {
                                let line = lines[i].trim();
                                if (line === "" || line.startsWith("#"))
                                    continue;
                                addAttachmentFromFile(line);
                            }
                        }

                        function removeAttachment(index) {
                            let list = pendingAttachments.slice();
                            list.splice(index, 1);
                            pendingAttachments = list;
                        }

                        function clearAttachments() {
                            pendingAttachments = [];
                        }
                        StyledRect {
                            id: historyPage
                            anchors.fill: parent
                            variant: "bg"
                            visible: root.menuExpanded
                            opacity: root.menuExpanded ? 1 : 0
                            z: 10

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Config.animDuration
                                }
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 8

                                Text {
                                    text: "Chat History"
                                    color: Colors.overSurface
                                    font.family: Config.theme.font
                                    font.pixelSize: 18
                                    font.weight: Font.Bold
                                }

                                ListView {
                                    id: historyList
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true
                                    model: Ai.chatHistory
                                    spacing: 4

                                    delegate: Button {
                                        width: historyList.width
                                        height: 48
                                        flat: true

                                        contentItem: RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 12
                                            spacing: 8

                                            Column {
                                                Layout.fillWidth: true
                                                Layout.alignment: Qt.AlignVCenter

                                                Text {
                                                    text: modelData.title || "New Chat"
                                                    color: Ai.currentChatId === modelData.id ? Styling.srItem("primary") : Colors.overSurface
                                                    font.family: Config.theme.font
                                                    font.pixelSize: 14
                                                    font.weight: Font.Medium
                                                    elide: Text.ElideRight
                                                    width: parent.width
                                                }

                                                Text {
                                                    text: {
                                                        let date = new Date(parseInt(modelData.id));
                                                        return date.toLocaleString(Qt.locale(), "MMM dd, hh:mm a");
                                                    }
                                                    color: Ai.currentChatId === modelData.id ? Styling.srItem("primary") : Colors.outline
                                                    font.family: Config.theme.font
                                                    font.pixelSize: 11
                                                    elide: Text.ElideRight
                                                    width: parent.width
                                                }
                                            }

                                            Button {
                                                visible: parent.parent.hovered
                                                flat: true
                                                Layout.preferredWidth: 28
                                                Layout.preferredHeight: 28

                                                contentItem: Text {
                                                    text: Icons.trash
                                                    font.family: Icons.font
                                                    color: parent.hovered ? Colors.error : Colors.outline
                                                    font.pixelSize: 14
                                                    horizontalAlignment: Text.AlignHCenter
                                                    verticalAlignment: Text.AlignVCenter
                                                }

                                                background: null
                                                onClicked: Ai.deleteChat(modelData.id)
                                            }
                                        }

                                        background: StyledRect {
                                            variant: Ai.currentChatId === modelData.id ? "focus" : (parent.hovered ? "surfaceVariant" : "transparent")
                                            radius: Styling.radius(6)
                                        }

                                        onClicked: {
                                            Ai.loadChat(modelData.id);
                                            root.menuExpanded = false;
                                        }
                                    }
                                }
                            }
                        }
                        property int retryIndex: -1
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

                        Process {
                            id: zenityProcess
                            command: ["zenity", "--file-selection", "--file-filter=Images | *.png *.jpg *.jpeg *.gif *.webp *.bmp", "--file-filter=All files | *"]
                            stdout: StdioCollector {
                                onStreamFinished: {
                                    let filePath = text.trim();
                                    if (filePath.length > 0)
                                        mainChatArea.addAttachmentFromFile(filePath);
                                }
                            }
                        }

                        Process {
                            id: attachmentReadProcess
                            property string filePath: ""
                            property string mimeType: ""
                            property string fileName: ""
                            command: ["bash", "-c", "/usr/bin/base64 -w 0 '" + filePath.replace(/'/g, "'\\''") + "'"]
                            stdout: StdioCollector {
                                onStreamFinished: {
                                    let data = text.trim();
                                    if (data.length > 0)
                                        mainChatArea.addAttachment(attachmentReadProcess.mimeType, data, attachmentReadProcess.fileName);
                                    else if (attachmentReadProcess.filePath.length > 0)
                                        Ai.pushSystemMessage("Failed to read attachment data.");
                                }
                            }
                            stderr: StdioCollector {
                                id: attachmentReadStderr
                            }
                            onExited: exitCode => {
                                if (exitCode !== 0) {
                                    let errorText = attachmentReadStderr.text.trim();
                                    Ai.pushSystemMessage("Failed to read attachment: " + (errorText.length > 0 ? errorText : "unknown error"));
                                }
                            }
                        }

                        Process {
                            id: clipboardTypesProcess
                            command: ["wl-paste", "--list-types"]
                            stdout: StdioCollector {
                                onStreamFinished: {
                                    let types = text.trim().split("\n");
                                    let imageType = "";
                                    for (let i = 0; i < types.length; i++) {
                                        if (types[i].startsWith("image/")) {
                                            imageType = types[i].trim();
                                            break;
                                        }
                                    }
                                    if (imageType.length > 0) {
                                        clipboardImageProcess.mimeType = imageType;
                                        clipboardImageProcess.running = true;
                                        return;
                                    }
                                    if (types.indexOf("text/uri-list") !== -1) {
                                        clipboardUrisProcess.running = true;
                                        return;
                                    }
                                    Ai.pushSystemMessage("Clipboard does not contain an image or file.");
                                }
                            }
                            stderr: StdioCollector {
                                id: clipboardTypesStderr
                            }
                            onExited: exitCode => {
                                if (exitCode !== 0) {
                                    let err = clipboardTypesStderr.text.trim();
                                    Ai.pushSystemMessage("Clipboard read failed: " + (err.length > 0 ? err : "unknown error"));
                                }
                            }
                        }

                        Process {
                            id: clipboardImageProcess
                            property string mimeType: ""
                            command: ["bash", "-c", "wl-paste --type \"" + mimeType + "\" 2>/dev/null | /usr/bin/base64 -w 0" ]
                            stdout: StdioCollector {
                                onStreamFinished: {
                                    let data = text.trim();
                                    if (data.length > 0) {
                                        let ext = clipboardImageProcess.mimeType.split("/")[1] || "png";
                                        mainChatArea.addAttachment(clipboardImageProcess.mimeType, data, "clipboard." + ext);
                                    } else {
                                        Ai.pushSystemMessage("Clipboard image read returned no data.");
                                    }
                                }
                            }
                            stderr: StdioCollector {
                                id: clipboardImageStderr
                            }
                            onExited: exitCode => {
                                if (exitCode !== 0) {
                                    let err = clipboardImageStderr.text.trim();
                                    Ai.pushSystemMessage("Clipboard image read failed: " + (err.length > 0 ? err : "unknown error"));
                                }
                            }
                        }

                        Process {
                            id: clipboardUrisProcess
                            command: ["wl-paste", "--type", "text/uri-list"]
                            stdout: StdioCollector {
                                onStreamFinished: {
                                    let data = text.trim();
                                    if (data.length > 0)
                                        mainChatArea.addAttachmentsFromUriList(data);
                                    else
                                        Ai.pushSystemMessage("Clipboard file list is empty.");
                                }
                            }
                            stderr: StdioCollector {
                                id: clipboardUrisStderr
                            }
                            onExited: exitCode => {
                                if (exitCode !== 0) {
                                    let err = clipboardUrisStderr.text.trim();
                                    Ai.pushSystemMessage("Clipboard file read failed: " + (err.length > 0 ? err : "unknown error"));
                                }
                            }
                        }
                        property bool isWelcome: Ai.currentChat.length === 0

                        ColumnLayout {
                            anchors.bottom: inputContainer.top
                            anchors.bottomMargin: 24
                            anchors.horizontalCenter: parent.horizontalCenter
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
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                height: 40

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

                                visible: false
                            }

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

                                bottomMargin: mainChatArea.isWelcome ? 0 : inputContainer.height

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
                                    property bool retryMode: false

                                    width: ListView.view.width
                                    height: bubbleArea.height + 8

                                    Row {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.margins: 10
                                        layoutDirection: (isUser && !isSystem) ? Qt.RightToLeft : Qt.LeftToRight
                                        spacing: 12

                                        Item {
                                            width: 32
                                            height: 32
                                            visible: !isSystem

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

                                            ClippingRectangle {
                                                anchors.fill: parent
                                                radius: Styling.radius(16)
                                                color: Colors.surfaceDim
                                                visible: isUser

                                                Image {
                                                    mipmap: true
                                                    anchors.fill: parent
                                                    source: "file://" + Quickshell.env("HOME") + "/.face.icon"
                                                    fillMode: Image.PreserveAspectCrop

                                                    onStatusChanged: {
                                                        if (status === Image.Error) {
                                                            source = "";
                                                        }
                                                    }

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

                                        MouseArea {
                                            id: bubbleArea
                                            width: parent.width
                                            height: Math.max(bubble.height, 32) + (modelIndicator.visible ? modelIndicator.implicitHeight + 4 : 0)
                                            hoverEnabled: true
                                            acceptedButtons: Qt.NoButton

                                            Row {
                                                anchors.verticalCenter: bubble.verticalCenter
                                                anchors.left: isUser ? undefined : bubble.right
                                                anchors.right: isUser ? bubble.left : undefined
                                                anchors.leftMargin: 8
                                                anchors.rightMargin: 8
                                                spacing: 4
                                                visible: bubbleArea.containsMouse || messageDelegate.isEditing

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

                                                    onClicked: Ai.regenerateResponse(index)
                                                }
                                            }

                                            StyledRect {
                                                id: bubble
                                                width: Math.min(Math.max(bubbleContent.implicitWidth + 32, 100), chatView.width * (isSystem ? 0.9 : 0.7))
                                                height: bubbleContent.implicitHeight + 24

                                                anchors.right: isUser ? parent.right : undefined
                                                anchors.left: isUser ? undefined : parent.left

                                                variant: isSystem ? "surface" : (isUser ? "primary" : "secondary")
                                                radius: Styling.radius(4)
                                                border.width: isSystem || messageDelegate.isEditing ? 1 : 0
                                                border.color: messageDelegate.isEditing ? Styling.srItem("overprimary") : Colors.surfaceDim

                                                ColumnLayout {
                                                    id: bubbleContent
                                                    anchors.centerIn: parent
                                                    width: parent.width - 32
                                                    spacing: 8

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
                                                                        color: isSystem ? Colors.outline : (isUser ? Styling.srItem("primary") : Styling.srItem("secondary"))
                                                                        font.family: Config.theme.font
                                                                        font.pixelSize: 14
                                                                        wrapMode: Text.Wrap
                                                                        readOnly: true
                                                                        selectByMouse: true

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

                                                    TextEdit {
                                                        id: bubbleContentText
                                                        Layout.fillWidth: true
                                                        text: modelData.content || ""
                                                        textFormat: Text.PlainText
                                                        color: isSystem ? Colors.outline : (isUser ? Styling.srItem("primary") : Styling.srItem("secondary"))
                                                        font.family: Config.theme.font
                                                        font.pixelSize: 14
                                                        wrapMode: Text.Wrap
                                                        readOnly: !messageDelegate.isEditing
                                                        selectByMouse: true
                                                        visible: messageDelegate.isEditing
                                                    }

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
                                                            color: Colors.surface
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
                        }

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

                        Item {
                            id: inputContainer
                            property int attachmentPreviewHeight: attachmentPreview.visible ? Math.min(attachmentPreview.contentHeight, 120) + 8 : 0
                            height: attachmentPreviewHeight + Math.min(150, Math.max(48, inputField.contentHeight + 24))

                            anchors.bottom: parent.bottom
                            property real centerMargin: (parent.height / 2) - (height / 2)
                            anchors.bottomMargin: mainChatArea.isWelcome ? centerMargin : 20
                            anchors.horizontalCenter: parent.horizontalCenter

                            width: Math.min(600, parent.width - 40)

                            Behavior on anchors.bottomMargin {
                                NumberAnimation {
                                    duration: Config.animDuration
                                    easing.type: Easing.OutCubic
                                }
                            }

                            StyledRect {
                                id: inputStyledRect
                                anchors.fill: parent
                                variant: "pane"
                                radius: Styling.radius(4)
                                enableShadow: true

                                DropArea {
                                    anchors.fill: parent
                                    onDropped: drop => {
                                        if (drop.urls && drop.urls.length > 0) {
                                            for (let i = 0; i < drop.urls.length; i++)
                                                mainChatArea.addAttachmentFromFile(drop.urls[i]);
                                            drop.accepted = true;
                                            return;
                                        }
                                        if (drop.text && drop.text.length > 0) {
                                            mainChatArea.addAttachmentsFromUriList(drop.text);
                                            drop.accepted = true;
                                        }
                                    }
                                }

                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: 6

                                    Flickable {
                                        id: attachmentPreview
                                        height: visible ? Math.min(contentHeight, 120) : 0
                                        Layout.fillWidth: true
                                        Layout.leftMargin: 12
                                        Layout.rightMargin: 12
                                        Layout.topMargin: 8
                                        Layout.preferredHeight: height
                                        visible: mainChatArea.pendingAttachments.length > 0
                                        clip: true
                                        boundsBehavior: Flickable.StopAtBounds
                                        interactive: contentHeight > height

                                        contentWidth: width
                                        contentHeight: attachmentsFlow.height

                                        Flow {
                                            id: attachmentsFlow
                                            width: attachmentPreview.width
                                            spacing: 6

                                            Repeater {
                                                model: mainChatArea.pendingAttachments

                                                Item {
                                                    width: 48
                                                    height: 48

                                                    StyledRect {
                                                        anchors.fill: parent
                                                        variant: "surface"
                                                        radius: Styling.radius(6)

                                                        Image {
                                                            anchors.fill: parent
                                                            anchors.margins: 2
                                                            source: "data:" + modelData.mimeType + ";base64," + modelData.base64
                                                            fillMode: Image.PreserveAspectCrop
                                                            sourceSize.width: 48
                                                            sourceSize.height: 48
                                                        }
                                                    }

                                                    Button {
                                                        anchors.right: parent.right
                                                        anchors.top: parent.top
                                                        anchors.rightMargin: -4
                                                        anchors.topMargin: -4
                                                        width: 16
                                                        height: 16
                                                        flat: true
                                                        z: 1

                                                        contentItem: Text {
                                                            text: Icons.cancel
                                                            font.family: Icons.font
                                                            font.pixelSize: 10
                                                            color: Colors.overSurface
                                                            horizontalAlignment: Text.AlignHCenter
                                                            verticalAlignment: Text.AlignVCenter
                                                        }

                                                        background: Rectangle {
                                                            color: Colors.surfaceBright
                                                            radius: 8
                                                        }

                                                        onClicked: mainChatArea.removeAttachment(index)
                                                    }
                                                }
                                            }
                                        }
                                    }

                                Popup {
                                    id: suggestionsPopup
                                    parent: inputContainer
                                    y: -height - 8
                                    x: 0
                                    width: parent.width
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
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.leftMargin: 16
                                    Layout.rightMargin: 16
                                    Layout.topMargin: attachmentPreview.visible ? 0 : 8
                                    Layout.bottomMargin: 8

                                    ScrollView {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        TextArea {
                                            id: inputField
                                            focus: true
                                            activeFocusOnTab: true
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
                                                if (event.key === Qt.Key_V && (event.modifiers & Qt.ControlModifier)) {
                                                    clipboardTypesProcess.running = true;
                                                    return;
                                                }
                                                if (event.key === Qt.Key_Escape) {
                                                    if (root.menuExpanded) {
                                                        root.menuExpanded = false;
                                                    } else {
                                                        root.wantsFocus = false;
                                                    }
                                                    event.accepted = true;
                                                    return;
                                                }
                                                if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ShiftModifier)) {
                                                    if (text.trim().length > 0 || mainChatArea.pendingAttachments.length > 0) {
                                                        Ai.sendMessage(text.trim(), mainChatArea.pendingAttachments.length > 0 ? mainChatArea.pendingAttachments : undefined);
                                                        text = "";
                                                        mainChatArea.clearAttachments();
                                                    }
                                                    event.accepted = true;
                                                }
                                            }
                                            Component.onCompleted: {
                                                if (root.active)
                                                    forceActiveFocus();
                                            }
                                        }
                                    }

                                    Button {
                                        Layout.preferredWidth: 32
                                        Layout.preferredHeight: 32
                                        flat: true

                                        contentItem: Text {
                                            text: Icons.plus
                                            font.family: Icons.font
                                            font.pixelSize: 20
                                            color: Colors.outline
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        background: Rectangle {
                                            color: parent.hovered ? Colors.surfaceBright : "transparent"
                                            radius: 16
                                        }

                                        onClicked: zenityProcess.running = true
                                    }
                                    Button {
                                        Layout.preferredWidth: 32
                                        Layout.preferredHeight: 32
                                        flat: true
                                        visible: inputField.text.length > 0 || mainChatArea.pendingAttachments.length > 0

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
                                            if (inputField.text.trim().length > 0 || mainChatArea.pendingAttachments.length > 0) {
                                                Ai.sendMessage(inputField.text.trim(), mainChatArea.pendingAttachments.length > 0 ? mainChatArea.pendingAttachments : undefined);
                                                inputField.text = "";
                                                mainChatArea.clearAttachments();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

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
                                anchors.margins: -4
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
        }
    }
}
