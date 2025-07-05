import QtQuick
import Quickshell
import "./modules/bar/"

ShellRoot {
    id: root

    Loader {
        active: true
        sourceComponent: Bar {}
    }
}
