//@ pragma UseQApplication
//@ pragma ShellId ambxst
//@ pragma DataDir $BASE/ambxst
//@ pragma StateDir $BASE/ambxst
//@ pragma CacheDir $BASE/ambxst

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.bar
import qs.modules.bar.workspaces
import qs.modules.notifications
import qs.modules.widgets.dashboard.wallpapers

import qs.modules.notch
import qs.modules.widgets.overview
import qs.modules.widgets.presets
import qs.modules.services
import qs.modules.corners
import qs.modules.frame
import qs.modules.components
import qs.modules.desktop
import qs.modules.lockscreen
import qs.modules.dock
import qs.modules.globals
import qs.modules.shell
import qs.config
import qs.modules.shell.osd
import "modules/tools"

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
            active: Config.desktop.enabled && SuspendManager.wakeReady
            required property ShellScreen modelData
            sourceComponent: Desktop {
                screen: desktopLoader.modelData
            }
        }
    }

    // Unified Visual Panel and Reservation Windows
    Variants {
        model: Quickshell.screens

        Item {
            id: screenShellContainer
            required property ShellScreen modelData

            // Unified Visual Panel (Bar, Notch, Dock, Frame, Corners)
            UnifiedShellPanel {
                id: unifiedPanel
                targetScreen: screenShellContainer.modelData
            }

            ScreenCorners {
                screen: screenShellContainer.modelData
            }

            // Reservation Windows for Exclusive Zones
            ReservationWindows {
                screen: screenShellContainer.modelData

                // Bar status for reservations
                barEnabled: {
                    const list = Config.bar.screenList;
                    return (!list || list.length === 0 || list.includes(screen.name));
                }
                barPosition: unifiedPanel.barPosition
                barPinned: unifiedPanel.pinned
                barSize: (unifiedPanel.barPosition === "left" || unifiedPanel.barPosition === "right") ? unifiedPanel.barTargetWidth : unifiedPanel.barTargetHeight
                barOuterMargin: unifiedPanel.barOuterMargin

                // Dock status for reservations
                dockEnabled: {
                    if (!(Config.dock?.enabled ?? false) || (Config.dock?.theme ?? "default") === "integrated")
                        return false;

                    const list = Config.dock?.screenList ?? [];
                    if (!list || list.length === 0)
                        return true;
                    return list.includes(screenShellContainer.modelData.name);
                }
                dockPosition: unifiedPanel.dockPosition
                dockPinned: unifiedPanel.dockPinned
                dockHeight: unifiedPanel.dockHeight
                containBar: unifiedPanel.containBar

                frameEnabled: Config.bar?.frameEnabled ?? false
                frameThickness: Config.bar?.frameThickness ?? 6
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
            active: (Config.overview?.enabled ?? true) && SuspendManager.wakeReady
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
            active: SuspendManager.wakeReady
            required property ShellScreen modelData
            sourceComponent: PresetsPopup {
                screen: presetsLoader.modelData
            }
        }
    }

    // Secure lockscreen using WlSessionLock
    WlSessionLock {
        id: sessionLock
        locked: GlobalStates.lockscreenVisible

        // WlSessionLockSurface creates automatically for each screen
        LockScreen {}
    }

    HyprlandConfig {
        id: hyprlandConfig
    }

    HyprlandKeybinds {
        id: hyprlandKeybinds
    }

    // Screenshot Tool
    Variants {
        model: Quickshell.screens

        Loader {
            id: screenshotLoader
            active: GlobalStates.screenshotToolVisible
            required property ShellScreen modelData
            sourceComponent: ScreenshotTool {
                targetScreen: screenshotLoader.modelData
            }
        }
    }

    // Screenshot Overlay (Preview)
    Variants {
        model: Quickshell.screens

        Loader {
            id: screenshotOverlayLoader
            active: SuspendManager.wakeReady
            required property ShellScreen modelData
            sourceComponent: ScreenshotOverlay {
                targetScreen: screenshotOverlayLoader.modelData
            }
        }
    }

    // Screen Record Tool
    Loader {
        id: screenRecordLoader
        active: SuspendManager.wakeReady
        source: "modules/tools/ScreenrecordTool.qml"

        Connections {
            target: GlobalStates
            function onScreenRecordToolVisibleChanged() {
                if (screenRecordLoader.status === Loader.Ready) {
                    if (GlobalStates.screenRecordToolVisible) {
                        screenRecordLoader.item.open();
                    } else {
                        screenRecordLoader.item.close();
                    }
                }
            }
        }

        Connections {
            target: screenRecordLoader.item
            ignoreUnknownSignals: true
            function onVisibleChanged() {
                if (!screenRecordLoader.item.visible && GlobalStates.screenRecordToolVisible) {
                    GlobalStates.screenRecordToolVisible = false;
                }
            }
        }
    }

    // Mirror Tool
    Loader {
        id: mirrorLoader
        active: SuspendManager.wakeReady
        source: "modules/tools/MirrorWindow.qml"
    }

    // Settings Window
    Loader {
        id: settingsWindowLoader
        active: SuspendManager.wakeReady
        source: "modules/widgets/config/SettingsWindow.qml"
    }

    // OSD
    Variants {
        model: Quickshell.screens

        OSD {
            targetScreen: modelData
        }
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
            let _ = NightLightService.active;
            _ = GameModeService.toggled;
            _ = CaffeineService.inhibit;
            _ = IdleService.lockCmd; // Force init
            _ = GlobalShortcuts.appId; // Force init
        }
    }
}
