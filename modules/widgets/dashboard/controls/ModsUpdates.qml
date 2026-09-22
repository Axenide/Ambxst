pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.modules.components
import qs.modules.services
import qs.modules.theme

StyledRect {
    id: root
    implicitHeight: content.implicitHeight + 32
    variant: "common"
    radius: Styling.radius(-2)
    enableShadow: false
    property bool expanded: false
    property bool diagnosticsVisible: false
    property bool toolsVisible: false
    readonly property var updates: ModsService.updates
    readonly property var changedItems: (updates?.items ?? []).filter(item => item.state !== "current")
    readonly property int currentCount: (updates?.items ?? []).filter(item => item.state === "current").length
    readonly property bool working: ModsService.busy || (updates?.busy ?? false)

    component Label: Text {
        Layout.fillWidth: true
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-2)
        color: Colors.overBackground
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
    }

    component Action: Button {
        id: action
        property bool primary: false
        implicitHeight: 34
        leftPadding: 12
        rightPadding: 12
        enabled: !root.working
        opacity: enabled ? 1 : 0.45
        Accessible.name: text
        readonly property string surface: primary ? "primary" : hovered || activeFocus ? "secondary" : "focus"
        background: StyledRect {
            variant: action.surface
            radius: Styling.radius(-2)
            enableShadow: false
        }
        contentItem: Text {
            text: action.text
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            color: Styling.srItem(action.surface)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 16
        spacing: 12

        Label {
            text: I18n.t("mods.updates_title")
            font.pixelSize: Styling.fontSize(1)
            font.weight: Font.DemiBold
        }
        RowLayout {
            Layout.fillWidth: true
            Label {
                text: I18n.t("mods.auto_updates")
                font.weight: Font.DemiBold
                font.pixelSize: Styling.fontSize(-1)
            }
            Action {
                text: I18n.t(ModsService.autoUpdate ? "common.on" : "common.off")
                primary: ModsService.autoUpdate
                Accessible.description: I18n.t("mods.auto_updates_description")
                onClicked: ModsService.setUpdatePolicy("", ModsService.autoUpdate ? "off" : "on")
            }
        }
        Label {
            text: I18n.t("mods.auto_updates_description")
            color: Colors.outline
        }
        Label {
            text: I18n.t("mods.check_frequency")
            font.weight: Font.Medium
        }
        Flow {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: [1, 6, 24, 168]
                delegate: Action {
                    required property int modelData
                    text: I18n.t("mods.interval_" + modelData)
                    primary: ModsService.updateIntervalHours === modelData
                    onClicked: ModsService.setUpdateInterval(modelData)
                }
            }
        }
        Label {
            text: I18n.t("mods.check_frequency_description")
            color: Colors.outline
        }
        Separator { Layout.fillWidth: true; Layout.topMargin: 4; Layout.bottomMargin: 4 }
        Flow {
            Layout.fillWidth: true
            spacing: 6
            Action {
                text: I18n.t(root.working ? "mods.working" : "mods.check_updates")
                onClicked: ModsService.checkUpdates()
            }
            Action {
                visible: (root.updates?.items ?? []).length > 0
                text: I18n.t(root.expanded ? "mods.hide_preview" : "mods.review_updates")
                enabled: true
                onClicked: root.expanded = !root.expanded
            }
            Action {
                text: I18n.t("mods.diagnostics")
                onClicked: {
                    ModsService.diagnosticText = "";
                    root.diagnosticsVisible = true;
                    ModsService.loadDiagnostics();
                }
            }
            Action {
                text: I18n.t("mods.recovery_tools")
                enabled: true
                onClicked: root.toolsVisible = !root.toolsVisible
            }
        }
        Label {
            visible: (root.updates?.phase ?? "") !== ""
            text: I18n.t("mods.update_phase_" + (root.updates?.phase ?? "current"))
            color: root.updates?.phase === "failed" ? Colors.error : Colors.overBackground
        }
        Label {
            visible: (root.updates?.lastAttempt ?? "") !== ""
            text: I18n.t("mods.last_check", Qt.formatDateTime(new Date(root.updates?.lastAttempt ?? ""), "dd.MM.yyyy HH:mm"))
            color: Colors.outline
        }
        Label {
            visible: (root.updates?.details ?? "") !== ""
            text: I18n.t("mods.technical_details", root.updates?.details ?? "")
            color: Colors.error
            wrapMode: Text.WrapAnywhere
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.expanded
            spacing: 16
            Label {
                text: I18n.t("mods.update_summary", root.changedItems.length, root.currentCount)
                font.weight: Font.DemiBold
            }
            Label {
                text: I18n.t("mods.preview_description")
                color: Colors.outline
            }
            Repeater {
                model: root.changedItems
                delegate: ColumnLayout {
                    required property var modelData
                    property bool notesExpanded: false
                    property bool detailsExpanded: false
                    Layout.fillWidth: true
                    spacing: 10
                    Layout.topMargin: 8
                    Layout.bottomMargin: 8
                    Label {
                        text: ((ModsService.mods ?? []).find(mod => mod.id === modelData.id)?.name ?? modelData.id)
                            + " · " + (modelData.fromVersion || "?")
                            + (modelData.toVersion && modelData.toVersion !== modelData.fromVersion ? " → " + modelData.toVersion : "")
                            + " · " + I18n.t("mods.update_item_" + modelData.state)
                        font.weight: Font.DemiBold
                    }
                    Label {
                        visible: modelData.state === "available" && modelData.toVersion === modelData.fromVersion
                        text: I18n.t("mods.revision_update")
                        color: Colors.outline
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 8
                        Action {
                            visible: modelData.state === "available" || modelData.state === "updated"
                            text: I18n.t(notesExpanded ? "mods.hide_changelog" : "mods.whats_new")
                            enabled: true
                            onClicked: notesExpanded = !notesExpanded
                        }

                        Action {
                            text: I18n.t(detailsExpanded ? "mods.hide_preview" : "mods.package_details")
                            enabled: true
                            onClicked: detailsExpanded = !detailsExpanded
                        }
                    }
                    Label {
                        visible: notesExpanded
                        text: modelData.changelog ? I18n.t("mods.changelog_source", modelData.changelogFile)
                            : I18n.t("mods.changelog_missing")
                        color: Colors.outline
                    }
                    ScrollView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(changelogText.implicitHeight, 240)
                        visible: notesExpanded && (modelData.changelog ?? "") !== ""
                        clip: true
                        contentWidth: availableWidth
                        TextArea {
                            id: changelogText
                            width: parent.width
                            readOnly: true
                            selectByMouse: true
                            textFormat: TextEdit.PlainText
                            wrapMode: TextEdit.Wrap
                            text: modelData.changelog ?? ""
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            color: Colors.overBackground
                            Accessible.name: I18n.t("mods.whats_new")
                            background: StyledRect { variant: "internalbg"; radius: Styling.radius(-2) }
                        }
                    }
                    Label {
                        visible: detailsExpanded && (modelData.revision ?? "") !== ""
                        text: I18n.t("mods.revision") + ": "
                            + (modelData.fromRevision && modelData.fromRevision !== modelData.revision
                                ? modelData.fromRevision.substring(0, 12) + " → " : "")
                            + (modelData.revision ?? "").substring(0, 12)
                    }
                    Label {
                        visible: (modelData.reviewReasons ?? []).length > 0
                        text: (modelData.reviewReasons ?? []).map(reason => I18n.t("mods.review_" + reason)).join("\n")
                        color: Colors.warning
                    }
                    Label {
                        visible: !!modelData.deprecated && (modelData.deprecatedReason ?? "") !== ""
                        text: modelData.deprecatedReason ?? ""
                        color: Colors.warning
                    }
                    Label {
                        visible: detailsExpanded && (modelData.dependencies ?? []).length > 0
                        text: I18n.t("mods.required_mods") + ": " + (modelData.dependencies ?? []).join(", ")
                    }
                    Label {
                        visible: detailsExpanded && (modelData.permissions ?? []).length > 0
                        text: I18n.t("mods.permissions") + ": " + (modelData.permissions ?? []).join(", ")
                    }
                    Label {
                        visible: detailsExpanded && Object.keys(modelData.dependencySources ?? {}).length > 0
                        text: Object.entries(modelData.dependencySources ?? {}).map(pair => pair[0] + ": " + pair[1]).join("\n")
                        wrapMode: Text.WrapAnywhere
                    }
                    Label {
                        visible: detailsExpanded && (modelData.commands ?? []).length > 0
                        text: I18n.t("mods.requirements") + ": " + (modelData.commands ?? []).join(", ")
                    }
                    Label {
                        visible: detailsExpanded && (modelData.files ?? []).length > 0
                        text: I18n.t("mods.affected_files") + ": " + (modelData.files ?? []).join("\n")
                        wrapMode: Text.WrapAnywhere
                        color: Colors.outline
                    }
                    Label {
                        visible: (modelData.errorCode ?? "") !== ""
                        text: I18n.t("mods.error_" + (modelData.errorCode ?? "invalid_package"))
                        color: Colors.error
                    }
                    Label {
                        visible: detailsExpanded && (modelData.details ?? "") !== ""
                        text: I18n.t("mods.technical_details", modelData.details ?? "")
                        color: Colors.error
                        wrapMode: Text.WrapAnywhere
                    }
                    Separator { Layout.fillWidth: true; Layout.topMargin: 6 }
                }
            }
            Label {
                visible: root.updates?.restartRequired ?? false
                text: I18n.t("mods.update_restart_notice")
            }
            Flow {
                Layout.fillWidth: true
                spacing: 8
                Action {
                    visible: root.updates?.canApply ?? false
                    text: I18n.t("mods.apply_updates")
                    primary: true
                    enabled: !root.working && !ModsService.restartRequired
                    onClicked: ModsService.applyUpdates()
                }
                Action {
                    visible: root.updates?.canApply ?? false
                    text: I18n.t("mods.dismiss_updates")
                    onClicked: ModsService.discardUpdates()
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.diagnosticsVisible
            Label { text: I18n.t("mods.diagnostics_description") }
            ScrollView {
                Layout.fillWidth: true
                Layout.preferredHeight: 180
                TextArea {
                    id: diagnosticPreview
                    text: ModsService.diagnosticText
                    readOnly: true
                    selectByMouse: true
                    font.family: Config.theme.monoFont
                    font.pixelSize: Styling.fontSize(-2)
                    color: Colors.overBackground
                    wrapMode: TextEdit.WrapAnywhere
                    Accessible.name: I18n.t("mods.diagnostics")
                    background: StyledRect { variant: "internalbg"; enableShadow: false }
                }
            }
            Flow {
                Layout.fillWidth: true
                spacing: 6
                Action {
                    text: I18n.t("mods.copy_report")
                    enabled: ModsService.diagnosticText !== ""
                    onClicked: {
                        diagnosticPreview.selectAll();
                        diagnosticPreview.copy();
                        diagnosticPreview.deselect();
                    }
                }
                Action {
                    text: I18n.t("mods.hide_preview")
                    enabled: true
                    onClicked: root.diagnosticsVisible = false
                }
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: 6
            visible: root.toolsVisible
            Action {
                text: I18n.t("mods.check_compatibility")
                onClicked: ModsService.checkCompatibility(candidatePath.text.trim())
            }
            Action {
                text: I18n.t("mods.recovery_base")
                onClicked: ModsService.setModsEnabled(false)
            }
            Action {
                visible: ModsService.previousGeneration !== "" || root.updates?.phase === "applied"
                text: I18n.t("mods.rollback")
                onClicked: ModsService.rollback()
            }
        }
        TextField {
            id: candidatePath
            visible: root.toolsVisible
            Layout.fillWidth: true
            placeholderText: I18n.t("mods.candidate_path")
            Accessible.name: placeholderText
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            color: Colors.overBackground
            selectByMouse: true
            background: StyledRect { variant: "internalbg"; enableShadow: false }
        }
        Label {
            visible: root.toolsVisible && ModsService.compatibilityReport !== null
            text: I18n.t(ModsService.compatibilityReport?.composes ? "mods.compatibility_passed" : "mods.compatibility_failed")
                + (ModsService.compatibilityReport?.details ? "\n" + ModsService.compatibilityReport.details : "")
            color: ModsService.compatibilityReport?.composes ? Colors.overBackground : Colors.error
        }
    }
    Connections {
        target: ModsService
        function onUpdatesChanged() {
            if (ModsService.updates?.canApply || ModsService.updates?.phase === "failed") root.expanded = true;
        }
    }
}
