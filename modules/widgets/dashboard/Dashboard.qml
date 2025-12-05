import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.globals
import qs.modules.services
import qs.modules.notch
import qs.modules.widgets.dashboard.widgets
import qs.modules.widgets.dashboard.kanban
import qs.modules.widgets.dashboard.assistant
import qs.modules.widgets.dashboard.tmux
import qs.modules.widgets.dashboard.clipboard
import qs.modules.widgets.dashboard.emoji
import qs.modules.widgets.dashboard.metrics
import qs.config

NotchAnimationBehavior {
    id: root

    property int leftPanelWidth

    property var state: QtObject {
        property int currentTab: GlobalStates.dashboardCurrentTab
    }

    readonly property var tabModel: [Icons.widgets, Icons.kanban, Icons.heartbeat, Icons.assistant]
    readonly property int tabCount: tabModel.length
    readonly property int tabSpacing: 8

    readonly property int tabWidth: 48
    readonly property real nonAnimWidth: (state.currentTab === 0 ? 600 : 400) + tabWidth + 16 // unified launcher tab is wider

    implicitWidth: nonAnimWidth
    implicitHeight: 430

    focus: true

    Keys.onPressed: event => {
        if (state.currentTab === 0 && MprisController.activePlayer) {
            if (event.key === Qt.Key_Space) {
                MprisController.togglePlaying();
                event.accepted = true;
            } else if (event.key === Qt.Key_Left && MprisController.activePlayer.canSeek) {
                MprisController.activePlayer.position = Math.max(0, MprisController.activePlayer.position - 10);
                event.accepted = true;
            } else if (event.key === Qt.Key_Right && MprisController.activePlayer.canSeek) {
                MprisController.activePlayer.position = Math.min(MprisController.activePlayer.length, MprisController.activePlayer.position + 10);
                event.accepted = true;
            } else if (event.key === Qt.Key_Up && MprisController.canGoPrevious) {
                MprisController.previous();
                event.accepted = true;
            } else if (event.key === Qt.Key_Down && MprisController.canGoNext) {
                MprisController.next();
                event.accepted = true;
            }
        }
    }

    // Usar el comportamiento estándar de animaciones del notch
    isVisible: GlobalStates.dashboardOpen

    // Navegar a la pestaña seleccionada cuando se abre el dashboard
    Component.onCompleted: {
        root.state.currentTab = GlobalStates.dashboardCurrentTab;
    }

    // Focus search input when dashboard opens to different tabs
    onIsVisibleChanged: {
        if (isVisible) {
            if (GlobalStates.dashboardCurrentTab === 0) {
                Notifications.hideAllPopups();
                focusUnifiedLauncherTimer.restart();
            }
        } else {
            // Reset launcher state when dashboard closes
            GlobalStates.clearLauncherState();
        }
    }

    // Timer para focus en unified launcher tab
    Timer {
        id: focusUnifiedLauncherTimer
        interval: 50
        repeat: false
        onTriggered: {
            if (stack.currentItem && stack.currentItem.focusSearchInput) {
                stack.currentItem.focusSearchInput();
            }
        }
    }

    // Escuchar cambios en dashboardCurrentTab para navegar automáticamente
    Connections {
        target: GlobalStates
        function onDashboardCurrentTabChanged() {
            if (GlobalStates.dashboardCurrentTab !== root.state.currentTab) {
                stack.navigateToTab(GlobalStates.dashboardCurrentTab);
            }
        }

        // Focus cuando cambia el texto del launcher (por shortcuts con prefix)
        function onLauncherSearchTextChanged() {
            if (isVisible && GlobalStates.dashboardCurrentTab === 0) {
                focusUnifiedLauncherTimer.restart();
            }
        }
    }

    Row {
        id: mainLayout
        anchors.fill: parent
        spacing: 8

        // Tab buttons
        Item {
            id: tabsContainer
            width: root.tabWidth
            height: parent.height

            // Manejo del scroll con rueda del mouse
            WheelHandler {
                id: wheelHandler
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

                onWheel: event => {
                    // Determinar dirección del scroll
                    let scrollUp = event.angleDelta.y > 0;
                    let newIndex = root.state.currentTab;

                    if (scrollUp && newIndex > 0) {
                        // Scroll hacia arriba = pestaña anterior
                        newIndex = newIndex - 1;
                    } else if (!scrollUp && newIndex < root.tabCount - 1) {
                        // Scroll hacia abajo = pestaña siguiente
                        newIndex = newIndex + 1;
                    }

                    // Navegar solo si cambió el índice
                    if (newIndex !== root.state.currentTab) {
                        stack.navigateToTab(newIndex);
                    }
                }
            }

            // Background highlight que se desplaza verticalmente con efecto elástico
            StyledRect {
                id: tabHighlight
                variant: "primary"
                width: parent.width
                radius: Styling.radius(4)
                z: 0

                property real idx1: root.state.currentTab
                property real idx2: root.state.currentTab

                x: 0
                y: Math.min(idx1, idx2) * (width + root.tabSpacing)
                height: Math.abs(idx1 - idx2) * (width + root.tabSpacing) + width

                Behavior on idx1 {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration / 3
                        easing.type: Easing.OutSine
                    }
                }
                Behavior on idx2 {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutSine
                    }
                }
            }

            Column {
                id: tabs
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: root.tabSpacing

                Repeater {
                    model: root.tabModel

                    Button {
                        required property int index
                        required property string modelData

                        text: modelData
                        flat: true
                        width: tabsContainer.width
                        height: width
                        // implicitHeight: (tabsContainer.height - root.tabSpacing * (root.tabCount - 1)) / root.tabCount

                        background: Rectangle {
                            color: "transparent"
                            radius: Styling.radius(4)
                        }

                        contentItem: Text {
                            text: parent.text
                            textFormat: Text.RichText
                            color: root.state.currentTab === index ? Config.resolveColor(Config.theme.srPrimary.itemColor) : Colors.overBackground
                            // font.family: Config.theme.font
                            font.family: Icons.font
                            // font.pixelSize: Config.theme.fontSize
                            font.pixelSize: 20
                            font.weight: Font.Medium
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter

                            Behavior on color {
                                enabled: Config.animDuration > 0
                                ColorAnimation {
                                    duration: Config.animDuration
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        onClicked: stack.navigateToTab(index)
                    }
                }
            }

            // Settings button
            Button {
                id: settingsButton
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: width
                flat: true
                hoverEnabled: true

                background: StyledRect {
                    radius: Styling.radius(4)
                    variant: settingsButton.hovered ? "focus" : "common"
                }

                contentItem: Text {
                    text: Icons.gear
                    font.family: Icons.font
                    font.pixelSize: 20
                    font.weight: Font.Medium
                    color: Colors.overBackground
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    Visibilities.setActiveModule("");
                    GlobalStates.openSettings();
                }
            }
        }

        // Separator
        Separator {
            width: 2
            height: parent.height
            vert: true
            gradient: null
            color: Colors.surface
        }

        // Content area
        Rectangle {
            id: viewWrapper

            color: "transparent"

            width: parent.width - root.tabWidth - 2 - 16 // Ancho total menos tabs, separador y spacings
            height: parent.height

            clip: true

            StackView {
                id: stack
                anchors.fill: parent

                // Array de componentes para cargar dinámicamente
                property var components: [unifiedLauncherComponent, quickSettingsComponent, metricsComponent, assistantComponent]

                // Cargar directamente el componente correcto según GlobalStates
                initialItem: components[GlobalStates.dashboardCurrentTab]

                // Handler para cuando el item actual cambia
                onCurrentItemChanged: {
                    if (currentItem) {
                        if (root.state.currentTab === 0 && currentItem.focusSearchInput) {
                            focusUnifiedLauncherTimer.restart();
                        }
                    }
                }

                // Función para navegar a un tab específico
                function navigateToTab(index) {
                    if (index >= 0 && index < components.length && index !== root.state.currentTab) {
                        let targetComponent = components[index];

                        let direction = index > root.state.currentTab ? StackView.PushTransition : StackView.PopTransition;

                        stack.replace(targetComponent, {}, direction);

                        // Reset launcher state when leaving unified launcher tab (tab 0)
                        if (root.state.currentTab === 0 && index !== 0) {
                            GlobalStates.clearLauncherState();
                        }

                        root.state.currentTab = index;
                        GlobalStates.dashboardCurrentTab = index;

                        if (index === 0) {
                            Notifications.hideAllPopups();
                            focusUnifiedLauncherTimer.restart();
                        }
                    }
                }

                pushEnter: Transition {
                    PropertyAnimation {
                        property: "y"
                        from: stack.height
                        to: 0
                        duration: Config.animDuration
                        easing.type: Easing.OutCubic
                    }
                    PropertyAnimation {
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                }

                pushExit: Transition {
                    PropertyAnimation {
                        property: "y"
                        from: 0
                        to: -stack.height
                        duration: Config.animDuration
                        easing.type: Easing.OutCubic
                    }
                    PropertyAnimation {
                        property: "opacity"
                        from: 1
                        to: 0
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                }

                popEnter: Transition {
                    PropertyAnimation {
                        property: "y"
                        from: -stack.height
                        to: 0
                        duration: Config.animDuration
                        easing.type: Easing.OutCubic
                    }
                    PropertyAnimation {
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                }

                popExit: Transition {
                    PropertyAnimation {
                        property: "y"
                        from: 0
                        to: stack.height
                        duration: Config.animDuration
                        easing.type: Easing.OutCubic
                    }
                    PropertyAnimation {
                        property: "opacity"
                        from: 1
                        to: 0
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                }

                // Gesture handling para swipe vertical
                MouseArea {
                    anchors.fill: parent
                    property real startY: 0
                    property real startX: 0
                    property bool swiping: false
                    property real swipeThreshold: 50
                    property real swipeProgress: 0

                    onPressed: mouse => {
                        startY = mouse.y;
                        startX = mouse.x;
                        swiping = false;
                        swipeProgress = 0;
                    }

                    onPositionChanged: mouse => {
                        let deltaY = mouse.y - startY;
                        let deltaX = Math.abs(mouse.x - startX);

                        // Solo considerar swipe vertical si el movimiento horizontal es mínimo
                        if (Math.abs(deltaY) > 20 && deltaX < 30) {
                            swiping = true;
                            swipeProgress = Math.max(-1, Math.min(1, deltaY / (parent.height * 0.3)));
                        }
                    }

                    onReleased: mouse => {
                        if (swiping) {
                            let deltaY = mouse.y - startY;

                            if (deltaY < -swipeThreshold && root.state.currentTab < root.tabCount - 1) {
                                // Swipe hacia arriba - siguiente tab
                                stack.navigateToTab(root.state.currentTab + 1);
                            } else if (deltaY > swipeThreshold && root.state.currentTab > 0) {
                                // Swipe hacia abajo - tab anterior
                                stack.navigateToTab(root.state.currentTab - 1);
                            }
                        }

                        swiping = false;
                        swipeProgress = 0;
                    }

                    // Pasar eventos de click a los elementos internos
                    propagateComposedEvents: true
                }
            }
        }
    }

    // Atajos de teclado para navegación
    Shortcut {
        id: nextTabShortcut
        sequence: "Ctrl+Tab"
        enabled: GlobalStates.dashboardOpen

        onActivated: {
            let nextIndex = (root.state.currentTab + 1) % root.tabCount;
            stack.navigateToTab(nextIndex);
        }
    }

    Shortcut {
        id: prevTabShortcut
        sequence: "Ctrl+Shift+Tab"
        enabled: GlobalStates.dashboardOpen

        onActivated: {
            let prevIndex = root.state.currentTab - 1;
            if (prevIndex < 0) {
                prevIndex = root.tabCount - 1;
            }
            stack.navigateToTab(prevIndex);
        }
    }

    // Animated size properties for smooth transitions
    property real animatedWidth: implicitWidth
    property real animatedHeight: implicitHeight

    width: animatedWidth
    height: animatedHeight

    // Update animated properties when implicit properties change
    onImplicitWidthChanged: animatedWidth = implicitWidth
    onImplicitHeightChanged: animatedHeight = implicitHeight

    Behavior on animatedWidth {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutBack
            easing.overshoot: 1.1
        }
    }

    Behavior on animatedHeight {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutBack
            easing.overshoot: 1.1
        }
    }

    // Component definitions for better performance (defined once, reused)
    Component {
        id: unifiedLauncherComponent
        WidgetsTab {
            leftPanelWidth: root.leftPanelWidth
        }
    }

    Component {
        id: quickSettingsComponent
        KanbanTab {}
    }

    Component {
        id: assistantComponent
        AssistantTab {}
    }

    Component {
        id: metricsComponent
        MetricsTab {}
    }
}
