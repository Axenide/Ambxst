import QtQuick
import qs.modules.components
import qs.modules.theme
import qs.modules.services

ToggleButton {
    id: toolsButton
    buttonIcon: Icons.toolbox
    tooltipText: "Tools"
    onToggle: function () {
        if (Visibilities.currentActiveModule === "tools") {
            Visibilities.setActiveModule("");
        } else {
            Visibilities.setActiveModule("tools");
        }
    }
}
