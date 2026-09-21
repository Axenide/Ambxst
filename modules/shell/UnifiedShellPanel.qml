import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.modules.bar
import qs.modules.bar.workspaces
import qs.modules.notch
import qs.modules.dock
import qs.modules.frame
import qs.modules.services
import qs.modules.globals
import qs.modules.components
import qs.config
import qs.modules.sidebar

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

    // Dynamic keyboard focus: Exclusive when a notch module is open (so text fields work),
    // None otherwise (so compositor receives normal input).
    WlrLayershell.keyboardFocus: {
        if (notchContent.screenNotchOpen) {
            return WlrKeyboardFocus.Exclusive;
        }
        if (assistantSidebar.active && assistantSidebar.wantsFocus) {
            return WlrKeyboardFocus.Exclusive;
        }
        return WlrKeyboardFocus.None;
    }
    WlrLayershell.namespace: "ambxst"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore

    // Whether we need to capture full-screen input for click-outside detection.
    // True when notch modules are open OR any FocusGrab is active (e.g., BarPopups).
    readonly property bool needsFullScreenInput: notchContent.screenNotchOpen || FocusGrabManager.hasActiveGrab || (assistantSidebar.active && assistantSidebar.wantsFocus)

    readonly property bool barEnabled: {
        if (!Config.barReady) return false;
        const list = Config.bar.screenList;
        return (!list || list.length === 0 || list.indexOf(targetScreen.name) !== -1);
    }

    readonly property bool dockEnabled: {
        if (!Config.dockReady) return false;
        if (!(Config.dock.enabled ?? false) || (Config.dock.theme ?? "default") === "integrated")
            return false;
        const list = Config.dock.screenList;
        return (!list || list.length === 0 || list.indexOf(targetScreen.name) !== -1);
    }

    readonly property alias barPosition: barContent.barPosition
    readonly property alias barPinned: barContent.pinned
    readonly property alias barHoverActive: barContent.hoverActive
    readonly property alias barFullscreen: barContent.activeWindowFullscreen
    readonly property bool barReveal: barEnabled && barContent.reveal
    readonly property alias barTargetWidth: barContent.barTargetWidth
    readonly property alias barTargetHeight: barContent.barTargetHeight
    readonly property alias barOuterMargin: barContent.baseOuterMargin

    readonly property alias dockPosition: dockContent.position
    readonly property alias dockPinned: dockContent.pinned
    readonly property bool dockReveal: dockEnabled && dockContent.reveal
    readonly property alias dockFullscreen: dockContent.activeWindowFullscreen
    readonly property int dockHeight: dockContent.dockSize + dockContent.totalMargin

    readonly property alias notchHoverActive: notchContent.hoverActive
    readonly property alias notchOpen: notchContent.screenNotchOpen
    readonly property alias notchReveal: notchContent.reveal

    // Generic names for external compatibility (Visibilities expects these on the panel object)
    readonly property alias pinned: barContent.pinned
    readonly property bool reveal: barEnabled ? barContent.reveal : false
    readonly property alias hoverActive: barContent.hoverActive // Default hoverActive points to bar
    readonly property alias notch_hoverActive: notchContent.hoverActive // Used by bar to check notch

    readonly property bool unifiedEffectActive: false // Flag to notify children to disable internal borders

    readonly property var compositorMonitor: AxctlService.monitorFor(targetScreen)
    readonly property bool hasFullscreenWindow: {
        if (!compositorMonitor)
            return false;

        const activeWorkspaceId = compositorMonitor.activeWorkspace.id;
        const monId = compositorMonitor.id;

        // Check active toplevel first (fast path)
        const toplevel = ToplevelManager.activeToplevel;
        if (toplevel && toplevel.fullscreen && AxctlService.focusedMonitor.id === monId) {
            return true;
        }

        // Check all windows on this monitor (robust path)
        const wins = CompositorData.windowList;
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

    // Full-screen mask item (used when modules/popups are open)
    Item {
        id: fullScreenMask
        anchors.fill: parent
    }

    // Mask Region Logic
    // When a module or popup is open, expand to full-screen to capture click-outside.
    // Otherwise, restrict input to Bar, Notch, and Dock hitboxes only.
    mask: Region {
        // Full-screen capture when any module/popup is open
        item: unifiedPanel.needsFullScreenInput ? fullScreenMask : null
        regions: [
            Region {
                item: barContent.visible ? barContent.barHitbox : null
            },
            Region {
                item: notchContent.notchHitbox
            },
            Region {
                // Only include the dock hitbox if the dock is actually enabled and visible on this screen.
                item: dockContent.visible ? dockContent.dockHitbox : null
            },
            Region {
                item: (assistantSidebar.active || assistantSidebar.hitbox.visible) ? assistantSidebar.hitbox : null
            }
        ]
    }

    // Focus Grab for Notch — registers with FocusGrabManager for click-outside coordination
    FocusGrab {
        id: focusGrab
        windows: [unifiedPanel]
        active: notchContent.screenNotchOpen

        onCleared: {
            Visibilities.setActiveModule("");
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // CLICK-OUTSIDE BACKDROP
    // ═══════════════════════════════════════════════════════════════

    // Transparent backdrop that captures clicks on empty areas when modules/popups are open.
    // z: -1 ensures it's below all visual content (bar, notch, dock).
    MouseArea {
        id: backdropArea
        anchors.fill: parent
        visible: unifiedPanel.needsFullScreenInput
        z: -1

        onClicked: {
            FocusGrabManager.clearTopGrab();
            if (assistantSidebar.active && assistantSidebar.wantsFocus) {
                assistantSidebar.wantsFocus = false;
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // VISUAL CONTENT
    // ═══════════════════════════════════════════════════════════════

    Item {
        id: visualContent
        anchors.fill: parent

        layer.enabled: true
        layer.effect: Shadow {}

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
            visible: unifiedPanel.barEnabled
        }

        DockContent {
            id: dockContent
            unifiedEffectActive: unifiedPanel.unifiedEffectActive
            anchors.fill: parent
            screen: unifiedPanel.targetScreen
            z: 3
            visible: unifiedPanel.dockEnabled
        }

        NotchContent {
            id: notchContent
            unifiedEffectActive: unifiedPanel.unifiedEffectActive
            anchors.fill: parent
            screen: unifiedPanel.targetScreen
            z: 4
        }

        AssistantSidebar {
            id: assistantSidebar
            targetScreen: unifiedPanel.targetScreen
            z: 1
            
            // Respect top/bottom bar reservations so the sidebar doesn't overlap them
            anchors.topMargin: {
                let frameOn = (Config.bar?.frameEnabled ?? false);
                let frameWrapped = frameOn && GlobalStates.assistantPinned;
                let margin = (frameOn && !frameWrapped) ? (Config.bar?.frameThickness ?? 6) : 0;
                if (unifiedPanel.barEnabled && unifiedPanel.barPosition === "top" && unifiedPanel.barPinned) {
                    margin += unifiedPanel.barTargetHeight + unifiedPanel.barOuterMargin + (unifiedPanel.containBar ? Config.bar.frameThickness : 0);
                }
                return margin;
            }
            
            anchors.bottomMargin: {
                let frameOn = (Config.bar?.frameEnabled ?? false);
                let frameWrapped = frameOn && GlobalStates.assistantPinned;
                let margin = (frameOn && !frameWrapped) ? (Config.bar?.frameThickness ?? 6) : 0;
                if (unifiedPanel.barEnabled && unifiedPanel.barPosition === "bottom" && unifiedPanel.barPinned) {
                    margin += unifiedPanel.barTargetHeight + unifiedPanel.barOuterMargin + (unifiedPanel.containBar ? Config.bar.frameThickness : 0);
                } else if (unifiedPanel.dockEnabled && dockContent.dockPosition === "bottom" && dockContent.pinned) {
                    margin += dockContent.dockHeight;
                }
                return margin;
            }

            anchors.leftMargin: {
                let sidebarPos = GlobalStates.assistantPosition;
                let frameOn = (Config.bar?.frameEnabled ?? false);
                let frameWrapped = frameOn && GlobalStates.assistantPinned;
                let margin = 0;
                if (sidebarPos === "left" && frameOn && !frameWrapped)
                    margin += (Config.bar?.frameThickness ?? 6);
                if (unifiedPanel.barEnabled && unifiedPanel.barPosition === "left" && unifiedPanel.barPinned)
                    margin += unifiedPanel.barTargetWidth + unifiedPanel.barOuterMargin + (unifiedPanel.containBar ? Config.bar.frameThickness : 0);
                return margin;
            }

            anchors.rightMargin: {
                let sidebarPos = GlobalStates.assistantPosition;
                let frameOn = (Config.bar?.frameEnabled ?? false);
                let frameWrapped = frameOn && GlobalStates.assistantPinned;
                let margin = 0;
                if (sidebarPos === "right" && frameOn && !frameWrapped)
                    margin += (Config.bar?.frameThickness ?? 6);
                if (unifiedPanel.barEnabled && unifiedPanel.barPosition === "right" && unifiedPanel.barPinned)
                    margin += unifiedPanel.barTargetWidth + unifiedPanel.barOuterMargin + (unifiedPanel.containBar ? Config.bar.frameThickness : 0);
                return margin;
            }
        }
    }
}
