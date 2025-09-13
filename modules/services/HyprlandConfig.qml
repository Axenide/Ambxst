import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.modules.theme

QtObject {
    id: root

    property Process hyprctlProcess: Process {}

    function getColorValue(colorName) {
        switch(colorName) {
            case "background": return Colors.adapter.background
            case "blue": return Colors.adapter.blue
            case "blueContainer": return Colors.adapter.blueContainer
            case "blueSource": return Colors.adapter.blueSource
            case "blueValue": return Colors.adapter.blueValue
            case "cyan": return Colors.adapter.cyan
            case "cyanContainer": return Colors.adapter.cyanContainer
            case "cyanSource": return Colors.adapter.cyanSource
            case "cyanValue": return Colors.adapter.cyanValue
            case "error": return Colors.adapter.error
            case "errorContainer": return Colors.adapter.errorContainer
            case "green": return Colors.adapter.green
            case "greenContainer": return Colors.adapter.greenContainer
            case "greenSource": return Colors.adapter.greenSource
            case "greenValue": return Colors.adapter.greenValue
            case "inverseOnSurface": return Colors.adapter.inverseOnSurface
            case "inversePrimary": return Colors.adapter.inversePrimary
            case "inverseSurface": return Colors.adapter.inverseSurface
            case "magenta": return Colors.adapter.magenta
            case "magentaContainer": return Colors.adapter.magentaContainer
            case "magentaSource": return Colors.adapter.magentaSource
            case "magentaValue": return Colors.adapter.magentaValue
            case "overBackground": return Colors.adapter.overBackground
            case "overBlue": return Colors.adapter.overBlue
            case "overBlueContainer": return Colors.adapter.overBlueContainer
            case "overCyan": return Colors.adapter.overCyan
            case "overCyanContainer": return Colors.adapter.overCyanContainer
            case "overError": return Colors.adapter.overError
            case "overErrorContainer": return Colors.adapter.overErrorContainer
            case "overGreen": return Colors.adapter.overGreen
            case "overGreenContainer": return Colors.adapter.overGreenContainer
            case "overMagenta": return Colors.adapter.overMagenta
            case "overMagentaContainer": return Colors.adapter.overMagentaContainer
            case "overPrimary": return Colors.adapter.overPrimary
            case "overPrimaryContainer": return Colors.adapter.overPrimaryContainer
            case "overPrimaryFixed": return Colors.adapter.overPrimaryFixed
            case "overPrimaryFixedVariant": return Colors.adapter.overPrimaryFixedVariant
            case "overRed": return Colors.adapter.overRed
            case "overRedContainer": return Colors.adapter.overRedContainer
            case "overSecondary": return Colors.adapter.overSecondary
            case "overSecondaryContainer": return Colors.adapter.overSecondaryContainer
            case "overSecondaryFixed": return Colors.adapter.overSecondaryFixed
            case "overSecondaryFixedVariant": return Colors.adapter.overSecondaryFixedVariant
            case "overSurface": return Colors.adapter.overSurface
            case "overSurfaceVariant": return Colors.adapter.overSurfaceVariant
            case "overTertiary": return Colors.adapter.overTertiary
            case "overTertiaryContainer": return Colors.adapter.overTertiaryContainer
            case "overTertiaryFixed": return Colors.adapter.overTertiaryFixed
            case "overTertiaryFixedVariant": return Colors.adapter.overTertiaryFixedVariant
            case "overWhite": return Colors.adapter.overWhite
            case "overWhiteContainer": return Colors.adapter.overWhiteContainer
            case "overYellow": return Colors.adapter.overYellow
            case "overYellowContainer": return Colors.adapter.overYellowContainer
            case "outline": return Colors.adapter.outline
            case "outlineVariant": return Colors.adapter.outlineVariant
            case "primary": return Colors.adapter.primary
            case "primaryContainer": return Colors.adapter.primaryContainer
            case "primaryFixed": return Colors.adapter.primaryFixed
            case "primaryFixedDim": return Colors.adapter.primaryFixedDim
            case "red": return Colors.adapter.red
            case "redContainer": return Colors.adapter.redContainer
            case "redSource": return Colors.adapter.redSource
            case "redValue": return Colors.adapter.redValue
            case "scrim": return Colors.adapter.scrim
            case "secondary": return Colors.adapter.secondary
            case "secondaryContainer": return Colors.adapter.secondaryContainer
            case "secondaryFixed": return Colors.adapter.secondaryFixed
            case "secondaryFixedDim": return Colors.adapter.secondaryFixedDim
            case "shadow": return Colors.adapter.shadow
            case "surface": return Colors.adapter.surface
            case "surfaceBright": return Colors.adapter.surfaceBright
            case "surfaceContainer": return Colors.adapter.surfaceContainer
            case "surfaceContainerHigh": return Colors.adapter.surfaceContainerHigh
            case "surfaceContainerHighest": return Colors.adapter.surfaceContainerHighest
            case "surfaceContainerLow": return Colors.adapter.surfaceContainerLow
            case "surfaceContainerLowest": return Colors.adapter.surfaceContainerLowest
            case "surfaceDim": return Colors.adapter.surfaceDim
            case "surfaceTint": return Colors.adapter.surfaceTint
            case "surfaceVariant": return Colors.adapter.surfaceVariant
            case "tertiary": return Colors.adapter.tertiary
            case "tertiaryContainer": return Colors.adapter.tertiaryContainer
            case "tertiaryFixed": return Colors.adapter.tertiaryFixed
            case "tertiaryFixedDim": return Colors.adapter.tertiaryFixedDim
            case "white": return Colors.adapter.white
            case "whiteContainer": return Colors.adapter.whiteContainer
            case "whiteSource": return Colors.adapter.whiteSource
            case "whiteValue": return Colors.adapter.whiteValue
            case "yellow": return Colors.adapter.yellow
            case "yellowContainer": return Colors.adapter.yellowContainer
            case "yellowSource": return Colors.adapter.yellowSource
            case "yellowValue": return Colors.adapter.yellowValue
            case "sourceColor": return Colors.adapter.sourceColor
            default: return Colors.adapter.primary
        }
    }

    function formatColorForHyprland(color) {
        // Hyprland expects colors in format: rgb(rrggbb) or rgba(rrggbbaa)
        const r = Math.round(color.r * 255).toString(16).padStart(2, '0')
        const g = Math.round(color.g * 255).toString(16).padStart(2, '0')
        const b = Math.round(color.b * 255).toString(16).padStart(2, '0')
        const a = Math.round(color.a * 255).toString(16).padStart(2, '0')
        
        if (color.a === 1.0) {
            return `rgb(${r}${g}${b})`
        } else {
            return `rgba(${r}${g}${b}${a})`
        }
    }

    function applyHyprlandConfig() {
        const activeColor = getColorValue(Config.hyprland.activeBorderColor)
        const inactiveColor = getColorValue(Config.hyprland.inactiveBorderColor)
        
        // Para el color inactivo, usar con opacidad completa como especificaste
        const inactiveColorWithFullOpacity = Qt.rgba(inactiveColor.r, inactiveColor.g, inactiveColor.b, 1.0)
        
        const activeColorFormatted = formatColorForHyprland(activeColor)
        const inactiveColorFormatted = formatColorForHyprland(inactiveColorWithFullOpacity)
        
        // Usar batch para aplicar todos los comandos de una vez
        const batchCommand = `keyword general:col.active_border ${activeColorFormatted} ; keyword general:col.inactive_border ${inactiveColorFormatted} ; keyword general:border_size ${Config.hyprland.borderSize} ; keyword decoration:rounding ${Config.hyprlandRounding}`
        
        hyprctlProcess.command = ["hyprctl", "--batch", batchCommand]
        hyprctlProcess.running = true
    }



    property Connections configConnections: Connections {
        target: Config.loader
        function onFileChanged() { applyHyprlandConfig() }
    }

    Component.onCompleted: {
        applyHyprlandConfig()
    }
}