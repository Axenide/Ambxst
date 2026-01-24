import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    function generate(Colors) {
        if (!Colors) return

        const fmt = (c) => c.toString()

        const cursor = fmt(Colors.overSurface)
        const cursorText = fmt(Colors.overSurfaceVariant)
        
        const foreground = fmt(Colors.overSurface)
        const background = fmt(Colors.background)
        const selectionForeground = fmt(Colors.overSecondary)
        const selectionBackground = fmt(Colors.secondaryFixedDim)
        const urlColor = fmt(Colors.primary)

        // black
        const color0 = fmt(Colors.surfaceContainerLow)
        const color8 = fmt(Colors.surfaceBright)

        // red
        const color1 = fmt(Colors.red)
        const color9 = fmt(Colors.lightRed)

        // green
        const color2 = fmt(Colors.green)
        const color10 = fmt(Colors.lightGreen)

        // yellow
        const color3 = fmt(Colors.yellow)
        const color11 = fmt(Colors.lightYellow)

        // blue
        // User requested primary for color4
        const color4 = fmt(Colors.primary)
        const color12 = fmt(Colors.lightBlue)

        // magenta
        const color5 = fmt(Colors.magenta)
        const color13 = fmt(Colors.lightMagenta)

        // cyan
        const color6 = fmt(Colors.cyan)
        const color14 = fmt(Colors.lightCyan)

        // white
        const color7 = fmt(Colors.outline)
        const color15 = fmt(Colors.overSurface)

        let conf = ""
        conf += `cursor ${cursor}\n`
        conf += `cursor_text_color ${cursorText}\n\n`
        
        conf += `foreground ${foreground}\n`
        conf += `background ${background}\n`
        conf += `selection_foreground ${selectionForeground}\n`
        conf += `selection_background ${selectionBackground}\n`
        conf += `url_color ${urlColor}\n\n`

        conf += `# black\n`
        conf += `color0 ${color0}\n`
        conf += `color8 ${color8}\n\n`

        conf += `# red\n`
        conf += `color1 ${color1}\n`
        conf += `color9 ${color9}\n\n`

        conf += `# green\n`
        conf += `color2 ${color2}\n`
        conf += `color10 ${color10}\n\n`

        conf += `# yellow\n`
        conf += `color3 ${color3}\n`
        conf += `color11 ${color11}\n\n`

        conf += `# blue\n`
        conf += `color4 ${color4}\n`
        conf += `color12 ${color12}\n\n`

        conf += `# magenta\n`
        conf += `color5 ${color5}\n`
        conf += `color13 ${color13}\n\n`

        conf += `# cyan\n`
        conf += `color6 ${color6}\n`
        conf += `color14 ${color14}\n\n`

        conf += `# white\n`
        conf += `color7 ${color7}\n`
        conf += `color15 ${color15}\n`

        writer.text = conf
        
        const kittyConfPath = Quickshell.dataPath("colors/kitty.conf")
        
        // Ensure directory exists and write file
        const cmd = `
            mkdir -p "$(dirname "${kittyConfPath}")" && \\
            echo "${conf}" > "${kittyConfPath}" && \\
            pkill -SIGUSR1 kitty
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
            onStreamFinished: console.log("KittyGenerator: Colors generated.")
        }
        stderr: StdioCollector {
            onStreamFinished: (err) => {
                if (err) console.error("KittyGenerator Error:", err)
            }
        }
    }
}
