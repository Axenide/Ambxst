pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.globals
import qs.modules.theme
import qs.modules.services as Services
import "ConfigDefaults.js" as ConfigDefaults
import "ConfigValidator.js" as ConfigValidator

Singleton {
    id: root

    property alias loader: loader
    property alias keybindsLoader: keybindsLoader
    property bool initialLoadComplete: false
    property bool keybindsInitialLoadComplete: false
    property bool pauseAutoSave: false  // When true, changes won't auto-save to JSON
    property string configPath: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/Ambxst/config.json"
    property string keybindsPath: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/Ambxst/binds.json"

    FileView {
        id: rawLoader
        path: configPath
        onLoaded: {
            if (!root.initialLoadComplete) {
                validateConfig();
            }
        }
    }

    function validateConfig() {
        var raw = rawLoader.text();
        if (!raw)
            return;

        try {
            var current = JSON.parse(raw);
            var validated = ConfigValidator.validate(current, ConfigDefaults.data);

            if (JSON.stringify(current) !== JSON.stringify(validated)) {
                console.log("Merging and updating config.json...");
                rawLoader.setText(JSON.stringify(validated, null, 4));
            }
            root.initialLoadComplete = true;
        } catch (e) {
            console.log("Error validating config (invalid JSON?): " + e);
            console.log("Overwriting with defaults due to error.");
            rawLoader.setText(JSON.stringify(ConfigDefaults.data, null, 4));
            root.initialLoadComplete = true;
        }
    }

    Process {
        id: checkFile
        running: true
        command: ["sh", "-c", "mkdir -p \"$(dirname '" + configPath + "')\" && test -f \"" + configPath + "\""]

        onExited: exitCode => {
            if (exitCode !== 0) {
                console.log("config.json not found, creating with default values...");
                rawLoader.setText(JSON.stringify(ConfigDefaults.data, null, 4));
                root.initialLoadComplete = true;
            }
        }
    }

    Process {
        id: checkKeybindsFile
        running: true
        command: ["sh", "-c", "mkdir -p \"$(dirname '" + keybindsPath + "')\" && test -f \"" + keybindsPath + "\""]

        onExited: exitCode => {
            if (exitCode !== 0) {
                console.log("binds.json not found, creating with default values...");
                keybindsLoader.writeAdapter();
            }
            root.keybindsInitialLoadComplete = true;
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
            if (root.initialLoadComplete && !root.pauseAutoSave) {
                loader.writeAdapter();
            }
        }

        adapter: JsonAdapter {
            property JsonObject theme: JsonObject {
                property bool oledMode: false
                property bool lightMode: false
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
                property list<var> separatorColor: [["surfaceBright", 0.0]]

                // StyledRect variant configurations
                // Each variant (bg, pane, common, focus, primary, etc.) contains:
                // - gradient properties (stops, type, angle, center, halftone)
                // - border properties [color, width]
                // - item color (text/icon color to use on top of the variant)

                // SR: Background variant
                property JsonObject srBg: JsonObject {
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

                // SR: Internal Background variant (same as bg, but for internal components)
                property JsonObject srInternalBg: JsonObject {
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

                // SR: Pane variant
                property JsonObject srPane: JsonObject {
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

                // SR: Common variant (default/neutral)
                property JsonObject srCommon: JsonObject {
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

                // SR: Focus variant
                property JsonObject srFocus: JsonObject {
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

                // SR: Primary variants
                property JsonObject srPrimary: JsonObject {
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

                // SR: Secondary variants
                property JsonObject srSecondary: JsonObject {
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

                // SR: Tertiary variants
                property JsonObject srTertiary: JsonObject {
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

                // SR: Error variants
                property JsonObject srError: JsonObject {
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

            property JsonObject bar: JsonObject {
                property string position: "top"
                property string launcherIcon: ""
                property bool launcherIconTint: true
                property bool launcherIconFullTint: true
                property int launcherIconSize: 24
                property bool showBackground: false
                property real bgOpacity: 0.5
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
                property bool dynamic: false
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

            property JsonObject lockscreen: JsonObject {
                property string position: "bottom"
            }

            property JsonObject prefix: JsonObject {
                property string clipboard: "cc"
                property string emoji: "ee"
                property string tmux: "tt"
                property string wallpapers: "ww"
            }

            property JsonObject system: JsonObject {
                property list<string> disks: ["/"]
            }
        }
    }

    FileView {
        id: keybindsLoader
        path: keybindsPath
        atomicWrites: true
        watchChanges: true
        onFileChanged: reload()
        onPathChanged: reload()
        onAdapterUpdated: {
            if (root.keybindsInitialLoadComplete) {
                keybindsLoader.writeAdapter();
            }
        }

        adapter: JsonAdapter {
            property JsonObject ambxst: JsonObject {
                property JsonObject dashboard: JsonObject {
                    property JsonObject widgets: JsonObject {
                        property list<string> modifiers: ["SUPER"]
                        property string key: "R"
                        property string dispatcher: "global"
                        property string argument: "ambxst:dashboard-widgets"
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
                    property JsonObject tmux: JsonObject {
                        property list<string> modifiers: ["SUPER"]
                        property string key: "T"
                        property string dispatcher: "global"
                        property string argument: "ambxst:dashboard-tmux"
                    }
                    property JsonObject kanban: JsonObject {
                        property list<string> modifiers: ["SUPER"]
                        property string key: "N"
                        property string dispatcher: "global"
                        property string argument: "ambxst:dashboard-kanban"
                    }
                    property JsonObject wallpapers: JsonObject {
                        property list<string> modifiers: ["SUPER"]
                        property string key: "COMMA"
                        property string dispatcher: "global"
                        property string argument: "ambxst:dashboard-wallpapers"
                    }
                    property JsonObject assistant: JsonObject {
                        property list<string> modifiers: ["SUPER"]
                        property string key: "A"
                        property string dispatcher: "global"
                        property string argument: "ambxst:dashboard-assistant"
                    }
                }
                property JsonObject system: JsonObject {
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
                    property JsonObject config: JsonObject {
                        property list<string> modifiers: ["SUPER", "SHIFT"]
                        property string key: "C"
                        property string dispatcher: "global"
                        property string argument: "ambxst:config"
                    }
                    property JsonObject lockscreen: JsonObject {
                        property list<string> modifiers: ["SUPER"]
                        property string key: "L"
                        property string dispatcher: "global"
                        property string argument: "ambxst:lockscreen"
                    }
                }
            }
            property list<var> custom: [
                // Window management
                {
                    "modifiers": ["SUPER"],
                    "key": "C",
                    "dispatcher": "killactive",
                    "argument": "",
                    "enabled": true
                },

                // Switch workspaces with SUPER + [0-9]
                {
                    "modifiers": ["SUPER"],
                    "key": "1",
                    "dispatcher": "workspace",
                    "argument": "1",
                    "enabled": true
                },
                {
                    "modifiers": ["SUPER"],
                    "key": "2",
                    "dispatcher": "workspace",
                    "argument": "2",
                    "enabled": true
                },
                {
                    "modifiers": ["SUPER"],
                    "key": "3",
                    "dispatcher": "workspace",
                    "argument": "3",
                    "enabled": true
                },
                {
                    "modifiers": ["SUPER"],
                    "key": "4",
                    "dispatcher": "workspace",
                    "argument": "4",
                    "enabled": true
                },
                {
                    "modifiers": ["SUPER"],
                    "key": "5",
                    "dispatcher": "workspace",
                    "argument": "5",
                    "enabled": true
                },
                {
                    "modifiers": ["SUPER"],
                    "key": "6",
                    "dispatcher": "workspace",
                    "argument": "6",
                    "enabled": true
                },
                {
                    "modifiers": ["SUPER"],
                    "key": "7",
                    "dispatcher": "workspace",
                    "argument": "7",
                    "enabled": true
                },
                {
                    "modifiers": ["SUPER"],
                    "key": "8",
                    "dispatcher": "workspace",
                    "argument": "8",
                    "enabled": true
                },
                {
                    "modifiers": ["SUPER"],
                    "key": "9",
                    "dispatcher": "workspace",
                    "argument": "9",
                    "enabled": true
                },
                {
                    "modifiers": ["SUPER"],
                    "key": "0",
                    "dispatcher": "workspace",
                    "argument": "10",
                    "enabled": true
                },

                // Move active window to workspace with SUPER + SHIFT + [0-9]
                {
                    "modifiers": ["SUPER", "SHIFT"],
                    "key": "1",
                    "dispatcher": "movetoworkspace",
                    "argument": "1",
                    "enabled": true
                },
                {
                    "modifiers": ["SUPER", "SHIFT"],
                    "key": "2",
                    "dispatcher": "movetoworkspace",
                    "argument": "2",
                    "enabled": true
                },
                {
                    "modifiers": ["SUPER", "SHIFT"],
                    "key": "3",
                    "dispatcher": "movetoworkspace",
                    "argument": "3",
                    "enabled": true
                },
                {
                    "modifiers": ["SUPER", "SHIFT"],
                    "key": "4",
                    "dispatcher": "movetoworkspace",
                    "argument": "4",
                    "enabled": true
                },
                {
                    "modifiers": ["SUPER", "SHIFT"],
                    "key": "5",
                    "dispatcher": "movetoworkspace",
                    "argument": "5",
                    "enabled": true
                },
                {
                    "modifiers": ["SUPER", "SHIFT"],
                    "key": "6",
                    "dispatcher": "movetoworkspace",
                    "argument": "6",
                    "enabled": true
                },
                {
                    "modifiers": ["SUPER", "SHIFT"],
                    "key": "7",
                    "dispatcher": "movetoworkspace",
                    "argument": "7",
                    "enabled": true
                },
                {
                    "modifiers": ["SUPER", "SHIFT"],
                    "key": "8",
                    "dispatcher": "movetoworkspace",
                    "argument": "8",
                    "enabled": true
                },
                {
                    "modifiers": ["SUPER", "SHIFT"],
                    "key": "9",
                    "dispatcher": "movetoworkspace",
                    "argument": "9",
                    "enabled": true
                },
                {
                    "modifiers": ["SUPER", "SHIFT"],
                    "key": "0",
                    "dispatcher": "movetoworkspace",
                    "argument": "10",
                    "enabled": true
                },

                // Scroll through workspaces
                {
                    "modifiers": ["SUPER"],
                    "key": "mouse_down",
                    "dispatcher": "workspace",
                    "argument": "e-1",
                    "enabled": true
                },
                {
                    "modifiers": ["SUPER", "SHIFT"],
                    "key": "Z",
                    "dispatcher": "workspace",
                    "argument": "e-1",
                    "enabled": true
                },
                {
                    "modifiers": ["SUPER"],
                    "key": "mouse_up",
                    "dispatcher": "workspace",
                    "argument": "e+1",
                    "enabled": true
                },
                {
                    "modifiers": ["SUPER", "SHIFT"],
                    "key": "X",
                    "dispatcher": "workspace",
                    "argument": "e+1",
                    "enabled": true
                },

                // Next/previous workspace with Z and X
                {
                    "modifiers": ["SUPER"],
                    "key": "Z",
                    "dispatcher": "workspace",
                    "argument": "-1",
                    "enabled": true
                },
                {
                    "modifiers": ["SUPER"],
                    "key": "X",
                    "dispatcher": "workspace",
                    "argument": "+1",
                    "enabled": true
                },

                // Move/resize windows with mouse
                {
                    "modifiers": ["SUPER"],
                    "key": "mouse:272",
                    "dispatcher": "movewindow",
                    "argument": "",
                    "flags": "m",
                    "enabled": true
                },
                {
                    "modifiers": ["SUPER"],
                    "key": "mouse:273",
                    "dispatcher": "resizewindow",
                    "argument": "",
                    "flags": "m",
                    "enabled": true
                },

                // Media player controls
                {
                    "modifiers": [],
                    "key": "XF86AudioPlay",
                    "dispatcher": "exec",
                    "argument": "playerctl play-pause",
                    "enabled": true
                },
                {
                    "modifiers": [],
                    "key": "XF86AudioPrev",
                    "dispatcher": "exec",
                    "argument": "playerctl previous",
                    "enabled": true
                },
                {
                    "modifiers": [],
                    "key": "XF86AudioNext",
                    "dispatcher": "exec",
                    "argument": "playerctl next",
                    "enabled": true
                },
                {
                    "modifiers": [],
                    "key": "XF86AudioMedia",
                    "dispatcher": "exec",
                    "argument": "playerctl play-pause",
                    "flags": "l",
                    "enabled": true
                },
                {
                    "modifiers": [],
                    "key": "XF86AudioStop",
                    "dispatcher": "exec",
                    "argument": "playerctl stop",
                    "flags": "l",
                    "enabled": true
                },

                // Volume controls
                {
                    "modifiers": [],
                    "key": "XF86AudioRaiseVolume",
                    "dispatcher": "exec",
                    "argument": "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 10%+",
                    "flags": "le",
                    "enabled": true
                },
                {
                    "modifiers": [],
                    "key": "XF86AudioLowerVolume",
                    "dispatcher": "exec",
                    "argument": "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 10%-",
                    "flags": "le",
                    "enabled": true
                },
                {
                    "modifiers": [],
                    "key": "XF86AudioMute",
                    "dispatcher": "exec",
                    "argument": "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle",
                    "flags": "le",
                    "enabled": true
                },

                // Brightness controls
                {
                    "modifiers": [],
                    "key": "XF86MonBrightnessUp",
                    "dispatcher": "exec",
                    "argument": "swayosd-client --brightness=raise 5",
                    "flags": "le",
                    "enabled": true
                },
                {
                    "modifiers": [],
                    "key": "XF86MonBrightnessDown",
                    "dispatcher": "exec",
                    "argument": "swayosd-client --brightness=lower 5",
                    "flags": "le",
                    "enabled": true
                },

                // Calculator key
                {
                    "modifiers": [],
                    "key": "XF86Calculator",
                    "dispatcher": "exec",
                    "argument": "notify-send \"Soon\"",
                    "enabled": true
                },

                // Special workspaces
                {
                    "modifiers": ["SUPER", "SHIFT"],
                    "key": "V",
                    "dispatcher": "togglespecialworkspace",
                    "argument": "",
                    "enabled": true
                },
                {
                    "modifiers": ["SUPER", "ALT"],
                    "key": "V",
                    "dispatcher": "movetoworkspace",
                    "argument": "special",
                    "enabled": true
                },

                // Lid switch events
                {
                    "modifiers": [],
                    "key": "switch:Lid Switch",
                    "dispatcher": "exec",
                    "argument": "loginctl lock-session",
                    "flags": "l",
                    "enabled": true
                },
                {
                    "modifiers": [],
                    "key": "switch:on:Lid Switch",
                    "dispatcher": "exec",
                    "argument": "hyprctl dispatch dpms off",
                    "flags": "l",
                    "enabled": true
                },
                {
                    "modifiers": [],
                    "key": "switch:off:Lid Switch",
                    "dispatcher": "exec",
                    "argument": "hyprctl dispatch dpms on",
                    "flags": "l",
                    "enabled": true
                }
            ]
        }
    }

    // Theme configuration
    property QtObject theme: loader.adapter.theme
    property bool oledMode: lightMode ? false : theme.oledMode
    property bool lightMode: theme.lightMode

    property int roundness: theme.roundness
    property string defaultFont: theme.font
    property string currentTheme: theme.currentTheme
    property int animDuration: Services.GameModeService.toggled ? 0 : theme.animDuration
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
    property int hyprlandRounding: hyprland.syncRoundness ? Math.max(0, roundness - (hyprland.gapsOut - hyprlandBorderSize)) : Math.max(0, hyprland.rounding - hyprlandBorderSize)
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

    // Lockscreen configuration
    property QtObject lockscreen: loader.adapter.lockscreen

    // Prefix configuration
    property QtObject prefix: loader.adapter.prefix

    // System configuration
    property QtObject system: loader.adapter.system

    // Helper functions for color handling (HEX or named colors)
    function isHexColor(colorValue) {
        if (typeof colorValue !== 'string')
            return false;
        const normalized = colorValue.toLowerCase().trim();
        return normalized.startsWith('#') || normalized.startsWith('rgb');
    }

    function resolveColor(colorValue) {
        if (isHexColor(colorValue)) {
            return colorValue;
        }
        return Colors[colorValue] || Colors.primary;
    }

    function resolveColorWithOpacity(colorValue, opacity) {
        const color = isHexColor(colorValue) ? Qt.color(colorValue) : (Colors[colorValue] || Colors.primary);
        return Qt.rgba(color.r, color.g, color.b, opacity);
    }
}
