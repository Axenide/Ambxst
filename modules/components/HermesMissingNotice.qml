import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.modules.theme
import qs.modules.services
import qs.config

// Shown wherever the Hermes backend is selected but no binary was found.
// Visibility is the caller's decision: during the check this stays hidden.
StyledRect {
    id: root

    property bool compact: false

    readonly property string website: "https://hermes-agent.nousresearch.com"

    variant: "internalbg"
    radius: Styling.radius(4)
    implicitHeight: noticeColumn.implicitHeight + (compact ? 20 : 28)
    implicitWidth: noticeColumn.implicitWidth

    ColumnLayout {
        id: noticeColumn
        anchors.fill: parent
        anchors.margins: compact ? 10 : 14
        spacing: compact ? 6 : 10

        Text {
            Layout.fillWidth: true
            text: I18n.t("ai.hermes_missing")
            color: Colors.overSurface
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(0)
            font.weight: Font.Medium
            wrapMode: Text.WordWrap
        }

        Text {
            Layout.fillWidth: true
            visible: !root.compact
            text: I18n.t("ai.hermes_missing_hint")
            color: Colors.overSurfaceVariant
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Button {
                id: getButton
                text: I18n.t("ai.hermes_get")
                leftPadding: 10
                rightPadding: 10
                topPadding: 5
                bottomPadding: 5

                background: StyledRect {
                    variant: getButton.down ? "overprimary" : (getButton.hovered ? "primaryfocus" : "primary")
                    radius: Styling.radius(4)
                }

                contentItem: Text {
                    text: getButton.text
                    color: Colors.overPrimary
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: Quickshell.execDetached(["xdg-open", root.website])
            }

            Button {
                id: checkButton
                text: I18n.t("ai.hermes_check_again")
                leftPadding: 10
                rightPadding: 10
                topPadding: 5
                bottomPadding: 5

                background: StyledRect {
                    variant: checkButton.down ? "focus" : (checkButton.hovered ? "common" : "internalbg")
                    radius: Styling.radius(4)
                }

                contentItem: Text {
                    text: checkButton.text
                    color: Colors.overSurface
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: Ai.checkHermes(true)
            }
        }
    }
}
