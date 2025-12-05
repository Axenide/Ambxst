pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.components
import qs.modules.globals
import qs.config

FloatingWindow {
    id: root

    visible: GlobalStates.settingsVisible
    title: "Ambxst Settings"
    color: "transparent"

    minimumSize: Qt.size(750, 750)
    maximumSize: Qt.size(750, 750)

    property string selectedVariant: ""
    property bool hasChanges: false

    // Snapshot of Config state when editor opens (to detect changes)
    property var savedSnapshot: ({})

    // When window becomes visible, take a snapshot and pause auto-save
    onVisibleChanged: {
        if (visible) {
            Config.pauseAutoSave = true;  // Pause auto-save while editing
            takeSnapshot();
            hasChanges = false;
        } else {
            Config.pauseAutoSave = false;  // Resume auto-save when closed
        }
    }

    // Take a snapshot of all variant configs from Config
    function takeSnapshot() {
        savedSnapshot = {
            srBg: cloneVariant(Config.theme.srBg),
            srInternalBg: cloneVariant(Config.theme.srInternalBg),
            srPane: cloneVariant(Config.theme.srPane),
            srCommon: cloneVariant(Config.theme.srCommon),
            srFocus: cloneVariant(Config.theme.srFocus),
            srPrimary: cloneVariant(Config.theme.srPrimary),
            srPrimaryFocus: cloneVariant(Config.theme.srPrimaryFocus),
            srOverPrimary: cloneVariant(Config.theme.srOverPrimary),
            srSecondary: cloneVariant(Config.theme.srSecondary),
            srSecondaryFocus: cloneVariant(Config.theme.srSecondaryFocus),
            srOverSecondary: cloneVariant(Config.theme.srOverSecondary),
            srTertiary: cloneVariant(Config.theme.srTertiary),
            srTertiaryFocus: cloneVariant(Config.theme.srTertiaryFocus),
            srOverTertiary: cloneVariant(Config.theme.srOverTertiary),
            srError: cloneVariant(Config.theme.srError),
            srErrorFocus: cloneVariant(Config.theme.srErrorFocus),
            srOverError: cloneVariant(Config.theme.srOverError)
        };
    }

    // Deep clone a variant config object
    function cloneVariant(v) {
        return {
            gradient: JSON.parse(JSON.stringify(v.gradient)),
            gradientType: v.gradientType,
            gradientAngle: v.gradientAngle,
            gradientCenterX: v.gradientCenterX,
            gradientCenterY: v.gradientCenterY,
            halftoneDotMin: v.halftoneDotMin,
            halftoneDotMax: v.halftoneDotMax,
            halftoneStart: v.halftoneStart,
            halftoneEnd: v.halftoneEnd,
            halftoneDotColor: v.halftoneDotColor,
            halftoneBackgroundColor: v.halftoneBackgroundColor,
            border: JSON.parse(JSON.stringify(v.border)),
            itemColor: v.itemColor,
            opacity: v.opacity
        };
    }

    // Get the Config variant object by id
    function getConfigVariant(variantId) {
        switch (variantId) {
        case "bg":
            return Config.theme.srBg;
        case "internalbg":
            return Config.theme.srInternalBg;
        case "pane":
            return Config.theme.srPane;
        case "common":
            return Config.theme.srCommon;
        case "focus":
            return Config.theme.srFocus;
        case "primary":
            return Config.theme.srPrimary;
        case "primaryfocus":
            return Config.theme.srPrimaryFocus;
        case "overprimary":
            return Config.theme.srOverPrimary;
        case "secondary":
            return Config.theme.srSecondary;
        case "secondaryfocus":
            return Config.theme.srSecondaryFocus;
        case "oversecondary":
            return Config.theme.srOverSecondary;
        case "tertiary":
            return Config.theme.srTertiary;
        case "tertiaryfocus":
            return Config.theme.srTertiaryFocus;
        case "overtertiary":
            return Config.theme.srOverTertiary;
        case "error":
            return Config.theme.srError;
        case "errorfocus":
            return Config.theme.srErrorFocus;
        case "overerror":
            return Config.theme.srOverError;
        default:
            return null;
        }
    }

    // Update a property directly in Config (real-time changes)
    function updateConfigVariant(variantId, property, value) {
        const configVar = getConfigVariant(variantId);
        if (configVar) {
            configVar[property] = value;
            hasChanges = true;
        }
    }

    // Apply: write current Config state to JSON
    function applyChanges() {
        if (!hasChanges)
            return;
        Config.loader.writeAdapter();
        takeSnapshot(); // Update snapshot to current state
        hasChanges = false;
    }

    // Discard: restore Config from saved snapshot
    function discardChanges() {
        if (!hasChanges)
            return;

        // Restore each variant from snapshot
        restoreVariant(savedSnapshot.srBg, Config.theme.srBg);
        restoreVariant(savedSnapshot.srInternalBg, Config.theme.srInternalBg);
        restoreVariant(savedSnapshot.srPane, Config.theme.srPane);
        restoreVariant(savedSnapshot.srCommon, Config.theme.srCommon);
        restoreVariant(savedSnapshot.srFocus, Config.theme.srFocus);
        restoreVariant(savedSnapshot.srPrimary, Config.theme.srPrimary);
        restoreVariant(savedSnapshot.srPrimaryFocus, Config.theme.srPrimaryFocus);
        restoreVariant(savedSnapshot.srOverPrimary, Config.theme.srOverPrimary);
        restoreVariant(savedSnapshot.srSecondary, Config.theme.srSecondary);
        restoreVariant(savedSnapshot.srSecondaryFocus, Config.theme.srSecondaryFocus);
        restoreVariant(savedSnapshot.srOverSecondary, Config.theme.srOverSecondary);
        restoreVariant(savedSnapshot.srTertiary, Config.theme.srTertiary);
        restoreVariant(savedSnapshot.srTertiaryFocus, Config.theme.srTertiaryFocus);
        restoreVariant(savedSnapshot.srOverTertiary, Config.theme.srOverTertiary);
        restoreVariant(savedSnapshot.srError, Config.theme.srError);
        restoreVariant(savedSnapshot.srErrorFocus, Config.theme.srErrorFocus);
        restoreVariant(savedSnapshot.srOverError, Config.theme.srOverError);

        hasChanges = false;
    }

    // Restore a single variant from snapshot
    function restoreVariant(snapshot, configVar) {
        configVar.gradient = snapshot.gradient;
        configVar.gradientType = snapshot.gradientType;
        configVar.gradientAngle = snapshot.gradientAngle;
        configVar.gradientCenterX = snapshot.gradientCenterX;
        configVar.gradientCenterY = snapshot.gradientCenterY;
        configVar.halftoneDotMin = snapshot.halftoneDotMin;
        configVar.halftoneDotMax = snapshot.halftoneDotMax;
        configVar.halftoneStart = snapshot.halftoneStart;
        configVar.halftoneEnd = snapshot.halftoneEnd;
        configVar.halftoneDotColor = snapshot.halftoneDotColor;
        configVar.halftoneBackgroundColor = snapshot.halftoneBackgroundColor;
        configVar.border = snapshot.border;
        configVar.itemColor = snapshot.itemColor;
        configVar.opacity = snapshot.opacity;
    }

    StyledRect {
        id: background
        anchors.fill: parent
        variant: "bg"
        enableShadow: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 8

            // Title bar
            StyledRect {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                variant: "pane"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 8

                    // Title
                    Text {
                        text: "Ambxst Settings"
                        font.family: Styling.defaultFont
                        font.pixelSize: Styling.fontSize(0) + 2
                        font.bold: true
                        color: Colors.primary
                        Layout.fillWidth: true
                    }

                    // Unsaved indicator
                    Text {
                        visible: root.hasChanges
                        text: "Unsaved changes"
                        font.family: Styling.defaultFont
                        font.pixelSize: Styling.fontSize(0)
                        font.italic: true
                        color: Colors.error
                        opacity: 0.8
                    }

                    // Discard button
                    Button {
                        id: discardButton
                        visible: root.hasChanges
                        Layout.preferredWidth: 100
                        Layout.preferredHeight: 32

                        background: StyledRect {
                            variant: discardButton.hovered ? "errorfocus" : "error"
                        }

                        contentItem: RowLayout {
                            spacing: 6

                            Text {
                                text: Icons.sync
                                font.family: Icons.font
                                font.pixelSize: 18
                                color: Colors.overError
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Text {
                                text: "Discard"
                                font.family: Styling.defaultFont
                                font.pixelSize: Styling.fontSize(0)
                                font.bold: true
                                color: Colors.overError
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }

                        onClicked: root.discardChanges()

                        ToolTip.visible: hovered
                        ToolTip.text: "Discard all changes"
                        ToolTip.delay: 500
                    }

                    // Apply button
                    Button {
                        id: applyButton
                        Layout.preferredWidth: 100
                        Layout.preferredHeight: 32

                        background: StyledRect {
                            variant: root.hasChanges ? (applyButton.hovered ? "primaryfocus" : "primary") : "common"
                            opacity: root.hasChanges ? 1.0 : 0.5
                        }

                        contentItem: RowLayout {
                            spacing: 6

                            Text {
                                text: Icons.disk
                                font.family: Icons.font
                                font.pixelSize: 18
                                color: root.hasChanges ? Colors.overPrimary : Colors.overBackground
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Text {
                                text: "Apply"
                                font.family: Styling.defaultFont
                                font.pixelSize: Styling.fontSize(0)
                                font.bold: true
                                color: root.hasChanges ? Colors.overPrimary : Colors.overBackground
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }

                        onClicked: root.applyChanges()

                        ToolTip.visible: hovered
                        ToolTip.text: "Save changes to config"
                        ToolTip.delay: 500
                    }

                    // Close button
                    Button {
                        id: titleCloseButton
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32

                        background: StyledRect {
                            variant: titleCloseButton.hovered ? "error" : "common"
                        }

                        contentItem: Text {
                            text: Icons.cancel
                            font.family: Icons.font
                            font.pixelSize: 18
                            color: titleCloseButton.hovered ? Colors.overError : Colors.overBackground
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            if (root.hasChanges) {
                                root.discardChanges();
                            }
                            GlobalStates.settingsVisible = false;
                        }
                    }
                }
            }

            // Main content
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8

                // Left side: Vertical tabs
                StyledRect {
                    id: tabsContainer
                    Layout.preferredWidth: 160
                    Layout.fillHeight: true
                    variant: "pane"

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 4

                        Text {
                            text: "Settings"
                            font.family: Styling.defaultFont
                            font.pixelSize: Styling.fontSize(0)
                            font.bold: true
                            color: Colors.primary
                            Layout.alignment: Qt.AlignHCenter
                            Layout.bottomMargin: 8
                        }

                        Repeater {
                            model: [
                                {
                                    name: "Theme",
                                    icon: Icons.cube
                                },
                                {
                                    name: "Bar",
                                    icon: Icons.gear
                                },
                                {
                                    name: "Hyprland",
                                    icon: Icons.gear
                                }
                            ]

                            delegate: Button {
                                id: tabButton
                                required property var modelData
                                required property int index

                                Layout.fillWidth: true
                                Layout.preferredHeight: 40

                                readonly property bool isSelected: tabStack.currentIndex === index

                                background: StyledRect {
                                    variant: tabButton.isSelected ? "primary" : (tabButton.hovered ? "focus" : "common")

                                    Behavior on opacity {
                                        enabled: (Config.animDuration ?? 0) > 0
                                        NumberAnimation {
                                            duration: (Config.animDuration ?? 0) / 2
                                        }
                                    }
                                }

                                contentItem: RowLayout {
                                    spacing: 8

                                    Text {
                                        text: tabButton.modelData.icon
                                        font.family: Icons.font
                                        font.pixelSize: 18
                                        color: tabButton.isSelected ? Colors.overPrimary : Colors.overBackground
                                        Layout.alignment: Qt.AlignVCenter
                                    }

                                    Text {
                                        text: tabButton.modelData.name
                                        font.family: Styling.defaultFont
                                        font.pixelSize: Styling.fontSize(0)
                                        color: tabButton.isSelected ? Colors.overPrimary : Colors.overBackground
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                }

                                onClicked: tabStack.currentIndex = index
                            }
                        }

                        Item {
                            Layout.fillHeight: true
                        }
                    }
                }

                // Right side: Content area
                StackLayout {
                    id: tabStack
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: 0

                    // Theme tab
                    ThemeTab {
                        id: themeTab
                        onUpdateVariant: (variantId, property, value) => {
                            root.updateConfigVariant(variantId, property, value);
                        }
                    }

                    // Bar tab (placeholder)
                    StyledRect {
                        variant: "pane"

                        Text {
                            anchors.centerIn: parent
                            text: "Bar Settings (Coming Soon)"
                            font.family: Styling.defaultFont
                            font.pixelSize: Styling.fontSize(0)
                            color: Colors.overBackground
                        }
                    }

                    // Hyprland tab (placeholder)
                    StyledRect {
                        variant: "pane"

                        Text {
                            anchors.centerIn: parent
                            text: "Hyprland Settings (Coming Soon)"
                            font.family: Styling.defaultFont
                            font.pixelSize: Styling.fontSize(0)
                            color: Colors.overBackground
                        }
                    }
                }
            }
        }
    }
}
