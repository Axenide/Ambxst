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

                    required property int index
                    required property var modelData

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
                        label: "Hyprland"
                        image: "../../../../assets/compositors/hyprland.svg"
                        isSelected: stackLayout.currentIndex === 0
                        onClicked: stackLayout.currentIndex = 0
                    }

                    CompositorTabButton {
                        label: "Coming Soon"
                        icon: Icons.clock
                        isSelected: stackLayout.currentIndex === 1
                        onClicked: stackLayout.currentIndex = 1
                    }
                }
            }

            // Stack for content
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: stackLayout.height

                StackLayout {
                    id: stackLayout
                    width: root.contentWidth
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: currentIndex === 0 ? hyprlandPage.implicitHeight : placeholderPage.implicitHeight
                    currentIndex: 0

                    // ═══════════════════════════════════════════════════════════════
                    // HYPRLAND TAB
                    // ═══════════════════════════════════════════════════════════════
                    ColumnLayout {
                        id: hyprlandPage
                        Layout.fillWidth: true
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
                                label: "SUPER Key Launcher"
                                checked: Config.system.superKeyLauncher ?? true
                                onToggled: value => {
                                    Config.system.superKeyLauncher = value;
                                }
                            }

                            ToggleRow {
                                label: "Sync Border Size"
                                checked: Config.hyprland.syncBorderWidth ?? false
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.hyprland.syncBorderWidth = value;
                                }
                            }

                            NumberInputRow {
                                label: "Border Size"
                                value: Config.hyprland.borderSize ?? 2
                                minValue: 0
                                maxValue: 999
                                suffix: "px"
                                enabled: !Config.hyprland.syncBorderWidth
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.hyprland.borderSize = newValue;
                                }
                            }

                            ToggleRow {
                                label: "Sync Rounding"
                                checked: Config.hyprland.syncRoundness ?? true
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.hyprland.syncRoundness = value;
                                }
                            }

                            NumberInputRow {
                                label: "Rounding"
                                value: Config.hyprland.rounding ?? 16
                                minValue: 0
                                maxValue: 999
                                suffix: "px"
                                enabled: !Config.hyprland.syncRoundness
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.hyprland.rounding = newValue;
                                }
                            }

                            NumberInputRow {
                                label: "Gaps In"
                                value: Config.hyprland.gapsIn ?? 5
                                minValue: 0
                                maxValue: 50
                                suffix: "px"
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.hyprland.gapsIn = newValue;
                                }
                            }

                            NumberInputRow {
                                label: "Gaps Out"
                                value: Config.hyprland.gapsOut ?? 10
                                minValue: 0
                                maxValue: 50
                                suffix: "px"
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.hyprland.gapsOut = newValue;
                                }
                            }

                            NumberInputRow {
                                label: "Border Angle"
                                value: Config.hyprland.borderAngle ?? 45
                                minValue: 0
                                maxValue: 360
                                suffix: "deg"
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.hyprland.borderAngle = newValue;
                                }
                            }

                            NumberInputRow {
                                label: "Inactive Angle"
                                value: Config.hyprland.inactiveBorderAngle ?? 45
                                minValue: 0
                                maxValue: 360
                                suffix: "deg"
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.hyprland.inactiveBorderAngle = newValue;
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
                                checked: Config.hyprland.syncBorderColor ?? false
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.hyprland.syncBorderColor = value;
                                }
                            }

                            // Active Border Color
                            BorderGradientRow {
                                label: "Active Border"
                                colors: Config.hyprland.activeBorderColor || ["primary"]
                                dialogTitle: "Edit Active Border Color"
                                enabled: !Config.hyprland.syncBorderColor
                                onColorsEdited: newColors => {
                                    GlobalStates.markCompositorChanged();
                                    Config.hyprland.activeBorderColor = newColors;
                                }
                            }

                            // Inactive Border Color
                            BorderGradientRow {
                                label: "Inactive Border"
                                colors: Config.hyprland.inactiveBorderColor || ["surface"]
                                dialogTitle: "Edit Inactive Border Color"
                                onColorsEdited: newColors => {
                                    GlobalStates.markCompositorChanged();
                                    Config.hyprland.inactiveBorderColor = newColors;
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
                                checked: Config.hyprland.shadowEnabled ?? true
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.hyprland.shadowEnabled = value;
                                }
                            }

                            ToggleRow {
                                label: "Sync Color"
                                checked: Config.hyprland.syncShadowColor ?? false
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.hyprland.syncShadowColor = value;
                                }
                            }

                            ToggleRow {
                                label: "Sync Opacity"
                                checked: Config.hyprland.syncShadowOpacity ?? false
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.hyprland.syncShadowOpacity = value;
                                }
                            }

                            NumberInputRow {
                                label: "Range"
                                value: Config.hyprland.shadowRange ?? 4
                                minValue: 0
                                maxValue: 100
                                suffix: "px"
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.hyprland.shadowRange = newValue;
                                }
                            }

                            NumberInputRow {
                                label: "Offset X"
                                value: parseInt((Config.hyprland.shadowOffset ?? "0 0").split(" ")[0]) || 0
                                minValue: -50
                                maxValue: 50
                                suffix: "px"
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    let parts = (Config.hyprland.shadowOffset ?? "0 0").split(" ");
                                    let y = parts.length > 1 ? parts[1] : "0";
                                    Config.hyprland.shadowOffset = newValue + " " + y;
                                }
                            }

                            NumberInputRow {
                                label: "Offset Y"
                                value: parseInt((Config.hyprland.shadowOffset ?? "0 0").split(" ")[1]) || 0
                                minValue: -50
                                maxValue: 50
                                suffix: "px"
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    let parts = (Config.hyprland.shadowOffset ?? "0 0").split(" ");
                                    let x = parts.length > 0 ? parts[0] : "0";
                                    Config.hyprland.shadowOffset = x + " " + newValue;
                                }
                            }

                            NumberInputRow {
                                label: "Render Power"
                                value: Config.hyprland.shadowRenderPower ?? 3
                                minValue: 1
                                maxValue: 4
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.hyprland.shadowRenderPower = newValue;
                                }
                            }

                            DecimalInputRow {
                                label: "Scale"
                                value: Config.hyprland.shadowScale ?? 1.0
                                minValue: 0.0
                                maxValue: 1.0
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.hyprland.shadowScale = newValue;
                                }
                            }

                            DecimalInputRow {
                                label: "Opacity"
                                value: Config.hyprland.shadowOpacity ?? 0.5
                                minValue: 0.0
                                maxValue: 1.0
                                enabled: !Config.hyprland.syncShadowOpacity
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.hyprland.shadowOpacity = newValue;
                                }
                            }

                            ToggleRow {
                                label: "Sharp"
                                checked: Config.hyprland.shadowSharp ?? false
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.hyprland.shadowSharp = value;
                                }
                            }

                            ToggleRow {
                                label: "Ignore Window"
                                checked: Config.hyprland.shadowIgnoreWindow ?? true
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.hyprland.shadowIgnoreWindow = value;
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
                                checked: Config.hyprland.blurEnabled ?? true
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.hyprland.blurEnabled = value;
                                }
                            }

                            NumberInputRow {
                                label: "Size"
                                value: Config.hyprland.blurSize ?? 8
                                minValue: 0
                                maxValue: 20
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.hyprland.blurSize = newValue;
                                }
                            }

                            NumberInputRow {
                                label: "Passes"
                                value: Config.hyprland.blurPasses ?? 1
                                minValue: 0
                                maxValue: 4
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.hyprland.blurPasses = newValue;
                                }
                            }

                            ToggleRow {
                                label: "Xray"
                                checked: Config.hyprland.blurXray ?? false
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.hyprland.blurXray = value;
                                }
                            }

                            ToggleRow {
                                label: "New Optimizations"
                                checked: Config.hyprland.blurNewOptimizations ?? true
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.hyprland.blurNewOptimizations = value;
                                }
                            }

                            ToggleRow {
                                label: "Ignore Opacity"
                                checked: Config.hyprland.blurIgnoreOpacity ?? true
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.hyprland.blurIgnoreOpacity = value;
                                }
                            }

                            ToggleRow {
                                label: "Explicit Ignorealpha"
                                checked: Config.hyprland.blurExplicitIgnoreAlpha ?? false
                                onToggled: value => {
                                    GlobalStates.markCompositorChanged();
                                    Config.hyprland.blurExplicitIgnoreAlpha = value;
                                }
                            }

                            DecimalInputRow {
                                label: "Ignorealpha Value"
                                value: Config.hyprland.blurIgnoreAlphaValue ?? 0.2
                                minValue: 0.0
                                maxValue: 1.0
                                enabled: Config.hyprland.blurExplicitIgnoreAlpha
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.hyprland.blurIgnoreAlphaValue = newValue;
                                }
                            }

                            DecimalInputRow {
                                label: "Noise"
                                value: Config.hyprland.blurNoise ?? 0.01
                                minValue: 0.0
                                maxValue: 1.0
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.hyprland.blurNoise = newValue;
                                }
                            }

                            DecimalInputRow {
                                label: "Contrast"
                                value: Config.hyprland.blurContrast ?? 0.89
                                minValue: 0.0
                                maxValue: 2.0
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.hyprland.blurContrast = newValue;
                                }
                            }

                            DecimalInputRow {
                                label: "Brightness"
                                value: Config.hyprland.blurBrightness ?? 0.81
                                minValue: 0.0
                                maxValue: 2.0
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.hyprland.blurBrightness = newValue;
                                }
                            }

                            DecimalInputRow {
                                label: "Vibrancy"
                                value: Config.hyprland.blurVibrancy ?? 0.17
                                minValue: 0.0
                                maxValue: 1.0
                                onValueEdited: newValue => {
                                    GlobalStates.markCompositorChanged();
                                    Config.hyprland.blurVibrancy = newValue;
                                }
                            }
                        }

                        // Bottom Padding
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 16
                        }
                    }

                    // ═══════════════════════════════════════════════════════════════
                    // COMING SOON TAB
                    // ═══════════════════════════════════════════════════════════════
                    Item {
                        id: placeholderPage
                        Layout.fillWidth: true
                        implicitHeight: 300

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 16

                            Text {
                                text: Icons.clock
                                font.family: Icons.font
                                font.pixelSize: 64
                                color: Colors.surfaceVariant
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                text: "Coming Soon"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(2)
                                font.bold: true
                                color: Colors.overBackground
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                text: "Support for more compositors\nis planned for future updates."
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(0)
                                color: Colors.overSurfaceVariant
                                horizontalAlignment: Text.AlignHCenter
                                Layout.alignment: Qt.AlignHCenter
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
