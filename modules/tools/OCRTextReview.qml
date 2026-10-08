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
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property bool copying: false
    property real offsetX: 0
    property real offsetY: 0

    // Match the other movable overlays: only the pane receives input,
    // except while dragging so the pointer can follow across the screen.
    mask: Region {
        item: headerDrag.pressed ? dragRegion : reviewPane
    }

    Item {
        id: dragRegion
        anchors.fill: parent
    }

    function moveReview(x, y) {
        offsetX = Math.max(0, Math.min(x, root.width - reviewPane.width)) - (root.width - reviewPane.width) / 2;
        offsetY = Math.max(0, Math.min(y, root.height - reviewPane.height)) - (root.height - reviewPane.height) / 2;
    }

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
        id: reviewPane
        objectName: "ocrReviewPane"
        width: Math.max(0, Math.min(720, root.width - 32))
        height: Math.max(0, Math.min(480, root.height - 32))
        x: Math.max(0, Math.min((root.width - width) / 2 + root.offsetX, root.width - width))
        y: Math.max(0, Math.min((root.height - height) / 2 + root.offsetY, root.height - height))
        variant: "popup"
        radius: Styling.radius(4)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            Item {
                Layout.fillWidth: true
                implicitHeight: Math.max(32, titleText.implicitHeight)

                Text {
                    id: titleText
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t("screenshot.ocr_result")
                    font.family: Styling.defaultFont
                    font.pixelSize: Styling.fontSize(2)
                    font.bold: true
                    color: Colors.overBackground
                }
                MouseArea {
                    id: headerDrag
                    objectName: "ocrReviewHeader"
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    preventStealing: true
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    property point startPoint: Qt.point(0, 0)
                    property point startPosition: Qt.point(0, 0)

                    onPressed: mouse => {
                        startPoint = mapToItem(null, mouse.x, mouse.y);
                        startPosition = Qt.point(reviewPane.x, reviewPane.y);
                    }
                    onPositionChanged: mouse => {
                        if (!pressed) return;
                        var point = mapToItem(null, mouse.x, mouse.y);
                        root.moveReview(startPosition.x + point.x - startPoint.x,
                                        startPosition.y + point.y - startPoint.y);
                    }
                }
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
