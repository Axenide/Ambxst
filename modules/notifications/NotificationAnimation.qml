import QtQuick
import qs.config
import qs.modules.theme

Item {
    id: root

    // Propiedades para la animación de destrucción
    property Item targetItem: null
    property real dismissOvershoot: 20
    property real parentWidth: 0
    property bool isDiscardAll: false

    // Señales para diferentes tipos de animación
    signal destroyFinished

    // Animación de destrucción
    ParallelAnimation {
        id: destroyAnimation
        running: false

        NumberAnimation {
            target: root.targetItem?.anchors
            property: "leftMargin"
            to: root.parentWidth / 8 + root.dismissOvershoot
            duration: Anim.standardNormal
            easing.type: Anim.easing("emphasized").type
                        easing.bezierCurve: Anim.easing("emphasized").bezierCurve
        }

        NumberAnimation {
            target: root.targetItem
            property: "scale"
            from: 1.0
            to: 0.8
            duration: Anim.standardNormal
            easing.type: Anim.easing("emphasized", "exit").type
            easing.bezierCurve: Anim.easing("emphasized", "exit").bezierCurve
        }

        NumberAnimation {
            target: root.targetItem
            property: "opacity"
            from: 1.0
            to: 0.0
            duration: Anim.standardNormal
            easing.type: Anim.easing("emphasized", "exit").type
            easing.bezierCurve: Anim.easing("emphasized", "exit").bezierCurve
        }

        onFinished: {
            root.destroyFinished();
        }
    }

    // Función pública para ejecutar animación de destrucción
    function startDestroy() {
        destroyAnimation.running = true;
    }
}
