import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.modules.theme
import qs.modules.components
import qs.modules.services

PanelWindow {
    id: root
    required property var targetScreen
    screen: targetScreen
    implicitWidth: Math.min(720, targetScreen.width - 32)
    implicitHeight: Math.min(480, targetScreen.height - 32)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property bool copying: false

    function copySelection() {
        if (Screenshot.ocrReviewBusy || root.copying || editor.text === "") return;
        var text = (editor.selectedText || editor.text).replace(/\u2029/g, "\n");
        var request = Screenshot.ocrReviewRequest;
        root.copying = true;
        BackendService.call("ocr.copy", {text: text}, (result, error) => {
            root.copying = false;
            if (request !== Screenshot.ocrReviewRequest) return;
            if (error) {
                Screenshot.ocrReviewError = "" + error;
                return;
            }
            Screenshot.closeOCRReview();
        });
    }

    Shortcut {
        sequence: "Escape"
        onActivated: Screenshot.closeOCRReview()
    }
    Shortcut {
        sequence: "Ctrl+Return"
        onActivated: root.copySelection()
    }

    StyledRect {
        anchors.fill: parent
        variant: "popup"
        radius: Styling.radius(4)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            Text {
                text: I18n.t("screenshot.ocr_result")
                font.family: Styling.defaultFont
                font.pixelSize: Styling.fontSize(2)
                font.bold: true
                color: Colors.overBackground
            }
            Text {
                Layout.fillWidth: true
                text: Screenshot.ocrReviewBusy ? I18n.t("screenshot.recognizing_text") : I18n.t("screenshot.select_text")
                wrapMode: Text.WordWrap
                font.family: Styling.defaultFont
                font.pixelSize: Styling.fontSize(-1)
                color: Colors.overBackground
            }
            Text {
                Layout.fillWidth: true
                visible: Screenshot.ocrReviewError !== ""
                text: Screenshot.ocrReviewError
                wrapMode: Text.WordWrap
                font.family: Styling.defaultFont
                font.pixelSize: Styling.fontSize(0)
                color: Colors.error
            }
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                enabled: !Screenshot.ocrReviewBusy && !root.copying
                TextArea {
                    id: editor
                    text: Screenshot.ocrReviewText
                    textFormat: TextEdit.PlainText
                    wrapMode: TextEdit.Wrap
                    selectByMouse: true
                    persistentSelection: true
                    font.family: Styling.defaultFont
                    font.pixelSize: Styling.fontSize(0)
                    color: Colors.overBackground
                    selectionColor: Colors.primary
                    selectedTextColor: Colors.overPrimary
                    padding: 12
                    Accessible.name: I18n.t("screenshot.ocr_result")
                    background: StyledRect {
                        variant: "internalbg"
                        radius: Styling.radius(0)
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Item { Layout.fillWidth: true }
                ReviewButton {
                    text: I18n.t("common.cancel")
                    onClicked: Screenshot.closeOCRReview()
                }
                ReviewButton {
                    text: I18n.t(editor.selectedText ? "screenshot.copy_selection" : "screenshot.copy_all")
                    variant: "primary"
                    enabled: !Screenshot.ocrReviewBusy && !root.copying && editor.text !== ""
                    onClicked: root.copySelection()
                }
            }
        }
    }

    Connections {
        target: Screenshot
        function onOcrReviewBusyChanged() {
            if (!Screenshot.ocrReviewBusy && Screenshot.ocrReviewText !== "") {
                Qt.callLater(() => { editor.forceActiveFocus(); editor.selectAll(); });
            }
        }
    }
    Component.onCompleted: {
        if (!Screenshot.ocrReviewBusy && editor.text !== "") {
            editor.forceActiveFocus();
            editor.selectAll();
        }
    }

    component ReviewButton: Button {
        id: button
        property string variant: "common"
        implicitHeight: 40
        leftPadding: 16
        rightPadding: 16
        opacity: enabled ? 1 : 0.5
        contentItem: Text {
            text: button.text
            font.family: Styling.defaultFont
            font.pixelSize: Styling.fontSize(0)
            color: Styling.srItem(button.variant) || Colors.overBackground
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        background: StyledRect {
            variant: button.down || button.activeFocus || button.hovered ? "focus" : button.variant
            radius: Styling.radius(0)
        }
    }
}
