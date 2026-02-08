import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.modules.bar
import qs.modules.bar.workspaces
import qs.modules.notch
import qs.modules.dock
import qs.modules.frame
import qs.modules.services
import qs.modules.globals
import qs.modules.components
import qs.config

PanelWindow {
    id: unifiedPanel

    required property ShellScreen targetScreen
    screen: targetScreen

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"

    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "ambxst"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    
    // Compatibility properties for Visibilities and other components
    readonly property alias barPosition: barContent.barPosition
    readonly property alias barPinned: barContent.pinned
    readonly property alias barHoverActive: barContent.hoverActive
    readonly property alias barFullscreen: barContent.activeWindowFullscreen
    readonly property alias barReveal: barContent.reveal
    readonly property alias barTargetWidth: barContent.barTargetWidth
    readonly property alias barTargetHeight: barContent.barTargetHeight
    readonly property alias barOuterMargin: barContent.baseOuterMargin

    readonly property alias dockPosition: dockContent.position
    readonly property alias dockPinned: dockContent.pinned
    readonly property alias dockReveal: dockContent.reveal
    readonly property alias dockFullscreen: dockContent.activeWindowFullscreen
    readonly property int dockHeight: dockContent.dockSize + dockContent.totalMargin

    readonly property alias notchHoverActive: notchContent.hoverActive
    readonly property alias notchOpen: notchContent.screenNotchOpen
    readonly property alias notchReveal: notchContent.reveal
    readonly property real notchWidth: notchContent.notchContainerRef ? Math.max(
        notchContent.notchContainerRef.implicitWidth ?? 0,
        notchContent.notchContainerRef.width ?? 0,
        notchContent.notchRegionWidth ?? 0
    ) : 0
    readonly property real notchHitboxWidth: notchContent.notchHitbox ? Math.max(
        notchContent.notchHitbox.width ?? 0,
        notchWidth
    ) : notchWidth

    // Generic names for external compatibility (Visibilities expects these on the panel object)
    readonly property alias pinned: barContent.pinned
    readonly property alias reveal: barContent.reveal
    readonly property alias hoverActive: barContent.hoverActive // Default hoverActive points to bar
    readonly property alias notch_hoverActive: notchContent.hoverActive // Used by bar to check notch

    readonly property bool unifiedEffectActive: true // Flag to notify children to disable internal borders

    readonly property var hyprlandMonitor: Hyprland.monitorFor(targetScreen)
    readonly property bool hasFullscreenWindow: {
        if (!hyprlandMonitor) return false;
        
        const activeWorkspaceId = hyprlandMonitor.activeWorkspace.id;
        const monId = hyprlandMonitor.id;
        
        // Check active toplevel first (fast path)
        const toplevel = ToplevelManager.activeToplevel;
        if (toplevel && toplevel.fullscreen && Hyprland.focusedMonitor.id === monId) {
             return true;
        }

        // Check all windows on this monitor (robust path)
        const wins = HyprlandData.windowList;
        for (let i = 0; i < wins.length; i++) {
            if (wins[i].monitor === monId && wins[i].fullscreen && wins[i].workspace.id === activeWorkspaceId) {
                return true;
            }
        }
        return false;
    }

    // Proxy properties for Bar/Notch synchronization
    // Note: BarContent and NotchContent already handle their internal sync using Visibilities.
    
    // Helper properties for shadow logic
    readonly property bool keepBarShadow: Config.bar.keepBarShadow ?? false
    readonly property bool keepBarBorder: Config.bar.keepBarBorder ?? false
    readonly property bool containBar: Config.bar.containBar && (Config.bar.frameEnabled ?? false)

    Component.onCompleted: {
        Visibilities.registerBarPanel(screen.name, unifiedPanel);
        Visibilities.registerNotchPanel(screen.name, unifiedPanel);
        Visibilities.registerDockPanel(screen.name, dockContent);
        Visibilities.registerBar(screen.name, barContent);
        Visibilities.registerNotch(screen.name, notchContent.notchContainerRef);
        Visibilities.registerDock(screen.name, dockContent);
    }

    Component.onDestruction: {
        Visibilities.unregisterBarPanel(screen.name);
        Visibilities.unregisterNotchPanel(screen.name);
        Visibilities.unregisterDockPanel(screen.name);
        Visibilities.unregisterBar(screen.name);
        Visibilities.unregisterNotch(screen.name);
        Visibilities.unregisterDock(screen.name);
    }

    // Mask Region Logic
    // We use nested regions to define non-contiguous hit areas for each component.
    // This allows clicking through the empty space between the Bar, Notch, and Dock.
    mask: Region {
        regions: [
            Region {
                item: barContent.barHitbox
            },
            Region {
                item: notchContent.notchHitbox
            },
            Region {
                // Only include the dock hitbox if the dock is actually enabled and visible on this screen.
                item: dockContent.visible ? dockContent.dockHitbox : null
            }
        ]
    }

    // Focus Grab for Notch
    HyprlandFocusGrab {
        id: focusGrab
        windows: {
            let windowList = [unifiedPanel];
            // Optionally add other windows if needed, but since we are one window, this might be enough.
            return windowList;
        }
        active: notchContent.screenNotchOpen

        onCleared: {
            Visibilities.setActiveModule("");
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // VISUAL CONTENT (Unified Shadow & Border Wrapper)
    // ═══════════════════════════════════════════════════════════════

    Item {
        id: shadowMask
        anchors.fill: parent
        visible: false

        Rectangle {
            id: barCutout
            visible: unifiedPanel.containBar && !unifiedPanel.keepBarShadow
            color: "black" // Opaque for mask

            // Bind to barHitbox geometry
            x: barContent.barHitbox.x
            y: barContent.barHitbox.y
            width: barContent.barHitbox.width
            height: barContent.barHitbox.height
        }
    }

    UnifiedPanelEffect {
        id: unifiedEffect
        anchors.fill: parent
        sourceItem: visualContent
        maskEnabled: barCutout.visible
        maskSource: shadowMask
        maskInverted: true
    }

    Item {
        id: visualContent
        anchors.fill: parent
        
        ScreenFrameContent {
            id: frameContent
            anchors.fill: parent
            targetScreen: unifiedPanel.targetScreen
            hasFullscreenWindow: unifiedPanel.hasFullscreenWindow
            z: 1
        }

        BarContent {
            id: barContent
            anchors.fill: parent
            screen: unifiedPanel.targetScreen
            z: 2

            // Do not mask the entire bar; only center items should avoid the notch.
            layer.enabled: false
        }

        DockContent {
            id: dockContent
            unifiedEffectActive: unifiedPanel.unifiedEffectActive
            anchors.fill: parent
            screen: unifiedPanel.targetScreen
            z: 3
            visible: {
                if (!(Config.dock?.enabled ?? false) || (Config.dock?.theme ?? "default") === "integrated")
                    return false;
                
                const list = Config.dock?.screenList ?? [];
                if (!list || list.length === 0)
                    return true;
                return list.includes(screen.name);
            }
        }

        NotchContent {
            id: notchContent
            unifiedEffectActive: unifiedPanel.unifiedEffectActive
            anchors.fill: parent
            screen: unifiedPanel.targetScreen
            z: 4
        }
    }
}
