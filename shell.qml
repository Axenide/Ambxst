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
import qs.modules.services
import qs.modules.corners
import qs.modules.components
import qs.modules.desktop
import qs.modules.lockscreen
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
        }
    }
}
