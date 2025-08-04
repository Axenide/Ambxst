pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    FileView {
        id: loader
        path: Qt.resolvedUrl("./config.json")
        preload: true
        watchChanges: true
        onFileChanged: reload()

        adapter: JsonAdapter {
            property JsonObject theme: JsonObject {
                property bool oledMode: false
                property int roundness: 16
                property string iconFont: "nerd"
                property string defaultFont: "Roboto Condensed"
                property int animDuration: 300
            }

            property JsonObject bar: JsonObject {
                property bool bottom: false
                property bool borderless: false
                property string launcherNerdIcon: ""
                property string launcherTablerIcon: "f1fd"
                property string launcherPhosphorIcon: ""
                property bool showBackground: true
                property bool verbose: true
                property list<string> screenList: []
            }

            property JsonObject workspaces: JsonObject {
                property int shown: 10
                property bool showAppIcons: true
                property bool alwaysShowNumbers: false
                property bool showNumbers: false
            }
        }
    }

    // Theme configuration
    property bool oledMode: loader.adapter.theme.oledMode
    property int roundness: loader.adapter.theme.roundness
    property string iconFont: loader.adapter.theme.iconFont
    property string defaultFont: loader.adapter.theme.defaultFont
    property int animDuration: loader.adapter.theme.animDuration

    // Bar configuration
    property QtObject bar: loader.adapter.bar
    property string launcherIcon: iconFont === "nerd" ? loader.adapter.bar.launcherNerdIcon : iconFont === "tabler" ? loader.adapter.bar.launcherTablerIcon : iconFont === "phosphor" ? loader.adapter.bar.launcherPhosphorIcon : loader.adapter.bar.launcherIcon

    // Workspace configuration
    property QtObject workspaces: loader.adapter.workspaces
}
