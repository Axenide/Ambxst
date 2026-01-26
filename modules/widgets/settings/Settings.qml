pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.modules.components
import qs.modules.globals
import qs.modules.services
import qs.modules.theme
import qs.modules.widgets.dashboard.controls
import qs.config

FloatingWindow {
    id: root
    visible: GlobalStates.settingsVisible
    title: I18n.t("Ambxst Settings")
    color: "transparent"

    minimumSize: Qt.size(750, 750)
    maximumSize: Qt.size(750, 750)

    property string displayTitle: I18n.t("Ambxst Settings")
    property real titleOpacity: 1
    property real titleOffset: 0

    readonly property string desiredTitle: settingsTab
        ? settingsTab.currentTitle
        : I18n.t("Ambxst Settings")

    onDesiredTitleChanged: {
        if (desiredTitle === displayTitle) {
            return;
        }

        if (Config.animDuration <= 0) {
            displayTitle = desiredTitle;
            titleOpacity = 1;
            titleOffset = 0;
            return;
        }

        titleSwapAnimation.restart();
    }

    onVisibleChanged: {
        if (visible && settingsTab) {
            settingsTab.resetNavigation();
        }
    }

    StyledRect {
        id: background
        anchors.fill: parent
        variant: "bg"
        radius: Styling.radius(0)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 8

            // Title bar
            StyledRect {
                id: titleBar
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                variant: "pane"
                radius: Styling.radius(-1)

                readonly property bool hasAnyChanges: GlobalStates.themeHasChanges
                    || GlobalStates.shellHasChanges
                    || GlobalStates.compositorHasChanges

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8

                    // Back button (only when there is history)
                    Button {
                        id: titleBackButton
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        visible: settingsTab ? settingsTab.isInSubsection : false

                        background: StyledRect {
                            id: titleBackBg
                            variant: titleBackButton.hovered ? "focus" : "common"
                            radius: Styling.radius(-4)
                        }

                        contentItem: Text {
                            text: I18n.isRtl ? Icons.caretRight : Icons.caretLeft
                            font.family: Icons.font
                            font.pixelSize: 18
                            color: titleBackBg.item
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            if (settingsTab) {
                                settingsTab.goBack();
                            }
                        }
                    }

                    // Title
                    Text {
                        id: titleText
                        text: root.displayTitle
                        font.family: Styling.defaultFont
                        font.pixelSize: Styling.fontSize(0) + 2
                        font.bold: true
                        color: titleBar.item
                        opacity: root.titleOpacity
                        Layout.fillWidth: true

                        transform: Translate {
                            y: root.titleOffset
                        }
                    }

                    RowLayout {
                        id: sectionControls
                        spacing: 6
                        visible: settingsTab && (settingsTab.titlebarShowToggle
                            || (settingsTab.titlebarActions && settingsTab.titlebarActions.length > 0)
                            || settingsTab.titlebarCustomComponent)

                        Loader {
                            id: titlebarCustomLoader
                            sourceComponent: settingsTab ? settingsTab.titlebarCustomComponent : null
                            visible: item !== null
                        }

                        Repeater {
                            model: settingsTab ? settingsTab.titlebarActions : []

                            delegate: Button {
                                required property var modelData
                                required property int index
                                flat: true
                                implicitWidth: 28
                                implicitHeight: 28
                                property bool isLoading: modelData.loading === true
                                enabled: (modelData.enabled !== undefined ? modelData.enabled : true)
                                    && !isLoading

                                background: StyledRect {
                                    variant: parent.hovered ? "focus" : "common"
                                    radius: Styling.radius(-4)
                                }

                                contentItem: Text {
                                    text: modelData.icon || ""
                                    font.family: Icons.font
                                    font.pixelSize: 14
                                    color: parent.isLoading ? Styling.srItem("overprimary")
                                        : (parent.enabled ? Colors.overBackground : Colors.outline)
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter

                                }

                                onClicked: {
                                    if (modelData.onClicked) {
                                        modelData.onClicked();
                                    }
                                }

                                StyledToolTip {
                                    visible: parent.hovered && modelData.tooltip
                                    tooltipText: modelData.tooltip || ""
                                }
                            }
                        }

                        Switch {
                            id: sectionToggle
                            visible: settingsTab ? settingsTab.titlebarShowToggle : false
                            checked: settingsTab ? settingsTab.titlebarToggleChecked : false
                            onCheckedChanged: {
                                if (settingsTab && settingsTab.titlebarToggleHandler) {
                                    settingsTab.titlebarToggleHandler(checked);
                                }
                            }

                            indicator: Rectangle {
                                implicitWidth: 40
                                implicitHeight: 20
                                x: sectionToggle.leftPadding
                                y: parent.height / 2 - height / 2
                                radius: height / 2
                                color: sectionToggle.checked ? Styling.srItem("overprimary") : Colors.surfaceBright
                                border.color: sectionToggle.checked ? Styling.srItem("overprimary") : Colors.outline

                                Behavior on color {
                                    enabled: Config.animDuration > 0
                                    ColorAnimation {
                                        duration: Config.animDuration / 2
                                    }
                                }

                                Rectangle {
                                    x: sectionToggle.checked ? parent.width - width - 2 : 2
                                    y: 2
                                    width: parent.height - 4
                                    height: width
                                    radius: width / 2
                                    color: sectionToggle.checked ? Colors.background : Colors.overSurfaceVariant

                                    Behavior on x {
                                        enabled: Config.animDuration > 0
                                        NumberAnimation {
                                            duration: Config.animDuration / 2
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }
                            }
                            background: null
                        }
                    }

                    // Unsaved indicator
                    Text {
                        visible: titleBar.hasAnyChanges
                        text: I18n.t("Unsaved changes")
                        font.family: Styling.defaultFont
                        font.pixelSize: Styling.fontSize(0)
                        color: Styling.srItem("error")
                        opacity: 0.8
                    }

                    // Discard button
                    Button {
                        id: discardButton
                        enabled: titleBar.hasAnyChanges
                        visible: titleBar.hasAnyChanges
                        Layout.preferredHeight: 32
                        leftPadding: 12
                        rightPadding: 12

                        readonly property bool hasChanges: titleBar.hasAnyChanges

                        background: StyledRect {
                            id: discardButtonBg
                            variant: discardButton.hovered ? "errorfocus" : "error"
                            radius: Styling.radius(-4)
                        }

                        contentItem: RowLayout {
                            spacing: 6

                            Text {
                                text: Icons.sync
                                font.family: Icons.font
                                font.pixelSize: 18
                                color: discardButton.hasChanges ? discardButtonBg.item : Colors.overBackground
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Text {
                                text: I18n.t("Discard")
                                font.family: Styling.defaultFont
                                font.pixelSize: Styling.fontSize(0)
                                font.bold: true
                                color: discardButton.hasChanges ? discardButtonBg.item : Colors.overBackground
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }

                        onClicked: {
                            if (GlobalStates.themeHasChanges)
                                GlobalStates.discardThemeChanges();
                            if (GlobalStates.shellHasChanges)
                                GlobalStates.discardShellChanges();
                            if (GlobalStates.compositorHasChanges)
                                GlobalStates.discardCompositorChanges();
                        }

                        ToolTip.visible: hovered
                        ToolTip.text: I18n.t("Discard all changes")
                        ToolTip.delay: 500
                    }

                    // Apply button
                    Button {
                        id: applyButton
                        enabled: titleBar.hasAnyChanges
                        visible: titleBar.hasAnyChanges
                        Layout.preferredHeight: 32
                        leftPadding: 12
                        rightPadding: 12

                        readonly property bool hasChanges: titleBar.hasAnyChanges

                        background: StyledRect {
                            id: applyButtonBg
                            variant: applyButton.hovered ? "primaryfocus" : "primary"
                            radius: Styling.radius(-4)
                        }

                        contentItem: RowLayout {
                            spacing: 6

                            Text {
                                text: Icons.disk
                                font.family: Icons.font
                                font.pixelSize: 18
                                color: applyButton.hasChanges ? applyButtonBg.item : Colors.overBackground
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Text {
                                text: I18n.t("Apply")
                                font.family: Styling.defaultFont
                                font.pixelSize: Styling.fontSize(0)
                                font.bold: true
                                color: applyButton.hasChanges ? applyButtonBg.item : Colors.overBackground
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }

                        onClicked: {
                            if (GlobalStates.themeHasChanges)
                                GlobalStates.applyThemeChanges();
                            if (GlobalStates.shellHasChanges)
                                GlobalStates.applyShellChanges();
                            if (GlobalStates.compositorHasChanges)
                                GlobalStates.applyCompositorChanges();
                        }

                        ToolTip.visible: hovered
                        ToolTip.text: I18n.t("Save changes to config")
                        ToolTip.delay: 500
                    }
                }
            }

            // Main content
            SettingsTab {
                id: settingsTab
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }
    }

    Shortcut {
        sequence: "Esc"
        enabled: root.visible && settingsTab && settingsTab.isInSubsection
        onActivated: settingsTab.goBack()
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.BackButton
        hoverEnabled: false
        onClicked: {
            if (settingsTab && settingsTab.isInSubsection) {
                settingsTab.goBack();
                mouse.accepted = true;
            }
        }
    }

    SequentialAnimation {
        id: titleSwapAnimation
        running: false

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "titleOpacity"
                to: 0
                duration: Config.animDuration / 3
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: root
                property: "titleOffset"
                to: -6
                duration: Config.animDuration / 3
                easing.type: Easing.OutCubic
            }
        }

        ScriptAction {
            script: {
                root.displayTitle = root.desiredTitle;
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "titleOpacity"
                to: 1
                duration: Config.animDuration / 2
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: root
                property: "titleOffset"
                to: 0
                duration: Config.animDuration / 2
                easing.type: Easing.OutCubic
            }
        }
    }
}
