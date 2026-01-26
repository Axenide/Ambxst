pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.modules.theme
import qs.modules.components
import qs.modules.globals

Item {
    id: root

    property string hostname: ""
    property string osName: ""
    property string osIcon: ""
    property var linuxLogos: null

    implicitWidth: userRow.implicitWidth
    implicitHeight: userRow.implicitHeight

    function getOsIcon(osName) {
        if (!osName || !linuxLogos) {
            return "";
        }

        if (linuxLogos[osName]) {
            return linuxLogos[osName];
        }

        for (const distro in linuxLogos) {
            if (osName.toLowerCase().includes(distro.toLowerCase())) {
                return linuxLogos[distro];
            }
        }

        return linuxLogos["Linux"] || "";
    }

    onLinuxLogosChanged: {
        if (linuxLogos && osName) {
            const icon = getOsIcon(osName);
            osIcon = icon || "";
        }
    }

    Component.onCompleted: {
        hostnameReader.running = true;
        osReader.running = true;
        linuxLogosReader.running = true;
    }

    Process {
        id: linuxLogosReader
        running: false
        command: ["cat", Qt.resolvedUrl("../../../assets/linux-logos.json").toString().replace("file://", "")]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    if (!text || text.trim().length === 0) {
                        console.warn("linux-logos.json is empty");
                        return;
                    }
                    root.linuxLogos = JSON.parse(text);
                } catch (e) {
                    console.warn("Failed to parse linux-logos.json:", e);
                }
            }
        }
    }

    Process {
        id: hostnameReader
        running: false
        command: ["hostname"]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const host = text.trim();
                if (host) {
                    root.hostname = host.charAt(0).toUpperCase() + host.slice(1);
                }
            }
        }
    }

    Process {
        id: osReader
        running: false
        command: ["sh", "-c", "grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '\"'"]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const os = text.trim();
                if (os) {
                    root.osName = os;
                    if (root.linuxLogos) {
                        const icon = getOsIcon(os);
                        root.osIcon = icon || "";
                    }
                }
            }
        }
    }

    RowLayout {
        id: userRow
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        spacing: 10

        StyledRect {
            id: avatarContainer
            Layout.preferredWidth: 56
            Layout.preferredHeight: 56
            radius: height / 2
            variant: "primary"

            Image {
                id: userAvatar
                anchors.fill: parent
                anchors.margins: 2
                source: `file://${Quickshell.env("HOME")}/.face.icon?${GlobalStates.avatarCacheBuster}`
                fillMode: Image.PreserveAspectCrop
                smooth: true
                asynchronous: true
                visible: status === Image.Ready

                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                    maskSource: ShaderEffectSource {
                        sourceItem: Rectangle {
                            width: userAvatar.width
                            height: userAvatar.height
                        radius: height / 2
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                text: Icons.user
                font.family: Icons.font
                font.pixelSize: 28
                color: Colors.overSurfaceVariant
                visible: userAvatar.status !== Image.Ready
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: GlobalStates.pickUserAvatar()

                Rectangle {
                    anchors.fill: parent
                    color: Colors.overSurface
                    opacity: parent.containsMouse ? 0.1 : 0
                    radius: avatarContainer.radius

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 150
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

            Text {
                text: Icons.user
                font.family: Icons.font
                font.pixelSize: Styling.fontSize(-1)
                color: Styling.srItem("overprimary")
            }

            Text {
                Layout.fillWidth: true
                    text: {
                        const user = Quickshell.env("USER") || "user";
                        return user.charAt(0).toUpperCase() + user.slice(1);
                    }
                    font.family: Config.theme.font
                font.pixelSize: Config.theme.fontSize + 2
                font.weight: Font.Bold
                color: Colors.overBackground
                elide: Text.ElideRight
            }
        }

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

            Text {
                text: Icons.at
                font.family: Icons.font
                font.pixelSize: Styling.fontSize(-2)
                color: Colors.overSurfaceVariant
            }

            Text {
                Layout.fillWidth: true
                    text: {
                        if (!root.hostname)
                            return "Hostname";
                        const host = root.hostname.toLowerCase();
                        return host.charAt(0).toUpperCase() + host.slice(1);
                    }
                    font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-3)
                font.weight: Font.Medium
                color: Colors.overSurfaceVariant
                elide: Text.ElideRight
            }
        }

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

            Text {
                text: root.osIcon || (root.linuxLogos ? (root.linuxLogos["Linux"] || "") : "")
                font.family: "Symbols Nerd Font Mono"
                font.pixelSize: Styling.fontSize(-2)
                color: Colors.overSurfaceVariant
            }

            Text {
                Layout.fillWidth: true
                text: root.osName || "Linux"
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-3)
                font.weight: Font.Medium
                color: Colors.overSurfaceVariant
                elide: Text.ElideRight
            }
        }
        }
    }
}
