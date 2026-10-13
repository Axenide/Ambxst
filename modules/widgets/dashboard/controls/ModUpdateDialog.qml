pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.config
import qs.modules.components
import qs.modules.services
import qs.modules.theme

Popup {
    id: root
    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(560, parent ? parent.width - 32 : 560)
    height: Math.min(content.implicitHeight + 32, parent ? parent.height - 32 : 600)
    padding: 16
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape
    property string modId: ""
    property string planId: ""
    property var trigger: null
    readonly property var item: (ModsService.updates?.items ?? []).find(candidate => candidate.id === root.modId) ?? null
    readonly property bool working: ModsService.busy || (ModsService.updates?.busy ?? false)
    readonly property bool ready: planId !== "" && planId === ModsService.updates?.planId
        && !!ModsService.updates?.canApply && item?.state === "available"
        && (ModsService.updates?.items ?? []).filter(candidate => candidate.state === "available").length === 1

    function capturePlan() {
        if (root.visible && root.item?.state === "available" && ModsService.updates?.canApply
                && (ModsService.updates?.items ?? []).filter(candidate => candidate.state === "available").length === 1)
            root.planId = ModsService.updates.planId;
    }

    function review(id, button) {
        if (root.working)
            return;
        root.modId = id;
        root.planId = "";
        root.trigger = button;
        ModsService.errorMessage = "";
        ModsService.errorDetails = "";
        root.open();
        root.capturePlan();
        if (root.planId === "")
            ModsService.checkUpdates([id], () => root.capturePlan());
    }

    onOpened: cancelButton.forceActiveFocus()
    onClosed: {
        root.planId = "";
        if (root.trigger)
            root.trigger.forceActiveFocus();
        root.trigger = null;
    }
    background: StyledRect { variant: "popup"; radius: Styling.radius(1) }

    component Label: Text {
        Layout.fillWidth: true
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-1)
        color: Colors.overBackground
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
    }
    component Action: Button {
        id: action
        property bool primary: false
        readonly property string surface: hovered || down || activeFocus ? "secondary" : primary ? "primary" : "focus"
        implicitHeight: 36
        leftPadding: 12
        rightPadding: 12
        opacity: enabled ? 1 : 0.45
        Accessible.name: text
        background: StyledRect { variant: action.surface; radius: Styling.radius(-2); enableShadow: false }
        contentItem: Text {
            text: action.text
            color: Styling.srItem(action.surface)
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    contentItem: ColumnLayout {
        id: content
        spacing: 12
        Label {
            text: I18n.t("mods.update_mod_title", (ModsService.mods ?? []).find(mod => mod.id === root.modId)?.name ?? root.modId)
            font.pixelSize: Styling.fontSize(2)
            font.weight: Font.DemiBold
        }
        Label {
            text: root.working ? I18n.t("mods.working") : root.ready
                ? (root.item.fromVersion === root.item.toVersion
                    ? root.item.toVersion + " · " + I18n.t("mods.revision_update_short")
                    : root.item.fromVersion + " → " + root.item.toVersion)
                : I18n.t("mods.update_phase_" + (ModsService.updates?.phase || "current"))
            color: Colors.outline
        }
        ScrollView {
            id: reviewScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: Math.min(reviewContent.implicitHeight, 340)
            clip: true
            contentWidth: availableWidth
            ColumnLayout {
                id: reviewContent
                width: reviewScroll.availableWidth
                spacing: 12
                Label {
                    visible: root.ready
                    text: I18n.t("mods.single_update_notice")
                }
                Label {
                    visible: root.ready && (root.item?.reviewReasons ?? []).length > 0
                    text: (root.item?.reviewReasons ?? []).map(reason => I18n.t("mods.review_" + reason)).join("\n")
                    color: Colors.warning
                }
                Label {
                    visible: root.ready && !!root.item?.deprecated
                    text: root.item?.deprecatedReason ?? ""
                    color: Colors.warning
                }
                Label {
                    visible: root.ready
                    text: I18n.t("mods.whats_new")
                    font.weight: Font.DemiBold
                }
                Label {
                    visible: root.ready
                    text: root.item?.changelog || I18n.t("mods.changelog_missing")
                }
                Label {
                    visible: root.ready && (root.item?.permissions ?? []).length > 0
                    text: I18n.t("mods.permissions") + ":\n" + (root.item?.permissions ?? []).join("\n")
                }
                Label {
                    visible: root.ready && (root.item?.commands ?? []).length > 0
                    text: I18n.t("mods.requirements") + ": " + (root.item?.commands ?? []).join(", ")
                }
                Label {
                    visible: root.ready && (root.item?.dependencies ?? []).length > 0
                    text: I18n.t("mods.required_mods") + ": " + (root.item?.dependencies ?? []).join(", ")
                }
                Label {
                    visible: root.ready && (root.item?.files ?? []).length > 0
                    text: I18n.t("mods.affected_files") + ":\n" + (root.item?.files ?? []).join("\n")
                    wrapMode: Text.WrapAnywhere
                    color: Colors.outline
                }
                Label {
                    visible: !root.working && (!root.ready || ModsService.errorDetails !== "")
                    text: ModsService.errorDetails || root.item?.details || ModsService.updates?.details || I18n.t("mods.check_again_notice")
                    color: Colors.warning
                }
            }
        }
        Label {
            visible: root.ready
            text: I18n.t(ModsService.restartRequired ? "mods.restart_before_update" : "mods.update_restart_notice")
            color: Colors.outline
            font.pixelSize: Styling.fontSize(-2)
        }
        Flow {
            Layout.fillWidth: true
            spacing: 8
            Action {
                id: cancelButton
                text: I18n.t("common.cancel")
                onClicked: root.close()
            }
            Action {
                text: I18n.t(root.working ? "mods.working" : "mods.update")
                primary: true
                enabled: root.ready && !root.working && !ModsService.restartRequired
                onClicked: ModsService.applyUpdates(root.planId, () => root.close())
            }
        }
    }
}
