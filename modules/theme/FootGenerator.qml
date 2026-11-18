import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

QtObject {
    id: root

    function generate(Colors) {
        if (!Colors)
            return;

        const fmt = color => color.toString().replace("#", "");
        const foreground = fmt(Colors.overSurface);
        const background = fmt(Colors.background);
        const cursor = fmt(Colors.overSurface);
        const cursorText = fmt(Colors.overSurfaceVariant);
        const selectionForeground = fmt(Colors.overSecondary);
        const selectionBackground = fmt(Colors.secondaryFixedDim);
        const backgroundOpacity = Config.theme.srBg.opacity;

        const ansiColors = [
            fmt(Colors.surfaceContainerLow),
            fmt(Colors.red),
            fmt(Colors.green),
            fmt(Colors.yellow),
            fmt(Colors.primary),
            fmt(Colors.magenta),
            fmt(Colors.cyan),
            fmt(Colors.outline)
        ];
        const brightColors = [
            fmt(Colors.surfaceBright),
            fmt(Colors.lightRed),
            fmt(Colors.lightGreen),
            fmt(Colors.lightYellow),
            fmt(Colors.lightBlue),
            fmt(Colors.lightMagenta),
            fmt(Colors.lightCyan),
            fmt(Colors.overSurface)
        ];

        const lines = [
            "[colors-dark]",
            `alpha=${backgroundOpacity}`,
            `background=${background}`,
            `foreground=${foreground}`,
            `cursor=${cursorText} ${cursor}`,
            `selection-foreground=${selectionForeground}`,
            `selection-background=${selectionBackground}`,
            `urls=${fmt(Colors.primary)}`
        ];

        ansiColors.forEach((color, index) => lines.push(`regular${index}=${color}`));
        brightColors.forEach((color, index) => lines.push(`bright${index}=${color}`));

        const conf = lines.join(String.fromCharCode(10));
        writer.text = conf;

        const themePath = Quickshell.env("HOME") + "/.cache/ambxst/foot.ini";
        const newline = String.fromCharCode(10);
        const cmd = [
            `mkdir -p "$(dirname "${themePath}")" && cat > "${themePath}" <<'AMBXST_FOOT_THEME'`,
            conf,
            "AMBXST_FOOT_THEME",
            ""
        ].join(newline);

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
            onStreamFinished: console.log("FootGenerator: Colors generated.")
        }
        stderr: StdioCollector {
            onStreamFinished: err => {
                if (err)
                    console.error("FootGenerator Error:", err);
            }
        }
    }
}
