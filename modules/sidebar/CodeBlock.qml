import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.modules.theme
import qs.config
import qs.modules.components
import org.kde.syntaxhighlighting

ColumnLayout {
    id: root
    property string code: ""
    property string language: "txt"
    property alias implicitWidth: root.width

    spacing: 0

    // Repository { id: highlightRepo }

    // Header
    StyledRect {
        Layout.fillWidth: true
        Layout.preferredHeight: 32
        variant: "surface"
        topLeftRadius: Styling.radius(4)
        topRightRadius: Styling.radius(4)
        bottomLeftRadius: 0
        bottomRightRadius: 0

        // Flatten bottom corners to join with code area
        // Note: StyledRect doesn't support individual corner radius easily via variant.
        // We rely on visual stacking.

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 8
            spacing: 8

            Text {
                text: root.language || "text"
                color: Colors.outline
                font.family: Config.theme.font
                font.pixelSize: 12
                font.weight: Font.Bold
            }

            Item {
                Layout.fillWidth: true
            }

            Button {
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                flat: true
                padding: 0

                contentItem: Text {
                    text: Icons.copy
                    font.family: Icons.font
                    color: parent.hovered ? Styling.srItem("overprimary") : Colors.outline
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: null

                onClicked: {
                    let p = Qt.createQmlObject('import Quickshell; import Quickshell.Io; Process { command: ["wl-copy", "' + root.code.replace(/"/g, '\\"') + '"] }', parent);
                    p.running = true;
                    // Optional: Show "Copied" feedback
                    copyFeedback.visible = true;
                    copyFeedbackTimer.restart();
                }

                Text {
                    id: copyFeedback
                    text: "Copied!"
                    font.family: Config.theme.font
                    font.pixelSize: 10
                    color: Colors.success
                    visible: false
                    anchors.right: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: 4

                    Timer {
                        id: copyFeedbackTimer
                        interval: 2000
                        onTriggered: copyFeedback.visible = false
                    }
                }
            }
        }
    }

    // Code Area
    StyledRect {
        Layout.fillWidth: true
        implicitHeight: codeText.contentHeight + 16
        variant: "internalbg"
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: Styling.radius(4)
        bottomRightRadius: Styling.radius(4)

        // Overlap slightly to hide top radius if needed, or just keep as separate blocks

        TextEdit {
            id: codeText
            anchors.fill: parent
            anchors.margins: 8
            text: root.code
            font.family: "Monospace"
            font.pixelSize: 13
            color: Colors.overSurface
            readOnly: true
            selectByMouse: true
            wrapMode: TextEdit.Wrap
            textFormat: TextEdit.PlainText

            SyntaxHighlighter {
                textEdit: codeText
                repository: Repository
                definition: Repository.definitionForName(root.language)
                theme: Repository.theme("Breeze Dark")
            }
        }
    }
}
