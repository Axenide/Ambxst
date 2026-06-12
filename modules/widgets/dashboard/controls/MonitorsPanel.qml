import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

Item {
    id: root
    implicitHeight: layout.implicitHeight
    Layout.fillWidth: true

    property var monitorList: []
    property int selectedIndex: 0
    property bool hasChanges: false
    property bool isApplying: false
    property string statusMsg: ""

    Component.onCompleted: MonitorsWriter.listMonitors()

    Connections {
        target: MonitorsWriter
        function onMonitorsListed(data) {
            root.monitorList = data || [];
            if (root.selectedIndex >= root.monitorList.length) {
                root.selectedIndex = 0;
            }
            root.hasChanges = false;
        }
        function onSyncFinished(success, msg) {
            root.isApplying = false;
            if (success) {
                root.statusMsg = "Applied ✓";
                statusClearTimer.restart();
                MonitorsWriter.listMonitors();
            } else {
                root.statusMsg = "Error: " + msg;
            }
        }
    }

    Timer { id: statusClearTimer; interval: 3000; onTriggered: root.statusMsg = "" }

    function updateSetting(idx, key, value) {
        var list = JSON.parse(JSON.stringify(root.monitorList));
        list[idx][key] = value;
        root.monitorList = list;
        root.hasChanges = true;
    }

    function applyChanges() {
        if (!root.hasChanges || root.isApplying || root.monitorList.length === 0) return;
        root.isApplying = true;
        root.statusMsg = "Applying...";
        MonitorsWriter.syncWithData(root.monitorList);
    }

    ColumnLayout {
        id: layout
        anchors.left: parent.left; anchors.right: parent.right; spacing: 14

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Monitor Layout"
                font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-1)
                font.weight: Font.Medium; color: Colors.outline
                Layout.fillWidth: true
            }
            Button {
                flat: true; hoverEnabled: true
                Layout.preferredHeight: 28
                enabled: root.hasChanges && !root.isApplying
                background: StyledRect {
                    variant: root.hasChanges ? "primary" : "common"
                    radius: Styling.radius(-4)
                    opacity: root.hasChanges ? 1.0 : 0.5
                }
                contentItem: Text {
                    text: root.isApplying ? (Icons.circleNotch + " Applying...") : (Icons.shieldCheck + " Apply")
                    font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-2)
                    color: root.hasChanges ? Styling.srItem("primary") : Colors.overBackground
                    anchors.centerIn: parent
                }
                onClicked: root.applyChanges()
            }
        }

        MonitorArrangementView {
            id: arrangementView
            Layout.fillWidth: true
            monitors: root.monitorList
            selectedIndex: root.selectedIndex
            onMonitorMoved: (idx, x, y) => {
                var list = JSON.parse(JSON.stringify(root.monitorList));
                list[idx].x = x; list[idx].y = y;
                root.monitorList = list;
                root.hasChanges = true;
            }
            onMonitorSelected: (idx) => { root.selectedIndex = idx; }
        }

        Text {
            text: "Selected Monitor Settings"
            font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-1)
            font.weight: Font.Medium; color: Colors.outline
            Layout.topMargin: 4
        }

        MonitorSettingsForm {
            Layout.fillWidth: true
            monitor: root.monitorList.length > root.selectedIndex ? root.monitorList[root.selectedIndex] : null
            onSettingChanged: (key, value) => {
                root.updateSetting(root.selectedIndex, key, value);
            }
        }

        // Status bar
        StyledRect {
            Layout.fillWidth: true; Layout.preferredHeight: 24
            variant: root.hasChanges ? "focus" : "internalbg"
            radius: Styling.radius(-4)
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8
                Text {
                    Layout.fillWidth: true
                    text: root.statusMsg || (root.hasChanges ? Icons.edit + " Unsaved changes" : "All changes applied")
                    font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-3)
                    color: root.hasChanges ? Styling.srItem("primary") : Colors.outline; elide: Text.ElideRight
                }
            }
        }
    }
}
