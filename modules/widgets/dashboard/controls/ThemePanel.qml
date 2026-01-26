pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.globals
import qs.modules.services
import Quickshell
import Quickshell.Io
import qs.config

Item {
    id: root
    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property int maxContentWidth: 480
    readonly property int contentWidth: Math.min(width, maxContentWidth)
    readonly property real sideMargin: (width - contentWidth) / 2

    property string currentSection: ""
    property string selectedVariant: "bg"

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
            LayoutMirroring.enabled: I18n.isRtl
            LayoutMirroring.childrenInherit: true

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

    FileView {
        id: wallpaperConfig
        path: Quickshell.dataPath("wallpapers.json")

        JsonAdapter {
            property string currentWall: ""
            property string wallPath: ""
            property string matugenScheme: "scheme-tonal-spot"
            property string activeColorPreset: ""
        }
    }

    // Convert sr property name to variant id (srBg -> bg, srPrimaryFocus -> primaryfocus)
    function srNameToId(srName: string): string {
        return srName.substring(2).toLowerCase();
    }

    // Dynamically generate allVariants from Config.theme properties starting with "sr"
    // Reads the label property from each variant config
    readonly property var allVariants: {
        let variants = [];
        let theme = Config.theme;

        // Get all property names from theme that start with "sr"
        for (let prop in theme) {
            if (prop.startsWith("sr") && theme[prop] && typeof theme[prop] === "object") {
                // Read label from the variant config itself, fallback to property name
                let label = theme[prop].label || prop.substring(2);
                variants.push({
                    id: srNameToId(prop),
                    label: label
                });
            }
        }

        return variants;
    }

    function getVariantLabel(variantId: string): string {
        for (var i = 0; i < allVariants.length; i++) {
            if (allVariants[i].id === variantId) {
                return allVariants[i].label;
            }
        }
        return variantId;
    }

    // Main content - single Flickable for everything, fills entire width
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
            id: mainTranslate
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
            spacing: 12

            // Header wrapper
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: titlebar.visible ? titlebar.height : 0

                PanelTitlebar {
                    id: titlebar
                    width: root.contentWidth
                    anchors.horizontalCenter: parent.horizontalCenter
                    title: root.currentSection === "" ? I18n.t("Theme")
                        : I18n.t(root.currentSection.charAt(0).toUpperCase() + root.currentSection.slice(1))
                    showTitle: false
                    statusText: GlobalStates.themeHasChanges ? "Unsaved changes" : ""
                    statusColor: Colors.error
                    actions: []
                    visible: false
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
                    spacing: 12

                    // ═══════════════════════════════════════════════════════════════
                    // MENU SECTION
                    // ═══════════════════════════════════════════════════════════════
                    ColumnLayout {
                        visible: root.currentSection === ""
                        Layout.fillWidth: true
                        spacing: 12

                        SectionButton {
                            text: I18n.t("General")
                            sectionId: "general"
                        }
                        SectionButton {
                            text: I18n.t("Shadow")
                            sectionId: "shadow"
                        }
                        SectionButton {
                            text: I18n.t("Colors")
                            sectionId: "colors"
                        }
                    }

                    // General section
                    Item {
                        visible: root.currentSection === "general"
                        Layout.fillWidth: true
                        Layout.preferredHeight: generalContent.implicitHeight

                        ColumnLayout {
                            id: generalContent
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            spacing: 12

                            Text {
                                text: I18n.t("General")
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                font.weight: Font.Medium
                                color: Colors.overSurfaceVariant
                                Layout.bottomMargin: -4
                            }

                            // Wallpaper Path
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12
                                LayoutMirroring.enabled: I18n.isRtl
                                LayoutMirroring.childrenInherit: true

                                Text {
                                    text: I18n.t("Wallpapers")
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(0)
                                    color: Colors.overBackground
                                    Layout.preferredWidth: 80
                                    horizontalAlignment: I18n.isRtl ? Text.AlignRight : Text.AlignLeft
                                    elide: Text.ElideRight
                                    wrapMode: Text.NoWrap
                                }

                                StyledRect {
                                    variant: "common"
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 32
                                    radius: Styling.radius(-2)

                                    TextInput {
                                        id: wallPathInput
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(0)
                                        color: Colors.overBackground
                                        selectByMouse: true
                                        clip: true
                                        verticalAlignment: TextInput.AlignVCenter
                                        horizontalAlignment: I18n.isRtl ? TextInput.AlignRight : TextInput.AlignLeft

                                        // Placeholder for default path
                                        Text {
                                            anchors.fill: parent
                                            verticalAlignment: Text.AlignVCenter
                                            text: I18n.t("Default")
                                            font: parent.font
                                            color: Colors.overSurfaceVariant
                                            visible: !parent.text && !parent.activeFocus
                                            horizontalAlignment: I18n.isRtl ? Text.AlignRight : Text.AlignLeft
                                        }

                                        text: wallpaperConfig.adapter.wallPath

                                        onEditingFinished: {
                                            if (wallpaperConfig.adapter.wallPath !== text) {
                                                wallpaperConfig.adapter.wallPath = text;
                                                wallpaperConfig.writeAdapter();
                                            }
                                        }
                                    }
                                }
                            }

                            // Tint Icons toggle
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12
                                LayoutMirroring.enabled: I18n.isRtl
                                LayoutMirroring.childrenInherit: true

                                Text {
                                    text: I18n.t("Tint Icons")
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(0)
                                    color: Colors.overBackground
                                    Layout.fillWidth: true
                                    horizontalAlignment: I18n.isRtl ? Text.AlignRight : Text.AlignLeft
                                    elide: Text.ElideRight
                                    wrapMode: Text.NoWrap
                                }

                                Switch {
                                    id: tintIconsSwitch
                                    checked: Config.theme.tintIcons

                                    readonly property bool configValue: Config.theme.tintIcons

                                    onConfigValueChanged: {
                                        if (checked !== configValue) {
                                            checked = configValue;
                                        }
                                    }

                                    onCheckedChanged: {
                                        if (checked !== Config.theme.tintIcons) {
                                            GlobalStates.markThemeChanged();
                                            Config.theme.tintIcons = checked;
                                        }
                                    }

                                    indicator: Rectangle {
                                        implicitWidth: 40
                                        implicitHeight: 20
                                        x: tintIconsSwitch.leftPadding
                                        y: parent.height / 2 - height / 2
                                        radius: height / 2
                                        color: tintIconsSwitch.checked ? Styling.srItem("overprimary") : Colors.surfaceBright
                                        border.color: tintIconsSwitch.checked ? Styling.srItem("overprimary") : Colors.outline

                                        Behavior on color {
                                            enabled: Config.animDuration > 0
                                            ColorAnimation {
                                                duration: Config.animDuration / 2
                                            }
                                        }

                                        Rectangle {
                                            x: tintIconsSwitch.checked ? parent.width - width - 2 : 2
                                            y: 2
                                            width: parent.height - 4
                                            height: width
                                            radius: width / 2
                                            color: tintIconsSwitch.checked ? Colors.background : Colors.overSurfaceVariant

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

                            // Enable Corners toggle
                            RowLayout {
                                LayoutMirroring.enabled: I18n.isRtl
                                LayoutMirroring.childrenInherit: true
                                Layout.fillWidth: true
                                spacing: 12

                                Text {
                                    text: I18n.t("Enable Corners")
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(0)
                                    color: Colors.overBackground
                                    Layout.fillWidth: true
                                    horizontalAlignment: I18n.isRtl ? Text.AlignRight : Text.AlignLeft
                                    elide: Text.ElideRight
                                    wrapMode: Text.NoWrap
                                }

                                Switch {
                                    id: enableCornersSwitch
                                    checked: Config.theme.enableCorners

                                    readonly property bool configValue: Config.theme.enableCorners

                                    onConfigValueChanged: {
                                        if (checked !== configValue) {
                                            checked = configValue;
                                        }
                                    }

                                    onCheckedChanged: {
                                        if (checked !== Config.theme.enableCorners) {
                                            GlobalStates.markThemeChanged();
                                            Config.theme.enableCorners = checked;
                                        }
                                    }

                                    indicator: Rectangle {
                                        implicitWidth: 40
                                        implicitHeight: 20
                                        x: enableCornersSwitch.leftPadding
                                        y: parent.height / 2 - height / 2
                                        radius: height / 2
                                        color: enableCornersSwitch.checked ? Styling.srItem("overprimary") : Colors.surfaceBright
                                        border.color: enableCornersSwitch.checked ? Styling.srItem("overprimary") : Colors.outline

                                        Behavior on color {
                                            enabled: Config.animDuration > 0
                                            ColorAnimation {
                                                duration: Config.animDuration / 2
                                            }
                                        }

                                        Rectangle {
                                            x: enableCornersSwitch.checked ? parent.width - width - 2 : 2
                                            y: 2
                                            width: parent.height - 4
                                            height: width
                                            radius: width / 2
                                            color: enableCornersSwitch.checked ? Colors.background : Colors.overSurfaceVariant

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

                            // Animation Duration slider
                            RowLayout {
                                LayoutMirroring.enabled: I18n.isRtl
                                LayoutMirroring.childrenInherit: true
                                Layout.fillWidth: true
                                spacing: 12

                                Text {
                                    text: I18n.t("Animation")
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(0)
                                    color: Colors.overBackground
                                    Layout.preferredWidth: 80
                                    horizontalAlignment: I18n.isRtl ? Text.AlignRight : Text.AlignLeft
                                    elide: Text.ElideRight
                                    wrapMode: Text.NoWrap
                                }

                                StyledSlider {
                                    id: animDurationSlider
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 20
                                    progressColor: Styling.srItem("overprimary")
                                    tooltipText: `${Math.round(value * 1000)}ms`
                                    scroll: true
                                    stepSize: 0.01  // 10ms steps (1/100 of 1000ms)
                                    snapMode: "always"

                                    readonly property real configValue: Config.theme.animDuration / 1000

                                    onConfigValueChanged: {
                                        if (Math.abs(value - configValue) > 0.001) {
                                            value = configValue;
                                        }
                                    }

                                    Component.onCompleted: value = configValue

                                    onValueChanged: {
                                        let newDuration = Math.round(value * 1000);
                                        if (newDuration !== Config.theme.animDuration) {
                                            GlobalStates.markThemeChanged();
                                            Config.theme.animDuration = newDuration;
                                        }
                                    }
                                }

                                Text {
                                    text: Config.theme.animDuration + "ms"
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(0)
                                    color: Colors.overBackground
                                    horizontalAlignment: Text.AlignRight
                                    Layout.preferredWidth: 50
                                }
                            }

                            Separator {
                                Layout.fillWidth: true
                            }

                            Text {
                                text: I18n.t("Fonts")
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                font.weight: Font.Medium
                                color: Colors.overSurfaceVariant
                                Layout.bottomMargin: -4
                            }

                            // UI Font row
                            RowLayout {
                                LayoutMirroring.enabled: I18n.isRtl
                                LayoutMirroring.childrenInherit: true
                                Layout.fillWidth: true
                                spacing: 12

                                Text {
                                    text: I18n.t("UI Font")
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(0)
                                    color: Colors.overBackground
                                    Layout.preferredWidth: 80
                                    horizontalAlignment: I18n.isRtl ? Text.AlignRight : Text.AlignLeft
                                    elide: Text.ElideRight
                                    wrapMode: Text.NoWrap
                                }

                                StyledRect {
                                    variant: "common"
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 32
                                    radius: Styling.radius(-2)

                                    TextInput {
                                        id: fontInput
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(0)
                                        color: Colors.overBackground
                                        selectByMouse: true
                                        clip: true
                                        verticalAlignment: TextInput.AlignVCenter
                                        horizontalAlignment: I18n.isRtl ? TextInput.AlignRight : TextInput.AlignLeft

                                        readonly property string configValue: Config.theme.font

                                        onConfigValueChanged: {
                                            if (text !== configValue) {
                                                text = configValue;
                                            }
                                        }

                                        Component.onCompleted: text = configValue

                                        onEditingFinished: {
                                            if (text !== Config.theme.font && text.trim() !== "") {
                                                GlobalStates.markThemeChanged();
                                                Config.theme.font = text.trim();
                                            }
                                        }
                                    }
                                }

                                StyledRect {
                                    variant: "common"
                                    Layout.preferredWidth: 60
                                    Layout.preferredHeight: 32
                                    radius: Styling.radius(-2)

                                    TextInput {
                                        id: fontSizeInput
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
                                            bottom: 8
                                            top: 32
                                        }

                                        readonly property int configValue: Config.theme.fontSize

                                        onConfigValueChanged: {
                                            if (text !== configValue.toString()) {
                                                text = configValue.toString();
                                            }
                                        }

                                        Component.onCompleted: text = configValue.toString()

                                        onEditingFinished: {
                                            let newSize = parseInt(text);
                                            if (!isNaN(newSize) && newSize >= 8 && newSize <= 32 && newSize !== Config.theme.fontSize) {
                                                GlobalStates.markThemeChanged();
                                                Config.theme.fontSize = newSize;
                                            }
                                        }
                                    }
                                }

                                Text {
                                    text: I18n.t("px")
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(0)
                                    color: Colors.overSurfaceVariant
                                }
                            }

                            // Mono Font row
                            RowLayout {
                                LayoutMirroring.enabled: I18n.isRtl
                                LayoutMirroring.childrenInherit: true
                                Layout.fillWidth: true
                                spacing: 12

                                Text {
                                    text: I18n.t("Mono Font")
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(0)
                                    color: Colors.overBackground
                                    Layout.preferredWidth: 80
                                    horizontalAlignment: I18n.isRtl ? Text.AlignRight : Text.AlignLeft
                                    elide: Text.ElideRight
                                    wrapMode: Text.NoWrap
                                }

                                StyledRect {
                                    variant: "common"
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 32
                                    radius: Styling.radius(-2)

                                    TextInput {
                                        id: monoFontInput
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        font.family: Config.theme.monoFont
                                        font.pixelSize: Styling.monoFontSize(0)
                                        color: Colors.overBackground
                                        selectByMouse: true
                                        clip: true
                                        verticalAlignment: TextInput.AlignVCenter
                                        horizontalAlignment: I18n.isRtl ? TextInput.AlignRight : TextInput.AlignLeft

                                        readonly property string configValue: Config.theme.monoFont

                                        onConfigValueChanged: {
                                            if (text !== configValue) {
                                                text = configValue;
                                            }
                                        }

                                        Component.onCompleted: text = configValue

                                        onEditingFinished: {
                                            if (text !== Config.theme.monoFont && text.trim() !== "") {
                                                GlobalStates.markThemeChanged();
                                                Config.theme.monoFont = text.trim();
                                            }
                                        }
                                    }
                                }

                                StyledRect {
                                    variant: "common"
                                    Layout.preferredWidth: 60
                                    Layout.preferredHeight: 32
                                    radius: Styling.radius(-2)

                                    TextInput {
                                        id: monoFontSizeInput
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        font.family: Config.theme.monoFont
                                        font.pixelSize: Styling.monoFontSize(0)
                                        color: Colors.overBackground
                                        selectByMouse: true
                                        clip: true
                                        verticalAlignment: TextInput.AlignVCenter
                                        horizontalAlignment: TextInput.AlignHCenter
                                        validator: IntValidator {
                                            bottom: 8
                                            top: 32
                                        }

                                        readonly property int configValue: Config.theme.monoFontSize

                                        onConfigValueChanged: {
                                            if (text !== configValue.toString()) {
                                                text = configValue.toString();
                                            }
                                        }

                                        Component.onCompleted: text = configValue.toString()

                                        onEditingFinished: {
                                            let newSize = parseInt(text);
                                            if (!isNaN(newSize) && newSize >= 8 && newSize <= 32 && newSize !== Config.theme.monoFontSize) {
                                                GlobalStates.markThemeChanged();
                                                Config.theme.monoFontSize = newSize;
                                            }
                                        }
                                    }
                                }

                                Text {
                                    text: I18n.t("px")
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(0)
                                    color: Colors.overSurfaceVariant
                                }
                            }

                            Separator {
                                Layout.fillWidth: true
                            }

                            Text {
                                text: I18n.t("Roundness")
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                font.weight: Font.Medium
                                color: Colors.overSurfaceVariant
                                Layout.bottomMargin: -4
                            }

                            RowLayout {
                                LayoutMirroring.enabled: I18n.isRtl
                                LayoutMirroring.childrenInherit: true
                                Layout.fillWidth: true
                                spacing: 12

                                StyledSlider {
                                    id: roundnessSlider
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 20
                                    progressColor: Styling.srItem("overprimary")
                                    tooltipText: `${Math.round(value * 20)}`
                                    scroll: true
                                    stepSize: 0.05  // 1/20 = 0.05 for integer steps in 0-20 range
                                    snapMode: "always"

                                    // Use a computed property that always reads from Config
                                    readonly property real configValue: Config.theme.roundness / 20

                                    // Sync value when configValue changes (e.g., after discard)
                                    onConfigValueChanged: {
                                        if (Math.abs(value - configValue) > 0.001) {
                                            value = configValue;
                                        }
                                    }

                                    Component.onCompleted: value = configValue

                                    onValueChanged: {
                                        let newRoundness = Math.round(value * 20);
                                        if (newRoundness !== Config.theme.roundness) {
                                            GlobalStates.markThemeChanged();
                                            Config.theme.roundness = newRoundness;
                                        }
                                    }
                                }

                                Text {
                                    text: Math.round(roundnessSlider.value * 20)
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(0)
                                    color: Colors.overBackground
                                    horizontalAlignment: Text.AlignRight
                                    Layout.preferredWidth: 24
                                }
                            }
                        }
                    }

                    // Shadow section
                    Item {
                        visible: root.currentSection === "shadow"
                        Layout.fillWidth: true
                        Layout.preferredHeight: shadowContent.implicitHeight

                        ColumnLayout {
                            id: shadowContent
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            spacing: 12

                            Text {
                                text: I18n.t("Shadow")
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                font.weight: Font.Medium
                                color: Colors.overSurfaceVariant
                                Layout.bottomMargin: -4
                            }

                            // Opacity row
                            RowLayout {
                                LayoutMirroring.enabled: I18n.isRtl
                                LayoutMirroring.childrenInherit: true
                                Layout.fillWidth: true
                                spacing: 12

                                Text {
                                    text: I18n.t("Opacity")
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(0)
                                    color: Colors.overBackground
                                    Layout.preferredWidth: 80
                                    horizontalAlignment: I18n.isRtl ? Text.AlignRight : Text.AlignLeft
                                    elide: Text.ElideRight
                                    wrapMode: Text.NoWrap
                                }

                                StyledSlider {
                                    id: shadowOpacitySlider
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 20
                                    progressColor: Styling.srItem("overprimary")
                                    tooltipText: `${Math.round(value * 100)}%`
                                    scroll: true
                                    stepSize: 0.01
                                    snapMode: "always"

                                    readonly property real configValue: Config.theme.shadowOpacity

                                    onConfigValueChanged: {
                                        if (Math.abs(value - configValue) > 0.001) {
                                            value = configValue;
                                        }
                                    }

                                    Component.onCompleted: value = configValue

                                    onValueChanged: {
                                        if (Math.abs(value - Config.theme.shadowOpacity) > 0.001) {
                                            GlobalStates.markThemeChanged();
                                            Config.theme.shadowOpacity = value;
                                        }
                                    }
                                }

                                Text {
                                    text: Math.round(shadowOpacitySlider.value * 100) + "%"
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(0)
                                    color: Colors.overBackground
                                    horizontalAlignment: Text.AlignRight
                                    Layout.preferredWidth: 40
                                }
                            }

                            // Blur row
                            RowLayout {
                                LayoutMirroring.enabled: I18n.isRtl
                                LayoutMirroring.childrenInherit: true
                                Layout.fillWidth: true
                                spacing: 12

                                Text {
                                    text: I18n.t("Blur")
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(0)
                                    color: Colors.overBackground
                                    Layout.preferredWidth: 80
                                    horizontalAlignment: I18n.isRtl ? Text.AlignRight : Text.AlignLeft
                                    elide: Text.ElideRight
                                    wrapMode: Text.NoWrap
                                }

                                StyledSlider {
                                    id: shadowBlurSlider
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 20
                                    progressColor: Styling.srItem("overprimary")
                                    tooltipText: `${(value * 4).toFixed(1)}`
                                    scroll: true
                                    stepSize: 0.01
                                    snapMode: "always"

                                    readonly property real configValue: Config.theme.shadowBlur / 4

                                    onConfigValueChanged: {
                                        if (Math.abs(value - configValue) > 0.001) {
                                            value = configValue;
                                        }
                                    }

                                    Component.onCompleted: value = configValue

                                    onValueChanged: {
                                        let newBlur = value * 4;
                                        if (Math.abs(newBlur - Config.theme.shadowBlur) > 0.01) {
                                            GlobalStates.markThemeChanged();
                                            Config.theme.shadowBlur = newBlur;
                                        }
                                    }
                                }

                                Text {
                                    text: Config.theme.shadowBlur.toFixed(1)
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(0)
                                    color: Colors.overBackground
                                    horizontalAlignment: Text.AlignRight
                                    Layout.preferredWidth: 40
                                }
                            }

                            // Offset row (X and Y)
                            RowLayout {
                                LayoutMirroring.enabled: I18n.isRtl
                                LayoutMirroring.childrenInherit: true
                                Layout.fillWidth: true
                                spacing: 12

                                Text {
                                    text: I18n.t("Offset X")
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(0)
                                    color: Colors.overBackground
                                    Layout.preferredWidth: 80
                                    horizontalAlignment: I18n.isRtl ? Text.AlignRight : Text.AlignLeft
                                    elide: Text.ElideRight
                                    wrapMode: Text.NoWrap
                                }

                                StyledSlider {
                                    id: shadowXOffsetSlider
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 20
                                    progressColor: Styling.srItem("overprimary")
                                    tooltipText: `${Math.round((value - 0.5) * 40)}`
                                    scroll: true
                                    stepSize: 0.025  // 1/40 for integer steps in -20 to +20 range
                                    snapMode: "always"

                                    readonly property real configValue: (Config.theme.shadowXOffset + 20) / 40

                                    onConfigValueChanged: {
                                        if (Math.abs(value - configValue) > 0.001) {
                                            value = configValue;
                                        }
                                    }

                                    Component.onCompleted: value = configValue

                                    onValueChanged: {
                                        let newOffset = Math.round((value - 0.5) * 40);
                                        if (newOffset !== Config.theme.shadowXOffset) {
                                            GlobalStates.markThemeChanged();
                                            Config.theme.shadowXOffset = newOffset;
                                        }
                                    }
                                }

                                Text {
                                    text: Config.theme.shadowXOffset
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(0)
                                    color: Colors.overBackground
                                    horizontalAlignment: Text.AlignRight
                                    Layout.preferredWidth: 40
                                }
                            }

                            RowLayout {
                                LayoutMirroring.enabled: I18n.isRtl
                                LayoutMirroring.childrenInherit: true
                                Layout.fillWidth: true
                                spacing: 12

                                Text {
                                    text: I18n.t("Offset Y")
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(0)
                                    color: Colors.overBackground
                                    Layout.preferredWidth: 80
                                    horizontalAlignment: I18n.isRtl ? Text.AlignRight : Text.AlignLeft
                                    elide: Text.ElideRight
                                    wrapMode: Text.NoWrap
                                }

                                StyledSlider {
                                    id: shadowYOffsetSlider
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 20
                                    progressColor: Styling.srItem("overprimary")
                                    tooltipText: `${Math.round((value - 0.5) * 40)}`
                                    scroll: true
                                    stepSize: 0.025  // 1/40 for integer steps in -20 to +20 range
                                    snapMode: "always"

                                    readonly property real configValue: (Config.theme.shadowYOffset + 20) / 40

                                    onConfigValueChanged: {
                                        if (Math.abs(value - configValue) > 0.001) {
                                            value = configValue;
                                        }
                                    }

                                    Component.onCompleted: value = configValue

                                    onValueChanged: {
                                        let newOffset = Math.round((value - 0.5) * 40);
                                        if (newOffset !== Config.theme.shadowYOffset) {
                                            GlobalStates.markThemeChanged();
                                            Config.theme.shadowYOffset = newOffset;
                                        }
                                    }
                                }

                                Text {
                                    text: Config.theme.shadowYOffset
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(0)
                                    color: Colors.overBackground
                                    horizontalAlignment: Text.AlignRight
                                    Layout.preferredWidth: 40
                                }
                            }

                            // Color row
                            RowLayout {
                                LayoutMirroring.enabled: I18n.isRtl
                                LayoutMirroring.childrenInherit: true
                                Layout.fillWidth: true
                                spacing: 12

                                Text {
                                    text: I18n.t("Color")
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(0)
                                    color: Colors.overBackground
                                    Layout.preferredWidth: 80
                                    horizontalAlignment: I18n.isRtl ? Text.AlignRight : Text.AlignLeft
                                    elide: Text.ElideRight
                                    wrapMode: Text.NoWrap
                                }

                                StyledRect {
                                    id: shadowColorButton
                                    variant: "common"
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 32
                                    radius: Styling.radius(-2)

                                    property bool isHovered: false

                                    RowLayout {
                                        LayoutMirroring.enabled: I18n.isRtl
                                        LayoutMirroring.childrenInherit: true
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        spacing: 12

                                        Rectangle {
                                            Layout.preferredWidth: 16
                                            Layout.preferredHeight: 16
                                            radius: 4
                                            color: Config.resolveColor(Config.theme.shadowColor)
                                            border.width: 1
                                            border.color: Colors.outline
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: Config.theme.shadowColor
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(0)
                                            color: shadowColorButton.item
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        color: Styling.srItem("overprimary")
                                        radius: shadowColorButton.radius ?? 0
                                        opacity: shadowColorButton.isHovered ? 0.15 : 0

                                        Behavior on opacity {
                                            enabled: (Config.animDuration ?? 0) > 0
                                            NumberAnimation {
                                                duration: (Config.animDuration ?? 0) / 2
                                            }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor

                                        onEntered: shadowColorButton.isHovered = true
                                        onExited: shadowColorButton.isHovered = false

                                        onClicked: {
                                            root.openColorPicker(Colors.availableColorNames, Config.theme.shadowColor, "Select Shadow Color", function (color) {
                                                GlobalStates.markThemeChanged();
                                                Config.theme.shadowColor = color;
                                            });
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Variant selector section
                    Item {
                        id: variantSelectorPane
                        visible: root.currentSection === "colors"
                        Layout.fillWidth: true
                        Layout.preferredHeight: variantSelectorContent.implicitHeight

                        property bool variantExpanded: false

                        Behavior on Layout.preferredHeight {
                            enabled: (Config.animDuration ?? 0) > 0
                            NumberAnimation {
                                duration: (Config.animDuration ?? 0) / 2
                                easing.type: Easing.OutCubic
                            }
                        }

                        ColumnLayout {
                            id: variantSelectorContent
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            spacing: 12

                            Text {
                                text: I18n.t("Variant")
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                font.weight: Font.Medium
                                color: Colors.overSurfaceVariant
                                Layout.bottomMargin: -4
                            }

                            RowLayout {
                                LayoutMirroring.enabled: I18n.isRtl
                                LayoutMirroring.childrenInherit: true
                                Layout.fillWidth: true
                                spacing: 12
                                Layout.alignment: Qt.AlignTop

                                // Collapsed mode: horizontal scrollable row with scrollbar
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    visible: !variantSelectorPane.variantExpanded

                                    Flickable {
                                        id: variantFlickable
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 32
                                        contentWidth: variantRow.width
                                        flickableDirection: Flickable.HorizontalFlick
                                        clip: true
                                        boundsBehavior: Flickable.StopAtBounds

                                        Row {
                                            id: variantRow
                                            spacing: 4

                                            Repeater {
                                                model: root.allVariants

                                                delegate: StyledRect {
                                                    id: variantTagRow
                                                    required property var modelData
                                                    required property int index

                                                    property bool isSelected: root.selectedVariant === modelData.id
                                                    property bool isHovered: false

                                                    variant: modelData.id
                                                    enableShadow: true

                                                    width: tagContentRow.width + 24 + (isSelected ? checkIconRow.width + 4 : 0)
                                                    height: 32
                                                    radius: isSelected ? Styling.radius(0) / 2 : Styling.radius(0)

                                                    Behavior on width {
                                                        enabled: (Config.animDuration ?? 0) > 0
                                                        NumberAnimation {
                                                            duration: (Config.animDuration ?? 0) / 3
                                                            easing.type: Easing.OutCubic
                                                        }
                                                    }

                                                    Item {
                                                        anchors.fill: parent
                                                        anchors.margins: 8

                                                        Row {
                                                            anchors.centerIn: parent
                                                            spacing: variantTagRow.isSelected ? 4 : 0

                                                            Item {
                                                                width: checkIconRow.visible ? checkIconRow.width : 0
                                                                height: checkIconRow.height
                                                                clip: true

                                                                Text {
                                                                    id: checkIconRow
                                                                    text: Icons.accept
                                                                    font.family: Icons.font
                                                                    font.pixelSize: 16
                                                                    color: variantTagRow.item
                                                                    visible: variantTagRow.isSelected
                                                                    opacity: variantTagRow.isSelected ? 1 : 0

                                                                    Behavior on opacity {
                                                                        enabled: (Config.animDuration ?? 0) > 0
                                                                        NumberAnimation {
                                                                            duration: (Config.animDuration ?? 0) / 3
                                                                            easing.type: Easing.OutCubic
                                                                        }
                                                                    }
                                                                }

                                                                Behavior on width {
                                                                    enabled: (Config.animDuration ?? 0) > 0
                                                                    NumberAnimation {
                                                                        duration: (Config.animDuration ?? 0) / 3
                                                                        easing.type: Easing.OutCubic
                                                                    }
                                                                }
                                                            }

                                                            Text {
                                                                id: tagContentRow
                                                                text: variantTagRow.modelData.label
                                                                font.family: Config.theme.font
                                                                font.pixelSize: Config.theme.fontSize
                                                                font.bold: true
                                                                color: variantTagRow.item

                                                                Behavior on color {
                                                                    enabled: (Config.animDuration ?? 0) > 0
                                                                    ColorAnimation {
                                                                        duration: (Config.animDuration ?? 0) / 3
                                                                        easing.type: Easing.OutCubic
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }

                                                    Rectangle {
                                                        anchors.fill: parent
                                                        color: Styling.srItem("overprimary")
                                                        radius: variantTagRow.radius ?? 0
                                                        opacity: variantTagRow.isHovered ? 0.15 : 0

                                                        Behavior on opacity {
                                                            enabled: (Config.animDuration ?? 0) > 0
                                                            NumberAnimation {
                                                                duration: (Config.animDuration ?? 0) / 2
                                                            }
                                                        }
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor

                                                        onEntered: variantTagRow.isHovered = true
                                                        onExited: variantTagRow.isHovered = false

                                                        onClicked: root.selectedVariant = variantTagRow.modelData.id
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    ScrollBar {
                                        id: variantScrollBar
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 8
                                        orientation: Qt.Horizontal

                                        position: variantFlickable.contentWidth > 0 ? variantFlickable.contentX / variantFlickable.contentWidth : 0
                                        size: variantFlickable.contentWidth > 0 ? variantFlickable.width / variantFlickable.contentWidth : 1

                                        property bool scrollBarPressed: false

                                        background: Rectangle {
                                            implicitHeight: 8
                                            color: Colors.surface
                                            radius: 4
                                        }

                                        contentItem: Rectangle {
                                            implicitHeight: 8
                                            color: Styling.srItem("overprimary")
                                            radius: 4
                                        }

                                        onPressedChanged: {
                                            scrollBarPressed = pressed;
                                        }

                                        onPositionChanged: {
                                            if (scrollBarPressed && variantFlickable.contentWidth > variantFlickable.width) {
                                                variantFlickable.contentX = position * variantFlickable.contentWidth;
                                            }
                                        }
                                    }
                                }

                                // Expanded mode: Flow grid
                                Flow {
                                    id: variantsFlow
                                    Layout.fillWidth: true
                                    spacing: 4
                                    visible: variantSelectorPane.variantExpanded

                                    Repeater {
                                        model: root.allVariants

                                        delegate: StyledRect {
                                            id: variantTag
                                            required property var modelData
                                            required property int index

                                            property bool isSelected: root.selectedVariant === modelData.id
                                            property bool isHovered: false

                                            variant: modelData.id
                                            enableShadow: true

                                            width: tagContent.width + 24 + (isSelected ? checkIcon.width + 4 : 0)
                                            height: 32
                                            radius: isSelected ? Styling.radius(0) / 2 : Styling.radius(0)

                                            Behavior on width {
                                                enabled: (Config.animDuration ?? 0) > 0
                                                NumberAnimation {
                                                    duration: (Config.animDuration ?? 0) / 3
                                                    easing.type: Easing.OutCubic
                                                }
                                            }

                                            Item {
                                                anchors.fill: parent
                                                anchors.margins: 8

                                                Row {
                                                    anchors.centerIn: parent
                                                    spacing: variantTag.isSelected ? 4 : 0

                                                    Item {
                                                        width: checkIcon.visible ? checkIcon.width : 0
                                                        height: checkIcon.height
                                                        clip: true

                                                        Text {
                                                            id: checkIcon
                                                            text: Icons.accept
                                                            font.family: Icons.font
                                                            font.pixelSize: 16
                                                            color: variantTag.item
                                                            visible: variantTag.isSelected
                                                            opacity: variantTag.isSelected ? 1 : 0

                                                            Behavior on opacity {
                                                                enabled: (Config.animDuration ?? 0) > 0
                                                                NumberAnimation {
                                                                    duration: (Config.animDuration ?? 0) / 3
                                                                    easing.type: Easing.OutCubic
                                                                }
                                                            }
                                                        }

                                                        Behavior on width {
                                                            enabled: (Config.animDuration ?? 0) > 0
                                                            NumberAnimation {
                                                                duration: (Config.animDuration ?? 0) / 3
                                                                easing.type: Easing.OutCubic
                                                            }
                                                        }
                                                    }

                                                    Text {
                                                        id: tagContent
                                                        text: variantTag.modelData.label
                                                        font.family: Config.theme.font
                                                        font.pixelSize: Config.theme.fontSize
                                                        font.bold: true
                                                        color: variantTag.item

                                                        Behavior on color {
                                                            enabled: (Config.animDuration ?? 0) > 0
                                                            ColorAnimation {
                                                                duration: (Config.animDuration ?? 0) / 3
                                                                easing.type: Easing.OutCubic
                                                            }
                                                        }
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                id: hoverOverlay
                                                anchors.fill: parent
                                                color: Styling.srItem("overprimary")
                                                radius: variantTag.radius ?? 0
                                                opacity: variantTag.isHovered ? 0.15 : 0

                                                Behavior on opacity {
                                                    enabled: (Config.animDuration ?? 0) > 0
                                                    NumberAnimation {
                                                        duration: (Config.animDuration ?? 0) / 2
                                                    }
                                                }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor

                                                onEntered: variantTag.isHovered = true
                                                onExited: variantTag.isHovered = false

                                                onClicked: root.selectedVariant = variantTag.modelData.id
                                            }
                                        }
                                    }
                                }

                                // Toggle expand/collapse button
                                StyledRect {
                                    id: expandToggleButton
                                    variant: isHovered ? "focus" : "common"
                                    width: 32
                                    height: 32
                                    radius: Styling.radius(-2)
                                    Layout.alignment: Qt.AlignTop
                                    enableShadow: true

                                    property bool isHovered: false

                                    Text {
                                        anchors.centerIn: parent
                                        text: variantSelectorPane.variantExpanded ? Icons.caretUp : Icons.caretDown
                                        font.family: Icons.font
                                        font.pixelSize: 16
                                        color: expandToggleButton.item
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor

                                        onEntered: expandToggleButton.isHovered = true
                                        onExited: expandToggleButton.isHovered = false

                                        onClicked: variantSelectorPane.variantExpanded = !variantSelectorPane.variantExpanded
                                    }
                                }
                            }
                        }
                    }

                    // Editor section
                    Item {
                        visible: root.currentSection === "colors"
                        Layout.fillWidth: true
                        Layout.preferredHeight: editorContent.implicitHeight

                        ColumnLayout {
                            id: editorContent
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            spacing: 12

                            Text {
                                text: I18n.t("Editor - {0}", "Editor - {0}", [root.getVariantLabel(root.selectedVariant)])
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                font.weight: Font.Medium
                                color: Colors.overSurfaceVariant
                                Layout.bottomMargin: -4
                            }

                            VariantEditor {
                                Layout.fillWidth: true
                                variantId: root.selectedVariant
                                onClose: {}
                                onOpenColorPickerRequested: (colorNames, currentColor, dialogTitle, callback) => {
                                    root.openColorPicker(colorNames, currentColor, dialogTitle, callback);
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
            id: pickerTranslate
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
            // Consume all mouse events to prevent pass-through
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
