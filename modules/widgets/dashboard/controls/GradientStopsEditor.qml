pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import "../../../../config/defaults/theme.js" as ThemeDefaults

Item {
    id: root

    required property var colorNames
    required property var stops
    required property string variantId

    signal updateStops(var newStops)
    signal openColorPickerRequested(var colorNames, string currentColor, string dialogTitle, var callback)

    implicitHeight: contentColumn.implicitHeight

    // Currently selected stop index for editing (default to first stop)
    property int selectedStopIndex: 0

    // Drag state (kept at root level to survive delegate recreation)
    property int draggingIndex: -1
    property real dragPosition: 0

    // Helper to get effective position for a stop (uses drag position if dragging)
    function getStopPosition(index) {
        if (!stops || stops.length === 0)
            return 0;

        // Handle dragging
        if (draggingIndex === index)
            return dragPosition;

        // If index is within bounds, use actual position
        if (index >= 0 && index < stops.length)
            return stops[index][1];

        // If index is out of bounds, map to the last stop's position (clamped)
        return stops[stops.length - 1][1];
    }

    function getStopColor(index) {
        if (!stops || stops.length === 0)
            return "transparent";

        // If index is within bounds, use actual color
        if (index >= 0 && index < stops.length)
            return stops[index][0];

        // If index is out of bounds, map to the last stop's color
        return stops[stops.length - 1][0];
    }

    // Get the default gradient for this variant
    readonly property var defaultGradient: {
        const variantKeyMap = {
            "bg": "srBg",
            "internalbg": "srInternalBg",
            "barbg": "srBarBg",
            "pane": "srPane",
            "common": "srCommon",
            "focus": "srFocus",
            "primary": "srPrimary",
            "primaryfocus": "srPrimaryFocus",
            "overprimary": "srOverPrimary",
            "secondary": "srSecondary",
            "secondaryfocus": "srSecondaryFocus",
            "oversecondary": "srOverSecondary",
            "tertiary": "srTertiary",
            "tertiaryfocus": "srTertiaryFocus",
            "overtertiary": "srOverTertiary",
            "error": "srError",
            "errorfocus": "srErrorFocus",
            "overerror": "srOverError"
        };
        const variantKey = variantKeyMap[variantId] || "srCommon";
        // Guard against undefined ThemeDefaults.data
        if (!ThemeDefaults.data) {
            return [["surface", 0.0]];
        }
        const defaults = ThemeDefaults.data[variantKey];
        if (defaults && defaults.gradient) {
            return defaults.gradient;
        }
        return [["surface", 0.0]];
    }

    ColumnLayout {
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 8

        // Title row: "Gradient Stops (X)" + Separator + "Stop X"
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: I18n.t("Gradient Stops ({0})", "Gradient Stops ({0})", [root.stops.length])
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                font.weight: Font.Medium
                color: Colors.overSurfaceVariant
            }

            Separator {
                Layout.fillWidth: true
            }

            Text {
                text: I18n.t("Stop {0}", "Stop {0}", [root.selectedStopIndex + 1])
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                font.weight: Font.Medium
                color: Styling.srItem("overprimary")
                visible: root.selectedStopIndex >= 0 && root.selectedStopIndex < root.stops.length
            }
        }

        // Gradient bar with Add/Reset buttons on sides
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            spacing: 16

            // Add button
            StyledRect {
                id: addButton
                variant: "primary"
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                Layout.alignment: Qt.AlignVCenter
                radius: Styling.radius(-4)
                opacity: addButton.isEnabled ? (addMouseArea.containsMouse ? 0.8 : 1.0) : 0.5

                property bool isEnabled: true

                Text {
                    anchors.centerIn: parent
                    text: Icons.plus
                    font.family: Icons.font
                    font.pixelSize: 16
                    color: addButton.item
                }

                MouseArea {
                    id: addMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: addButton.isEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                    onClicked: {
                        if (!addButton.isEnabled)
                            return;
                        let newStops = root.stops.slice();
                        const lastColor = newStops[newStops.length - 1][0];
                        newStops.push([lastColor, 1.0]);
                        root.updateStops(newStops);
                        root.selectedStopIndex = newStops.length - 1;
                    }
                }

                StyledToolTip {
                    visible: addMouseArea.containsMouse
                    tooltipText: I18n.t("Add Stop")
                }
            }

            // Gradient container
            Item {
                id: gradientContainer
                Layout.fillWidth: true
                Layout.preferredHeight: 40

                // The gradient bar
                Rectangle {
                    id: gradientBar
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 32
                    radius: Styling.radius(-4)
                    border.color: Colors.outline
                    border.width: 2
                    clip: true

                    Canvas {
                        id: gradientPreviewCanvas
                        anchors.fill: parent
                        anchors.margins: 2 // Keep inside border

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);

                            var stops = root.stops;
                            if (!stops || stops.length === 0)
                                return;

                            var grad = ctx.createLinearGradient(0, 0, width, 0);
                            for (var i = 0; i < stops.length; i++) {
                                var s = stops[i];
                                grad.addColorStop(s[1], Config.resolveColor(s[0]));
                            }

                            ctx.fillStyle = grad;
                            ctx.fillRect(0, 0, width, height);
                        }

                        Connections {
                            target: root
                            function onStopsChanged() {
                                gradientPreviewCanvas.requestPaint();
                            }
                        }
                        Connections {
                            target: Colors
                            function onLoaded() {
                                gradientPreviewCanvas.requestPaint();
                            }
                        }

                        // Repaint when size changes
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
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

                        x: ((isDragging ? root.dragPosition : stopPosition) * gradientBar.width) - (width / 2)
                        y: 0
                        width: 20
                        height: gradientContainer.height

                        // Top connector line
                        Rectangle {
                            width: 2
                            height: 6
                            anchors.top: parent.top
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: stopHandle.isSelected ? Styling.srItem("overprimary") : Colors.outline
                        }

                        // Handle visual (centered)
                        Rectangle {
                            id: handleCircle
                            width: 16
                            height: 16
                            radius: 8
                            anchors.centerIn: parent
                            color: Config.resolveColor(stopHandle.stopColor)
                            border.color: stopHandle.isSelected ? Styling.srItem("overprimary") : Colors.outline
                            border.width: stopHandle.isSelected ? 2 : 1

                            // Inner highlight
                            Rectangle {
                                anchors.centerIn: parent
                                width: 6
                                height: 6
                                radius: 3
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

                        // Bottom connector line
                        Rectangle {
                            width: 2
                            height: 6
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: stopHandle.isSelected ? Styling.srItem("overprimary") : Colors.outline
                        }

                        MouseArea {
                            id: handleMouseArea
                            anchors.fill: parent
                            anchors.margins: -4
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
            StyledRect {
                id: resetButton
                variant: "error"
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                Layout.alignment: Qt.AlignVCenter
                radius: Styling.radius(-4)
                opacity: resetMouseArea.containsMouse ? 0.8 : 1.0

                Text {
                    anchors.centerIn: parent
                    text: Icons.broom
                    font.family: Icons.font
                    font.pixelSize: 16
                    color: resetButton.item
                }

                MouseArea {
                    id: resetMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        root.updateStops(root.defaultGradient.slice());
                        root.selectedStopIndex = 0;
                    }
                }

                StyledToolTip {
                    visible: resetMouseArea.containsMouse
                    tooltipText: I18n.t("Reset Gradient")
                }
            }
        }

        // Selected stop editor - ColorButton + Position/Delete panel
        RowLayout {
            id: stopEditor
            Layout.fillWidth: true
            spacing: 8

            // Current stop info
            readonly property var currentStop: root.selectedStopIndex >= 0 && root.selectedStopIndex < root.stops.length ? root.stops[root.selectedStopIndex] : null

            // Color selector - using ColorButton
            ColorButton {
                Layout.fillWidth: true
                colorNames: root.colorNames
                currentColor: (stopEditor.currentStop && stopEditor.currentStop[0]) ? stopEditor.currentStop[0].toString() : "surface"
                label: "Color"
                dialogTitle: "Select Stop Color"
                onColorSelected: color => {
                    if (root.selectedStopIndex >= 0 && root.selectedStopIndex < root.stops.length) {
                        let newStops = root.stops.slice();
                        newStops[root.selectedStopIndex] = [color, newStops[root.selectedStopIndex][1]];
                        root.updateStops(newStops);
                    }
                }
                onOpenColorPicker: (names, current, title) => {
                    const stopIndex = root.selectedStopIndex;
                    root.openColorPickerRequested(names, current, title, function (color) {
                        if (stopIndex >= 0 && stopIndex < root.stops.length) {
                            let newStops = root.stops.slice();
                            newStops[stopIndex] = [color, newStops[stopIndex][1]];
                            root.updateStops(newStops);
                        }
                    });
                }
            }

            // Position + Delete panel
            StyledRect {
                id: positionPanel
                variant: "pane"
                Layout.preferredWidth: 100
                Layout.preferredHeight: 56
                radius: Styling.radius(-1)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 4

                    // Position label
                    Text {
                        text: I18n.t("Position")
                        font.family: Styling.defaultFont
                        font.pixelSize: Styling.fontSize(-2)
                        font.bold: true
                        color: positionPanel.item
                        opacity: 0.6
                        Layout.alignment: Qt.AlignHCenter
                    }

                    // Input + Delete row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        // Position input
                        StyledRect {
                            id: positionInputContainer
                            variant: "internalbg"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 24
                            radius: Styling.radius(-3)

                            TextInput {
                                id: positionInput
                                anchors.fill: parent
                                anchors.margins: 4

                                readonly property var currentStop: root.selectedStopIndex >= 0 && root.selectedStopIndex < root.stops.length ? root.stops[root.selectedStopIndex] : null
                                readonly property real displayPosition: root.draggingIndex === root.selectedStopIndex ? root.dragPosition : (currentStop ? currentStop[1] : 0)

                                text: currentStop ? displayPosition.toFixed(3) : ""

                                font.family: "monospace"
                                font.pixelSize: Styling.fontSize(-1)
                                color: positionInputContainer.item
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
                        StyledRect {
                            id: deleteStopButton
                            variant: deleteStopButton.isEnabled && deleteMouseArea.containsMouse ? "focus" : "common"
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            radius: Styling.radius(-3)
                            opacity: isEnabled ? 1.0 : 0.3

                            property bool isEnabled: root.stops.length > 1

                            Text {
                                anchors.centerIn: parent
                                text: Icons.trash
                                font.family: Icons.font
                                font.pixelSize: 12
                                color: deleteStopButton.item
                            }

                            MouseArea {
                                id: deleteMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: deleteStopButton.isEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                                onClicked: {
                                    if (!deleteStopButton.isEnabled || root.stops.length <= 1)
                                        return;
                                    let newStops = root.stops.slice();
                                    newStops.splice(root.selectedStopIndex, 1);
                                    root.updateStops(newStops);
                                    root.selectedStopIndex = Math.min(root.selectedStopIndex, root.stops.length - 2);
                                }
                            }

                            StyledToolTip {
                                visible: deleteMouseArea.containsMouse
                                text: I18n.t("Delete stop")
                            }
                        }
                    }
                }
            }
        }
    }
}
