import QtQuick
import qs.modules.components
import qs.modules.theme
import qs.modules.services

ToggleButton {
    id: powerButton
    buttonIcon: Icons.shutdown
    tooltipText: "Power Menu"
    onToggle: function () {
        if (Visibilities.currentActiveModule === "powermenu") {
            Visibilities.setActiveModule("");
        } else {
            Visibilities.setActiveModule("powermenu");
        }
    }
}
