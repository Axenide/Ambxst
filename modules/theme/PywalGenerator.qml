import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.globals

QtObject {
    id: root

    function generate(Colors) {
        if (!Colors) return

        const fmt = (c) => c.toString()
        const image = GlobalStates.wallpaperManager ? GlobalStates.wallpaperManager.currentWallpaper : ""

        // Helper to escape double quotes for shell echo
        const escape = (str) => str.replace(/\\/g, "\\\\").replace(/"/g, '\\"')
        
        // Helper to darken color (percent 0-100)
        // Qt.tint with black. 12.5% -> 0.125
        const darken = (c, percent) => Qt.tint(c, "#000000", percent / 100).toString()

        // 1. ~/.cache/wal/colors
        // Mapped based on user input order
        let c0 = fmt(Colors.background)       // background
        let c1 = fmt(Colors.surfaceVariant)   // surface_variant
        let c2 = fmt(Colors.red)              // red
        let c3 = fmt(Colors.lightRed)         // red lighten 5.0
        let c4 = fmt(Colors.green)            // green
        let c5 = fmt(Colors.lightGreen)       // green lighten 5.0
        let c6 = fmt(Colors.yellow)           // yellow
        let c7 = fmt(Colors.lightYellow)      // yellow lighten 5.0
        let c8 = fmt(Colors.primary)          // primary
        let c9 = fmt(Colors.lightBlue)        // blue lighten 5.0 (mapped to lightBlue)
        let c10 = fmt(Colors.magenta)         // magenta
        let c11 = fmt(Colors.lightMagenta)    // magenta lighten 5.0
        let c12 = fmt(Colors.cyan)            // cyan
        let c13 = fmt(Colors.lightCyan)       // cyan lighten 5.0
        let c14 = fmt(Colors.overSurface)     // on_surface
        let c15 = fmt(Colors.overSurface)     // on_surface

        let colorsContent = ""
        colorsContent += c0 + "\n"
        colorsContent += c1 + "\n"
        colorsContent += c2 + "\n"
        colorsContent += c3 + "\n"
        colorsContent += c4 + "\n"
        colorsContent += c5 + "\n"
        colorsContent += c6 + "\n"
        colorsContent += c7 + "\n"
        colorsContent += c8 + "\n"
        colorsContent += c9 + "\n"
        colorsContent += c10 + "\n"
        colorsContent += c11 + "\n"
        colorsContent += c12 + "\n"
        colorsContent += c13 + "\n"
        colorsContent += c14 + "\n"
        colorsContent += c15 + "\n"

        // 2. ~/.cache/wal/colors.json
        const jsonColors = {
            "wallpaper": image,
            "alpha": "100",
            "special": {
                "background": darken(Colors.background, 5.0), // lighten -5.0
                "foreground": fmt(Colors.overBackground),
                "cursor": fmt(Colors.surfaceBright)
            },
            "colors": {
                "color0": fmt(Colors.background),
                "color1": fmt(Colors.surfaceVariant),
                "color2": fmt(Colors.secondaryFixedDim),
                "color3": fmt(Colors.outline),
                "color4": fmt(Colors.overSurfaceVariant),
                "color5": fmt(Colors.overSurface),
                "color6": fmt(Colors.overSurface),
                "color7": fmt(Colors.surface),
                "color8": darken(Colors.error, 10.0), // lighten -10.0
                "color9": fmt(Colors.tertiary),
                "color10": fmt(Colors.primary),
                "color11": fmt(Colors.tertiaryFixed),
                "color12": fmt(Colors.primaryFixedDim),
                "color13": fmt(Colors.surfaceBright),
                "color14": fmt(Colors.overPrimaryContainer),
                "color15": fmt(Colors.overSurface)
            }
        }
        const jsonContent = JSON.stringify(jsonColors, null, 2)

        // 3. ~/.cache/wal/colors.sh
        let shContent = ""
        shContent += `color0="${fmt(Colors.surface)}"\n`
        shContent += `color1="${darken(Colors.primary, 12.5)}"\n`
        shContent += `color2="${darken(Colors.primary, 10.0)}"\n`
        shContent += `color3="${darken(Colors.primary, 7.5)}"\n`
        shContent += `color4="${darken(Colors.primary, 5.0)}"\n`
        shContent += `color5="${darken(Colors.primary, 2.5)}"\n`
        shContent += `color6="${fmt(Colors.primary)}"\n`
        shContent += `color7="${fmt(Colors.overSurfaceVariant)}"\n`
        shContent += `color8="${fmt(Colors.surfaceVariant)}"\n`
        shContent += `color9="${darken(Colors.primaryFixed, 12.5)}"\n`
        shContent += `color10="${darken(Colors.primaryFixed, 10.0)}"\n`
        shContent += `color11="${darken(Colors.primaryFixed, 7.5)}"\n`
        shContent += `color12="${darken(Colors.primaryFixed, 5.0)}"\n`
        shContent += `color13="${darken(Colors.primaryFixed, 2.5)}"\n`
        shContent += `color14="${fmt(Colors.primaryFixed)}"\n`
        shContent += `color15="${fmt(Colors.overSurface)}"\n`

        // 4. ~/.cache/wal/wal
        const walContent = image

        // Paths
        const home = Quickshell.env("HOME")
        const walDir = home + "/.cache/wal"

        // Execute write and hooks
        // Using one command with chained operations
        const cmd = `
            mkdir -p "${walDir}" && \\
            echo "${escape(colorsContent)}" > "${walDir}/colors" && \\
            echo "${escape(jsonContent)}" > "${walDir}/colors.json" && \\
            echo "${escape(shContent)}" > "${walDir}/colors.sh" && \\
            echo "${image}" > "${walDir}/wal" && \\
            pywalfox update & \\
            walogram -B > /dev/null 2>&1 &
        `

        writerProcess.command = ["sh", "-c", cmd]
        writerProcess.running = true
    }

    property Process writerProcess: Process {
        id: writerProcess
        running: false
        stdout: StdioCollector {
            onStreamFinished: console.log("PywalGenerator: Colors generated.")
        }
        stderr: StdioCollector {
            onStreamFinished: (err) => {
                if (err) console.error("PywalGenerator Error:", err)
            }
        }
    }
}
