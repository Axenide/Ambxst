pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.modules.services
import qs.modules.components
import qs.modules.theme
import qs.config

Item {
    id: root

    required property var bar

    property bool vertical: bar.orientation === "vertical"
    property bool isHovered: false
    property bool layerEnabled: true

    property real radius: 0
    property real startRadius: radius
    property real endRadius: radius

    property bool popupOpen: devicePopup.isOpen

    // Device nodes must stay bound while a switch request is in flight. The
    // per-delegate trackers die with the popup in the same event-loop turn.
    PwObjectTracker {
        objects: Pipewire.nodes.values.filter(node => !node.isStream)
    }

    Layout.preferredWidth: 36
    Layout.preferredHeight: 36
    Layout.maximumWidth: 36
    Layout.maximumHeight: 36
    Layout.fillWidth: vertical
    Layout.fillHeight: !vertical

    // --- Excluded sinks filtering ---
    readonly property var excludedSinks: Config.bar.excludedAudioSinks ?? []

    function isExcluded(node): bool {
        const name = node?.name ?? "";
        const desc = node?.description ?? "";
        for (let i = 0; i < excludedSinks.length; i++) {
            const pattern = excludedSinks[i].toLowerCase();
            if (name.toLowerCase().includes(pattern) || desc.toLowerCase().includes(pattern))
                return true;
        }
        return false;
    }

    readonly property var filteredOutputs: {
        const all = Audio.outputDevices;
        if (!excludedSinks.length) return all;
        return all.filter(node => !root.isExcluded(node));
    }

    readonly property var filteredInputs: {
        const all = Audio.inputDevices;
        if (!excludedSinks.length) return all;
        return all.filter(node => !root.isExcluded(node));
    }

    // --- Dynamic icon detection from PipeWire node properties ---

    // Classify a real (non-virtual) sink by its PipeWire properties
    function classifyRealSink(props, nodeName: string, desc: string): string {
        const profileName = (props["device.profile.name"] ?? "").toLowerCase();
        const bus = (props["device.bus"] ?? "").toLowerCase();

        // HDMI/DisplayPort output
        if (profileName.includes("hdmi") || profileName.includes("displayport")
            || nodeName.includes("hdmi") || desc.includes("hdmi"))
            return "hdmi";

        // Bluetooth device
        if (bus === "bluetooth" || nodeName.includes("bluez"))
            return "headphones";

        // USB audio (headsets, DACs)
        if (bus === "usb")
            return "headphones";

        // Headset/headphone profiles
        if (profileName.includes("headset") || profileName.includes("headphone")
            || desc.includes("headset") || desc.includes("headphone"))
            return "headphones";

        return "speaker";
    }

    // Find a real output device by PipeWire node ID
    function findOutputById(nodeId: int): var {
        const outputs = Audio.outputDevices;
        for (let i = 0; i < outputs.length; i++) {
            const n = outputs[i];
            if (n && n.properties && parseInt(n.properties["object.id"] ?? -1) === nodeId)
                return n;
        }
        return null;
    }

    function classifyDevice(node, isSink: bool): string {
        if (!node) return isSink ? "speaker" : "mic";
        if (!isSink) return "mic";

        const props = node.properties ?? {};
        const factoryName = (props["factory.name"] ?? "").toLowerCase();
        const nodeName = (node.name ?? "").toLowerCase();
        const desc = (node.description ?? "").toLowerCase();

        // Virtual sink: audio processing software or routed virtual device
        if (factoryName === "support.null-audio-sink") {
            // Audio processing software (EasyEffects, Carla, JamesDSP, etc.)
            const isVirtual = props["node.virtual"] === true || props["node.virtual"] === "true";
            const appId = (props["application.id"] ?? "").toLowerCase();
            if (isVirtual || appId.includes("easyeffects") || appId.includes("carla")
                || appId.includes("jamesdsp") || appId.includes("pulseeffects"))
                return "effect";

            // Routed virtual sink: trace to real device via node.driver-id
            const driverId = parseInt(props["node.driver-id"] ?? -1);
            if (driverId >= 0) {
                const driver = root.findOutputById(driverId);
                if (driver) {
                    const driverProps = driver.properties ?? {};
                    return classifyRealSink(driverProps,
                        (driver.name ?? "").toLowerCase(),
                        (driver.description ?? "").toLowerCase());
                }
            }
            return "speaker";
        }

        return classifyRealSink(props, nodeName, desc);
    }

    function iconForClass(deviceClass: string): string {
        switch (deviceClass) {
        case "hdmi": return Icons.speakerHigh;
        case "headphones": return Icons.headphones;
        case "effect": return Icons.faders;
        case "mic": return Icons.mic;
        default: return Icons.speaker;
        }
    }

    function deviceIcon(node, isSink: bool): string {
        return iconForClass(classifyDevice(node, isSink));
    }

    function sinkIcon(): string {
        return deviceIcon(Audio.sink, true);
    }

    // --- Headset battery (D-Bus: ArctisManager) ---
    property int headsetBattery: -1
    property bool headsetOn: false

    readonly property bool isHeadsetSink: classifyDevice(Audio.sink, true) === "headphones"
    readonly property bool showBattery: isHeadsetSink && headsetOn && headsetBattery >= 0

    property Process batteryProc: Process {
        id: batteryProc
        command: ["dbus-send", "--session", "--print-reply", "--dest=name.giacomofurlan.ArctisManager.Next",
                  "/name/giacomofurlan/ArctisManager/Next/Status",
                  "name.giacomofurlan.ArctisManager.Next.Status.GetStatus"]
        running: false
        stdout: StdioCollector {}
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.headsetBattery = -1;
                root.headsetOn = false;
                return;
            }
            try {
                const raw = batteryProc.stdout.text;
                const match = raw.match(/string\s+"([\s\S]+)"/);
                if (!match) return;
                const data = JSON.parse(match[1]);
                const hs = data?.headset;
                root.headsetOn = hs?.headset_power_status?.value === "on";
                root.headsetBattery = hs?.headset_battery_charge?.value ?? -1;
            } catch (e) {
                root.headsetBattery = -1;
                root.headsetOn = false;
            }
        }
    }

    Timer {
        id: batteryTimer
        interval: 60000
        repeat: true
        running: root.isHeadsetSink
        triggeredOnStart: true
        onTriggered: batteryProc.running = true
    }

    HoverHandler {
        onHoveredChanged: root.isHovered = hovered
    }

    StyledRect {
        id: buttonBg
        variant: root.popupOpen ? "primary" : "bg"
        anchors.fill: parent
        enableShadow: root.layerEnabled

        topLeftRadius: root.vertical ? root.startRadius : root.startRadius
        topRightRadius: root.vertical ? root.startRadius : root.endRadius
        bottomLeftRadius: root.vertical ? root.endRadius : root.startRadius
        bottomRightRadius: root.vertical ? root.endRadius : root.endRadius

        Rectangle {
            anchors.fill: parent
            color: Styling.srItem("overprimary")
            opacity: root.popupOpen ? 0 : (root.isHovered ? 0.25 : 0)
            radius: parent.radius ?? 0

            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 2
                }
            }
        }

        // Icon + battery layout
        Row {
            anchors.centerIn: parent
            spacing: 1

            Text {
                id: buttonIcon
                text: root.sinkIcon()
                font.family: Icons.font
                font.pixelSize: root.showBattery ? 14 : 18
                color: root.popupOpen ? buttonBg.item : Styling.srItem("overprimary")
                anchors.verticalCenter: parent.verticalCenter

                Behavior on color {
                    enabled: Config.animDuration > 0
                    ColorAnimation { duration: Config.animDuration / 2 }
                }
                Behavior on font.pixelSize {
                    enabled: Config.animDuration > 0
                    NumberAnimation { duration: Config.animDuration / 2 }
                }
            }

            Text {
                visible: root.showBattery
                text: root.headsetBattery + "%"
                font.family: Styling.defaultFont
                font.pixelSize: 9
                font.bold: true
                color: root.popupOpen ? buttonBg.item : Styling.srItem("overprimary")
                anchors.verticalCenter: parent.verticalCenter

                Behavior on color {
                    enabled: Config.animDuration > 0
                    ColorAnimation { duration: Config.animDuration / 2 }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: false
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: devicePopup.toggle()
        }

        StyledToolTip {
            visible: root.isHovered && !root.popupOpen
            tooltipText: {
                const name = Audio.friendlyDeviceName(Audio.sink);
                if (root.showBattery)
                    return name + " · " + root.headsetBattery + "%";
                return name;
            }
        }
    }

    BarPopup {
        id: devicePopup
        anchorItem: buttonBg
        bar: root.bar
        popupPadding: 8

        contentWidth: 260
        contentHeight: popupColumn.implicitHeight + popupPadding * 2

        ColumnLayout {
            id: popupColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 2

            // Section: Output
            Text {
                Layout.leftMargin: 8
                Layout.topMargin: 4
                Layout.bottomMargin: 2
                text: "Output"
                font.family: Styling.defaultFont
                font.pixelSize: Styling.fontSize(-1)
                font.bold: true
                color: Colors.overSurfaceVariant
                opacity: 0.6
            }

            Repeater {
                model: root.filteredOutputs

                delegate: Item {
                    id: outputDelegate
                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: 36

                    readonly property bool isSelected: Audio.sink === modelData
                    property bool itemHovered: false

                    PwObjectTracker {
                        objects: [outputDelegate.modelData]
                    }

                    StyledRect {
                        anchors.fill: parent
                        variant: outputDelegate.isSelected ? "primary" : (outputDelegate.itemHovered ? "focus" : "common")
                        enableShadow: false
                        radius: Styling.radius(-2)
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: outputDelegate.itemHovered = true
                        onExited: outputDelegate.itemHovered = false
                        onClicked: {
                            Audio.setDefaultSink(outputDelegate.modelData);
                            Qt.callLater(() => devicePopup.close());
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Text {
                            text: root.deviceIcon(outputDelegate.modelData, true)
                            font.family: Icons.font
                            font.pixelSize: 14
                            color: outputDelegate.isSelected
                                ? Styling.srItem("primary")
                                : Colors.overBackground
                        }

                        Text {
                            Layout.fillWidth: true
                            text: Audio.friendlyDeviceName(outputDelegate.modelData)
                            font.family: Styling.defaultFont
                            font.pixelSize: Styling.fontSize(0)
                            font.weight: outputDelegate.isSelected ? Font.Bold : Font.Normal
                            color: outputDelegate.isSelected
                                ? Styling.srItem("primary")
                                : Colors.overBackground
                            elide: Text.ElideRight
                        }

                        Text {
                            visible: outputDelegate.isSelected
                            text: Icons.accept
                            font.family: Icons.font
                            font.pixelSize: 14
                            color: Styling.srItem("primary")
                        }
                    }
                }
            }

            // Separator
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                Layout.topMargin: 4
                Layout.bottomMargin: 4
                height: 1
                color: Colors.surfaceBright
            }

            // Section: Input
            Text {
                Layout.leftMargin: 8
                Layout.bottomMargin: 2
                text: "Input"
                font.family: Styling.defaultFont
                font.pixelSize: Styling.fontSize(-1)
                font.bold: true
                color: Colors.overSurfaceVariant
                opacity: 0.6
            }

            Repeater {
                model: root.filteredInputs

                delegate: Item {
                    id: inputDelegate
                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: 36

                    readonly property bool isSelected: Audio.source === modelData
                    property bool itemHovered: false

                    PwObjectTracker {
                        objects: [inputDelegate.modelData]
                    }

                    StyledRect {
                        anchors.fill: parent
                        variant: inputDelegate.isSelected ? "primary" : (inputDelegate.itemHovered ? "focus" : "common")
                        enableShadow: false
                        radius: Styling.radius(-2)
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: inputDelegate.itemHovered = true
                        onExited: inputDelegate.itemHovered = false
                        onClicked: {
                            Audio.setDefaultSource(inputDelegate.modelData);
                            Qt.callLater(() => devicePopup.close());
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Text {
                            text: root.deviceIcon(inputDelegate.modelData, false)
                            font.family: Icons.font
                            font.pixelSize: 14
                            color: inputDelegate.isSelected
                                ? Styling.srItem("primary")
                                : Colors.overBackground
                        }

                        Text {
                            Layout.fillWidth: true
                            text: Audio.friendlyDeviceName(inputDelegate.modelData)
                            font.family: Styling.defaultFont
                            font.pixelSize: Styling.fontSize(0)
                            font.weight: inputDelegate.isSelected ? Font.Bold : Font.Normal
                            color: inputDelegate.isSelected
                                ? Styling.srItem("primary")
                                : Colors.overBackground
                            elide: Text.ElideRight
                        }

                        Text {
                            visible: inputDelegate.isSelected
                            text: Icons.accept
                            font.family: Icons.font
                            font.pixelSize: 14
                            color: Styling.srItem("primary")
                        }
                    }
                }
            }
        }
    }
}
