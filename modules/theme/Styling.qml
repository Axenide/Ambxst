pragma Singleton
import QtQuick
import qs.config

QtObject {
    readonly property string defaultFont: Config.defaultFont

    function radius(offset) {
        return Config.roundness > 0 ? Math.max(Config.roundness + offset, 0) : 0;
    }

    function fontSize(offset) {
        return Math.max(Config.theme.fontSize + offset, 8);
    }

    function monoFontSize(offset) {
        return Math.max(Config.theme.monoFontSize + offset, 8);
    }

    // Standard radius for floating surfaces (popups, OSD, notifications).
    // Keeps every "floating" element visually consistent regardless of where
    // it is defined.
    function popupRadius() {
        return radius(8);
    }

    // Apply an alpha to an existing theme color without unpacking channels by
    // hand everywhere (e.g. Qt.rgba(Colors.overBackground.r, .g, .b, 0.2)).
    function tint(color, alpha) {
        return Qt.rgba(color.r, color.g, color.b, alpha);
    }

    // Consistent interaction feedback alphas used across every interactive
    // surface (buttons, app icons, list rows) so hover/press feel is uniform.
    readonly property real hoverAlpha: 0.12
    readonly property real pressAlpha: 0.24

    // Single canonical easing for shell motion. Centralizing it lets every
    // surface share the same "weight" of animation (OutQuart was inconsistent
    // with OutCubic/OutQuad used elsewhere).
    readonly property int animEasing: Easing.OutCubic

    function getStyledRectConfig(variant) {
        switch (variant) {
        case "transparent":
            // Internal variant: uses bg config but with opacity, border and radius forced to 0
            const bgConfig = Config.theme.srBg;
            return {
                gradient: bgConfig.gradient,
                gradientType: bgConfig.gradientType,
                gradientAngle: bgConfig.gradientAngle,
                gradientCenterX: bgConfig.gradientCenterX,
                gradientCenterY: bgConfig.gradientCenterY,
                halftoneDotMin: bgConfig.halftoneDotMin,
                halftoneDotMax: bgConfig.halftoneDotMax,
                halftoneStart: bgConfig.halftoneStart,
                halftoneEnd: bgConfig.halftoneEnd,
                halftoneDotColor: bgConfig.halftoneDotColor,
                halftoneBackgroundColor: bgConfig.halftoneBackgroundColor,
                itemColor: bgConfig.itemColor,
                opacity: 0,
                border: [bgConfig.border[0], 0],
                radius: 0
            };
        case "bg":
            return Config.theme.srBg;
        case "popup":
            return Config.theme.srPopup;
        case "internalbg":
            return Config.theme.srInternalBg;
        case "pane":
            return Config.theme.srPane;
        case "common":
            return Config.theme.srCommon;
        case "focus":
            return Config.theme.srFocus;
        case "primary":
            return Config.theme.srPrimary;
        case "primaryfocus":
            return Config.theme.srPrimaryFocus;
        case "overprimary":
            return Config.theme.srOverPrimary;
        case "secondary":
            return Config.theme.srSecondary;
        case "secondaryfocus":
            return Config.theme.srSecondaryFocus;
        case "oversecondary":
            return Config.theme.srOverSecondary;
        case "tertiary":
            return Config.theme.srTertiary;
        case "tertiaryfocus":
            return Config.theme.srTertiaryFocus;
        case "overtertiary":
            return Config.theme.srOverTertiary;
        case "error":
            return Config.theme.srError;
        case "errorfocus":
            return Config.theme.srErrorFocus;
        case "overerror":
            return Config.theme.srOverError;
        case "barbg":
            return Config.theme.srBarBg;
        default:
            return Config.theme.srCommon;
        }
    }

    function srItem(variant) {
        return Config.resolveColor(getStyledRectConfig(variant).itemColor);
    }
}
