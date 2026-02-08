pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.modules.globals
import qs.config

Scope {
    id: root

    property bool pinned: Config.dock?.pinnedOnStartup ?? false

    Variants {
        model: [] // Disabled to prevent double dock windows (using UnifiedShellPanel)
        /*
        model: {
            const screens = Quickshell.screens;
            const list = Config.dock?.screenList ?? [];
            if (!list || list.length === 0)
                return screens;
            return screens.filter(screen => list.includes(screen.name));
        }
        */

        PanelWindow {
            id: dockWindow

            required property ShellScreen modelData
            screen: modelData

            readonly property alias reveal: dockContent.reveal

            anchors {
                bottom: dockContent.isBottom
                left: dockContent.isLeft
                right: dockContent.isRight
            }

            exclusiveZone: (root.pinned && dockContent.barPinned && !dockContent.activeWindowFullscreen) ? dockContent.dockSize + dockContent.totalMargin : 0

            implicitWidth: dockContent.implicitWidth
            implicitHeight: dockContent.implicitHeight

            WlrLayershell.namespace: "ambxst:dock"
            WlrLayershell.layer: WlrLayer.Overlay
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore

            mask: Region {
                item: dockContent.dockHitbox
            }

            DockContent {
                id: dockContent
                anchors.fill: parent
                screen: dockWindow.screen
                pinned: root.pinned
            }
        }
    }
}
