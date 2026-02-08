pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.modules.theme
import qs.modules.components
import qs.modules.globals
import qs.config
import "../../../bar/BarItemRegistry.js" as BarItems

Item {
    id: root

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
    readonly property var barItemDefs: BarItems.items
    readonly property var barItemIds: BarItems.itemIds

    Component.onCompleted: {
        var barPos = Config.bar.position ?? "top";
        if (barPos === "left" || barPos === "right")
            ensureVerticalBarLists();
    }

    function sanitizeBarItems(list, allowedIds) {
        if (list === undefined || list === null || typeof list.length === "undefined")
            return [];

        var seen = {};
        var sanitized = [];
        for (var i = 0; i < list.length; i++) {
            var itemId = list[i];
            if (!barItemIds.includes(itemId))
                continue;
            if (allowedIds && !allowedIds.includes(itemId))
                continue;
            if (seen[itemId])
                continue;
            seen[itemId] = true;
            sanitized.push(itemId);
        }
        return sanitized;
    }

    function ensureVerticalBarLists() {
        var changed = false;
        if (Config.bar.itemsLeftVertical === undefined || Config.bar.itemsLeftVertical.length === 0) {
            Config.bar.itemsLeftVertical = ["launcher", "systray", "tools", "presets"];
            changed = true;
        }
        if (Config.bar.itemsCenterVertical === undefined || Config.bar.itemsCenterVertical.length === 0) {
            Config.bar.itemsCenterVertical = ["layout", "workspaces", "pin"];
            changed = true;
        }
        if (Config.bar.itemsRightVertical === undefined || Config.bar.itemsRightVertical.length === 0) {
            Config.bar.itemsRightVertical = ["controls", "battery", "clock", "power"];
            changed = true;
        }
        if (changed)
            GlobalStates.markShellChanged();
    }

    function getBarItems(groupId) {
        var barPos = Config.bar.position ?? "top";
        var isVertical = (barPos === "left" || barPos === "right");
        var verticalIds = BarItems.verticalItemIds || barItemIds;
        if (isVertical)
            ensureVerticalBarLists();
        if (groupId === "left")
            return isVertical
                ? sanitizeBarItems(Config.bar.itemsLeftVertical ?? ["launcher", "systray", "tools", "presets"], verticalIds)
                : sanitizeBarItems(Config.bar.itemsLeft);
        if (groupId === "center") {
            if (isVertical)
                return sanitizeBarItems(Config.bar.itemsCenterVertical ?? ["layout", "workspaces", "pin"], verticalIds);
            var centerItems = sanitizeBarItems(Config.bar.itemsCenter);
            var notchPos = Config.notchPosition ?? "top";
            if ((barPos === "top" && notchPos === "top") || (barPos === "bottom" && notchPos === "bottom")) {
                if (Config.bar.centerItemsSplitByNotch === false)
                    return centerItems;
                if (!centerItems.includes("notch"))
                    centerItems.push("notch");
            }
            return centerItems;
        }
        return isVertical
            ? sanitizeBarItems(Config.bar.itemsRightVertical ?? ["controls", "battery", "clock", "power"], verticalIds)
            : sanitizeBarItems(Config.bar.itemsRight);
    }

    function availableBarItems(groupId) {
        var current = getBarItems(groupId);
        var available = [];
        var barPos = Config.bar.position ?? "top";
        var isVertical = (barPos === "left" || barPos === "right");
        var verticalIds = BarItems.verticalItemIds || barItemIds;
        if (isVertical)
            ensureVerticalBarLists();
        for (var i = 0; i < barItemDefs.length; i++) {
            var def = barItemDefs[i];
            if (def.id === "notch" && (isVertical || groupId !== "center"))
                continue;
            if (isVertical && !verticalIds.includes(def.id))
                continue;
            if (!current.includes(def.id))
                available.push(def);
        }
        return available;
    }

    function applyBarItemsUpdate(groupId, newItems) {
        var barPos = Config.bar.position ?? "top";
        var isVertical = (barPos === "left" || barPos === "right");
        var verticalIds = BarItems.verticalItemIds || barItemIds;
        if (isVertical)
            ensureVerticalBarLists();
        var cleaned = sanitizeBarItems(newItems, isVertical ? verticalIds : null);
        var left = isVertical
            ? sanitizeBarItems(Config.bar.itemsLeftVertical ?? [], verticalIds)
            : sanitizeBarItems(Config.bar.itemsLeft);
        var center = isVertical
            ? sanitizeBarItems(Config.bar.itemsCenterVertical ?? [], verticalIds)
            : sanitizeBarItems(Config.bar.itemsCenter);
        var right = isVertical
            ? sanitizeBarItems(Config.bar.itemsRightVertical ?? [], verticalIds)
            : sanitizeBarItems(Config.bar.itemsRight);

        if (groupId === "left") {
            center = center.filter(itemId => !cleaned.includes(itemId));
            right = right.filter(itemId => !cleaned.includes(itemId));
            left = cleaned;
        } else if (groupId === "center") {
            left = left.filter(itemId => !cleaned.includes(itemId));
            right = right.filter(itemId => !cleaned.includes(itemId));
            center = cleaned;
        } else {
            left = left.filter(itemId => !cleaned.includes(itemId));
            center = center.filter(itemId => !cleaned.includes(itemId));
            right = cleaned;
        }

        if (!isVertical) {
            var notchPos = Config.notchPosition ?? "top";
            if ((barPos === "top" && notchPos === "top") || (barPos === "bottom" && notchPos === "bottom")) {
                if (Config.bar.centerItemsSplitByNotch === false) {
                    center = center.filter(itemId => itemId !== "notch");
                } else if (!center.includes("notch")) {
                    center.push("notch");
                }
            } else {
                center = center.filter(itemId => itemId !== "notch");
            }
        } else {
            center = center.filter(itemId => itemId !== "notch");
        }

        GlobalStates.markShellChanged();
        if (isVertical) {
            Config.bar.itemsLeftVertical = left;
            Config.bar.itemsCenterVertical = center;
            Config.bar.itemsRightVertical = right;
        } else {
            Config.bar.itemsLeft = left;
            Config.bar.itemsCenter = center;
            Config.bar.itemsRight = right;
        }
        if (typeof Config.saveBar === "function")
            Config.saveBar();
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
            }

            Text {
                text: Icons.caretRight
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

    component ActionButton: StyledRect {
        id: actionBtn
        required property string text
        property string icon: ""
        signal clicked

        property bool isHovered: false

        variant: isHovered ? "focus" : "pane"
        Layout.fillWidth: true
        Layout.preferredHeight: 56
        radius: Styling.radius(0)

        RowLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 16

            Text {
                text: actionBtn.icon
                font.family: Icons.font
                font.pixelSize: 20
                color: Colors.overSurfaceVariant
                visible: actionBtn.icon !== ""
            }

            Text {
                text: actionBtn.text
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(0)
                font.bold: true
                color: Colors.overBackground
                Layout.fillWidth: true
            }

            Text {
                text: Icons.arrowSquareOut
                font.family: Icons.font
                font.pixelSize: 18
                color: Colors.overSurfaceVariant
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: actionBtn.isHovered = true
            onExited: actionBtn.isHovered = false
            onClicked: actionBtn.clicked()
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
        spacing: 8

        Text {
            text: toggleRowRoot.label
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(0)
            color: Colors.overBackground
            Layout.fillWidth: true
        }

        Switch {
            id: toggleSwitch
            checked: toggleRowRoot.checked

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
        spacing: 8

        Text {
            text: numberInputRowRoot.label
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(0)
            color: Colors.overBackground
            Layout.fillWidth: true
        }

        StyledRect {
            variant: "common"
            Layout.preferredWidth: 60
            Layout.preferredHeight: 32
            radius: Styling.radius(-2)

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
        spacing: 8

        Text {
            text: textInputRowRoot.label
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(0)
            color: Colors.overBackground
            Layout.preferredWidth: 100
        }

        StyledRect {
            variant: "common"
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            radius: Styling.radius(-2)

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
        spacing: 4

        Text {
            text: selectorRowRoot.label
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            font.weight: Font.Medium
            color: Colors.overSurfaceVariant
            visible: selectorRowRoot.label !== ""
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 4

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
                        anchors.left: parent.left
                        anchors.leftMargin: 12
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
        property string label: "Screens"
        property var selectedScreens: []  // Array of screen names
        signal screensChanged(var newList)

        Layout.fillWidth: true
        spacing: 4

        Text {
            text: screenListRowRoot.label
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            font.weight: Font.Medium
            color: Colors.overSurfaceVariant
        }

        Text {
            text: "Empty = all screens"
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            color: Colors.outline
            Layout.bottomMargin: 4
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

    component StyledSelect: ComboBox {
        id: styledSelectRoot
        property string placeholder: ""

        Layout.fillWidth: true
        Layout.preferredHeight: 32

        background: StyledRect {
            variant: styledSelectRoot.hovered ? "focus" : "common"
            radius: Styling.radius(-2)
            enableShadow: true
        }

        contentItem: Text {
            text: {
                if (styledSelectRoot.currentIndex < 0 || styledSelectRoot.currentText === "")
                    return styledSelectRoot.placeholder;
                return styledSelectRoot.currentText;
            }
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            color: Colors.overBackground
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 24
        }

        indicator: Text {
            x: styledSelectRoot.width - width - 10
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.caretDown
            font.family: Icons.font
            font.pixelSize: 16
            color: Colors.overSurfaceVariant
        }

        popup: Popup {
            y: styledSelectRoot.height + 4
            width: Math.max(styledSelectRoot.width, popupList.contentWidth + 8)
            implicitHeight: popupList.contentHeight > 240 ? 240 : popupList.contentHeight
            padding: 4
            modal: true
            focus: true
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

            background: StyledRect {
                variant: "pane"
                radius: Styling.radius(-1)
                enableShadow: true
            }

            contentItem: ListView {
                id: popupList
                implicitWidth: styledSelectRoot.width
                model: styledSelectRoot.model
                clip: true
                spacing: 4

                delegate: StyledRect {
                    id: optionRect
                    required property var modelData
                    required property int index

                    property bool isHovered: false

                    variant: styledSelectRoot.currentIndex === index ? "primary" : (optionRect.isHovered ? "focus" : "common")
                    radius: Styling.radius(-2)
                    height: 32
                    width: popupList.width
                    enableShadow: false

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        text: (typeof optionRect.modelData === "string") ? optionRect.modelData : (optionRect.modelData && optionRect.modelData.text ? optionRect.modelData.text : "")
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        color: optionRect.item
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: optionRect.isHovered = true
                        onExited: optionRect.isHovered = false
                        onClicked: {
                            styledSelectRoot.currentIndex = optionRect.index;
                            styledSelectRoot.popup.close();
                            styledSelectRoot.activated(optionRect.index);
                        }
                    }
                }
            }
        }
    }

    component BarItemsList: ColumnLayout {
        id: barItemsListRoot
        required property string label
        required property string groupId
        required property var items
        required property var availableItems
        property bool readOnly: false
        signal itemsUpdated(var newList)

        property int rowHeight: 40

        Layout.fillWidth: true
        spacing: 8

        Text {
            text: barItemsListRoot.label
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            font.weight: Font.Medium
            color: Colors.overSurfaceVariant
        }

        ListView {
            id: itemsList
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(barItemsListRoot.rowHeight, contentHeight)
            Layout.minimumHeight: barItemsListRoot.rowHeight
            spacing: 6
            interactive: false
            clip: true
            model: barItemsListRoot.items ?? []

            delegate: StyledRect {
                id: delegateItem
                required property string modelData
                required property int index

                property real originalY: 0
                property bool held: dragArea.pressed

                width: itemsList.width
                height: barItemsListRoot.rowHeight
                variant: "pane"
                radius: Styling.radius(-2)

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8

                        Text {
                            text: Icons.dotsNine
                            font.family: Icons.font
                            font.pixelSize: 14
                            color: Colors.overSurfaceVariant
                            Layout.alignment: Qt.AlignVCenter
                        }

                    Text {
                        text: {
                            for (var i = 0; i < barItemDefs.length; i++) {
                                if (barItemDefs[i].id === delegateItem.modelData)
                                    return barItemDefs[i].label;
                            }
                            return delegateItem.modelData;
                        }
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(0)
                        color: Colors.overBackground
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                StyledRect {
                    id: removeButton
                    width: 28
                    height: 28
                    radius: Styling.radius(-2)
                    variant: "common"
                    visible: !barItemsListRoot.readOnly && delegateItem.modelData !== "notch"

                        Text {
                            anchors.centerIn: parent
                            text: Icons.trash
                            font.family: Icons.font
                            font.pixelSize: 14
                            color: Colors.overSurfaceVariant
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var newItems = barItemsListRoot.items.slice();
                                newItems.splice(delegateItem.index, 1);
                                barItemsListRoot.itemsUpdated(newItems);
                            }
                        }
                    }
                }

                MouseArea {
                    id: dragArea
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 48
                    hoverEnabled: true
                    cursorShape: Qt.SizeVerCursor
                    enabled: !barItemsListRoot.readOnly
                    drag.target: held ? delegateItem : undefined
                    drag.axis: Drag.YAxis
                    drag.minimumY: -delegateItem.height
                    drag.maximumY: itemsList.height
                    preventStealing: true

                    onPressed: {
                        delegateItem.z = 2;
                        delegateItem.originalY = delegateItem.y;
                    }
                    onReleased: {
                        delegateItem.z = 1;
                        if (drag.active) {
                            var newIndex = Math.round(delegateItem.y / (delegateItem.height + itemsList.spacing));
                            newIndex = Math.max(0, Math.min(newIndex, barItemsListRoot.items.length - 1));
                            if (newIndex !== delegateItem.index) {
                                var newItems = barItemsListRoot.items.slice();
                                var draggedItem = newItems.splice(delegateItem.index, 1)[0];
                                newItems.splice(newIndex, 0, draggedItem);
                                barItemsListRoot.itemsUpdated(newItems);
                            }
                        }
                        delegateItem.x = 0;
                        delegateItem.y = delegateItem.originalY;
                    }
                }

                Behavior on y {
                    enabled: !dragArea.held && !dragArea.drag.active
                    NumberAnimation {
                        duration: Config.animDuration > 0 ? Config.animDuration / 2 : 0
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            spacing: 8
            visible: !barItemsListRoot.readOnly

            StyledSelect {
                id: addComboBox
                Layout.fillWidth: true
                model: barItemsListRoot.availableItems.map(item => item.label)
                currentIndex: 0
                enabled: barItemsListRoot.availableItems.length > 0
                placeholder: "Select item"
            }

            StyledRect {
                id: addButton
                Layout.preferredWidth: 80
                Layout.preferredHeight: 32
                radius: Styling.radius(-2)
                variant: barItemsListRoot.availableItems.length > 0 ? "primary" : "common"
                enableShadow: barItemsListRoot.availableItems.length > 0

                Text {
                    anchors.centerIn: parent
                    text: "Add"
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    font.weight: Font.Medium
                    color: addButton.item
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: barItemsListRoot.availableItems.length > 0
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (barItemsListRoot.availableItems.length === 0)
                            return;
                        var selectedItem = barItemsListRoot.availableItems[addComboBox.currentIndex];
                        if (!selectedItem)
                            return;
                        var newItems = (barItemsListRoot.items ?? []).slice();
                        newItems.push(selectedItem.id);
                        barItemsListRoot.itemsUpdated(newItems);
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

            // Header wrapper
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: titlebar.height

                PanelTitlebar {
                    id: titlebar
                    width: root.contentWidth
                    anchors.horizontalCenter: parent.horizontalCenter
                    title: root.currentSection === "" ? "Shell" : (root.currentSection.charAt(0).toUpperCase() + root.currentSection.slice(1))
                    statusText: GlobalStates.shellHasChanges ? "Unsaved changes" : ""
                    statusColor: Colors.error

                    actions: {
                        let baseActions = [
                            {
                                icon: Icons.arrowCounterClockwise,
                                tooltip: "Discard changes",
                                enabled: GlobalStates.shellHasChanges,
                                onClicked: function () {
                                    GlobalStates.discardShellChanges();
                                }
                            },
                            {
                                icon: Icons.disk,
                                tooltip: "Apply changes",
                                enabled: GlobalStates.shellHasChanges,
                                onClicked: function () {
                                    GlobalStates.applyShellChanges();
                                }
                            }
                        ];

                        if (root.currentSection !== "") {
                            return [
                                {
                                    icon: Icons.arrowLeft,
                                    tooltip: "Back",
                                    onClicked: function () {
                                        root.currentSection = "";
                                    }
                                }
                            ].concat(baseActions);
                        }

                        return baseActions;
                    }
                }
            }

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
                            text: "Bar"
                            sectionId: "bar"
                        }
                        SectionButton {
                            text: "Frame"
                            sectionId: "frame"
                        }
                        SectionButton {
                            text: "Notch"
                            sectionId: "notch"
                        }
                        SectionButton {
                            text: "Workspaces"
                            sectionId: "workspaces"
                        }
                        SectionButton {
                            text: "Overview"
                            sectionId: "overview"
                        }
                        SectionButton {
                            text: "Dock"
                            sectionId: "dock"
                        }
                        SectionButton {
                            text: "Lockscreen"
                            sectionId: "lockscreen"
                        }
                        SectionButton {
                            text: "Desktop"
                            sectionId: "desktop"
                        }
                        SectionButton {
                            text: "System"
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

                        Text {
                            text: "Bar"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: Font.Medium
                            color: Colors.overSurfaceVariant
                            Layout.bottomMargin: -4
                        }

                        SelectorRow {
                            label: ""
                            options: [
                                {
                                    label: "Top",
                                    value: "top",
                                    icon: Icons.arrowUp
                                },
                                {
                                    label: "Bottom",
                                    value: "bottom",
                                    icon: Icons.arrowDown
                                },
                                {
                                    label: "Left",
                                    value: "left",
                                    icon: Icons.arrowLeft
                                },
                                {
                                    label: "Right",
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

                        Text {
                            text: "Bar Items"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: Font.Medium
                            color: Colors.overSurfaceVariant
                            Layout.topMargin: 8
                        }

                        BarItemsList {
                            label: "Left Group"
                            groupId: "left"
                            items: root.getBarItems("left")
                            availableItems: root.availableBarItems("left")
                            onItemsUpdated: newList => {
                                root.applyBarItemsUpdate("left", newList);
                            }
                        }

                        BarItemsList {
                            label: "Center Group"
                            groupId: "center"
                            items: root.getBarItems("center")
                            availableItems: root.availableBarItems("center")
                            onItemsUpdated: newList => {
                                root.applyBarItemsUpdate("center", newList);
                            }
                        }

                        BarItemsList {
                            label: "Right Group"
                            groupId: "right"
                            items: root.getBarItems("right")
                            availableItems: root.availableBarItems("right")
                            onItemsUpdated: newList => {
                                root.applyBarItemsUpdate("right", newList);
                            }
                        }

                        TextInputRow {
                            label: "Launcher Icon"
                            value: Config.bar.launcherIcon ?? ""
                            placeholder: "Symbol or path to icon..."
                            onValueEdited: newValue => {
                                if (newValue !== Config.bar.launcherIcon) {
                                    GlobalStates.markShellChanged();
                                    Config.bar.launcherIcon = newValue;
                                }
                            }
                        }

                        ToggleRow {
                            label: "Launcher Icon Tint"
                            checked: Config.bar.launcherIconTint ?? true
                            onToggled: value => {
                                if (value !== Config.bar.launcherIconTint) {
                                    GlobalStates.markShellChanged();
                                    Config.bar.launcherIconTint = value;
                                }
                            }
                        }

                        ToggleRow {
                            label: "Launcher Icon Full Tint"
                            checked: Config.bar.launcherIconFullTint ?? true
                            onToggled: value => {
                                if (value !== Config.bar.launcherIconFullTint) {
                                    GlobalStates.markShellChanged();
                                    Config.bar.launcherIconFullTint = value;
                                }
                            }
                        }

                        NumberInputRow {
                            label: "Launcher Icon Size"
                            value: Config.bar.launcherIconSize ?? 24
                            minValue: 12
                            maxValue: 64
                            suffix: "px"
                            onValueEdited: newValue => {
                                if (newValue !== Config.bar.launcherIconSize) {
                                    GlobalStates.markShellChanged();
                                    Config.bar.launcherIconSize = newValue;
                                }
                            }
                        }

                        SelectorRow {
                            label: "Pill Style"
                            options: [
                                {
                                    label: "Default",
                                    value: "default"
                                },
                                {
                                    label: "Squished",
                                    value: "squished"
                                }
                            ]
                            value: Config.bar.pillStyle ?? "default"
                            onValueSelected: newValue => {
                                if (newValue !== Config.bar.pillStyle) {
                                    GlobalStates.markShellChanged();
                                    Config.bar.pillStyle = newValue;
                                }
                            }
                        }

                        ToggleRow {
                            label: "Use 12h Format"
                            checked: Config.bar.use12hFormat ?? false
                            onToggled: value => {
                                if (value !== Config.bar.use12hFormat) {
                                    GlobalStates.markShellChanged();
                                    Config.bar.use12hFormat = value;
                                }
                            }
                        }

                        ToggleRow {
                            label: "Enable Firefox Player"
                            checked: Config.bar.enableFirefoxPlayer ?? false
                            onToggled: value => {
                                if (value !== Config.bar.enableFirefoxPlayer) {
                                    GlobalStates.markShellChanged();
                                    Config.bar.enableFirefoxPlayer = value;
                                }
                            }
                        }

                        Separator {
                            Layout.fillWidth: true
                        }

                        Text {
                            text: "Auto-hide"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: Font.Medium
                            color: Colors.overSurfaceVariant
                            Layout.bottomMargin: -4
                        }

                        ToggleRow {
                            label: "Pinned on Startup"
                            checked: Config.bar.pinnedOnStartup ?? true
                            onToggled: value => {
                                if (value !== Config.bar.pinnedOnStartup) {
                                    GlobalStates.markShellChanged();
                                    Config.bar.pinnedOnStartup = value;
                                }
                            }
                        }

                        ToggleRow {
                            label: "Hover to Reveal"
                            checked: Config.bar.hoverToReveal ?? true
                            onToggled: value => {
                                if (value !== Config.bar.hoverToReveal) {
                                    GlobalStates.markShellChanged();
                                    Config.bar.hoverToReveal = value;
                                }
                            }
                        }

                        NumberInputRow {
                            label: "Hover Region Height"
                            value: Config.bar.hoverRegionHeight ?? 8
                            minValue: 0
                            maxValue: 32
                            suffix: "px"
                            onValueEdited: newValue => {
                                if (newValue !== Config.bar.hoverRegionHeight) {
                                    GlobalStates.markShellChanged();
                                    Config.bar.hoverRegionHeight = newValue;
                                }
                            }
                        }

                        ToggleRow {
                            label: "Show Pin Button"
                            checked: Config.bar.showPinButton ?? true
                            onToggled: value => {
                                if (value !== Config.bar.showPinButton) {
                                    GlobalStates.markShellChanged();
                                    Config.bar.showPinButton = value;
                                }
                            }
                        }

                        ToggleRow {
                            label: "Available on Fullscreen"
                            checked: Config.bar.availableOnFullscreen ?? false
                            onToggled: value => {
                                if (value !== Config.bar.availableOnFullscreen) {
                                    GlobalStates.markShellChanged();
                                    Config.bar.availableOnFullscreen = value;
                                }
                            }
                        }

                        ScreenListRow {
                            label: "Screens"
                            selectedScreens: Config.bar.screenList ?? []
                            onScreensChanged: newList => {
                                GlobalStates.markShellChanged();
                                Config.bar.screenList = newList;
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

                        Text {
                            text: "Frame"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: Font.Medium
                            color: Colors.overSurfaceVariant
                            Layout.bottomMargin: -4
                        }

                        ToggleRow {
                            label: "Enabled"
                            checked: Config.bar.frameEnabled ?? false
                            onToggled: value => {
                                if (value !== Config.bar.frameEnabled) {
                                    GlobalStates.markShellChanged();
                                    Config.bar.frameEnabled = value;
                                }
                            }
                        }

                        NumberInputRow {
                            label: "Thickness"
                            value: Config.bar.frameThickness ?? 6
                            minValue: 1
                            maxValue: 40
                            suffix: "px"
                            onValueEdited: newValue => {
                                if (newValue !== Config.bar.frameThickness) {
                                    GlobalStates.markShellChanged();
                                    Config.bar.frameThickness = newValue;
                                }
                            }
                        }

                        ToggleRow {
                            label: "Contain Bar"
                            checked: Config.bar.containBar ?? false
                            onToggled: value => {
                                if (value !== Config.bar.containBar) {
                                    GlobalStates.markShellChanged();
                                    Config.bar.containBar = value;
                                }
                            }
                        }

                        ToggleRow {
                            label: "Keep Bar Shadow"
                            checked: Config.bar.keepBarShadow ?? false
                            visible: Config.bar.containBar ?? false
                            onToggled: value => {
                                if (value !== Config.bar.keepBarShadow) {
                                    GlobalStates.markShellChanged();
                                    Config.bar.keepBarShadow = value;
                                }
                            }
                        }

                        ToggleRow {
                            label: "Keep Bar Border"
                            checked: Config.bar.keepBarBorder ?? false
                            visible: Config.bar.containBar ?? false
                            onToggled: value => {
                                if (value !== Config.bar.keepBarBorder) {
                                    GlobalStates.markShellChanged();
                                    Config.bar.keepBarBorder = value;
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

                        Text {
                            text: "Notch"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: Font.Medium
                            color: Colors.overSurfaceVariant
                            Layout.bottomMargin: -4
                        }

                        SelectorRow {
                            label: ""
                            options: [
                                {
                                    label: "Top",
                                    value: "top",
                                    icon: Icons.arrowUp
                                },
                                {
                                    label: "Bottom",
                                    value: "bottom",
                                    icon: Icons.arrowDown
                                }
                            ]
                            value: Config.notch.position ?? "top"
                            onValueSelected: newValue => {
                                if (newValue !== Config.notch.position) {
                                    GlobalStates.markShellChanged();
                                    Config.notch.position = newValue;
                                }
                            }
                        }

                        SelectorRow {
                            label: ""
                            options: [
                                {
                                    label: "Default",
                                    value: "default"
                                },
                                {
                                    label: "Island",
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

                        NumberInputRow {
                            label: "Hover Region Height"
                            value: Config.notch.hoverRegionHeight ?? 8
                            minValue: 0
                            maxValue: 32
                            suffix: "px"
                            onValueEdited: newValue => {
                                if (newValue !== Config.notch.hoverRegionHeight) {
                                    GlobalStates.markShellChanged();
                                    Config.notch.hoverRegionHeight = newValue;
                                }
                            }
                        }

                        ToggleRow {
                            label: "Keep Hidden"
                            checked: Config.notch.keepHidden ?? false
                            onToggled: value => {
                                if (value !== Config.notch.keepHidden) {
                                    GlobalStates.markShellChanged();
                                    Config.notch.keepHidden = value;
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

                        Text {
                            text: "Workspaces"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: Font.Medium
                            color: Colors.overSurfaceVariant
                            Layout.bottomMargin: -4
                        }

                        NumberInputRow {
                            label: "Shown"
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

                        ToggleRow {
                            label: "Show App Icons"
                            checked: Config.workspaces.showAppIcons ?? true
                            onToggled: value => {
                                if (value !== Config.workspaces.showAppIcons) {
                                    GlobalStates.markShellChanged();
                                    Config.workspaces.showAppIcons = value;
                                }
                            }
                        }

                        ToggleRow {
                            label: "Always Show Numbers"
                            checked: Config.workspaces.alwaysShowNumbers ?? false
                            onToggled: value => {
                                if (value !== Config.workspaces.alwaysShowNumbers) {
                                    GlobalStates.markShellChanged();
                                    Config.workspaces.alwaysShowNumbers = value;
                                }
                            }
                        }

                        ToggleRow {
                            label: "Show Numbers"
                            checked: Config.workspaces.showNumbers ?? false
                            onToggled: value => {
                                if (value !== Config.workspaces.showNumbers) {
                                    GlobalStates.markShellChanged();
                                    Config.workspaces.showNumbers = value;
                                }
                            }
                        }

                        ToggleRow {
                            label: "Dynamic"
                            checked: Config.workspaces.dynamic ?? false
                            onToggled: value => {
                                if (value !== Config.workspaces.dynamic) {
                                    GlobalStates.markShellChanged();
                                    Config.workspaces.dynamic = value;
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

                        Text {
                            text: "Overview"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: Font.Medium
                            color: Colors.overSurfaceVariant
                            Layout.bottomMargin: -4
                        }

                        NumberInputRow {
                            label: "Rows"
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

                        NumberInputRow {
                            label: "Columns"
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

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "Scale"
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

                        NumberInputRow {
                            label: "Workspace Spacing"
                            value: Config.overview.workspaceSpacing ?? 4
                            minValue: 0
                            maxValue: 20
                            suffix: "px"
                            onValueEdited: newValue => {
                                if (newValue !== Config.overview.workspaceSpacing) {
                                    GlobalStates.markShellChanged();
                                    Config.overview.workspaceSpacing = newValue;
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

                        Text {
                            text: "Dock"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: Font.Medium
                            color: Colors.overSurfaceVariant
                            Layout.bottomMargin: -4
                        }

                        ToggleRow {
                            label: "Enabled"
                            checked: Config.dock.enabled ?? false
                            onToggled: value => {
                                if (value !== Config.dock.enabled) {
                                    GlobalStates.markShellChanged();
                                    Config.dock.enabled = value;
                                }
                            }
                        }

                        SelectorRow {
                            label: "Position"
                            options: [
                                {
                                    label: "Top",
                                    value: "top",
                                    icon: Icons.arrowUp
                                },
                                {
                                    label: "Bottom",
                                    value: "bottom",
                                    icon: Icons.arrowDown
                                },
                                {
                                    label: "Left",
                                    value: "left",
                                    icon: Icons.arrowLeft
                                },
                                {
                                    label: "Right",
                                    value: "right",
                                    icon: Icons.arrowRight
                                }
                            ]
                            value: Config.dock.position ?? "bottom"
                            onValueSelected: newValue => {
                                if (newValue !== Config.dock.position) {
                                    GlobalStates.markShellChanged();
                                    Config.dock.position = newValue;
                                }
                            }
                        }

                        SelectorRow {
                            label: "Theme"
                            options: [
                                {
                                    label: "Default",
                                    value: "default"
                                },
                                {
                                    label: "Floating",
                                    value: "floating"
                                },
                                {
                                    label: "Integrated",
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

                        NumberInputRow {
                            label: "Height"
                            visible: (Config.dock.theme ?? "default") !== "integrated"
                            value: Config.dock.height ?? 48
                            minValue: 32
                            maxValue: 128
                            suffix: "px"
                            onValueEdited: newValue => {
                                if (newValue !== Config.dock.height) {
                                    GlobalStates.markShellChanged();
                                    Config.dock.height = newValue;
                                }
                            }
                        }

                        NumberInputRow {
                            label: "Icon Size"
                            visible: (Config.dock.theme ?? "default") !== "integrated"
                            value: Config.dock.iconSize ?? 40
                            minValue: 24
                            maxValue: 96
                            suffix: "px"
                            onValueEdited: newValue => {
                                if (newValue !== Config.dock.iconSize) {
                                    GlobalStates.markShellChanged();
                                    Config.dock.iconSize = newValue;
                                }
                            }
                        }

                        NumberInputRow {
                            label: "Spacing"
                            visible: (Config.dock.theme ?? "default") !== "integrated"
                            value: Config.dock.spacing ?? 10
                            minValue: 0
                            maxValue: 32
                            suffix: "px"
                            onValueEdited: newValue => {
                                if (newValue !== Config.dock.spacing) {
                                    GlobalStates.markShellChanged();
                                    Config.dock.spacing = newValue;
                                }
                            }
                        }

                        NumberInputRow {
                            label: "Margin"
                            visible: (Config.dock.theme ?? "default") !== "integrated"
                            value: Config.dock.margin ?? 8
                            minValue: 0
                            maxValue: 32
                            suffix: "px"
                            onValueEdited: newValue => {
                                if (newValue !== Config.dock.margin) {
                                    GlobalStates.markShellChanged();
                                    Config.dock.margin = newValue;
                                }
                            }
                        }

                        ToggleRow {
                            label: "Hover to Reveal"
                            visible: (Config.dock.theme ?? "default") !== "integrated"
                            checked: Config.dock.hoverToReveal ?? true
                            onToggled: value => {
                                if (value !== Config.dock.hoverToReveal) {
                                    GlobalStates.markShellChanged();
                                    Config.dock.hoverToReveal = value;
                                }
                            }
                        }

                        NumberInputRow {
                            label: "Hover Region"
                            visible: (Config.dock.theme ?? "default") !== "integrated"
                            value: Config.dock.hoverRegionHeight ?? 8
                            minValue: 0
                            maxValue: 32
                            suffix: "px"
                            onValueEdited: newValue => {
                                if (newValue !== Config.dock.hoverRegionHeight) {
                                    GlobalStates.markShellChanged();
                                    Config.dock.hoverRegionHeight = newValue;
                                }
                            }
                        }

                        ToggleRow {
                            label: "Pinned on Startup"
                            visible: (Config.dock.theme ?? "default") !== "integrated"
                            checked: Config.dock.pinnedOnStartup ?? true
                            onToggled: value => {
                                if (value !== Config.dock.pinnedOnStartup) {
                                    GlobalStates.markShellChanged();
                                    Config.dock.pinnedOnStartup = value;
                                }
                            }
                        }

                        ToggleRow {
                            label: "Show Pin Button"
                            visible: (Config.dock.theme ?? "default") !== "integrated"
                            checked: Config.dock.showPinButton ?? true
                            onToggled: value => {
                                if (value !== Config.dock.showPinButton) {
                                    GlobalStates.markShellChanged();
                                    Config.dock.showPinButton = value;
                                }
                            }
                        }

                        ToggleRow {
                            label: "Available on Fullscreen"
                            visible: (Config.dock.theme ?? "default") !== "integrated"
                            checked: Config.dock.availableOnFullscreen ?? false
                            onToggled: value => {
                                if (value !== Config.dock.availableOnFullscreen) {
                                    GlobalStates.markShellChanged();
                                    Config.dock.availableOnFullscreen = value;
                                }
                            }
                        }

                        ToggleRow {
                            label: "Keep Hidden"
                            visible: (Config.dock.theme ?? "default") !== "integrated"
                            checked: Config.dock.keepHidden ?? false
                            onToggled: value => {
                                if (value !== Config.dock.keepHidden) {
                                    GlobalStates.markShellChanged();
                                    Config.dock.keepHidden = value;
                                }
                            }
                        }

                        ToggleRow {
                            label: "Show Running Indicators"
                            visible: (Config.dock.theme ?? "default") !== "integrated"
                            checked: Config.dock.showRunningIndicators ?? true
                            onToggled: value => {
                                if (value !== Config.dock.showRunningIndicators) {
                                    GlobalStates.markShellChanged();
                                    Config.dock.showRunningIndicators = value;
                                }
                            }
                        }

                        ToggleRow {
                            label: "Show Overview Button"
                            visible: (Config.dock.theme ?? "default") !== "integrated"
                            checked: Config.dock.showOverviewButton ?? true
                            onToggled: value => {
                                if (value !== Config.dock.showOverviewButton) {
                                    GlobalStates.markShellChanged();
                                    Config.dock.showOverviewButton = value;
                                }
                            }
                        }

                        ScreenListRow {
                            label: "Screens"
                            visible: (Config.dock.theme ?? "default") !== "integrated"
                            selectedScreens: Config.dock.screenList ?? []
                            onScreensChanged: newList => {
                                GlobalStates.markShellChanged();
                                Config.dock.screenList = newList;
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

                        Text {
                            text: "Lockscreen"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: Font.Medium
                            color: Colors.overSurfaceVariant
                            Layout.bottomMargin: -4
                        }

                        SelectorRow {
                            label: ""
                            options: [
                                {
                                    label: "Top",
                                    value: "top",
                                    icon: Icons.arrowUp
                                },
                                {
                                    label: "Bottom",
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

                        Text {
                            text: "Desktop"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: Font.Medium
                            color: Colors.overSurfaceVariant
                            Layout.bottomMargin: -4
                        }

                        ToggleRow {
                            label: "Enabled"
                            checked: Config.desktop.enabled ?? false
                            onToggled: value => {
                                if (value !== Config.desktop.enabled) {
                                    GlobalStates.markShellChanged();
                                    Config.desktop.enabled = value;
                                }
                            }
                        }

                        NumberInputRow {
                            label: "Icon Size"
                            value: Config.desktop.iconSize ?? 40
                            minValue: 24
                            maxValue: 96
                            suffix: "px"
                            onValueEdited: newValue => {
                                if (newValue !== Config.desktop.iconSize) {
                                    GlobalStates.markShellChanged();
                                    Config.desktop.iconSize = newValue;
                                }
                            }
                        }

                        NumberInputRow {
                            label: "Vertical Spacing"
                            value: Config.desktop.spacingVertical ?? 16
                            minValue: 0
                            maxValue: 48
                            suffix: "px"
                            onValueEdited: newValue => {
                                if (newValue !== Config.desktop.spacingVertical) {
                                    GlobalStates.markShellChanged();
                                    Config.desktop.spacingVertical = newValue;
                                }
                            }
                        }

                        // Text Color with ColorButton
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "Text Color"
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
                            text: "System"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: Font.Medium
                            color: Colors.overSurfaceVariant
                            Layout.bottomMargin: -4
                        }

                        ToggleRow {
                            label: "Update Service"
                            checked: Config.system.updateServiceEnabled ?? true
                            onToggled: value => {
                                if (value !== Config.system.updateServiceEnabled) {
                                    GlobalStates.markShellChanged();
                                    Config.system.updateServiceEnabled = value;
                                }
                            }
                        }

                        ActionButton {
                            text: "About Ambxst " + Config.version
                            icon: Icons.info
                            onClicked: Quickshell.execDetached(["xdg-open", "https://axeni.de/ambxst"])
                        }

                        ActionButton {
                            text: "Donate ❤️"
                            icon: Icons.heart
                            onClicked: Quickshell.execDetached(["xdg-open", "https://axeni.de/donate"])
                        }

                        Text {
                            text: "OCR Languages"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            color: Styling.srItem("overprimary")
                            font.bold: true
                            Layout.topMargin: 8
                        }

                        ToggleRow {
                            label: "English"
                            checked: Config.system.ocr.eng ?? true
                            onToggled: value => {
                                if (value !== Config.system.ocr.eng) {
                                    GlobalStates.markShellChanged();
                                    Config.system.ocr.eng = value;
                                }
                            }
                        }

                        ToggleRow {
                            label: "Spanish"
                            checked: Config.system.ocr.spa ?? true
                            onToggled: value => {
                                if (value !== Config.system.ocr.spa) {
                                    GlobalStates.markShellChanged();
                                    Config.system.ocr.spa = value;
                                }
                            }
                        }

                        ToggleRow {
                            label: "Latin"
                            checked: Config.system.ocr.lat ?? false
                            onToggled: value => {
                                if (value !== Config.system.ocr.lat) {
                                    GlobalStates.markShellChanged();
                                    Config.system.ocr.lat = value;
                                }
                            }
                        }

                        ToggleRow {
                            label: "Japanese"
                            checked: Config.system.ocr.jpn ?? false
                            onToggled: value => {
                                if (value !== Config.system.ocr.jpn) {
                                    GlobalStates.markShellChanged();
                                    Config.system.ocr.jpn = value;
                                }
                            }
                        }

                        ToggleRow {
                            label: "Chinese (Simplified)"
                            checked: Config.system.ocr.chi_sim ?? false
                            onToggled: value => {
                                if (value !== Config.system.ocr.chi_sim) {
                                    GlobalStates.markShellChanged();
                                    Config.system.ocr.chi_sim = value;
                                }
                            }
                        }

                        ToggleRow {
                            label: "Chinese (Traditional)"
                            checked: Config.system.ocr.chi_tra ?? false
                            onToggled: value => {
                                if (value !== Config.system.ocr.chi_tra) {
                                    GlobalStates.markShellChanged();
                                    Config.system.ocr.chi_tra = value;
                                }
                            }
                        }

                        ToggleRow {
                            label: "Korean"
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
