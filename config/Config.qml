pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.globals
import qs.modules.theme
import qs.modules.services as Services
import "defaults/theme.js" as ThemeDefaults
import "defaults/bar.js" as BarDefaults
import "defaults/workspaces.js" as WorkspacesDefaults
import "defaults/overview.js" as OverviewDefaults
import "defaults/notch.js" as NotchDefaults
import "defaults/hyprland.js" as HyprlandDefaults
import "defaults/performance.js" as PerformanceDefaults
import "defaults/weather.js" as WeatherDefaults
import "defaults/desktop.js" as DesktopDefaults
import "defaults/lockscreen.js" as LockscreenDefaults
import "defaults/prefix.js" as PrefixDefaults
import "defaults/system.js" as SystemDefaults
import "defaults/dock.js" as DockDefaults
import "defaults/ai.js" as AiDefaults
import "ConfigValidator.js" as ConfigValidator

Singleton {
    id: root

    property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/Ambxst/config"
    property string keybindsPath: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/Ambxst/binds.json"

    property bool pauseAutoSave: false

    // Track initialization of all modules
    property bool themeReady: false
    property bool barReady: false
    property bool workspacesReady: false
    property bool overviewReady: false
    property bool notchReady: false
    property bool hyprlandReady: false
    property bool performanceReady: false
    property bool weatherReady: false
    property bool desktopReady: false
    property bool lockscreenReady: false
    property bool prefixReady: false
    property bool systemReady: false
    property bool dockReady: false
    property bool aiReady: false
    property bool keybindsInitialLoadComplete: false

    property bool initialLoadComplete: themeReady && barReady && workspacesReady && overviewReady && notchReady && hyprlandReady && performanceReady && weatherReady && desktopReady && lockscreenReady && prefixReady && systemReady && dockReady && aiReady

    // Aliases for backward compatibility
    property alias loader: themeLoader
    property alias keybindsLoader: keybindsLoader

    // ============================================
    // BATCH INITIALIZATION
    // ============================================
    // Single process to check environment and all config files at once
    Process {
        id: initConfigs
        running: true
        command: ["bash", "-c", `
            mkdir -p "${root.configDir}"
            cd "${root.configDir}"
            MISSING=""
            [ ! -f theme.json ] && MISSING="$MISSING theme"
            [ ! -f bar.json ] && MISSING="$MISSING bar"
            [ ! -f workspaces.json ] && MISSING="$MISSING workspaces"
            [ ! -f overview.json ] && MISSING="$MISSING overview"
            [ ! -f notch.json ] && MISSING="$MISSING notch"
            [ ! -f hyprland.json ] && MISSING="$MISSING hyprland"
            [ ! -f performance.json ] && MISSING="$MISSING performance"
            [ ! -f weather.json ] && MISSING="$MISSING weather"
            [ ! -f desktop.json ] && MISSING="$MISSING desktop"
            [ ! -f lockscreen.json ] && MISSING="$MISSING lockscreen"
            [ ! -f prefix.json ] && MISSING="$MISSING prefix"
            [ ! -f system.json ] && MISSING="$MISSING system"
            [ ! -f dock.json ] && MISSING="$MISSING dock"
            [ ! -f ai.json ] && MISSING="$MISSING ai"
            echo "$MISSING"
        `]

        stdout: StdioCollector {
            onStreamFinished: {
                const missing = text.trim().split(" ");
                if (missing.includes("theme")) {
                    console.log("theme.json missing, creating default...");
                    themeRawLoader.setText(JSON.stringify(ThemeDefaults.data, null, 4));
                    root.themeReady = true;
                }
                if (missing.includes("bar")) {
                    console.log("bar.json missing, creating default...");
                    barRawLoader.setText(JSON.stringify(BarDefaults.data, null, 4));
                    root.barReady = true;
                }
                if (missing.includes("workspaces")) {
                    console.log("workspaces.json missing, creating default...");
                    workspacesRawLoader.setText(JSON.stringify(WorkspacesDefaults.data, null, 4));
                    root.workspacesReady = true;
                }
                if (missing.includes("overview")) {
                    console.log("overview.json missing, creating default...");
                    overviewRawLoader.setText(JSON.stringify(OverviewDefaults.data, null, 4));
                    root.overviewReady = true;
                }
                if (missing.includes("notch")) {
                    console.log("notch.json missing, creating default...");
                    notchRawLoader.setText(JSON.stringify(NotchDefaults.data, null, 4));
                    root.notchReady = true;
                }
                if (missing.includes("hyprland")) {
                    console.log("hyprland.json missing, creating default...");
                    hyprlandRawLoader.setText(JSON.stringify(HyprlandDefaults.data, null, 4));
                    root.hyprlandReady = true;
                }
                if (missing.includes("performance")) {
                    console.log("performance.json missing, creating default...");
                    performanceRawLoader.setText(JSON.stringify(PerformanceDefaults.data, null, 4));
                    root.performanceReady = true;
                }
                if (missing.includes("weather")) {
                    console.log("weather.json missing, creating default...");
                    weatherRawLoader.setText(JSON.stringify(WeatherDefaults.data, null, 4));
                    root.weatherReady = true;
                }
                if (missing.includes("desktop")) {
                    console.log("desktop.json missing, creating default...");
                    desktopRawLoader.setText(JSON.stringify(DesktopDefaults.data, null, 4));
                    root.desktopReady = true;
                }
                if (missing.includes("lockscreen")) {
                    console.log("lockscreen.json missing, creating default...");
                    lockscreenRawLoader.setText(JSON.stringify(LockscreenDefaults.data, null, 4));
                    root.lockscreenReady = true;
                }
                if (missing.includes("prefix")) {
                    console.log("prefix.json missing, creating default...");
                    prefixRawLoader.setText(JSON.stringify(PrefixDefaults.data, null, 4));
                    root.prefixReady = true;
                }
                if (missing.includes("system")) {
                    console.log("system.json missing, creating default...");
                    systemRawLoader.setText(JSON.stringify(SystemDefaults.data, null, 4));
                    root.systemReady = true;
                }
                if (missing.includes("dock")) {
                    console.log("dock.json missing, creating default...");
                    dockRawLoader.setText(JSON.stringify(DockDefaults.data, null, 4));
                    root.dockReady = true;
                }
                if (missing.includes("ai")) {
                    console.log("ai.json missing, creating default...");
                    aiRawLoader.setText(JSON.stringify(AiDefaults.data, null, 4));
                    root.aiReady = true;
                }
            }
        }
    }

    // ============================================
    // THEME MODULE
    // ============================================
    FileView {
        id: themeRawLoader
        path: root.configDir + "/theme.json"
        onLoaded: {
            if (!root.themeReady) {
                validateModule("theme", themeRawLoader, ThemeDefaults.data, () => {
                    root.themeReady = true;
                });
            }
        }
    }

    FileView {
        id: themeLoader
        path: root.configDir + "/theme.json"
        atomicWrites: true
        watchChanges: true
        onFileChanged: {
            root.pauseAutoSave = true;
            reload();
            root.pauseAutoSave = false;
        }
        onPathChanged: reload()
        onAdapterUpdated: {
            if (root.themeReady && !root.pauseAutoSave) {
                themeLoader.writeAdapter();
            }
        }

        adapter: JsonAdapter {
            property bool oledMode: false
            property bool lightMode: false
            property int roundness: 16
            property string font: "Roboto Condensed"
            property int fontSize: 14
            property string monoFont: "Iosevka Nerd Font Mono"
            property int monoFontSize: 14
            property bool tintIcons: false
            property bool enableCorners: true
            property int animDuration: 300
            property real shadowOpacity: 0.5
            property string shadowColor: "shadow"
            property int shadowXOffset: 0
            property int shadowYOffset: 0
            property real shadowBlur: 1

            property JsonObject srBg: JsonObject {
                property string label: "Background"
                property list<var> gradient: [["background", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "surface"
                property string halftoneBackgroundColor: "background"
                property list<var> border: ["surfaceBright", 0]
                property string itemColor: "overBackground"
                property real opacity: 1.0
            }

            property JsonObject srPopup: JsonObject {
                property string label: "Popup"
                property list<var> gradient: [["background", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "surface"
                property string halftoneBackgroundColor: "background"
                property list<var> border: ["surfaceBright", 2]
                property string itemColor: "overBackground"
                property real opacity: 1.0
            }

            property JsonObject srInternalBg: JsonObject {
                property string label: "Internal BG"
                property list<var> gradient: [["background", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "surface"
                property string halftoneBackgroundColor: "background"
                property list<var> border: ["surfaceBright", 0]
                property string itemColor: "overBackground"
                property real opacity: 1.0
            }

            property JsonObject srBarBg: JsonObject {
                property string label: "Bar BG"
                property list<var> gradient: [["surfaceDim", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "surface"
                property string halftoneBackgroundColor: "surfaceDim"
                property list<var> border: ["surfaceBright", 0]
                property string itemColor: "overBackground"
                property real opacity: 0.0
            }

            property JsonObject srPane: JsonObject {
                property string label: "Pane"
                property list<var> gradient: [["surface", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "surfaceBright"
                property string halftoneBackgroundColor: "surface"
                property list<var> border: ["surfaceBright", 0]
                property string itemColor: "overBackground"
                property real opacity: 1.0
            }

            property JsonObject srCommon: JsonObject {
                property string label: "Common"
                property list<var> gradient: [["surface", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "background"
                property string halftoneBackgroundColor: "surface"
                property list<var> border: ["surfaceBright", 0]
                property string itemColor: "overBackground"
                property real opacity: 1.0
            }

            property JsonObject srFocus: JsonObject {
                property string label: "Focus"
                property list<var> gradient: [["surfaceBright", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "surfaceVariant"
                property string halftoneBackgroundColor: "surfaceBright"
                property list<var> border: ["surfaceBright", 0]
                property string itemColor: "overBackground"
                property real opacity: 1.0
            }

            property JsonObject srPrimary: JsonObject {
                property string label: "Primary"
                property list<var> gradient: [["primary", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "overPrimaryContainer"
                property string halftoneBackgroundColor: "primary"
                property list<var> border: ["primary", 0]
                property string itemColor: "overPrimary"
                property real opacity: 1.0
            }

            property JsonObject srPrimaryFocus: JsonObject {
                property string label: "Primary Focus"
                property list<var> gradient: [["overPrimaryContainer", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "primary"
                property string halftoneBackgroundColor: "overPrimaryContainer"
                property list<var> border: ["overBackground", 0]
                property string itemColor: "overPrimary"
                property real opacity: 1.0
            }

            property JsonObject srOverPrimary: JsonObject {
                property string label: "Over Primary"
                property list<var> gradient: [["overPrimary", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "primaryContainer"
                property string halftoneBackgroundColor: "overPrimary"
                property list<var> border: ["overPrimary", 0]
                property string itemColor: "primary"
                property real opacity: 1.0
            }

            property JsonObject srSecondary: JsonObject {
                property string label: "Secondary"
                property list<var> gradient: [["secondary", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "overSecondaryContainer"
                property string halftoneBackgroundColor: "secondary"
                property list<var> border: ["secondary", 0]
                property string itemColor: "overSecondary"
                property real opacity: 1.0
            }

            property JsonObject srSecondaryFocus: JsonObject {
                property string label: "Secondary Focus"
                property list<var> gradient: [["overSecondaryContainer", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "secondary"
                property string halftoneBackgroundColor: "overSecondaryContainer"
                property list<var> border: ["overBackground", 0]
                property string itemColor: "overSecondary"
                property real opacity: 1.0
            }

            property JsonObject srOverSecondary: JsonObject {
                property string label: "Over Secondary"
                property list<var> gradient: [["overSecondary", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "secondaryContainer"
                property string halftoneBackgroundColor: "overSecondary"
                property list<var> border: ["overSecondary", 0]
                property string itemColor: "secondary"
                property real opacity: 1.0
            }

            property JsonObject srTertiary: JsonObject {
                property string label: "Tertiary"
                property list<var> gradient: [["tertiary", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "overTertiaryContainer"
                property string halftoneBackgroundColor: "tertiary"
                property list<var> border: ["tertiary", 0]
                property string itemColor: "overTertiary"
                property real opacity: 1.0
            }

            property JsonObject srTertiaryFocus: JsonObject {
                property string label: "Tertiary Focus"
                property list<var> gradient: [["overTertiaryContainer", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "tertiary"
                property string halftoneBackgroundColor: "overTertiaryContainer"
                property list<var> border: ["overBackground", 0]
                property string itemColor: "overTertiary"
                property real opacity: 1.0
            }

            property JsonObject srOverTertiary: JsonObject {
                property string label: "Over Tertiary"
                property list<var> gradient: [["overTertiary", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "tertiaryContainer"
                property string halftoneBackgroundColor: "overTertiary"
                property list<var> border: ["overTertiary", 0]
                property string itemColor: "tertiary"
                property real opacity: 1.0
            }

            property JsonObject srError: JsonObject {
                property string label: "Error"
                property list<var> gradient: [["error", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "overErrorContainer"
                property string halftoneBackgroundColor: "error"
                property list<var> border: ["error", 0]
                property string itemColor: "overError"
                property real opacity: 1.0
            }

            property JsonObject srErrorFocus: JsonObject {
                property string label: "Error Focus"
                property list<var> gradient: [["overBackground", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "error"
                property string halftoneBackgroundColor: "overErrorContainer"
                property list<var> border: ["overBackground", 0]
                property string itemColor: "overError"
                property real opacity: 1.0
            }

            property JsonObject srOverError: JsonObject {
                property string label: "Over Error"
                property list<var> gradient: [["overError", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "errorContainer"
                property string halftoneBackgroundColor: "overError"
                property list<var> border: ["overError", 0]
                property string itemColor: "error"
                property real opacity: 1.0
            }
        }
    }

    // ============================================
    // BAR MODULE
    // ============================================
    FileView {
        id: barRawLoader
        path: root.configDir + "/bar.json"
        onLoaded: {
            if (!root.barReady) {
                validateModule("bar", barRawLoader, BarDefaults.data, () => {
                    root.barReady = true;
                });
            }
        }
    }

    FileView {
        id: barLoader
        path: root.configDir + "/bar.json"
        atomicWrites: true
        watchChanges: true
        onFileChanged: {
            root.pauseAutoSave = true;
            reload();
            root.pauseAutoSave = false;
        }
        onPathChanged: reload()
        onAdapterUpdated: {
            if (root.barReady && !root.pauseAutoSave) {
                barLoader.writeAdapter();
            }
        }

        adapter: JsonAdapter {
            property string position: "top"
            property string launcherIcon: ""
            property bool launcherIconTint: true
            property bool launcherIconFullTint: true
            property int launcherIconSize: 24
            property list<string> screenList: []
            property bool enableFirefoxPlayer: false
            property list<var> barColor: [["surface", 0.0]]
            // Auto-hide properties
            property bool pinnedOnStartup: true
            property bool hoverToReveal: true
            property int hoverRegionHeight: 8
            property bool showPinButton: true
            property bool availableOnFullscreen: false
        }
    }

    // ============================================
    // WORKSPACES MODULE
    // ============================================
    FileView {
        id: workspacesRawLoader
        path: root.configDir + "/workspaces.json"
        onLoaded: {
            if (!root.workspacesReady) {
                validateModule("workspaces", workspacesRawLoader, WorkspacesDefaults.data, () => {
                    root.workspacesReady = true;
                });
            }
        }
    }

    FileView {
        id: workspacesLoader
        path: root.configDir + "/workspaces.json"
        atomicWrites: true
        watchChanges: true
        onFileChanged: {
            root.pauseAutoSave = true;
            reload();
            root.pauseAutoSave = false;
        }
        onPathChanged: reload()
        onAdapterUpdated: {
            if (root.workspacesReady && !root.pauseAutoSave) {
                workspacesLoader.writeAdapter();
            }
        }

        adapter: JsonAdapter {
            property int shown: 10
            property bool showAppIcons: true
            property bool alwaysShowNumbers: false
            property bool showNumbers: false
            property bool dynamic: false
        }
    }

    // ============================================
    // OVERVIEW MODULE
    // ============================================
    FileView {
        id: overviewRawLoader
        path: root.configDir + "/overview.json"
        onLoaded: {
            if (!root.overviewReady) {
                validateModule("overview", overviewRawLoader, OverviewDefaults.data, () => {
                    root.overviewReady = true;
                });
            }
        }
    }

    FileView {
        id: overviewLoader
        path: root.configDir + "/overview.json"
        atomicWrites: true
        watchChanges: true
        onFileChanged: {
            root.pauseAutoSave = true;
            reload();
            root.pauseAutoSave = false;
        }
        onPathChanged: reload()
        onAdapterUpdated: {
            if (root.overviewReady && !root.pauseAutoSave) {
                overviewLoader.writeAdapter();
            }
        }

        adapter: JsonAdapter {
            property int rows: 2
            property int columns: 5
            property real scale: 0.1
            property real workspaceSpacing: 4
        }
    }

    // ============================================
    // NOTCH MODULE
    // ============================================
    FileView {
        id: notchRawLoader
        path: root.configDir + "/notch.json"
        onLoaded: {
            if (!root.notchReady) {
                validateModule("notch", notchRawLoader, NotchDefaults.data, () => {
                    root.notchReady = true;
                });
            }
        }
    }

    FileView {
        id: notchLoader
        path: root.configDir + "/notch.json"
        atomicWrites: true
        watchChanges: true
        onFileChanged: {
            root.pauseAutoSave = true;
            reload();
            root.pauseAutoSave = false;
        }
        onPathChanged: reload()
        onAdapterUpdated: {
            if (root.notchReady && !root.pauseAutoSave) {
                notchLoader.writeAdapter();
            }
        }

        adapter: JsonAdapter {
            property string theme: "default"
            property int hoverRegionHeight: 8
        }
    }

    // ============================================
    // HYPRLAND MODULE
    // ============================================
    FileView {
        id: hyprlandRawLoader
        path: root.configDir + "/hyprland.json"
        onLoaded: {
            if (!root.hyprlandReady) {
                validateModule("hyprland", hyprlandRawLoader, HyprlandDefaults.data, () => {
                    root.hyprlandReady = true;
                });
            }
        }
    }

    FileView {
        id: hyprlandLoader
        path: root.configDir + "/hyprland.json"
        atomicWrites: true
        watchChanges: true
        onFileChanged: {
            root.pauseAutoSave = true;
            reload();
            root.pauseAutoSave = false;
        }
        onPathChanged: reload()
        onAdapterUpdated: {
            if (root.hyprlandReady && !root.pauseAutoSave) {
                hyprlandLoader.writeAdapter();
            }
        }

        adapter: JsonAdapter {
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
            property bool blurExplicitIgnoreAlpha: false
            property real blurIgnoreAlphaValue: 0.2
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
    }

    // ============================================
    // PERFORMANCE MODULE
    // ============================================
    FileView {
        id: performanceRawLoader
        path: root.configDir + "/performance.json"
        onLoaded: {
            if (!root.performanceReady) {
                validateModule("performance", performanceRawLoader, PerformanceDefaults.data, () => {
                    root.performanceReady = true;
                });
            }
        }
    }

    FileView {
        id: performanceLoader
        path: root.configDir + "/performance.json"
        atomicWrites: true
        watchChanges: true
        onFileChanged: {
            root.pauseAutoSave = true;
            reload();
            root.pauseAutoSave = false;
        }
        onPathChanged: reload()
        onAdapterUpdated: {
            if (root.performanceReady && !root.pauseAutoSave) {
                performanceLoader.writeAdapter();
            }
        }

        adapter: JsonAdapter {
            property bool blurTransition: true
            property bool windowPreview: true
            property bool wavyLine: true
        }
    }

    // ============================================
    // WEATHER MODULE
    // ============================================
    FileView {
        id: weatherRawLoader
        path: root.configDir + "/weather.json"
        onLoaded: {
            if (!root.weatherReady) {
                validateModule("weather", weatherRawLoader, WeatherDefaults.data, () => {
                    root.weatherReady = true;
                });
            }
        }
    }

    FileView {
        id: weatherLoader
        path: root.configDir + "/weather.json"
        atomicWrites: true
        watchChanges: true
        onFileChanged: {
            root.pauseAutoSave = true;
            reload();
            root.pauseAutoSave = false;
        }
        onPathChanged: reload()
        onAdapterUpdated: {
            if (root.weatherReady && !root.pauseAutoSave) {
                weatherLoader.writeAdapter();
            }
        }

        adapter: JsonAdapter {
            property string location: ""
            property string unit: "C"
        }
    }

    // ============================================
    // DESKTOP MODULE
    // ============================================
    FileView {
        id: desktopRawLoader
        path: root.configDir + "/desktop.json"
        onLoaded: {
            if (!root.desktopReady) {
                validateModule("desktop", desktopRawLoader, DesktopDefaults.data, () => {
                    root.desktopReady = true;
                });
            }
        }
    }

    FileView {
        id: desktopLoader
        path: root.configDir + "/desktop.json"
        atomicWrites: true
        watchChanges: true
        onFileChanged: {
            root.pauseAutoSave = true;
            reload();
            root.pauseAutoSave = false;
        }
        onPathChanged: reload()
        onAdapterUpdated: {
            if (root.desktopReady && !root.pauseAutoSave) {
                desktopLoader.writeAdapter();
            }
        }

        adapter: JsonAdapter {
            property bool enabled: false
            property int iconSize: 40
            property int spacingVertical: 16
            property string textColor: "overBackground"
        }
    }

    // ============================================
    // LOCKSCREEN MODULE
    // ============================================
    FileView {
        id: lockscreenRawLoader
        path: root.configDir + "/lockscreen.json"
        onLoaded: {
            if (!root.lockscreenReady) {
                validateModule("lockscreen", lockscreenRawLoader, LockscreenDefaults.data, () => {
                    root.lockscreenReady = true;
                });
            }
        }
    }

    FileView {
        id: lockscreenLoader
        path: root.configDir + "/lockscreen.json"
        atomicWrites: true
        watchChanges: true
        onFileChanged: {
            root.pauseAutoSave = true;
            reload();
            root.pauseAutoSave = false;
        }
        onPathChanged: reload()
        onAdapterUpdated: {
            if (root.lockscreenReady && !root.pauseAutoSave) {
                lockscreenLoader.writeAdapter();
            }
        }

        adapter: JsonAdapter {
            property string position: "bottom"
        }
    }

    // ============================================
    // PREFIX MODULE
    // ============================================
    FileView {
        id: prefixRawLoader
        path: root.configDir + "/prefix.json"
        onLoaded: {
            if (!root.prefixReady) {
                validateModule("prefix", prefixRawLoader, PrefixDefaults.data, () => {
                    root.prefixReady = true;
                });
            }
        }
    }

    FileView {
        id: prefixLoader
        path: root.configDir + "/prefix.json"
        atomicWrites: true
        watchChanges: true
        onFileChanged: {
            root.pauseAutoSave = true;
            reload();
            root.pauseAutoSave = false;
        }
        onPathChanged: reload()
        onAdapterUpdated: {
            if (root.prefixReady && !root.pauseAutoSave) {
                prefixLoader.writeAdapter();
            }
        }

        adapter: JsonAdapter {
            property string clipboard: "cc"
            property string emoji: "ee"
            property string tmux: "tt"
            property string wallpapers: "ww"
            property string notes: "nn"
        }
    }

    // ============================================
    // SYSTEM MODULE
    // ============================================
    FileView {
        id: systemRawLoader
        path: root.configDir + "/system.json"
        onLoaded: {
            if (!root.systemReady) {
                validateModule("system", systemRawLoader, SystemDefaults.data, () => {
                    root.systemReady = true;
                });
            }
        }
    }

    FileView {
        id: systemLoader
        path: root.configDir + "/system.json"
        atomicWrites: true
        watchChanges: true
        onFileChanged: {
            root.pauseAutoSave = true;
            reload();
            root.pauseAutoSave = false;
        }
        onPathChanged: reload()
        onAdapterUpdated: {
            if (root.systemReady && !root.pauseAutoSave) {
                systemLoader.writeAdapter();
            }
        }

        adapter: JsonAdapter {
            property list<string> disks: ["/"]
            property bool superKeyLauncher: true
            property JsonObject idle: JsonObject {
                property JsonObject general: JsonObject {
                    property string lock_cmd: "ambxst lock"
                    property string before_sleep_cmd: "loginctl lock-session"
                    property string after_sleep_cmd: "ambxst screen on"
                }
                property list<var> listeners: [
                    {
                        "timeout": 150,
                        "onTimeout": "ambxst brightness 10 -s",
                        "onResume": "ambxst brightness -r"
                    },
                    {
                        "timeout": 300,
                        "onTimeout": "loginctl lock-session"
                    },
                    {
                        "timeout": 330,
                        "onTimeout": "ambxst screen off",
                        "onResume": "ambxst screen on"
                    },
                    {
                        "timeout": 1800,
                        "onTimeout": "ambxst suspend"
                    }
                ]
            }
            property JsonObject ocr: JsonObject {
                property bool eng: true
                property bool spa: true
                property bool lat: false
                property bool jpn: false
                property bool chi_sim: false
                property bool chi_tra: false
                property bool kor: false
            }
        }
    }

    // ============================================
    // DOCK MODULE
    // ============================================
    FileView {
        id: dockRawLoader
        path: root.configDir + "/dock.json"
        onLoaded: {
            if (!root.dockReady) {
                validateModule("dock", dockRawLoader, DockDefaults.data, () => {
                    root.dockReady = true;
                });
            }
        }
    }

    FileView {
        id: dockLoader
        path: root.configDir + "/dock.json"
        atomicWrites: true
        watchChanges: true
        onFileChanged: {
            root.pauseAutoSave = true;
            reload();
            root.pauseAutoSave = false;
        }
        onPathChanged: reload()
        onAdapterUpdated: {
            if (root.dockReady && !root.pauseAutoSave) {
                dockLoader.writeAdapter();
            }
        }

        adapter: JsonAdapter {
            property bool enabled: false
            property string theme: "default"
            property string position: "bottom"
            property int height: 56
            property int iconSize: 40
            property int spacing: 4
            property int margin: 8
            property int hoverRegionHeight: 4
            property bool pinnedOnStartup: false
            property bool hoverToReveal: true
            property bool showRunningIndicators: true
            property bool showPinButton: true
            property bool showOverviewButton: true
            property list<string> ignoredAppRegexes: ["quickshell.*", "xdg-desktop-portal.*"]
            property list<string> screenList: []
        }
    }

    // ============================================
    // PINNED APPS (stored in dataPath for per-user data)
    // ============================================
    property bool pinnedAppsReady: false

    Process {
        id: checkPinnedAppsFile
        running: true
        command: ["test", "-f", Quickshell.dataPath("pinnedapps.json")]

        onExited: exitCode => {
            if (exitCode !== 0) {
                console.log("pinnedapps.json not found, creating with default values...");
                pinnedAppsLoader.writeAdapter();
            }
            root.pinnedAppsReady = true;
        }
    }

    FileView {
        id: pinnedAppsLoader
        path: Quickshell.dataPath("pinnedapps.json")
        atomicWrites: true
        watchChanges: true
        onFileChanged: {
            root.pauseAutoSave = true;
            reload();
            root.pauseAutoSave = false;
        }
        onPathChanged: reload()
        onAdapterUpdated: {
            if (root.pinnedAppsReady && !root.pauseAutoSave) {
                pinnedAppsLoader.writeAdapter();
            }
        }

        adapter: JsonAdapter {
            property list<string> apps: ["kitty"]
        }
    }

    // ============================================
    // AI MODULE
    // ============================================
    FileView {
        id: aiRawLoader
        path: root.configDir + "/ai.json"
        onLoaded: {
            if (!root.aiReady) {
                validateModule("ai", aiRawLoader, AiDefaults.data, () => {
                    root.aiReady = true;
                });
            }
        }
    }

    FileView {
        id: aiLoader
        path: root.configDir + "/ai.json"
        atomicWrites: true
        watchChanges: true
        onFileChanged: {
            root.pauseAutoSave = true;
            reload();
            root.pauseAutoSave = false;
        }
        onPathChanged: reload()
        onAdapterUpdated: {
            if (root.aiReady && !root.pauseAutoSave) {
                aiLoader.writeAdapter();
            }
        }

        adapter: JsonAdapter {
            property string systemPrompt: "You are a helpful assistant running on a Linux system. You have access to some tools to control the system."
            property string tool: "none"
            property list<var> extraModels: []
            property string defaultModel: "gemini-pro"
        }
    }

    // ============================================
    // KEYBINDS (kept separate as binds.json)
    // ============================================
    Process {
        id: checkKeybindsFile
        running: true
        command: ["sh", "-c", "mkdir -p \"$(dirname '" + keybindsPath + "')\" && test -f \"" + keybindsPath + "\""]

        onExited: exitCode => {
            if (exitCode !== 0) {
                console.log("binds.json not found, creating with default values...");
                keybindsLoader.writeAdapter();
            } else {
                // File exists, check if it needs repair
                repairKeybindsTimer.start();
            }
            root.keybindsInitialLoadComplete = true;
        }
    }

    // Timer to repair keybinds after initial load
    Timer {
        id: repairKeybindsTimer
        interval: 500
        repeat: false
        onTriggered: {
            if (keybindsRawLoader.status === FileView.Ready) {
                repairKeybinds();
            }
        }
    }

    // Raw loader to check and repair binds.json
    FileView {
        id: keybindsRawLoader
        path: keybindsPath
    }

    // Function to repair missing binds
    function repairKeybinds() {
        const raw = keybindsRawLoader.text();
        if (!raw) return;

        try {
            const current = JSON.parse(raw);
            let needsUpdate = false;

            // Ensure ambxst structure exists
            if (!current.ambxst) {
                current.ambxst = {};
                needsUpdate = true;
            }
            if (!current.ambxst.dashboard) {
                current.ambxst.dashboard = {};
                needsUpdate = true;
            }
            if (!current.ambxst.system) {
                current.ambxst.system = {};
                needsUpdate = true;
            }

            // Get default binds from adapter
            const adapter = keybindsLoader.adapter;
            if (!adapter || !adapter.ambxst) return;

            // Helper function to create clean bind object
            function createCleanBind(bindObj) {
                return {
                    "modifiers": bindObj.modifiers || [],
                    "key": bindObj.key || "",
                    "dispatcher": bindObj.dispatcher || "",
                    "argument": bindObj.argument || ""
                };
            }

            // Check dashboard binds
            const dashboardKeys = ["assistant", "clipboard", "emoji", "notes", "tmux", "wallpapers", "widgets"];
            for (const key of dashboardKeys) {
                if (!current.ambxst.dashboard[key] && adapter.ambxst.dashboard && adapter.ambxst.dashboard[key]) {
                    console.log("Adding missing dashboard bind:", key);
                    current.ambxst.dashboard[key] = createCleanBind(adapter.ambxst.dashboard[key]);
                    needsUpdate = true;
                }
            }

            // Check system binds
            const systemKeys = ["overview", "powermenu", "config", "lockscreen", "tools", "screenshot", "screenrecord", "lens"];
            for (const key of systemKeys) {
                if (!current.ambxst.system[key] && adapter.ambxst.system && adapter.ambxst.system[key]) {
                    console.log("Adding missing system bind:", key);
                    current.ambxst.system[key] = createCleanBind(adapter.ambxst.system[key]);
                    needsUpdate = true;
                }
            }

            if (needsUpdate) {
                console.log("Auto-repairing binds.json: adding missing binds");
                keybindsRawLoader.setText(JSON.stringify(current, null, 4));
            }
        } catch (e) {
            console.warn("Failed to repair binds.json:", e);
        }
    }

    FileView {
        id: keybindsLoader
        path: keybindsPath
        atomicWrites: true
        watchChanges: true
        onFileChanged: {
            root.pauseAutoSave = true;
            reload();
            normalizeCustomBinds();
            root.pauseAutoSave = false;
        }
        onPathChanged: {
            reload();
            normalizeCustomBinds();
        }
        onAdapterUpdated: {
            if (root.keybindsInitialLoadComplete) {
                keybindsLoader.writeAdapter();
            }
        }

        // Normalize custom binds to new format with keys[], actions[] and compositor
        function normalizeCustomBinds() {
            if (!adapter || !adapter.custom)
                return;

            let needsUpdate = false;
            let normalizedBinds = [];

            for (let i = 0; i < adapter.custom.length; i++) {
                let bind = adapter.custom[i];

                // Check if it's old format (has modifiers/key instead of keys[])
                if (bind.keys === undefined || bind.actions === undefined) {
                    needsUpdate = true;
                    normalizedBinds.push({
                        "name": bind.name || "",
                        "keys": [
                            {
                                "modifiers": bind.modifiers || [],
                                "key": bind.key || ""
                            }
                        ],
                        "actions": [
                            {
                                "dispatcher": bind.dispatcher || "",
                                "argument": bind.argument || "",
                                "flags": bind.flags || "",
                                "compositor": {
                                    "type": "hyprland",
                                    "layouts": []
                                }
                            }
                        ],
                        "enabled": bind.enabled !== false
                    });
                } else {
                    // Check if actions need compositor field added
                    let actionsNeedUpdate = false;
                    let normalizedActions = [];

                    for (let a = 0; a < bind.actions.length; a++) {
                        let action = bind.actions[a];
                        if (action.compositor === undefined) {
                            actionsNeedUpdate = true;
                            normalizedActions.push({
                                "dispatcher": action.dispatcher || "",
                                "argument": action.argument || "",
                                "flags": action.flags || "",
                                "compositor": {
                                    "type": "hyprland",
                                    "layouts": []
                                }
                            });
                        } else {
                            normalizedActions.push(action);
                        }
                    }

                    if (actionsNeedUpdate) {
                        needsUpdate = true;
                        normalizedBinds.push({
                            "name": bind.name || "",
                            "keys": bind.keys,
                            "actions": normalizedActions,
                            "enabled": bind.enabled !== false
                        });
                    } else {
                        normalizedBinds.push(bind);
                    }
                }
            }

            if (needsUpdate) {
                console.log("Normalizing custom binds: migrating to new keys/actions/compositor format");
                adapter.custom = normalizedBinds;
            }
        }

        adapter: JsonAdapter {
            property JsonObject ambxst: JsonObject {
                property JsonObject dashboard: JsonObject {
                    property JsonObject assistant: JsonObject {
                        property list<string> modifiers: ["SUPER"]
                        property string key: "A"
                        property string dispatcher: "global"
                        property string argument: "ambxst:dashboard-assistant"
                    }
                    property JsonObject clipboard: JsonObject {
                        property list<string> modifiers: ["SUPER"]
                        property string key: "V"
                        property string dispatcher: "global"
                        property string argument: "ambxst:dashboard-clipboard"
                    }
                    property JsonObject emoji: JsonObject {
                        property list<string> modifiers: ["SUPER"]
                        property string key: "PERIOD"
                        property string dispatcher: "global"
                        property string argument: "ambxst:dashboard-emoji"
                    }
                    property JsonObject notes: JsonObject {
                        property list<string> modifiers: ["SUPER"]
                        property string key: "N"
                        property string dispatcher: "global"
                        property string argument: "ambxst:dashboard-notes"
                    }
                    property JsonObject tmux: JsonObject {
                        property list<string> modifiers: ["SUPER"]
                        property string key: "T"
                        property string dispatcher: "global"
                        property string argument: "ambxst:dashboard-tmux"
                    }
                    property JsonObject wallpapers: JsonObject {
                        property list<string> modifiers: ["SUPER"]
                        property string key: "COMMA"
                        property string dispatcher: "global"
                        property string argument: "ambxst:dashboard-wallpapers"
                    }
                    property JsonObject widgets: JsonObject {
                        property list<string> modifiers: ["SUPER"]
                        property string key: "R"
                        property string dispatcher: "global"
                        property string argument: "ambxst:dashboard-widgets"
                    }
                }
                property JsonObject system: JsonObject {
                    property JsonObject config: JsonObject {
                        property list<string> modifiers: ["SUPER", "SHIFT"]
                        property string key: "C"
                        property string dispatcher: "global"
                        property string argument: "ambxst:config"
                    }
                    property JsonObject lockscreen: JsonObject {
                        property list<string> modifiers: ["SUPER"]
                        property string key: "L"
                        property string dispatcher: "exec"
                        property string argument: "loginctl lock-session"
                    }
                    property JsonObject overview: JsonObject {
                        property list<string> modifiers: ["SUPER"]
                        property string key: "TAB"
                        property string dispatcher: "global"
                        property string argument: "ambxst:overview"
                    }
                    property JsonObject powermenu: JsonObject {
                        property list<string> modifiers: ["SUPER"]
                        property string key: "ESCAPE"
                        property string dispatcher: "global"
                        property string argument: "ambxst:powermenu"
                    }
                    property JsonObject tools: JsonObject {
                        property list<string> modifiers: ["SUPER"]
                        property string key: "S"
                        property string dispatcher: "global"
                        property string argument: "ambxst:tools"
                    }
                    property JsonObject screenshot: JsonObject {
                        property list<string> modifiers: ["SUPER", "SHIFT"]
                        property string key: "S"
                        property string dispatcher: "global"
                        property string argument: "ambxst:screenshot"
                    }
                    property JsonObject screenrecord: JsonObject {
                        property list<string> modifiers: ["SUPER", "SHIFT"]
                        property string key: "R"
                        property string dispatcher: "global"
                        property string argument: "ambxst:screenrecord"
                    }
                    property JsonObject lens: JsonObject {
                        property list<string> modifiers: ["SUPER", "SHIFT"]
                        property string key: "A"
                        property string dispatcher: "global"
                        property string argument: "ambxst:lens"
                    }
                }
            }
            property list<var> custom: [
                // Window Management
                {
                    "name": "Close Window",
                    "keys": [
                        {
                            "modifiers": ["SUPER"],
                            "key": "C"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "killactive",
                            "argument": "",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": []
                            }
                        }
                    ],
                    "enabled": true
                },

                // Workspace Navigation (SUPER + [0-9])
                {
                    "name": "Workspace 1",
                    "keys": [
                        {
                            "modifiers": ["SUPER"],
                            "key": "1"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "workspace",
                            "argument": "1",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": []
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Workspace 2",
                    "keys": [
                        {
                            "modifiers": ["SUPER"],
                            "key": "2"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "workspace",
                            "argument": "2",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": []
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Workspace 3",
                    "keys": [
                        {
                            "modifiers": ["SUPER"],
                            "key": "3"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "workspace",
                            "argument": "3",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": []
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Workspace 4",
                    "keys": [
                        {
                            "modifiers": ["SUPER"],
                            "key": "4"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "workspace",
                            "argument": "4",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": []
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Workspace 5",
                    "keys": [
                        {
                            "modifiers": ["SUPER"],
                            "key": "5"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "workspace",
                            "argument": "5",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": []
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Workspace 6",
                    "keys": [
                        {
                            "modifiers": ["SUPER"],
                            "key": "6"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "workspace",
                            "argument": "6",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": []
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Workspace 7",
                    "keys": [
                        {
                            "modifiers": ["SUPER"],
                            "key": "7"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "workspace",
                            "argument": "7",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": []
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Workspace 8",
                    "keys": [
                        {
                            "modifiers": ["SUPER"],
                            "key": "8"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "workspace",
                            "argument": "8",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": []
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Workspace 9",
                    "keys": [
                        {
                            "modifiers": ["SUPER"],
                            "key": "9"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "workspace",
                            "argument": "9",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": []
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Workspace 10",
                    "keys": [
                        {
                            "modifiers": ["SUPER"],
                            "key": "0"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "workspace",
                            "argument": "10",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": []
                            }
                        }
                    ],
                    "enabled": true
                },

                // Move Window to Workspace (SUPER + SHIFT + [0-9])
                {
                    "name": "Move to Workspace 1",
                    "keys": [
                        {
                            "modifiers": ["SUPER", "SHIFT"],
                            "key": "1"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "movetoworkspace",
                            "argument": "1",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": []
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Move to Workspace 2",
                    "keys": [
                        {
                            "modifiers": ["SUPER", "SHIFT"],
                            "key": "2"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "movetoworkspace",
                            "argument": "2",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": []
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Move to Workspace 3",
                    "keys": [
                        {
                            "modifiers": ["SUPER", "SHIFT"],
                            "key": "3"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "movetoworkspace",
                            "argument": "3",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": []
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Move to Workspace 4",
                    "keys": [
                        {
                            "modifiers": ["SUPER", "SHIFT"],
                            "key": "4"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "movetoworkspace",
                            "argument": "4",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": []
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Move to Workspace 5",
                    "keys": [
                        {
                            "modifiers": ["SUPER", "SHIFT"],
                            "key": "5"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "movetoworkspace",
                            "argument": "5",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": []
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Move to Workspace 6",
                    "keys": [
                        {
                            "modifiers": ["SUPER", "SHIFT"],
                            "key": "6"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "movetoworkspace",
                            "argument": "6",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": []
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Move to Workspace 7",
                    "keys": [
                        {
                            "modifiers": ["SUPER", "SHIFT"],
                            "key": "7"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "movetoworkspace",
                            "argument": "7",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": []
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Move to Workspace 8",
                    "keys": [
                        {
                            "modifiers": ["SUPER", "SHIFT"],
                            "key": "8"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "movetoworkspace",
                            "argument": "8",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": []
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Move to Workspace 9",
                    "keys": [
                        {
                            "modifiers": ["SUPER", "SHIFT"],
                            "key": "9"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "movetoworkspace",
                            "argument": "9",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": []
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Move to Workspace 10",
                    "keys": [
                        {
                            "modifiers": ["SUPER", "SHIFT"],
                            "key": "0"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "movetoworkspace",
                            "argument": "10",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": []
                            }
                        }
                    ],
                    "enabled": true
                },

                // Workspace Navigation (Mouse Scroll & Keyboard)
                {
                    "name": "Previous Occupied Workspace (Scroll)",
                    "keys": [
                        {
                            "modifiers": ["SUPER"],
                            "key": "mouse_down"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "workspace",
                            "argument": "e-1",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": []
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Next Occupied Workspace (Scroll)",
                    "keys": [
                        {
                            "modifiers": ["SUPER"],
                            "key": "mouse_up"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "workspace",
                            "argument": "e+1",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": []
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Previous Occupied Workspace",
                    "keys": [
                        {
                            "modifiers": ["SUPER", "SHIFT"],
                            "key": "Z"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "workspace",
                            "argument": "e-1",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": []
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Next Occupied Workspace",
                    "keys": [
                        {
                            "modifiers": ["SUPER", "SHIFT"],
                            "key": "X"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "workspace",
                            "argument": "e+1",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": []
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Previous Workspace",
                    "keys": [
                        {
                            "modifiers": ["SUPER"],
                            "key": "Z"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "workspace",
                            "argument": "-1",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": []
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Next Workspace",
                    "keys": [
                        {
                            "modifiers": ["SUPER"],
                            "key": "X"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "workspace",
                            "argument": "+1",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": []
                            }
                        }
                    ],
                    "enabled": true
                },

                // Window Drag/Resize (Mouse)
                {
                    "name": "Drag Window",
                    "keys": [
                        {
                            "modifiers": ["SUPER"],
                            "key": "mouse:272"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "movewindow",
                            "argument": "",
                            "flags": "m",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": []
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Drag Resize Window",
                    "keys": [
                        {
                            "modifiers": ["SUPER"],
                            "key": "mouse:273"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "resizewindow",
                            "argument": "",
                            "flags": "m",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": []
                            }
                        }
                    ],
                    "enabled": true
                },

                // Media Player Controls
                {
                    "name": "Play/Pause",
                    "keys": [
                        {
                            "modifiers": [],
                            "key": "XF86AudioPlay"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "exec",
                            "argument": "playerctl play-pause",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": []
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Previous Track",
                    "keys": [
                        {
                            "modifiers": [],
                            "key": "XF86AudioPrev"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "exec",
                            "argument": "playerctl previous",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": []
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Next Track",
                    "keys": [
                        {
                            "modifiers": [],
                            "key": "XF86AudioNext"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "exec",
                            "argument": "playerctl next",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": []
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Media Play/Pause",
                    "keys": [
                        {
                            "modifiers": [],
                            "key": "XF86AudioMedia"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "exec",
                            "argument": "playerctl play-pause",
                            "flags": "l",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": []
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Stop Playback",
                    "keys": [
                        {
                            "modifiers": [],
                            "key": "XF86AudioStop"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "exec",
                            "argument": "playerctl stop",
                            "flags": "l",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": []
                            }
                        }
                    ],
                    "enabled": true
                },

                // Volume Controls
                {
                    "name": "Volume Up",
                    "keys": [
                        {
                            "modifiers": [],
                            "key": "XF86AudioRaiseVolume"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "exec",
                            "argument": "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 10%+",
                            "flags": "le",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": []
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Volume Down",
                    "keys": [
                        {
                            "modifiers": [],
                            "key": "XF86AudioLowerVolume"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "exec",
                            "argument": "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 10%-",
                            "flags": "le",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": []
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Mute Audio",
                    "keys": [
                        {
                            "modifiers": [],
                            "key": "XF86AudioMute"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "exec",
                            "argument": "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle",
                            "flags": "le",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": []
                            }
                        }
                    ],
                    "enabled": true
                },

                // Brightness Controls
                {
                    "name": "Brightness Up",
                    "keys": [
                        {
                            "modifiers": [],
                            "key": "XF86MonBrightnessUp"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "exec",
                            "argument": "ambxst brightness +5",
                            "flags": "le",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": []
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Brightness Down",
                    "keys": [
                        {
                            "modifiers": [],
                            "key": "XF86MonBrightnessDown"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "exec",
                            "argument": "ambxst brightness -5",
                            "flags": "le",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": []
                            }
                        }
                    ],
                    "enabled": true
                },

                // Special Keys
                {
                    "name": "Calculator",
                    "keys": [
                        {
                            "modifiers": [],
                            "key": "XF86Calculator"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "exec",
                            "argument": "notify-send \"Soon\"",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": []
                            }
                        }
                    ],
                    "enabled": true
                },

                // Special Workspaces
                {
                    "name": "Toggle Special Workspace",
                    "keys": [
                        {
                            "modifiers": ["SUPER", "SHIFT"],
                            "key": "V"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "togglespecialworkspace",
                            "argument": "",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": []
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Move to Special Workspace",
                    "keys": [
                        {
                            "modifiers": ["SUPER", "ALT"],
                            "key": "V"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "movetoworkspace",
                            "argument": "special",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": []
                            }
                        }
                    ],
                    "enabled": true
                },

                // Lid Switch Events
                {
                    "name": "Lock on Lid Close",
                    "keys": [
                        {
                            "modifiers": [],
                            "key": "switch:Lid Switch"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "exec",
                            "argument": "loginctl lock-session",
                            "flags": "l",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": []
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Display Off on Lid Close",
                    "keys": [
                        {
                            "modifiers": [],
                            "key": "switch:on:Lid Switch"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "exec",
                            "argument": "hyprctl dispatch dpms off",
                            "flags": "l",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": []
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Display On on Lid Open",
                    "keys": [
                        {
                            "modifiers": [],
                            "key": "switch:off:Lid Switch"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "exec",
                            "argument": "hyprctl dispatch dpms on",
                            "flags": "l",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": []
                            }
                        }
                    ],
                    "enabled": true
                },

                // Window Focus (Layout-aware)
                {
                    "name": "Focus Up",
                    "keys": [
                        {
                            "modifiers": ["SUPER"],
                            "key": "Up"
                        },
                        {
                            "modifiers": ["SUPER", "CTRL"],
                            "key": "k"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "layoutmsg",
                            "argument": "focus u",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": ["scrolling"]
                            }
                        },
                        {
                            "dispatcher": "movefocus",
                            "argument": "u",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": ["dwindle", "master"]
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Focus Down",
                    "keys": [
                        {
                            "modifiers": ["SUPER"],
                            "key": "Down"
                        },
                        {
                            "modifiers": ["SUPER", "CTRL"],
                            "key": "j"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "layoutmsg",
                            "argument": "focus d",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": ["scrolling"]
                            }
                        },
                        {
                            "dispatcher": "movefocus",
                            "argument": "d",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": ["master", "dwindle"]
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Focus Left",
                    "keys": [
                        {
                            "modifiers": ["SUPER"],
                            "key": "Left"
                        },
                        {
                            "modifiers": ["SUPER", "CTRL"],
                            "key": "z"
                        },
                        {
                            "modifiers": ["SUPER", "CTRL"],
                            "key": "h"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "layoutmsg",
                            "argument": "focus l",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": ["scrolling"]
                            }
                        },
                        {
                            "dispatcher": "movefocus",
                            "argument": "l",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": ["dwindle", "master"]
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Focus Right",
                    "keys": [
                        {
                            "modifiers": ["SUPER"],
                            "key": "Right"
                        },
                        {
                            "modifiers": ["SUPER", "CTRL"],
                            "key": "x"
                        },
                        {
                            "modifiers": ["SUPER", "CTRL"],
                            "key": "l"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "layoutmsg",
                            "argument": "focus r",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": ["scrolling"]
                            }
                        },
                        {
                            "dispatcher": "movefocus",
                            "argument": "r",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": ["master", "dwindle"]
                            }
                        }
                    ],
                    "enabled": true
                },

                // Window Movement (Layout-aware)
                {
                    "name": "Move Window Left",
                    "keys": [
                        {
                            "modifiers": ["SUPER", "SHIFT"],
                            "key": "Left"
                        },
                        {
                            "modifiers": ["SUPER", "SHIFT"],
                            "key": "h"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "movewindow",
                            "argument": "l",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": ["master", "dwindle"]
                            }
                        },
                        {
                            "dispatcher": "layoutmsg",
                            "argument": "movewindowto l",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": ["scrolling"]
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Move Window Right",
                    "keys": [
                        {
                            "modifiers": ["SUPER", "SHIFT"],
                            "key": "Right"
                        },
                        {
                            "modifiers": ["SUPER", "SHIFT"],
                            "key": "l"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "movewindow",
                            "argument": "r",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": ["dwindle", "master"]
                            }
                        },
                        {
                            "dispatcher": "layoutmsg",
                            "argument": "movewindowto r",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": ["scrolling"]
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Move Window Up",
                    "keys": [
                        {
                            "modifiers": ["SUPER", "SHIFT"],
                            "key": "Up"
                        },
                        {
                            "modifiers": ["SUPER", "SHIFT"],
                            "key": "k"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "movewindow",
                            "argument": "u",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": ["master", "dwindle"]
                            }
                        },
                        {
                            "dispatcher": "layoutmsg",
                            "argument": "movewindowto u",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": ["scrolling"]
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Move Window Down",
                    "keys": [
                        {
                            "modifiers": ["SUPER", "SHIFT"],
                            "key": "Down"
                        },
                        {
                            "modifiers": ["SUPER", "SHIFT"],
                            "key": "j"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "movewindow",
                            "argument": "d",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": ["master", "dwindle"]
                            }
                        },
                        {
                            "dispatcher": "layoutmsg",
                            "argument": "movewindowto d",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": []
                            }
                        }
                    ],
                    "enabled": true
                },

                // Window Resize (Layout-aware)
                {
                    "name": "Horizontal Resize +",
                    "keys": [
                        {
                            "modifiers": ["SUPER", "ALT"],
                            "key": "Right"
                        },
                        {
                            "modifiers": ["SUPER", "ALT"],
                            "key": "l"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "layoutmsg",
                            "argument": "colresize +0.1",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": ["scrolling"]
                            }
                        },
                        {
                            "dispatcher": "resizeactive",
                            "argument": "50 0",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": ["master", "dwindle"]
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Horizontal Resize -",
                    "keys": [
                        {
                            "modifiers": ["SUPER", "ALT"],
                            "key": "Left"
                        },
                        {
                            "modifiers": ["SUPER", "ALT"],
                            "key": "h"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "layoutmsg",
                            "argument": "colresize -0.1",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": ["scrolling"]
                            }
                        },
                        {
                            "dispatcher": "resizeactive",
                            "argument": "-50 0",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": ["master", "dwindle"]
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Vertical Resize +",
                    "keys": [
                        {
                            "modifiers": ["SUPER", "ALT"],
                            "key": "Down"
                        },
                        {
                            "modifiers": ["SUPER", "ALT"],
                            "key": "j"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "resizeactive",
                            "argument": "0 50",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": []
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Vertical Resize -",
                    "keys": [
                        {
                            "modifiers": ["SUPER", "ALT"],
                            "key": "Up"
                        },
                        {
                            "modifiers": ["SUPER", "ALT"],
                            "key": "k"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "resizeactive",
                            "argument": "0 -50",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": []
                            }
                        }
                    ],
                    "enabled": true
                },

                // Scrolling Layout Specific
                {
                    "name": "Promote (Scrolling)",
                    "keys": [
                        {
                            "modifiers": ["SUPER", "ALT"],
                            "key": "SPACE"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "layoutmsg",
                            "argument": "promote",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": ["scrolling"]
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Toggle Fit (Scrolling)",
                    "keys": [
                        {
                            "modifiers": ["SUPER", "CTRL"],
                            "key": "SPACE"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "layoutmsg",
                            "argument": "togglefit",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": ["scrolling"]
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Toggle Full Column (Scrolling)",
                    "keys": [
                        {
                            "modifiers": ["SUPER", "SHIFT"],
                            "key": "SPACE"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "layoutmsg",
                            "argument": "colresize +conf",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": ["scrolling"]
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Swap Column Left",
                    "keys": [
                        {
                            "modifiers": ["SUPER", "ALT", "CTRL"],
                            "key": "Left"
                        },
                        {
                            "modifiers": ["SUPER", "ALT", "CTRL"],
                            "key": "h"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "layoutmsg",
                            "argument": "swapcol l",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": ["scrolling"]
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Swap Column Right",
                    "keys": [
                        {
                            "modifiers": ["SUPER", "ALT", "CTRL"],
                            "key": "Right"
                        },
                        {
                            "modifiers": ["SUPER", "ALT", "CTRL"],
                            "key": "l"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "layoutmsg",
                            "argument": "swapcol r",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": ["scrolling"]
                            }
                        }
                    ],
                    "enabled": true
                },

                // Move Column to Workspace (Scrolling Layout)
                {
                    "name": "Move Column To Workspace 1",
                    "keys": [
                        {
                            "modifiers": ["SUPER", "CTRL", "ALT"],
                            "key": "1"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "layoutmsg",
                            "argument": "movecoltoworkspace 1",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": ["scrolling"]
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Move Column To Workspace 2",
                    "keys": [
                        {
                            "modifiers": ["SUPER", "CTRL", "ALT"],
                            "key": "2"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "layoutmsg",
                            "argument": "movecoltoworkspace 2",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": ["scrolling"]
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Move Column To Workspace 3",
                    "keys": [
                        {
                            "modifiers": ["SUPER", "CTRL", "ALT"],
                            "key": "3"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "layoutmsg",
                            "argument": "movecoltoworkspace 3",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": ["scrolling"]
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Move Column To Workspace 4",
                    "keys": [
                        {
                            "modifiers": ["SUPER", "CTRL", "ALT"],
                            "key": "4"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "layoutmsg",
                            "argument": "movecoltoworkspace 4",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": ["scrolling"]
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Move Column To Workspace 5",
                    "keys": [
                        {
                            "modifiers": ["SUPER", "CTRL", "ALT"],
                            "key": "5"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "layoutmsg",
                            "argument": "movecoltoworkspace 5",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": ["scrolling"]
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Move Column To Workspace 6",
                    "keys": [
                        {
                            "modifiers": ["SUPER", "CTRL", "ALT"],
                            "key": "6"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "layoutmsg",
                            "argument": "movecoltoworkspace 6",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": ["scrolling"]
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Move Column To Workspace 7",
                    "keys": [
                        {
                            "modifiers": ["SUPER", "CTRL", "ALT"],
                            "key": "7"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "layoutmsg",
                            "argument": "movecoltoworkspace 7",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": ["scrolling"]
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Move Column To Workspace 8",
                    "keys": [
                        {
                            "modifiers": ["SUPER", "CTRL", "ALT"],
                            "key": "8"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "layoutmsg",
                            "argument": "movecoltoworkspace 8",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": ["scrolling"]
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Move Column To Workspace 9",
                    "keys": [
                        {
                            "modifiers": ["SUPER", "CTRL", "ALT"],
                            "key": "9"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "layoutmsg",
                            "argument": "movecoltoworkspace 9",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": ["scrolling"]
                            }
                        }
                    ],
                    "enabled": true
                },
                {
                    "name": "Move Column To Workspace 10",
                    "keys": [
                        {
                            "modifiers": ["SUPER", "CTRL", "ALT"],
                            "key": "0"
                        }
                    ],
                    "actions": [
                        {
                            "dispatcher": "layoutmsg",
                            "argument": "movecoltoworkspace 10",
                            "flags": "",
                            "compositor": {
                                "type": "hyprland",
                                "layouts": ["scrolling"]
                            }
                        }
                    ],
                    "enabled": true
                }
            ]
        }
    }

    // ============================================
    // VALIDATION HELPER
    // ============================================
    function validateModule(name, rawLoader, defaults, onComplete) {
        var raw = rawLoader.text();
        if (!raw) {
            onComplete();
            return;
        }

        try {
            var current = JSON.parse(raw);
            var validated = ConfigValidator.validate(current, defaults);

            if (JSON.stringify(current) !== JSON.stringify(validated)) {
                console.log("Merging and updating " + name + ".json...");
                rawLoader.setText(JSON.stringify(validated, null, 4));
            }
            onComplete();
        } catch (e) {
            console.log("Error validating " + name + " config (invalid JSON?): " + e);
            console.log("Overwriting with defaults due to error.");
            rawLoader.setText(JSON.stringify(defaults, null, 4));
            onComplete();
        }
    }

    // ============================================
    // EXPOSED PROPERTIES (backward compatibility)
    // ============================================

    // Theme configuration
    property QtObject theme: themeLoader.adapter
    property bool oledMode: lightMode ? false : theme.oledMode
    property bool lightMode: theme.lightMode

    property int roundness: theme.roundness
    property string defaultFont: theme.font
    property int animDuration: Services.GameModeService.toggled ? 0 : theme.animDuration
    property bool tintIcons: theme.tintIcons

    // Detect lightMode changes and run Matugen
    onLightModeChanged: {
        console.log("lightMode changed to:", lightMode);
        if (GlobalStates.wallpaperManager) {
            var wallpaperManager = GlobalStates.wallpaperManager;
            if (wallpaperManager.currentWallpaper) {
                console.log("Re-running Matugen due to lightMode change");
                wallpaperManager.runMatugenForCurrentWallpaper();
            }
        }
    }

    // Bar configuration
    property QtObject bar: barLoader.adapter
    property bool showBackground: theme.srBarBg.opacity > 0

    // Workspace configuration
    property QtObject workspaces: workspacesLoader.adapter

    // Overview configuration
    property QtObject overview: overviewLoader.adapter

    // Notch configuration
    property QtObject notch: notchLoader.adapter
    property string notchTheme: notch.theme

    // Hyprland configuration
    property QtObject hyprland: hyprlandLoader.adapter
    property int hyprlandRounding: hyprland.syncRoundness ? roundness : hyprland.rounding
    property int hyprlandBorderSize: hyprland.syncBorderWidth ? (theme.srBg.border[1] || 0) : hyprland.borderSize
    property string hyprlandBorderColor: hyprland.syncBorderColor ? (theme.srBg.border[0] || "primary") : (hyprland.activeBorderColor.length > 0 ? hyprland.activeBorderColor[0] : "primary")
    property real hyprlandShadowOpacity: hyprland.syncShadowOpacity ? theme.shadowOpacity : hyprland.shadowOpacity
    property string hyprlandShadowColor: hyprland.syncShadowColor ? theme.shadowColor : hyprland.shadowColor

    // Performance configuration
    property QtObject performance: performanceLoader.adapter
    property bool blurTransition: performance.blurTransition

    // Weather configuration
    property QtObject weather: weatherLoader.adapter

    // Desktop configuration
    property QtObject desktop: desktopLoader.adapter

    // Lockscreen configuration
    property QtObject lockscreen: lockscreenLoader.adapter

    // Prefix configuration
    property QtObject prefix: prefixLoader.adapter

    // System configuration
    property QtObject system: systemLoader.adapter

    // Dock configuration
    property QtObject dock: dockLoader.adapter

    // Pinned apps configuration (stored in dataPath)
    property QtObject pinnedApps: pinnedAppsLoader.adapter

    // AI configuration
    property QtObject ai: aiLoader.adapter

    // Save functions for modules
    function saveBar() {
        barLoader.writeAdapter();
    }
    function saveWorkspaces() {
        workspacesLoader.writeAdapter();
    }
    function saveOverview() {
        overviewLoader.writeAdapter();
    }
    function saveNotch() {
        notchLoader.writeAdapter();
    }
    function saveHyprland() {
        hyprlandLoader.writeAdapter();
    }
    function savePerformance() {
        performanceLoader.writeAdapter();
    }
    function saveWeather() {
        weatherLoader.writeAdapter();
    }
    function saveDesktop() {
        desktopLoader.writeAdapter();
    }
    function saveLockscreen() {
        lockscreenLoader.writeAdapter();
    }
    function savePrefix() {
        prefixLoader.writeAdapter();
    }
    function saveSystem() {
        systemLoader.writeAdapter();
    }
    function saveDock() {
        dockLoader.writeAdapter();
    }
    function savePinnedApps() {
        pinnedAppsLoader.writeAdapter();
    }
    function saveAi() {
        aiLoader.writeAdapter();
    }

    // Helper functions for color handling (HEX or named colors)
    function isHexColor(colorValue) {
        if (!colorValue || typeof colorValue !== 'string')
            return false;
        const normalized = colorValue.toLowerCase().trim();
        return normalized.startsWith('#') || normalized.startsWith('rgb');
    }

    function resolveColor(colorValue) {
        if (!colorValue)
            return "transparent"; // Fallback safe color

        if (isHexColor(colorValue)) {
            return colorValue;
        }

        // Check if Colors singleton is ready
        if (typeof Colors === 'undefined' || !Colors)
            return "transparent";

        return Colors[colorValue] || "transparent";
    }

    function resolveColorWithOpacity(colorValue, opacity) {
        if (!colorValue)
            return Qt.rgba(0, 0, 0, 0);

        const color = isHexColor(colorValue) ? Qt.color(colorValue) : (Colors[colorValue] || Qt.color("transparent"));
        return Qt.rgba(color.r, color.g, color.b, opacity);
    }
}
