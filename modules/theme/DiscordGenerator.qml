import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

QtObject {
    id: root

    function generate(Colors) {
        if (!Colors) return

        const toRGB = (c) => {
            return `${Math.round(c.r * 255)},${Math.round(c.g * 255)},${Math.round(c.b * 255)}`
        }
        
        const accentcolor = toRGB(Colors.primary)
        const accentcolor2 = toRGB(Colors.secondary)
        const linkcolor = toRGB(Colors.blue)
        const mentioncolor = toRGB(Colors.yellow)
        
        const font = Config.theme.font || "gg sans"

        const isLight = Config.theme.lightMode
        
        // Background derivatives
        const bg = Colors.background
        const backgroundaccent = isLight ? toRGB(Qt.darker(bg, 1.05)) : toRGB(Qt.lighter(bg, 1.66))
        const backgroundprimary = toRGB(bg)
        const backgroundsecondary = isLight ? toRGB(Qt.darker(bg, 1.1)) : toRGB(Qt.darker(bg, 1.5))
        const backgroundsecondaryalt = isLight ? toRGB(Qt.darker(bg, 1.15)) : toRGB(Qt.darker(bg, 2.0))
        const backgroundtertiary = isLight ? toRGB(Qt.darker(bg, 1.2)) : toRGB(Qt.darker(bg, 3.0))
        const backgroundfloating = isLight ? toRGB(Qt.darker(bg, 1.05)) : "0,0,0"

        // Text derivatives
        const fg = Colors.overBackground
        const textbrightest = toRGB(fg)
        const textbrighter = isLight ? toRGB(Qt.lighter(fg, 1.15)) : toRGB(Qt.darker(fg, 1.15))
        const textbright = isLight ? toRGB(Qt.lighter(fg, 1.38)) : toRGB(Qt.darker(fg, 1.38))
        const textdark = isLight ? toRGB(Qt.lighter(fg, 1.82)) : toRGB(Qt.darker(fg, 1.82))
        const textdarker = isLight ? toRGB(Qt.lighter(fg, 2.22)) : toRGB(Qt.darker(fg, 2.22))
        const textdarkest = isLight ? toRGB(Qt.lighter(fg, 3.19)) : toRGB(Qt.darker(fg, 3.19))

        let css = `/**
 * @name Ambxst
 * @description A Discord recolor theme, generated with Ambxst.
 * @author Axenide
 * @version 1.0.0
 * @invite gHG9WHyNvH
 * @website https://axeni.de/ambxst
 * @source https://github.com/Axenide/Ambxst
 * @authorId 294856304969908224
 * @authorLink https://axeni.de
*/ 

@import url('https://mwittrien.github.io/BetterDiscordAddons/Themes/DiscordRecolor/DiscordRecolor.css');

:root {
  --accentcolor: ${accentcolor};
  --accentcolor2: ${accentcolor2};
  --linkcolor: ${linkcolor};
  --mentioncolor: ${mentioncolor};
  --textbrightest: ${textbrightest};
  --textbrighter: ${textbrighter};
  --textbright: ${textbright};
  --textdark: ${textdark};
  --textdarker: ${textdarker};
  --textdarkest: ${textdarkest};
  --font: ${font}, gg sans;
  --backgroundaccent: ${backgroundaccent};
  --backgroundprimary: ${backgroundprimary};
  --backgroundsecondary: ${backgroundsecondary};
  --backgroundsecondaryalt: ${backgroundsecondaryalt};
  --backgroundtertiary: ${backgroundtertiary};
  --backgroundfloating: ${backgroundfloating};
  --settingsicons: 1;
}

/* Any custom CSS below here */ 
`

        const home = Quickshell.env("HOME")
        const vesktopPath = home + "/.config/vesktop/themes/ambxst.css"
        
        const escape = (str) => {
            if (!str) return ""
            return str.toString()
                .replace(/\\/g, "\\\\")
                .replace(/"/g, '\\"')
                .replace(/\$/g, '\\$')
                .replace(/`/g, '\\`');
        }

        const cmd = `mkdir -p "$(dirname "${vesktopPath}")" && echo "${escape(css)}" > "${vesktopPath}"`
        
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
            onStreamFinished: console.log("DiscordGenerator: Theme generated.")
        }
        stderr: StdioCollector {
            onStreamFinished: (err) => {
                if (err) {
                    const text = err.toString().trim();
                    if (text) console.error("DiscordGenerator Error:", text)
                }
            }
        }
    }
}
