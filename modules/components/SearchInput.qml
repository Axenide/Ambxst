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
    property bool clearOnEscape: true
    
    signal searchTextChanged(string text)
    signal accepted()
    signal escapePressed()
    signal downPressed()
    signal upPressed()
    signal pageDownPressed()
    signal pageUpPressed()
    signal homePressed()
    signal endPressed()

    function focusInput() {
        textField.forceActiveFocus()
    }

    function clear() {
        textField.text = ""
    }

    implicitHeight: 48
    radius: Config.roundness > 0 ? Config.roundness + 4 : 0

    RowLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Text {
            text: root.iconText
            font.family: Styling.defaultFont
            font.pixelSize: 20
            color: Colors.adapter.primary
            visible: root.iconText.length > 0
        }

        TextField {
            id: textField
            Layout.fillWidth: true
            placeholderTextColor: Colors.adapter.outline
            font.family: Styling.defaultFont
            font.pixelSize: 14
            color: Colors.adapter.overBackground
            background: null

            onTextChanged: {
                root.searchTextChanged(text)
            }

            onAccepted: {
                root.accepted()
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    if (root.clearOnEscape) {
                        clear()
                    }
                    root.escapePressed()
                    event.accepted = true
                } else if (event.key === Qt.Key_Down) {
                    root.downPressed()
                    event.accepted = true
                } else if (event.key === Qt.Key_Up) {
                    root.upPressed()
                    event.accepted = true
                } else if (event.key === Qt.Key_PageDown) {
                    root.pageDownPressed()
                    event.accepted = true
                } else if (event.key === Qt.Key_PageUp) {
                    root.pageUpPressed()
                    event.accepted = true
                } else if (event.key === Qt.Key_Home) {
                    root.homePressed()
                    event.accepted = true
                } else if (event.key === Qt.Key_End) {
                    root.endPressed()
                    event.accepted = true
                }
            }
        }
    }
}