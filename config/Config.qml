pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.globals

Singleton {
    id: root

    property alias loader: loader
    property bool initialLoadComplete: false
    property string configPath: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/Ambxst/config.json"

    Process {
        id: checkFile
        running: true
        command: ["sh", "-c", "mkdir -p \"$(dirname '" + configPath + "')\" && test -f \"" + configPath + "\""]

        onExited: exitCode => {
            if (exitCode !== 0) {
                console.log("config.json not found, creating with default values...");
                loader.writeAdapter();
            }
            root.initialLoadComplete = true;
        }
    }

    FileView {
        id: loader
        path: configPath
        atomicWrites: true
        watchChanges: true
        onFileChanged: reload()
        onPathChanged: reload()
        onAdapterUpdated: {
            if (root.initialLoadComplete) {
                loader.writeAdapter();
            }
        }

        adapter: JsonAdapter {
             property JsonObject theme: JsonObject {
                 property bool oledMode: false
                 property bool lightMode: false
                 property real opacity: 1.0
                 property int roundness: 16
                 property int borderSize: 0
                 property string borderColor: "surfaceBright"
                 property string font: "Roboto Condensed"
                 property int fontSize: 14
                 property bool tintIcons: false
                 property string currentTheme: "default"
                 property bool enableCorners: true
                 property int animDuration: 300
                 property real shadowOpacity: 0.5
                 property string shadowColor: "shadow"
                 property int shadowXOffset: 0
                 property int shadowYOffset: 0
                 property real shadowBlur: 1
                 property list<var> bgColor: [["background", 0.0]]
                 property string bgOrientation: "vertical"
                 property list<var> paneColor: [["surface", 0.0]]
                 property string paneOrientation: "vertical"

             }

            property JsonObject bar: JsonObject {
                property string position: "top"
                property string launcherIcon: ""
                property bool showBackground: false
                property real bgOpacity: 0.5
                property string bgColor: "surface"
                property bool verbose: true
                property list<string> screenList: []
                property bool enableFirefoxPlayer: false
                property list<var> barColor: [["surface", 0.0]]
                property string barOrientation: "vertical"
            }

            property JsonObject workspaces: JsonObject {
                property int shown: 10
                property bool showAppIcons: true
                property bool alwaysShowNumbers: false
                property bool showNumbers: false
            }

            property JsonObject overview: JsonObject {
                property int rows: 2
                property int columns: 5
                property real scale: 0.1
                property real workspaceSpacing: 4
            }

            property JsonObject notch: JsonObject {
                property string theme: "default"
            }

            property JsonObject hyprland: JsonObject {
                property list<string> activeBorderColor: ["primary"]
                property int borderAngle: 45
                property list<string> inactiveBorderColor: ["surface"]
                property int inactiveBorderAngle: 45
                property int borderSize: 2
                property int rounding: 16
                property bool syncRoundness: true
                property bool syncBorderWidth: false
                property bool syncBorderColor: false
                property bool syncShadowOpacity: false
                property bool syncShadowColor: false
                property int gapsIn: 2
                property int gapsOut: 4
                property string layout: "dwindle"
                property bool shadowEnabled: true
                property int shadowRange: 8
                property int shadowRenderPower: 3
                property bool shadowSharp: false
                property bool shadowIgnoreWindow: true
                property string shadowColor: "shadow"
                property string shadowColorInactive: "shadow"
                property real shadowOpacity: 0.5
                property string shadowOffset: "0 0"
                property real shadowScale: 1.0
                property bool blurEnabled: true
                property int blurSize: 4
                property int blurPasses: 2
                property bool blurIgnoreOpacity: true
                property bool blurNewOptimizations: true
                property bool blurXray: false
                property real blurNoise: 0.0
                property real blurContrast: 1.0
                property real blurBrightness: 1.0
                property real blurVibrancy: 0.0
                property real blurVibrancyDarkness: 0.0
                property bool blurSpecial: true
                property bool blurPopups: false
                property real blurPopupsIgnorealpha: 0.2
                property bool blurInputMethods: false
                property real blurInputMethodsIgnorealpha: 0.2
            }

             property JsonObject performance: JsonObject {
                 property bool blurTransition: true
                 property bool windowPreview: true
                 property bool wavyLine: true
             }

            property JsonObject weather: JsonObject {
                property string location: ""
                property string unit: "C"
            }

            property JsonObject desktop: JsonObject {
                property bool enabled: false
                property int iconSize: 40
                property int spacingVertical: 16
                property string textColor: "overBackground"
            }
        }
    }

    // Theme configuration
    property QtObject theme: loader.adapter.theme
    property bool oledMode: lightMode ? false : theme.oledMode
    property bool lightMode: theme.lightMode
    property real opacity: Math.min(Math.max(theme.opacity, 0.1), 1.0)
    property int roundness: theme.roundness
    property string defaultFont: theme.font
    property string currentTheme: theme.currentTheme
    property int animDuration: theme.animDuration
    property bool tintIcons: theme.tintIcons

    // Detectar cambios en lightMode y ejecutar Matugen
    onLightModeChanged: {
        console.log("lightMode changed to:", lightMode);
        // Ejecutar Matugen con el wallpaper actual si existe un wallpaper manager
        if (GlobalStates.wallpaperManager) {
            var wallpaperManager = GlobalStates.wallpaperManager;
            if (wallpaperManager.currentWallpaper) {
                console.log("Re-running Matugen due to lightMode change");
                wallpaperManager.runMatugenForCurrentWallpaper();
            }
        }
    }

    // Bar configuration
    property QtObject bar: loader.adapter.bar
    property real bgOpacity: Math.min(Math.max(bar.opacity, 0.1), 1.0)

    // Workspace configuration
    property QtObject workspaces: loader.adapter.workspaces

    // Overview configuration
    property QtObject overview: loader.adapter.overview

    // Notch configuration
    property QtObject notch: loader.adapter.notch
    property string notchTheme: notch.theme

    // Hyprland configuration
    property QtObject hyprland: loader.adapter.hyprland
    property int hyprlandRounding: hyprland.syncRoundness ? Math.max(0, roundness - hyprlandBorderSize) : Math.max(0, hyprland.rounding - hyprland.borderSize)
    property int hyprlandBorderSize: hyprland.syncBorderWidth ? theme.borderSize : hyprland.borderSize
    property string hyprlandBorderColor: hyprland.syncBorderColor ? theme.borderColor : (hyprland.activeBorderColor.length > 0 ? hyprland.activeBorderColor[0] : "primary")
    property real hyprlandShadowOpacity: hyprland.syncShadowOpacity ? theme.shadowOpacity : hyprland.shadowOpacity
    property string hyprlandShadowColor: hyprland.syncShadowColor ? theme.shadowColor : hyprland.shadowColor

    // Performance configuration
    property QtObject performance: loader.adapter.performance
    property bool blurTransition: performance.blurTransition

    // Weather configuration
    property QtObject weather: loader.adapter.weather

    // Desktop configuration
    property QtObject desktop: loader.adapter.desktop
}
