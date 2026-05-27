pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.modules.theme
import qs.modules.components
import qs.config

StyledRect {
    id: root
    variant: "pane"
    Layout.fillWidth: true
    Layout.preferredHeight: cardLayout.implicitHeight + 28
    radius: Styling.radius(0)
    enableShadow: true

    property var monitor: null
    signal settingChanged(string key, var value)

    property var availableModes: []
    property int currentModeIndex: 0
    property bool disabled: !monitor

    onMonitorChanged: {
        if (!monitor) {
            availableModes = [];
            currentModeIndex = 0;
            return;
        }

        var modes = monitor.modes || [];
        if (modes.length === 0) {
            modes = [monitor.width + "x" + monitor.height + "@" + monitor.refreshRate.toFixed(2) + "Hz"];
        }
        availableModes = modes;
        
        currentModeIndex = 0;
        for (var j = 0; j < modes.length; j++) {
            var ms = (modes[j]+"").replace(/Hz/gi,"").trim();
            if (ms.indexOf(monitor.width+"x"+monitor.height) === 0 && ms.indexOf(Math.round(monitor.refreshRate).toString()) !== -1) {
                currentModeIndex = j; break;
            }
        }
    }

    // ─── Shared ComboBox style components ───
    component NLCombo: ComboBox {
        id: nlCombo
        Layout.preferredWidth: 180
        Layout.preferredHeight: 28
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-1)

        background: Rectangle {
            color: nlCombo.hovered ? Colors.surfaceContainerHigh : Colors.surfaceContainer
            radius: 4
            border.color: Colors.surfaceBright
            border.width: 1
        }

        contentItem: Text {
            leftPadding: 8
            rightPadding: 8
            text: nlCombo.displayText
            color: Colors.overBackground
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        indicator: Text {
            x: nlCombo.width - width - 8
            y: (nlCombo.height - height) / 2
            text: "▼"
            font.family: Icons.font
            font.pixelSize: 9
            color: Colors.overSurfaceVariant
        }

        popup: Popup {
            y: nlCombo.height + 2
            width: nlCombo.width
            implicitHeight: Math.min(contentItem.implicitHeight + 12, 350)
            padding: 4

            background: Rectangle {
                color: Colors.surfaceContainer
                radius: 6
                border.color: Colors.surfaceBright
                border.width: 1
            }

            contentItem: ListView {
                clip: true
                implicitHeight: contentHeight
                model: nlCombo.delegateModel
                currentIndex: nlCombo.currentIndex
                interactive: contentHeight > 300
                spacing: 2
            }

            onVisibleChanged: {
                if (visible) {
                    // Ensure popup is within screen bounds
                    const maxY = parent.screen ? parent.screen.height : 1080;
                    if (y + implicitHeight > maxY - 40) {
                        y = nlCombo.height + 2;
                    }
                }
            }
        }

        delegate: ItemDelegate {
            required property var modelData
            width: nlCombo.width - 8
            height: 28
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            leftPadding: 10

            contentItem: Text {
                text: modelData && modelData.text !== undefined ? modelData.text : (typeof modelData === "string" ? modelData : "")
                font: parent.font
                color: parent.highlighted ? Qt.rgba(1, 1, 1, 1) : Colors.overBackground
                opacity: parent.highlighted ? 1.0 : 0.85
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }

            background: Rectangle {
                color: {
                    if (parent.highlighted) return Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.35);
                    if (parent.hovered) return Qt.rgba(Colors.overBackground.r, Colors.overBackground.g, Colors.overBackground.b, 0.08);
                    return "transparent";
                }
                radius: 3
            }
        }
    }

    component NLToggle: RowLayout {
        property string label: ""
        property bool checked: false
        signal toggled(bool value)
        spacing: 8
        Layout.fillWidth: true

        Text {
            text: label
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            color: Colors.overBackground
            Layout.fillWidth: true
        }

        Switch {
            id: toggleSwitch
            checked: parent.checked
            onClicked: parent.toggled(checked)

            indicator: Rectangle {
                implicitWidth: 36
                implicitHeight: 20
                radius: 10
                color: toggleSwitch.checked ? Colors.primary : Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.3)
                border.color: toggleSwitch.checked ? Colors.primary : Colors.outline
                border.width: 1

                Rectangle {
                    x: toggleSwitch.checked ? parent.width - width - 3 : 3
                    y: (parent.height - height) / 2
                    width: 14
                    height: 14
                    radius: 7
                    color: toggleSwitch.checked ? "#ffffff" : Colors.outline

                    Behavior on x {
                        enabled: Anim.animationsEnabled
                        NumberAnimation { duration: Anim.standardSmall; easing.type: Anim.easing("standard").type; easing.bezierCurve: Anim.easing("standard").bezierCurve }
                    }
                }

                Behavior on color {
                    enabled: Anim.animationsEnabled
                    ColorAnimation { duration: Anim.standardSmall }
                }
            }
        }
    }

    ColumnLayout {
        id: cardLayout
        anchors.fill: parent; anchors.margins: 14; spacing: 14

        // ── Header row ──
        RowLayout {
            Layout.fillWidth: true; spacing: 10

            // Status dot
            Rectangle {
                width: 10; height: 10; radius: 5
                color: (root.monitor && root.monitor.focused) ? Colors.primary : Colors.outline
                Layout.alignment: Qt.AlignVCenter
            }

            // Monitor info
            ColumnLayout {
                Layout.fillWidth: true; spacing: 1
                Text {
                    text: root.monitor ? root.monitor.name : "Select a monitor"
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(1)
                    font.weight: Font.DemiBold
                    color: Colors.overBackground
                }
                Text {
                    text: root.monitor ? [root.monitor.make, root.monitor.model, root.monitor.description].filter(function(s){return s}).join(" · ") : ""
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-2)
                    color: Colors.overSurfaceVariant
                    elide: Text.ElideRight
                }
            }

            // Enabled toggle
            NLToggle {
                label: ""
                checked: root.monitor ? root.monitor.enabled : false
                onToggled: root.settingChanged("enabled", value)
            }
        }

        // ── Settings grid ──
        ColumnLayout {
            Layout.fillWidth: true; spacing: 10
            opacity: root.disabled ? 0.5 : 1.0
            enabled: !root.disabled

            // Resolution
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: 10
                columnSpacing: 8

                Text {
                    text: Icons.layout; font.family: Icons.font; font.pixelSize: 14
                    color: Colors.outline; Layout.alignment: Qt.AlignVCenter
                }
                RowLayout { Layout.fillWidth: true; spacing: 8
                    Text { text: "Resolution"; font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-1); color: Colors.overBackground; Layout.preferredWidth: 80 }
                    NLCombo {
                        id: modeCombo
                        Layout.fillWidth: true
                        model: root.availableModes.length > 0 ? root.availableModes.map(function(m){return (m+"").replace("Hz"," Hz")}) : []
                        currentIndex: root.currentModeIndex
                        onActivated: {
                            if (root.availableModes.length > 0 && index < root.availableModes.length) {
                                var val = root.availableModes[index];
                                var clean = (val + "").replace(/Hz/gi, "").trim();
                                var parts = clean.split("@"), wh = parts[0].split("x");
                                root.settingChanged("width", parseInt(wh[0]));
                                root.settingChanged("height", parseInt(wh[1]));
                                root.settingChanged("refreshRate", parseFloat(parts[1]));
                            }
                        }
                    }
                }

                // Scale
                Text { text: Icons.arrowsOut; font.family: Icons.font; font.pixelSize: 14; color: Colors.outline }
                RowLayout { Layout.fillWidth: true; spacing: 8
                    Text { text: "Scale"; font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-1); color: Colors.overBackground; Layout.preferredWidth: 80 }
                    TextField {
                        id: scaleInput
                        text: root.monitor ? root.monitor.scale.toFixed(2) : "1.00"
                        font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-1)
                        color: Colors.overBackground
                        Layout.preferredWidth: 80; horizontalAlignment: Text.AlignRight
                        validator: DoubleValidator { bottom: 0.25; top: 10.0; decimals: 2 }
                        background: Rectangle {
                            color: scaleInput.hovered ? Colors.surfaceContainerHigh : Colors.surfaceContainer
                            radius: 4; border.color: Colors.surfaceBright; border.width: 1
                        }
                        onEditingFinished: {
                            var v = parseFloat(text);
                            if (!isNaN(v) && v>=0.25 && v<=10.0) root.settingChanged("scale", v);
                            else text = root.monitor ? root.monitor.scale.toFixed(2) : "1.00";
                        }
                    }
                    Text { text: "×"; font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-1); color: Colors.outline }
                }

                // Position X
                Text { text: Icons.arrowsOutCardinal; font.family: Icons.font; font.pixelSize: 14; color: Colors.outline }
                RowLayout { Layout.fillWidth: true; spacing: 8
                    Text { text: "Position X"; font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-1); color: Colors.overBackground; Layout.preferredWidth: 80 }
                    SpinBox { id: posX; from: -10000; to: 30000; stepSize: 10; value: root.monitor ? root.monitor.x : 0; editable: true; Layout.preferredWidth: 90
                        background: Rectangle { color: Colors.surfaceContainer; border.color: Colors.surfaceBright; border.width: 1; radius: 4 }
                        contentItem: TextInput { text: posX.value; font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-1); color: Colors.overBackground; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onValueModified: root.settingChanged("x", posX.value) }
                    Text { text: "Y"; font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-2); color: Colors.outline }
                    SpinBox { id: posY; from: -10000; to: 30000; stepSize: 10; value: root.monitor ? root.monitor.y : 0; editable: true; Layout.preferredWidth: 90
                        background: Rectangle { color: Colors.surfaceContainer; border.color: Colors.surfaceBright; border.width: 1; radius: 4 }
                        contentItem: TextInput { text: posY.value; font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-1); color: Colors.overBackground; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onValueModified: root.settingChanged("y", posY.value) }
                }

                // Rotation
                Text { text: Icons.arrowCounterClockwise; font.family: Icons.font; font.pixelSize: 14; color: Colors.outline }
                RowLayout { Layout.fillWidth: true; spacing: 8
                    Text { text: "Rotation"; font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-1); color: Colors.overBackground; Layout.preferredWidth: 80 }
                    NLCombo {
                        id: transformCombo
                        Layout.fillWidth: true
                        model: ["0° Normal","90°","180°","270°","90° Flip","270° Flip"]
                        currentIndex: root.monitor ? Math.min(root.monitor.transform, 5) : 0
                        onActivated: root.settingChanged("transform", index)
                    }
                }

                // VRR
                Text { text: Icons.waveform; font.family: Icons.font; font.pixelSize: 14; color: Colors.outline }
                RowLayout { Layout.fillWidth: true; spacing: 8
                    Text { text: "VRR"; font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-1); color: Colors.overBackground; Layout.preferredWidth: 80 }
                    NLCombo {
                        id: vrrCombo
                        Layout.fillWidth: true
                        model: ["Global Default","Disabled","Enabled","Fullscreen","Fullscreen+Gaming"]
                        currentIndex: root.monitor && root.monitor.vrr !== undefined ? root.monitor.vrr : 0
                        onActivated: { var v=[0,0,1,2,3]; root.settingChanged("vrr", v[index]) }
                    }
                }

                // HDR toggle
                Text { text: Icons.sun; font.family: Icons.font; font.pixelSize: 14; color: Colors.outline }
                RowLayout { Layout.fillWidth: true; spacing: 8
                    Text { text: "HDR"; font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-1); color: Colors.overBackground; Layout.preferredWidth: 80 }
                    Text {
                        text: root.monitor && root.monitor.hdrSupported ? "Supported" : "Not supported"
                        font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-2)
                        color: root.monitor && root.monitor.hdrSupported ? Colors.primary : Colors.outline
                        Layout.fillWidth: true
                    }
                    NLToggle {
                        checked: root.monitor ? root.monitor.hdr || false : false
                        enabled: root.monitor && root.monitor.hdrSupported || false
                        onToggled: root.settingChanged("hdr", value)
                    }
                }

                // Refresh rate display
                Text { text: Icons.clock; font.family: Icons.font; font.pixelSize: 14; color: Colors.outline }
                RowLayout { Layout.fillWidth: true; spacing: 8
                    Text { text: "Refresh"; font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-1); color: Colors.overBackground; Layout.preferredWidth: 80 }
                    Text {
                        text: root.monitor ? root.monitor.refreshRate.toFixed(2) + " Hz" : ""
                        font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-1)
                        color: Colors.overSurfaceVariant
                    }
                }
            }
        }
    }

    component SR: RowLayout {
        property string ic: ""; property string lb: ""
        spacing: 8
        Text { text: ic; font.family: Icons.font; font.pixelSize: 14; color: Colors.outline; Layout.preferredWidth: 20 }
        Text { text: lb; font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-1); color: Colors.overBackground; Layout.preferredWidth: 90 }
    }
}
