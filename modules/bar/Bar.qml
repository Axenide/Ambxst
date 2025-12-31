import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import qs.modules.bar.workspaces
import qs.modules.theme
import qs.modules.bar.clock
import qs.modules.bar.systray
import qs.modules.widgets.overview
import qs.modules.widgets.dashboard
import qs.modules.widgets.powermenu
import qs.modules.widgets.presets
import qs.modules.corners
import qs.modules.components
import qs.modules.services
import qs.modules.globals
import qs.modules.bar
import qs.config
import "." as Bar

PanelWindow {
    id: panel

    property string position: ["top", "bottom", "left", "right"].includes(Config.bar.position) ? Config.bar.position : "top"
    property string orientation: position === "left" || position === "right" ? "vertical" : "horizontal"

    // Integrated dock configuration
    readonly property bool integratedDockEnabled: (Config.dock?.enabled ?? false) && (Config.dock?.theme ?? "default") === "integrated"
    // Map dock position for integrated: "bottom"/"top" should be "center" for integrated dock
    // In vertical orientation, "center" falls back to "left" (start) to avoid layout issues
    readonly property string integratedDockPosition: {
        const pos = Config.dock?.position ?? "center";
        // For integrated, "bottom" and "top" don't make sense - map to "center"
        let mappedPos = (pos === "bottom" || pos === "top") ? "center" : pos;
        // In vertical orientation, center is not supported - fallback to "left" (start)
        if (panel.orientation === "vertical" && mappedPos === "center") {
            return "left";
        }
        return mappedPos;
    }

    anchors {
        top: position !== "bottom"
        bottom: position !== "top"
        left: position !== "right"
        right: position !== "left"
    }

    color: "transparent"

    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.layer: WlrLayer.Top

    exclusiveZone: Config.showBackground ? 44 : 40
    exclusionMode: ExclusionMode.Ignore

    // Altura implícita incluye espacio extra para animaciones / futuros elementos.
    implicitHeight: Screen.height

    // La máscara sigue a la barra principal para mantener correcta interacción en ambas posiciones.
    mask: Region {
        item: bar
    }

    Component.onCompleted: {
        Visibilities.registerBar(screen.name, bar);
        Visibilities.registerPanel(screen.name, panel);
    }

    Component.onDestruction: {
        Visibilities.unregisterBar(screen.name);
        Visibilities.unregisterPanel(screen.name);
    }

    Item {
        id: bar

        layer.enabled: true
        layer.effect: Shadow {}

        states: [
            State {
                name: "top"
                when: panel.position === "top"
                AnchorChanges {
                    target: bar
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: undefined
                }
                PropertyChanges {
                    target: bar
                    width: undefined
                    height: 44
                }
            },
            State {
                name: "bottom"
                when: panel.position === "bottom"
                AnchorChanges {
                    target: bar
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: undefined
                    anchors.bottom: parent.bottom
                }
                PropertyChanges {
                    target: bar
                    width: undefined
                    height: 44
                }
            },
            State {
                name: "left"
                when: panel.position === "left"
                AnchorChanges {
                    target: bar
                    anchors.left: parent.left
                    anchors.right: undefined
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                }
                PropertyChanges {
                    target: bar
                    width: 44
                    height: undefined
                }
            },
            State {
                name: "right"
                when: panel.position === "right"
                AnchorChanges {
                    target: bar
                    anchors.left: undefined
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                }
                PropertyChanges {
                    target: bar
                    width: 44
                    height: undefined
                }
            }
        ]

        BarBg {
            id: barBg
            anchors.fill: parent
            position: panel.position
        }


        RowLayout {
            id: horizontalLayout
            visible: panel.orientation === "horizontal"
            anchors.fill: parent
            anchors.margins: 4
            spacing: 4

            // Obtener referencia al notch de esta pantalla
            readonly property var notchContainer: Visibilities.getNotchForScreen(panel.screen.name)

            LauncherButton {
                id: launcherButton
            }

            Workspaces {
                orientation: panel.orientation
                bar: QtObject {
                    property var screen: panel.screen
                }
                layer.enabled: false
            }

            LayoutSelectorButton {
                id: layoutSelectorButton
                bar: panel
                layerEnabled: false
            }

            Bar.IntegratedDock {
                bar: panel
                orientation: panel.orientation
                visible: panel.orientation === "horizontal" && integratedDockEnabled && integratedDockPosition === "center"
            }

            Item {
                Layout.fillWidth: true
                visible: !(panel.orientation === "horizontal" && integratedDockEnabled && integratedDockPosition === "center")
            }

            PresetsButton {
                id: presetsButton
            }

            ToolsButton {
                id: toolsButton
            }

            SysTray {
                bar: panel
                layer.enabled: Config.showBackground
            }

            ControlsButton {
                id: controlsButton
                bar: panel
                layerEnabled: false
            }

            Bar.BatteryIndicator {
                id: batteryIndicator
                bar: panel
                layerEnabled: false
            }

            Clock {
                id: clockComponent
                bar: panel
                layer.enabled: Config.showBackground
            }

            PowerButton {
                id: powerButton
            }
        }

        ColumnLayout {
            id: verticalLayout
            visible: panel.orientation === "vertical"
            anchors.fill: parent
            anchors.margins: 4
            spacing: 4

            LauncherButton {
                id: launcherButtonVert
                Layout.preferredHeight: 36
            }

            SysTray {
                bar: panel
                layer.enabled: Config.showBackground
            }

            ControlsButton {
                id: controlsButtonVert
                bar: panel
                layerEnabled: false
            }

            LayoutSelectorButton {
                id: layoutSelectorButtonVert
                bar: panel
                layerEnabled: false
            }

            Workspaces {
                orientation: panel.orientation
                bar: QtObject {
                    property var screen: panel.screen
                }
                layer.enabled: false
            }

            Bar.IntegratedDock {
                bar: panel
                orientation: panel.orientation
                visible: integratedDockEnabled
            }

            Item {
                Layout.fillHeight: true
                visible: !integratedDockEnabled
            }

            ToolsButton {
                id: toolsButtonVert
            }

            PresetsButton {
                id: presetsButtonVert
            }

            Bar.BatteryIndicator {
                id: batteryIndicatorVert
                bar: panel
                layerEnabled: false
            }

            Clock {
                id: clockComponentVert
                bar: panel
                layer.enabled: Config.showBackground
            }

            PowerButton {
                id: powerButtonVert
                Layout.preferredHeight: 36
            }
        }
    }
}
