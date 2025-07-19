//@ pragma UseQApplication
import QtQuick
import Quickshell
import "./modules/bar/"
import "./modules/launcher/"
import "./modules/workspaces/"
import "./modules/notifications/"
import "./modules/wallpaper/"
import "./services/"

ShellRoot {
    id: root

    // Wallpaper for all screens
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

    // Multi-monitor support - create bar for each screen
    Variants {
        model: {
            const screens = Quickshell.screens;
            const list = ConfigOptions.bar.screenList;
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

    Loader {
        active: true
        sourceComponent: LauncherWindow {}
    }

    Loader {
        active: true
        sourceComponent: NotificationPopup {}
    }
}
