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

    ColumnLayout {
        id: cardLayout
        anchors.fill: parent; anchors.margins: 14; spacing: 14

        // ── Header row ──
        RowLayout {
            Layout.fillWidth: true; spacing: 10
            Rectangle { width: 10; height: 10; radius: 5; color: (root.monitor && root.monitor.focused) ? Styling.srItem("primary") : Colors.outline; Layout.alignment: Qt.AlignVCenter }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 1
                Text { text: root.monitor ? root.monitor.name : "Select a monitor"; font.family: Config.theme.font; font.pixelSize: Styling.fontSize(1); font.bold: true; color: Colors.overBackground }
                Text {
                    text: root.monitor ? [root.monitor.make, root.monitor.model, root.monitor.description].filter(function(s){return s}).join(" · ") : ""
                    font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-2); color: Colors.outline; elide: Text.ElideRight
                }
            }
            Switch {
                checked: root.monitor ? root.monitor.enabled : false
                enabled: !root.disabled
                onClicked: root.settingChanged("enabled", checked)
                indicator: Rectangle { implicitWidth: 36; implicitHeight: 20; radius: 10
                    color: parent.checked ? Styling.srItem("primary") : Qt.rgba(Colors.outline.r,Colors.outline.g,Colors.outline.b,0.3)
                    border.color: parent.checked ? Styling.srItem("primary") : Colors.outline; border.width: 1
                    Rectangle { x: parent.checked ? parent.parent.width-width-3 : 3; y: (parent.parent.height-height)/2; width: 14; height: 14; radius: 7
                        color: parent.checked ? "#ffffff" : Colors.outline
                        Behavior on x { enabled: Config.animDuration > 0; NumberAnimation { duration: Config.animDuration/2; easing.type: Easing.OutCubic } } }
                    Behavior on color { enabled: Config.animDuration > 0; ColorAnimation { duration: Config.animDuration/2 } } }
            }
        }

        // ── Settings ──
        ColumnLayout {
            Layout.fillWidth: true; spacing: 8; opacity: root.disabled ? 0.5 : 1.0; enabled: !root.disabled

            SR { ic: Icons.layout; lb: "Resolution"; Layout.fillWidth: true
                ComboBox { id: modeCombo
                    model: root.availableModes.length > 0 ? root.availableModes.map(function(m){return (m+"").replace("Hz"," Hz")}) : []
                    currentIndex: root.currentModeIndex; Layout.preferredWidth: 220
                    background: Rectangle { color: modeCombo.hovered ? Colors.surfaceContainerHigh : Colors.surfaceContainer; radius: Styling.radius(-2); border.color: Colors.outlineVariant; border.width: 1 }
                    contentItem: Text { text: modeCombo.displayText; font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-1); color: Colors.overBackground; verticalAlignment: Text.AlignVCenter; leftPadding: 10; elide: Text.ElideRight }
                    indicator: Text { text: Icons.caretDown; font.family: Icons.font; font.pixelSize: 14; color: Colors.overBackground; anchors.verticalCenter: parent.verticalCenter; anchors.right: parent.right; anchors.rightMargin: 8 }
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

            SR { ic: Icons.arrowsOut; lb: "Scale"; Layout.fillWidth: true
                RowLayout { spacing: 4
                    TextField { id: scaleInput; text: root.monitor ? root.monitor.scale.toFixed(2) : "1.00"; font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-1); color: Colors.overBackground; Layout.preferredWidth: 70; horizontalAlignment: Text.AlignRight
                        validator: DoubleValidator { bottom: 0.25; top: 10.0; decimals: 2 }
                        background: Rectangle { color: scaleInput.hovered ? Colors.surfaceContainerHigh : Colors.surfaceContainer; radius: Styling.radius(-2); border.color: Colors.outlineVariant; border.width: 1 }
                        onEditingFinished: { var v = parseFloat(text); if (!isNaN(v) && v>=0.25 && v<=10.0) root.settingChanged("scale", v); else text = root.monitor ? root.monitor.scale.toFixed(2) : "1.00" } }
                    Text { text: "×"; font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-1); color: Colors.outline } 
                } 
            }

            SR { ic: Icons.arrowsOutCardinal; lb: "Position"; Layout.fillWidth: true
                RowLayout { spacing: 4
                    Text { text: "X"; font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-2); color: Colors.outline }
                    SpinBox { id: posX; from: -10000; to: 30000; stepSize: 10; value: root.monitor ? root.monitor.x : 0; editable: true; Layout.preferredWidth: 80
                        background: Rectangle { color: Colors.surfaceContainer; border.color: Colors.outlineVariant; border.width: 1; radius: Styling.radius(-2) }
                        contentItem: TextInput { text: posX.value; font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-1); color: Colors.overBackground; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onValueModified: root.settingChanged("x", posX.value) }
                    Text { text: "Y"; font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-2); color: Colors.outline }
                    SpinBox { id: posY; from: -10000; to: 30000; stepSize: 10; value: root.monitor ? root.monitor.y : 0; editable: true; Layout.preferredWidth: 80
                        background: Rectangle { color: Colors.surfaceContainer; border.color: Colors.outlineVariant; border.width: 1; radius: Styling.radius(-2) }
                        contentItem: TextInput { text: posY.value; font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-1); color: Colors.overBackground; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onValueModified: root.settingChanged("y", posY.value) } 
                } 
            }

            SR { ic: Icons.arrowCounterClockwise; lb: "Rotation"; Layout.fillWidth: true
                ComboBox { id: transformCombo; model: ["0° Normal","90°","180°","270°","90° Flip","270° Flip"]; currentIndex: root.monitor ? Math.min(root.monitor.transform, 5) : 0; Layout.preferredWidth: 140
                    background: Rectangle { color: transformCombo.hovered ? Colors.surfaceContainerHigh : Colors.surfaceContainer; radius: Styling.radius(-2); border.color: Colors.outlineVariant; border.width: 1 }
                    contentItem: Text { text: transformCombo.displayText; font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-1); color: Colors.overBackground; verticalAlignment: Text.AlignVCenter; leftPadding: 10 }
                    indicator: Text { text: Icons.caretDown; font.family: Icons.font; font.pixelSize: 14; color: Colors.overBackground; anchors.verticalCenter: parent.verticalCenter; anchors.right: parent.right; anchors.rightMargin: 8 }
                    onActivated: root.settingChanged("transform", index) } }

            SR { ic: Icons.waveform; lb: "VRR"; Layout.fillWidth: true
                ComboBox { id: vrrCombo; model: ["Global Default","Disabled","Enabled","Fullscreen","Fullscreen+Gaming"]; currentIndex: root.monitor ? root.monitor.vrr : 0; Layout.preferredWidth: 160
                    background: Rectangle { color: vrrCombo.hovered ? Colors.surfaceContainerHigh : Colors.surfaceContainer; radius: Styling.radius(-2); border.color: Colors.outlineVariant; border.width: 1 }
                    contentItem: Text { text: vrrCombo.displayText; font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-1); color: Colors.overBackground; verticalAlignment: Text.AlignVCenter; leftPadding: 10 }
                    indicator: Text { text: Icons.caretDown; font.family: Icons.font; font.pixelSize: 14; color: Colors.overBackground; anchors.verticalCenter: parent.verticalCenter; anchors.right: parent.right; anchors.rightMargin: 8 }
                    onActivated: { var v=[0,0,1,2,3]; root.settingChanged("vrr", v[index]) } } }
        }
    }

    component SR: RowLayout {
        property string ic: ""; property string lb: ""
        spacing: 8
        Text { text: ic; font.family: Icons.font; font.pixelSize: 14; color: Colors.outline; Layout.preferredWidth: 20 }
        Text { text: lb; font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-1); color: Colors.overBackground; Layout.preferredWidth: 90 }
    }
}
