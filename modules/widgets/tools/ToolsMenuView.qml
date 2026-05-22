import QtQuick
import qs.modules.components
import qs.modules.services
import qs.config

Item {
    implicitWidth: toolsMenu.implicitWidth
    implicitHeight: toolsMenu.implicitHeight

    Behavior on implicitWidth {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutQuart
        }
    }

    Behavior on implicitHeight {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutQuart
        }
    }

    ToolsMenu {
        id: toolsMenu
        anchors.fill: parent
        
        onItemSelected: {
            Visibilities.setActiveModule("")
        }
    }
    
    // Forzar foco cuando aparece la vista en el StackView
    onVisibleChanged: {
        if (visible) {
            Qt.callLater(() => {
                toolsMenu.forceActiveFocus();
            });
        }
    }
    
    Component.onCompleted: {
        if (visible) {
            Qt.callLater(() => {
                toolsMenu.forceActiveFocus();
            });
        }
    }
}
