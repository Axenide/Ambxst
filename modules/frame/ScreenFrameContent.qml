import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.modules.components
import qs.modules.corners
import qs.modules.services
import qs.modules.theme
import qs.config

Item {
    id: root

    required property ShellScreen targetScreen
    property bool hasFullscreenWindow: false

    // State source: Singletons and Registry
    readonly property bool frameEnabled: Config.bar?.frameEnabled ?? false
    readonly property bool configContainBar: Config.bar?.containBar ?? false
    readonly property string barPos: Config.bar?.position ?? "top"
    readonly property string notchPos: Config.notchPosition ?? "top"
    
    readonly property var barPanel: Visibilities.barPanels[targetScreen.name]
    readonly property var dockPanel: Visibilities.dockPanels[targetScreen.name]
    
    // Effective Reveal States
    readonly property bool barReveal: barPanel ? barPanel.reveal : true
    readonly property bool dockReveal: dockPanel ? dockPanel.reveal : true
    readonly property bool notchReveal: barPanel ? barPanel.notchReveal : true

    // Hover States for Restoration Logic
    readonly property bool barHovered: barPanel ? (barPanel.barHoverActive || barPanel.notchHoverActive || barPanel.notchOpen) : false
    readonly property bool dockHovered: dockPanel ? (dockPanel.reveal && (dockPanel.activeWindowFullscreen || dockPanel.keepHidden || !dockPanel.pinned)) : false

    readonly property real baseThickness: {
        const base = Config.bar?.frameThickness ?? 6;
        return Math.max(1, Math.min(Math.round(base), 40));
    }

    readonly property int barSize: {
        if (!barPanel) return 44;
        const isHoriz = barPos === "top" || barPos === "bottom";
        return isHoriz ? barPanel.barTargetHeight : barPanel.barTargetWidth;
    }

    // --- Animation Synchronization ---
    
    property real _barAnimProgress: barReveal ? 1.0 : 0.0
    Behavior on _barAnimProgress {
        enabled: Config.animDuration > 0
        NumberAnimation { duration: Config.animDuration / 2; easing.type: Easing.OutCubic }
    }

    property real _dockAnimProgress: dockReveal ? 1.0 : 0.0
    Behavior on _dockAnimProgress {
        enabled: Config.animDuration > 0
        NumberAnimation { duration: Config.animDuration / 2; easing.type: Easing.OutCubic }
    }

    property real _notchAnimProgress: notchReveal ? 1.0 : 0.0
    Behavior on _notchAnimProgress {
        enabled: Config.animDuration > 0
        NumberAnimation { duration: Config.animDuration / 2; easing.type: Easing.OutCubic }
    }

    // Bar expansion logic (synchronized with bar reveal)
    // Only expand if frame is enabled and bar is being contained
    readonly property int barExpansion: (frameEnabled && configContainBar) ? Math.round((barSize + baseThickness) * _barAnimProgress) : 0

    // --- Side-Specific Thickness Restoration ---

    readonly property int topThickness: calculateSideThickness("top")
    readonly property int bottomThickness: calculateSideThickness("bottom")
    readonly property int leftThickness: calculateSideThickness("left")
    readonly property int rightThickness: calculateSideThickness("right")

    function calculateSideThickness(side) {
        let t = baseThickness;
        if (hasFullscreenWindow) {
            let restore = false;
            let progress = 0.0;

            if (barPos === side && barHovered) { restore = true; progress = Math.max(progress, _barAnimProgress); }
            if (notchPos === side && barHovered) { restore = true; progress = Math.max(progress, _notchAnimProgress); }
            if (dockPanel && dockPanel.position === side && dockHovered) { restore = true; progress = Math.max(progress, _dockAnimProgress); }
            
            t = restore ? (baseThickness * progress) : 0;
        }
        
        let expansion = (configContainBar && barPos === side) ? barExpansion : 0;
        return Math.round(t) + expansion;
    }

    // --- Corner Logic ---
    
    readonly property real targetInnerRadius: {
        if (!root.hasFullscreenWindow) return Styling.radius(4);
        if (!barHovered && !dockHovered) return 0;
        
        let progress = Math.max(_barAnimProgress, _dockAnimProgress, _notchAnimProgress);
        return Styling.radius(4) * progress;
    }
    
    property real innerRadius: targetInnerRadius

    // --- Visuals ---

    StyledRect {
        id: frameFill
        anchors.fill: parent
        variant: "bg"
        radius: 0
        enableBorder: false
        visible: root.frameEnabled
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: frameMask
            maskInverted: true
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }
    }

    Item {
        id: frameMask
        anchors.fill: parent
        visible: false
        layer.enabled: true

        Rectangle {
            id: maskRect
            x: root.leftThickness
            y: root.topThickness
            width: parent.width - (root.leftThickness + root.rightThickness)
            height: parent.height - (root.topThickness + root.bottomThickness)
            radius: root.innerRadius
            color: "white"
            visible: width > 0 && height > 0
        }
    }
}
