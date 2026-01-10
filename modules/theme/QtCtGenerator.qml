import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    function generate(Colors) {
        if (!Colors) return

        // Helper to format color
        const fmt = (c) => c.toString()

        // Core colors
        const bg = fmt(Colors.background)
        const fg = fmt(Colors.overBackground)
        const surface = fmt(Colors.surface)
        const primary = fmt(Colors.primary)
        const secondary = fmt(Colors.secondary)
        const error = fmt(Colors.error)
        const inactive = fmt(Colors.outline)
        const link = fmt(Colors.tertiary)
        const selection = fmt(Colors.primary)
        const selectionFg = fmt(Colors.overPrimary)

        // Construct INI content
        let ini = ""

        ini += "[ColorEffects:Disabled]\n"
        ini += `Color=${bg}\n`
        ini += "ColorAmount=0.5\n"
        ini += "ColorEffect=3\n"
        ini += "ContrastAmount=0\n"
        ini += "ContrastEffect=0\n"
        ini += "IntensityAmount=0\n"
        ini += "IntensityEffect=0\n\n"

        ini += "[ColorEffects:Inactive]\n"
        ini += "ChangeSelectionColor=true\n"
        ini += `Color=${bg}\n`
        ini += "ColorAmount=0.025\n"
        ini += "ColorEffect=0\n"
        ini += "ContrastAmount=0.1\n"
        ini += "ContrastEffect=0\n"
        ini += "Enable=true\n"
        ini += "IntensityAmount=0\n"
        ini += "IntensityEffect=0\n\n"

        ini += "[Colors:Button]\n"
        ini += `BackgroundAlternate=${surface}\n`
        ini += `BackgroundNormal=${surface}\n`
        ini += `DecorationFocus=${primary}\n`
        ini += `DecorationHover=${primary}\n`
        ini += `ForegroundActive=${fg}\n`
        ini += `ForegroundInactive=${inactive}\n`
        ini += `ForegroundLink=${link}\n`
        ini += `ForegroundNegative=${error}\n`
        ini += `ForegroundNeutral=${fg}\n`
        ini += `ForegroundNormal=${fg}\n`
        ini += `ForegroundPositive=${secondary}\n`
        ini += `ForegroundVisited=${fmt(Colors.tertiary)}\n`
        ini += "\n"

        ini += "[Colors:Complementary]\n"
        ini += `BackgroundAlternate=${bg}\n`
        ini += `BackgroundNormal=${bg}\n`
        ini += `DecorationFocus=${primary}\n`
        ini += `DecorationHover=${primary}\n`
        ini += `ForegroundActive=${fg}\n`
        ini += `ForegroundInactive=${inactive}\n`
        ini += `ForegroundLink=${link}\n`
        ini += `ForegroundNegative=${error}\n`
        ini += `ForegroundNeutral=${fg}\n`
        ini += `ForegroundNormal=${fg}\n`
        ini += `ForegroundPositive=${secondary}\n`
        ini += `ForegroundVisited=${fmt(Colors.tertiary)}\n`
        ini += "\n"

        ini += "[Colors:Header]\n"
        ini += `BackgroundAlternate=${bg}\n`
        ini += `BackgroundNormal=${bg}\n`
        ini += `DecorationFocus=${primary}\n`
        ini += `DecorationHover=${primary}\n`
        ini += `ForegroundActive=${fg}\n`
        ini += `ForegroundInactive=${inactive}\n`
        ini += `ForegroundLink=${link}\n`
        ini += `ForegroundNegative=${error}\n`
        ini += `ForegroundNeutral=${fg}\n`
        ini += `ForegroundNormal=${fg}\n`
        ini += `ForegroundPositive=${secondary}\n`
        ini += `ForegroundVisited=${fmt(Colors.tertiary)}\n`
        ini += "\n"

        ini += "[Colors:Header][Inactive]\n"
        ini += `BackgroundAlternate=${bg}\n`
        ini += `BackgroundNormal=${bg}\n`
        ini += `DecorationFocus=${primary}\n`
        ini += `DecorationHover=${primary}\n`
        ini += `ForegroundActive=${fg}\n`
        ini += `ForegroundInactive=${inactive}\n`
        ini += `ForegroundLink=${link}\n`
        ini += `ForegroundNegative=${error}\n`
        ini += `ForegroundNeutral=${fg}\n`
        ini += `ForegroundNormal=${fg}\n`
        ini += `ForegroundPositive=${secondary}\n`
        ini += `ForegroundVisited=${fmt(Colors.tertiary)}\n`
        ini += "\n"

        ini += "[Colors:Selection]\n"
        ini += `BackgroundAlternate=${selection}\n`
        ini += `BackgroundNormal=${selection}\n`
        ini += `DecorationFocus=${selection}\n`
        ini += `DecorationHover=${selection}\n`
        ini += `ForegroundActive=${selectionFg}\n`
        ini += `ForegroundInactive=${selectionFg}\n`
        ini += `ForegroundLink=${link}\n`
        ini += `ForegroundNegative=${error}\n`
        ini += `ForegroundNeutral=${selectionFg}\n`
        ini += `ForegroundNormal=${selectionFg}\n`
        ini += `ForegroundPositive=${secondary}\n`
        ini += `ForegroundVisited=${fmt(Colors.tertiary)}\n`
        ini += "\n"

        ini += "[Colors:Tooltip]\n"
        ini += `BackgroundAlternate=${surface}\n`
        ini += `BackgroundNormal=${bg}\n`
        ini += `DecorationFocus=${primary}\n`
        ini += `DecorationHover=${primary}\n`
        ini += `ForegroundActive=${fg}\n`
        ini += `ForegroundInactive=${inactive}\n`
        ini += `ForegroundLink=${link}\n`
        ini += `ForegroundNegative=${error}\n`
        ini += `ForegroundNeutral=${fg}\n`
        ini += `ForegroundNormal=${fg}\n`
        ini += `ForegroundPositive=${secondary}\n`
        ini += `ForegroundVisited=${fmt(Colors.tertiary)}\n`
        ini += "\n"

        ini += "[Colors:View]\n"
        ini += `BackgroundAlternate=${surface}\n`
        ini += `BackgroundNormal=${bg}\n`
        ini += `DecorationFocus=${primary}\n`
        ini += `DecorationHover=${primary}\n`
        ini += `ForegroundActive=${fg}\n`
        ini += `ForegroundInactive=${inactive}\n`
        ini += `ForegroundLink=${link}\n`
        ini += `ForegroundNegative=${error}\n`
        ini += `ForegroundNeutral=${fg}\n`
        ini += `ForegroundNormal=${fg}\n`
        ini += `ForegroundPositive=${secondary}\n`
        ini += `ForegroundVisited=${fmt(Colors.tertiary)}\n`
        ini += "\n"

        ini += "[Colors:Window]\n"
        ini += `BackgroundAlternate=${surface}\n`
        ini += `BackgroundNormal=${bg}\n`
        ini += `DecorationFocus=${primary}\n`
        ini += `DecorationHover=${primary}\n`
        ini += `ForegroundActive=${fg}\n`
        ini += `ForegroundInactive=${inactive}\n`
        ini += `ForegroundLink=${link}\n`
        ini += `ForegroundNegative=${error}\n`
        ini += `ForegroundNeutral=${fg}\n`
        ini += `ForegroundNormal=${fg}\n`
        ini += `ForegroundPositive=${secondary}\n`
        ini += `ForegroundVisited=${fmt(Colors.tertiary)}\n`
        ini += "\n"

        ini += "[General]\n"
        ini += "ColorScheme=Ambxst\n"
        ini += "Name=Ambxst\n"
        ini += "shadeSortColumn=true\n"
        ini += "\n"
        
        ini += "[KDE]\n"
        ini += "contrast=4\n"
        ini += "\n"
        
        ini += "[WM]\n"
        ini += `activeBackground=${bg}\n`
        ini += "activeBlend=252,252,252\n" 
        ini += `activeForeground=${fg}\n`
        ini += `inactiveBackground=${fmt(Colors.surfaceDim)}\n`
        ini += "inactiveBlend=161,169,177\n"
        ini += `inactiveForeground=${inactive}\n`

        const home = Quickshell.env("HOME")
        const ambxstDir = home + "/.config/Ambxst"
        const qt5Dir = home + "/.config/qt5ct/colors"
        const qt6Dir = home + "/.config/qt6ct/colors"

        writer.text = ini
        
        // Single command to ensure dirs and write files
        const cmd = `
            mkdir -p "${ambxstDir}" "${qt5Dir}" "${qt6Dir}" && \\
            echo "${ini}" | tee "${ambxstDir}/ambxst.colors" "${qt5Dir}/ambxst.colors" "${qt6Dir}/ambxst.colors" > /dev/null
        `
        
        writerProcess.command = ["sh", "-c", cmd]
        writerProcess.running = true
    }
    
    property QtObject writer: QtObject {
        id: writer
        property string text
    }

    property Process writerProcess: Process {
        id: writerProcess
        running: false
        stdout: StdioCollector {
            onStreamFinished: console.log("QtCtGenerator: Colors generated.")
        }
        stderr: StdioCollector {
            onStreamFinished: (err) => {
                if (err) console.error("QtCtGenerator Error:", err)
            }
        }
    }
}
