import QtQuick
import qs.modules.widgets.dashboard
import qs.modules.services

Item {
    id: root

    implicitWidth: 900
    implicitHeight: 56 + 48 * 6
    property string screenName: ""

    readonly property int leftPanelWidth: 270

    Dashboard {
        id: dashboardItem
        anchors.fill: parent
        leftPanelWidth: root.leftPanelWidth
        screenName: root.screenName

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
