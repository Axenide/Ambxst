pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    property var widgets: []

    function registerWidget(widget) {
        if (root.widgets.includes(widget)) return;
        root.widgets = root.widgets.concat([widget]);
    }

    function unregisterWidget(widget) {
        root.widgets = root.widgets.filter(item => item !== widget);
    }

    property IpcHandler ipcHandler: IpcHandler {
        target: "pomodoro"

        function check() {
            const widget = root.widgets[0];
            if (widget) widget.requestPopupOpen();
        }

        function stop() {
            const widget = root.widgets[0];
            if (!widget) return;
            widget.stopAlarm();
            widget.isRunning = false;
        }
    }
}
