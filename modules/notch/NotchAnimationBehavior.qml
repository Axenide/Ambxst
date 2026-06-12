import QtQuick
import qs.config
import qs.modules.theme

// Comportamiento estándar para animaciones de elementos que aparecen en el notch
Item {
    id: root

    // Propiedad para controlar la visibilidad con animaciones
    property bool isVisible: false

    // Aplicar las animaciones estándar del notch
    scale: isVisible ? 1.0 : 0.8
    opacity: isVisible ? 1.0 : 0.0
    visible: opacity > 0

    Behavior on scale {
        enabled: Anim.animationsEnabled
        NumberAnimation {
            duration: Anim.emphasizedNormal
            easing.type: Anim.easing("emphasized").type
            easing.bezierCurve: Anim.easing("emphasized").bezierCurve
        }
    }

    Behavior on opacity {
        enabled: Anim.animationsEnabled
        NumberAnimation {
            duration: Anim.standardNormal
            easing.type: Anim.easing("standard").type
            easing.bezierCurve: Anim.easing("standard").bezierCurve
        }
    }
}
