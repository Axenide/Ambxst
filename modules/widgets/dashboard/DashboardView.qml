import QtQuick
import qs.modules.widgets.dashboard
import qs.modules.services

Item {
    implicitWidth: 1000
    implicitHeight: 56 + 48 * 7

    readonly property int leftPanelWidth: 180

    Dashboard {
        id: dashboardItem
        anchors.fill: parent
        leftPanelWidth: parent.leftPanelWidth

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                Visibilities.setActiveModule("");
                event.accepted = true;
            } else if (event.key === Qt.Key_Space) {
                event.accepted = false;
            }
        }

        Component.onCompleted: {
            Qt.callLater(() => {
                forceActiveFocus();
            });
        }
    }
}
