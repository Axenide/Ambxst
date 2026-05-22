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
        if (GlobalStates.overviewOpen) {
            Visibilities.setActiveModule("");
        } else {
            Visibilities.setActiveModule("overview");
        }
    }
}
