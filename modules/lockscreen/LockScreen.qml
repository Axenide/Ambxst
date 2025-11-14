pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.modules.components
import qs.modules.corners
import qs.modules.theme
import qs.modules.globals
import qs.modules.widgets.dashboard.widgets
import qs.config

// Lock surface UI - shown on each screen when locked
WlSessionLockSurface {
    id: root

    property bool startAnim: false
    property bool authenticating: false
    property string errorMessage: ""
    property int failLockSecondsLeft: 0

    // Always transparent - blur background handles the visuals
    color: "transparent"

    // Screen capture background
    ScreencopyView {
        id: screencopyBackground
        anchors.fill: parent
        captureSource: root.screen
        live: false
        paintCursor: false
        visible: true
    }

    // Blur effect
    MultiEffect {
        id: blurEffect
        anchors.fill: parent
        source: screencopyBackground
        autoPaddingEnabled: false
        blurEnabled: true
        blur: startAnim ? 1 : 0
        blurMax: 64
        visible: true
        opacity: 1

        property real zoomScale: startAnim ? 1.25 : 1.0

        transform: Scale {
            origin.x: blurEffect.width / 2
            origin.y: blurEffect.height / 2
            xScale: blurEffect.zoomScale
            yScale: blurEffect.zoomScale
        }

        Behavior on blur {
            NumberAnimation {
                duration: Config.animDuration * 1.2
                easing.type: Easing.OutExpo
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutQuint
            }
        }

        Behavior on zoomScale {
            NumberAnimation {
                duration: Config.animDuration * 1.8
                easing.type: Easing.OutExpo
            }
        }
    }

    // Overlay for dimming
    Rectangle {
        id: dimOverlay
        anchors.fill: parent
        color: "black"
        opacity: startAnim ? 0.25 : 0

        property real zoomScale: startAnim ? 1.1 : 1.0

        transform: Scale {
            origin.x: dimOverlay.width / 2
            origin.y: dimOverlay.height / 2
            xScale: dimOverlay.zoomScale
            yScale: dimOverlay.zoomScale
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutQuint
            }
        }

        Behavior on zoomScale {
            NumberAnimation {
                duration: Config.animDuration * 1.8
                easing.type: Easing.OutExpo
            }
        }
    }

    // Clock (center)
    Item {
        id: clockContainer
        anchors.centerIn: parent
        width: clockRow.width
        height: hoursText.height + (hoursText.height * 0.5)

        Row {
            id: clockRow
            spacing: 0
            anchors.top: parent.top

            Text {
                id: hoursText
                text: Qt.formatTime(new Date(), "hh")
                font.family: "Universal Accreditation"
                font.pixelSize: 240
                font.weight: Font.Bold
                color: Colors.primary
                antialiasing: true
                opacity: startAnim ? 1 : 0

                property real slideOffset: startAnim ? 0 : -150

                transform: Translate {
                    y: hoursText.slideOffset
                }

                layer.enabled: true
                layer.effect: BgShadow {}

                Behavior on opacity {
                    NumberAnimation {
                        duration: Config.animDuration * 1.1
                        easing.type: Easing.OutExpo
                    }
                }

                Behavior on slideOffset {
                    NumberAnimation {
                        duration: Config.animDuration * 1.3
                        easing.type: Easing.OutExpo
                    }
                }
            }

            Text {
                id: minutesText
                text: Qt.formatTime(new Date(), "mm")
                font.family: "Universal Accreditation"
                font.pixelSize: 240
                font.weight: Font.Bold
                color: Colors.overBackground
                antialiasing: true
                anchors.verticalCenter: undefined
                anchors.top: hoursText.top
                anchors.topMargin: hoursText.height * 0.5
                opacity: startAnim ? 1 : 0

                property real slideOffset: startAnim ? 0 : 150

                transform: Translate {
                    y: minutesText.slideOffset
                }

                layer.enabled: true
                layer.effect: BgShadow {}

                Behavior on opacity {
                    NumberAnimation {
                        duration: Config.animDuration * 1.1
                        easing.type: Easing.OutExpo
                    }
                }

                Behavior on slideOffset {
                    NumberAnimation {
                        duration: Config.animDuration * 1.3
                        easing.type: Easing.OutExpo
                    }
                }
            }
        }

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: {
                hoursText.text = Qt.formatTime(new Date(), "hh");
                minutesText.text = Qt.formatTime(new Date(), "mm");
            }
        }
    }

    // Music player (slides from left)
    Item {
        id: playerContainer
        
        property bool isTopPosition: Config.lockscreen.position === "top"
        
        anchors {
            left: parent.left
            leftMargin: startAnim ? 32 : -(playerContainer.width + 64)
            top: isTopPosition ? parent.top : undefined
            topMargin: isTopPosition ? 32 : 0
            bottom: !isTopPosition ? parent.bottom : undefined
            bottomMargin: !isTopPosition ? 32 : 0
        }
        width: 350
        height: playerContent.height

        opacity: startAnim ? 1 : 0

        Behavior on anchors.leftMargin {
            NumberAnimation {
                duration: Config.animDuration * 1.1
                easing.type: Easing.OutExpo
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Config.animDuration * 0.8
                easing.type: Easing.OutQuad
            }
        }

        LockPlayer {
            id: playerContent
            width: parent.width
        }
    }

    // Password input container (slides from top or bottom)
    Item {
        id: passwordContainer
        
        property bool isTopPosition: Config.lockscreen.position === "top"
        
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: isTopPosition ? parent.top : undefined
            topMargin: isTopPosition ? (startAnim ? 32 : -80) : 0
            bottom: !isTopPosition ? parent.bottom : undefined
            bottomMargin: !isTopPosition ? (startAnim ? 32 : -80) : 0
        }
        width: 350
        height: 96

        opacity: startAnim ? 1 : 0
        scale: startAnim ? 1 : 0.92

        Behavior on anchors.topMargin {
            NumberAnimation {
                duration: Config.animDuration * 1.2
                easing.type: Easing.OutExpo
            }
        }

        Behavior on anchors.bottomMargin {
            NumberAnimation {
                duration: Config.animDuration * 1.2
                easing.type: Easing.OutExpo
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Config.animDuration * 0.9
                easing.type: Easing.OutQuad
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Config.animDuration * 1.2
                easing.type: Easing.OutBack
                easing.overshoot: 1.2
            }
        }

        // Password input with avatar
        BgRect {
            id: passwordInputBox
            anchors.centerIn: parent
            width: parent.width
            height: 96
            radius: Config.roundness > 0 ? (height / 2) * (Config.roundness / 16) : 0

            property real shakeOffset: 0
            property bool showError: false

            transform: Translate {
                x: passwordInputBox.shakeOffset
            }

            Row {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 24
                spacing: 12

                // Avatar (64x64)
                Rectangle {
                    id: avatarContainer
                    width: 64
                    height: 64
                    radius: Config.roundness > 0 ? (height / 2) * (Config.roundness / 16) : 0
                    color: "transparent"
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        id: userAvatar
                        anchors.fill: parent
                        source: `file://${Quickshell.env("HOME")}/.face.icon`
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        asynchronous: true
                        visible: status === Image.Ready

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskThresholdMin: 0.5
                            maskSpreadAtMin: 1.0
                            maskSource: ShaderEffectSource {
                                sourceItem: Rectangle {
                                    width: userAvatar.width
                                    height: userAvatar.height
                                    radius: Config.roundness > 0 ? (height / 2) * (Config.roundness / 16) : 0
                                }
                            }
                        }
                    }

                    // Fallback icon if image not found
                    Text {
                        anchors.centerIn: parent
                        text: "👤"
                        font.pixelSize: 32
                        visible: userAvatar.status !== Image.Ready
                    }
                }

                // Password field
                Rectangle {
                    width: parent.width - avatarContainer.width - parent.spacing
                    height: 48
                    anchors.verticalCenter: parent.verticalCenter
                    color: passwordInputBox.showError ? Colors.error : Colors.surface
                    radius: Config.roundness > 0 ? (height / 2) * (Config.roundness / 16) : 0

                    Behavior on color {
                        ColorAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutQuad
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 32
                        spacing: 8

                        // User icon / Spinner
                        Text {
                            id: userIcon
                            text: authenticating ? Icons.spinnerGap : Icons.user
                            font.family: Icons.font
                            font.pixelSize: 24
                            color: passwordInputBox.showError ? Colors.overError : Colors.overBackground
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            Layout.alignment: Qt.AlignVCenter
                            z: 10
                            rotation: 0

                            Behavior on color {
                                ColorAnimation {
                                    duration: Config.animDuration
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Timer {
                                id: spinnerTimer
                                interval: 100
                                repeat: true
                                running: authenticating
                                onTriggered: {
                                    userIcon.rotation = (userIcon.rotation + 45) % 360;
                                }
                            }

                            onTextChanged: {
                                if (userIcon.text === Icons.user) {
                                    userIcon.rotation = 0;
                                }
                            }
                        }

                        // Text field
                        TextField {
                            id: passwordInput
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            placeholderText: usernameCollector.text.trim()
                            placeholderTextColor: passwordInputBox.showError ? Qt.rgba(Colors.overError.r, Colors.overError.g, Colors.overError.b, 0.5) : Colors.outline
                            font.family: Config.theme.font
                            font.pixelSize: Config.theme.fontSize
                            color: passwordInputBox.showError ? Colors.overError : Colors.overBackground
                            background: null
                            echoMode: TextInput.Password
                            verticalAlignment: TextInput.AlignVCenter
                            enabled: !authenticating

                            Behavior on color {
                                ColorAnimation {
                                    duration: Config.animDuration
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Behavior on placeholderTextColor {
                                ColorAnimation {
                                    duration: Config.animDuration
                                    easing.type: Easing.OutQuad
                                }
                            }

                            onAccepted: {
                                if (passwordInput.text.trim() === "")
                                    return;

                                // Guardar contraseña y limpiar campo inmediatamente
                                authPasswordHolder.password = passwordInput.text;
                                passwordInput.text = "";

                                authenticating = true;
                                errorMessage = "";
                                pamAuth.running = true;
                            }
                        }
                    }
                }
            }

            SequentialAnimation {
                id: wrongPasswordAnim
                ScriptAction {
                    script: {
                        passwordInputBox.showError = true;
                    }
                }
                NumberAnimation {
                    target: passwordInputBox
                    property: "shakeOffset"
                    to: 10
                    duration: 50
                    easing.type: Easing.InOutQuad
                }
                NumberAnimation {
                    target: passwordInputBox
                    property: "shakeOffset"
                    to: -10
                    duration: 100
                    easing.type: Easing.InOutQuad
                }
                NumberAnimation {
                    target: passwordInputBox
                    property: "shakeOffset"
                    to: 10
                    duration: 100
                    easing.type: Easing.InOutQuad
                }
                NumberAnimation {
                    target: passwordInputBox
                    property: "shakeOffset"
                    to: 0
                    duration: 50
                    easing.type: Easing.InOutQuad
                }
                ScriptAction {
                    script: {
                        passwordInput.text = "";
                        authenticating = false;
                        passwordInputBox.showError = false;
                    }
                }
            }
        }
    }

    // Timer to unlock after exit animation
    Timer {
        id: unlockTimer
        interval: Config.animDuration
        onTriggered: {
            GlobalStates.lockscreenVisible = false;
        }
    }

    // Processes for user info
    Process {
        id: usernameProc
        command: ["whoami"]
        running: true

        stdout: StdioCollector {
            id: usernameCollector
            waitForEnd: true
        }
    }

    Process {
        id: hostnameProc
        command: ["hostname"]
        running: true

        stdout: StdioCollector {
            id: hostnameCollector
            waitForEnd: true
        }
    }

    // Holder temporal para la contraseña durante autenticación
    QtObject {
        id: authPasswordHolder
        property string password: ""
    }

    // Proceso para verificar tiempo de faillock
    Process {
        id: failLockCheck
        command: ["bash", "-c", `faillock --user '${usernameCollector.text.trim()}' 2>/dev/null | grep -oP 'left \\K[0-9]+' | head -1`]
        running: false

        stdout: StdioCollector {
            id: failLockCollector

            onStreamFinished: {
                const output = text.trim();
                const seconds = parseInt(output);

                if (!isNaN(seconds) && seconds > 0) {
                    failLockSecondsLeft = seconds;
                    failLockCountdown.start();
                } else {
                    failLockSecondsLeft = 0;
                }
            }
        }
    }

    // Timer para actualizar el countdown de faillock
    Timer {
        id: failLockCountdown
        interval: 1000
        repeat: true
        running: false

        onTriggered: {
            if (failLockSecondsLeft > 0) {
                failLockSecondsLeft--;
            } else {
                stop();
                errorMessage = "";
            }
        }
    }

    // PAM authentication process
    Process {
        id: pamAuth
        command: [Qt.resolvedUrl("ambxst-auth-stdin.sh").toString().replace("file://", "")]
        running: false
        environment: {
            "PAM_USER": usernameCollector.text.trim(),
            "PAM_PASSWORD": authPasswordHolder.password
        }

        onExited: exitCode => {
            // Limpiar contraseña
            authPasswordHolder.password = "";

            if (exitCode === 0) {
                // Autenticación exitosa - trigger exit animation
                startAnim = false;

                // Wait for exit animation, then unlock
                unlockTimer.start();

                errorMessage = "";
                authenticating = false;
            } else {
                // Error de autenticación
                let msg = "";
                switch (exitCode) {
                case 10:
                    msg = "Usuario no encontrado";
                    break;
                case 11:
                    msg = "Contraseña incorrecta";
                    break;
                case 12:
                    msg = "Error de autenticación";
                    break;
                case 20:
                    msg = "Cuenta expirada";
                    break;
                case 21:
                    msg = "Debe cambiar su contraseña";
                    break;
                case 22:
                    msg = "Cuenta bloqueada";
                    break;
                case 23:
                    msg = "Error de estado de cuenta";
                    break;
                case 30:
                    // Faillock detectado - verificar tiempo restante
                    failLockCheck.running = true;
                    msg = "Cuenta bloqueada por intentos fallidos";
                    break;
                case 100:
                    msg = "Error: parámetro inválido";
                    break;
                case 101:
                    msg = "Error leyendo contraseña";
                    break;
                case 102:
                    msg = "Error inicializando PAM";
                    break;
                case 103:
                    msg = "Timeout esperando contraseña";
                    break;
                case 104:
                    msg = "Error interno";
                    break;
                default:
                    msg = `Error desconocido (${exitCode})`;
                }

                errorMessage = msg;
                console.warn("PAM auth failed:", exitCode, msg);
                wrongPasswordAnim.start();
            }
        }
    }

    // Screen corners
    RoundCorner {
        id: topLeft
        size: Config.roundness > 0 ? Config.roundness + 4 : 0
        anchors.left: parent.left
        anchors.top: parent.top
        corner: RoundCorner.CornerEnum.TopLeft
    }

    RoundCorner {
        id: topRight
        size: Config.roundness > 0 ? Config.roundness + 4 : 0
        anchors.right: parent.right
        anchors.top: parent.top
        corner: RoundCorner.CornerEnum.TopRight
    }

    RoundCorner {
        id: bottomLeft
        size: Config.roundness > 0 ? Config.roundness + 4 : 0
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        corner: RoundCorner.CornerEnum.BottomLeft
    }

    RoundCorner {
        id: bottomRight
        size: Config.roundness > 0 ? Config.roundness + 4 : 0
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        corner: RoundCorner.CornerEnum.BottomRight
    }

    // Initialize when component is created (when lock becomes active)
    Component.onCompleted: {
        // Capture screen immediately
        screencopyBackground.captureFrame();

        // Start animations
        startAnim = true;
        passwordInput.forceActiveFocus();
    }
}
