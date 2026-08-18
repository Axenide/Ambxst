import QtQuick
import qs.modules.globals
import qs.modules.services
import qs.config
import qs.modules.components
import qs.modules.theme

ToggleButton {
    buttonIcon: Icons.overview
    tooltipText: "Open Window Overview"

    onToggle: function () {
        // On niri use the compositor's built-in overview (real windows).
        if (AxctlService.toggleOverview()) {
            return;
        }
        if (GlobalStates.overviewOpen) {
            Visibilities.setActiveModule("");
        } else {
            Visibilities.setActiveModule("overview");
        }
    }
}
