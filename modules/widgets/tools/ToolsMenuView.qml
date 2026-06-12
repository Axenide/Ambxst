import QtQuick
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.theme

Item {
    implicitWidth: toolsMenu.implicitWidth
    implicitHeight: toolsMenu.implicitHeight

    Behavior on implicitWidth {
        enabled: Anim.animationsEnabled
        NumberAnimation {
            duration: Anim.standardNormal
            easing.type: Anim.easing("standard").type
                        easing.bezierCurve: Anim.easing("standard").bezierCurve
        }
    }

    Behavior on implicitHeight {
        enabled: Anim.animationsEnabled
        NumberAnimation {
            duration: Anim.standardNormal
            easing.type: Anim.easing("standard").type
                        easing.bezierCurve: Anim.easing("standard").bezierCurve
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
