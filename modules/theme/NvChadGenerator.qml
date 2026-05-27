import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    function generate(Colors) {
        if (!Colors) return

        const fmt = (c) => c.toString()

        const onBackground = fmt(Colors.overBackground)
        const background = fmt(Colors.background)
        const surfaceVariant = fmt(Colors.surfaceVariant)
        const outline = fmt(Colors.outline)
        const red = fmt(Colors.red)
        const tertiary = fmt(Colors.tertiary)
        const green = fmt(Colors.green)
        const blue = fmt(Colors.blue)
        const yellow = fmt(Colors.yellow)
        const secondaryContainer = fmt(Colors.secondaryContainer)
        const primaryFixedDim = fmt(Colors.primaryFixedDim)
        const cyan = fmt(Colors.cyan)
        const onSurfaceVariant = fmt(Colors.overSurfaceVariant)
        const onSurface = fmt(Colors.overSurface)
        const inverseSurface = fmt(Colors.inverseSurface)

        let lua = ""
        lua += "local M = {}\n\n"
        lua += "local lighten = require(\"base46.colors\").change_hex_lightness\n\n"

        lua += "M.base_30 = {\n"
        lua += `\twhite = "${onBackground}",\n`
        lua += `\tblack = "${background}",\n`
        lua += `\tdarker_black = lighten("${background}", -3),\n`
        lua += `\tblack2 = lighten("${background}", 6),\n`
        lua += `\tone_bg = lighten("${background}", 10),\n`
        lua += `\tone_bg2 = lighten("${background}", 16),\n`
        lua += `\tone_bg3 = lighten("${background}", 22),\n`
        lua += `\tgrey = "${surfaceVariant}",\n`
        lua += `\tgrey_fg = lighten("${surfaceVariant}", -10),\n`
        lua += `\tgrey_fg2 = lighten("${surfaceVariant}", -20),\n`
        lua += `\tlight_grey = "${outline}",\n`
        lua += `\tred = "${red}",\n`
        lua += `\tbaby_pink = lighten("${red}", 10),\n`
        lua += `\tpink = "${tertiary}",\n`
        lua += `\tline = "${outline}",\n`
        lua += `\tgreen = "${green}",\n`
        lua += `\tvibrant_green = lighten("${green}", 10),\n`
        lua += `\tblue = "${blue}",\n`
        lua += `\tnord_blue = lighten("${blue}", 10),\n`
        lua += `\tyellow = "${yellow}",\n`
        lua += `\tsun = lighten("${yellow}", 10),\n`
        lua += `\tpurple = "${tertiary}",\n`
        lua += `\tdark_purple = lighten("${tertiary}", -10),\n`
        lua += `\tteal = "${secondaryContainer}",\n`
        lua += `\torange = "${red}",\n`
        lua += `\tcyan = "${cyan}",\n`
        lua += `\tstatusline_bg = lighten("${background}", 6),\n`
        lua += `\tpmenu_bg = "${surfaceVariant}",\n`
        lua += `\tfolder_bg = lighten("${primaryFixedDim}", 0),\n`
        lua += `\tlightbg = lighten("${background}", 10),\n`
        lua += "}\n\n"

        lua += "M.base_16 = {\n"
        lua += `\tbase00 = "${background}",\n`
        lua += `\tbase01 = lighten("${surfaceVariant}", 0),\n`
        lua += `\tbase02 = lighten("${surfaceVariant}", 3),\n`
        lua += `\tbase03 = lighten("${outline}", 0),\n`
        lua += `\tbase04 = lighten("${onSurfaceVariant}", 0),\n`
        lua += `\tbase05 = "${onSurface}",\n`
        lua += `\tbase06 = lighten("${onSurface}", 0),\n`
        lua += `\tbase07 = "${background}",\n`
        lua += `\tbase08 = "${red}",\n`
        lua += `\tbase09 = "${yellow}",\n`
        lua += `\tbase0A = "${blue}",\n`
        lua += `\tbase0B = "${green}",\n`
        lua += `\tbase0C = "${cyan}",\n`
        lua += `\tbase0D = lighten("${blue}", 20),\n`
        lua += `\tbase0E = "${tertiary}",\n`
        lua += `\tbase0F = "${inverseSurface}",\n`
        lua += "}\n\n"

        lua += "M.type = \"dark\"\n\n"

        lua += "M.polish_hl = {\n"
        lua += "\tdefaults = {\n"
        lua += "\t\tComment = {\n"
        lua += "\t\t\titalic = true,\n"
        lua += "\t\t\tfg = M.base_16.base03,\n"
        lua += "\t\t},\n"
        lua += "\t},\n"
        lua += "\tSyntax = {\n"
        lua += "\t\tString = {\n"
        lua += `\t\t\tfg = "${tertiary}",\n`
        lua += "\t\t},\n"
        lua += "\t},\n"
        lua += "\ttreesitter = {\n"
        lua += "\t\t[\"@comment\"] = {\n"
        lua += "\t\t\tfg = M.base_16.base03,\n"
        lua += "\t\t},\n"
        lua += "\t\t[\"@string\"] = {\n"
        lua += `\t\t\tfg = "${tertiary}",\n`
        lua += "\t\t},\n"
        lua += "\t},\n"
        lua += "}\n\n"

        lua += "return M"

        writer.text = lua
        
        const home = Quickshell.env("HOME")
        const targetPath = home + "/.cache/wal/base46-dark.lua"
        
        // Use HEREDOC to handle special characters and newlines correctly
        const cmd = `
            mkdir -p "$(dirname "${targetPath}")"
            cat <<'EOF_NVCHAD' > "${targetPath}"
${lua}
EOF_NVCHAD
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
            onStreamFinished: console.log("NvChadGenerator: Colors generated.")
        }
        stderr: StdioCollector {
            onStreamFinished: (err) => {
                if (err) console.error("NvChadGenerator Error:", err)
            }
        }
    }
}
