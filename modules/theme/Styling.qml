pragma Singleton
import QtQuick
import qs.config

QtObject {
    id: root
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

    // Pre-built "transparent" variant to avoid allocating a new object on every call
    property var _transparentConfig: null

    function getStyledRectConfig(variant) {
        switch (variant) {
        case "transparent":
            // Lazy-init the transparent config (needs bgConfig which may change on theme reload)
            var bgConfig = Config.theme.srBg;
            if (!root._transparentConfig) {
                root._transparentConfig = {
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
            }
            return root._transparentConfig;
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
