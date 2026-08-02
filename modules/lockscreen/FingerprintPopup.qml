pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.modules.components
import qs.modules.theme
import qs.modules.globals
import qs.config

// Floating fingerprint-scan indicator, shown by FprintdInterceptor while an
// external app (polkit, sudo, …) runs a fprintd verification. A standalone
// PanelWindow (like the OSD) so it can be created and driven from a service
// singleton — the old `Popup` variant could never be displayed that way and
// the interceptor's `typeof FingerprintPopup` check silently no-opped.
PanelWindow {
    id: root

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "ambxst+:fprint"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    // No anchors: wlr-layershell centers unattached windows on the monitor.
    color: "transparent"

    width: 360
    height: 260

    property bool scanning: false
    property bool showError: false
    property string errorMessage: ""
    property string title: "Fingerprint Authentication"
    property string message: "Place your finger on the sensor"

    signal scanAccepted()
    signal scanRejected()

    // Window visibility: shown while a scan is in progress or an error is
    // being displayed; keep the fade-out visible until the opacity anim ends.
    property bool popupVisible: false
    visible: popupVisible || bgRect.opacity > 0

    function open() {
        scanning = false;
        showError = false;
        popupVisible = true;
    }

    function close() {
        popupVisible = false;
        scanning = false;
        showError = false;
    }

    function startScanning() {
        scanning = true;
        showError = false;
    }

    function setError(error) {
        showError = true;
        errorMessage = error;
        scanning = false;
    }

    function setSuccess() {
        scanning = false;
    }

    function reset() {
        scanning = false;
        showError = false;
        errorMessage = "";
    }

    StyledRect {
        id: bgRect
        variant: "popup"
        anchors.centerIn: parent
        implicitWidth: 360
        implicitHeight: 260
        radius: Styling.radius(8)

        opacity: root.popupVisible ? 1 : 0
        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Styling.animEasing
            }
        }

        scale: root.popupVisible ? 1 : 0.9
        Behavior on scale {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Styling.animEasing
            }
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
                    font.pixelSize: Styling.fontSize(34)
                    color: root.showError ? Colors.error : Colors.primary
                    visible: !root.scanning
                }
            }

            Text {
                text: root.title
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(2)
                font.bold: true
                color: Colors.overBackground
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
            }

            Text {
                text: root.showError ? root.errorMessage : root.message
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(0)
                color: root.showError ? Colors.error : Colors.overSurfaceVariant
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
                wrapMode: Text.Wrap
            }
        }
    }
}
