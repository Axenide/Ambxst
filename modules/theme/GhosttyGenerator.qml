import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

QtObject {
    id: root

    function generate(Colors) {
        if (!Colors)
            return;
        const fmt = c => c.toString().replace("#", "");

        const cursor = fmt(Colors.overSurface);
        const cursorText = fmt(Colors.overSurfaceVariant);

        const foreground = fmt(Colors.overSurface);
        const background = fmt(Colors.background);
        const selectionForeground = fmt(Colors.overSecondary);
        const selectionBackground = fmt(Colors.secondaryFixedDim);
        const urlColor = fmt(Colors.primary);
        const backgroundOpacity = Config.theme.srBg.opacity;

        // black
        const color0 = fmt(Colors.surfaceContainerLow);
        const color8 = fmt(Colors.surfaceBright);

        // red
        const color1 = fmt(Colors.red);
        const color9 = fmt(Colors.lightRed);

        // green
        const color2 = fmt(Colors.green);
        const color10 = fmt(Colors.lightGreen);

        // yellow
        const color3 = fmt(Colors.yellow);
        const color11 = fmt(Colors.lightYellow);

        // blue
        // User requested primary for color4
        const color4 = fmt(Colors.primary);
        const color12 = fmt(Colors.lightBlue);

        // magenta
        const color5 = fmt(Colors.magenta);
        const color13 = fmt(Colors.lightMagenta);

        // cyan
        const color6 = fmt(Colors.cyan);
        const color14 = fmt(Colors.lightCyan);

        // white
        const color7 = fmt(Colors.outline);
        const color15 = fmt(Colors.overSurface);

        let conf = "";
        conf += `cursor-color = ${cursor}\n`;
        conf += `cursor-text = ${cursorText}\n\n`;

        conf += `foreground = ${foreground}\n`;
        conf += `background = ${background}\n`;
        conf += `background-opacity = ${backgroundOpacity}\n`;
        conf += `selection-foreground = ${selectionForeground}\n`;
        conf += `selection-background = ${selectionBackground}\n\n`;

        conf += `palette = 0=${color0}\n`;
        conf += `palette = 1=${color1}\n`;
        conf += `palette = 2=${color2}\n`;
        conf += `palette = 3=${color3}\n`;
        conf += `palette = 4=${color4}\n`;
        conf += `palette = 5=${color5}\n`;
        conf += `palette = 6=${color6}\n`;
        conf += `palette = 7=${color7}\n`;
        conf += `palette = 8=${color8}\n`;
        conf += `palette = 9=${color9}\n`;
        conf += `palette = 10=${color10}\n`;
        conf += `palette = 11=${color11}\n`;
        conf += `palette = 12=${color12}\n`;
        conf += `palette = 13=${color13}\n`;
        conf += `palette = 14=${color14}\n`;
        conf += `palette = 15=${color15}\n`;

        writer.text = conf;

        // QUICKSHELL-GIT: const ghosttyConfPath = Quickshell.cacheDir + "/ghostty/themes/ambxst";
        const ghosttyThemePath = Quickshell.env("HOME") + "/.config/ghostty/themes/ambxst";

        // Ensure directory exists and write file
        const cmd = `
            mkdir -p "$(dirname "${ghosttyThemePath}")" && \\
            echo "${conf}" > "${ghosttyThemePath}" && \\
            killall -SIGUSR2 ghostty
        `;

        writerProcess.command = ["sh", "-c", cmd];
        writerProcess.running = true;
    }

    property QtObject writer: QtObject {
        id: writer
        property string text
    }

    property Process writerProcess: Process {
        id: writerProcess
        running: false
        stdout: StdioCollector {
            onStreamFinished: console.log("GhosttyGenerator: Colors generated.")
        }
        stderr: StdioCollector {
            onStreamFinished: err => {
                if (err)
                    console.error("GhosttyGenerator Error:", err);
            }
        }
    }
}
