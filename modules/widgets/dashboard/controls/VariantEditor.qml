pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.components
import qs.modules.globals
import qs.config

Item {
    id: root

    required property string variantId

    signal close
    signal openColorPickerRequested(var colorNames, string currentColor, string dialogTitle, var callback)

    implicitHeight: mainColumn.implicitHeight

    // Get the Config object for this variant (reads directly from Config)
    readonly property var variantConfig: {
        // Convert variant id to sr property name (e.g., "bg" -> "srBg", "primaryfocus" -> "srPrimaryfocus")
        let srName = "sr" + variantId.charAt(0).toUpperCase() + variantId.slice(1);
        // Try to get the property from Config.theme
        let config = Config.theme[srName];
        if (config && typeof config === "object") {
            return config;
        }
        // Fallback: search for matching property (handles case variations)
        for (let prop in Config.theme) {
            if (prop.toLowerCase() === srName.toLowerCase()) {
                return Config.theme[prop];
            }
        }
        return null;
    }

    // List of available color names from Colors singleton
    readonly property var colorNames: Colors.availableColorNames

    // Gradient type options
    readonly property var gradientTypes: ["linear", "radial", "halftone"]

    // Helper to update a property - updates Config directly
    function updateProp(prop, value) {
        if (variantConfig) {
            GlobalStates.markThemeChanged();
            variantConfig[prop] = value;
        }
    }

    ColumnLayout {
        id: mainColumn
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 8
        enabled: root.variantConfig !== null

        // === GRADIENT TYPE SELECTOR ===
        Row {
            id: typeSelector
            Layout.fillWidth: true
            spacing: 4

            readonly property int currentIndex: {
                if (!root.variantConfig)
                    return 0;
                const idx = root.gradientTypes.indexOf(root.variantConfig.gradientType);
                return idx >= 0 ? idx : 0;
            }

            Repeater {
                model: root.gradientTypes

                delegate: StyledRect {
                    id: typeButton
                    required property string modelData
                    required property int index

                    readonly property bool isSelected: typeSelector.currentIndex === index
                    property bool isHovered: false

                    variant: isSelected ? "primary" : (isHovered ? "focus" : "common")
                    enableShadow: true
                    width: (typeSelector.width - (root.gradientTypes.length - 1) * typeSelector.spacing) / root.gradientTypes.length
                    height: 36
                    radius: isSelected ? Styling.radius(0) / 2 : Styling.radius(0)

                    Text {
                        id: typeIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            switch (typeButton.modelData) {
                            case "linear":
                                return Icons.arrowFatLinesDown;
                            case "radial":
                                return Icons.arrowsOutCardinal;
                            case "halftone":
                                return Icons.dotsNine;
                            default:
                                return "";
                            }
                        }
                        font.family: Icons.font
                        font.pixelSize: 14
                        color: typeButton.itemColor
                    }

                    Text {
                        anchors.centerIn: parent
                        text: typeButton.modelData.charAt(0).toUpperCase() + typeButton.modelData.slice(1)
                        font.family: Styling.defaultFont
                        font.pixelSize: Styling.fontSize(0)
                        font.bold: true
                        color: typeButton.itemColor
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onEntered: typeButton.isHovered = true
                        onExited: typeButton.isHovered = false

                        onClicked: root.updateProp("gradientType", typeButton.modelData)
                    }
                }
            }
        }

        // === MAIN PROPERTIES ROW ===
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Item Color
            ColorButton {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                colorNames: root.colorNames
                currentColor: (root.variantConfig && root.variantConfig.itemColor) ? root.variantConfig.itemColor : "surface"
                label: "Item Color"
                dialogTitle: "Select Item Color"
                onColorSelected: color => root.updateProp("itemColor", color)
                onOpenColorPicker: (names, current, title) => {
                    root.openColorPickerRequested(names, current, title, function (color) {
                        root.updateProp("itemColor", color);
                    });
                }
            }

            // Opacity + Border Controls Container
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                spacing: 8

                // Opacity Control
                StyledRect {
                    id: opacityControl
                    variant: "pane"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    radius: Styling.radius(-1)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 4
                        anchors.rightMargin: 12
                        spacing: 8

                        // CircularControl
                        CircularControl {
                            icon: Icons.circleHalf
                            value: root.variantConfig ? root.variantConfig.opacity : 1.0
                            accentColor: Styling.srItem("overprimary")
                            isToggleable: false
                            isToggled: false
                            showBackground: false
                            onControlValueChanged: newValue => root.updateProp("opacity", newValue)
                        }

                        // Label + Value
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: "Opacity"
                                font.family: Styling.defaultFont
                                font.pixelSize: Styling.fontSize(-2)
                                font.bold: true
                                color: opacityControl.itemColor
                                opacity: 0.6
                            }

                            Text {
                                Layout.fillWidth: true
                                text: root.variantConfig ? (root.variantConfig.opacity * 100).toFixed(0) + "%" : "100%"
                                font.family: Styling.defaultFont
                                font.pixelSize: Styling.fontSize(1)
                                font.bold: true
                                color: opacityControl.itemColor
                            }
                        }
                    }
                }

                // Border Control
                StyledRect {
                    id: borderControl
                    variant: "pane"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    radius: Styling.radius(-1)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 4
                        anchors.rightMargin: 12
                        spacing: 8

                        // CircularControl with ColorButton as center
                        Item {
                            width: 48
                            height: 48

                            // Color button in center (behind CircularControl for visual, but we handle click separately)
                            Rectangle {
                                id: borderColorButton
                                anchors.centerIn: parent
                                width: 20
                                height: 20
                                radius: width / 2
                                color: root.variantConfig ? Config.resolveColor(root.variantConfig.border[0]) : Colors.outline
                                border.width: 2
                                border.color: Colors.overBackground
                                z: 0
                            }

                            CircularControl {
                                id: borderCircular
                                anchors.fill: parent
                                icon: ""
                                value: root.variantConfig ? root.variantConfig.border[1] / 16 : 0
                                accentColor: root.variantConfig ? Config.resolveColor(root.variantConfig.border[0]) : Colors.outline
                                isToggleable: true
                                isToggled: false
                                showBackground: false
                                z: 1
                                onControlValueChanged: newValue => {
                                    if (root.variantConfig) {
                                        const newWidth = Math.round(newValue * 16);
                                        root.updateProp("border", [root.variantConfig.border[0], newWidth]);
                                    }
                                }
                                onToggled: {
                                    root.openColorPickerRequested(root.colorNames, root.variantConfig ? root.variantConfig.border[0] : "outline", "Select Border Color", function (color) {
                                        if (!root.variantConfig)
                                            return;
                                        root.updateProp("border", [color, root.variantConfig.border[1]]);
                                    });
                                }
                            }
                        }

                        // Label + Value
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: "Border"
                                font.family: Styling.defaultFont
                                font.pixelSize: Styling.fontSize(-2)
                                font.bold: true
                                color: borderControl.itemColor
                                opacity: 0.6
                            }

                            Text {
                                Layout.fillWidth: true
                                text: root.variantConfig ? root.variantConfig.border[1] + "px" : "0px"
                                font.family: Styling.defaultFont
                                font.pixelSize: Styling.fontSize(1)
                                font.bold: true
                                color: borderControl.itemColor
                            }
                        }
                    }
                }
            }
        }

        // === GRADIENT STOPS (for linear/radial) ===
        GradientStopsEditor {
            Layout.fillWidth: true
            colorNames: root.colorNames
            stops: root.variantConfig ? root.variantConfig.gradient : []
            variantId: root.variantId
            visible: root.variantConfig && root.variantConfig.gradientType !== "halftone"
            onUpdateStops: newStops => root.updateProp("gradient", newStops)
            onOpenColorPickerRequested: (colorNames, currentColor, dialogTitle, callback) => {
                root.openColorPickerRequested(colorNames, currentColor, dialogTitle, callback);
            }
        }

        // === LINEAR SETTINGS ===
        StyledRect {
            variant: "common"
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            radius: Styling.radius(-2)
            visible: root.variantConfig && root.variantConfig.gradientType === "linear"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 16

                Text {
                    text: Icons.arrowDown
                    font.family: Icons.font
                    font.pixelSize: 20
                    color: Styling.srItem("overprimary")
                    rotation: root.variantConfig ? root.variantConfig.gradientAngle : 0

                    Behavior on rotation {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Config.animDuration / 2
                            easing.type: Easing.OutQuart
                        }
                    }
                }

                ColumnLayout {
                    spacing: 2

                    Text {
                        text: "Angle"
                        font.family: Styling.defaultFont
                        font.pixelSize: Styling.fontSize(-2)
                        font.bold: true
                        color: Colors.overBackground
                        opacity: 0.6
                    }

                    Text {
                        text: root.variantConfig ? root.variantConfig.gradientAngle + "°" : "0°"
                        font.family: Styling.defaultFont
                        font.pixelSize: Styling.fontSize(1)
                        font.bold: true
                        color: Colors.overBackground
                    }
                }

                StyledSlider {
                    id: linearAngleSlider
                    Layout.fillWidth: true
                    Layout.preferredHeight: 24
                    resizeParent: false
                    scroll: false
                    tooltip: true
                    tooltipText: Math.round(value * 360) + "°"

                    readonly property real configValue: root.variantConfig ? root.variantConfig.gradientAngle / 360 : 0
                    onConfigValueChanged: if (Math.abs(value - configValue) > 0.001)
                        value = configValue
                    Component.onCompleted: value = configValue

                    onValueChanged: {
                        if (root.variantConfig) {
                            const newAngle = Math.round(value * 360);
                            if (newAngle !== root.variantConfig.gradientAngle) {
                                root.updateProp("gradientAngle", newAngle);
                            }
                        }
                    }
                }
            }
        }

        // === RADIAL SETTINGS ===
        StyledRect {
            variant: "common"
            Layout.fillWidth: true
            Layout.preferredHeight: 100
            radius: Styling.radius(-2)
            visible: root.variantConfig && root.variantConfig.gradientType === "radial"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                // X Position
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Text {
                        text: "X"
                        font.family: Styling.defaultFont
                        font.pixelSize: Styling.fontSize(0)
                        font.bold: true
                        color: Styling.srItem("overprimary")
                        Layout.preferredWidth: 20
                    }

                    StyledSlider {
                        id: centerXSlider
                        Layout.fillWidth: true
                        Layout.preferredHeight: 20
                        resizeParent: false
                        scroll: false
                        tooltip: true
                        tooltipText: (value * 100).toFixed(0) + "%"

                        readonly property real configValue: root.variantConfig ? root.variantConfig.gradientCenterX : 0.5
                        onConfigValueChanged: if (Math.abs(value - configValue) > 0.001)
                            value = configValue
                        Component.onCompleted: value = configValue

                        onValueChanged: {
                            if (root.variantConfig && Math.abs(value - root.variantConfig.gradientCenterX) > 0.001) {
                                root.updateProp("gradientCenterX", value);
                            }
                        }
                    }

                    Text {
                        text: root.variantConfig ? (root.variantConfig.gradientCenterX * 100).toFixed(0) + "%" : "50%"
                        font.family: Styling.defaultFont
                        font.pixelSize: Styling.fontSize(0)
                        font.bold: true
                        color: Colors.overBackground
                        Layout.preferredWidth: 40
                        horizontalAlignment: Text.AlignRight
                    }
                }

                // Y Position
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Text {
                        text: "Y"
                        font.family: Styling.defaultFont
                        font.pixelSize: Styling.fontSize(0)
                        font.bold: true
                        color: Styling.srItem("overprimary")
                        Layout.preferredWidth: 20
                    }

                    StyledSlider {
                        id: centerYSlider
                        Layout.fillWidth: true
                        Layout.preferredHeight: 20
                        resizeParent: false
                        scroll: false
                        tooltip: true
                        tooltipText: (value * 100).toFixed(0) + "%"

                        readonly property real configValue: root.variantConfig ? root.variantConfig.gradientCenterY : 0.5
                        onConfigValueChanged: if (Math.abs(value - configValue) > 0.001)
                            value = configValue
                        Component.onCompleted: value = configValue

                        onValueChanged: {
                            if (root.variantConfig && Math.abs(value - root.variantConfig.gradientCenterY) > 0.001) {
                                root.updateProp("gradientCenterY", value);
                            }
                        }
                    }

                    Text {
                        text: root.variantConfig ? (root.variantConfig.gradientCenterY * 100).toFixed(0) + "%" : "50%"
                        font.family: Styling.defaultFont
                        font.pixelSize: Styling.fontSize(0)
                        font.bold: true
                        color: Colors.overBackground
                        Layout.preferredWidth: 40
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }

        // === HALFTONE SETTINGS ===
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: root.variantConfig && root.variantConfig.gradientType === "halftone"

            // Colors row
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // Dot Color
                ColorButton {
                    Layout.fillWidth: true
                    colorNames: root.colorNames
                    currentColor: (root.variantConfig && root.variantConfig.halftoneDotColor) ? root.variantConfig.halftoneDotColor : "surface"
                    label: "Dot Color"
                    circlePreview: true
                    dialogTitle: "Select Dot Color"
                    onColorSelected: color => root.updateProp("halftoneDotColor", color)
                    onOpenColorPicker: (names, current, title) => {
                        root.openColorPickerRequested(names, current, title, function (color) {
                            root.updateProp("halftoneDotColor", color);
                        });
                    }
                }

                // Background Color
                ColorButton {
                    Layout.fillWidth: true
                    colorNames: root.colorNames
                    currentColor: (root.variantConfig && root.variantConfig.halftoneBackgroundColor) ? root.variantConfig.halftoneBackgroundColor : "surface"
                    label: "Background"
                    dialogTitle: "Select Background Color"
                    onColorSelected: color => root.updateProp("halftoneBackgroundColor", color)
                    onOpenColorPicker: (names, current, title) => {
                        root.openColorPickerRequested(names, current, title, function (color) {
                            root.updateProp("halftoneBackgroundColor", color);
                        });
                    }
                }
            }

            // Halftone controls
            StyledRect {
                variant: "common"
                Layout.fillWidth: true
                Layout.preferredHeight: 160
                radius: Styling.radius(-2)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    // Angle
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Item {
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24

                            Text {
                                anchors.centerIn: parent
                                text: Icons.arrowDown
                                font.family: Icons.font
                                font.pixelSize: 18
                                color: Styling.srItem("overprimary")
                                rotation: root.variantConfig ? root.variantConfig.gradientAngle : 0

                                Behavior on rotation {
                                    enabled: Config.animDuration > 0
                                    NumberAnimation {
                                        duration: Config.animDuration / 2
                                        easing.type: Easing.OutQuart
                                    }
                                }
                            }
                        }

                        Text {
                            text: "Angle"
                            font.family: Styling.defaultFont
                            font.pixelSize: Styling.fontSize(0)
                            font.bold: true
                            color: Colors.overBackground
                            Layout.preferredWidth: 60
                        }

                        StyledSlider {
                            id: halftoneAngleSlider
                            Layout.fillWidth: true
                            Layout.preferredHeight: 20
                            resizeParent: false
                            scroll: false
                            tooltip: false

                            readonly property real configValue: root.variantConfig ? root.variantConfig.gradientAngle / 360 : 0
                            onConfigValueChanged: if (Math.abs(value - configValue) > 0.001)
                                value = configValue
                            Component.onCompleted: value = configValue

                            onValueChanged: {
                                if (root.variantConfig) {
                                    const newAngle = Math.round(value * 360);
                                    if (newAngle !== root.variantConfig.gradientAngle) {
                                        root.updateProp("gradientAngle", newAngle);
                                    }
                                }
                            }
                        }

                        Text {
                            text: root.variantConfig ? root.variantConfig.gradientAngle + "°" : "0°"
                            font.family: Styling.defaultFont
                            font.pixelSize: Styling.fontSize(0)
                            font.bold: true
                            color: Styling.srItem("overprimary")
                            Layout.preferredWidth: 40
                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    // Dot Size Range
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Text {
                            text: Icons.circle
                            font.family: Icons.font
                            font.pixelSize: 18
                            color: Styling.srItem("overprimary")
                            Layout.preferredWidth: 24
                        }

                        Text {
                            text: "Size"
                            font.family: Styling.defaultFont
                            font.pixelSize: Styling.fontSize(0)
                            font.bold: true
                            color: Colors.overBackground
                            Layout.preferredWidth: 60
                        }

                        Text {
                            text: root.variantConfig ? root.variantConfig.halftoneDotMin.toFixed(1) : "2.0"
                            font.family: Styling.defaultFont
                            font.pixelSize: Styling.fontSize(-1)
                            color: Colors.overBackground
                            opacity: 0.7
                        }

                        StyledSlider {
                            id: halftoneDotMinSlider
                            Layout.fillWidth: true
                            Layout.preferredHeight: 20
                            resizeParent: false
                            scroll: false
                            tooltip: false

                            readonly property real configValue: root.variantConfig ? root.variantConfig.halftoneDotMin / 20 : 0.1
                            onConfigValueChanged: if (Math.abs(value - configValue) > 0.001)
                                value = configValue
                            Component.onCompleted: value = configValue

                            onValueChanged: {
                                if (root.variantConfig) {
                                    const newVal = value * 20;
                                    if (Math.abs(newVal - root.variantConfig.halftoneDotMin) > 0.01) {
                                        root.updateProp("halftoneDotMin", newVal);
                                    }
                                }
                            }
                        }

                        Text {
                            text: "-"
                            font.family: Styling.defaultFont
                            font.pixelSize: Styling.fontSize(0)
                            color: Colors.overBackground
                            opacity: 0.5
                        }

                        StyledSlider {
                            id: halftoneDotMaxSlider
                            Layout.fillWidth: true
                            Layout.preferredHeight: 20
                            resizeParent: false
                            scroll: false
                            tooltip: false

                            readonly property real configValue: root.variantConfig ? root.variantConfig.halftoneDotMax / 20 : 0.4
                            onConfigValueChanged: if (Math.abs(value - configValue) > 0.001)
                                value = configValue
                            Component.onCompleted: value = configValue

                            onValueChanged: {
                                if (root.variantConfig) {
                                    const newVal = value * 20;
                                    if (Math.abs(newVal - root.variantConfig.halftoneDotMax) > 0.01) {
                                        root.updateProp("halftoneDotMax", newVal);
                                    }
                                }
                            }
                        }

                        Text {
                            text: root.variantConfig ? root.variantConfig.halftoneDotMax.toFixed(1) : "8.0"
                            font.family: Styling.defaultFont
                            font.pixelSize: Styling.fontSize(-1)
                            color: Colors.overBackground
                            opacity: 0.7
                        }
                    }

                    // Gradient Range
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Text {
                            text: Icons.range
                            font.family: Icons.font
                            font.pixelSize: 18
                            color: Styling.srItem("overprimary")
                            Layout.preferredWidth: 24
                        }

                        Text {
                            text: "Range"
                            font.family: Styling.defaultFont
                            font.pixelSize: Styling.fontSize(0)
                            font.bold: true
                            color: Colors.overBackground
                            Layout.preferredWidth: 60
                        }

                        Text {
                            text: root.variantConfig ? (root.variantConfig.halftoneStart * 100).toFixed(0) + "%" : "0%"
                            font.family: Styling.defaultFont
                            font.pixelSize: Styling.fontSize(-1)
                            color: Colors.overBackground
                            opacity: 0.7
                        }

                        StyledSlider {
                            id: halftoneStartSlider
                            Layout.fillWidth: true
                            Layout.preferredHeight: 20
                            resizeParent: false
                            scroll: false
                            tooltip: false

                            readonly property real configValue: root.variantConfig ? root.variantConfig.halftoneStart : 0
                            onConfigValueChanged: if (Math.abs(value - configValue) > 0.001)
                                value = configValue
                            Component.onCompleted: value = configValue

                            onValueChanged: {
                                if (root.variantConfig && Math.abs(value - root.variantConfig.halftoneStart) > 0.001) {
                                    root.updateProp("halftoneStart", value);
                                }
                            }
                        }

                        Text {
                            text: "-"
                            font.family: Styling.defaultFont
                            font.pixelSize: Styling.fontSize(0)
                            color: Colors.overBackground
                            opacity: 0.5
                        }

                        StyledSlider {
                            id: halftoneEndSlider
                            Layout.fillWidth: true
                            Layout.preferredHeight: 20
                            resizeParent: false
                            scroll: false
                            tooltip: false

                            readonly property real configValue: root.variantConfig ? root.variantConfig.halftoneEnd : 1
                            onConfigValueChanged: if (Math.abs(value - configValue) > 0.001)
                                value = configValue
                            Component.onCompleted: value = configValue

                            onValueChanged: {
                                if (root.variantConfig && Math.abs(value - root.variantConfig.halftoneEnd) > 0.001) {
                                    root.updateProp("halftoneEnd", value);
                                }
                            }
                        }

                        Text {
                            text: root.variantConfig ? (root.variantConfig.halftoneEnd * 100).toFixed(0) + "%" : "100%"
                            font.family: Styling.defaultFont
                            font.pixelSize: Styling.fontSize(-1)
                            color: Colors.overBackground
                            opacity: 0.7
                        }
                    }
                }
            }
        }
    }
}
