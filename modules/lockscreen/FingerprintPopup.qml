import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.modules.components
import qs.modules.theme
import qs.modules.globals
import qs.config

Popup {
    id: root

    property bool scanning: false
    property bool showProgress: false
    property real progress: 0
    property bool showError: false
    property string errorMessage: ""
    property string title: "Fingerprint Authentication"
    property string message: "Place your finger on the sensor"

    signal scanAccepted()
    signal scanRejected()

    width: 380
    height: 280
    visible: false
    modal: true
    closePolicy: Popup.NoAutoKeys
    background: null
    padding: 0
    topMargin: 0
    bottomMargin: 0
    leftMargin: 0
    rightMargin: 0

    function open() {
        scanning = false;
        showError = false;
        progress = 0;
        Popup.open();
    }

    function close() {
        Popup.close();
    }

    function startScanning() {
        scanning = true;
        showError = false;
        progress = 0;
    }

    function setProgress(value) {
        progress = value;
    }

    function setError(error) {
        showError = true;
        errorMessage = error;
        scanning = false;
        progress = 0;
    }

    function setSuccess() {
        scanning = false;
        progress = 1;
    }

    function reset() {
        scanning = false;
        showError = false;
        progress = 0;
        errorMessage = "";
    }

    Component {
        id: fingerprintContent

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
                    spacing: 16

                    Item {
                        width: 80
                        height: 80
                        anchors.horizontalCenter: parent.horizontalCenter

                        BusyIndicator {
                            id: fingerprintSpinner
                            anchors.centerIn: parent
                            width: 64
                            height: 64
                            running: root.scanning
                            visible: root.scanning
                            implicitWidth: 64
                            implicitHeight: 64
                        }

                        Text {
                            id: fingerprintIcon
                            anchors.centerIn: parent
                            text: root.showError ? Icons.warning : Icons.fingerprint
                            font.family: Icons.font
                            font.pixelSize: 48
                            color: root.showError ? Colors.error : Colors.primary
                            visible: !root.scanning
                        }

                        NumberAnimation on opacity {
                            from: 0; to: 1
                            duration: Config.animDuration
                            easing.type: Easing.OutCubic
                        }
                    }

                    Text {
                        text: root.title
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(2)
                        font.bold: true
                        color: Colors.onSurface
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width
                        visible: !root.showError
                    }

                    Text {
                        text: root.showError ? root.errorMessage : root.message
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(0)
                        color: root.showError ? Colors.error : Colors.onSurfaceDim
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width
                        wrapMode: Text.Wrap
                        visible: !root.scanning
                    }

                    Rectangle {
                        width: parent.width
                        height: 4
                        color: Colors.outline
                        radius: 2
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 0
                        clip: true

                        Rectangle {
                            width: root.progress * parent.width
                            height: parent.height
                            color: root.showError ? Colors.error : Colors.primary
                            radius: 2
                            Behavior on width {
                                enabled: Config.animDuration > 0
                                NumberAnimation {
                                    duration: Config.animDuration
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        visible: root.scanning
                    }

                    Text {
                        text: "Cancel"
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(0)
                        color: Colors.primary
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.scanRejected()
                        }
                        visible: !root.showError
                    }
                }
            }
        }
    }

    contentItem: Loader {
        sourceComponent: fingerprintContent
    }
}
