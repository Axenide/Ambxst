pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

// Reusable wl-copy process. Created per copy with `CopyProcess.createObject(parent, {content: ...})`
// and destroys itself on exit. Never string-build QML or shell for clipboard writes.
Component {
    id: root

    property string content: ""

    Process {
        command: ["wl-copy", root.content]
        running: true
        onExited: (code, status) => destroy()
    }
}
