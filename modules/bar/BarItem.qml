pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.bar.workspaces
import qs.modules.theme
import qs.modules.bar.clock
import qs.modules.bar.systray
import qs.modules.widgets.dashboard
import qs.modules.widgets.powermenu
import qs.modules.widgets.presets
import qs.modules.components
import qs.modules.services
import qs.modules.globals
import qs.modules.bar
import qs.config
import "." as Bar

Item {
    id: root

    property string itemId: ""
    property var bar: null
    property bool vertical: false
    property real startRadius: 0
    property real endRadius: 0
    property bool enableShadow: true
    property var itemsList: []

    readonly property var orientation: root.vertical ? "vertical" : "horizontal"
    readonly property bool isSpring: root.itemId === "spring"
    readonly property bool integratedDockEnabled: (Config.dock && Config.dock.enabled !== undefined ? Config.dock.enabled : false) && (Config.dock && Config.dock.theme !== undefined ? Config.dock.theme : "default") === "integrated"
    readonly property bool pinHidden: root.itemId === "pin" && !(Config.bar && Config.bar.showPinButton !== undefined ? Config.bar.showPinButton : true)

    readonly property int springsBefore: {
        var c = 0;
        for (var i = 0; i < index; i++)
            if (itemsList[i] === "spring")
                c++;
        return c;
    }
    readonly property bool placeDock: root.isSpring && root.integratedDockEnabled && root.springsBefore === 0

    // Alignment of the integrated dock within its spring region
    readonly property string dockAlign: {
        const pos = (Config.dock && Config.dock.position !== undefined) ? Config.dock.position : "center";
        if (root.vertical)
            return "center";
        if (pos === "left" || pos === "start")
            return "start";
        if (pos === "right" || pos === "end")
            return "end";
        return "center";
    }

    // Forward sizing from the loaded component so the parent RowLayout/ColumnLayout
    // sizes this delegate correctly.
    implicitWidth: loadedItem ? loadedItem.implicitWidth : 0
    implicitHeight: loadedItem ? loadedItem.implicitHeight : 0
    Layout.preferredWidth: (!root.isSpring && loadedItem && loadedItem.Layout.preferredWidth >= 0) ? loadedItem.Layout.preferredWidth : implicitWidth
    Layout.preferredHeight: (!root.isSpring && loadedItem && loadedItem.Layout.preferredHeight >= 0) ? loadedItem.Layout.preferredHeight : implicitHeight
    Layout.minimumWidth: loadedItem ? loadedItem.Layout.minimumWidth : 0
    Layout.minimumHeight: loadedItem ? loadedItem.Layout.minimumHeight : 0
    Layout.maximumWidth: loadedItem ? loadedItem.Layout.maximumWidth : Infinity
    Layout.maximumHeight: loadedItem ? loadedItem.Layout.maximumHeight : Infinity
    Layout.fillWidth: root.isSpring ? !root.vertical : (loadedItem ? loadedItem.Layout.fillWidth : false)
    Layout.fillHeight: root.isSpring ? root.vertical : (loadedItem ? loadedItem.Layout.fillHeight : false)

    Loader {
        id: innerLoader
        anchors.fill: parent
        active: !root.isSpring && !root.pinHidden
        sourceComponent: root.componentFor(root.itemId)
    }

    readonly property var loadedItem: innerLoader.item

    // Spring spacer region (also hosts the integrated dock)
    Item {
        anchors.fill: parent
        visible: root.isSpring

        Bar.IntegratedDock {
            id: dockHost
            visible: root.placeDock
            bar: root.bar
            orientation: root.orientation
            enableShadow: root.enableShadow
            startRadius: root.innerRadius
            endRadius: root.innerRadius

            width: Math.min(implicitWidth, parent.width)
            height: Math.min(implicitHeight, parent.height)

            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: root.dockAlign === "center" ? parent.horizontalCenter : undefined
            anchors.left: root.dockAlign === "start" ? parent.left : undefined
            anchors.right: root.dockAlign === "end" ? parent.right : undefined
        }
    }

    function componentFor(id) {
        switch (id) {
        case "launcher":
            return launcherComp;
        case "workspaces":
            return workspacesComp;
        case "layout":
            return layoutComp;
        case "pin":
            return pinComp;
        case "presets":
            return presetsComp;
        case "tools":
            return toolsComp;
        case "systray":
            return systrayComp;
        case "controls":
            return controlsComp;
        case "battery":
            return batteryComp;
        case "clock":
            return clockComp;
        case "power":
            return powerComp;
        }
        return null;
    }

    Component {
        id: launcherComp
        LauncherButton {
            anchors.fill: parent
            vertical: root.vertical
            enableShadow: root.enableShadow
            startRadius: root.startRadius
            endRadius: root.endRadius
        }
    }
    Component {
        id: workspacesComp
        Workspaces {
            anchors.fill: parent
            orientation: root.orientation
            bar: root.bar
            startRadius: root.startRadius
            endRadius: root.endRadius
        }
    }
    Component {
        id: layoutComp
        LayoutSelectorButton {
            anchors.fill: parent
            bar: root.bar
            layerEnabled: root.enableShadow
            vertical: root.vertical
            startRadius: root.startRadius
            endRadius: root.endRadius
        }
    }
    Component {
        id: pinComp
        Bar.PinButton {
            anchors.fill: parent
            bar: root.bar
            enableShadow: root.enableShadow
            vertical: root.vertical
            startRadius: root.startRadius
            endRadius: root.endRadius
        }
    }
    Component {
        id: presetsComp
        PresetsButton {
            anchors.fill: parent
            vertical: root.vertical
            enableShadow: root.enableShadow
            startRadius: root.startRadius
            endRadius: root.endRadius
        }
    }
    Component {
        id: toolsComp
        ToolsButton {
            anchors.fill: parent
            vertical: root.vertical
            enableShadow: root.enableShadow
            startRadius: root.startRadius
            endRadius: root.endRadius
        }
    }
    Component {
        id: systrayComp
        SysTray {
            anchors.fill: parent
            bar: root.bar
            enableShadow: root.enableShadow
            startRadius: root.startRadius
            endRadius: root.endRadius
        }
    }
    Component {
        id: controlsComp
        ControlsButton {
            anchors.fill: parent
            bar: root.bar
            layerEnabled: root.enableShadow
            startRadius: root.startRadius
            endRadius: root.endRadius
        }
    }
    Component {
        id: batteryComp
        BatteryIndicator {
            anchors.fill: parent
            bar: root.bar
            layerEnabled: root.enableShadow
            startRadius: root.startRadius
            endRadius: root.endRadius
        }
    }
    Component {
        id: clockComp
        Clock {
            anchors.fill: parent
            bar: root.bar
            layerEnabled: root.enableShadow
            startRadius: root.startRadius
            endRadius: root.endRadius
        }
    }
    Component {
        id: powerComp
        PowerButton {
            anchors.fill: parent
            vertical: root.vertical
            enableShadow: root.enableShadow
            startRadius: root.startRadius
            endRadius: root.endRadius
        }
    }
}
