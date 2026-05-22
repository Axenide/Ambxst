pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.globals

QtObject {
    id: root

    function toggle() {
        GlobalStates.lockscreenVisible = !GlobalStates.lockscreenVisible;
    }

    function lock() {
        GlobalStates.lockscreenVisible = true;
    }

    function unlock() {
        GlobalStates.lockscreenVisible = false;
    }

    property IpcHandler ipc: IpcHandler {
        target: "lockscreen"

        function toggle() {
            root.toggle();
        }

        function lock() {
            root.lock();
        }

        function unlock() {
            root.unlock();
        }
    }
}
