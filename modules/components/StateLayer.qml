pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.modules.theme

/*!
    StateLayer.qml — Material 3 interaction state layer with ripple.

    Provides visual feedback for hover, press, focus, and disabled states,
    plus a ripple emanating from the click point.

    Usage:
        StateLayer {
            anchors.fill: parent
            color: Colors.overPrimary
            onClicked: console.log("clicked!")
        }
*/
Item {
    id: root

    // Fill parent by default so it acts as an overlay
    anchors.fill: parent

    // ============================================
    // PUBLIC API
    // ============================================

    /*! Whether this layer is interactive. When false, no states or ripple are shown. */
    property bool interactive: true

    /*! Base color of the state layer. Typically the "on" color of the surface below. */
    property color color: Colors.overBackground

    /*! Opacity values per M3 spec. */
    property real hoverOpacity: 0.08
    property real pressedOpacity: 0.12
    property real draggedOpacity: 0.16
    property real focusOpacity: 0.12
    property real disabledOpacity: 0.04
    property real rippleOpacity: 0.12

    /*! If true, the ripple animation plays on press. */
    property bool enableRipple: true

    /*! If true, the hover/pressed flat overlay is shown. */
    property bool enableOverlay: true

    // Signals forwarded from the internal MouseArea
    signal clicked(var mouse)
    signal pressed(var mouse)
    signal released(var mouse)
    signal entered()
    signal exited()
    signal positionChanged(var mouse)

    // ============================================
    // INTERNAL
    // ============================================

    opacity: interactive ? 1 : disabledOpacity

    // Flat state overlay (hover / pressed / focus)
    Rectangle {
        id: overlay
        anchors.fill: parent
        color: root.color
        opacity: {
            if (!root.interactive || !root.enableOverlay) return 0;
            if (mouseArea.containsPress) return root.pressedOpacity;
            if (mouseArea.containsMouse) return root.hoverOpacity;
            return 0;
        }

        Behavior on opacity {
            enabled: Anim.animationsEnabled
            NumberAnimation {
                duration: Anim.standardSmall
                easing.type: Easing.OutCubic
            }
        }
    }

    // Ripple layer
    Item {
        id: rippleLayer
        anchors.fill: parent
        clip: true
        visible: root.interactive && root.enableRipple

        Rectangle {
            id: ripple
            width: 0
            height: width
            radius: width / 2
            color: root.color
            opacity: 0
            // Centered via x/y update in triggerRipple
        }

        ParallelAnimation {
            id: rippleAnim
            alwaysRunToEnd: false

            NumberAnimation {
                target: ripple
                property: "width"
                from: 0
                to: Math.max(root.width, root.height) * 2.8
                duration: Anim.emphasizedNormal
                easing.type: Anim.easing("emphasized").type
                easing.bezierCurve: Anim.easing("emphasized").bezierCurve
            }

            NumberAnimation {
                target: ripple
                property: "opacity"
                from: root.rippleOpacity
                to: 0
                duration: Anim.emphasizedNormal
                easing.type: Easing.OutCubic
            }

            onStopped: {
                ripple.width = 0;
                ripple.opacity = 0;
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true

        onClicked: mouse => root.clicked(mouse)
        onPressed: mouse => {
            root.pressed(mouse);
            if (root.enableRipple) {
                triggerRipple(mouse.x, mouse.y);
            }
        }
        onReleased: mouse => root.released(mouse)
        onEntered: root.entered()
        onExited: root.exited()
        onPositionChanged: mouse => root.positionChanged(mouse)
    }

    function triggerRipple(cx, cy) {
        if (!Anim.animationsEnabled) return;
        rippleAnim.stop();
        ripple.x = cx - ripple.width / 2;
        ripple.y = cy - ripple.height / 2;
        rippleAnim.start();
    }
}
