import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.components
import qs.modules.globals
import qs.config

Item {
    id: root
    property bool schemeListExpanded: false
    readonly property var matugenSchemes: ["scheme-content", "scheme-expressive", "scheme-fidelity", "scheme-fruit-salad", "scheme-monochrome", "scheme-neutral", "scheme-rainbow", "scheme-tonal-spot"]
    property var presets: GlobalStates.wallpaperManager ? GlobalStates.wallpaperManager.colorPresets : []
    onPresetsChanged: console.log("SchemeSelector received presets:", presets)

    property var combinedModel: {
        var currentPresets = presets; // Explicit dependency
        var list = [];
        for (var i = 0; i < matugenSchemes.length; i++) {
            list.push({
                id: matugenSchemes[i],
                label: getSchemeDisplayName(matugenSchemes[i]),
                type: "matugen"
            });
        }
        for (var j = 0; j < currentPresets.length; j++) {
            list.push({
                id: currentPresets[j],
                label: currentPresets[j],
                type: "preset"
            });
        }
        return list;
    }

    property bool scrollBarPressed: false
    property int selectedSchemeIndex: -1
    property bool keyboardNavigationActive: false

    signal schemeSelectorClosed
    signal escapePressedOnScheme
    signal tabPressed
    signal shiftTabPressed

    function openAndFocus() {
        schemeListExpanded = true;
        updateSelectedIndex();
        keyboardNavigationActive = true;
        schemeButton.forceActiveFocus();
        // Posicionar el ListView en el item seleccionado después de que se expanda
        positionTimer.restart();
    }

    function positionAtSelectedScheme() {
        if (selectedSchemeIndex >= 0 && selectedSchemeIndex < combinedModel.length) {
            schemeListView.positionViewAtIndex(selectedSchemeIndex, ListView.Center);
        }
    }

    Timer {
        id: positionTimer
        interval: 50
        repeat: false
        onTriggered: {
            positionAtSelectedScheme();
        }
    }

    function closeAndSignal() {
        keyboardNavigationActive = false;
        schemeListExpanded = false;
        schemeSelectorClosed();
    }

    Connections {
        target: GlobalStates.wallpaperManager
        function onCurrentMatugenSchemeChanged() {
            updateSelectedIndex();
        }
        function onActiveColorPresetChanged() {
            updateSelectedIndex();
        }
    }

    function updateSelectedIndex() {
        if (!GlobalStates.wallpaperManager)
            return;

        var activePreset = GlobalStates.wallpaperManager.activeColorPreset;
        var activeMatugen = GlobalStates.wallpaperManager.currentMatugenScheme;

        var index = -1;

        if (activePreset) {
            for (var i = 0; i < combinedModel.length; i++) {
                if (combinedModel[i].type === "preset" && combinedModel[i].id === activePreset) {
                    index = i;
                    break;
                }
            }
        } else if (activeMatugen) {
            for (var i = 0; i < combinedModel.length; i++) {
                if (combinedModel[i].type === "matugen" && combinedModel[i].id === activeMatugen) {
                    index = i;
                    break;
                }
            }
        }

        if (index !== -1)
            selectedSchemeIndex = index;
    }

    Component.onCompleted: {
        updateSelectedIndex();
    }

    function getSchemeDisplayName(scheme) {
        const map = {
            "scheme-content": "Content",
            "scheme-expressive": "Expressive",
            "scheme-fidelity": "Fidelity",
            "scheme-fruit-salad": "Fruit Salad",
            "scheme-monochrome": "Monochrome",
            "scheme-neutral": "Neutral",
            "scheme-rainbow": "Rainbow",
            "scheme-tonal-spot": "Tonal Spot"
        };
        return map[scheme] || scheme;
    }

    function getCurrentDisplayName() {
        if (!GlobalStates.wallpaperManager)
            return "Select Scheme";

        if (GlobalStates.wallpaperManager.activeColorPreset) {
            return GlobalStates.wallpaperManager.activeColorPreset;
        }

        if (GlobalStates.wallpaperManager.currentMatugenScheme) {
            return getSchemeDisplayName(GlobalStates.wallpaperManager.currentMatugenScheme);
        }

        return "Select Scheme";
    }

    // Layout properties (can be overridden by parent)
    implicitWidth: 200
    implicitHeight: schemeListExpanded ? 40 + 4 + (40 * 3) + 8 : 48

    Behavior on implicitHeight {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutQuart
        }
    }

    StyledRect {
        variant: keyboardNavigationActive && schemeButton.activeFocus ? "focus" : "pane"
        radius: Styling.radius(4)
        anchors.fill: parent

        ColumnLayout {
            id: mainLayout
            anchors.fill: parent
            anchors.margins: 4
            spacing: 0

            // Top row with scheme button and dark/light button
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Button {
                    id: schemeButton
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    text: getCurrentDisplayName()
                    focus: true

                    onActiveFocusChanged: {
                        if (!activeFocus) {
                            keyboardNavigationActive = false;
                            if (schemeListExpanded) {
                                schemeListExpanded = false;
                            }
                        }
                    }

                    onClicked: {
                        keyboardNavigationActive = false;
                        schemeListExpanded = !schemeListExpanded;
                        if (schemeListExpanded) {
                            updateSelectedIndex();
                            positionTimer.restart();
                        }
                    }

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Tab) {
                            if (keyboardNavigationActive) {
                                keyboardNavigationActive = false;
                                if (schemeListExpanded) {
                                    schemeListExpanded = false;
                                }
                                if (event.modifiers & Qt.ShiftModifier) {
                                    shiftTabPressed();
                                } else {
                                    tabPressed();
                                }
                                event.accepted = true;
                            }
                        } else if (event.key === Qt.Key_Space) {
                            schemeListExpanded = !schemeListExpanded;
                            if (schemeListExpanded) {
                                updateSelectedIndex();
                                positionTimer.restart();
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Left) {
                            Config.theme.lightMode = true;
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Right) {
                            Config.theme.lightMode = false;
                            event.accepted = true;
                        } else if (!schemeListExpanded) {
                            return;
                        } else if (event.key === Qt.Key_Down) {
                            if (selectedSchemeIndex < combinedModel.length - 1) {
                                selectedSchemeIndex++;
                                schemeListView.currentIndex = selectedSchemeIndex;
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            if (selectedSchemeIndex > 0) {
                                selectedSchemeIndex--;
                                schemeListView.currentIndex = selectedSchemeIndex;
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (selectedSchemeIndex >= 0 && GlobalStates.wallpaperManager) {
                                var item = combinedModel[selectedSchemeIndex];
                                if (item.type === "preset") {
                                    GlobalStates.wallpaperManager.setColorPreset(item.id);
                                } else {
                                    GlobalStates.wallpaperManager.setMatugenScheme(item.id);
                                }
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Escape) {
                            keyboardNavigationActive = false;
                            schemeButton.focus = false;
                            if (schemeListExpanded) {
                                schemeListExpanded = false;
                            }
                            escapePressedOnScheme();
                            event.accepted = true;
                        }
                    }

                    background: Rectangle {
                        color: Colors.background
                        radius: Styling.radius(0)
                    }

                    contentItem: Text {
                        text: parent.text
                        color: Colors.overSurface
                        font.family: Config.theme.font
                        font.pixelSize: Config.theme.fontSize
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 8
                    }
                }

                Switch {
                    Layout.preferredWidth: 72
                    Layout.preferredHeight: 40
                    checked: Config.theme.lightMode
                    focusPolicy: Qt.NoFocus

                    onCheckedChanged: {
                        Config.theme.lightMode = checked;
                    }

                    indicator: Rectangle {
                        implicitWidth: 72
                        implicitHeight: 40
                        radius: Styling.radius(0)
                        color: Colors.background

                        Text {
                            z: 1
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: Icons.sun
                            color: Config.theme.lightMode ? Styling.srItem("primary") : Colors.overBackground
                            font.family: Icons.font
                            font.pixelSize: 20
                        }

                        Text {
                            z: 1
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: Icons.moon
                            color: Config.theme.lightMode ? Colors.overBackground : Styling.srItem("primary")
                            font.family: Icons.font
                            font.pixelSize: 20
                        }

                        StyledRect {
                            variant: "primary"
                            z: 0
                            width: 36
                            height: 36
                            radius: Styling.radius(-2)
                            x: Config.theme.lightMode ? 2 : 36
                            anchors.verticalCenter: parent.verticalCenter

                            Behavior on x {
                                enabled: Config.animDuration > 0
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                ClippingRectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: schemeListExpanded ? 40 * 3 : 0
                    Layout.topMargin: schemeListExpanded ? 4 : 0
                    color: Colors.background
                    radius: Styling.radius(0)
                    opacity: schemeListExpanded ? 1 : 0

                    ListView {
                        id: schemeListView
                        anchors.fill: parent
                        clip: true
                        model: combinedModel
                        currentIndex: selectedSchemeIndex
                        interactive: true
                        boundsBehavior: Flickable.StopAtBounds
                        highlightFollowsCurrentItem: !isScrolling
                        highlightRangeMode: ListView.ApplyRange
                        preferredHighlightBegin: 0
                        preferredHighlightEnd: height

                        // Propiedad para detectar si está en movimiento
                        property bool isScrolling: dragging || flicking

                        onCurrentIndexChanged: {
                            if (currentIndex !== selectedSchemeIndex) {
                                selectedSchemeIndex = currentIndex;
                            }
                        }

                        delegate: Button {
                            required property var modelData
                            required property int index

                            width: schemeListView.width
                            height: 40
                            text: modelData.label

                            onClicked: {
                                if (GlobalStates.wallpaperManager) {
                                    if (modelData.type === "preset") {
                                        GlobalStates.wallpaperManager.setColorPreset(modelData.id);
                                    } else {
                                        GlobalStates.wallpaperManager.setMatugenScheme(modelData.id);
                                    }
                                    schemeListExpanded = false;
                                }
                            }

                            background: Rectangle {
                                color: "transparent"
                            }

                            contentItem: Text {
                                text: parent.text
                                color: selectedSchemeIndex === index ? Styling.srItem("primary") : Colors.overSurface
                                font.family: Config.theme.font
                                font.pixelSize: Config.theme.fontSize
                                font.weight: selectedSchemeIndex === index ? Font.Bold : Font.Normal
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: 8

                                Behavior on color {
                                    enabled: Config.animDuration > 0
                                    ColorAnimation {
                                        duration: Config.animDuration / 2
                                        easing.type: Easing.OutQuart
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: !schemeListView.isScrolling
                                onEntered: {
                                    if (schemeListView.isScrolling)
                                        return;
                                    selectedSchemeIndex = index;
                                    schemeListView.currentIndex = index;
                                }
                                onClicked: {
                                    if (schemeListView.isScrolling)
                                        return;
                                    if (GlobalStates.wallpaperManager) {
                                        if (modelData.type === "preset") {
                                            GlobalStates.wallpaperManager.setColorPreset(modelData.id);
                                        } else {
                                            GlobalStates.wallpaperManager.setMatugenScheme(modelData.id);
                                        }
                                        schemeListExpanded = false;
                                    }
                                }
                            }
                        }

                        highlight: StyledRect {
                            variant: "primary"
                            radius: Styling.radius(0)
                            visible: selectedSchemeIndex >= 0
                            z: -1
                        }

                        highlightMoveDuration: Config.animDuration > 0 ? Config.animDuration / 2 : 0
                        highlightMoveVelocity: -1
                        highlightResizeDuration: Config.animDuration / 2
                        highlightResizeVelocity: -1
                    }

                    // Animate topMargin for ClippingRectangle
                    Behavior on Layout.topMargin {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutQuart
                        }
                    }

                    Behavior on Layout.preferredHeight {
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
                }

                ScrollBar {
                    Layout.preferredWidth: 8
                    Layout.preferredHeight: schemeListExpanded ? (40 * 3) - 32 : 0
                    Layout.alignment: Qt.AlignVCenter
                    orientation: Qt.Vertical
                    visible: schemeListView.contentHeight > schemeListView.height

                    position: schemeListView.contentY / schemeListView.contentHeight
                    size: schemeListView.height / schemeListView.contentHeight

                    background: Rectangle {
                        color: Colors.background
                        radius: Styling.radius(0)
                    }

                    contentItem: StyledRect {
                        variant: "primary"
                        radius: Styling.radius(0)
                    }

                    onPressedChanged: {
                        scrollBarPressed = pressed;
                    }

                    onPositionChanged: {
                        if (scrollBarPressed && schemeListView.contentHeight > schemeListView.height) {
                            schemeListView.contentY = position * schemeListView.contentHeight;
                        }
                    }
                }
            }
        }
    }
}
