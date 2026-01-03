import QtQuick
import qs.modules.components
import qs.modules.services
import qs.modules.theme
import Quickshell.Io

ActionGrid {
    id: root

    signal itemSelected

    layout: "row"
    buttonSize: 48
    iconSize: 20
    spacing: 8

    Process {
        id: actionProcess
        running: false
    }

    Component.onCompleted: {
        root.forceActiveFocus();
    }

    actions: [
        {
            icon: Icons.lock,
            tooltip: "Lock Session",
            command: "loginctl lock-session"
        },
        {
            icon: Icons.suspend,
            tooltip: "Suspend",
            command: "systemctl suspend"
        },
        {
            icon: Icons.logout,
            tooltip: "Exit Hyprland",
            command: "hyprctl dispatch exit"
        },
        {
            icon: Icons.reboot,
            tooltip: "Reboot",
            command: "systemctl reboot"
        },
        {
            icon: Icons.shutdown,
            tooltip: "Power Off",
            command: "systemctl poweroff"
        },
        {
            icon: Icons.hibernate,
            tooltip: "Hibernate",
            command: "systemctl hibernate"
        }
    ]

    onActionTriggered: action => {
        console.log("Action triggered:", action.command);
        if (action.command) {
            actionProcess.command = ["/bin/bash", "-c", action.command];
            console.log("Starting process with command:", actionProcess.command);
            actionProcess.running = true;
        }
        root.itemSelected();
    }
}
