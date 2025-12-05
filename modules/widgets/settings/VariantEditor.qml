pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.components
import qs.config

StyledRect {
    id: root

    required property string variantId

    signal updateVariant(string property, var value)
    signal close

    variant: "pane"

    // Get the Config object for this variant (reads directly from Config)
    readonly property var variantConfig: {
        switch (variantId) {
        case "bg":
            return Config.theme.srBg;
        case "internalbg":
            return Config.theme.srInternalBg;
        case "pane":
            return Config.theme.srPane;
        case "common":
            return Config.theme.srCommon;
        case "focus":
            return Config.theme.srFocus;
        case "primary":
            return Config.theme.srPrimary;
        case "primaryfocus":
            return Config.theme.srPrimaryFocus;
        case "overprimary":
            return Config.theme.srOverPrimary;
        case "secondary":
            return Config.theme.srSecondary;
        case "secondaryfocus":
            return Config.theme.srSecondaryFocus;
        case "oversecondary":
            return Config.theme.srOverSecondary;
        case "tertiary":
            return Config.theme.srTertiary;
        case "tertiaryfocus":
            return Config.theme.srTertiaryFocus;
        case "overtertiary":
            return Config.theme.srOverTertiary;
        case "error":
            return Config.theme.srError;
        case "errorfocus":
            return Config.theme.srErrorFocus;
        case "overerror":
            return Config.theme.srOverError;
        default:
            return null;
        }
    }

    readonly property string variantDisplayName: {
        switch (variantId) {
        case "bg":
            return "Background";
        case "internalbg":
            return "Internal Background";
        case "pane":
            return "Pane";
        case "common":
            return "Common";
        case "focus":
            return "Focus";
        case "primary":
            return "Primary";
        case "primaryfocus":
            return "Primary Focus";
        case "overprimary":
            return "Over Primary";
        case "secondary":
            return "Secondary";
        case "secondaryfocus":
            return "Secondary Focus";
        case "oversecondary":
            return "Over Secondary";
        case "tertiary":
            return "Tertiary";
        case "tertiaryfocus":
            return "Tertiary Focus";
        case "overtertiary":
            return "Over Tertiary";
        case "error":
            return "Error";
        case "errorfocus":
            return "Error Focus";
        case "overerror":
            return "Over Error";
        default:
            return "Unknown";
        }
    }

    // List of available color names from Colors.qml
    readonly property var colorNames: ["background", "surface", "surfaceBright", "surfaceContainer", "surfaceContainerHigh", "surfaceContainerHighest", "surfaceContainerLow", "surfaceContainerLowest", "surfaceDim", "surfaceTint", "surfaceVariant", "primary", "primaryContainer", "primaryFixed", "primaryFixedDim", "secondary", "secondaryContainer", "secondaryFixed", "secondaryFixedDim", "tertiary", "tertiaryContainer", "tertiaryFixed", "tertiaryFixedDim", "error", "errorContainer", "overBackground", "overSurface", "overSurfaceVariant", "overPrimary", "overPrimaryContainer", "overPrimaryFixed", "overPrimaryFixedVariant", "overSecondary", "overSecondaryContainer", "overSecondaryFixed", "overSecondaryFixedVariant", "overTertiary", "overTertiaryContainer", "overTertiaryFixed", "overTertiaryFixedVariant", "overError", "overErrorContainer", "outline", "outlineVariant", "inversePrimary", "inverseSurface", "inverseOnSurface", "shadow", "scrim", "blue", "blueContainer", "overBlue", "overBlueContainer", "cyan", "cyanContainer", "overCyan", "overCyanContainer", "green", "greenContainer", "overGreen", "overGreenContainer", "magenta", "magentaContainer", "overMagenta", "overMagentaContainer", "red", "redContainer", "overRed", "overRedContainer", "yellow", "yellowContainer", "overYellow", "overYellowContainer", "white", "whiteContainer", "overWhite", "overWhiteContainer"]

    // Gradient type options
    readonly property var gradientTypes: ["linear", "radial", "halftone"]

    // Helper to update a property - updates Config directly
    function updateProp(prop, value) {
        if (variantConfig) {
            variantConfig[prop] = value;
            root.updateVariant(prop, value);
        }
    }

    ScrollView {
        anchors.fill: parent
        anchors.margins: 12
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: parent.width
            spacing: 16
            enabled: root.variantConfig !== null

            // === GRADIENT TYPE SELECTOR (PowerProfile style) ===
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "Gradient Type"
                    font.family: Styling.defaultFont
                    font.pixelSize: Styling.fontSize(0)
                    font.bold: true
                    color: Colors.primary
                }

                StyledRect {
                    id: typeSelector
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    variant: "bg"

                    readonly property int buttonCount: 3
                    readonly property int spacing: 2
                    readonly property int padding: 2

                    readonly property int currentIndex: {
                        if (!root.variantConfig)
                            return 0;
                        const idx = root.gradientTypes.indexOf(root.variantConfig.gradientType);
                        return idx >= 0 ? idx : 0;
                    }

                    Item {
                        anchors.fill: parent
                        anchors.margins: typeSelector.padding

                        // Sliding highlight
                        StyledRect {
                            id: typeHighlight
                            variant: "primary"
                            z: 0
                            radius: Styling.radius(-2)

                            readonly property real buttonWidth: (parent.width - (typeSelector.buttonCount - 1) * typeSelector.spacing) / typeSelector.buttonCount

                            width: buttonWidth
                            height: parent.height
                            x: typeSelector.currentIndex * (buttonWidth + typeSelector.spacing)

                            Behavior on x {
                                enabled: Config.animDuration > 0
                                NumberAnimation {
                                    duration: Config.animDuration / 2
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        // Buttons
                        RowLayout {
                            anchors.fill: parent
                            spacing: typeSelector.spacing
                            z: 1

                            Repeater {
                                model: root.gradientTypes

                                Rectangle {
                                    id: typeButton
                                    required property string modelData
                                    required property int index

                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    color: "transparent"

                                    readonly property bool isSelected: typeSelector.currentIndex === index

                                    Text {
                                        anchors.centerIn: parent
                                        text: typeButton.modelData.charAt(0).toUpperCase() + typeButton.modelData.slice(1)
                                        font.family: Styling.defaultFont
                                        font.pixelSize: Styling.fontSize(0)
                                        color: typeButton.isSelected ? Colors.overPrimary : Colors.overBackground
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter

                                        Behavior on color {
                                            enabled: Config.animDuration > 0
                                            ColorAnimation {
                                                duration: Config.animDuration / 2
                                                easing.type: Easing.OutQuart
                                            }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.updateProp("gradientType", typeButton.modelData)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // === ITEM COLOR ===
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: "Item Color"
                    font.family: Styling.defaultFont
                    font.pixelSize: Styling.fontSize(0)
                    font.bold: true
                    color: Colors.primary
                }

                ColorSelector {
                    Layout.fillWidth: true
                    colorNames: root.colorNames
                    currentValue: root.variantConfig ? root.variantConfig.itemColor : ""
                    onColorChanged: newColor => root.updateProp("itemColor", newColor)
                }
            }

            // === OPACITY ===
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: "Opacity"
                    font.family: Styling.defaultFont
                    font.pixelSize: Styling.fontSize(0)
                    font.bold: true
                    color: Colors.primary
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    StyledSlider {
                        id: opacitySlider
                        Layout.fillWidth: true
                        Layout.preferredHeight: 24
                        value: root.variantConfig ? root.variantConfig.opacity : 1.0
                        vertical: false
                        resizeParent: false
                        scroll: false
                        tooltip: true
                        tooltipText: root.variantConfig ? (root.variantConfig.opacity * 100).toFixed(0) + "%" : "100%"
                        onValueChanged: {
                            if (root.variantConfig && Math.abs(value - root.variantConfig.opacity) > 0.001) {
                                root.updateProp("opacity", value);
                            }
                        }
                    }

                    Text {
                        text: root.variantConfig ? (root.variantConfig.opacity * 100).toFixed(0) + "%" : "100%"
                        font.family: Styling.defaultFont
                        font.pixelSize: Styling.fontSize(0)
                        color: Colors.overBackground
                        Layout.preferredWidth: 40
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }

            // === BORDER SECTION ===
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "Border"
                    font.family: Styling.defaultFont
                    font.pixelSize: Styling.fontSize(0)
                    font.bold: true
                    color: Colors.primary
                }

                // Border color
                ColorSelector {
                    Layout.fillWidth: true
                    colorNames: root.colorNames
                    currentValue: root.variantConfig ? root.variantConfig.border[0] : ""
                    onColorChanged: newColor => {
                        if (!root.variantConfig)
                            return;
                        let border = [newColor, root.variantConfig.border[1]];
                        root.updateProp("border", border);
                    }
                }

                // Border width
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Width:"
                        font.family: Styling.defaultFont
                        font.pixelSize: Styling.fontSize(0)
                        color: Colors.overBackground
                        opacity: 0.7
                    }

                    StyledSlider {
                        id: borderWidthSlider
                        Layout.fillWidth: true
                        Layout.preferredHeight: 24
                        value: root.variantConfig ? root.variantConfig.border[1] / 16 : 0
                        resizeParent: false
                        scroll: false
                        tooltip: true
                        tooltipText: Math.round(value * 16) + "px"
                        onValueChanged: {
                            if (root.variantConfig) {
                                const newWidth = Math.round(value * 16);
                                if (newWidth !== root.variantConfig.border[1]) {
                                    root.updateProp("border", [root.variantConfig.border[0], newWidth]);
                                }
                            }
                        }
                    }

                    Text {
                        text: root.variantConfig ? root.variantConfig.border[1] + "px" : "0px"
                        font.family: Styling.defaultFont
                        font.pixelSize: Styling.fontSize(0)
                        color: Colors.overBackground
                        Layout.preferredWidth: 35
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }

            // === GRADIENT STOPS (for linear/radial) ===
            GradientStopsEditor {
                Layout.fillWidth: true
                Layout.preferredHeight: 220
                colorNames: root.colorNames
                stops: root.variantConfig ? root.variantConfig.gradient : []
                variantId: root.variantId
                visible: root.variantConfig && root.variantConfig.gradientType !== "halftone"
                onUpdateStops: newStops => root.updateProp("gradient", newStops)
            }

            // === TYPE-SPECIFIC SETTINGS ===
            // Linear settings
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                visible: root.variantConfig && root.variantConfig.gradientType === "linear"

                Text {
                    text: "Angle"
                    font.family: Styling.defaultFont
                    font.pixelSize: Styling.fontSize(0)
                    font.bold: true
                    color: Colors.primary
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    StyledSlider {
                        id: angleSlider
                        Layout.fillWidth: true
                        Layout.preferredHeight: 24
                        value: root.variantConfig ? root.variantConfig.gradientAngle / 360 : 0
                        resizeParent: false
                        scroll: false
                        tooltip: true
                        tooltipText: Math.round(value * 360) + "°"
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
                        color: Colors.overBackground
                        Layout.preferredWidth: 40
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }

            // Radial settings
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                visible: root.variantConfig && root.variantConfig.gradientType === "radial"

                Text {
                    text: "Center Position"
                    font.family: Styling.defaultFont
                    font.pixelSize: Styling.fontSize(0)
                    font.bold: true
                    color: Colors.primary
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "X:"
                            font.family: Styling.defaultFont
                            font.pixelSize: Styling.fontSize(0)
                            color: Colors.overBackground
                            opacity: 0.7
                        }

                        StyledSlider {
                            id: centerXSlider
                            Layout.fillWidth: true
                            Layout.preferredHeight: 24
                            value: root.variantConfig ? root.variantConfig.gradientCenterX : 0.5
                            resizeParent: false
                            scroll: false
                            tooltip: true
                            tooltipText: (value * 100).toFixed(0) + "%"
                            onValueChanged: {
                                if (root.variantConfig && Math.abs(value - root.variantConfig.gradientCenterX) > 0.001) {
                                    root.updateProp("gradientCenterX", value);
                                }
                            }
                        }

                        Text {
                            text: root.variantConfig ? root.variantConfig.gradientCenterX.toFixed(2) : "0.50"
                            font.family: Styling.defaultFont
                            font.pixelSize: Styling.fontSize(0)
                            color: Colors.overBackground
                            Layout.preferredWidth: 35
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "Y:"
                            font.family: Styling.defaultFont
                            font.pixelSize: Styling.fontSize(0)
                            color: Colors.overBackground
                            opacity: 0.7
                        }

                        StyledSlider {
                            id: centerYSlider
                            Layout.fillWidth: true
                            Layout.preferredHeight: 24
                            value: root.variantConfig ? root.variantConfig.gradientCenterY : 0.5
                            resizeParent: false
                            scroll: false
                            tooltip: true
                            tooltipText: (value * 100).toFixed(0) + "%"
                            onValueChanged: {
                                if (root.variantConfig && Math.abs(value - root.variantConfig.gradientCenterY) > 0.001) {
                                    root.updateProp("gradientCenterY", value);
                                }
                            }
                        }

                        Text {
                            text: root.variantConfig ? root.variantConfig.gradientCenterY.toFixed(2) : "0.50"
                            font.family: Styling.defaultFont
                            font.pixelSize: Styling.fontSize(0)
                            color: Colors.overBackground
                            Layout.preferredWidth: 35
                        }
                    }
                }
            }

            // Halftone settings
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: root.variantConfig && root.variantConfig.gradientType === "halftone"

                // Colors row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: "Dot Color"
                            font.family: Styling.defaultFont
                            font.pixelSize: Styling.fontSize(0)
                            font.bold: true
                            color: Colors.primary
                        }

                        ColorSelector {
                            Layout.fillWidth: true
                            colorNames: root.colorNames
                            currentValue: root.variantConfig ? root.variantConfig.halftoneDotColor : ""
                            onColorChanged: newColor => root.updateProp("halftoneDotColor", newColor)
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: "Background"
                            font.family: Styling.defaultFont
                            font.pixelSize: Styling.fontSize(0)
                            font.bold: true
                            color: Colors.primary
                        }

                        ColorSelector {
                            Layout.fillWidth: true
                            colorNames: root.colorNames
                            currentValue: root.variantConfig ? root.variantConfig.halftoneBackgroundColor : ""
                            onColorChanged: newColor => root.updateProp("halftoneBackgroundColor", newColor)
                        }
                    }
                }

                // Angle row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Angle:"
                        font.family: Styling.defaultFont
                        font.pixelSize: Styling.fontSize(0)
                        color: Colors.overBackground
                        opacity: 0.7
                        Layout.preferredWidth: 50
                    }

                    StyledSlider {
                        id: halftoneAngleSlider
                        Layout.fillWidth: true
                        Layout.preferredHeight: 24
                        value: root.variantConfig ? root.variantConfig.gradientAngle / 360 : 0
                        resizeParent: false
                        scroll: false
                        tooltip: true
                        tooltipText: Math.round(value * 360) + "°"
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
                        color: Colors.overBackground
                        Layout.preferredWidth: 40
                        horizontalAlignment: Text.AlignRight
                    }
                }

                // Dot size row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "Dot Min:"
                            font.family: Styling.defaultFont
                            font.pixelSize: Styling.fontSize(0)
                            color: Colors.overBackground
                            opacity: 0.7
                        }

                        StyledSlider {
                            id: dotMinSlider
                            Layout.fillWidth: true
                            Layout.preferredHeight: 24
                            value: root.variantConfig ? root.variantConfig.halftoneDotMin / 20 : 0.1
                            resizeParent: false
                            scroll: false
                            tooltip: true
                            tooltipText: (value * 20).toFixed(1)
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
                            text: root.variantConfig ? root.variantConfig.halftoneDotMin.toFixed(1) : "2.0"
                            font.family: Styling.defaultFont
                            font.pixelSize: Styling.fontSize(0)
                            color: Colors.overBackground
                            Layout.preferredWidth: 30
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "Dot Max:"
                            font.family: Styling.defaultFont
                            font.pixelSize: Styling.fontSize(0)
                            color: Colors.overBackground
                            opacity: 0.7
                        }

                        StyledSlider {
                            id: dotMaxSlider
                            Layout.fillWidth: true
                            Layout.preferredHeight: 24
                            value: root.variantConfig ? root.variantConfig.halftoneDotMax / 20 : 0.4
                            resizeParent: false
                            scroll: false
                            tooltip: true
                            tooltipText: (value * 20).toFixed(1)
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
                            font.pixelSize: Styling.fontSize(0)
                            color: Colors.overBackground
                            Layout.preferredWidth: 30
                        }
                    }
                }

                // Start/End row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "Start:"
                            font.family: Styling.defaultFont
                            font.pixelSize: Styling.fontSize(0)
                            color: Colors.overBackground
                            opacity: 0.7
                        }

                        StyledSlider {
                            id: halftoneStartSlider
                            Layout.fillWidth: true
                            Layout.preferredHeight: 24
                            value: root.variantConfig ? root.variantConfig.halftoneStart : 0
                            resizeParent: false
                            scroll: false
                            tooltip: true
                            tooltipText: (value * 100).toFixed(0) + "%"
                            onValueChanged: {
                                if (root.variantConfig && Math.abs(value - root.variantConfig.halftoneStart) > 0.001) {
                                    root.updateProp("halftoneStart", value);
                                }
                            }
                        }

                        Text {
                            text: root.variantConfig ? root.variantConfig.halftoneStart.toFixed(2) : "0.00"
                            font.family: Styling.defaultFont
                            font.pixelSize: Styling.fontSize(0)
                            color: Colors.overBackground
                            Layout.preferredWidth: 35
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "End:"
                            font.family: Styling.defaultFont
                            font.pixelSize: Styling.fontSize(0)
                            color: Colors.overBackground
                            opacity: 0.7
                        }

                        StyledSlider {
                            id: halftoneEndSlider
                            Layout.fillWidth: true
                            Layout.preferredHeight: 24
                            value: root.variantConfig ? root.variantConfig.halftoneEnd : 1
                            resizeParent: false
                            scroll: false
                            tooltip: true
                            tooltipText: (value * 100).toFixed(0) + "%"
                            onValueChanged: {
                                if (root.variantConfig && Math.abs(value - root.variantConfig.halftoneEnd) > 0.001) {
                                    root.updateProp("halftoneEnd", value);
                                }
                            }
                        }

                        Text {
                            text: root.variantConfig ? root.variantConfig.halftoneEnd.toFixed(2) : "1.00"
                            font.family: Styling.defaultFont
                            font.pixelSize: Styling.fontSize(0)
                            color: Colors.overBackground
                            Layout.preferredWidth: 35
                        }
                    }
                }
            }

            // Spacer
            Item {
                Layout.fillHeight: true
                Layout.preferredHeight: 20
            }
        }
    }
}
