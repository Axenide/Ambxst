import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.modules.components
import qs.modules.theme
import qs.modules.globals
import qs.config
import qs.modules.lockscreen

Popup {
    id: root

    property string enrollFinger: ""
    property int enrollStage: 0
    property int enrollTotalStages: 5
    property bool enrolling: false
    property bool enrollComplete: false
    property string enrollError: ""
    property string enrollMessage: "Place your finger on the sensor"
    property var fingerOptions: [
        "right-thumb", "right-index-finger", "right-middle-finger",
        "right-ring-finger", "right-little-finger",
        "left-thumb", "left-index-finger", "left-middle-finger",
        "left-ring-finger", "left-little-finger"
    ]

    signal enrollAccepted()
    signal enrollRejected()

    width: 420
    height: 430
    visible: false
    modal: true
    closePolicy: Popup.NoAutoClose
    background: null
    padding: 0

    function open(finger) {
        enrollFinger = finger || "right-index-finger";
        enrollStage = 0;
        enrollComplete = false;
        enrollError = "";
        enrolling = false;
        enrollMessage = "Place your finger on the sensor";
        visible = true;
    }

    function close() {
        visible = false;
    }

    function startEnrollment() {
        enrolling = true;
        enrollStage = 0;
        enrollError = "";
        enrollMessage = "Place your finger on the sensor to enroll";
        FingerprintService.enrollFinger(enrollFinger);
    }

    function updateStage(stage) {
        enrollStage = stage;
        enrollMessage = "Lift and replace your finger... (scan " + stage + " of ~" + enrollTotalStages + ")";
    }

    function setError(error) {
        enrolling = false;
        enrollError = error;
        enrollMessage = error;
    }

    function reset() {
        enrolling = false;
        enrollStage = 0;
        enrollComplete = false;
        enrollError = "";
        enrollMessage = "Place your finger on the sensor";
    }

    Connections {
        target: FingerprintService

        // Real per-scan progress: each successful scan emits enrollProgress.
        // (The old code counted authSuccess signals — which fire exactly once
        // at the end — so the wizard froze at "stage 2 of 5" forever.)
        onEnrollProgress: {
            if (root.enrolling) {
                root.updateStage(stage);
            }
        }

        onAuthSuccess: {
            if (root.enrolling) {
                root.enrollComplete = true;
                root.enrolling = false;
                root.enrollMessage = "Enrollment complete!";
            }
        }

        onAuthFailed: {
            if (root.enrolling) {
                root.setError(error);
            }
        }
    }

    Component {
        id: enrollContent

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
                        width: 80
                        height: 80
                        anchors.horizontalCenter: parent.horizontalCenter

                        BusyIndicator {
                            id: enrollSpinner
                            anchors.centerIn: parent
                            width: 64
                            height: 64
                            running: root.enrolling
                            visible: root.enrolling
                        }

                        Text {
                            anchors.centerIn: parent
                            text: root.enrollComplete ? Icons.shieldCheck : (root.enrollError ? Icons.warning : Icons.fingerprint)
                            font.family: Icons.font
                            font.pixelSize: Styling.fontSize(34)
                            color: root.enrollComplete ? Colors.green : (root.enrollError ? Colors.error : Colors.primary)
                            visible: !root.enrolling
                        }
                    }

                    Text {
                        text: root.enrollComplete ? "Enrollment Complete!" : "Enroll Finger"
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(2)
                        font.bold: true
                        color: Colors.overBackground
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width
                    }

                    Text {
                        text: root.enrollMessage
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(0)
                        color: root.enrollError ? Colors.error : Colors.overSurfaceVariant
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width
                        wrapMode: Text.Wrap
                    }

                    Rectangle {
                        width: parent.width
                        height: 4
                        color: Colors.outline
                        radius: 2
                        clip: true
                        visible: root.enrolling

                        Rectangle {
                            width: (root.enrollStage / root.enrollTotalStages) * parent.width
                            height: parent.height
                            color: Colors.primary
                            radius: 2
                            Behavior on width {
                                enabled: Config.animDuration > 0
                                NumberAnimation {
                                    duration: Config.animDuration
                                    easing.type: Styling.animEasing
                                }
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 8
                        visible: !root.enrolling && !root.enrollComplete

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Choose a finger:"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            color: Colors.overSurfaceVariant
                        }

                        Flow {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 340
                            spacing: 6

                            Repeater {
                                model: root.fingerOptions

                                StyledRect {
                                    required property string modelData
                                    variant: root.enrollFinger === modelData ? "primary" : "common"
                                    width: 106
                                    height: 28
                                    radius: Styling.radius(-3)

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.replace(/-/g, " ")
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-2)
                                        elide: Text.ElideRight
                                        color: parent.variant === "primary" ? parent.item : Colors.overSurfaceVariant
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.enrollFinger = modelData
                                    }
                                }
                            }
                        }
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 16
                        visible: !root.enrollComplete

                        StyledRect {
                            id: startBtn
                            variant: "common"
                            width: 100
                            height: 36
                            radius: Styling.radius(-2)

                            Text {
                                anchors.centerIn: parent
                                text: root.enrolling ? "Cancel" : "Start"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(0)
                                color: startBtn.item
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.enrolling) {
                                        root.reset();
                                        FingerprintService.stopVerification();
                                    } else {
                                        root.startEnrollment();
                                    }
                                }
                            }
                        }

                        StyledRect {
                            id: doneBtn
                            variant: "primary"
                            width: 100
                            height: 36
                            radius: Styling.radius(-2)

                            Text {
                                anchors.centerIn: parent
                                text: "Done"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(0)
                                color: doneBtn.item
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.close();
                                    root.enrollRejected();
                                }
                            }
                        }
                    }

                    StyledRect {
                        id: finishBtn
                        variant: "primary"
                        width: 120
                        height: 36
                        radius: Styling.radius(-2)
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: root.enrollComplete

                        Text {
                            anchors.centerIn: parent
                            text: "Finish"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(0)
                            color: finishBtn.item
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.close();
                                root.enrollAccepted();
                            }
                        }
                    }
                }
            }
        }
    }

    contentItem: Loader {
        sourceComponent: enrollContent
    }
}
