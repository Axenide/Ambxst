pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import qs.modules.theme
import qs.modules.components
import qs.modules.globals
import qs.config

Item {
    id: root

    property int maxContentWidth: 480
    readonly property int contentWidth: Math.min(width, maxContentWidth)
    readonly property real sideMargin: (width - contentWidth) / 2

    property string currentSection: ""

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

    // Available color names for color picker
    readonly property var colorNames: Colors.availableColorNames

    // Color picker state
    property bool colorPickerActive: false
    property var colorPickerColorNames: []
    property string colorPickerCurrentColor: ""
    property string colorPickerDialogTitle: ""
    property var colorPickerCallback: null

    function openColorPicker(colorNames, currentColor, dialogTitle, callback) {
        // Ensure colorNames is a valid array for QML
        colorPickerColorNames = colorNames;
        // Ensure currentColor is a string
        colorPickerCurrentColor = currentColor.toString();
        // Ensure dialogTitle is a string
        colorPickerDialogTitle = dialogTitle ? dialogTitle.toString() : "";
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
        opacity: enabled ? 1.0 : 0.5

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

    // Inline component for decimal input rows
    component DecimalInputRow: RowLayout {
        id: decimalInputRowRoot
        property string label: ""
        property real value: 0.0
        property real minValue: 0.0
        property real maxValue: 1.0
        property string suffix: ""
        signal valueEdited(real newValue)

        Layout.fillWidth: true
        spacing: 8
        opacity: enabled ? 1.0 : 0.5

        Text {
            text: decimalInputRowRoot.label
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
                id: decimalTextInput
                anchors.fill: parent
                anchors.margins: 8
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(0)
                color: Colors.overBackground
                selectByMouse: true
                clip: true
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter
                validator: DoubleValidator {
                    bottom: decimalInputRowRoot.minValue
                    top: decimalInputRowRoot.maxValue
                    decimals: 2
                }

                // Sync text when external value changes
                readonly property real configValue: decimalInputRowRoot.value
                onConfigValueChanged: {
                    if (!activeFocus) {
                        // Check if roughly equal to avoid formatting loops
                        if (Math.abs(parseFloat(text) - configValue) > 0.001 || text === "")
                            text = configValue.toFixed(1); // Default format
                    }
                }
                Component.onCompleted: text = configValue.toFixed(1)

                onEditingFinished: {
                    let newVal = parseFloat(text);
                    if (!isNaN(newVal)) {
                        newVal = Math.max(decimalInputRowRoot.minValue, Math.min(decimalInputRowRoot.maxValue, newVal));
                        decimalInputRowRoot.valueEdited(newVal);
                    }
                }
            }
        }

        Text {
            text: decimalInputRowRoot.suffix
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
        property string text: ""
        property string placeholder: ""
        signal textEdited(string newText)

        Layout.fillWidth: true
        spacing: 8

        Text {
            text: textInputRowRoot.label
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(0)
            color: Colors.overBackground
            Layout.fillWidth: true
        }

        StyledRect {
            variant: "common"
            Layout.preferredWidth: 120
            Layout.preferredHeight: 32
            radius: Styling.radius(-2)

            TextInput {
                id: textInput
                anchors.fill: parent
                anchors.margins: 8
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(0)
                color: Colors.overBackground
                selectByMouse: true
                clip: true
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter

                readonly property string configText: textInputRowRoot.text
                onConfigTextChanged: {
                    if (!activeFocus && text !== configText) {
                        text = configText;
                    }
                }
                Component.onCompleted: text = configText

                onEditingFinished: {
                    textInputRowRoot.textEdited(text);
                }
            }
        }
    }

    // Inline component for Border Gradients (Multi-color list)
    component BorderGradientRow: ColumnLayout {
        id: gradientRow
        property string label: ""
        property var colors: []
        property string dialogTitle: ""
        property bool enabled: true
        signal colorsEdited(var newColors)

        spacing: 8
        Layout.fillWidth: true
        opacity: enabled ? 1.0 : 0.5

        // Header
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: gradientRow.label
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(0)
                color: Colors.overBackground
                Layout.fillWidth: true
            }
            Text {
                text: "Right click to remove"
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                color: Colors.overSurfaceVariant
                visible: gradientRow.colors.length > 1
            }
        }

        // Color List
        Flow {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                id: colorsRepeater
                model: gradientRow.colors
                delegate: MouseArea {
                    width: 32
                    height: 32
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    required property var modelData
                    required property int index

                    // Swatch
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: Config.resolveColor(parent.modelData)
                        border.width: 2
                        border.color: parent.containsMouse ? Styling.srItem("overprimary") : Colors.outline

                        // Inner check for visual depth
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width - 4
                            height: width
                            radius: width / 2
                            color: "transparent"
                            border.width: 1
                            border.color: Colors.surface
                            opacity: 0.3
                        }
                    }

                    // Tooltip
                    StyledToolTip {
                        text: parent.modelData.toString()
                        visible: parent.containsMouse && !contextMenu.visible
                    }

                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton) {
                            // Remove color (if more than 1)
                            if (gradientRow.colors.length > 1) {
                                let newColors = [...gradientRow.colors];
                                newColors.splice(index, 1);
                                gradientRow.colorsEdited(newColors);
                            }
                        } else {
                            // Edit color
                            root.openColorPicker(root.colorNames, modelData, gradientRow.dialogTitle, function (selectedColor) {
                                let newColors = [...gradientRow.colors];
                                newColors[index] = selectedColor;
                                gradientRow.colorsEdited(newColors);
                            });
                        }
                    }
                }
            }
            StyledRect {
                width: 32
                height: 32
                radius: 16
                variant: "common"
                color: mouseAreaAdd.containsMouse ? Colors.surfaceBright : Colors.surface
                border.width: 1
                border.color: Colors.outline

                Text {
                    anchors.centerIn: parent
                    text: Icons.plus
                    font.family: Icons.font
                    font.pixelSize: 16
                    color: Colors.overSurfaceVariant
                }

                MouseArea {
                    id: mouseAreaAdd
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        let newColors = [...gradientRow.colors];
                        // Duplicate last color or default to primary
                        let colorToAdd = newColors.length > 0 ? newColors[newColors.length - 1] : "primary";
                        newColors.push(colorToAdd);
                        gradientRow.colorsEdited(newColors);
                    }
                }
            }
        }
    }

    // Inline component for Compositor Tabs
    component CompositorTabButton: StyledRect {
        id: tabBtn
        property string label: ""
        property string icon: ""
        property string image: ""
        property bool isSelected: false
        signal clicked

        variant: isSelected ? "primary" : (hoverHandler.hovered ? "focus" : "common")
        Layout.preferredWidth: 140
        Layout.preferredHeight: 36
        radius: isSelected ? Styling.radius(0) / 2 : Styling.radius(0)
        enableShadow: true

        HoverHandler {
            id: hoverHandler
        }
        TapHandler {
            onTapped: tabBtn.clicked()
        }

        RowLayout {
            anchors.centerIn: parent
            spacing: 8

            // Image Icon (with effect)
            Image {
                mipmap: true
                visible: tabBtn.image !== ""
                source: tabBtn.image
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                sourceSize: Qt.size(32, 32)
                fillMode: Image.PreserveAspectFit
                smooth: true

                layer.enabled: true
                layer.effect: MultiEffect {
                    colorization: 1.0
                    colorizationColor: tabBtn.item
                }
            }

            // Font Icon
            Text {
                visible: tabBtn.icon !== "" && tabBtn.image === ""
                text: tabBtn.icon
                font.family: Icons.font
                font.pixelSize: 14
                color: tabBtn.item
            }

            // Label
            Text {
                text: tabBtn.label
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(0)
                font.bold: true
                color: tabBtn.item
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
                    title: root.currentSection === "" ? "Compositor" : (root.currentSection.charAt(0).toUpperCase() + root.currentSection.slice(1))
                    statusText: GlobalStates.compositorHasChanges ? "Unsaved changes" : ""
                    statusColor: Colors.error

                    actions: {
                        let baseActions = [
                            {
                                icon: Icons.arrowCounterClockwise,
                                tooltip: "Discard changes",
                                enabled: GlobalStates.compositorHasChanges,
                                onClicked: function () {
                                    GlobalStates.discardCompositorChanges();
                                }
                            },
                            {
                                icon: Icons.disk,
                                tooltip: "Apply changes",
                                enabled: GlobalStates.compositorHasChanges,
                                onClicked: function () {
                                    GlobalStates.applyCompositorChanges();
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

            // Tabs Switch
            Item {
                visible: root.currentSection === ""
                Layout.fillWidth: true
                Layout.preferredHeight: 40

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    CompositorTabButton {
                        label: "AxctlService"
                        image: "../../../../assets/compositors/hyprland.svg"
                        isSelected: true
                    }
                }
            }

            // Content
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: compositorPage.implicitHeight

                ColumnLayout {
                    id: compositorPage
                    width: root.contentWidth
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 16

                        // Menu Section
                        ColumnLayout {
                            visible: root.currentSection === ""
                            Layout.fillWidth: true
                            spacing: 8

                            SectionButton {
                                text: "General"
                                sectionId: "general"
                            }
                            SectionButton {
                                text: "Colors"
                                sectionId: "colors"
                            }
                            SectionButton {
                                text: "Shadows"
                                sectionId: "shadows"
                            }
                            SectionButton {
                                text: "Blur"
                                sectionId: "blur"
                            }
                            SectionButton {
                                text: "Opacity && Dim"
                                sectionId: "opacity"
                            }
                            SectionButton {
                                text: "Snap"
                                sectionId: "snap"
                            }
                            SectionButton {
                                text: "Input"
                                sectionId: "input"
                            }
                            SectionButton {
                                text: "Cursor"
                                sectionId: "cursor"
                            }
                            SectionButton {
                                text: "Monitors"
                                sectionId: "monitors"
                            }
                            SectionButton {
                                text: "Gestures"
                                sectionId: "gestures"
                            }
                            SectionButton {
                                text: "Layouts"
                                sectionId: "layouts"
                            }
                            SectionButton {
                                text: "Advanced"
                                sectionId: "advanced"
                            }
                        }

                        // General Section
                        ColumnLayout {
                            visible: root.currentSection === "general"
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "General"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                font.weight: Font.Medium
                                color: Colors.overSurfaceVariant
                                Layout.bottomMargin: -4
                            }

                            ToggleRow {
                                label: "Sync Border Size"
                                checked: Config.compositor.syncBorderWidth ?? false
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.syncBorderWidth = value;
                                }
                            }

                            NumberInputRow {
                                label: "Border Size"
                                value: Config.compositor.borderSize ?? 2
                                minValue: 0
                                maxValue: 999
                                suffix: "px"
                                enabled: !Config.compositor.syncBorderWidth
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.borderSize = newValue;
                                }
                            }

                            ToggleRow {
                                label: "Sync Rounding"
                                checked: Config.compositor.syncRoundness ?? true
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.syncRoundness = value;
                                }
                            }

                            NumberInputRow {
                                label: "Rounding"
                                value: Config.compositor.rounding ?? 16
                                minValue: 0
                                maxValue: 999
                                suffix: "px"
                                enabled: !Config.compositor.syncRoundness
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.rounding = newValue;
                                }
                            }

                            NumberInputRow {
                                label: "Gaps In"
                                value: Config.compositor.gapsIn ?? 5
                                minValue: 0
                                maxValue: 50
                                suffix: "px"
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.gapsIn = newValue;
                                }
                            }

                            NumberInputRow {
                                label: "Gaps Out"
                                value: Config.compositor.gapsOut ?? 10
                                minValue: 0
                                maxValue: 50
                                suffix: "px"
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.gapsOut = newValue;
                                }
                            }

                            NumberInputRow {
                                label: "Border Angle"
                                value: Config.compositor.borderAngle ?? 45
                                minValue: 0
                                maxValue: 360
                                suffix: "deg"
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.borderAngle = newValue;
                                }
                            }

                            NumberInputRow {
                                label: "Inactive Angle"
                                value: Config.compositor.inactiveBorderAngle ?? 45
                                minValue: 0
                                maxValue: 360
                                suffix: "deg"
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.inactiveBorderAngle = newValue;
                                }
                            }
                        }

                        Separator {
                            Layout.fillWidth: true
                            visible: false
                        }

                        // Colors Section
                        ColumnLayout {
                            visible: root.currentSection === "colors"
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "Colors"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                font.weight: Font.Medium
                                color: Colors.overSurfaceVariant
                                Layout.bottomMargin: -4
                            }

                            ToggleRow {
                                label: "Sync Border Color"
                                checked: Config.compositor.syncBorderColor ?? false
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.syncBorderColor = value;
                                }
                            }

                            // Active Border Color
                            BorderGradientRow {
                                label: "Active Border"
                                colors: Config.compositor.activeBorderColor || ["primary"]
                                dialogTitle: "Edit Active Border Color"
                                enabled: !Config.compositor.syncBorderColor
                                onColorsEdited: newColors => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.activeBorderColor = newColors;
                                }
                            }

                            // Inactive Border Color
                            BorderGradientRow {
                                label: "Inactive Border"
                                colors: Config.compositor.inactiveBorderColor || ["surface"]
                                dialogTitle: "Edit Inactive Border Color"
                                onColorsEdited: newColors => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.inactiveBorderColor = newColors;
                                }
                            }
                        }

                        Separator {
                            Layout.fillWidth: true
                            visible: false
                        }

                        // Shadows Section
                        ColumnLayout {
                            visible: root.currentSection === "shadows"
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "Shadows"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                font.weight: Font.Medium
                                color: Colors.overSurfaceVariant
                                Layout.bottomMargin: -4
                            }

                            ToggleRow {
                                label: "Enabled"
                                checked: Config.compositor.shadowEnabled ?? true
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.shadowEnabled = value;
                                }
                            }

                            ToggleRow {
                                label: "Sync Color"
                                checked: Config.compositor.syncShadowColor ?? false
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.syncShadowColor = value;
                                }
                            }

                            ToggleRow {
                                label: "Sync Opacity"
                                checked: Config.compositor.syncShadowOpacity ?? false
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.syncShadowOpacity = value;
                                }
                            }

                            NumberInputRow {
                                label: "Range"
                                value: Config.compositor.shadowRange ?? 4
                                minValue: 0
                                maxValue: 100
                                suffix: "px"
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.shadowRange = newValue;
                                }
                            }

                            NumberInputRow {
                                label: "Offset X"
                                value: parseInt((Config.compositor.shadowOffset ?? "0 0").split(" ")[0]) || 0
                                minValue: -50
                                maxValue: 50
                                suffix: "px"
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    let parts = (Config.compositor.shadowOffset ?? "0 0").split(" ");
                                    let y = parts.length > 1 ? parts[1] : "0";
                                    Config.compositor.shadowOffset = newValue + " " + y;
                                }
                            }

                            NumberInputRow {
                                label: "Offset Y"
                                value: parseInt((Config.compositor.shadowOffset ?? "0 0").split(" ")[1]) || 0
                                minValue: -50
                                maxValue: 50
                                suffix: "px"
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    let parts = (Config.compositor.shadowOffset ?? "0 0").split(" ");
                                    let x = parts.length > 0 ? parts[0] : "0";
                                    Config.compositor.shadowOffset = x + " " + newValue;
                                }
                            }

                            NumberInputRow {
                                label: "Render Power"
                                value: Config.compositor.shadowRenderPower ?? 3
                                minValue: 1
                                maxValue: 4
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.shadowRenderPower = newValue;
                                }
                            }

                            DecimalInputRow {
                                label: "Scale"
                                value: Config.compositor.shadowScale ?? 1.0
                                minValue: 0.0
                                maxValue: 1.0
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.shadowScale = newValue;
                                }
                            }

                            DecimalInputRow {
                                label: "Opacity"
                                value: Config.compositor.shadowOpacity ?? 0.5
                                minValue: 0.0
                                maxValue: 1.0
                                enabled: !Config.compositor.syncShadowOpacity
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.shadowOpacity = newValue;
                                }
                            }

                            ToggleRow {
                                label: "Sharp"
                                checked: Config.compositor.shadowSharp ?? false
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.shadowSharp = value;
                                }
                            }

                            ToggleRow {
                                label: "Ignore Window"
                                checked: Config.compositor.shadowIgnoreWindow ?? true
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.shadowIgnoreWindow = value;
                                }
                            }
                        }

                        Separator {
                            Layout.fillWidth: true
                            visible: false
                        }

                        // Blur Section
                        ColumnLayout {
                            visible: root.currentSection === "blur"
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "Blur"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                font.weight: Font.Medium
                                color: Colors.overSurfaceVariant
                                Layout.bottomMargin: -4
                            }

                            ToggleRow {
                                label: "Enabled"
                                checked: Config.compositor.blurEnabled ?? true
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.blurEnabled = value;
                                }
                            }

                            NumberInputRow {
                                label: "Size"
                                value: Config.compositor.blurSize ?? 8
                                minValue: 0
                                maxValue: 20
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.blurSize = newValue;
                                }
                            }

                            NumberInputRow {
                                label: "Passes"
                                value: Config.compositor.blurPasses ?? 1
                                minValue: 0
                                maxValue: 4
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.blurPasses = newValue;
                                }
                            }

                            ToggleRow {
                                label: "Xray"
                                checked: Config.compositor.blurXray ?? false
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.blurXray = value;
                                }
                            }

                            ToggleRow {
                                label: "New Optimizations"
                                checked: Config.compositor.blurNewOptimizations ?? true
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.blurNewOptimizations = value;
                                }
                            }

                            ToggleRow {
                                label: "Ignore Opacity"
                                checked: Config.compositor.blurIgnoreOpacity ?? true
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.blurIgnoreOpacity = value;
                                }
                            }

                            ToggleRow {
                                label: "Explicit Ignorealpha"
                                checked: Config.compositor.blurExplicitIgnoreAlpha ?? false
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.blurExplicitIgnoreAlpha = value;
                                }
                            }

                            DecimalInputRow {
                                label: "Ignorealpha Value"
                                value: Config.compositor.blurIgnoreAlphaValue ?? 0.2
                                minValue: 0.0
                                maxValue: 1.0
                                enabled: Config.compositor.blurExplicitIgnoreAlpha
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.blurIgnoreAlphaValue = newValue;
                                }
                            }

                            DecimalInputRow {
                                label: "Noise"
                                value: Config.compositor.blurNoise ?? 0.01
                                minValue: 0.0
                                maxValue: 1.0
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.blurNoise = newValue;
                                }
                            }

                            DecimalInputRow {
                                label: "Contrast"
                                value: Config.compositor.blurContrast ?? 0.89
                                minValue: 0.0
                                maxValue: 2.0
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.blurContrast = newValue;
                                }
                            }

                            DecimalInputRow {
                                label: "Brightness"
                                value: Config.compositor.blurBrightness ?? 0.81
                                minValue: 0.0
                                maxValue: 2.0
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.blurBrightness = newValue;
                                }
                            }

                            DecimalInputRow {
                                label: "Vibrancy"
                                value: Config.compositor.blurVibrancy ?? 0.17
                                minValue: 0.0
                                maxValue: 1.0
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.blurVibrancy = newValue;
                                }
                            }
                        }

                        // Opacity & Dim Section
                        ColumnLayout {
                            visible: root.currentSection === "opacity"
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "Opacity && Dim"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                font.weight: Font.Medium
                                color: Colors.overSurfaceVariant
                                Layout.bottomMargin: -4
                            }

                            Text {
                                text: "Window Opacity"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-2)
                                font.weight: Font.Medium
                                color: Colors.overSurfaceVariant
                                Layout.topMargin: 4
                            }

                            DecimalInputRow {
                                label: "Active"
                                value: Config.compositor.activeOpacity ?? 1.0
                                minValue: 0.0
                                maxValue: 1.0
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.activeOpacity = newValue;
                                }
                            }

                            DecimalInputRow {
                                label: "Inactive"
                                value: Config.compositor.inactiveOpacity ?? 1.0
                                minValue: 0.0
                                maxValue: 1.0
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.inactiveOpacity = newValue;
                                }
                            }

                            DecimalInputRow {
                                label: "Fullscreen"
                                value: Config.compositor.fullscreenOpacity ?? 1.0
                                minValue: 0.0
                                maxValue: 1.0
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.fullscreenOpacity = newValue;
                                }
                            }

                            Text {
                                text: "Dim"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-2)
                                font.weight: Font.Medium
                                color: Colors.overSurfaceVariant
                                Layout.topMargin: 8
                            }

                            ToggleRow {
                                label: "Dim Inactive"
                                checked: Config.compositor.dimInactive ?? false
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.dimInactive = value;
                                }
                            }

                            DecimalInputRow {
                                label: "Dim Strength"
                                value: Config.compositor.dimStrength ?? 0.5
                                minValue: 0.0
                                maxValue: 1.0
                                enabled: Config.compositor.dimInactive
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.dimStrength = newValue;
                                }
                            }

                            DecimalInputRow {
                                label: "Dim Around"
                                value: Config.compositor.dimAround ?? 0.4
                                minValue: 0.0
                                maxValue: 1.0
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.dimAround = newValue;
                                }
                            }

                            DecimalInputRow {
                                label: "Dim Special"
                                value: Config.compositor.dimSpecial ?? 0.2
                                minValue: 0.0
                                maxValue: 1.0
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.dimSpecial = newValue;
                                }
                            }
                        }

                        // Snap Section
                        ColumnLayout {
                            visible: root.currentSection === "snap"
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "Snap"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                font.weight: Font.Medium
                                color: Colors.overSurfaceVariant
                                Layout.bottomMargin: -4
                            }

                            ToggleRow {
                                label: "Enabled"
                                checked: Config.compositor.snapEnabled ?? true
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.snapEnabled = value;
                                }
                            }

                            NumberInputRow {
                                label: "Window Gap"
                                value: Config.compositor.snapWindowGap ?? 10
                                minValue: 0
                                maxValue: 100
                                suffix: "px"
                                enabled: Config.compositor.snapEnabled
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.snapWindowGap = newValue;
                                }
                            }

                            NumberInputRow {
                                label: "Monitor Gap"
                                value: Config.compositor.snapMonitorGap ?? 10
                                minValue: 0
                                maxValue: 100
                                suffix: "px"
                                enabled: Config.compositor.snapEnabled
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.snapMonitorGap = newValue;
                                }
                            }

                            ToggleRow {
                                label: "Border Overlap"
                                checked: Config.compositor.snapBorderOverlap ?? false
                                enabled: Config.compositor.snapEnabled
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.snapBorderOverlap = value;
                                }
                            }

                            ToggleRow {
                                label: "Respect Gaps"
                                checked: Config.compositor.snapRespectGaps ?? false
                                enabled: Config.compositor.snapEnabled
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.snapRespectGaps = value;
                                }
                            }
                        }

                        // Input Section
                        ColumnLayout {
                            visible: root.currentSection === "input"
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "Input"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                font.weight: Font.Medium
                                color: Colors.overSurfaceVariant
                                Layout.bottomMargin: -4
                            }

                            Text {
                                text: "Keyboard"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-2)
                                font.weight: Font.Medium
                                color: Colors.overSurfaceVariant
                                Layout.topMargin: 4
                            }

                            TextInputRow {
                                label: "Layout"
                                text: Config.compositor.kbLayout ?? "us"
                                placeholder: "us"
                                onTextEdited: newText => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.kbLayout = newText;
                                }
                            }

                            TextInputRow {
                                label: "Variant"
                                text: Config.compositor.kbVariant ?? ""
                                placeholder: "e.g. dvorak"
                                onTextEdited: newText => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.kbVariant = newText;
                                }
                            }

                            TextInputRow {
                                label: "Options"
                                text: Config.compositor.kbOptions ?? ""
                                placeholder: "e.g. caps:escape"
                                onTextEdited: newText => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.kbOptions = newText;
                                }
                            }

                            ToggleRow {
                                label: "Numlock by Default"
                                checked: Config.compositor.numlockByDefault ?? false
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.numlockByDefault = value;
                                }
                            }

                            NumberInputRow {
                                label: "Repeat Rate"
                                value: Config.compositor.repeatRate ?? 25
                                minValue: 0
                                maxValue: 300
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.repeatRate = newValue;
                                }
                            }

                            NumberInputRow {
                                label: "Repeat Delay"
                                value: Config.compositor.repeatDelay ?? 600
                                minValue: 0
                                maxValue: 2000
                                suffix: "ms"
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.repeatDelay = newValue;
                                }
                            }

                            Text {
                                text: "Mouse"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-2)
                                font.weight: Font.Medium
                                color: Colors.overSurfaceVariant
                                Layout.topMargin: 8
                            }

                            DecimalInputRow {
                                label: "Sensitivity"
                                value: Config.compositor.mouseSensitivity ?? 0.0
                                minValue: -1.0
                                maxValue: 1.0
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.mouseSensitivity = newValue;
                                }
                            }

                            ToggleRow {
                                label: "Natural Scroll"
                                checked: Config.compositor.mouseNaturalScroll ?? false
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.mouseNaturalScroll = value;
                                }
                            }

                            ToggleRow {
                                label: "Left Handed"
                                checked: Config.compositor.mouseLeftHanded ?? false
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.mouseLeftHanded = value;
                                }
                            }

                            DecimalInputRow {
                                label: "Scroll Factor"
                                value: Config.compositor.mouseScrollFactor ?? 1.0
                                minValue: 0.1
                                maxValue: 10.0
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.mouseScrollFactor = newValue;
                                }
                            }

                            Text {
                                text: "Touchpad"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-2)
                                font.weight: Font.Medium
                                color: Colors.overSurfaceVariant
                                Layout.topMargin: 8
                            }

                            ToggleRow {
                                label: "Disable While Typing"
                                checked: Config.compositor.touchpadDisableWhileTyping ?? true
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.touchpadDisableWhileTyping = value;
                                }
                            }

                            ToggleRow {
                                label: "Natural Scroll"
                                checked: Config.compositor.touchpadNaturalScroll ?? true
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.touchpadNaturalScroll = value;
                                }
                            }

                            ToggleRow {
                                label: "Tap to Click"
                                checked: Config.compositor.touchpadTapToClick ?? true
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.touchpadTapToClick = value;
                                }
                            }

                            DecimalInputRow {
                                label: "Scroll Factor"
                                value: Config.compositor.touchpadScrollFactor ?? 1.0
                                minValue: 0.1
                                maxValue: 10.0
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.touchpadScrollFactor = newValue;
                                }
                            }
                        }

                        // Cursor Section
                        ColumnLayout {
                            visible: root.currentSection === "cursor"
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "Cursor"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                font.weight: Font.Medium
                                color: Colors.overSurfaceVariant
                                Layout.bottomMargin: -4
                            }

                            ToggleRow {
                                label: "Enable Hyprcursor"
                                checked: Config.compositor.enableHyprcursor ?? true
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.enableHyprcursor = value;
                                }
                            }

                            ToggleRow {
                                label: "No Hardware Cursors"
                                checked: Config.compositor.noHardwareCursors ?? false
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.noHardwareCursors = value;
                                }
                            }

                            ToggleRow {
                                label: "No Warps"
                                checked: Config.compositor.noWarps ?? false
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.noWarps = value;
                                }
                            }

                            ToggleRow {
                                label: "Persistent Warps"
                                checked: Config.compositor.persistentWarps ?? false
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.persistentWarps = value;
                                }
                            }

                            ToggleRow {
                                label: "Warp on Workspace Change"
                                checked: Config.compositor.warpOnChangeWorkspace ?? false
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.warpOnChangeWorkspace = value;
                                }
                            }

                            DecimalInputRow {
                                label: "Zoom Factor"
                                value: Config.compositor.cursorZoomFactor ?? 1.0
                                minValue: 0.1
                                maxValue: 10.0
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.cursorZoomFactor = newValue;
                                }
                            }

                            NumberInputRow {
                                label: "Inactive Timeout"
                                value: Config.compositor.cursorInactiveTimeout ?? 0
                                minValue: 0
                                maxValue: 60
                                suffix: "s"
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.cursorInactiveTimeout = newValue;
                                }
                            }

                            ToggleRow {
                                label: "Hide on Key Press"
                                checked: Config.compositor.cursorHideOnKeyPress ?? false
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.cursorHideOnKeyPress = value;
                                }
                            }

                            ToggleRow {
                                label: "Hide on Touch"
                                checked: Config.compositor.cursorHideOnTouch ?? false
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.cursorHideOnTouch = value;
                                }
                            }
                        }

                        // Gestures Section
                        ColumnLayout {
                            visible: root.currentSection === "gestures"
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "Gestures"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                font.weight: Font.Medium
                                color: Colors.overSurfaceVariant
                                Layout.bottomMargin: -4
                            }

                            ToggleRow {
                                label: "Create New Workspace"
                                checked: Config.compositor.workspaceSwipeCreateNew ?? true
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.workspaceSwipeCreateNew = value;
                                }
                            }

                            ToggleRow {
                                label: "Swipe Forever"
                                checked: Config.compositor.workspaceSwipeForever ?? false
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.workspaceSwipeForever = value;
                                }
                            }

                            ToggleRow {
                                label: "Direction Lock"
                                checked: Config.compositor.workspaceSwipeDirectionLock ?? true
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.workspaceSwipeDirectionLock = value;
                                }
                            }

                            ToggleRow {
                                label: "Use Relative Workspaces"
                                checked: Config.compositor.workspaceSwipeUseR ?? false
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.workspaceSwipeUseR = value;
                                }
                            }

                            ToggleRow {
                                label: "Invert Direction"
                                checked: Config.compositor.workspaceSwipeInvert ?? true
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.workspaceSwipeInvert = value;
                                }
                            }

                            DecimalInputRow {
                                label: "Cancel Ratio"
                                value: Config.compositor.workspaceSwipeCancelRatio ?? 0.5
                                minValue: 0.0
                                maxValue: 1.0
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.workspaceSwipeCancelRatio = newValue;
                                }
                            }

                            NumberInputRow {
                                label: "Min Speed to Force"
                                value: Config.compositor.workspaceSwipeMinSpeedToForce ?? 30
                                minValue: 0
                                maxValue: 500
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.workspaceSwipeMinSpeedToForce = newValue;
                                }
                            }

                            NumberInputRow {
                                label: "Swipe Distance"
                                value: Config.compositor.workspaceSwipeDistance ?? 300
                                minValue: 0
                                maxValue: 1000
                                suffix: "px"
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.workspaceSwipeDistance = newValue;
                                }
                            }
                        }

                        // Layouts Section
                        ColumnLayout {
                            visible: root.currentSection === "layouts"
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "Layouts"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                font.weight: Font.Medium
                                color: Colors.overSurfaceVariant
                                Layout.bottomMargin: -4
                            }

                            Text {
                                text: "Dwindle"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-2)
                                font.weight: Font.Medium
                                color: Colors.overSurfaceVariant
                                Layout.topMargin: 4
                            }

                            ToggleRow {
                                label: "Preserve Split"
                                checked: Config.compositor.dwindlePreserveSplit ?? true
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.dwindlePreserveSplit = value;
                                }
                            }

                            ToggleRow {
                                label: "Smart Split"
                                checked: Config.compositor.dwindleSmartSplit ?? true
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.dwindleSmartSplit = value;
                                }
                            }

                            ToggleRow {
                                label: "Smart Resizing"
                                checked: Config.compositor.dwindleSmartResizing ?? true
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.dwindleSmartResizing = value;
                                }
                            }

                            DecimalInputRow {
                                label: "Split Ratio"
                                value: Config.compositor.dwindleDefaultSplitRatio ?? 1.0
                                minValue: 0.1
                                maxValue: 5.0
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.dwindleDefaultSplitRatio = newValue;
                                }
                            }

                            DecimalInputRow {
                                label: "Special Scale"
                                value: Config.compositor.dwindleSpecialScaleFactor ?? 0.8
                                minValue: 0.1
                                maxValue: 1.0
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.dwindleSpecialScaleFactor = newValue;
                                }
                            }

                            Text {
                                text: "Master"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-2)
                                font.weight: Font.Medium
                                color: Colors.overSurfaceVariant
                                Layout.topMargin: 8
                            }

                            DecimalInputRow {
                                label: "Master Factor"
                                value: Config.compositor.masterMfact ?? 0.55
                                minValue: 0.05
                                maxValue: 0.95
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.masterMfact = newValue;
                                }
                            }

                            ToggleRow {
                                label: "Smart Resizing"
                                checked: Config.compositor.masterSmartResizing ?? true
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.masterSmartResizing = value;
                                }
                            }

                            DecimalInputRow {
                                label: "Special Scale"
                                value: Config.compositor.masterSpecialScaleFactor ?? 0.8
                                minValue: 0.1
                                maxValue: 1.0
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.masterSpecialScaleFactor = newValue;
                                }
                            }

                            Text {
                                text: "Scrolling"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-2)
                                font.weight: Font.Medium
                                color: Colors.overSurfaceVariant
                                Layout.topMargin: 8
                            }

                            DecimalInputRow {
                                label: "Column Width"
                                value: Config.compositor.scrollingColumnWidth ?? 0.3
                                minValue: 0.05
                                maxValue: 1.0
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.scrollingColumnWidth = newValue;
                                }
                            }

                            ToggleRow {
                                label: "Follow Focus"
                                checked: Config.compositor.scrollingFollowFocus ?? true
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.scrollingFollowFocus = value;
                                }
                            }

                            DecimalInputRow {
                                label: "Min Visible"
                                value: Config.compositor.scrollingFollowMinVisible ?? 0.1
                                minValue: 0.0
                                maxValue: 1.0
                                enabled: Config.compositor.scrollingFollowFocus
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.scrollingFollowMinVisible = newValue;
                                }
                            }
                        }

                        // Advanced Section
                        ColumnLayout {
                            visible: root.currentSection === "advanced"
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "Advanced"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                font.weight: Font.Medium
                                color: Colors.overSurfaceVariant
                                Layout.bottomMargin: -4
                            }

                    // =====================
                    // MONITORS SECTION
                    // =====================
                    ColumnLayout {
                        visible: root.currentSection === "monitors"
                        property string settingsSection: "monitors"
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "Monitor Layout"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: Font.Medium
                            color: Colors.overSurfaceVariant
                            Layout.bottomMargin: -4
                        }

                        Repeater {
                            model: Quickshell.screens.length
                            delegate: StyledRect {
                                readonly property var scr: Quickshell.screens[index]
                                Layout.fillWidth: true
                                variant: "surface"
                                radius: Styling.radius(8)
                                implicitHeight: monCol.implicitHeight + 16
                                ColumnLayout {
                                    id: monCol
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 6
                                    Text {
                                        text: scr.name + "  " + scr.width + "x" + scr.height
                                        font.bold: true
                                        color: Colors.overSurface
                                    }
                                    Text {
                                        text: "Position: " + (scr.x || 0) + "x" + (scr.y || 0)
                                        color: Colors.outline
                                        font.pixelSize: Styling.fontSize(-1)
                                    }
                                    RowLayout {
                                        spacing: 6
                                        Button { text: "<< Left"; onClicked: Qt.createQmlObject('import Quickshell.Io; Process { command: ["bash", "-c", "hyprctl keyword monitor ' + scr.name + ',preferred,' + Math.max(0,(scr.x||0)-1920) + 'x' + (scr.y||0) + ',1"]; running: true }', root); }
                                        Button { text: "Right >>"; onClicked: Qt.createQmlObject('import Quickshell.Io; Process { command: ["bash", "-c", "hyprctl keyword monitor ' + scr.name + ',preferred,' + ((scr.x||0)+1920) + 'x' + (scr.y||0) + ',1"]; running: true }', root); }
                                        Button { text: "Up ^"; onClicked: Qt.createQmlObject('import Quickshell.Io; Process { command: ["bash", "-c", "hyprctl keyword monitor ' + scr.name + ',preferred,' + (scr.x||0) + 'x' + Math.max(0,(scr.y||0)-1080) + ',1"]; running: true }', root); }
                                        Button { text: "v Down"; onClicked: Qt.createQmlObject('import Quickshell.Io; Process { command: ["bash", "-c", "hyprctl keyword monitor ' + scr.name + ',preferred,' + (scr.x||0) + 'x' + (scr.y||0)+1080 + ',1"]; running: true }', root); }
                                    }
                                }
                            }
                        }

                        Button {
                            text: "Auto-arrange horizontally"
                            // variant: "primary"
                            Layout.fillWidth: true
                            onClicked: {
                                var py = "python3 -c 'import json,os,sys; m=json.load(sys.stdin); [os.system(\"hyprctl keyword monitor \"+x[\"name\"]+\",preferred,\"+str(i*1920)+\"x0,1\") for i,x in enumerate(m)]'";
                                Qt.createQmlObject('import Quickshell.Io; Process { command: ["bash", "-c", "hyprctl monitors -j | ' + py + '"]; running: true }', root);
                            }
                        }
                    }



                            Text {
                                text: "General"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-2)
                                font.weight: Font.Medium
                                color: Colors.overSurfaceVariant
                                Layout.topMargin: 4
                            }

                            ToggleRow {
                                label: "Allow Tearing"
                                checked: Config.compositor.allowTearing ?? false
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.allowTearing = value;
                                }
                            }

                            ToggleRow {
                                label: "Animations"
                                checked: Config.compositor.animationsEnabled ?? true
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.animationsEnabled = value;
                                }
                            }

                            ToggleRow {
                                label: "Animate Manual Resizes"
                                checked: Config.compositor.animateManualResizes ?? false
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.animateManualResizes = value;
                                }
                            }

                            ToggleRow {
                                label: "Animate Mouse Dragging"
                                checked: Config.compositor.animateMouseWindowdragging ?? true
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.animateMouseWindowdragging = value;
                                }
                            }

                            ToggleRow {
                                label: "Focus on Activate"
                                checked: Config.compositor.focusOnActivate ?? false
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.focusOnActivate = value;
                                }
                            }

                            ToggleRow {
                                label: "Resize on Border"
                                checked: Config.compositor.resizeOnBorder ?? false
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.resizeOnBorder = value;
                                }
                            }

                            NumberInputRow {
                                label: "Border Grab Area"
                                value: Config.compositor.extendBorderGrabArea ?? 15
                                minValue: 0
                                maxValue: 50
                                suffix: "px"
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.extendBorderGrabArea = newValue;
                                }
                            }

                            Text {
                                text: "XWayland"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-2)
                                font.weight: Font.Medium
                                color: Colors.overSurfaceVariant
                                Layout.topMargin: 8
                            }

                            ToggleRow {
                                label: "XWayland Enabled"
                                checked: Config.compositor.xwaylandEnabled ?? true
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.xwaylandEnabled = value;
                                }
                            }

                            ToggleRow {
                                label: "Force Zero Scaling"
                                checked: Config.compositor.xwaylandForceZeroScaling ?? false
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.xwaylandForceZeroScaling = value;
                                }
                            }

                            Text {
                                text: "Display"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-2)
                                font.weight: Font.Medium
                                color: Colors.overSurfaceVariant
                                Layout.topMargin: 8
                            }

                            ToggleRow {
                                label: "VFR (Variable Frame Rate)"
                                checked: Config.compositor.vfr ?? true
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.vfr = value;
                                }
                            }

                            Text {
                                text: "Startup"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-2)
                                font.weight: Font.Medium
                                color: Colors.overSurfaceVariant
                                Layout.topMargin: 8
                            }

                            ToggleRow {
                                label: "Disable Logo"
                                checked: Config.compositor.disableHyprlandLogo ?? true
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.disableHyprlandLogo = value;
                                }
                            }

                            ToggleRow {
                                label: "Disable Splash"
                                checked: Config.compositor.disableSplashRendering ?? false
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.disableSplashRendering = value;
                                }
                            }

                            ToggleRow {
                                label: "Disable Update News"
                                checked: Config.compositor.noUpdateNews ?? true
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.compositor.noUpdateNews = value;
                                }
                            }
                        }

                        // Bottom Padding
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 16
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
