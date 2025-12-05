pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import qs.modules.theme
import qs.modules.components
import qs.config
import "../../../config/ConfigDefaults.js" as ConfigDefaults

GroupBox {
    id: root

    required property var colorNames
    required property var stops
    required property string variantId

    signal updateStops(var newStops)

    // Currently selected stop index for editing (default to first stop)
    property int selectedStopIndex: 0

    // Drag state (kept at root level to survive delegate recreation)
    property int draggingIndex: -1
    property real dragPosition: 0

    // Helper to get effective position for a stop (uses drag position if dragging)
    function getStopPosition(index) {
        if (draggingIndex === index)
            return dragPosition;
        if (index >= 0 && index < stops.length)
            return stops[index][1];
        return 0;
    }

    // Get the default gradient for this variant
    readonly property var defaultGradient: {
        const variantKey = "sr" + variantId.charAt(0).toUpperCase() + variantId.slice(1);
        const defaults = ConfigDefaults.data.theme[variantKey];
        if (defaults && defaults.gradient) {
            return defaults.gradient;
        }
        return [["surface", 0.0]];
    }

    title: "Gradient Stops (" + stops.length + "/20)"

    background: StyledRect {
        variant: "common"
    }

    label: Text {
        text: parent.title
        font.family: Styling.defaultFont
        font.pixelSize: Styling.fontSize(0)
        font.bold: true
        color: Colors.primary
        leftPadding: 10
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 0
        anchors.bottomMargin: 4
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        spacing: 8

        // Gradient bar with Add/Reset buttons on sides
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            Layout.topMargin: 4
            spacing: 4

            // Add button
            Button {
                id: addButton
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                Layout.alignment: Qt.AlignTop
                enabled: root.stops.length < 20

                background: StyledRect {
                    variant: addButton.enabled ? (addButton.hovered ? "primaryfocus" : "primary") : "common"
                    opacity: addButton.enabled ? 1.0 : 0.5
                }

                contentItem: Text {
                    text: Icons.plus
                    font.family: Icons.font
                    font.pixelSize: 16
                    color: addButton.enabled ? Colors.overPrimary : Colors.overBackground
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    if (root.stops.length >= 20)
                        return;
                    let newStops = root.stops.slice();
                    const lastColor = newStops[newStops.length - 1][0];
                    newStops.push([lastColor, 1.0]);
                    root.updateStops(newStops);
                    root.selectedStopIndex = newStops.length - 1;
                }

                ToolTip.visible: hovered
                ToolTip.text: "Add stop"
                ToolTip.delay: 500
            }

            // Gradient container
            Item {
                id: gradientContainer
                Layout.fillWidth: true
                Layout.preferredHeight: 56

                // The gradient bar
                Rectangle {
                    id: gradientBar
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 32
                    radius: Styling.radius(-12)
                    border.color: Colors.outline
                    border.width: 1

                    gradient: Gradient {
                        orientation: Gradient.Horizontal

                        GradientStop {
                            property var stopData: root.stops[0] || ["surface", 0.0]
                            position: root.getStopPosition(0)
                            color: Config.resolveColor(stopData[0])
                        }

                        GradientStop {
                            property var stopData: root.stops[1] || root.stops[root.stops.length - 1]
                            position: root.stops[1] ? root.getStopPosition(1) : root.getStopPosition(root.stops.length - 1)
                            color: Config.resolveColor(stopData[0])
                        }

                        GradientStop {
                            property var stopData: root.stops[2] || root.stops[root.stops.length - 1]
                            position: root.stops[2] ? root.getStopPosition(2) : root.getStopPosition(root.stops.length - 1)
                            color: Config.resolveColor(stopData[0])
                        }

                        GradientStop {
                            property var stopData: root.stops[3] || root.stops[root.stops.length - 1]
                            position: root.stops[3] ? root.getStopPosition(3) : root.getStopPosition(root.stops.length - 1)
                            color: Config.resolveColor(stopData[0])
                        }

                        GradientStop {
                            property var stopData: root.stops[4] || root.stops[root.stops.length - 1]
                            position: root.stops[4] ? root.getStopPosition(4) : root.getStopPosition(root.stops.length - 1)
                            color: Config.resolveColor(stopData[0])
                        }

                        GradientStop {
                            property var stopData: root.stops[5] || root.stops[root.stops.length - 1]
                            position: root.stops[5] ? root.getStopPosition(5) : root.getStopPosition(root.stops.length - 1)
                            color: Config.resolveColor(stopData[0])
                        }

                        GradientStop {
                            property var stopData: root.stops[6] || root.stops[root.stops.length - 1]
                            position: root.stops[6] ? root.getStopPosition(6) : root.getStopPosition(root.stops.length - 1)
                            color: Config.resolveColor(stopData[0])
                        }

                        GradientStop {
                            property var stopData: root.stops[7] || root.stops[root.stops.length - 1]
                            position: root.stops[7] ? root.getStopPosition(7) : root.getStopPosition(root.stops.length - 1)
                            color: Config.resolveColor(stopData[0])
                        }

                        GradientStop {
                            property var stopData: root.stops[8] || root.stops[root.stops.length - 1]
                            position: root.stops[8] ? root.getStopPosition(8) : root.getStopPosition(root.stops.length - 1)
                            color: Config.resolveColor(stopData[0])
                        }

                        GradientStop {
                            property var stopData: root.stops[9] || root.stops[root.stops.length - 1]
                            position: root.stops[9] ? root.getStopPosition(9) : root.getStopPosition(root.stops.length - 1)
                            color: Config.resolveColor(stopData[0])
                        }
                    }
                }

                // Draggable stop handles
                Repeater {
                    model: root.stops

                    delegate: Item {
                        id: stopHandle

                        required property var modelData
                        required property int index

                        readonly property real stopPosition: modelData[1]
                        readonly property string stopColor: modelData[0] ? modelData[0].toString() : ""
                        readonly property bool isSelected: root.selectedStopIndex === index
                        readonly property bool isDragging: root.draggingIndex === index

                        x: ((isDragging ? root.dragPosition : stopPosition) * gradientBar.width) - (handleCircle.width / 2)
                        y: gradientBar.height - 6
                        width: 20
                        height: 26

                        // Handle visual
                        Rectangle {
                            id: handleCircle
                            width: 20
                            height: 20
                            radius: 10
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: Config.resolveColor(stopHandle.stopColor)
                            border.color: stopHandle.isSelected ? Colors.primary : Colors.outline
                            border.width: stopHandle.isSelected ? 3 : 2

                            // Inner highlight
                            Rectangle {
                                anchors.centerIn: parent
                                width: 8
                                height: 8
                                radius: 4
                                color: Qt.lighter(parent.color, 1.4)
                                opacity: 0.6
                            }

                            Behavior on border.width {
                                enabled: (Config.animDuration ?? 0) > 0
                                NumberAnimation {
                                    duration: (Config.animDuration ?? 0) / 3
                                }
                            }
                        }

                        // Connector line to gradient bar
                        Rectangle {
                            width: 2
                            height: 8
                            anchors.bottom: handleCircle.top
                            anchors.horizontalCenter: handleCircle.horizontalCenter
                            color: stopHandle.isSelected ? Colors.primary : Colors.outline
                        }

                        MouseArea {
                            id: handleMouseArea
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            preventStealing: true

                            property bool dragging: false

                            onPressed: mouse => {
                                if (mouse.button === Qt.LeftButton) {
                                    root.selectedStopIndex = stopHandle.index;
                                    dragging = true;
                                    mouse.accepted = true;
                                } else if ((mouse.button === Qt.RightButton || mouse.button === Qt.MiddleButton) && root.stops.length > 1) {
                                    let newStops = root.stops.slice();
                                    newStops.splice(stopHandle.index, 1);
                                    root.updateStops(newStops);
                                    if (root.selectedStopIndex >= newStops.length) {
                                        root.selectedStopIndex = newStops.length - 1;
                                    }
                                    mouse.accepted = true;
                                }
                            }

                            onPositionChanged: mouse => {
                                if (dragging) {
                                    const globalPos = mapToItem(gradientBar, mouse.x, mouse.y);
                                    const newPosition = Math.max(0, Math.min(1, globalPos.x / gradientBar.width));
                                    root.draggingIndex = stopHandle.index;
                                    root.dragPosition = Math.round(newPosition * 1000) / 1000;
                                }
                            }

                            onReleased: {
                                if (dragging) {
                                    dragging = false;
                                    if (root.draggingIndex >= 0) {
                                        let newStops = root.stops.slice();
                                        newStops[root.draggingIndex] = [newStops[root.draggingIndex][0], root.dragPosition];
                                        root.draggingIndex = -1;
                                        root.updateStops(newStops);
                                    }
                                }
                            }
                        }
                    }
                }

                // Double-click on bar to add stop
                MouseArea {
                    anchors.fill: gradientBar
                    z: -1
                    onDoubleClicked: mouse => {
                        if (root.stops.length >= 20)
                            return;
                        const position = Math.round((mouse.x / gradientBar.width) * 1000) / 1000;
                        let nearestColor = root.stops[0][0];
                        let minDist = 1.0;
                        for (let i = 0; i < root.stops.length; i++) {
                            const dist = Math.abs(root.stops[i][1] - position);
                            if (dist < minDist) {
                                minDist = dist;
                                nearestColor = root.stops[i][0];
                            }
                        }
                        let newStops = root.stops.slice();
                        newStops.push([nearestColor, position]);
                        newStops.sort((a, b) => a[1] - b[1]);
                        root.updateStops(newStops);
                    }
                }
            }

            // Reset button
            Button {
                id: resetButton
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                Layout.alignment: Qt.AlignTop

                background: StyledRect {
                    variant: resetButton.hovered ? "errorfocus" : "error"
                }

                contentItem: Text {
                    text: Icons.broom
                    font.family: Icons.font
                    font.pixelSize: 16
                    color: Colors.overError
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    root.updateStops(root.defaultGradient.slice());
                    root.selectedStopIndex = 0;
                }

                ToolTip.visible: hovered
                ToolTip.text: "Reset to default"
                ToolTip.delay: 500
            }
        }

        // Selected stop editor - only visible when a stop is selected
        ColumnLayout {
            id: stopEditor
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8
            visible: root.selectedStopIndex >= 0 && root.selectedStopIndex < root.stops.length

            // Current stop info
            readonly property var currentStop: root.selectedStopIndex >= 0 && root.selectedStopIndex < root.stops.length ? root.stops[root.selectedStopIndex] : null
            readonly property string colorStr: currentStop ? (currentStop[0] ? currentStop[0].toString() : "") : ""
            readonly property bool isHex: colorStr.startsWith("#")
            readonly property string displayHex: {
                if (isHex)
                    return colorStr;
                const color = Colors[colorStr];
                return color ? color.toString() : "#000000";
            }

            // Header row: Stop number, position, delete
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "Stop " + (root.selectedStopIndex + 1)
                    font.family: Styling.defaultFont
                    font.pixelSize: Styling.fontSize(0)
                    font.bold: true
                    color: Colors.primary
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    text: "Position:"
                    font.family: Styling.defaultFont
                    font.pixelSize: Styling.fontSize(0)
                    color: Colors.overBackground
                    opacity: 0.7
                }

                StyledRect {
                    Layout.preferredWidth: 70
                    Layout.preferredHeight: 28
                    variant: positionInput.activeFocus ? "focus" : "common"

                    TextInput {
                        id: positionInput
                        anchors.fill: parent
                        anchors.margins: 6

                        readonly property var currentStop: root.selectedStopIndex >= 0 && root.selectedStopIndex < root.stops.length ? root.stops[root.selectedStopIndex] : null
                        readonly property real displayPosition: root.draggingIndex === root.selectedStopIndex ? root.dragPosition : (currentStop ? currentStop[1] : 0)

                        text: currentStop ? displayPosition.toFixed(3) : ""

                        font.family: "monospace"
                        font.pixelSize: Styling.fontSize(0)
                        color: Colors.overBackground
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        selectByMouse: true

                        onEditingFinished: {
                            if (!currentStop)
                                return;
                            let val = parseFloat(text);
                            if (!isNaN(val)) {
                                val = Math.round(Math.max(0, Math.min(1, val)) * 1000) / 1000;
                                let newStops = root.stops.slice();
                                newStops[root.selectedStopIndex] = [newStops[root.selectedStopIndex][0], val];
                                root.updateStops(newStops);
                            }
                        }

                        Keys.onReturnPressed: editingFinished()
                        Keys.onEnterPressed: editingFinished()
                    }
                }

                // Delete button
                Button {
                    id: deleteStopButton
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    enabled: root.stops.length > 1

                    background: StyledRect {
                        variant: deleteStopButton.enabled ? (deleteStopButton.hovered ? "error" : "common") : "common"
                        opacity: deleteStopButton.enabled ? 1.0 : 0.3
                    }

                    contentItem: Text {
                        text: Icons.trash
                        font.family: Icons.font
                        font.pixelSize: 16
                        color: deleteStopButton.enabled ? (deleteStopButton.hovered ? Colors.overError : Colors.overBackground) : Colors.overBackground
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        if (root.stops.length <= 1)
                            return;
                        let newStops = root.stops.slice();
                        newStops.splice(root.selectedStopIndex, 1);
                        root.updateStops(newStops);
                        root.selectedStopIndex = Math.min(root.selectedStopIndex, root.stops.length - 2);
                    }

                    ToolTip.visible: hovered
                    ToolTip.text: "Delete stop"
                    ToolTip.delay: 500
                }
            }

            // Color selector row
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // Color preview
                Rectangle {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: Styling.radius(-12)
                    border.color: Colors.outline
                    border.width: 1
                    color: stopEditor.currentStop ? Config.resolveColor(stopEditor.currentStop[0]) : "transparent"
                }

                // Color dropdown
                ComboBox {
                    id: stopColorCombo
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32

                    model: ["Custom"].concat(root.colorNames)
                    currentIndex: {
                        if (stopEditor.isHex)
                            return 0;
                        const idx = root.colorNames.indexOf(stopEditor.colorStr);
                        return idx >= 0 ? idx + 1 : 0;
                    }

                    onActivated: idx => {
                        if (idx === 0) {
                            // Switch to custom/hex mode - use current resolved color
                            let newStops = root.stops.slice();
                            newStops[root.selectedStopIndex] = [stopEditor.displayHex, newStops[root.selectedStopIndex][1]];
                            root.updateStops(newStops);
                            return;
                        }
                        let newStops = root.stops.slice();
                        newStops[root.selectedStopIndex] = [root.colorNames[idx - 1], newStops[root.selectedStopIndex][1]];
                        root.updateStops(newStops);
                    }

                    background: StyledRect {
                        variant: stopColorCombo.hovered ? "focus" : "common"
                    }

                    contentItem: Text {
                        text: stopEditor.isHex ? "Custom" : stopEditor.colorStr
                        font.family: Styling.defaultFont
                        font.pixelSize: Styling.fontSize(0)
                        color: Colors.overBackground
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 8
                    }

                    indicator: Text {
                        x: stopColorCombo.width - width - 6
                        anchors.verticalCenter: parent.verticalCenter
                        text: Icons.caretDown
                        font.family: Icons.font
                        font.pixelSize: Styling.fontSize(0)
                        color: Colors.overBackground
                    }

                    popup: Popup {
                        y: stopColorCombo.height + 2
                        width: stopColorCombo.width
                        implicitHeight: contentItem.implicitHeight > 200 ? 200 : contentItem.implicitHeight
                        padding: 2

                        background: StyledRect {
                            variant: "pane"
                            enableShadow: true
                        }

                        contentItem: ListView {
                            clip: true
                            implicitHeight: contentHeight
                            model: stopColorCombo.popup.visible ? stopColorCombo.delegateModel : null
                            currentIndex: stopColorCombo.highlightedIndex
                            ScrollIndicator.vertical: ScrollIndicator {}
                        }
                    }

                    delegate: ItemDelegate {
                        id: colorDelegate
                        required property var modelData
                        required property int index

                        width: stopColorCombo.width - 4
                        height: 28

                        background: StyledRect {
                            variant: colorDelegate.highlighted ? "focus" : "common"
                        }

                        contentItem: RowLayout {
                            spacing: 6

                            Rectangle {
                                Layout.preferredWidth: 18
                                Layout.preferredHeight: 18
                                radius: 2
                                color: colorDelegate.index === 0 ? "transparent" : (Colors[root.colorNames[colorDelegate.index - 1]] || "transparent")
                                border.color: Colors.outline
                                border.width: colorDelegate.index === 0 ? 0 : 1

                                // Diagonal line for "Custom"
                                Rectangle {
                                    visible: colorDelegate.index === 0
                                    width: parent.width * 1.2
                                    height: 2
                                    color: Colors.error
                                    anchors.centerIn: parent
                                    rotation: 45
                                }
                            }

                            Text {
                                text: colorDelegate.modelData
                                font.family: Styling.defaultFont
                                font.pixelSize: Styling.fontSize(0)
                                color: Colors.overBackground
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        highlighted: stopColorCombo.highlightedIndex === index
                    }
                }

                // Color picker button
                Button {
                    id: pickerButton
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32

                    background: StyledRect {
                        variant: pickerButton.hovered ? "focus" : "common"
                    }

                    contentItem: Text {
                        text: Icons.picker
                        font.family: Icons.font
                        font.pixelSize: 16
                        color: Colors.overBackground
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: colorDialog.open()

                    ToolTip.visible: hovered
                    ToolTip.text: "Color picker"
                    ToolTip.delay: 500
                }
            }

            // HEX input row - only enabled when Custom is selected
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                opacity: stopEditor.isHex ? 1.0 : 0.5

                Text {
                    text: "HEX:"
                    font.family: Styling.defaultFont
                    font.pixelSize: Styling.fontSize(0)
                    color: Colors.overBackground
                    opacity: 0.7
                }

                StyledRect {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    variant: hexInput.activeFocus ? "focus" : "common"

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 2

                        Text {
                            text: "#"
                            font.family: "monospace"
                            font.pixelSize: Styling.fontSize(0)
                            color: Colors.overBackground
                            opacity: 0.6
                        }

                        TextInput {
                            id: hexInput
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            text: stopEditor.displayHex.replace("#", "").toUpperCase()

                            font.family: "monospace"
                            font.pixelSize: Styling.fontSize(0)
                            color: Colors.overBackground
                            verticalAlignment: Text.AlignVCenter
                            selectByMouse: true
                            maximumLength: 8
                            readOnly: !stopEditor.isHex

                            validator: RegularExpressionValidator {
                                regularExpression: /[0-9A-Fa-f]{0,8}/
                            }

                            onEditingFinished: {
                                if (!stopEditor.isHex)
                                    return;
                                let hex = text.trim();
                                if (hex.length >= 6) {
                                    let newStops = root.stops.slice();
                                    newStops[root.selectedStopIndex] = ["#" + hex.toUpperCase(), newStops[root.selectedStopIndex][1]];
                                    root.updateStops(newStops);
                                }
                            }

                            Keys.onReturnPressed: editingFinished()
                            Keys.onEnterPressed: editingFinished()
                        }
                    }
                }
            }

            Item {
                Layout.fillHeight: true
            }
        }

        // Placeholder when no stop selected
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.selectedStopIndex < 0 || root.selectedStopIndex >= root.stops.length

            Item {
                Layout.fillHeight: true
            }

            Text {
                text: Icons.mousePointer
                font.family: Icons.font
                font.pixelSize: 32
                color: Colors.overBackground
                opacity: 0.4
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: "Click a stop to edit"
                font.family: Styling.defaultFont
                font.pixelSize: Styling.fontSize(0)
                color: Colors.overBackground
                opacity: 0.5
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: "Double-click bar to add\nRight/middle-click stop to delete"
                font.family: Styling.defaultFont
                font.pixelSize: Styling.fontSize(-2)
                color: Colors.overBackground
                opacity: 0.4
                horizontalAlignment: Text.AlignHCenter
                Layout.alignment: Qt.AlignHCenter
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }

    ColorDialog {
        id: colorDialog
        title: "Select Color"
        selectedColor: {
            const stop = root.selectedStopIndex >= 0 && root.selectedStopIndex < root.stops.length ? root.stops[root.selectedStopIndex] : null;
            return stop ? Config.resolveColor(stop[0]) : "#000000";
        }

        onAccepted: {
            if (root.selectedStopIndex >= 0 && root.selectedStopIndex < root.stops.length) {
                let newStops = root.stops.slice();
                newStops[root.selectedStopIndex] = [selectedColor.toString().toUpperCase(), newStops[root.selectedStopIndex][1]];
                root.updateStops(newStops);
            }
        }
    }
}
