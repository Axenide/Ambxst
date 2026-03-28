pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

Item {
    id: root

    required property var bar

    property bool vertical: bar.orientation === "vertical"
    property bool isHovered: false
    property bool layerEnabled: true

    property real startRadius: 0
    property real endRadius: 0

    // I18n helper — works with or without i18n PR merged
    function tr(key, fallback) {
        try {
            const val = I18n.t(key);
            return (val && val !== key) ? val : fallback;
        } catch (e) {
            return fallback;
        }
    }

    // Resource visibility config with safe defaults
    readonly property bool showCpu: Config.system.resources && Config.system.resources.show ? Config.system.resources.show.cpu !== false : true
    readonly property bool showRam: Config.system.resources && Config.system.resources.show ? Config.system.resources.show.ram !== false : true
    readonly property bool showGpu: Config.system.resources && Config.system.resources.show ? Config.system.resources.show.gpu !== false : true
    readonly property bool showDisk: Config.system.resources && Config.system.resources.show ? Config.system.resources.show.disk !== false : true

    function gpuColor(vendor) {
        switch ((vendor || "").toLowerCase()) {
        case "nvidia": return Colors.green;
        case "amd":    return Colors.red;
        case "intel":  return Colors.blue;
        default:       return Colors.magenta;
        }
    }

    implicitWidth: bg.implicitWidth
    implicitHeight: 36
    Layout.preferredWidth: bg.implicitWidth
    Layout.preferredHeight: 36
    Layout.alignment: Qt.AlignVCenter

    // Fixed-width metrics so numeric values don't cause layout jitter
    TextMetrics {
        id: pctMetrics
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-1)
        text: "100%"
    }
    TextMetrics {
        id: tempMetrics
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-2)
        text: "100°"
    }
    readonly property real pctWidth: pctMetrics.width
    readonly property real tempWidth: tempMetrics.width
    // Foreground color of the bg tile — switches when popup opens (primary variant)
    readonly property color itemColor: bg.item

    HoverHandler {
        onHoveredChanged: root.isHovered = hovered
    }

    StyledRect {
        id: bg
        variant: popup.isOpen ? "primary" : "bg"
        anchors.fill: parent
        enableShadow: root.layerEnabled

        implicitWidth: itemsRow.implicitWidth + 16
        implicitHeight: 36

        topLeftRadius:    root.vertical ? root.startRadius : root.startRadius
        topRightRadius:   root.vertical ? root.startRadius : root.endRadius
        bottomLeftRadius: root.vertical ? root.endRadius   : root.startRadius
        bottomRightRadius: root.vertical ? root.endRadius  : root.endRadius

        Rectangle {
            anchors.fill: parent
            color: Styling.srItem("overprimary")
            opacity: popup.isOpen ? 0 : (root.isHovered ? 0.12 : 0)
            radius: parent.radius ?? 0
            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation { duration: Config.animDuration / 2 }
            }
        }

        RowLayout {
            id: itemsRow
            anchors.centerIn: parent
            spacing: 8

            // ── CPU ──────────────────────────────────────────────────
            Loader {
                active: root.showCpu
                visible: active
                sourceComponent: RowLayout {
                    spacing: 3
                    Text {
                        text: Icons.cpu
                        font.family: Icons.font
                        font.pixelSize: 13
                        color: popup.isOpen ? root.itemColor : Colors.red
                        Behavior on color { enabled: Config.animDuration > 0; ColorAnimation { duration: Config.animDuration / 2 } }
                    }
                    Text {
                        text: Math.round(SystemResources.cpuUsage) + "%"
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        color: popup.isOpen ? root.itemColor : Colors.overBackground
                        width: root.pctWidth
                        horizontalAlignment: Text.AlignRight
                        Behavior on color { enabled: Config.animDuration > 0; ColorAnimation { duration: Config.animDuration / 2 } }
                    }
                    Text {
                        visible: SystemResources.cpuTemp >= 0
                        text: SystemResources.cpuTemp + "°"
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-2)
                        color: popup.isOpen ? root.itemColor : Colors.overSurfaceVariant
                        width: root.tempWidth
                        horizontalAlignment: Text.AlignRight
                        Behavior on color { enabled: Config.animDuration > 0; ColorAnimation { duration: Config.animDuration / 2 } }
                    }
                }
            }

            // ── Divider CPU|RAM ──────────────────────────────────────
            Loader {
                active: root.showCpu && root.showRam
                visible: active
                sourceComponent: Rectangle {
                    width: 1; height: 16
                    color: Colors.outline
                    opacity: 0.4
                }
            }

            // ── RAM ──────────────────────────────────────────────────
            Loader {
                active: root.showRam
                visible: active
                sourceComponent: RowLayout {
                    spacing: 3
                    Text {
                        text: Icons.ram
                        font.family: Icons.font
                        font.pixelSize: 13
                        color: popup.isOpen ? root.itemColor : Colors.cyan
                        Behavior on color { enabled: Config.animDuration > 0; ColorAnimation { duration: Config.animDuration / 2 } }
                    }
                    Text {
                        text: Math.round(SystemResources.ramUsage) + "%"
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        color: popup.isOpen ? root.itemColor : Colors.overBackground
                        width: root.pctWidth
                        horizontalAlignment: Text.AlignRight
                        Behavior on color { enabled: Config.animDuration > 0; ColorAnimation { duration: Config.animDuration / 2 } }
                    }
                }
            }

            // ── Divider RAM|GPU ──────────────────────────────────────
            Loader {
                active: (root.showCpu || root.showRam) && root.showGpu && SystemResources.gpuDetected
                visible: active
                sourceComponent: Rectangle {
                    width: 1; height: 16
                    color: Colors.outline
                    opacity: 0.4
                }
            }

            // ── GPU(s) ───────────────────────────────────────────────
            Loader {
                active: root.showGpu && SystemResources.gpuDetected
                visible: active
                sourceComponent: RowLayout {
                    spacing: 4
                    Repeater {
                        model: SystemResources.gpuCount
                        delegate: RowLayout {
                            required property int index
                            spacing: 3
                            Text {
                                text: Icons.gpu
                                font.family: Icons.font
                                font.pixelSize: 13
                                color: popup.isOpen ? root.itemColor : root.gpuColor(SystemResources.gpuVendors[index] || "")
                                Behavior on color { enabled: Config.animDuration > 0; ColorAnimation { duration: Config.animDuration / 2 } }
                            }
                            Text {
                                text: Math.round(SystemResources.gpuUsages[index] || 0) + "%"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                color: popup.isOpen ? root.itemColor : Colors.overBackground
                                width: root.pctWidth
                                horizontalAlignment: Text.AlignRight
                                Behavior on color { enabled: Config.animDuration > 0; ColorAnimation { duration: Config.animDuration / 2 } }
                            }
                            Text {
                                visible: (SystemResources.gpuTemps[index] ?? -1) >= 0
                                text: (SystemResources.gpuTemps[index] || 0) + "°"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-2)
                                color: popup.isOpen ? root.itemColor : Colors.overSurfaceVariant
                                width: root.tempWidth
                                horizontalAlignment: Text.AlignRight
                                Behavior on color { enabled: Config.animDuration > 0; ColorAnimation { duration: Config.animDuration / 2 } }
                            }
                        }
                    }
                }
            }

            // ── Divider GPU|Disk ─────────────────────────────────────
            Loader {
                active: (root.showCpu || root.showRam || (root.showGpu && SystemResources.gpuDetected)) && root.showDisk && SystemResources.validDisks.length > 0
                visible: active
                sourceComponent: Rectangle {
                    width: 1; height: 16
                    color: Colors.outline
                    opacity: 0.4
                }
            }

            // ── Disk(s) ──────────────────────────────────────────────
            Loader {
                active: root.showDisk && SystemResources.validDisks.length > 0
                visible: active
                sourceComponent: RowLayout {
                    spacing: 4
                    Repeater {
                        model: SystemResources.validDisks
                        delegate: RowLayout {
                            required property string modelData
                            spacing: 3
                            Text {
                                text: Icons.disk
                                font.family: Icons.font
                                font.pixelSize: 13
                                color: popup.isOpen ? root.itemColor : Colors.yellow
                                Behavior on color { enabled: Config.animDuration > 0; ColorAnimation { duration: Config.animDuration / 2 } }
                            }
                            Text {
                                text: Math.round(SystemResources.diskUsage[modelData] || 0) + "%"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                color: popup.isOpen ? root.itemColor : Colors.overBackground
                                width: root.pctWidth
                                horizontalAlignment: Text.AlignRight
                                Behavior on color { enabled: Config.animDuration > 0; ColorAnimation { duration: Config.animDuration / 2 } }
                            }
                        }
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: popup.toggle()
        }

        StyledToolTip {
            show: root.isHovered && !popup.isOpen
            tooltipText: root.tr("bar.resources.tooltip", "System Resources")
        }
    }

    // ── Detail popup ─────────────────────────────────────────────────
    BarPopup {
        id: popup
        anchorItem: bg
        bar: root.bar
        contentWidth: bg.width
        contentHeight: popupColumn.implicitHeight + popup.popupPadding * 2

        ColumnLayout {
            id: popupColumn
            anchors.fill: parent
            spacing: 4

            // CPU detail
            Loader {
                active: root.showCpu
                visible: active
                Layout.fillWidth: true
                sourceComponent: StyledRect {
                    variant: "common"
                    implicitHeight: detailCpuRow.implicitHeight + 12
                    radius: Styling.radius(-2)

                    RowLayout {
                        id: detailCpuRow
                        anchors {
                            left: parent.left; right: parent.right
                            verticalCenter: parent.verticalCenter
                            leftMargin: 10; rightMargin: 10
                        }
                        spacing: 8

                        Text {
                            text: Icons.cpu
                            font.family: Icons.font
                            font.pixelSize: 16
                            color: Colors.red
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    text: "CPU"
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-1)
                                    font.weight: Font.Medium
                                    color: Colors.overBackground
                                    Layout.fillWidth: true
                                }

                                Text {
                                    visible: SystemResources.cpuTemp >= 0
                                    text: SystemResources.cpuTemp + "°C"
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-2)
                                    color: Colors.overSurfaceVariant
                                }

                                Text {
                                    text: Math.round(SystemResources.cpuUsage) + "%"
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-1)
                                    font.weight: Font.Medium
                                    color: Colors.overBackground
                                }
                            }

                            Text {
                                text: SystemResources.cpuModel
                                visible: SystemResources.cpuModel !== ""
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-2)
                                color: Colors.overSurfaceVariant
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            // RAM detail
            Loader {
                active: root.showRam
                visible: active
                Layout.fillWidth: true
                sourceComponent: StyledRect {
                    variant: "common"
                    implicitHeight: detailRamRow.implicitHeight + 12
                    radius: Styling.radius(-2)

                    RowLayout {
                        id: detailRamRow
                        anchors {
                            left: parent.left; right: parent.right
                            verticalCenter: parent.verticalCenter
                            leftMargin: 10; rightMargin: 10
                        }
                        spacing: 8

                        Text {
                            text: Icons.ram
                            font.family: Icons.font
                            font.pixelSize: 16
                            color: Colors.cyan
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    text: "RAM"
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-1)
                                    font.weight: Font.Medium
                                    color: Colors.overBackground
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: Math.round(SystemResources.ramUsage) + "%"
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-1)
                                    font.weight: Font.Medium
                                    color: Colors.overBackground
                                }
                            }

                            Text {
                                text: {
                                    const used = (SystemResources.ramUsed / 1024 / 1024).toFixed(1);
                                    const total = (SystemResources.ramTotal / 1024 / 1024).toFixed(1);
                                    return used + " / " + total + " GB";
                                }
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-2)
                                color: Colors.overSurfaceVariant
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }

            // GPU(s) detail
            Loader {
                active: root.showGpu && SystemResources.gpuDetected
                visible: active
                Layout.fillWidth: true
                sourceComponent: ColumnLayout {
                    spacing: 4
                    Repeater {
                        model: SystemResources.gpuCount
                        delegate: StyledRect {
                            required property int index
                            variant: "common"
                            implicitHeight: detailGpuRow.implicitHeight + 12
                            radius: Styling.radius(-2)
                            Layout.fillWidth: true

                            RowLayout {
                                id: detailGpuRow
                                anchors {
                                    left: parent.left; right: parent.right
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: 10; rightMargin: 10
                                }
                                spacing: 8

                                Text {
                                    text: Icons.gpu
                                    font.family: Icons.font
                                    font.pixelSize: 16
                                    color: root.gpuColor(SystemResources.gpuVendors[index] || "")
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    RowLayout {
                                        Layout.fillWidth: true

                                        Text {
                                            text: SystemResources.gpuNames[index] || "GPU"
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(-1)
                                            font.weight: Font.Medium
                                            color: Colors.overBackground
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            visible: (SystemResources.gpuTemps[index] ?? -1) >= 0
                                            text: (SystemResources.gpuTemps[index] || 0) + "°C"
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(-2)
                                            color: Colors.overSurfaceVariant
                                        }

                                        Text {
                                            text: Math.round(SystemResources.gpuUsages[index] || 0) + "%"
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(-1)
                                            font.weight: Font.Medium
                                            color: Colors.overBackground
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Disk(s) detail
            Loader {
                active: root.showDisk && SystemResources.validDisks.length > 0
                visible: active
                Layout.fillWidth: true
                sourceComponent: ColumnLayout {
                    spacing: 4
                    Repeater {
                        model: SystemResources.validDisks
                        delegate: StyledRect {
                            required property string modelData
                            variant: "common"
                            implicitHeight: detailDiskRow.implicitHeight + 12
                            radius: Styling.radius(-2)
                            Layout.fillWidth: true

                            RowLayout {
                                id: detailDiskRow
                                anchors {
                                    left: parent.left; right: parent.right
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: 10; rightMargin: 10
                                }
                                spacing: 8

                                Text {
                                    text: Icons.disk
                                    font.family: Icons.font
                                    font.pixelSize: 16
                                    color: Colors.yellow
                                }

                                RowLayout {
                                    Layout.fillWidth: true

                                    Text {
                                        text: modelData
                                        font.family: Config.theme.monoFont
                                        font.pixelSize: Styling.fontSize(-1)
                                        color: Colors.overBackground
                                        Layout.fillWidth: true
                                        elide: Text.ElideMiddle
                                    }

                                    Text {
                                        text: Math.round(SystemResources.diskUsage[modelData] || 0) + "%"
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-1)
                                        font.weight: Font.Medium
                                        color: Colors.overBackground
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
