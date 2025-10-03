pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Singleton {
    id: root

    component Notif: QtObject {
        required property int id
        property Notification notification
        property list<var> actions: notification?.actions.map(action => ({
                    "identifier": action.identifier,
                    "text": action.text
                })) ?? []
        property bool popup: false
        // Capturar valores inmediatamente para evitar binding issues
        property string appIcon: ""
        property string appName: ""
        property string body: ""
        property string image: ""
        property string summary: ""
        property double time
        property string urgency: "normal"
        property Timer timer

        // Propiedades para cache de imágenes
        property string cachedAppIcon: ""
        property string cachedImage: ""

        // Indica si esta notificación fue cargada desde cache
        property bool isCached: false

        // Inicializar valores cuando se asigna la notification
        onNotificationChanged: {
            if (notification) {
                appIcon = notification.appIcon ?? "";
                appName = notification.appName ?? "";
                body = notification.body ?? "";
                image = notification.image ?? "";
                summary = notification.summary ?? "";
                urgency = notification.urgency.toString() ?? "normal";

                // Cachear imágenes
                if (appIcon && !appIcon.startsWith("data:")) {
                    root.cacheImageAsBase64(appIcon, function(cachedData) {
                        cachedAppIcon = cachedData;
                    });
                }
                if (image && !image.startsWith("data:")) {
                    root.cacheImageAsBase64(image, function(cachedData) {
                        cachedImage = cachedData;
                    });
                }

                // Escuchar cuando la notificación es cerrada por la aplicación
                notification.closed.connect(function(reason) {
                    // CloseRequested = 3: la aplicación solicitó cerrar la notificación
                    if (reason === 3) {
                        root.discardNotification(id);
                    }
                });
            }
        }
    }

    function notifToJSON(notif) {
        return {
            "id": notif.id,
            "actions": notif.actions,
            "appIcon": notif.appIcon,
            "appName": notif.appName,
            "body": notif.body,
            "image": notif.image,
            "summary": notif.summary,
            "time": notif.time,
            "urgency": notif.urgency,
            "cachedAppIcon": notif.cachedAppIcon,
            "cachedImage": notif.cachedImage,
            "isCached": notif.isCached
        };
    }

    component NotifTimer: Timer {
        required property int id
        property int originalInterval: 5000
        property bool isPaused: false
        property real startTime: Date.now()

        interval: originalInterval
        running: !isPaused

        function pause() {
            if (!isPaused) {
                isPaused = true;
                stop();
            }
        }

        function resume() {
            if (isPaused) {
                isPaused = false;
                interval = originalInterval;
                startTime = Date.now();
                start();
            }
        }

        function triggerTimeout() {
            root.timeoutNotification(id);
            destroy();
        }

        onTriggered: triggerTimeout()

        onRunningChanged: {
            if (running) {
                startTime = Date.now();
            }
        }
    }

    property bool silent: false
    property list<Notif> list: []
    property var popupList: list.filter(notif => notif.popup)
    property bool popupInhibited: silent
    property var latestTimeForApp: ({})
    property var totalCounts: ({})  // Conteo total independiente del almacenamiento: {appName: {summary: count}}

    Component {
        id: notifComponent
        Notif {}
    }
    Component {
        id: notifTimerComponent
        NotifTimer {}
    }

    FileView {
        id: notifFileView
        path: Quickshell.cacheDir + "/notifications.json"
        onLoaded: loadNotifications()
    }

    function stringifyList(list) {
        return JSON.stringify(list.map(notif => notifToJSON(notif)), null, 2);
    }

    function jsonToNotif(json) {
        return notifComponent.createObject(root, {
            "id": json.id,
            "actions": json.actions,
            "appIcon": json.cachedAppIcon || json.appIcon,  // Usar cached si disponible
            "appName": json.appName,
            "body": json.body,
            "image": json.cachedImage || json.image,  // Usar cached si disponible
            "summary": json.summary,
            "time": json.time,
            "urgency": json.urgency,
            "cachedAppIcon": json.cachedAppIcon || "",
            "cachedImage": json.cachedImage || "",
            "isCached": json.isCached || true,  // Default to true for loaded notifications
            "popup": false  // No popup para notificaciones cargadas
        });
    }

    function saveNotifications() {
        // Limitar notificaciones almacenadas a 5 por summary para evitar almacenamiento excesivo
        const limitedList = limitNotificationsPerSummary(root.list);
        notifFileView.setText(stringifyList(limitedList));
    }

    function limitNotificationsPerSummary(notifications) {
        const groups = new Map();
        // Agrupar por appName y summary
        notifications.forEach(notif => {
            const key = notif.appName + '|' + (notif.summary || '');
            if (!groups.has(key)) {
                groups.set(key, []);
            }
            groups.get(key).push(notif);
        });

        // Limitar cada grupo a 5 notificaciones, manteniendo las más recientes
        const limitedNotifications = [];
        for (const group of groups.values()) {
            // Ordenar por tiempo descendente (más recientes primero)
            group.sort((a, b) => b.time - a.time);
            // Tomar solo las primeras 5
            limitedNotifications.push(...group.slice(0, 5));
        }

        return limitedNotifications;
    }

    function loadNotifications() {
        try {
            const data = JSON.parse(notifFileView.text());
            root.list = data.map(jsonToNotif);
            // Set idOffset to max id + 1
            let maxId = 0;
            root.list.forEach(notif => {
                if (notif.id > maxId) maxId = notif.id;
            });
            root.idOffset = maxId + 1;
        } catch (e) {
            console.log("No saved notifications or error loading:", e);
            root.list = [];
            root.idOffset = 0;
        }
    }

    onListChanged: {
        // Update latest time for each app
        root.list.forEach(notif => {
            if (!root.latestTimeForApp[notif.appName] || notif.time > root.latestTimeForApp[notif.appName]) {
                root.latestTimeForApp[notif.appName] = Math.max(root.latestTimeForApp[notif.appName] || 0, notif.time);
            }
        });
        // Remove apps that no longer have notifications
        Object.keys(root.latestTimeForApp).forEach(appName => {
            if (!root.list.some(notif => notif.appName === appName)) {
                delete root.latestTimeForApp[appName];
            }
        });
    }

    function appNameListForGroups(groups) {
        return Object.keys(groups).sort((a, b) => {
            // Sort by time, descending
            return groups[b].time - groups[a].time;
        });
    }

    function groupsForList(list) {
        const groups = {};
        list.forEach((notif, index) => {
            // Verificar que la notificación es válida antes de agruparla
            if (!notif || !notif.appName || (!notif.summary && !notif.body)) {
                return;
            }

            if (!groups[notif.appName]) {
                groups[notif.appName] = {
                    appName: notif.appName,
                    appIcon: notif.appIcon,
                    notifications: [],
                    time: 0,
                    totalCount: 0  // Conteo independiente del almacenamiento
                };
            }
            groups[notif.appName].notifications.push(notif);
            groups[notif.appName].totalCount++;
            // Always set to the latest time in the group
            groups[notif.appName].time = latestTimeForApp[notif.appName] || notif.time;
        });

        return groups;
    }

    property var groupsByAppName: groupsForList(root.list)
    property var popupGroupsByAppName: groupsForList(root.popupList)
    property var appNameList: appNameListForGroups(root.groupsByAppName)
    property var popupAppNameList: appNameListForGroups(root.popupGroupsByAppName)

    // Quickshell's notification IDs starts at 1 on each run, while saved notifications
    // can already contain higher IDs. This is for avoiding id collisions
    property int idOffset
    signal initDone
    signal notify(notification: var)
    signal discard(id: var)
    signal discardAll
    signal timeout(id: var)

    NotificationServer {
        id: notifServer
        actionsSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        bodyMarkupSupported: true
        bodySupported: true
        imageSupported: true
        keepOnReload: false
        persistenceSupported: true

        onNotification: notification => {
            // Verificar que la notificación tiene contenido válido antes de procesarla
            if (!notification || (!notification.summary && !notification.body)) {
                return;
            }
            
            notification.tracked = true;
            const newNotifObject = notifComponent.createObject(root, {
                "id": notification.id + root.idOffset,
                "notification": notification,
                "time": Date.now()
            });

            // Usar Qt.callLater para evitar race conditions al actualizar la lista
            Qt.callLater(() => {
                root.list = [...root.list, newNotifObject];
                saveNotifications();
            });

            // Popup - ahora se muestra en el notch en lugar de popup window
            if (!root.popupInhibited) {
                newNotifObject.popup = true;
                newNotifObject.timer = notifTimerComponent.createObject(root, {
                    "id": newNotifObject.id,
                    "interval": notification.expireTimeout < 0 ? 5000 : notification.expireTimeout // Aumentado para notch
                });
            }

            root.notify(newNotifObject);
        }
    }

    function discardNotification(id) {
        const index = root.list.findIndex(notif => notif.id === id);
        const notifServerIndex = notifServer.trackedNotifications.values.findIndex(notif => notif.id + root.idOffset === id);
        if (index !== -1) {
            root.list.splice(index, 1);
            triggerListChange();
            saveNotifications();
        }
        if (notifServerIndex !== -1) {
            notifServer.trackedNotifications.values[notifServerIndex].dismiss();
        }
        root.discard(id);
    }

    function discardNotifications(ids) {
        if (!ids || ids.length === 0) return;

        // Remover todas las notificaciones de la lista de una vez
        const idsSet = new Set(ids);
        const newList = root.list.filter(notif => !idsSet.has(notif.id));
        const removedCount = root.list.length - newList.length;

        if (removedCount > 0) {
            root.list = newList;
            triggerListChange();
            saveNotifications();
        }

        // Dismiss en el servidor de notificaciones
        ids.forEach(id => {
            const notifServerIndex = notifServer.trackedNotifications.values.findIndex(notif => notif.id + root.idOffset === id);
            if (notifServerIndex !== -1) {
                notifServer.trackedNotifications.values[notifServerIndex].dismiss();
            }
            root.discard(id);
        });
    }

    function discardAllNotifications() {
        root.list = [];
        triggerListChange();
        saveNotifications();
        notifServer.trackedNotifications.values.forEach(notif => {
            notif.dismiss();
        });
        root.discardAll();
    }

    signal timeoutWithAnimation(id: var)

    function timeoutNotification(id) {
        // Primero emitir la señal para que la UI haga animación
        root.timeoutWithAnimation(id);

        // Luego, después de un delay para la animación, quitar del popup
        const timeoutTimer = Qt.createQmlObject(`
            import QtQuick
            Timer {
                interval: 350
                running: true
                repeat: false
                onTriggered: {
                    const index = root.list.findIndex((notif) => notif.id === ${id});
                    if (root.list[index] != null)
                        root.list[index].popup = false;
                    root.timeout(${id});
                    destroy();
                }
            }
        `, root);
    }

    function timeoutAll() {
        root.popupList.forEach(notif => {
            root.timeout(notif.id);
        });
        root.popupList.forEach(notif => {
            notif.popup = false;
        });
    }

    function attemptInvokeAction(id, notifIdentifier, autoDiscard = true) {
        const notifServerIndex = notifServer.trackedNotifications.values.findIndex(notif => notif.id + root.idOffset === id);
        if (notifServerIndex !== -1) {
            const notifServerNotif = notifServer.trackedNotifications.values[notifServerIndex];
            const action = notifServerNotif.actions.find(action => action.identifier === notifIdentifier);
            action.invoke();
        } else {
        }
        if (autoDiscard) {
            root.discardNotification(id);
        }
    }

    function pauseGroupTimers(appName) {
        root.popupList.forEach(notif => {
            if (notif.appName === appName && notif.timer) {
                notif.timer.pause();
            }
        });
    }

    function resumeGroupTimers(appName) {
        root.popupList.forEach(notif => {
            if (notif.appName === appName && notif.timer) {
                notif.timer.resume();
            }
        });
    }

    function pauseAllTimers() {
        root.popupList.forEach(notif => {
            if (notif.timer) {
                notif.timer.pause();
            }
        });
    }

    function resumeAllTimers() {
        root.popupList.forEach(notif => {
            if (notif.timer) {
                notif.timer.resume();
            }
        });
    }

    function hideAllPopups() {
        root.popupList.forEach(notif => {
            notif.popup = false;
            if (notif.timer) {
                notif.timer.stop();
                notif.timer.destroy();
                notif.timer = null;
            }
        });
    }

    function triggerListChange() {
        root.list = root.list.slice(0);
    }

    // Función para cachear imágenes como base64
    function cacheImageAsBase64(imageUrl, callback) {
        if (!imageUrl || imageUrl.startsWith("data:")) {
            callback(imageUrl);
            return;
        }

        // Solo cachear URLs HTTP/HTTPS válidas
        if (!imageUrl.startsWith("http://") && !imageUrl.startsWith("https://")) {
            callback(imageUrl);
            return;
        }

        // Evitar URLs demasiado largas o inválidas
        if (imageUrl.length > 2048) {
            callback(imageUrl);
            return;
        }

        var xhr = new XMLHttpRequest();
        xhr.open("GET", imageUrl, true);
        xhr.responseType = "arraybuffer";
        xhr.timeout = 5000; // 5 segundos timeout

        xhr.onload = function() {
            if (xhr.status === 200 && xhr.response) {
                try {
                    var arrayBuffer = xhr.response;
                    var bytes = new Uint8Array(arrayBuffer);
                    var binary = '';
                    var len = Math.min(bytes.byteLength, 1024 * 1024); // Limitar a 1MB
                    for (var i = 0; i < len; i++) {
                        binary += String.fromCharCode(bytes[i]);
                    }
                    var base64 = btoa(binary);

                    var mimeType = "image/png";
                    var lowerUrl = imageUrl.toLowerCase();
                    if (lowerUrl.includes(".jpg") || lowerUrl.includes(".jpeg")) {
                        mimeType = "image/jpeg";
                    } else if (lowerUrl.includes(".gif")) {
                        mimeType = "image/gif";
                    } else if (lowerUrl.includes(".webp")) {
                        mimeType = "image/webp";
                    }

                    callback("data:" + mimeType + ";base64," + base64);
                } catch (e) {
                    callback(imageUrl);
                }
            } else {
                callback(imageUrl);
            }
        };

        xhr.onerror = function() {
            callback(imageUrl);
        };

        xhr.ontimeout = function() {
            callback(imageUrl);
        };

        xhr.send();
    }

    Component.onCompleted: {
        notifFileView.reload();
        root.initDone();
    }
}
