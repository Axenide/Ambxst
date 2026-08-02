import QtQuick
import qs.modules.components
import qs.modules.services
import qs.modules.globals
import qs.modules.notch
import qs.config

NotchAnimationBehavior {
    id: root
    isVisible: GlobalStates.powermenuOpen
    implicitWidth: powerMenu.implicitWidth
    implicitHeight: powerMenu.implicitHeight

    Behavior on implicitWidth {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Styling.animEasing
        }
    }

    Behavior on implicitHeight {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Styling.animEasing
        }
    }

    PowerMenu {
        id: powerMenu
        anchors.fill: parent
        
        onItemSelected: {
            Visibilities.setActiveModule("")
        }
    }
    
    // Forzar foco cuando aparece la vista en el StackView
    onVisibleChanged: {
        if (visible) {
            Qt.callLater(() => {
                powerMenu.forceActiveFocus();
            });
        }
    }
    
    Component.onCompleted: {
        if (visible) {
            Qt.callLater(() => {
                powerMenu.forceActiveFocus();
            });
        }
    }
}