import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

QtObject {
    id: root

    function generate(Colors) {
        if (!Colors)
            return;

        const fmt = color => color.toString();
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
            "[window]",
            `opacity = ${backgroundOpacity}`,
            "",
            "[colors.primary]",
            `foreground = "${foreground}"`,
            `background = "${background}"`,
            "",
            "[colors.cursor]",
            `text = "${cursorText}"`,
            `cursor = "${cursor}"`,
            "",
            "[colors.selection]",
            `text = "${selectionForeground}"`,
            `background = "${selectionBackground}"`,
            "",
            "[colors.normal]",
            `black = "${ansiColors[0]}"`,
            `red = "${ansiColors[1]}"`,
            `green = "${ansiColors[2]}"`,
            `yellow = "${ansiColors[3]}"`,
            `blue = "${ansiColors[4]}"`,
            `magenta = "${ansiColors[5]}"`,
            `cyan = "${ansiColors[6]}"`,
            `white = "${ansiColors[7]}"`,
            "",
            "[colors.bright]",
            `black = "${brightColors[0]}"`,
            `red = "${brightColors[1]}"`,
            `green = "${brightColors[2]}"`,
            `yellow = "${brightColors[3]}"`,
            `blue = "${brightColors[4]}"`,
            `magenta = "${brightColors[5]}"`,
            `cyan = "${brightColors[6]}"`,
            `white = "${brightColors[7]}"`
        ];
        const conf = lines.join(String.fromCharCode(10));
        writer.text = conf;

        const themePath = Quickshell.env("HOME") + "/.cache/ambxst/alacritty.toml";
        const newline = String.fromCharCode(10);
        const cmd = [
            `mkdir -p "$(dirname "${themePath}")" && cat > "${themePath}" <<'AMBXST_ALACRITTY_THEME'`,
            conf,
            "AMBXST_ALACRITTY_THEME",
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
            onStreamFinished: console.log("AlacrittyGenerator: Colors generated.")
        }
        stderr: StdioCollector {
            onStreamFinished: err => {
                if (err)
                    console.error("AlacrittyGenerator Error:", err);
            }
        }
    }
}
