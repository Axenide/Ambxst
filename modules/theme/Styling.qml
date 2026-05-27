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

    // ============================================
    // M3 TYPOGRAPHY SYSTEM
    // ============================================
    // Material 3 type scale: https://m3.material.io/styles/typography/type-scale-tokens
    //
    // Each level returns { font, size, weight, lineHeight }
    //
    // Usage:
    //   Text { font.pixelSize: Styling.m3("title", "medium").size; font.weight: Styling.m3("title", "medium").weight }
    //
    // Scale is derived from Config.theme.fontSize (base = 14px)

    readonly property real _m3BaseSize: Math.max(Config.theme.fontSize || 14, 10)

    property var _m3Scale: null

    function _buildM3Scale() {
        const b = root._m3BaseSize;
        // M3 type scale ratios (relative to base 14px)
        const s = (mult) => Math.round(b * mult / 14 * 10) / 10;
        root._m3Scale = {
            // Display: large, medium, small
            "display": {
                large:  { size: s(57), weight: Font.Normal, lineHeight: s(64) },
                medium: { size: s(45), weight: Font.Normal, lineHeight: s(52) },
                small:  { size: s(36), weight: Font.Normal, lineHeight: s(44) }
            },
            // Headline
            "headline": {
                large:  { size: s(32), weight: Font.Normal, lineHeight: s(40) },
                medium: { size: s(28), weight: Font.Normal, lineHeight: s(36) },
                small:  { size: s(24), weight: Font.Normal, lineHeight: s(32) }
            },
            // Title
            "title": {
                large:  { size: s(22), weight: Font.Medium, lineHeight: s(28) },
                medium: { size: s(16), weight: Font.Medium, lineHeight: s(24) },
                small:  { size: s(14), weight: Font.Medium, lineHeight: s(20) }
            },
            // Label
            "label": {
                large:  { size: s(14), weight: Font.Medium, lineHeight: s(20) },
                medium: { size: s(12), weight: Font.Medium, lineHeight: s(16) },
                small:  { size: s(11), weight: Font.Medium, lineHeight: s(16) }
            },
            // Body
            "body": {
                large:  { size: s(16), weight: Font.Normal, lineHeight: s(24) },
                medium: { size: s(14), weight: Font.Normal, lineHeight: s(20) },
                small:  { size: s(12), weight: Font.Normal, lineHeight: s(16) }
            }
        };
    }

    /*! Get M3 typography token.
        @param type: "display" | "headline" | "title" | "label" | "body"
        @param size: "large" | "medium" | "small"
        @returns object with { size, weight, lineHeight }
    */
    function m3(type, size) {
        if (!root._m3Scale) root._buildM3Scale();
        const t = root._m3Scale[type];
        if (!t || !t[size]) {
            console.warn("M3 typography: unknown type/size", type, size);
            return { size: 14, weight: Font.Normal, lineHeight: 20 };
        }
        return t[size];
    }

    // Convenience properties — using function() instead of bindings to avoid loops
    property int m3HeadlineLarge:   0
    property int m3HeadlineMedium:  0
    property int m3HeadlineSmall:   0
    property int m3TitleLarge:      0
    property int m3TitleMedium:     0
    property int m3TitleSmall:      0
    property int m3BodyLarge:       0
    property int m3BodyMedium:      0
    property int m3BodySmall:       0
    property int m3LabelLarge:      0
    property int m3LabelMedium:     0
    property int m3LabelSmall:      0

    function _initM3Convenience() {
        root.m3HeadlineLarge  = root.m3("headline", "large").size;
        root.m3HeadlineMedium = root.m3("headline", "medium").size;
        root.m3HeadlineSmall  = root.m3("headline", "small").size;
        root.m3TitleLarge     = root.m3("title", "large").size;
        root.m3TitleMedium    = root.m3("title", "medium").size;
        root.m3TitleSmall     = root.m3("title", "small").size;
        root.m3BodyLarge      = root.m3("body", "large").size;
        root.m3BodyMedium     = root.m3("body", "medium").size;
        root.m3BodySmall      = root.m3("body", "small").size;
        root.m3LabelLarge     = root.m3("label", "large").size;
        root.m3LabelMedium    = root.m3("label", "medium").size;
        root.m3LabelSmall     = root.m3("label", "small").size;
    }

    Component.onCompleted: root._initM3Convenience()

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
