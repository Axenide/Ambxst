import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.modules.components
import qs.modules.theme
import qs.modules.globals
import qs.config
import qs.modules.lockscreen

Popup {
    id: root

    property bool authRequired: Config.lockscreen.requireAuthForDashboard
    property string authMethod: Config.lockscreen.authMethod
    property bool authenticating: false
    property bool authSuccess: false
    property string errorMessage: ""
    property string password: ""

    signal authCompleted(bool success)

    width: 400
    height: 280
    visible: false
    modal: true
    closePolicy: Popup.NoAutoKeys
    background: null
    padding: 0

    function open() {
        if (!authRequired)
            return;

        authSuccess = false;
        errorMessage = "";
        password = "";
        authenticating = false;
        Popup.open();

        if (authMethod === "fingerprint" || authMethod === "both") {
            if (FingerprintService.available && FingerprintService.enrolled) {
                Qt.callLater(function() {
                    FingerprintService.startVerification();
                });
            }
        }
    }

    function close() {
        Popup.close();
    }

    function authenticatePassword(pwd) {
        if (authMethod === "fingerprint" && authMethod !== "both")
            return;

        authenticating = true;
        errorMessage = "";

        var proc = Qt.createQmlObject('import Quickshell.Io; Process {}', root);
        proc.command = ["python3", "-c", "import pam; p = pam.pam(); print('success' if p.authenticate('" + Quickshell.env("USER") + "', '" + pwd + "') else 'failed')"];
        proc.running = true;

        var collector = Qt.createQmlObject('import Quickshell.Io; StdioCollector {}', proc);
        collector.waitForEnd = true;

        proc.onExited.connect(function() {
            authenticating = false;
            var result = collector.text.trim();
            if (result === "success") {
                authSuccess = true;
                authCompleted(true);
                root.close();
            } else {
                errorMessage = "Password authentication failed";
                password = "";
            }
        });
    }

    Connections {
        target: FingerprintService

        onAuthSuccess: {
            if (root.authRequired && (root.authMethod === "fingerprint" || root.authMethod === "both")) {
                root.authSuccess = true;
                root.authCompleted(true);
                root.close();
            }
        }

        onAuthFailed: {
            if (root.authRequired && (root.authMethod === "fingerprint" || root.authMethod === "both")) {
                root.errorMessage = error;
            }
        }
    }

    Component {
        id: authContent

        Item {
            anchors.fill: parent

            Rectangle {
                anchors.fill: parent
                color: Colors.surface
                radius: Config.roundness > 0 ? (height / 2) * (Config.roundness / 16) : 0
                layer.enabled: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: 1
                    blurMax: 32
                    shadowEnabled: true
                    shadowColor: Qt.rgba(0, 0, 0, 0.3)
                    shadowVerticalOffset: 4
                    shadowHorizontalOffset: 0
                    shadowBlurRadius: 16
                }

                Column {
                    anchors.centerIn: parent
                    anchors.margins: 32
                    spacing: 20

                    Item {
                        width: 64
                        height: 64
                        anchors.horizontalCenter: parent.horizontalCenter

                        Text {
                            anchors.centerIn: parent
                            text: root.authSuccess ? Icons.shieldCheck : Icons.lock
                            font.family: Icons.font
                            font.pixelSize: 32
                            color: root.authSuccess ? Colors.green : Colors.primary
                        }
                    }

                    Text {
                        text: "Authentication Required"
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(2)
                        font.bold: true
                        color: Colors.onSurface
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width
                    }

                    Text {
                        text: root.errorMessage || "Please authenticate to access the dashboard"
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(0)
                        color: root.errorMessage ? Colors.error : Colors.onSurfaceDim
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width
                        wrapMode: Text.Wrap
                        visible: !root.authSuccess
                    }

                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 12
                        visible: !root.authSuccess && (root.authMethod === "password" || root.authMethod === "both")

                        StyledRect {
                            variant: root.errorMessage ? "error" : "common"
                            width: 300
                            height: 44
                            radius: Styling.radius(-2)

                            TextInput {
                                id: passwordField
                                anchors.fill: parent
                                anchors.margins: 12
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(0)
                                color: Colors.overBackground
                                echoMode: TextInput.Password
                                selectByMouse: true
                                clip: true
                                verticalAlignment: TextInput.AlignVCenter
                                focus: true

                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    text: "Enter password"
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(0)
                                    color: Colors.overSurfaceVariant
                                    visible: passwordField.text === ""
                                }

                                onTextChanged: {
                                    root.password = text;
                                }

                                onAccepted: {
                                    root.authenticatePassword(passwordField.text);
                                }
                            }
                        }

                        StyledRect {
                            variant: "primary"
                            width: 300
                            height: 36
                            radius: Styling.radius(-2)
                            enabled: !root.authenticating

                            Text {
                                anchors.centerIn: parent
                                text: root.authenticating ? "Authenticating..." : "Unlock Dashboard"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(0)
                                color: Colors.onPrimary
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                enabled: !root.authenticating
                                onClicked: {
                                    root.authenticatePassword(passwordField.text);
                                }
                            }
                        }
                    }

                    Item {
                        width: 1
                        height: 1
                        visible: root.authMethod === "fingerprint" || root.authMethod === "both"
                    }

                    StyledRect {
                        variant: "common"
                        width: 120
                        height: 36
                        radius: Styling.radius(-2)
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: root.authMethod === "fingerprint" || root.authMethod === "both"

                        Text {
                            anchors.centerIn: parent
                            text: Icons.fingerprint
                            font.family: Icons.font
                            font.pixelSize: 20
                            color: Colors.primary
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (FingerprintService.available && FingerprintService.enrolled) {
                                    FingerprintService.startVerification();
                                }
                            }
                        }
                    }

                    StyledRect {
                        variant: "common"
                        width: 100
                        height: 36
                        radius: Styling.radius(-2)
                        anchors.horizontalCenter: parent.horizontalCenter

                        Text {
                            anchors.centerIn: parent
                            text: "Cancel"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(0)
                            color: Colors.overBackground
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.close();
                                root.authCompleted(false);
                            }
                        }
                    }
                }
            }
        }
    }

    contentItem: Loader {
        sourceComponent: authContent
    }
}
