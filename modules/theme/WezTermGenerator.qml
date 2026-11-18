import QtQuick
import Quickshell
import Quickshell.Io

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
        const newline = String.fromCharCode(10);

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

        const conf = [
            "[colors]",
            `foreground = "${foreground}"`,
            `background = "${background}"`,
            `cursor_bg = "${cursor}"`,
            `cursor_fg = "${cursorText}"`,
            `cursor_border = "${cursor}"`,
            `selection_fg = "${selectionForeground}"`,
            `selection_bg = "${selectionBackground}"`,
            `ansi = [${ansiColors.map(color => `"${color}"`).join(", ")}]`,
            `brights = [${brightColors.map(color => `"${color}"`).join(", ")}]`
        ].join(newline);

        writer.text = conf;

        const themePath = Quickshell.env("HOME") + "/.cache/ambxst/ambxst.toml";
        const cmd = [
            `mkdir -p "$(dirname "${themePath}")" && cat > "${themePath}" <<'AMBXST_WEZTERM_THEME'`,
            conf,
            "AMBXST_WEZTERM_THEME",
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
            onStreamFinished: console.log("WezTermGenerator: Colors generated.")
        }
        stderr: StdioCollector {
            onStreamFinished: err => {
                if (err)
                    console.error("WezTermGenerator Error:", err);
            }
        }
    }
}
