import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.config

PaneRect {
    id: root

    property alias text: textField.text
    property alias placeholderText: textField.placeholderText
    property string iconText: ""
    property string prefixText: ""  // Prefix indicator (e.g., "clip ")
    property bool clearOnEscape: true
    property bool handleTabNavigation: false  // Si true, captura Tab y emite señales. Si false, usa navegación normal.
    property bool passwordMode: false  // Si true, muestra círculos en lugar del texto
    property bool centerText: false  // Si true, centra el texto horizontalmente

    signal searchTextChanged(string text)
    signal accepted
    signal shiftAccepted
    signal backspaceOnEmpty  // Signal when backspace is pressed on empty text
    signal tabPressed
    signal shiftTabPressed
    signal ctrlRPressed
    signal ctrlPPressed
    signal ctrlUpPressed
    signal ctrlDownPressed
    signal escapePressed
    signal downPressed
    signal upPressed
    signal leftPressed
    signal rightPressed
    signal pageDownPressed
    signal pageUpPressed
    signal homePressed
    signal endPressed

    function focusInput() {
        textField.forceActiveFocus();
    }

    function clear() {
        textField.text = "";
    }

    implicitHeight: 48
    radius: Config.roundness > 0 ? Config.roundness + 4 : 0

    RowLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Text {
            text: root.iconText
            font.family: Config.theme.font
            font.pixelSize: 20
            color: Colors.primary
            visible: root.iconText.length > 0
        }

        // Prefix indicator
        Rectangle {
            Layout.preferredWidth: prefixLabel.implicitWidth + 16
            Layout.preferredHeight: 32
            radius: Config.roundness > 0 ? Math.max(Config.roundness - 4, 0) : 0
            color: Colors.primary
            visible: root.prefixText.length > 0

            Text {
                id: prefixLabel
                anchors.centerIn: parent
                text: root.prefixText.trim()
                font.family: Config.theme.font
                font.pixelSize: Config.theme.fontSize - 1
                font.weight: Font.Bold
                color: Colors.overPrimary
            }
        }

        TextField {
            id: textField
            Layout.fillWidth: true
            placeholderTextColor: Colors.outline
            font.family: Config.theme.font
            font.pixelSize: Config.theme.fontSize
            color: Colors.overBackground
            background: null
            echoMode: root.passwordMode ? TextInput.Password : TextInput.Normal
            horizontalAlignment: root.centerText ? TextInput.AlignHCenter : TextInput.AlignLeft

            onTextChanged: {
                root.searchTextChanged(text);
            }

            onAccepted: {
                root.accepted();
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Backspace && textField.text.length === 0) {
                    root.backspaceOnEmpty();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Tab && root.handleTabNavigation) {
                    if (event.modifiers & Qt.ShiftModifier) {
                        root.shiftTabPressed();
                    } else {
                        root.tabPressed();
                    }
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (event.modifiers & Qt.ShiftModifier) {
                        root.shiftAccepted();
                    } else {
                        root.accepted();
                    }
                    event.accepted = true;
                } else if (event.key === Qt.Key_R && (event.modifiers & Qt.ControlModifier)) {
                    root.ctrlRPressed();
                    event.accepted = true;
                } else if (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier)) {
                    root.ctrlPPressed();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Up && (event.modifiers & Qt.ControlModifier)) {
                    root.ctrlUpPressed();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Down && (event.modifiers & Qt.ControlModifier)) {
                    root.ctrlDownPressed();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Escape) {
                    if (root.clearOnEscape) {
                        clear();
                    }
                    root.escapePressed();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Down) {
                    root.downPressed();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Up) {
                    root.upPressed();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Left) {
                    root.leftPressed();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Right) {
                    root.rightPressed();
                    event.accepted = true;
                } else if (event.key === Qt.Key_PageDown) {
                    root.pageDownPressed();
                    event.accepted = true;
                } else if (event.key === Qt.Key_PageUp) {
                    root.pageUpPressed();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Home) {
                    root.homePressed();
                    event.accepted = true;
                } else if (event.key === Qt.Key_End) {
                    root.endPressed();
                    event.accepted = true;
                }
            }
        }
    }
}
