import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.modules.globals
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

PanelWindow {
    id: specialPopup

    anchors {
        top: true
        left: true
        right: true
    }

    height: Math.round((screen?.height || 0) * 0.8)
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    exclusionMode: ExclusionMode.Ignore

    readonly property var monitors: HyprlandData.monitors
    readonly property var windowList: HyprlandData.windowList
    readonly property bool specialOpen: monitors.some(m => ((m.activeWorkspace?.name || "").startsWith("special:")))

    property var specialWorkspaces: []

    visible: specialOpen || container.opacity > 0.01

    // No input capture
    mask: Region {
        item: emptyMask
    }

    Item {
        id: emptyMask
        width: 0
        height: 0
    }

    function refreshSpecialWorkspaces() {
        const map = {};
        for (let i = 0; i < windowList.length; i++) {
            const win = windowList[i];
            if (!win || !win.workspace || !win.workspace.name)
                continue;
            const name = String(win.workspace.name);
            if (!name.startsWith("special:"))
                continue;
            if (!map[name]) {
                map[name] = [];
            }
            map[name].push(win);
        }

        const entries = Object.keys(map).sort().map(name => {
            return {
                name: name,
                label: name.slice("special:".length) || name,
                windows: map[name]
            };
        });

        specialWorkspaces = entries;
    }

    onWindowListChanged: refreshSpecialWorkspaces()
    Component.onCompleted: refreshSpecialWorkspaces()

    Item {
        id: container
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: parent.height

        y: specialOpen ? 0 : -height
        opacity: specialOpen ? 1 : 0

        Behavior on y {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutQuart
            }
        }

        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutQuart
            }
        }

        StyledRect {
            id: background
            anchors.fill: parent
            variant: "bg"
            radius: Styling.radius(2)
            enableShadow: true

            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 0.6
                brightness: 0.02
            }
        }

        Flickable {
            id: contentFlickable
            anchors.fill: parent
            anchors.margins: 24
            contentHeight: contentColumn.implicitHeight
            clip: true

            ColumnLayout {
                id: contentColumn
                width: parent.width
                spacing: 16

                GridLayout {
                    id: workspaceGrid
                    width: parent.width
                    columns: Math.max(1, Math.min(3, Math.floor(width / 320)))
                    rowSpacing: 16
                    columnSpacing: 16

                    Repeater {
                        model: specialWorkspaces

                        delegate: StyledRect {
                            required property var modelData

                            Layout.fillWidth: true
                            radius: Styling.radius(1)
                            variant: "pane"
                            enableShadow: true
                            implicitHeight: workspaceContent.implicitHeight + 24

                            ColumnLayout {
                                id: workspaceContent
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 12

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: modelData.label
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(1)
                                        font.weight: Font.Bold
                                        color: Colors.overBackground
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: `${modelData.windows.length}`
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-1)
                                        color: Colors.overSurfaceVariant
                                    }
                                }

                                Flow {
                                    width: parent.width
                                    spacing: 10

                                    Repeater {
                                        model: modelData.windows

                                        delegate: Column {
                                            required property var modelData
                                            spacing: 4

                                            Image {
                                                width: 28
                                                height: 28
                                                fillMode: Image.PreserveAspectFit
                                                source: Quickshell.iconPath(AppSearch.getCachedIcon(modelData?.class || ""), "image-missing")
                                            }

                                            Text {
                                                text: modelData.title || modelData.class || ""
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(-2)
                                                color: Colors.overBackground
                                                elide: Text.ElideRight
                                                width: 120
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 8
                }
            }
        }
    }
}
