pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.components

/*!
    Surface.qml — Material 3 elevated surface with optional interaction state layer.

    Maps M3 elevation levels (0-4) to existing StyledRect variants and adds
    automatic shadows + StateLayer when interactive.

    Elevation mapping:
        0 → "bg"           (surface / background)
        1 → "common"       (surfaceContainerLow)
        2 → "pane"         (surfaceContainer)
        3 → "popup"        (surfaceContainerHigh)
        4 → "internalbg"   (surfaceContainerHighest)

    Usage:
        Surface {
            elevation: 2
            interactive: true
            width: 200; height: 48
            onClicked: console.log("surface clicked")

            Text {
                anchors.centerIn: parent
                text: "Button"
                color: Styling.srItem(parent.variant)
            }
        }
*/
StyledRect {
    id: root

    // ============================================
    // PUBLIC API
    // ============================================

    /*! M3 elevation level: 0 (flat) → 4 (highest). */
    property int elevation: 0

    /*! If true, a StateLayer is added and this surface reacts to hover/press. */
    property bool interactive: false

    /*! Override the automatic variant mapping. If empty, elevation is used. */
    property string variantOverride: ""

    /*! Forwarded signals from StateLayer (only emitted when interactive). */
    signal clicked(var mouse)
    signal pressed(var mouse)
    signal released(var mouse)

    // ============================================
    // RESOLVED VARIANT
    // ============================================

    readonly property string resolvedVariant: {
        if (root.variantOverride !== "") return root.variantOverride;
        switch (root.elevation) {
        case 0: return "bg";
        case 1: return "common";
        case 2: return "pane";
        case 3: return "popup";
        case 4: return "internalbg";
        default: return "bg";
        }
    }

    variant: root.resolvedVariant

    // Shadow enabled for elevations > 0
    enableShadow: root.elevation > 0 && Config.theme.shadowOpacity > 0

    // ============================================
    // STATE LAYER
    // ============================================

    // Determine state-layer color from the resolved variant's itemColor.
    // Falls back to Colors.overBackground if the variant has no explicit itemColor.
    readonly property color stateLayerColor: {
        const cfg = Styling.getStyledRectConfig(root.resolvedVariant);
        if (cfg && cfg.itemColor) return Config.resolveColor(cfg.itemColor);
        return Colors.overBackground;
    }

    StateLayer {
        id: stateLayer
        anchors.fill: parent
        interactive: root.interactive
        color: root.stateLayerColor

        onClicked: mouse => root.clicked(mouse)
        onPressed: mouse => root.pressed(mouse)
        onReleased: mouse => root.released(mouse)
    }
}
