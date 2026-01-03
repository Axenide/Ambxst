//@ pragma UseQApplication
//@ pragma ShellId Ambxst
//@ pragma DataDir $BASE/Ambxst
//@ pragma StateDir $BASE/Ambxst

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.bar
import qs.modules.bar.workspaces
import qs.modules.notifications
import qs.modules.widgets.dashboard.wallpapers
import qs.modules.widgets.settings
import qs.modules.notch
import qs.modules.widgets.overview
import qs.modules.widgets.presets
import qs.modules.services
import qs.modules.corners
import qs.modules.components
import qs.modules.desktop
import qs.modules.lockscreen
import qs.modules.dock
import qs.modules.globals
import qs.config

ShellRoot {
    id: root

    ContextMenu {
        id: contextMenu
        screen: Quickshell.screens[0]
        Component.onCompleted: Visibilities.setContextMenu(contextMenu)
    }

    Variants {
        model: Quickshell.screens

        Loader {
            id: wallpaperLoader
            active: true
            required property ShellScreen modelData
            sourceComponent: Wallpaper {
                screen: wallpaperLoader.modelData
            }
        }
    }

    Variants {
        model: Quickshell.screens

        Loader {
            id: desktopLoader
            active: Config.desktop.enabled
            required property ShellScreen modelData
            sourceComponent: Desktop {
                screen: desktopLoader.modelData
            }
        }
    }

    Variants {
        model: {
            const screens = Quickshell.screens;
            const list = Config.bar.screenList;
            if (!list || list.length === 0)
                return screens;
            return screens.filter(screen => list.includes(screen.name));
        }

        Loader {
            id: barLoader
            active: true
            required property ShellScreen modelData
            sourceComponent: Bar {
                screen: barLoader.modelData
            }
        }
    }

    Variants {
        model: {
            const screens = Quickshell.screens;
            const list = Config.bar.screenList;
            if (!list || list.length === 0)
                return screens;
            return screens.filter(screen => list.includes(screen.name));
        }

        Loader {
            id: notchLoader
            active: true
            required property ShellScreen modelData
            sourceComponent: NotchWindow {
                screen: notchLoader.modelData
            }
        }
    }

    // Overview popup window (separate from notch)
    Variants {
        model: {
            const screens = Quickshell.screens;
            const list = Config.bar.screenList;
            if (!list || list.length === 0)
                return screens;
            return screens.filter(screen => list.includes(screen.name));
        }

        Loader {
            id: overviewLoader
            active: Config.overview?.enabled ?? true
            required property ShellScreen modelData
            sourceComponent: OverviewPopup {
                screen: overviewLoader.modelData
            }
        }
    }

    // Presets popup window
    Variants {
        model: {
            const screens = Quickshell.screens;
            const list = Config.bar.screenList;
            if (!list || list.length === 0)
                return screens;
            return screens.filter(screen => list.includes(screen.name));
        }

        Loader {
            id: presetsLoader
            active: true
            required property ShellScreen modelData
            sourceComponent: PresetsPopup {
                screen: presetsLoader.modelData
            }
        }
    }

    Variants {
        model: Quickshell.screens

        Loader {
            id: cornersLoader
            active: true
            required property ShellScreen modelData
            sourceComponent: ScreenCorners {
                screen: cornersLoader.modelData
            }
        }
    }

    // Application Dock - only load when enabled and not integrated
    Loader {
        id: dockLoader
        active: (Config.dock?.enabled ?? false) && (Config.dock?.theme ?? "default") !== "integrated"
        sourceComponent: Dock {}
    }

    // Secure lockscreen using WlSessionLock
    WlSessionLock {
        id: sessionLock
        locked: GlobalStates.lockscreenVisible

        LockScreen {
            // WlSessionLockSurface creates automatically for each screen
        }
    }

    GlobalShortcuts {
        id: globalShortcuts
    }

    HyprlandConfig {
        id: hyprlandConfig
    }

    HyprlandKeybinds {
        id: hyprlandKeybinds
    }

    // Ambxst Settings floating window
    Settings {
        id: settingsWindow
    }

    // Screenshot Tool
    Loader {
        id: screenshotLoader
        active: true
        source: "modules/tools/ScreenshotTool.qml"
        
        Connections {
            target: GlobalStates
            function onScreenshotToolVisibleChanged() {
                if (GlobalStates.screenshotToolVisible) {
                    Screenshot.startCapture();
                } else {
                    Screenshot.stopCapture();
                }
            }
        }

        Connections {
            target: Screenshot
            function onStateChanged() {
                if (Screenshot.state === "idle" && GlobalStates.screenshotToolVisible) {
                    GlobalStates.screenshotToolVisible = false;
                }
            }
        }
    }

    // Screen Record Tool (REMOVED: functionality moved to ToolsMenu)
    // Loader {
    //     id: screenRecordLoader
    //     active: false // Disabled
    // }


    // Mirror Tool
    Loader {
        id: mirrorLoader
        active: true
        source: "modules/tools/MirrorWindow.qml"
    }

    // Initialize clipboard service at startup to ensure clipboard watching starts immediately
    Connections {
        target: ClipboardService
        function onListCompleted() {
            // Service initialized and ready
        }
    }

    // Force initialization of control services at startup
    QtObject {
        id: serviceInitializer
        
        Component.onCompleted: {
            // Reference the services to force their creation
            let _ = NightLightService.active
            _ = GameModeService.toggled
            _ = CaffeineService.inhibit
            _ = WeatherService.dataAvailable
            _ = SystemResources.cpuUsage
            _ = IdleService.lockCmd // Force init
        }
    }
}
