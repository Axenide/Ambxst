pragma Singleton

import QtQuick
import qs.config

QtObject {
    // Icon font
    readonly property string font: Config.theme.fillIcons ? "Phosphor-Fill" : "Phosphor-Bold"
    // Overview button
    readonly property string overview: ""
    // Powermenu
    readonly property string lock: ""
    readonly property string suspend: ""
    readonly property string logout: ""
    readonly property string reboot: ""
    readonly property string shutdown: ""
    // Caret
    readonly property string caretLeft: ""
    readonly property string caretRight: ""
    readonly property string caretUp: ""
    readonly property string caretDown: ""
    // Dashboard
    readonly property string widgets: ""
    readonly property string pins: ""
    readonly property string kanban: ""
    readonly property string wallpapers: ""
    readonly property string assistant: ""
    // Launcher
    readonly property string apps: ""
    readonly property string terminal: ""
    readonly property string terminalWindow: ""
    readonly property string clipboard: ""
    readonly property string image: ""
    readonly property string clip: ""
    // Misc
    readonly property string accept: ""
    readonly property string cancel: ""
    readonly property string add: ""
    readonly property string alert: ""
    readonly property string edit: ""
    readonly property string trash: ""
    readonly property string copy: ""
}
