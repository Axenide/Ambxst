import QtQuick
import Quickshell.Hyprland._GlobalShortcuts
import qs.modules.globals
import qs.modules.services

Item {
    id: root

    GlobalShortcut {
        id: launcherShortcut
        appid: "ambyst"
        name: "launcher"
        description: "Toggle application launcher"

        onPressed: {
            console.log("Launcher shortcut pressed");
            let visibilities = Visibilities.getForActive();
            if (!visibilities) return;
            
            // Toggle launcher - si ya está abierto, se cierra; si no, abre launcher y cierra dashboard
            if (visibilities.launcher) {
                visibilities.launcher = false;
            } else {
                visibilities.dashboard = false;
                visibilities.overview = false;
                visibilities.launcher = true;
            }
        }
    }

    GlobalShortcut {
        id: dashboardShortcut
        appid: "ambyst"
        name: "dashboard"
        description: "Toggle dashboard"

        onPressed: {
            console.log("Dashboard shortcut pressed");
            let visibilities = Visibilities.getForActive();
            if (!visibilities) return;
            
            // Toggle dashboard - si ya está abierto, se cierra; si no, abre dashboard y cierra launcher
            if (visibilities.dashboard) {
                visibilities.dashboard = false;
            } else {
                visibilities.launcher = false;
                visibilities.overview = false;
                visibilities.dashboard = true;
            }
        }
    }

    GlobalShortcut {
        id: overviewShortcut
        appid: "ambyst"
        name: "overview"
        description: "Toggle window overview"

        onPressed: {
            console.log("Overview shortcut pressed");
            let visibilities = Visibilities.getForActive();
            if (!visibilities) return;
            
            // Toggle overview - si ya está abierto, se cierra; si no, abre overview y cierra otros
            if (visibilities.overview) {
                visibilities.overview = false;
            } else {
                visibilities.launcher = false;
                visibilities.dashboard = false;
                visibilities.overview = true;
            }
        }
    }
}
