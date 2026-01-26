pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.modules.theme
import qs.modules.components
import qs.modules.globals
import qs.modules.services
import qs.config

Item {
    id: root
    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property int maxContentWidth: 480
    readonly property int contentWidth: Math.min(width, maxContentWidth)
    readonly property real sideMargin: (width - contentWidth) / 2

    // Available color names for color picker
    readonly property var colorNames: Colors.availableColorNames

    // Color picker state
    property bool colorPickerActive: false
    property var colorPickerColorNames: []
    property string colorPickerCurrentColor: ""
    property string colorPickerDialogTitle: ""
    property var colorPickerCallback: null

    function openColorPicker(colorNames, currentColor, dialogTitle, callback) {
        colorPickerColorNames = colorNames;
        colorPickerCurrentColor = currentColor;
        colorPickerDialogTitle = dialogTitle;
        colorPickerCallback = callback;
        colorPickerActive = true;
    }

    function closeColorPicker() {
        colorPickerActive = false;
        colorPickerCallback = null;
    }

    function handleColorSelected(color) {
        if (colorPickerCallback) {
            colorPickerCallback(color);
        }
        colorPickerCurrentColor = color;
    }

    property string currentSection: ""
    property string highlightKey: ""
    property int highlightNonce: 0
    property var highlightRegistry: ({})
    property string pendingScrollKey: ""

    function flashOption(key) {
        if (!key)
            return;
        highlightKey = key;
        highlightNonce++;
        queueScrollToHighlight(key);
    }

    function queueScrollToHighlight(key) {
        pendingScrollKey = key;
        scrollToHighlightAttempts = 0;
        scrollToHighlightTimer.start();
    }

    function scrollToHighlight(key) {
        if (!key || !highlightRegistry[key])
            return;
        const target = highlightRegistry[key];
        Qt.callLater(() => {
            if (!target || !mainFlickable)
                return;
            const localPos = target.mapToItem(mainFlickable.contentItem, 0, 0);
            const padding = 16;
            const targetY = Math.max(0, localPos.y - padding);
            const maxY = Math.max(0, mainFlickable.contentHeight - mainFlickable.height);
            mainFlickable.contentY = Math.min(targetY, maxY);
        });
    }

    Timer {
        id: scrollToHighlightTimer
        interval: 80
        repeat: true
        onTriggered: {
            if (!pendingScrollKey) {
                stop();
                return;
            }
            scrollToHighlightAttempts++;
            scrollToHighlight(pendingScrollKey);
            if (scrollToHighlightAttempts >= 6) {
                stop();
            }
        }
    }

    property int scrollToHighlightAttempts: 0

    component HighlightRow: Item {
        id: highlightRowRoot
        property string highlightId: ""
        property int highlightNonce: root.highlightNonce
        property real pulseOpacity: 0.35
        property int pulseDuration: 160
        property int pulsePause: 120
        default property alias content: contentLayout.data

        Layout.fillWidth: true
        implicitHeight: Math.max(contentLayout.implicitHeight, 0)
        implicitWidth: Math.max(contentLayout.implicitWidth, 0)
        Layout.preferredHeight: implicitHeight

        Rectangle {
            id: highlightRect
            anchors.fill: parent
            anchors.margins: -2
            radius: Styling.radius(-2)
            color: Styling.srItem("overprimary")
            opacity: 0
            z: 0
        }

        ColumnLayout {
            id: contentLayout
            anchors.fill: parent
            spacing: 0
            z: 1
        }

        SequentialAnimation {
            id: highlightPulse
            running: false
            loops: 2

            NumberAnimation {
                target: highlightRect
                property: "opacity"
                from: 0
                to: highlightRowRoot.pulseOpacity
                duration: highlightRowRoot.pulseDuration
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: highlightRect
                property: "opacity"
                from: highlightRowRoot.pulseOpacity
                to: 0
                duration: highlightRowRoot.pulseDuration + highlightRowRoot.pulsePause
                easing.type: Easing.OutCubic
            }
        }

        onHighlightNonceChanged: {
            if (highlightId !== "" && highlightId === root.highlightKey) {
                highlightPulse.restart();
            }
        }

        Component.onCompleted: {
            if (highlightId !== "") {
                root.highlightRegistry[highlightId] = highlightRowRoot;
            }
        }

        Component.onDestruction: {
            if (highlightId !== "" && root.highlightRegistry[highlightId] === highlightRowRoot) {
                delete root.highlightRegistry[highlightId];
            }
        }
    }

    component SectionButton: StyledRect {
        id: sectionBtn
        required property string text
        required property string sectionId

        property bool isHovered: false

        variant: isHovered ? "focus" : "pane"
        Layout.fillWidth: true
        Layout.preferredHeight: 56
        radius: Styling.radius(0)
        LayoutMirroring.enabled: I18n.isRtl
        LayoutMirroring.childrenInherit: true

        RowLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 16

            Text {
                text: sectionBtn.text
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(0)
                font.bold: true
                color: Colors.overBackground
                Layout.fillWidth: true
                horizontalAlignment: I18n.isRtl ? Text.AlignRight : Text.AlignLeft
            }

            Text {
                text: I18n.isRtl ? Icons.caretLeft : Icons.caretRight
                font.family: Icons.font
                font.pixelSize: 20
                color: Colors.overSurfaceVariant
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: sectionBtn.isHovered = true
            onExited: sectionBtn.isHovered = false
            onClicked: root.currentSection = sectionBtn.sectionId
        }
    }

    // Inline component for toggle rows
    component ToggleRow: RowLayout {
        id: toggleRowRoot
        property string label: ""
        property bool checked: false
        signal toggled(bool value)

        // Track if we're updating from external binding
        property bool _updating: false

        onCheckedChanged: {
            if (!_updating && toggleSwitch.checked !== checked) {
                _updating = true;
                toggleSwitch.checked = checked;
                _updating = false;
            }
        }

        Layout.fillWidth: true
        spacing: 12
        LayoutMirroring.enabled: I18n.isRtl
        LayoutMirroring.childrenInherit: true

        Text {
            text: toggleRowRoot.label
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(0)
            color: Colors.overBackground
            Layout.fillWidth: true
            horizontalAlignment: I18n.isRtl ? Text.AlignRight : Text.AlignLeft
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
        }

        Switch {
            id: toggleSwitch
            checked: toggleRowRoot.checked
            Layout.alignment: I18n.isRtl ? Qt.AlignLeft : Qt.AlignRight

            onCheckedChanged: {
                if (!toggleRowRoot._updating && checked !== toggleRowRoot.checked) {
                    toggleRowRoot.toggled(checked);
                }
            }

            indicator: Rectangle {
                implicitWidth: 40
                implicitHeight: 20
                x: toggleSwitch.leftPadding
                y: parent.height / 2 - height / 2
                radius: height / 2
                color: toggleSwitch.checked ? Styling.srItem("overprimary") : Colors.surfaceBright
                border.color: toggleSwitch.checked ? Styling.srItem("overprimary") : Colors.outline

                Behavior on color {
                    enabled: Config.animDuration > 0
                    ColorAnimation {
                        duration: Config.animDuration / 2
                    }
                }

                Rectangle {
                    x: toggleSwitch.checked ? parent.width - width - 2 : 2
                    y: 2
                    width: parent.height - 4
                    height: width
                    radius: width / 2
                    color: toggleSwitch.checked ? Colors.background : Colors.overSurfaceVariant

                    Behavior on x {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Config.animDuration / 2
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
            background: null
        }
    }

    // Inline component for number input rows
    component NumberInputRow: RowLayout {
        id: numberInputRowRoot
        property string label: ""
        property int value: 0
        property int minValue: 0
        property int maxValue: 100
        property string suffix: ""
        signal valueEdited(int newValue)

        Layout.fillWidth: true
        spacing: 12
        LayoutMirroring.enabled: I18n.isRtl
        LayoutMirroring.childrenInherit: true

        Text {
            text: numberInputRowRoot.label
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(0)
            color: Colors.overBackground
            Layout.fillWidth: true
            horizontalAlignment: I18n.isRtl ? Text.AlignRight : Text.AlignLeft
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
        }

        StyledRect {
            variant: "common"
            Layout.preferredWidth: 60
            Layout.preferredHeight: 32
            radius: Styling.radius(-2)
            Layout.alignment: I18n.isRtl ? Qt.AlignLeft : Qt.AlignRight

            TextInput {
                id: numberTextInput
                anchors.fill: parent
                anchors.margins: 8
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(0)
                color: Colors.overBackground
                selectByMouse: true
                clip: true
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter
                validator: IntValidator {
                    bottom: numberInputRowRoot.minValue
                    top: numberInputRowRoot.maxValue
                }

                // Sync text when external value changes
                readonly property int configValue: numberInputRowRoot.value
                onConfigValueChanged: {
                    if (!activeFocus && text !== configValue.toString()) {
                        text = configValue.toString();
                    }
                }
                Component.onCompleted: text = configValue.toString()

                onEditingFinished: {
                    let newVal = parseInt(text);
                    if (!isNaN(newVal)) {
                        newVal = Math.max(numberInputRowRoot.minValue, Math.min(numberInputRowRoot.maxValue, newVal));
                        numberInputRowRoot.valueEdited(newVal);
                    }
                }
            }
        }

        Text {
            text: numberInputRowRoot.suffix
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(0)
            color: Colors.overSurfaceVariant
            visible: suffix !== ""
            Layout.alignment: I18n.isRtl ? Qt.AlignLeft : Qt.AlignRight
        }
    }

    // Inline component for text input rows
    component TextInputRow: RowLayout {
        id: textInputRowRoot
        property string label: ""
        property string value: ""
        property string placeholder: ""
        signal valueEdited(string newValue)

        Layout.fillWidth: true
        spacing: 12
        LayoutMirroring.enabled: I18n.isRtl
        LayoutMirroring.childrenInherit: true

        Text {
            text: textInputRowRoot.label
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(0)
            color: Colors.overBackground
            Layout.preferredWidth: Math.max(100, implicitWidth)
            horizontalAlignment: I18n.isRtl ? Text.AlignRight : Text.AlignLeft
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
        }

        StyledRect {
            variant: "common"
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            radius: Styling.radius(-2)
            Layout.alignment: I18n.isRtl ? Qt.AlignLeft : Qt.AlignRight

            TextInput {
                id: textInputField
                anchors.fill: parent
                anchors.margins: 8
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(0)
                color: Colors.overBackground
                selectByMouse: true
                clip: true
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: I18n.isRtl ? TextInput.AlignRight : TextInput.AlignLeft

                // Sync text when external value changes
                readonly property string configValue: textInputRowRoot.value
                onConfigValueChanged: {
                    if (!activeFocus && text !== configValue) {
                        text = configValue;
                    }
                }
                Component.onCompleted: text = configValue

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: textInputRowRoot.placeholder
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(0)
                    color: Colors.overSurfaceVariant
                    visible: textInputField.text === ""
                    horizontalAlignment: I18n.isRtl ? Text.AlignRight : Text.AlignLeft
                }

                onEditingFinished: {
                    textInputRowRoot.valueEdited(text);
                }
            }
        }
    }

    // Inline component for segmented selector rows
    component SelectorRow: ColumnLayout {
        id: selectorRowRoot
        property string label: ""
        property var options: []  // Array of { label: "...", value: "...", icon: "..." (optional) }
        property string value: ""
        signal valueSelected(string newValue)

        function getIndexFromValue(val: string): int {
            for (let i = 0; i < options.length; i++) {
                if (options[i].value === val)
                    return i;
            }
            return 0;
        }

        Layout.fillWidth: true
        spacing: 6
        LayoutMirroring.enabled: I18n.isRtl
        LayoutMirroring.childrenInherit: true

        Text {
            text: selectorRowRoot.label
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            font.weight: Font.Medium
            color: Colors.overSurfaceVariant
            visible: selectorRowRoot.label !== ""
            horizontalAlignment: I18n.isRtl ? Text.AlignRight : Text.AlignLeft
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            LayoutMirroring.enabled: I18n.isRtl
            LayoutMirroring.childrenInherit: true

            Repeater {
                model: selectorRowRoot.options

                delegate: StyledRect {
                    id: optionButton
                    required property var modelData
                    required property int index

                    readonly property bool isSelected: selectorRowRoot.getIndexFromValue(selectorRowRoot.value) === index
                    property bool isHovered: false

                    variant: isSelected ? "primary" : (isHovered ? "focus" : "common")
                    enableShadow: true
                    Layout.fillWidth: true
                    height: 36
                    radius: isSelected ? Styling.radius(0) / 2 : Styling.radius(0)

                    Text {
                        id: optionIcon
                        anchors.left: I18n.isRtl ? undefined : parent.left
                        anchors.right: I18n.isRtl ? parent.right : undefined
                        anchors.leftMargin: I18n.isRtl ? 0 : 12
                        anchors.rightMargin: I18n.isRtl ? 12 : 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: optionButton.modelData.icon ?? ""
                        font.family: Icons.font
                        font.pixelSize: 14
                        color: optionButton.item
                        visible: (optionButton.modelData.icon ?? "") !== ""
                    }

                    Text {
                        anchors.centerIn: parent
                        text: optionButton.modelData.label
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(0)
                        font.bold: true
                        color: optionButton.item
                        horizontalAlignment: I18n.isRtl ? Text.AlignRight : Text.AlignLeft
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onEntered: optionButton.isHovered = true
                        onExited: optionButton.isHovered = false

                        onClicked: selectorRowRoot.valueSelected(optionButton.modelData.value)
                    }
                }
            }
        }
    }

    // Inline component for screen list selection
    component ScreenListRow: ColumnLayout {
        id: screenListRowRoot
        property string label: I18n.t("Screens")
        property var selectedScreens: []  // Array of screen names
        signal screensChanged(var newList)

        Layout.fillWidth: true
        spacing: 4
        LayoutMirroring.enabled: I18n.isRtl
        LayoutMirroring.childrenInherit: true

        Text {
            text: screenListRowRoot.label
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            font.weight: Font.Medium
            color: Colors.overSurfaceVariant
            horizontalAlignment: I18n.isRtl ? Text.AlignRight : Text.AlignLeft
        }

        Text {
            text: I18n.t("Empty = all screens")
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            color: Colors.outline
            Layout.bottomMargin: 4
            horizontalAlignment: I18n.isRtl ? Text.AlignRight : Text.AlignLeft
        }

        Flow {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: Quickshell.screens

                delegate: StyledRect {
                    id: screenButton
                    required property var modelData
                    required property int index

                    readonly property string screenName: modelData.name
                    readonly property bool isSelected: {
                        const list = screenListRowRoot.selectedScreens;
                        return list && list.length > 0 && list.includes(screenName);
                    }
                    property bool isHovered: false

                    variant: isSelected ? "primary" : (isHovered ? "focus" : "common")
                    width: screenLabel.implicitWidth + 24
                    height: 32
                    radius: Styling.radius(-2)

                    Text {
                        id: screenLabel
                        anchors.centerIn: parent
                        text: screenButton.screenName
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        font.bold: screenButton.isSelected
                        color: screenButton.item
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onEntered: screenButton.isHovered = true
                        onExited: screenButton.isHovered = false

                        onClicked: {
                            let currentList = screenListRowRoot.selectedScreens ? [...screenListRowRoot.selectedScreens] : [];
                            const idx = currentList.indexOf(screenButton.screenName);
                            if (idx >= 0) {
                                currentList.splice(idx, 1);
                            } else {
                                currentList.push(screenButton.screenName);
                            }
                            screenListRowRoot.screensChanged(currentList);
                        }
                    }
                }
            }
        }
    }

    // Main content
    Flickable {
        id: mainFlickable
        anchors.fill: parent
        contentHeight: mainColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: !root.colorPickerActive

        // Horizontal slide + fade animation
        opacity: root.colorPickerActive ? 0 : 1
        transform: Translate {
            x: root.colorPickerActive ? -30 : 0

            Behavior on x {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 2
                    easing.type: Easing.OutQuart
                }
            }
        }

        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration / 2
                easing.type: Easing.OutQuart
            }
        }

        ColumnLayout {
            id: mainColumn
            width: mainFlickable.width
            spacing: 8

            // Content wrapper - centered
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: contentColumn.implicitHeight

                ColumnLayout {
                    id: contentColumn
                    width: root.contentWidth
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 16

                    // ═══════════════════════════════════════════════════════════════
                    // MENU SECTION
                    // ═══════════════════════════════════════════════════════════════
                    ColumnLayout {
                        visible: root.currentSection === ""
                        Layout.fillWidth: true
                        spacing: 8

                        SectionButton {
                            text: I18n.t("Bar")
                            sectionId: "bar"
                        }
                        SectionButton {
                            text: I18n.t("Frame")
                            sectionId: "frame"
                        }
                        SectionButton {
                            text: I18n.t("Notch")
                            sectionId: "notch"
                        }
                        SectionButton {
                            text: I18n.t("Workspaces")
                            sectionId: "workspaces"
                        }
                        SectionButton {
                            text: I18n.t("Overview")
                            sectionId: "overview"
                        }
                        SectionButton {
                            text: I18n.t("Dock")
                            sectionId: "dock"
                        }
                        SectionButton {
                            text: I18n.t("Lockscreen")
                            sectionId: "lockscreen"
                        }
                        SectionButton {
                            text: I18n.t("Desktop")
                            sectionId: "desktop"
                        }
                        SectionButton {
                            text: I18n.t("System")
                            sectionId: "system"
                        }
                    }

                    // ═══════════════════════════════════════════════════════════════
                    // BAR SECTION
                    // ═══════════════════════════════════════════════════════════════
                    ColumnLayout {
                        visible: root.currentSection === "bar"
                        Layout.fillWidth: true
                        spacing: 8

                        HighlightRow {
                            highlightId: "bar.position"

                            SelectorRow {
                                label: ""
                                options: [
                                    {
                                        label: I18n.t("Top"),
                                        value: "top",
                                        icon: Icons.arrowUp
                                    },
                                    {
                                        label: I18n.t("Bottom"),
                                        value: "bottom",
                                        icon: Icons.arrowDown
                                    },
                                    {
                                        label: I18n.t("Left"),
                                        value: "left",
                                        icon: Icons.arrowLeft
                                    },
                                    {
                                        label: I18n.t("Right"),
                                        value: "right",
                                        icon: Icons.arrowRight
                                    }
                                ]
                                value: Config.bar.position ?? "top"
                                onValueSelected: newValue => {
                                    if (newValue !== Config.bar.position) {
                                        GlobalStates.markShellChanged();
                                        Config.bar.position = newValue;
                                    }
                                }
                            }
                        }

                        HighlightRow {
                            highlightId: "bar.launcherIcon"

                            TextInputRow {
                                label: I18n.t("Launcher Icon")
                                value: Config.bar.launcherIcon ?? ""
                                placeholder: I18n.t("Symbol or path to icon...")
                                onValueEdited: newValue => {
                                    if (newValue !== Config.bar.launcherIcon) {
                                        GlobalStates.markShellChanged();
                                        Config.bar.launcherIcon = newValue;
                                    }
                                }
                            }
                        }

                        HighlightRow {
                            highlightId: "bar.launcherIconTint"

                            ToggleRow {
                                label: I18n.t("Launcher Icon Tint")
                                checked: Config.bar.launcherIconTint ?? true
                                onToggled: value => {
                                    if (value !== Config.bar.launcherIconTint) {
                                        GlobalStates.markShellChanged();
                                        Config.bar.launcherIconTint = value;
                                    }
                                }
                            }
                        }

                        HighlightRow {
                            highlightId: "bar.launcherIconFullTint"

                            ToggleRow {
                                label: I18n.t("Launcher Icon Full Tint")
                                checked: Config.bar.launcherIconFullTint ?? true
                                onToggled: value => {
                                    if (value !== Config.bar.launcherIconFullTint) {
                                        GlobalStates.markShellChanged();
                                        Config.bar.launcherIconFullTint = value;
                                    }
                                }
                            }
                        }

                        HighlightRow {
                            highlightId: "bar.launcherIconSize"

                            NumberInputRow {
                                label: I18n.t("Launcher Icon Size")
                                value: Config.bar.launcherIconSize ?? 24
                                minValue: 12
                                maxValue: 64
                                suffix: I18n.t("px")
                                onValueEdited: newValue => {
                                    if (newValue !== Config.bar.launcherIconSize) {
                                        GlobalStates.markShellChanged();
                                        Config.bar.launcherIconSize = newValue;
                                    }
                                }
                            }
                        }

                        HighlightRow {
                            highlightId: "bar.enableFirefoxPlayer"

                            ToggleRow {
                                label: I18n.t("Enable Firefox Player")
                                checked: Config.bar.enableFirefoxPlayer ?? false
                                onToggled: value => {
                                    if (value !== Config.bar.enableFirefoxPlayer) {
                                        GlobalStates.markShellChanged();
                                        Config.bar.enableFirefoxPlayer = value;
                                    }
                                }
                            }
                        }

                        HighlightRow {
                            highlightId: "bar.showBongoCat"

                            ToggleRow {
                                label: I18n.t("Show Bongo Cat")
                                checked: Config.bar.showBongoCat ?? true
                                onToggled: value => {
                                    if (value !== Config.bar.showBongoCat) {
                                        GlobalStates.markShellChanged();
                                        Config.bar.showBongoCat = value;
                                    }
                                }
                            }
                        }

                        Separator {
                            Layout.fillWidth: true
                        }

                        Text {
                            text: I18n.t("Auto-hide")
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: Font.Medium
                            color: Colors.overSurfaceVariant
                            Layout.bottomMargin: -4
                        }

                        HighlightRow {
                            highlightId: "bar.pinnedOnStartup"

                            ToggleRow {
                                label: I18n.t("Pinned on Startup")
                                checked: Config.bar.pinnedOnStartup ?? true
                                onToggled: value => {
                                    if (value !== Config.bar.pinnedOnStartup) {
                                        GlobalStates.markShellChanged();
                                        Config.bar.pinnedOnStartup = value;
                                    }
                                }
                            }
                        }

                        HighlightRow {
                            highlightId: "bar.hoverToReveal"

                            ToggleRow {
                                label: I18n.t("Hover to Reveal")
                                checked: Config.bar.hoverToReveal ?? true
                                onToggled: value => {
                                    if (value !== Config.bar.hoverToReveal) {
                                        GlobalStates.markShellChanged();
                                        Config.bar.hoverToReveal = value;
                                    }
                                }
                            }
                        }

                        HighlightRow {
                            highlightId: "bar.hoverRegionHeight"

                            NumberInputRow {
                                label: I18n.t("Hover Region Height")
                                value: Config.bar.hoverRegionHeight ?? 8
                                minValue: 0
                                maxValue: 32
                                suffix: I18n.t("px")
                                onValueEdited: newValue => {
                                    if (newValue !== Config.bar.hoverRegionHeight) {
                                        GlobalStates.markShellChanged();
                                        Config.bar.hoverRegionHeight = newValue;
                                    }
                                }
                            }
                        }

                        HighlightRow {
                            highlightId: "bar.showPinButton"

                            ToggleRow {
                                label: I18n.t("Show Pin Button")
                                checked: Config.bar.showPinButton ?? true
                                onToggled: value => {
                                    if (value !== Config.bar.showPinButton) {
                                        GlobalStates.markShellChanged();
                                        Config.bar.showPinButton = value;
                                    }
                                }
                            }
                        }

                        HighlightRow {
                            highlightId: "bar.availableOnFullscreen"

                            ToggleRow {
                                label: I18n.t("Available on Fullscreen")
                                checked: Config.bar.availableOnFullscreen ?? false
                                onToggled: value => {
                                    if (value !== Config.bar.availableOnFullscreen) {
                                        GlobalStates.markShellChanged();
                                        Config.bar.availableOnFullscreen = value;
                                    }
                                }
                            }
                        }

                        HighlightRow {
                            highlightId: "bar.screenList"

                            ScreenListRow {
                                label: I18n.t("Screens")
                                selectedScreens: Config.bar.screenList ?? []
                                onScreensChanged: newList => {
                                    GlobalStates.markShellChanged();
                                    Config.bar.screenList = newList;
                                }
                            }
                        }
                    }

                    // ═══════════════════════════════════════════════════════════════
                    // FRAME SECTION
                    // ═══════════════════════════════════════════════════════════════
                    ColumnLayout {
                        visible: root.currentSection === "frame"
                        Layout.fillWidth: true
                        spacing: 8

                        HighlightRow {
                            highlightId: "frame.enabled"

                            ToggleRow {
                                label: I18n.t("Enabled")
                                checked: Config.bar.frameEnabled ?? false
                                onToggled: value => {
                                    if (value !== Config.bar.frameEnabled) {
                                        GlobalStates.markShellChanged();
                                        Config.bar.frameEnabled = value;
                                    }
                                }
                            }
                        }

                        HighlightRow {
                            highlightId: "frame.thickness"

                            NumberInputRow {
                                label: I18n.t("Thickness")
                                value: Config.bar.frameThickness ?? 6
                                minValue: 1
                                maxValue: 40
                                suffix: I18n.t("px")
                                onValueEdited: newValue => {
                                    if (newValue !== Config.bar.frameThickness) {
                                        GlobalStates.markShellChanged();
                                        Config.bar.frameThickness = newValue;
                                    }
                                }
                            }
                        }
                    }

                    Separator {
                        Layout.fillWidth: true
                        visible: false
                    }

                    // ═══════════════════════════════════════════════════════════════
                    // NOTCH SECTION
                    // ═══════════════════════════════════════════════════════════════
                    ColumnLayout {
                        visible: root.currentSection === "notch"
                        Layout.fillWidth: true
                        spacing: 8

                        HighlightRow {
                            highlightId: "notch.theme"

                            SelectorRow {
                                label: ""
                                options: [
                                    {
                                        label: I18n.t("Default"),
                                        value: "default"
                                    },
                                    {
                                        label: I18n.t("Island"),
                                        value: "island"
                                    }
                                ]
                                value: Config.notch.theme ?? "default"
                                onValueSelected: newValue => {
                                    if (newValue !== Config.notch.theme) {
                                        GlobalStates.markShellChanged();
                                        Config.notch.theme = newValue;
                                    }
                                }
                            }
                        }

                        HighlightRow {
                            highlightId: "notch.hoverRegionHeight"

                            NumberInputRow {
                                label: I18n.t("Hover Region Height")
                                value: Config.notch.hoverRegionHeight ?? 8
                                minValue: 0
                                maxValue: 32
                                suffix: I18n.t("px")
                                onValueEdited: newValue => {
                                    if (newValue !== Config.notch.hoverRegionHeight) {
                                        GlobalStates.markShellChanged();
                                        Config.notch.hoverRegionHeight = newValue;
                                    }
                                }
                            }
                        }
                    }

                    Separator {
                        Layout.fillWidth: true
                        visible: false
                    }

                    // ═══════════════════════════════════════════════════════════════
                    // WORKSPACES SECTION
                    // ═══════════════════════════════════════════════════════════════
                    ColumnLayout {
                        visible: root.currentSection === "workspaces"
                        Layout.fillWidth: true
                        spacing: 8

                        HighlightRow {
                            highlightId: "workspaces.shown"

                            NumberInputRow {
                                label: I18n.t("Shown")
                                value: Config.workspaces.shown ?? 10
                                minValue: 1
                                maxValue: 20
                                onValueEdited: newValue => {
                                    if (newValue !== Config.workspaces.shown) {
                                        GlobalStates.markShellChanged();
                                        Config.workspaces.shown = newValue;
                                    }
                                }
                            }
                        }

                        HighlightRow {
                            highlightId: "workspaces.showAppIcons"

                            ToggleRow {
                                label: I18n.t("Show App Icons")
                                checked: Config.workspaces.showAppIcons ?? true
                                onToggled: value => {
                                    if (value !== Config.workspaces.showAppIcons) {
                                        GlobalStates.markShellChanged();
                                        Config.workspaces.showAppIcons = value;
                                    }
                                }
                            }
                        }

                        HighlightRow {
                            highlightId: "workspaces.alwaysShowNumbers"

                            ToggleRow {
                                label: I18n.t("Always Show Numbers")
                                checked: Config.workspaces.alwaysShowNumbers ?? false
                                onToggled: value => {
                                    if (value !== Config.workspaces.alwaysShowNumbers) {
                                        GlobalStates.markShellChanged();
                                        Config.workspaces.alwaysShowNumbers = value;
                                    }
                                }
                            }
                        }

                        HighlightRow {
                            highlightId: "workspaces.showNumbers"

                            ToggleRow {
                                label: I18n.t("Show Numbers")
                                checked: Config.workspaces.showNumbers ?? false
                                onToggled: value => {
                                    if (value !== Config.workspaces.showNumbers) {
                                        GlobalStates.markShellChanged();
                                        Config.workspaces.showNumbers = value;
                                    }
                                }
                            }
                        }

                        HighlightRow {
                            highlightId: "workspaces.dynamic"

                            ToggleRow {
                                label: I18n.t("Dynamic")
                                checked: Config.workspaces.dynamic ?? false
                                onToggled: value => {
                                    if (value !== Config.workspaces.dynamic) {
                                        GlobalStates.markShellChanged();
                                        Config.workspaces.dynamic = value;
                                    }
                                }
                            }
                        }
                    }

                    Separator {
                        Layout.fillWidth: true
                        visible: false
                    }

                    // ═══════════════════════════════════════════════════════════════
                    // OVERVIEW SECTION
                    // ═══════════════════════════════════════════════════════════════
                    ColumnLayout {
                        visible: root.currentSection === "overview"
                        Layout.fillWidth: true
                        spacing: 8

                        HighlightRow {
                            highlightId: "overview.rows"

                            NumberInputRow {
                                label: I18n.t("Rows")
                                value: Config.overview.rows ?? 2
                                minValue: 1
                                maxValue: 5
                                onValueEdited: newValue => {
                                    if (newValue !== Config.overview.rows) {
                                        GlobalStates.markShellChanged();
                                        Config.overview.rows = newValue;
                                    }
                                }
                            }
                        }

                        HighlightRow {
                            highlightId: "overview.columns"

                            NumberInputRow {
                                label: I18n.t("Columns")
                                value: Config.overview.columns ?? 5
                                minValue: 1
                                maxValue: 10
                                onValueEdited: newValue => {
                                    if (newValue !== Config.overview.columns) {
                                        GlobalStates.markShellChanged();
                                        Config.overview.columns = newValue;
                                    }
                                }
                            }
                        }

                        HighlightRow {
                            highlightId: "overview.scale"

                            RowLayout {
                                spacing: 8

                                Text {
                                    text: I18n.t("Scale")
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(0)
                                    color: Colors.overBackground
                                    Layout.preferredWidth: 100
                                }

                                StyledSlider {
                                    id: overviewScaleSlider
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 20
                                    progressColor: Styling.srItem("overprimary")
                                    tooltipText: `${(value * 0.2).toFixed(2)}`
                                    scroll: true
                                    stepSize: 0.05  // 0.05 * 0.2 = 0.01 scale steps
                                    snapMode: "always"

                                    readonly property real configValue: (Config.overview.scale ?? 0.15) / 0.2

                                    onConfigValueChanged: {
                                        if (Math.abs(value - configValue) > 0.001) {
                                            value = configValue;
                                        }
                                    }

                                    Component.onCompleted: value = configValue

                                    onValueChanged: {
                                        let newScale = Math.round(value * 0.2 * 100) / 100;  // Round to 2 decimals
                                        if (Math.abs(newScale - (Config.overview.scale ?? 0.15)) > 0.001) {
                                            GlobalStates.markShellChanged();
                                            Config.overview.scale = newScale;
                                        }
                                    }
                                }

                                Text {
                                    text: ((Config.overview.scale ?? 0.15)).toFixed(2)
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(0)
                                    color: Colors.overBackground
                                    horizontalAlignment: Text.AlignRight
                                    Layout.preferredWidth: 40
                                }
                            }
                        }

                        HighlightRow {
                            highlightId: "overview.workspaceSpacing"

                            NumberInputRow {
                                label: I18n.t("Workspace Spacing")
                                value: Config.overview.workspaceSpacing ?? 4
                                minValue: 0
                                maxValue: 20
                                suffix: I18n.t("px")
                                onValueEdited: newValue => {
                                    if (newValue !== Config.overview.workspaceSpacing) {
                                        GlobalStates.markShellChanged();
                                        Config.overview.workspaceSpacing = newValue;
                                    }
                                }
                            }
                        }
                    }

                    Separator {
                        Layout.fillWidth: true
                        visible: false
                    }

                    // ═══════════════════════════════════════════════════════════════
                    // DOCK SECTION
                    // ═══════════════════════════════════════════════════════════════
                    ColumnLayout {
                        visible: root.currentSection === "dock"
                        Layout.fillWidth: true
                        spacing: 8

                        HighlightRow {
                            highlightId: "dock.enabled"

                            ToggleRow {
                                label: I18n.t("Enabled")
                                checked: Config.dock.enabled ?? false
                                onToggled: value => {
                                    if (value !== Config.dock.enabled) {
                                        GlobalStates.markShellChanged();
                                        Config.dock.enabled = value;
                                    }
                                }
                            }
                        }

                        HighlightRow {
                            highlightId: "dock.theme"

                            SelectorRow {
                                label: ""
                                options: [
                                    {
                                        label: I18n.t("Default"),
                                        value: "default"
                                    },
                                    {
                                        label: I18n.t("Floating"),
                                        value: "floating"
                                    },
                                    {
                                        label: I18n.t("Integrated"),
                                        value: "integrated"
                                    }
                                ]
                                value: Config.dock.theme ?? "default"
                                onValueSelected: newValue => {
                                    if (newValue !== Config.dock.theme) {
                                        GlobalStates.markShellChanged();
                                        Config.dock.theme = newValue;
                                    }
                                }
                            }
                        }

                        HighlightRow {
                            highlightId: "dock.position"

                            SelectorRow {
                                label: ""
                                options: {
                                    const isIntegrated = (Config.dock.theme ?? "default") === "integrated";
                                    return [
                                        {
                                            label: isIntegrated ? "Start" : "Left",
                                            value: "left",
                                            icon: isIntegrated ? Icons.alignLeft : Icons.arrowLeft
                                        },
                                        {
                                            label: isIntegrated ? "Center" : "Bottom",
                                            value: "bottom",
                                            icon: isIntegrated ? Icons.alignCenter : Icons.arrowDown
                                        },
                                        {
                                            label: isIntegrated ? "End" : "Right",
                                            value: "right",
                                            icon: isIntegrated ? Icons.alignRight : Icons.arrowRight
                                        }
                                    ];
                                }
                                value: Config.dock.position ?? "bottom"
                                onValueSelected: newValue => {
                                    if (newValue !== Config.dock.position) {
                                        GlobalStates.markShellChanged();
                                        Config.dock.position = newValue;
                                    }
                                }
                            }
                        }

                        HighlightRow {
                            highlightId: "dock.height"
                            visible: (Config.dock.theme ?? "default") !== "integrated"

                            NumberInputRow {
                                label: I18n.t("Height")
                                value: Config.dock.height ?? 56
                                minValue: 32
                                maxValue: 128
                                suffix: I18n.t("px")
                                visible: (Config.dock.theme ?? "default") !== "integrated"
                                onValueEdited: newValue => {
                                    if (newValue !== Config.dock.height) {
                                        GlobalStates.markShellChanged();
                                        Config.dock.height = newValue;
                                    }
                                }
                            }
                        }

                        HighlightRow {
                            highlightId: "dock.iconSize"
                            visible: (Config.dock.theme ?? "default") !== "integrated"

                            NumberInputRow {
                                label: I18n.t("Icon Size")
                                value: Config.dock.iconSize ?? 40
                                minValue: 16
                                maxValue: 96
                                suffix: I18n.t("px")
                                visible: (Config.dock.theme ?? "default") !== "integrated"
                                onValueEdited: newValue => {
                                    if (newValue !== Config.dock.iconSize) {
                                        GlobalStates.markShellChanged();
                                        Config.dock.iconSize = newValue;
                                    }
                                }
                            }
                        }

                        HighlightRow {
                            highlightId: "dock.spacing"
                            visible: (Config.dock.theme ?? "default") !== "integrated"

                            NumberInputRow {
                                label: I18n.t("Spacing")
                                value: Config.dock.spacing ?? 4
                                minValue: 0
                                maxValue: 24
                                suffix: I18n.t("px")
                                visible: (Config.dock.theme ?? "default") !== "integrated"
                                onValueEdited: newValue => {
                                    if (newValue !== Config.dock.spacing) {
                                        GlobalStates.markShellChanged();
                                        Config.dock.spacing = newValue;
                                    }
                                }
                            }
                        }

                        HighlightRow {
                            highlightId: "dock.margin"
                            visible: (Config.dock.theme ?? "default") !== "integrated"

                            NumberInputRow {
                                label: I18n.t("Margin")
                                value: Config.dock.margin ?? 8
                                minValue: 0
                                maxValue: 32
                                suffix: I18n.t("px")
                                visible: (Config.dock.theme ?? "default") !== "integrated"
                                onValueEdited: newValue => {
                                    if (newValue !== Config.dock.margin) {
                                        GlobalStates.markShellChanged();
                                        Config.dock.margin = newValue;
                                    }
                                }
                            }
                        }

                        HighlightRow {
                            highlightId: "dock.hoverRegionHeight"
                            visible: (Config.dock.theme ?? "default") !== "integrated"

                            NumberInputRow {
                                label: I18n.t("Hover Region Height")
                                value: Config.dock.hoverRegionHeight ?? 4
                                minValue: 0
                                maxValue: 32
                                suffix: I18n.t("px")
                                visible: (Config.dock.theme ?? "default") !== "integrated"
                                onValueEdited: newValue => {
                                    if (newValue !== Config.dock.hoverRegionHeight) {
                                        GlobalStates.markShellChanged();
                                        Config.dock.hoverRegionHeight = newValue;
                                    }
                                }
                            }
                        }

                        HighlightRow {
                            highlightId: "dock.pinnedOnStartup"
                            visible: (Config.dock.theme ?? "default") !== "integrated"

                            ToggleRow {
                                label: I18n.t("Pinned on Startup")
                                checked: Config.dock.pinnedOnStartup ?? false
                                visible: (Config.dock.theme ?? "default") !== "integrated"
                                onToggled: value => {
                                    if (value !== Config.dock.pinnedOnStartup) {
                                        GlobalStates.markShellChanged();
                                        Config.dock.pinnedOnStartup = value;
                                    }
                                }
                            }
                        }

                        HighlightRow {
                            highlightId: "dock.hoverToReveal"
                            visible: (Config.dock.theme ?? "default") !== "integrated"

                            ToggleRow {
                                label: I18n.t("Hover to Reveal")
                                checked: Config.dock.hoverToReveal ?? true
                                visible: (Config.dock.theme ?? "default") !== "integrated"
                                onToggled: value => {
                                    if (value !== Config.dock.hoverToReveal) {
                                        GlobalStates.markShellChanged();
                                        Config.dock.hoverToReveal = value;
                                    }
                                }
                            }
                        }

                        HighlightRow {
                            highlightId: "dock.availableOnFullscreen"
                            visible: (Config.dock.theme ?? "default") !== "integrated"

                            ToggleRow {
                                label: I18n.t("Available on Fullscreen")
                                checked: Config.dock.availableOnFullscreen ?? false
                                visible: (Config.dock.theme ?? "default") !== "integrated"
                                onToggled: value => {
                                    if (value !== Config.dock.availableOnFullscreen) {
                                        GlobalStates.markShellChanged();
                                        Config.dock.availableOnFullscreen = value;
                                    }
                                }
                            }
                        }

                        HighlightRow {
                            highlightId: "dock.showRunningIndicators"
                            visible: (Config.dock.theme ?? "default") !== "integrated"

                            ToggleRow {
                                label: I18n.t("Show Running Indicators")
                                checked: Config.dock.showRunningIndicators ?? true
                                visible: (Config.dock.theme ?? "default") !== "integrated"
                                onToggled: value => {
                                    if (value !== Config.dock.showRunningIndicators) {
                                        GlobalStates.markShellChanged();
                                        Config.dock.showRunningIndicators = value;
                                    }
                                }
                            }
                        }

                        HighlightRow {
                            highlightId: "dock.showPinButton"
                            visible: (Config.dock.theme ?? "default") !== "integrated"

                            ToggleRow {
                                label: I18n.t("Show Pin Button")
                                checked: Config.dock.showPinButton ?? true
                                visible: (Config.dock.theme ?? "default") !== "integrated"
                                onToggled: value => {
                                    if (value !== Config.dock.showPinButton) {
                                        GlobalStates.markShellChanged();
                                        Config.dock.showPinButton = value;
                                    }
                                }
                            }
                        }

                        HighlightRow {
                            highlightId: "dock.showOverviewButton"
                            visible: (Config.dock.theme ?? "default") !== "integrated"

                            ToggleRow {
                                label: I18n.t("Show Overview Button")
                                checked: Config.dock.showOverviewButton ?? true
                                visible: (Config.dock.theme ?? "default") !== "integrated"
                                onToggled: value => {
                                    if (value !== Config.dock.showOverviewButton) {
                                        GlobalStates.markShellChanged();
                                        Config.dock.showOverviewButton = value;
                                    }
                                }
                            }
                        }

                        HighlightRow {
                            highlightId: "dock.screenList"
                            visible: (Config.dock.theme ?? "default") !== "integrated"

                            ScreenListRow {
                                label: I18n.t("Screens")
                                visible: (Config.dock.theme ?? "default") !== "integrated"
                                selectedScreens: Config.dock.screenList ?? []
                                onScreensChanged: newList => {
                                    GlobalStates.markShellChanged();
                                    Config.dock.screenList = newList;
                                }
                            }
                        }
                    }

                    Separator {
                        Layout.fillWidth: true
                        visible: false
                    }

                    // ═══════════════════════════════════════════════════════════════
                    // LOCKSCREEN SECTION
                    // ═══════════════════════════════════════════════════════════════
                    ColumnLayout {
                        visible: root.currentSection === "lockscreen"
                        Layout.fillWidth: true
                        spacing: 8

                        HighlightRow {
                            highlightId: "lockscreen.position"

                            SelectorRow {
                                label: ""
                                options: [
                                    {
                                        label: I18n.t("Top"),
                                        value: "top",
                                        icon: Icons.arrowUp
                                    },
                                    {
                                        label: I18n.t("Bottom"),
                                        value: "bottom",
                                        icon: Icons.arrowDown
                                    }
                                ]
                                value: Config.lockscreen.position ?? "bottom"
                                onValueSelected: newValue => {
                                    if (newValue !== Config.lockscreen.position) {
                                        GlobalStates.markShellChanged();
                                        Config.lockscreen.position = newValue;
                                    }
                                }
                            }
                        }
                    }

                    Separator {
                        Layout.fillWidth: true
                        visible: false
                    }

                    // ═══════════════════════════════════════════════════════════════
                    // DESKTOP SECTION
                    // ═══════════════════════════════════════════════════════════════
                    ColumnLayout {
                        visible: root.currentSection === "desktop"
                        Layout.fillWidth: true
                        spacing: 8

                        HighlightRow {
                            highlightId: "desktop.enabled"

                            ToggleRow {
                                label: I18n.t("Enabled")
                                checked: Config.desktop.enabled ?? false
                                onToggled: value => {
                                    if (value !== Config.desktop.enabled) {
                                        GlobalStates.markShellChanged();
                                        Config.desktop.enabled = value;
                                    }
                                }
                            }
                        }

                        HighlightRow {
                            highlightId: "desktop.iconSize"

                            NumberInputRow {
                                label: I18n.t("Icon Size")
                                value: Config.desktop.iconSize ?? 40
                                minValue: 24
                                maxValue: 96
                                suffix: I18n.t("px")
                                onValueEdited: newValue => {
                                    if (newValue !== Config.desktop.iconSize) {
                                        GlobalStates.markShellChanged();
                                        Config.desktop.iconSize = newValue;
                                    }
                                }
                            }
                        }

                        HighlightRow {
                            highlightId: "desktop.spacingVertical"

                            NumberInputRow {
                                label: I18n.t("Vertical Spacing")
                                value: Config.desktop.spacingVertical ?? 16
                                minValue: 0
                                maxValue: 48
                                suffix: I18n.t("px")
                                onValueEdited: newValue => {
                                    if (newValue !== Config.desktop.spacingVertical) {
                                        GlobalStates.markShellChanged();
                                        Config.desktop.spacingVertical = newValue;
                                    }
                                }
                            }
                        }

                        // Text Color with ColorButton
                        HighlightRow {
                            highlightId: "desktop.textColor"

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: I18n.t("Text Color")
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(0)
                                    color: Colors.overBackground
                                    Layout.preferredWidth: 100
                                }

                                ColorButton {
                                    id: desktopTextColorButton
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 48
                                    colorNames: root.colorNames
                                    currentColor: Config.desktop.textColor ?? "overBackground"
                                    dialogTitle: "Desktop Text Color"
                                    compact: false

                                    onOpenColorPicker: (colorNames, currentColor, dialogTitle) => {
                                        root.openColorPicker(colorNames, currentColor, dialogTitle, function (color) {
                                            if (color !== Config.desktop.textColor) {
                                                GlobalStates.markShellChanged();
                                                Config.desktop.textColor = color;
                                            }
                                        });
                                    }
                                }

                                Separator {
                                    Layout.fillWidth: true
                                    visible: false
                                }

                                // ═══════════════════════════════════════════════════════════════
                                // SYSTEM SECTION
                                // ═══════════════════════════════════════════════════════════════
                                ColumnLayout {
                                    visible: root.currentSection === "system"
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: I18n.t("OCR Languages")
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-2)
                                        color: Styling.srItem("overprimary")
                                        font.bold: true
                                        Layout.topMargin: 8
                                    }

                                    HighlightRow {
                                        highlightId: "system.ocr.eng"

                                        ToggleRow {
                                            label: I18n.t("English")
                                            checked: Config.system.ocr.eng ?? true
                                            onToggled: value => {
                                                if (value !== Config.system.ocr.eng) {
                                                    GlobalStates.markShellChanged();
                                                    Config.system.ocr.eng = value;
                                                }
                                            }
                                        }
                                    }

                                    HighlightRow {
                                        highlightId: "system.ocr.spa"

                                        ToggleRow {
                                            label: I18n.t("Spanish")
                                            checked: Config.system.ocr.spa ?? true
                                            onToggled: value => {
                                                if (value !== Config.system.ocr.spa) {
                                                    GlobalStates.markShellChanged();
                                                    Config.system.ocr.spa = value;
                                                }
                                            }
                                        }
                                    }

                                    HighlightRow {
                                        highlightId: "system.ocr.lat"

                                        ToggleRow {
                                            label: I18n.t("Latin")
                                            checked: Config.system.ocr.lat ?? false
                                            onToggled: value => {
                                                if (value !== Config.system.ocr.lat) {
                                                    GlobalStates.markShellChanged();
                                                    Config.system.ocr.lat = value;
                                                }
                                            }
                                        }
                                    }

                                    HighlightRow {
                                        highlightId: "system.ocr.jpn"

                                        ToggleRow {
                                            label: I18n.t("Japanese")
                                            checked: Config.system.ocr.jpn ?? false
                                            onToggled: value => {
                                                if (value !== Config.system.ocr.jpn) {
                                                    GlobalStates.markShellChanged();
                                                    Config.system.ocr.jpn = value;
                                                }
                                            }
                                        }
                                    }

                                    HighlightRow {
                                        highlightId: "system.ocr.chi_sim"

                                        ToggleRow {
                                            label: I18n.t("Chinese (Simplified)")
                                            checked: Config.system.ocr.chi_sim ?? false
                                            onToggled: value => {
                                                if (value !== Config.system.ocr.chi_sim) {
                                                    GlobalStates.markShellChanged();
                                                    Config.system.ocr.chi_sim = value;
                                                }
                                            }
                                        }
                                    }

                                    HighlightRow {
                                        highlightId: "system.ocr.chi_tra"

                                        ToggleRow {
                                            label: I18n.t("Chinese (Traditional)")
                                            checked: Config.system.ocr.chi_tra ?? false
                                            onToggled: value => {
                                                if (value !== Config.system.ocr.chi_tra) {
                                                    GlobalStates.markShellChanged();
                                                    Config.system.ocr.chi_tra = value;
                                                }
                                            }
                                        }
                                    }

                                    HighlightRow {
                                        highlightId: "system.ocr.kor"

                                        ToggleRow {
                                            label: I18n.t("Korean")
                                            checked: Config.system.ocr.kor ?? false
                                            onToggled: value => {
                                                if (value !== Config.system.ocr.kor) {
                                                    GlobalStates.markShellChanged();
                                                    Config.system.ocr.kor = value;
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Color picker view (shown when colorPickerActive)
    Item {
        id: colorPickerContainer
        anchors.fill: parent
        clip: true

        // Horizontal slide + fade animation (enters from right)
        opacity: root.colorPickerActive ? 1 : 0
        transform: Translate {
            x: root.colorPickerActive ? 0 : 30

            Behavior on x {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 2
                    easing.type: Easing.OutQuart
                }
            }
        }

        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration / 2
                easing.type: Easing.OutQuart
            }
        }

        // Prevent interaction when hidden
        enabled: root.colorPickerActive

        // Block interaction with elements behind when active
        MouseArea {
            anchors.fill: parent
            enabled: root.colorPickerActive
            hoverEnabled: true
            acceptedButtons: Qt.AllButtons
            onPressed: event => event.accepted = true
            onReleased: event => event.accepted = true
            onWheel: event => event.accepted = true
        }

        ColorPickerView {
            id: colorPickerContent
            anchors.fill: parent
            anchors.leftMargin: root.sideMargin
            anchors.rightMargin: root.sideMargin
            colorNames: root.colorPickerColorNames
            currentColor: root.colorPickerCurrentColor
            dialogTitle: root.colorPickerDialogTitle

            onColorSelected: color => root.handleColorSelected(color)
            onClosed: root.closeColorPicker()
        }
    }
}
