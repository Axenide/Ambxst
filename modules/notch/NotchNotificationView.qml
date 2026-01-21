import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs.modules.theme
import qs.modules.services
import qs.modules.globals
import qs.modules.components
import qs.modules.notifications
import qs.config
import "../notifications/notification_utils.js" as NotificationUtils

Item {
    id: root

    implicitWidth: hovered ? 420 : 320
    implicitHeight: mainColumn.implicitHeight

    Behavior on implicitWidth {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutBack
            easing.overshoot: 1.2
        }
    }

    property var currentNotification: {
        return (Notifications.popupList.length > currentIndex && currentIndex >= 0) ? Notifications.popupList[currentIndex] : (Notifications.popupList.length > 0 ? Notifications.popupList[0] : null);
    }
    property bool notchHovered: false
    property bool isNavigating: false
    property bool hovered: notchHovered || isNavigating

    // Índice actual para navegación
    property int currentIndex: 0
    // Contador para detectar cuando se añaden nuevas notificaciones
    property int lastNotificationCount: 0
    // Contador para forzar actualización del timestamp (incrementa cada minuto)
    property int timestampUpdateCounter: 0

    // Timer para forzar actualización del timestamp cada minuto
    // Solo corre cuando el componente es visible y hay notificaciones
    Timer {
        id: timestampUpdateTimer
        interval: 60000 // 1 minuto
        repeat: true
        running: root.visible && currentNotification !== null
        triggeredOnStart: false
        onTriggered: {
            // Incrementar contador para forzar re-evaluación del binding del timestamp
            root.timestampUpdateCounter++;
        }
    }

    // MouseArea para scroll y middle-click
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: false
        acceptedButtons: Qt.MiddleButton
        propagateComposedEvents: true
        z: 50

        // Navegación con rueda del ratón cuando hay múltiples notificaciones
        onWheel: wheel => {
            if (Notifications.popupList.length > 1) {
                if (wheel.angleDelta.y > 0) {
                    // Scroll hacia arriba - ir a la notificación anterior
                    navigateToPrevious();
                } else {
                    // Scroll hacia abajo - ir a la siguiente notificación
                    navigateToNext();
                }
            }
        }

        // Middle-click para descartar notificación
        onPressed: mouse => {
            if (mouse.button === Qt.MiddleButton && currentNotification) {
                if (Notifications.popupList.length > 1) {
                    root.isNavigating = true;
                    navigationHoverTimer.restart();
                }
                Notifications.discardNotification(currentNotification.id);
            }
            mouse.accepted = false;
        }
    }

    // Timer para mantener hover durante navegación
    Timer {
        id: navigationHoverTimer
        interval: Config.animDuration + 50
        repeat: false
        onTriggered: {
            root.isNavigating = false;
        }
    }

    // Funciones de navegación
    function navigateToNext() {
        if (Notifications.popupList.length > 1) {
            root.isNavigating = true;
            navigationHoverTimer.restart();
            const nextIndex = (currentIndex + 1) % Notifications.popupList.length;
            notificationStack.navigateToNotification(nextIndex);
        }
    }

    function navigateToPrevious() {
        if (Notifications.popupList.length > 1) {
            root.isNavigating = true;
            navigationHoverTimer.restart();
            const prevIndex = currentIndex > 0 ? currentIndex - 1 : Notifications.popupList.length - 1;
            notificationStack.navigateToNotification(prevIndex);
        }
    }

    function updateNotificationStack() {
        if (Notifications.popupList.length > 0 && notificationStack) {
            notificationStack.navigateToNotification(currentIndex);
        }
    }

    // Manejo del hover - pausa/reanuda timers de timeout de todas las notificaciones
    onHoveredChanged: {
        if (hovered) {
            // Pausar todos los timers de notificaciones activas
            Notifications.pauseAllTimers();
        } else {
            // Reanudar todos los timers de notificaciones activas
            Notifications.resumeAllTimers();
        }
    }

    // Sincronizar estado cuando el componente cambia de visibilidad
    onVisibleChanged: {
        if (visible && Notifications.popupList.length > 0) {
            // Ajustar índice si está fuera de rango
            if (currentIndex >= Notifications.popupList.length) {
                currentIndex = Math.max(0, Notifications.popupList.length - 1);
            }
            lastNotificationCount = Notifications.popupList.length;
            // Actualizar el stack si es necesario
            if (notificationStack.depth === 0) {
                notificationStack.push(notificationComponent, {
                    "notification": Notifications.popupList[currentIndex]
                });
            }
        } else if (!visible) {
            // Limpiar el stack cuando se oculta para evitar acumulación
            // Usar clear(StackView.Immediate) para evitar animaciones pendientes
            if (notificationStack.depth > 0) {
                notificationStack.clear(StackView.Immediate);
            }
            // Resetear contadores
            timestampUpdateCounter = 0;
        }
    }

    Column {
        id: mainColumn
        anchors.fill: parent
        spacing: 0

        // ÁREA DE CONTENIDO CON SCROLL: Combina contenido y botones de acción
        RowLayout {
            id: contentWithScrollArea
            width: parent.width
            implicitHeight: notificationStack.implicitHeight
            height: implicitHeight
            spacing: 8

            // Área principal de notificaciones (StackView)
            Item {
                id: notificationArea
                Layout.fillWidth: true
                Layout.preferredHeight: notificationStack.implicitHeight

                StackView {
                    id: notificationStack
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    implicitHeight: currentItem ? currentItem.implicitHeight : 0
                    height: implicitHeight
                    clip: true

                    // Crear componente inicial
                    Component.onCompleted: {
                        if (Notifications.popupList.length > 0) {
                            push(notificationComponent, {
                                "notification": Notifications.popupList[0]
                            });
                        }
                    }

                    // Función para navegar a una notificación específica
                    function navigateToNotification(index, forceDirection = null) {
                        if (index >= 0 && index < Notifications.popupList.length) {
                            const newNotification = Notifications.popupList[index];
                            const currentItem = notificationStack.currentItem;

                            if (!currentItem || !currentItem.notification || currentItem.notification.id !== newNotification.id) {

                                // Determinar dirección de la transición
                                let direction;
                                if (forceDirection !== null) {
                                    direction = forceDirection;
                                } else {
                                    direction = index > root.currentIndex ? StackView.PushTransition : StackView.PopTransition;
                                }

                                // Usar replace para evitar acumulación en el stack
                                replace(notificationComponent, {
                                    "notification": newNotification
                                }, direction);

                                root.currentIndex = index;
                            }
                        }
                    }

                    // Actualizar cuando cambie la lista de notificaciones
                    // Solo activo cuando el componente es visible para evitar trabajo duplicado
                    Connections {
                        target: root.visible ? Notifications : null
                        function onPopupListChanged() {
                            if (Notifications.popupList.length === 0) {
                                notificationStack.clear();
                                root.currentIndex = 0;
                                root.lastNotificationCount = 0;
                                return;
                            }

                            // Si no hay items en el stack, añadir la primera notificación
                            if (notificationStack.depth === 0) {
                                notificationStack.push(notificationComponent, {
                                    "notification": Notifications.popupList[0]
                                });
                                root.currentIndex = 0;
                                root.lastNotificationCount = Notifications.popupList.length;
                                return;
                            }

                            // Detectar nueva notificación: si la lista creció, ir a la más reciente (última)
                            // Solo si no hay hover para no interrumpir la interacción del usuario
                            if (Notifications.popupList.length > root.lastNotificationCount && !root.hovered) {
                                const newIndex = Notifications.popupList.length - 1;
                                root.currentIndex = newIndex;
                                notificationStack.navigateToNotification(newIndex, StackView.PushTransition);
                                root.lastNotificationCount = Notifications.popupList.length;
                                return;
                            }

                            // Actualizar el contador
                            root.lastNotificationCount = Notifications.popupList.length;

                            // Manejar eliminación de notificaciones
                            // Obtener la notificación actual antes del ajuste
                            const currentNotificationId = notificationStack.currentItem?.notification?.id;
                            const oldIndex = root.currentIndex;

                            // Ajustar el índice si es necesario
                            if (root.currentIndex >= Notifications.popupList.length) {
                                root.currentIndex = Math.max(0, Notifications.popupList.length - 1);
                            }

                            // Determinar si una notificación fue eliminada y calcular la dirección apropiada
                            const newNotification = Notifications.popupList[root.currentIndex];
                            let forceDirection = null;

                            // Si la notificación actual cambió, significa que se eliminó una
                            if (currentNotificationId && newNotification && currentNotificationId !== newNotification.id) {
                                // Si estábamos viendo una notificación posterior y ahora vemos una anterior,
                                // significa que se eliminó una notificación antes de la actual -> transición hacia abajo
                                if (oldIndex > 0 && root.currentIndex < oldIndex) {
                                    forceDirection = StackView.PopTransition; // Aparece desde arriba (hacia abajo)
                                } else
                                // Si se eliminó la notificación actual y vamos a la siguiente
                                if (root.currentIndex === oldIndex) {
                                    forceDirection = StackView.PushTransition; // Aparece desde abajo (hacia arriba)
                                }
                            }

                            // Navegar a la notificación actual con la dirección calculada
                            notificationStack.navigateToNotification(root.currentIndex, forceDirection);
                        }
                    }

                    // Transiciones verticales - igual que el launcher
                    pushEnter: Transition {
                        PropertyAnimation {
                            property: "y"
                            from: notificationStack.height
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
                            to: -notificationStack.height
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
                            from: -notificationStack.height
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
                            to: notificationStack.height
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
                }

                // Componente de notificación reutilizable
                Component {
                    id: notificationComponent

                    Item {
                        width: notificationStack.width
                        implicitHeight: notificationContent.implicitHeight

                        property var notification

                        Column {
                            id: notificationContent
                            width: parent.width
                            spacing: hovered ? 8 : 0

                            Behavior on spacing {
                                enabled: Config.animDuration > 0
                                NumberAnimation {
                                    duration: Config.animDuration
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 1.2
                                }
                            }

                            // Contenido principal de la notificación
                            Item {
                                width: parent.width
                                property int criticalMargins: hovered && notification && notification.urgency == NotificationUrgency.Critical ? 16 : 0
                                implicitHeight: mainContentRow.implicitHeight + (criticalMargins * 2)

                                Behavior on criticalMargins {
                                    enabled: Config.animDuration > 0
                                    NumberAnimation {
                                        duration: Config.animDuration
                                        easing.type: Easing.OutQuart
                                    }
                                }

                                DiagonalStripePattern {
                                    id: notchStripeContainer
                                    anchors.fill: parent
                                    visible: notification && notification.urgency == NotificationUrgency.Critical
                                    radius: Styling.radius(4)
                                    animationRunning: visible
                                }

                                RowLayout {
                                    id: mainContentRow
                                    anchors.fill: parent
                                    anchors.topMargin: parent.criticalMargins
                                    anchors.bottomMargin: parent.criticalMargins
                                    anchors.leftMargin: parent.criticalMargins > 0 ? 8 : 0
                                    anchors.rightMargin: parent.criticalMargins > 0 ? 8 : 0
                                    implicitHeight: Math.max(hovered ? 48 : 32, textContainer.implicitHeight)
                                    spacing: 8

                                    // Contenido principal
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        // App icon
                                        NotificationAppIcon {
                                            id: appIcon
                                            property int iconSize: hovered ? 48 : 32
                                            Layout.preferredWidth: iconSize
                                            Layout.preferredHeight: iconSize
                                            Layout.alignment: Qt.AlignTop
                                            size: iconSize
                                            radius: Styling.radius(4)
                                            appIcon: notification ? (notification.cachedAppIcon || notification.appIcon) : ""
                                            image: notification ? (notification.cachedImage || notification.image) : ""
                                            summary: notification ? notification.summary : ""
                                            urgency: notification ? notification.urgency : NotificationUrgency.Normal

                                            Behavior on iconSize {
                                                enabled: Config.animDuration > 0
                                                NumberAnimation {
                                                    duration: Config.animDuration
                                                    easing.type: Easing.OutQuart
                                                }
                                            }
                                        }

                                        // Textos de la notificación
                                        Item {
                                            id: textContainer
                                            Layout.fillWidth: true
                                            implicitHeight: hovered ? textColumnExpanded.implicitHeight : textRowCollapsed.implicitHeight

                                            Column {
                                                id: textColumnExpanded
                                                width: parent.width
                                                spacing: 4
                                                visible: hovered

                                                // Fila del summary, app name y timestamp
                                                RowLayout {
                                                    width: parent.width
                                                    spacing: 4

                                                    // Contenedor izquierdo para summary y app name
                                                    Row {
                                                        id: leftTextsContainer
                                                        Layout.fillWidth: true
                                                        Layout.minimumWidth: 0
                                                        spacing: 4

                                                        Text {
                                                            id: summaryText
                                                            property real combinedImplicitWidth: implicitWidth + (appNameText.visible ? appNameText.implicitWidth + parent.spacing : 0)
                                                            width: {
                                                                if (combinedImplicitWidth <= leftTextsContainer.width) {
                                                                    return implicitWidth;
                                                                }
                                                                return leftTextsContainer.width - (appNameText.visible ? appNameText.width + parent.spacing : 0);
                                                            }
                                                            text: notification ? notification.summary : ""
                                                            font.family: Config.theme.font
                                                            font.pixelSize: Config.theme.fontSize
                                                            font.weight: Font.Bold
                                                            font.underline: notification && notification.urgency == NotificationUrgency.Critical && hovered
                                                            color: notification && notification.urgency == NotificationUrgency.Critical ? Colors.criticalText : Styling.srItem("overprimary")
                                                            elide: Text.ElideRight
                                                            maximumLineCount: 1
                                                            wrapMode: Text.NoWrap
                                                            verticalAlignment: Text.AlignVCenter
                                                        }

                                                        Text {
                                                            id: appNameText
                                                            property real availableWidth: leftTextsContainer.width - summaryText.implicitWidth - (visible ? parent.spacing : 0)
                                                            width: {
                                                                if (summaryText.combinedImplicitWidth <= leftTextsContainer.width) {
                                                                    return implicitWidth;
                                                                }
                                                                return Math.min(implicitWidth, Math.max(60, availableWidth, leftTextsContainer.width * 0.3));
                                                            }
                                                            text: notification ? "• " + notification.appName : ""
                                                            font.family: Config.theme.font
                                                            font.pixelSize: Config.theme.fontSize
                                                            font.weight: Font.Bold
                                                            color: notification && notification.urgency == NotificationUrgency.Critical ? Colors.criticalText : Colors.outline
                                                            elide: Text.ElideRight
                                                            maximumLineCount: 1
                                                            wrapMode: Text.NoWrap
                                                            verticalAlignment: Text.AlignVCenter
                                                            visible: text !== ""
                                                        }
                                                    }

                                                    // Timestamp a la derecha
                                                    Text {
                                                        id: timestampText
                                                        // Usar timestampUpdateCounter para forzar re-evaluación cada minuto
                                                        text: notification ? (root.timestampUpdateCounter, NotificationUtils.getFriendlyNotifTimeString(notification.time)) : ""
                                                        font.family: Config.theme.font
                                                        font.pixelSize: Config.theme.fontSize
                                                        font.weight: Font.Bold
                                                        color: notification && notification.urgency == NotificationUrgency.Critical ? Colors.criticalText : Colors.outline
                                                        verticalAlignment: Text.AlignVCenter
                                                        visible: text !== ""
                                                    }
                                                }

                                                Text {
                                                    width: parent.width
                                                    text: notification ? processNotificationBody(notification.body, notification.appName) : ""
                                                    font.family: Config.theme.font
                                                    font.pixelSize: Config.theme.fontSize
                                                    font.weight: notification && notification.urgency == NotificationUrgency.Critical ? Font.Bold : Font.Normal
                                                    color: notification && notification.urgency == NotificationUrgency.Critical ? Colors.criticalText : Colors.overBackground
                                                    wrapMode: Text.Wrap
                                                    maximumLineCount: 3
                                                    elide: Text.ElideRight
                                                    visible: text !== ""
                                                }
                                            }

                                            Row {
                                                id: textRowCollapsed
                                                width: parent.width
                                                spacing: 4
                                                visible: !hovered

                                                Text {
                                                    id: summaryCollapsed
                                                    property real combinedImplicitWidth: implicitWidth + (bodyCollapsed.visible ? bodyCollapsed.implicitWidth + bulletCollapsed.implicitWidth + parent.spacing * 2 : 0)
                                                    width: {
                                                        if (combinedImplicitWidth <= parent.width) {
                                                            return implicitWidth;
                                                        }
                                                        return parent.width - (bodyCollapsed.visible ? bodyCollapsed.width + bulletCollapsed.width + parent.spacing * 2 : 0);
                                                    }
                                                    text: notification ? notification.summary : ""
                                                    font.family: Config.theme.font
                                                    font.pixelSize: Config.theme.fontSize
                                                    font.weight: Font.Bold
                                                    color: notification && notification.urgency == NotificationUrgency.Critical ? Colors.criticalText : Styling.srItem("overprimary")
                                                    elide: Text.ElideRight
                                                    maximumLineCount: 1
                                                    wrapMode: Text.NoWrap
                                                    verticalAlignment: Text.AlignVCenter
                                                }

                                                Text {
                                                    id: bulletCollapsed
                                                    text: "•"
                                                    font.family: Config.theme.font
                                                    font.pixelSize: Config.theme.fontSize
                                                    font.weight: Font.Bold
                                                    color: notification && notification.urgency == NotificationUrgency.Critical ? Colors.criticalText : Colors.outline
                                                    verticalAlignment: Text.AlignVCenter
                                                    visible: notification && notification.body && notification.body.length > 0
                                                }

                                                Text {
                                                    id: bodyCollapsed
                                                    property real availableWidth: parent.width - summaryCollapsed.implicitWidth - (visible ? bulletCollapsed.implicitWidth + parent.spacing * 2 : 0)
                                                    width: {
                                                        if (summaryCollapsed.combinedImplicitWidth <= parent.width) {
                                                            return implicitWidth;
                                                        }
                                                        return Math.min(implicitWidth, Math.max(60, availableWidth, parent.width * 0.3));
                                                    }
                                                    text: notification ? processNotificationBody(notification.body || "").replace(/\n/g, ' ') : ""
                                                    font.family: Config.theme.font
                                                    font.pixelSize: Config.theme.fontSize
                                                    font.weight: notification && notification.urgency == NotificationUrgency.Critical ? Font.Bold : Font.Normal
                                                    color: notification && notification.urgency == NotificationUrgency.Critical ? Colors.criticalText : Colors.overBackground
                                                    wrapMode: Text.NoWrap
                                                    elide: Text.ElideRight
                                                    maximumLineCount: 1
                                                    verticalAlignment: Text.AlignVCenter
                                                    visible: text.length > 0
                                                }
                                            }
                                        }
                                    }

                                    // Botón de descartar
                                    Item {
                                        property int buttonSize: hovered ? 24 : 0
                                        Layout.preferredWidth: buttonSize
                                        Layout.preferredHeight: buttonSize
                                        Layout.alignment: Qt.AlignTop
                                        z: 200

                                        Behavior on buttonSize {
                                            enabled: Config.animDuration > 0
                                            NumberAnimation {
                                                duration: Config.animDuration
                                                easing.type: Easing.OutQuart
                                            }
                                        }

                                        Loader {
                                            anchors.fill: parent
                                            active: hovered

                                            sourceComponent: Button {
                                                id: dismissButton
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                z: 200

                                                background: Item {
                                                    id: notchDismissBg
                                                    property color iconColor: notification && notification.urgency == NotificationUrgency.Critical ? Colors.shadow : (dismissButton.pressed ? Colors.overError : Colors.error)

                                                    Rectangle {
                                                        anchors.fill: parent
                                                        visible: notification && notification.urgency == NotificationUrgency.Critical
                                                        color: parent.parent.hovered ? Qt.lighter(Colors.criticalRed, 1.3) : Colors.criticalRed
                                                        radius: Styling.radius(4)

                                                        Behavior on color {
                                                            enabled: Config.animDuration > 0
                                                            ColorAnimation {
                                                                duration: Config.animDuration
                                                            }
                                                        }
                                                    }

                                                    StyledRect {
                                                        id: notchDismissStyled
                                                        anchors.fill: parent
                                                        visible: !(notification && notification.urgency == NotificationUrgency.Critical)
                                                        variant: parent.parent.pressed ? "error" : (parent.parent.hovered ? "focus" : "common")
                                                        radius: Styling.radius(4)
                                                    }
                                                }

                                                contentItem: Text {
                                                    text: Icons.cancel
                                                    textFormat: Text.RichText
                                                    font.family: Icons.font
                                                    font.pixelSize: 16
                                                    color: notchDismissBg.iconColor
                                                    horizontalAlignment: Text.AlignHCenter
                                                    verticalAlignment: Text.AlignVCenter
                                                }

                                                onClicked: {
                                                    if (notification) {
                                                        Notifications.discardNotification(notification.id);
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Botones de acción (solo visible con hover)
                            Item {
                                id: actionButtonsRow
                                width: parent.width
                                implicitHeight: (hovered && notification && notification.actions.length > 0 && !notification.isCached) ? 32 : 0
                                height: implicitHeight
                                visible: implicitHeight > 0
                                clip: true
                                z: 200

                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 4

                                    Repeater {
                                        model: notification ? notification.actions : []

                                        Button {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 32
                                            z: 200

                                            text: modelData.text
                                            font.family: Config.theme.font
                                            font.pixelSize: Config.theme.fontSize
                                            font.weight: Font.Bold
                                            hoverEnabled: true

                                            background: Item {
                                                id: notchActionBg
                                                property color textColor: notification && notification.urgency == NotificationUrgency.Critical ? Colors.shadow : notchActionStyled.item

                                                Rectangle {
                                                    anchors.fill: parent
                                                    visible: notification && notification.urgency == NotificationUrgency.Critical
                                                    color: parent.parent.hovered ? Qt.lighter(Colors.criticalRed, 1.3) : Colors.criticalRed
                                                    radius: Styling.radius(4)

                                                    Behavior on color {
                                                        enabled: Config.animDuration > 0
                                                        ColorAnimation {
                                                            duration: Config.animDuration
                                                        }
                                                    }
                                                }

                                                StyledRect {
                                                    id: notchActionStyled
                                                    anchors.fill: parent
                                                    visible: !(notification && notification.urgency == NotificationUrgency.Critical)
                                                    variant: parent.parent.pressed ? "primary" : (parent.parent.hovered ? "focus" : "common")
                                                    radius: Styling.radius(4)
                                                }
                                            }

                                            contentItem: Text {
                                                text: parent.text
                                                font: parent.font
                                                color: notchActionBg.textColor
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                                elide: Text.ElideRight
                                            }

                                            onClicked: {
                                                Notifications.attemptInvokeAction(notification.id, modelData.identifier);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Indicadores de navegación (solo visible con múltiples notificaciones)
            Item {
                id: pageIndicators
                Layout.preferredWidth: (Notifications.popupList.length > 1) ? 8 : 0
                Layout.preferredHeight: 32
                Layout.alignment: Qt.AlignVCenter
                visible: Notifications.popupList.length > 1
                clip: true

                Behavior on Layout.preferredWidth {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                }

                Column {
                    id: dotsColumn
                    width: parent.width
                    spacing: 4

                    // Posición Y animada para el efecto de scroll
                    y: {
                        if (Notifications.popupList.length <= 3)
                            return 0;

                        const totalNotifications = Notifications.popupList.length;
                        const dotHeight = 8 + 4; // altura del punto + spacing
                        const maxY = -(totalNotifications - 3) * dotHeight;
                        const currentIndex = root.currentIndex;

                        // Calcular posición basada en el índice actual
                        let targetY = 0;
                        if (currentIndex >= 1 && currentIndex < totalNotifications - 1) {
                            // Centrar en el punto actual (mantener en posición media)
                            targetY = -(currentIndex - 1) * dotHeight;
                        } else if (currentIndex >= totalNotifications - 1) {
                            // Al final, mostrar los últimos 3
                            targetY = maxY;
                        }

                        return Math.max(maxY, Math.min(0, targetY));
                    }

                    Behavior on y {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutCubic
                        }
                    }

                    Repeater {
                        model: Notifications.popupList.length

                        Rectangle {
                            width: 8
                            height: 8
                            radius: 4
                            property bool isCritical: Notifications.popupList[index] && Notifications.popupList[index].urgency == NotificationUrgency.Critical
                            color: isCritical ? Colors.criticalRed : (index === root.currentIndex ? Styling.srItem("overprimary") : Colors.surfaceBright)

                            Behavior on color {
                                enabled: Config.animDuration > 0
                                ColorAnimation {
                                    duration: Config.animDuration
                                    easing.type: Easing.OutCubic
                                }
                            }

                            // Animación de escala para el punto activo
                            scale: index === root.currentIndex ? 1.0 : 0.5

                            Behavior on scale {
                                enabled: Config.animDuration > 0
                                NumberAnimation {
                                    duration: Config.animDuration
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Función auxiliar para procesar el cuerpo de la notificación
    function processNotificationBody(body, appName) {
        if (!body)
            return "";

        let processedBody = body;

        // Limpiar notificaciones de navegadores basados en Chromium
        if (appName) {
            const lowerApp = appName.toLowerCase();
            const chromiumBrowsers = ["brave", "chrome", "chromium", "vivaldi", "opera", "microsoft edge"];

            if (chromiumBrowsers.some(name => lowerApp.includes(name))) {
                const lines = body.split('\n\n');

                if (lines.length > 1 && lines[0].startsWith('<a')) {
                    processedBody = lines.slice(1).join('\n\n');
                }
            }
        }

        // No reemplazar saltos de línea con espacios
        return processedBody;
    }
}
