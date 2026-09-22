pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.config
import qs.modules.components
import qs.modules.services
import qs.modules.theme

RowLayout {
    id: root
    required property var mod
    property bool canEnable: false
    property bool compact: false
    readonly property bool working: ModsService.busy || (ModsService.updates?.busy ?? false)
    signal enableRequested(var trigger)
    signal removeRequested(var trigger)
    spacing: 0

    component IconAction: Button {
        id: action
        required property string glyph
        property bool destructive: false
        readonly property string surface: hovered || down || activeFocus
            ? (destructive ? "error" : "secondary") : "focus"
        implicitWidth: Math.max(44, Styling.fontSize(28))
        implicitHeight: implicitWidth
        padding: root.compact ? 8 : 4
        enabled: !root.working
        opacity: enabled ? 1 : 0.45
        Accessible.name: text + ": " + (root.mod?.name ?? "")
        StyledToolTip {
            show: action.hovered || action.activeFocus
            tooltipText: action.text
            delay: 500
        }
        background: Item {
            StyledRect {
                anchors.fill: parent
                anchors.margins: action.padding
                radius: width / 2
                variant: action.surface
                enableShadow: false
            }
        }
        contentItem: Text {
            text: action.glyph
            font.family: Icons.font
            font.pixelSize: Styling.fontSize(root.compact ? 1 : 4)
            color: action.destructive && !action.hovered && !action.activeFocus
                ? Colors.error : Styling.srItem(action.surface)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            Accessible.ignored: true
        }
    }

    IconAction {
        text: I18n.t(root.mod?.enabled ? "mods.disable" : "mods.enable")
        glyph: root.mod?.enabled ? Icons.pause : Icons.play
        enabled: !root.working && (!!root.mod?.enabled || root.canEnable)
        onClicked: {
            if (root.mod.enabled)
                ModsService.setEnabled(root.mod.id, false);
            else
                root.enableRequested(this);
        }
    }
    IconAction {
        text: I18n.t("mods.remove")
        glyph: Icons.trash
        destructive: true
        onClicked: root.removeRequested(this)
    }
}
