pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

Item {
    id: root
    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property int maxContentWidth: 480
    readonly property int contentWidth: Math.min(width, maxContentWidth)
    readonly property real sideMargin: (width - contentWidth) / 2

    // Presets section - fills entire width for scroll/drag
    Flickable {
        id: mainFlickable
        anchors.fill: parent
        contentHeight: mainColumn.implicitHeight
        clip: true

        ColumnLayout {
            id: mainColumn
            width: mainFlickable.width
            spacing: 8
            LayoutMirroring.enabled: I18n.isRtl
            LayoutMirroring.childrenInherit: true

            // Header wrapper
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: titlebar.visible ? titlebar.height : 0

                PanelTitlebar {
                    id: titlebar
                    width: root.contentWidth
                    anchors.horizontalCenter: parent.horizontalCenter
                    title: I18n.t("EasyEffects")
                    showTitle: false
                    statusText: EasyEffectsService.bypassed ? "Bypassed" : ""
                    statusColor: Colors.error
                    showToggle: false
                    toggleChecked: false
                    actions: []
                    visible: false
                }
            }

            // Content wrapper - centered
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: presetsColumn.implicitHeight

                ColumnLayout {
                    id: presetsColumn
                    width: root.contentWidth
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12
                    LayoutMirroring.enabled: I18n.isRtl
                    LayoutMirroring.childrenInherit: true

                    // Not available state
                    Text {
                        visible: !EasyEffectsService.available
                        text: I18n.t("EasyEffects not installed")
                        font.family: Config.theme.font
                        font.pixelSize: Config.theme.fontSize
                        color: Colors.overSurfaceVariant
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 32
                    }

                    // Output presets
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        visible: EasyEffectsService.available && EasyEffectsService.outputPresets.length > 0

                        Text {
                            text: I18n.t("Output Presets")
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: Font.Medium
                            color: Colors.overSurfaceVariant
                            Layout.fillWidth: true
                            horizontalAlignment: I18n.isRtl ? Text.AlignRight : Text.AlignLeft
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: 6
                            LayoutMirroring.enabled: I18n.isRtl
                            LayoutMirroring.childrenInherit: true

                            Repeater {
                                model: EasyEffectsService.outputPresets

                                delegate: Button {
                                    id: presetButton
                                    required property string modelData
                                    flat: true

                                    property bool isActive: EasyEffectsService.activeOutputPreset === modelData

                                    background: StyledRect {
                                        variant: presetButton.isActive ? "primary" : (presetButton.hovered ? "focus" : "common")
                                        radius: presetButton.isActive ? Styling.radius(-4) : Styling.radius(4)
                                    }

                                    contentItem: Row {
                                        spacing: presetButton.isActive ? 6 : 0
                                        leftPadding: 12
                                        rightPadding: 12
                                        topPadding: 6
                                        bottomPadding: 6
                                        layoutDirection: I18n.isRtl ? Qt.RightToLeft : Qt.LeftToRight

                                        Behavior on spacing {
                                            enabled: Config.animDuration > 0
                                            NumberAnimation {
                                                duration: Config.animDuration / 3
                                                easing.type: Easing.OutCubic
                                            }
                                        }

                                        // Icon with reveal animation
                                        Item {
                                            width: presetButton.isActive ? presetIcon.implicitWidth : 0
                                            height: presetIcon.implicitHeight
                                            anchors.verticalCenter: parent.verticalCenter
                                            clip: true

                                            Behavior on width {
                                                enabled: Config.animDuration > 0
                                                NumberAnimation {
                                                    duration: Config.animDuration / 3
                                                    easing.type: Easing.OutCubic
                                                }
                                            }

                                            Text {
                                                id: presetIcon
                                                text: Icons.sparkle
                                                font.family: Icons.font
                                                font.pixelSize: Styling.fontSize(-1)
                                                color: Styling.srItem("primary")
                                                opacity: presetButton.isActive ? 1 : 0

                                                Behavior on opacity {
                                                    enabled: Config.animDuration > 0
                                                    NumberAnimation {
                                                        duration: Config.animDuration / 3
                                                        easing.type: Easing.OutCubic
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            text: presetButton.modelData
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(-1)
                                            font.weight: presetButton.isActive ? Font.Bold : Font.Normal
                                            color: presetButton.isActive ? Styling.srItem("primary") : Colors.overBackground
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    onClicked: EasyEffectsService.loadOutputPreset(modelData)
                                }
                            }
                        }
                    }

                    // Input presets
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        visible: EasyEffectsService.available && EasyEffectsService.inputPresets.length > 0

                        Text {
                            text: I18n.t("Input Presets")
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: Font.Medium
                            color: Colors.overSurfaceVariant
                            Layout.fillWidth: true
                            horizontalAlignment: I18n.isRtl ? Text.AlignRight : Text.AlignLeft
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: 6
                            LayoutMirroring.enabled: I18n.isRtl
                            LayoutMirroring.childrenInherit: true

                            Repeater {
                                model: EasyEffectsService.inputPresets

                                delegate: Button {
                                    id: inputPresetButton
                                    required property string modelData
                                    flat: true

                                    property bool isActive: EasyEffectsService.activeInputPreset === modelData

                                    background: StyledRect {
                                        variant: inputPresetButton.isActive ? "primary" : (inputPresetButton.hovered ? "focus" : "common")
                                        radius: inputPresetButton.isActive ? Styling.radius(-4) : Styling.radius(4)
                                    }

                                    contentItem: Row {
                                        spacing: inputPresetButton.isActive ? 6 : 0
                                        leftPadding: 12
                                        rightPadding: 12
                                        topPadding: 6
                                        bottomPadding: 6
                                        layoutDirection: I18n.isRtl ? Qt.RightToLeft : Qt.LeftToRight

                                        Behavior on spacing {
                                            enabled: Config.animDuration > 0
                                            NumberAnimation {
                                                duration: Config.animDuration / 3
                                                easing.type: Easing.OutCubic
                                            }
                                        }

                                        // Icon with reveal animation
                                        Item {
                                            width: inputPresetButton.isActive ? inputPresetIcon.implicitWidth : 0
                                            height: inputPresetIcon.implicitHeight
                                            anchors.verticalCenter: parent.verticalCenter
                                            clip: true

                                            Behavior on width {
                                                enabled: Config.animDuration > 0
                                                NumberAnimation {
                                                    duration: Config.animDuration / 3
                                                    easing.type: Easing.OutCubic
                                                }
                                            }

                                            Text {
                                                id: inputPresetIcon
                                                text: Icons.sparkle
                                                font.family: Icons.font
                                                font.pixelSize: Styling.fontSize(-1)
                                                color: Styling.srItem("primary")
                                                opacity: inputPresetButton.isActive ? 1 : 0

                                                Behavior on opacity {
                                                    enabled: Config.animDuration > 0
                                                    NumberAnimation {
                                                        duration: Config.animDuration / 3
                                                        easing.type: Easing.OutCubic
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            text: inputPresetButton.modelData
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(-1)
                                            font.weight: inputPresetButton.isActive ? Font.Bold : Font.Normal
                                            color: inputPresetButton.isActive ? Styling.srItem("primary") : Colors.overBackground
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    onClicked: EasyEffectsService.loadInputPreset(modelData)
                                }
                            }
                        }
                    }

                    // Empty state
                    Text {
                        visible: EasyEffectsService.available && EasyEffectsService.outputPresets.length === 0 && EasyEffectsService.inputPresets.length === 0
                        text: I18n.t("No presets configured")
                        font.family: Config.theme.font
                        font.pixelSize: Config.theme.fontSize
                        color: Colors.overSurfaceVariant
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 16
                    }

                    // Current status
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 16
                        spacing: 4
                        visible: EasyEffectsService.available && (EasyEffectsService.activeOutputPreset || EasyEffectsService.activeInputPreset)

                        Text {
                            text: I18n.t("Active")
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: Font.Medium
                            color: Colors.overSurfaceVariant
                            Layout.fillWidth: true
                            horizontalAlignment: I18n.isRtl ? Text.AlignRight : Text.AlignLeft
                        }

                        RowLayout {
                            spacing: 16
                            visible: EasyEffectsService.activeOutputPreset
                            LayoutMirroring.enabled: I18n.isRtl
                            LayoutMirroring.childrenInherit: true

                            Text {
                                text: Icons.speakerHigh
                                font.family: Icons.font
                                font.pixelSize: 14
                                color: Styling.srItem("overprimary")
                            }
                            Text {
                                text: EasyEffectsService.activeOutputPreset
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                color: Colors.overBackground
                            }
                        }

                        RowLayout {
                            spacing: 16
                            visible: EasyEffectsService.activeInputPreset
                            LayoutMirroring.enabled: I18n.isRtl
                            LayoutMirroring.childrenInherit: true

                            Text {
                                text: Icons.mic
                                font.family: Icons.font
                                font.pixelSize: 14
                                color: Styling.srItem("overprimary")
                            }
                            Text {
                                text: EasyEffectsService.activeInputPreset
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                color: Colors.overBackground
                            }
                        }
                    }
                }
            }
        }
    }
}
