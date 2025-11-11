pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.modules.components
import qs.modules.theme
import qs.modules.globals
import qs.config

PanelWindow {
    id: root

    visible: GlobalStates.lockscreenVisible
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    focusable: true
    mask: null
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "ambxst-lockscreen"

    // Screen capture background
    ScreencopyView {
        id: screencopyBackground
        anchors.fill: parent
        captureSource: root.screen
        live: false
        paintCursor: false
        visible: false
    }

    // Blur effect
    MultiEffect {
        id: blurEffect
        anchors.fill: parent
        source: screencopyBackground
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 0
        blurMax: 64
        visible: false

        Behavior on blur {
            NumberAnimation {
                duration: 800
                easing.type: Easing.OutCubic
            }
        }
    }

    // Overlay for dimming
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.3
    }

    // Password input container
    Item {
        anchors.centerIn: parent
        width: Math.min(400, parent.width - 64)
        height: passwordInput.height

        SearchInput {
            id: passwordInput
            width: parent.width
            iconText: "🔒"
            placeholderText: "Enter password..."
            clearOnEscape: false

            onAccepted: {
                if (passwordInput.text === "123") {
                    GlobalStates.lockscreenVisible = false;
                    passwordInput.clear();
                } else {
                    // Simple shake animation for wrong password
                    wrongPasswordAnim.start();
                }
            }

            onEscapePressed: {
                GlobalStates.lockscreenVisible = false;
                passwordInput.clear();
            }

            SequentialAnimation {
                id: wrongPasswordAnim
                NumberAnimation {
                    target: passwordInput
                    property: "x"
                    from: 0
                    to: 10
                    duration: 50
                    easing.type: Easing.InOutQuad
                }
                NumberAnimation {
                    target: passwordInput
                    property: "x"
                    from: 10
                    to: -10
                    duration: 100
                    easing.type: Easing.InOutQuad
                }
                NumberAnimation {
                    target: passwordInput
                    property: "x"
                    from: -10
                    to: 10
                    duration: 100
                    easing.type: Easing.InOutQuad
                }
                NumberAnimation {
                    target: passwordInput
                    property: "x"
                    from: 10
                    to: 0
                    duration: 50
                    easing.type: Easing.InOutQuad
                }
                ScriptAction {
                    script: passwordInput.clear()
                }
            }

            Component.onCompleted: {
                if (GlobalStates.lockscreenVisible) {
                    passwordInput.focusInput();
                }
            }
        }
    }

    // Timer to animate blur after capture
    Timer {
        id: blurAnimTimer
        interval: 50
        onTriggered: {
            blurEffect.blur = 1;
        }
    }

    // Focus the input when lockscreen becomes visible
    onVisibleChanged: {
        if (visible) {
            blurEffect.blur = 0;
            screencopyBackground.captureFrame();
            blurEffect.visible = true;
            blurAnimTimer.start();
            passwordInput.focusInput();
        } else {
            blurAnimTimer.stop();
            blurEffect.visible = false;
            blurEffect.blur = 0;
        }
    }

    // Capture all keyboard input
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            GlobalStates.lockscreenVisible = false;
            passwordInput.clear();
            event.accepted = true;
        }
    }
}
