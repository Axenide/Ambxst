pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.modules.globals

FileView {
    id: colors
    // QUICKSHELL-GIT: path: Quickshell.cachePath("colors.json")
    path: Quickshell.env("HOME") + "/.cache/ambxst/colors.json"
    preload: true
    watchChanges: true
    onFileChanged: {
        reload();
        generationTimer.restart();
    }

    property Connections oledWatcher: Connections {
        target: Config
        function onOledModeChanged() {
            generationTimer.restart();
        }
    }

    property Connections themeWatcher: Connections {
        target: Config.loader
        function onFileChanged() {
            generationTimer.restart();
        }
    }

    property QtCtGenerator qtCtGenerator: QtCtGenerator {
        id: qtCtGenerator
    }

    property GtkGenerator gtkGenerator: GtkGenerator {
        id: gtkGenerator
    }

    property PywalGenerator pywalGenerator: PywalGenerator {
        id: pywalGenerator
    }

    property KittyGenerator kittyGenerator: KittyGenerator {
        id: kittyGenerator
    }

    property NvChadGenerator nvChadGenerator: NvChadGenerator {
        id: nvChadGenerator
    }

    property DiscordGenerator discordGenerator: DiscordGenerator {
        id: discordGenerator
    }

    property Timer generationTimer: Timer {
        id: generationTimer
        interval: 100
        repeat: false
        onTriggered: {
            qtCtGenerator.generate(colors);
            gtkGenerator.generate(colors);
            pywalGenerator.generate(colors);
            kittyGenerator.generate(colors);
            nvChadGenerator.generate(colors);
            discordGenerator.generate(colors);
        }
    }

    adapter: JsonAdapter {
        property color background: "#1a1111"
        property color blue: "#cebdfe"
        property color blueContainer: "#4c3e76"
        property color blueSource: "#0000ff"
        property color blueValue: "#0000ff"
        property color cyan: "#84d5c4"
        property color cyanContainer: "#005045"
        property color cyanSource: "#00ffff"
        property color cyanValue: "#00ffff"
        property color error: "#ffb4ab"
        property color errorContainer: "#93000a"
        property color green: "#b7d085"
        property color greenContainer: "#3a4d10"
        property color greenSource: "#00ff00"
        property color greenValue: "#00ff00"
        property color inverseOnSurface: "#382e2d"
        property color inversePrimary: "#904a46"
        property color inverseSurface: "#f1dedd"
        property color lightBlue: "#cebdfe"
        property color lightCyan: "#84d5c4"
        property color lightGreen: "#b7d085"
        property color lightMagenta: "#fcb0d5"
        property color lightRed: "#ffb4ab"
        property color lightYellow: "#dec56e"
        property color magenta: "#fcb0d5"
        property color magentaContainer: "#6c3353"
        property color magentaSource: "#ff00ff"
        property color magentaValue: "#ff00ff"
        property color overBackground: "#f1dedd"
        property color overBlue: "#35275e"
        property color overBlueContainer: "#e8ddff"
        property color overCyan: "#00382f"
        property color overCyanContainer: "#9ff2e0"
        property color overError: "#690005"
        property color overErrorContainer: "#ffdad6"
        property color overGreen: "#253600"
        property color overGreenContainer: "#d3ec9e"
        property color overMagenta: "#521d3c"
        property color overMagentaContainer: "#ffd8e8"
        property color overPrimary: "#571d1c"
        property color overPrimaryContainer: "#ffdad7"
        property color overPrimaryFixed: "#3b0809"
        property color overPrimaryFixedVariant: "#733331"
        property color overRed: "#561e19"
        property color overRedContainer: "#ffdad6"
        property color overSecondary: "#442928"
        property color overSecondaryContainer: "#ffdad7"
        property color overSecondaryFixed: "#2c1514"
        property color overSecondaryFixedVariant: "#5d3f3d"
        property color overSurface: "#f1dedd"
        property color overSurfaceVariant: "#d8c2c0"
        property color overTertiary: "#402d04"
        property color overTertiaryContainer: "#ffdea7"
        property color overTertiaryFixed: "#271900"
        property color overTertiaryFixedVariant: "#594319"
        property color overWhite: "#00363d"
        property color overWhiteContainer: "#9eeffd"
        property color overYellow: "#3b2f00"
        property color overYellowContainer: "#fce186"
        property color outline: "#a08c8b"
        property color outlineVariant: "#534342"
        property color primary: "#ffb3ae"
        property color primaryContainer: "#733331"
        property color primaryFixed: "#ffdad7"
        property color primaryFixedDim: "#ffb3ae"
        property color red: "#ffb4ab"
        property color redContainer: "#73332e"
        property color redSource: "#ff0000"
        property color redValue: "#ff0000"
        property color scrim: "#000000"
        property color secondary: "#e7bdb9"
        property color secondaryContainer: "#5d3f3d"
        property color secondaryFixed: "#ffdad7"
        property color secondaryFixedDim: "#e7bdb9"
        property color shadow: "#000000"
        property color surface: "#1a1111"
        property color surfaceBright: "#423736"
        property color surfaceContainer: "#271d1d"
        property color surfaceContainerHigh: "#322827"
        property color surfaceContainerHighest: "#3d3231"
        property color surfaceContainerLow: "#231919"
        property color surfaceContainerLowest: "#140c0c"
        property color surfaceDim: "#1a1111"
        property color surfaceTint: "#ffb3ae"
        property color surfaceVariant: "#534342"
        property color tertiary: "#e2c28c"
        property color tertiaryContainer: "#594319"
        property color tertiaryFixed: "#ffdea7"
        property color tertiaryFixedDim: "#e2c28c"
        property color white: "#82d3e0"
        property color whiteContainer: "#004f58"
        property color whiteSource: "#ffffff"
        property color whiteValue: "#ffffff"
        property color yellow: "#dec56e"
        property color yellowContainer: "#554500"
        property color yellowSource: "#ffff00"
        property color yellowValue: "#ffff00"
        property color sourceColor: "#7f2424"
    }

    // ============================================
    // DYNAMIC SURFACE OPACITY — adjusted by wallpaper vibrancy
    // More vibrant wallpapers → more transparent (show more wallpaper)
    // Muted wallpapers → more opaque (better readability)
    // ============================================
    readonly property real _vibrancyAlpha: 0.5 + (1.0 - (typeof root !== "undefined" ? root.vibrancy : 0.5)) * 0.5

    property color background: Config.oledMode ? "#000000" : adapter.background

    property color surface: Qt.tint(background, Qt.rgba(adapter.overBackground.r, adapter.overBackground.g, adapter.overBackground.b, 0.1 * (typeof root !== "undefined" ? root._vibrancyAlpha : 0.75)))
    property color surfaceBright: Qt.tint(background, Qt.rgba(adapter.overBackground.r, adapter.overBackground.g, adapter.overBackground.b, 0.2 * (typeof root !== "undefined" ? root._vibrancyAlpha : 0.75)))
    property color surfaceContainer: adapter.surfaceContainer
    property color surfaceContainerHigh: adapter.surfaceContainerHigh
    property color surfaceContainerHighest: adapter.surfaceContainerHighest
    property color surfaceContainerLow: adapter.surfaceContainerLow
    property color surfaceContainerLowest: adapter.surfaceContainerLowest
    property color surfaceDim: adapter.surfaceDim
    property color surfaceTint: adapter.surfaceTint
    property color surfaceVariant: adapter.surfaceVariant

    // Direct color properties from adapter
    property color blue: adapter.blue
    property color blueContainer: adapter.blueContainer
    property color blueSource: adapter.blueSource
    property color blueValue: adapter.blueValue
    property color cyan: adapter.cyan
    property color cyanContainer: adapter.cyanContainer
    property color cyanSource: adapter.cyanSource
    property color cyanValue: adapter.cyanValue
    property color error: adapter.error
    property color errorContainer: adapter.errorContainer
    property color green: adapter.green
    property color greenContainer: adapter.greenContainer
    property color greenSource: adapter.greenSource
    property color greenValue: adapter.greenValue
    property color inverseOnSurface: adapter.inverseOnSurface
    property color inversePrimary: adapter.inversePrimary
    property color inverseSurface: adapter.inverseSurface
    property color lightBlue: adapter.lightBlue
    property color lightCyan: adapter.lightCyan
    property color lightGreen: adapter.lightGreen
    property color lightMagenta: adapter.lightMagenta
    property color lightRed: adapter.lightRed
    property color lightYellow: adapter.lightYellow
    property color magenta: adapter.magenta
    property color magentaContainer: adapter.magentaContainer
    property color magentaSource: adapter.magentaSource
    property color magentaValue: adapter.magentaValue
    property color overBackground: adapter.overBackground
    property color overBlue: adapter.overBlue
    property color overBlueContainer: adapter.overBlueContainer
    property color overCyan: adapter.overCyan
    property color overCyanContainer: adapter.overCyanContainer
    property color overError: adapter.overError
    property color overErrorContainer: adapter.overErrorContainer
    property color overGreen: adapter.overGreen
    property color overGreenContainer: adapter.overGreenContainer
    property color overMagenta: adapter.overMagenta
    property color overMagentaContainer: adapter.overMagentaContainer
    property color overPrimary: adapter.overPrimary
    property color overPrimaryContainer: adapter.overPrimaryContainer
    property color overPrimaryFixed: adapter.overPrimaryFixed
    property color overPrimaryFixedVariant: adapter.overPrimaryFixedVariant
    property color overRed: adapter.overRed
    property color overRedContainer: adapter.overRedContainer
    property color overSecondary: adapter.overSecondary
    property color overSecondaryContainer: adapter.overSecondaryContainer
    property color overSecondaryFixed: adapter.overSecondaryFixed
    property color overSecondaryFixedVariant: adapter.overSecondaryFixedVariant
    property color overSurface: adapter.overSurface
    property color overSurfaceVariant: adapter.overSurfaceVariant
    property color onSurface: overBackground  // alias for M3 compatibility
    property color onSurfaceVariant: overSurfaceVariant  // alias for M3 compatibility
    property color onPrimaryContainer: overPrimaryContainer
    property color onSecondaryContainer: overSecondaryContainer
    property color onTertiaryContainer: overTertiaryContainer
    property color onErrorContainer: overErrorContainer
    property color onPrimary: overPrimary
    property color onSecondary: overSecondary
    property color onTertiary: overTertiary
    property color onError: overError
    property color overTertiary: adapter.overTertiary
    property color overTertiaryContainer: adapter.overTertiaryContainer
    property color overTertiaryFixed: adapter.overTertiaryFixed
    property color overTertiaryFixedVariant: adapter.overTertiaryFixedVariant
    property color overWhite: adapter.overWhite
    property color overWhiteContainer: adapter.overWhiteContainer
    property color overYellow: adapter.overYellow
    property color overYellowContainer: adapter.overYellowContainer
    property color outline: adapter.outline
    property color outlineVariant: adapter.outlineVariant
    property color primary: adapter.primary
    property color primaryContainer: adapter.primaryContainer
    property color primaryFixed: adapter.primaryFixed
    property color primaryFixedDim: adapter.primaryFixedDim
    property color red: adapter.red
    property color redContainer: adapter.redContainer
    property color redSource: adapter.redSource
    property color redValue: adapter.redValue
    property color scrim: adapter.scrim
    property color secondary: adapter.secondary
    property color secondaryContainer: adapter.secondaryContainer
    property color secondaryFixed: adapter.secondaryFixed
    property color secondaryFixedDim: adapter.secondaryFixedDim
    property color shadow: adapter.shadow
    property color tertiary: adapter.tertiary
    property color tertiaryContainer: adapter.tertiaryContainer
    property color tertiaryFixed: adapter.tertiaryFixed
    property color tertiaryFixedDim: adapter.tertiaryFixedDim
    property color white: adapter.white
    property color whiteContainer: adapter.whiteContainer
    property color whiteSource: adapter.whiteSource
    property color whiteValue: adapter.whiteValue
    property color yellow: adapter.yellow
    property color yellowContainer: adapter.yellowContainer
    property color yellowSource: adapter.yellowSource
    property color yellowValue: adapter.yellowValue
    property color sourceColor: adapter.sourceColor

    // ============================================
    // DYNAMIC COLOR — Wallpaper ColorQuantizer (M3 Material You)
    // Extracts dominant colors from current wallpaper for dynamic theming.
    // ============================================

    /*! Dominant color extracted from wallpaper via ColorQuantizer (rescaleSize: 10).
        Falls back to adapter.sourceColor when unavailable. */
    property color dominantColor: adapter.sourceColor

    /*! Vibrancy (0.0-1.0) of the extracted dominant color.
        High vibrancy → more transparent surfaces.
        Low vibrancy → more opaque surfaces (muted wallpapers). */
    property real vibrancy: 0.5

    /*! Whether dynamic color from wallpaper is active.
        Controlled by Config.dynamicColor toggle.
        When enabled, overrides static palette with quantizer colors. */
    property bool dynamicColorEnabled: false
    onDynamicColorEnabledChanged: {
        if (dynamicColorEnabled && wallpaperQuantizer.colors.length > 0) {
            console.log("DynamicColor: enabled, regenerating palette");
        }
    }

    /*! Connection to wallpaperManager: re-quantize when wallpaper changes.
        Delayed 500ms to ensure wallpaperManager is available. */
    property Timer _wallpaperInitTimer: Timer {
        id: _wallpaperInitTimer
        interval: 500
        repeat: false
        onTriggered: {
            if (typeof GlobalStates !== "undefined" && GlobalStates.wallpaperManager) {
                wallpaperWatcher.target = GlobalStates.wallpaperManager;
                const path = GlobalStates.wallpaperManager.currentWallpaper || "";
                const ext = path.split(".").pop().toLowerCase();
                if (["mp4", "webm", "mov", "avi", "mkv", "gif"].indexOf(ext) < 0) {
                    wallpaperQuantizer.source = path;
                }
            } else {
                // Retry later — services may not be initialized yet
                _wallpaperInitTimer.restart();
            }
        }
        Component.onCompleted: _wallpaperInitTimer.restart();
    }

    /*! Listen for wallpaper changes and re-quantize colors.
        Target is set dynamically by _wallpaperInitTimer.
        Skips video files (mp4, webm, gif) since ColorQuantizer only handles images. */
    property Connections wallpaperWatcher: Connections {
        id: wallpaperWatcher
        target: null
        function onCurrentWallpaperChanged() {
            if (wallpaperWatcher.target) {
                const path = wallpaperWatcher.target.currentWallpaper || "";
                // Skip video files — ColorQuantizer only handles images
                const ext = path.split(".").pop().toLowerCase();
                if (["mp4", "webm", "mov", "avi", "mkv", "gif"].indexOf(ext) >= 0) {
                    console.log("DynamicColor: skipping video wallpaper:", ext);
                    return;
                }
                wallpaperQuantizer.source = path;
            }
        }
    }

    /*! ColorQuantizer: extracts dominant colors from current wallpaper.
        Uses rescaleSize:10 (tiny downscale) for maximum performance.
        Colors are available in wallpaperQuantizer.colors array.
        Falls back to adapter.sourceColor when wallpaper is unavailable. */
    property ColorQuantizer wallpaperQuantizer: ColorQuantizer {
        id: wallpaperQuantizer
        depth: 6
        rescaleSize: 10
        source: ""
        onColorsChanged: {
            if (wallpaperQuantizer.colors.length > 0) {
                const c = wallpaperQuantizer.colors[0];
                root.dominantColor = Qt.hsla(c.hslHue, c.hslSaturation, c.hslLightness, 1.0);
                // Vibrancy: 0.0 (muted/greyscale) to 1.0 (vibrant/colorful)
                // Formula: saturation contributes 60%, lightness contrast 40%
                const sat = c.hslSaturation;
                const lightContrast = 1.0 - Math.abs(c.hslLightness - 0.5) * 2.0;
                root.vibrancy = Math.min(1.0, Math.max(0.0, sat * 0.6 + lightContrast * 0.4));
                console.log("DynamicColor:", wallpaperQuantizer.colors.length, "colors,",
                    "dominant:", root.dominantColor, "vibrancy:", root.vibrancy.toFixed(2));
            }
        }
        onSourceChanged: {
            if (source.toString().length > 0) {
                const src = source.toString();
                const ext = src.split(".").pop().toLowerCase();
                if (["mp4", "webm", "mov", "avi", "mkv", "gif"].indexOf(ext) >= 0) {
                    console.log("DynamicColor: skipping video (safety):", ext);
                    // Clear the source to prevent the quantizer from trying to load it
                    wallpaperQuantizer.source = "";
                    return;
                }
                console.log("DynamicColor: quantizing:", src);
            }
        }
    }

    // ============================================
    // M3 ELEVATION SYSTEM — helpers & semantic surfaces
    // ============================================
    // M3 defines 5 elevation levels (0-4) mapped to surface colors:
    //   Level 0: surfaceDim (lowest, sunken)
    //   Level 1: surfaceContainerLowest
    //   Level 2: surfaceContainerLow
    //   Level 3: surfaceContainer
    //   Level 4: surfaceContainerHigh
    //   Level 5: surfaceContainerHighest
    //
    // Usage:  Colors.elevation(3)  => surfaceContainer
    //         Colors.elevation(0)  => surfaceDim

    /*! Get surface color for M3 elevation level (0-5). */
    function elevation(level) {
        switch (level) {
        case 0:  return root.surfaceDim;
        case 1:  return root.surfaceContainerLowest;
        case 2:  return root.surfaceContainerLow;
        case 3:  return root.surfaceContainer;
        case 4:  return root.surfaceContainerHigh;
        case 5:  return root.surfaceContainerHighest;
        default: return level <= 0 ? root.surfaceDim : root.surfaceContainerHighest;
        }
    }

    /*! Convenience: get the over-surface color for a given elevation level. */
    function overElevation(level) {
        return root.overBackground; // M3 spec: all levels use same text color
    }

    /*! Get the surface tint/primary color for elevation (same as surfaceTint). */
    function elevationTint(level) {
        return root.surfaceTint;
    }

    // ============================================
    // M3 PALETTE GENERATION — from source/dominant color
    // ============================================
    // Generates a tonal palette from a source color using the M3 HCT
    // (Hue-Chroma-Tone) approach. Since QML doesn't expose HCT natively,
    // we approximate using HSL + fixed chroma offsets per tone.
    //
    // Usage:
    //   const palette = Colors.generatePalette(Colors.dominantColor);
    //   console.log(palette.primary, palette.primaryContainer);

    /*! Generate a tonal M3 palette from a source color.
        Returns { primary, primaryContainer, secondary, secondaryContainer,
                  tertiary, tertiaryContainer, error, errorContainer,
                  surface, surfaceContainer, ... }
        Uses a simplified HCT approximation (HSL-based). */
    function generatePalette(sourceColor) {
        if (!sourceColor) {
            console.warn("generatePalette: no source color, using adapter");
            return null;
        }

        const h = sourceColor.hslHue;
        const s = sourceColor.hslSaturation;
        const l = sourceColor.hslLightness;

        // Tonal keys (M3): primary uses highest chroma at tone 40/80
        // Secondary:  lower chroma, same hue
        // Tertiary:   hue shifted by ~60°, lower chroma
        // Error:      fixed red hue
        // Surface:    neutral greys with hue shift
        const palette = {
            // Primary — full saturation, medium-light
            primary:           Qt.hsla(h, Math.min(1.0, s * 0.9), 0.50, 1.0),
            primaryContainer:  Qt.hsla(h, Math.min(1.0, s * 0.5), 0.30, 1.0),
            primaryFixed:      Qt.hsla(h, Math.min(1.0, s * 0.7), 0.85, 1.0),
            primaryFixedDim:   Qt.hsla(h, Math.min(1.0, s * 0.6), 0.70, 1.0),
            onPrimary:         Qt.hsla(h, 0.0, 0.95, 1.0),
            onPrimaryContainer: Qt.hsla(h, 0.0, 0.85, 1.0),

            // Secondary — desaturated, same hue
            secondary:           Qt.hsla(h, s * 0.3, 0.55, 1.0),
            secondaryContainer:  Qt.hsla(h, s * 0.2, 0.30, 1.0),
            secondaryFixed:      Qt.hsla(h, s * 0.2, 0.85, 1.0),
            secondaryFixedDim:   Qt.hsla(h, s * 0.15, 0.70, 1.0),
            onSecondary:         Qt.hsla(h, 0.0, 0.95, 1.0),
            onSecondaryContainer: Qt.hsla(h, 0.0, 0.85, 1.0),

            // Tertiary — hue shifted +60°, desaturated
            tertiary:           Qt.hsla((h + 0.17) % 1.0, s * 0.25, 0.60, 1.0),
            tertiaryContainer:  Qt.hsla((h + 0.17) % 1.0, s * 0.15, 0.30, 1.0),
            tertiaryFixed:      Qt.hsla((h + 0.17) % 1.0, s * 0.15, 0.85, 1.0),
            tertiaryFixedDim:   Qt.hsla((h + 0.17) % 1.0, s * 0.10, 0.70, 1.0),
            onTertiary:         Qt.hsla(0.0, 0.0, 0.95, 1.0),
            onTertiaryContainer: Qt.hsla(0.0, 0.0, 0.85, 1.0),

            // Error — fixed red hue
            error:              Qt.hsla(0.0, 0.8, 0.55, 1.0),
            errorContainer:     Qt.hsla(0.0, 0.6, 0.25, 1.0),
            onError:            Qt.hsla(0.0, 0.0, 0.95, 1.0),
            onErrorContainer:   Qt.hsla(0.0, 0.0, 0.85, 1.0),

            // Surface hierarchy — neutral with subtle hue tint
            surface:             Qt.hsla(h, 0.03, 0.10, 1.0),
            surfaceDim:          Qt.hsla(h, 0.02, 0.06, 1.0),
            surfaceBright:       Qt.hsla(h, 0.04, 0.25, 1.0),
            surfaceContainer:        Qt.hsla(h, 0.03, 0.14, 1.0),
            surfaceContainerLow:     Qt.hsla(h, 0.02, 0.12, 1.0),
            surfaceContainerLowest:  Qt.hsla(h, 0.02, 0.08, 1.0),
            surfaceContainerHigh:    Qt.hsla(h, 0.04, 0.18, 1.0),
            surfaceContainerHighest: Qt.hsla(h, 0.05, 0.22, 1.0),
            surfaceVariant:      Qt.hsla(h, 0.04, 0.30, 1.0),
            surfaceTint:         Qt.hsla(h, Math.min(1.0, s * 0.9), 0.50, 1.0),

            // On-surface and backgrounds
            onBackground:        Qt.hsla(h, 0.02, 0.92, 1.0),
            onSurface:           Qt.hsla(h, 0.02, 0.92, 1.0),
            onSurfaceVariant:    Qt.hsla(h, 0.03, 0.80, 1.0),
            background:          Qt.hsla(h, 0.02, 0.10, 1.0),
            outline:             Qt.hsla(h, 0.04, 0.55, 1.0),
            outlineVariant:      Qt.hsla(h, 0.03, 0.25, 1.0),
            shadow:              Qt.hsla(0.0, 0.0, 0.0, 1.0),
            scrim:               Qt.hsla(0.0, 0.0, 0.0, 0.6),

            // Light-mode equivalents (for toggling)
            light: {
                primary:           Qt.hsla(h, Math.min(1.0, s * 0.9), 0.40, 1.0),
                secondary:         Qt.hsla(h, s * 0.3, 0.45, 1.0),
                tertiary:          Qt.hsla((h + 0.17) % 1.0, s * 0.25, 0.45, 1.0),
                background:        Qt.hsla(h, 0.02, 0.95, 1.0),
                surface:           Qt.hsla(h, 0.02, 0.93, 1.0),
                onBackground:      Qt.hsla(h, 0.02, 0.08, 1.0),
                onSurface:         Qt.hsla(h, 0.02, 0.08, 1.0)
            }
        };

        return palette;
    }

    /*! Compute luminance of a color (0-1). Useful for dynamic contrast logic. */
    function luminance(color) {
        return (0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b);
    }

    /*! Check if a color is "light" (luminance > 0.5). */
    function isLight(color) {
        return root.luminance(color) > 0.5;
    }

    /*! Blend two colors with alpha (useful for surface tints).
        Equivalent to CSS: rgba(over.r, over.g, over.b, alpha) on top of base. */
    function blend(base, over, alpha) {
        const a = Math.max(0, Math.min(1, alpha));
        return Qt.rgba(
            over.r * a + base.r * (1 - a),
            over.g * a + base.g * (1 - a),
            over.b * a + base.b * (1 - a),
            1.0
        );
    }

    property color criticalText: "#FF6B08"
    property color criticalRed: "#FF0028"

    // Semantic aliases
    property color warning: adapter.yellow
    property color success: adapter.green
    property color info: adapter.secondary
    property color danger: adapter.error

    // List of available color names for color pickers (excludes internal/source colors)
    readonly property var availableColorNames: ["background", "surface", "surfaceBright", "surfaceContainer", "surfaceContainerHigh", "surfaceContainerHighest", "surfaceContainerLow", "surfaceContainerLowest", "surfaceDim", "surfaceTint", "surfaceVariant", "primary", "primaryContainer", "primaryFixed", "primaryFixedDim", "secondary", "secondaryContainer", "secondaryFixed", "secondaryFixedDim", "tertiary", "tertiaryContainer", "tertiaryFixed", "tertiaryFixedDim", "error", "errorContainer", "overBackground", "overSurface", "overSurfaceVariant", "overPrimary", "overPrimaryContainer", "overPrimaryFixed", "overPrimaryFixedVariant", "overSecondary", "overSecondaryContainer", "overSecondaryFixed", "overSecondaryFixedVariant", "overTertiary", "overTertiaryContainer", "overTertiaryFixed", "overTertiaryFixedVariant", "overError", "overErrorContainer", "outline", "outlineVariant", "inversePrimary", "inverseSurface", "inverseOnSurface", "shadow", "scrim", "blue", "blueContainer", "overBlue", "overBlueContainer", "lightBlue", "cyan", "cyanContainer", "overCyan", "overCyanContainer", "lightCyan", "green", "greenContainer", "overGreen", "overGreenContainer", "lightGreen", "magenta", "magentaContainer", "overMagenta", "overMagentaContainer", "lightMagenta", "red", "redContainer", "overRed", "overRedContainer", "lightRed", "yellow", "yellowContainer", "overYellow", "overYellowContainer", "lightYellow", "white", "whiteContainer", "overWhite", "overWhiteContainer"]
}
