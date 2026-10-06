pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications
import qs.modules.services

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
        property int historyPriority: 0
        property string replaceKey: ""
        property var localActionHandlers: ({})
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
                    root.cacheImage(appIcon, function (cachedData) {
                        cachedAppIcon = cachedData;
                        root.scheduleCacheSave();
                    });
                }
                if (image && !image.startsWith("data:")) {
                    root.cacheImage(image, function (cachedData) {
                        cachedImage = cachedData;
                        root.scheduleCacheSave();
                    });
                }

                // Escuchar cuando la notificación es cerrada por la aplicación
                notification.closed.connect(function (reason) {
                    // CloseRequested = 3: la aplicación solicitó cerrar la notificación
                    if (reason === 3) {
                        root.discardNotification(id);
                    }
                });
            }
        }

        Component.onDestruction: {
            if (timer) {
                timer.stop();
                timer.destroy();
                timer = null;
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
            "historyPriority": notif.historyPriority,
            "replaceKey": notif.replaceKey,
            "cachedAppIcon": notif.cachedAppIcon,
            "cachedImage": notif.cachedImage,
            "isCached": notif.isCached
        };
    }

    component NotifTimer: Timer {
        required property int id
        property bool isPaused: false
        property real startTime: Date.now()

        property var suspendConnections: Connections {
            target: SuspendManager
            function onWakingUp() {
                if (!isPaused) {
                    // Small delay after wake to prevent popups appearing while screen is still transitioning
                    wakeStartTimer.restart();
                }
            }
        }

        property var wakeStartTimer: Timer {
            id: wakeStartTimer
            interval: 1000
            repeat: false
            onTriggered: if (!isPaused)
                parent.start()
        }

        running: !isPaused && !SuspendManager.isSuspending && interval > 0
        onTriggered: root.timeoutNotification(id)

        function pause() {
            isPaused = true;
            stop();
        }

        function resume() {
            isPaused = false;
            if (!SuspendManager.isSuspending && interval > 0) {
                start();
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
        // QUICKSHELL-GIT: path: Quickshell.cachePath("notifications.json")
        path: Quickshell.env("HOME") + "/.cache/ambxst/notifications.json"
        onLoaded: loadNotifications()
    }

    function stringifyList(list) {
        return JSON.stringify(list.map(notif => notifToJSON(notif)), null, 2);
    }

    function jsonToNotif(json) {
        return notifComponent.createObject(root, {
            "id": json.id,
            "actions": json.actions,
            "appIcon": json.cachedAppIcon || json.appIcon  // Usar cached si disponible
            ,
            "appName": json.appName,
            "body": json.body,
            "image": json.cachedImage || json.image  // Usar cached si disponible
            ,
            "summary": json.summary,
            "time": json.time,
            "urgency": json.urgency,
            "historyPriority": json.historyPriority || 0,
            "replaceKey": json.replaceKey || "",
            "cachedAppIcon": json.cachedAppIcon || "",
            "cachedImage": json.cachedImage || "",
            "isCached": json.isCached || true  // Default to true for loaded notifications
            ,
            "popup": false  // No popup para notificaciones cargadas
        });
    }

    function saveNotifications() {
        // Limitar notificaciones almacenadas a 5 por summary para evitar almacenamiento excesivo
        const limitedList = limitNotificationsPerSummary(root.list);
        notifFileView.setText(stringifyList(limitedList));
    }

    function limitNotificationsPerSummary(notifications) {
        var groups = {};

        notifications.forEach(notif => {
            const key = notif.appName + '|' + (notif.summary || '');
            if (!groups[key]) {
                groups[key] = [];
            }
            groups[key].push(notif);
        });

        const limitedNotifications = [];
        for (const key in groups) {
            const group = groups[key];
            group.sort((a, b) => b.time - a.time);
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
                if (notif.id > maxId)
                    maxId = notif.id;
                if (notif.id <= -1000000)
                    root.internalIdCounter = Math.max(root.internalIdCounter, Math.abs(notif.id) - 999999);
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
            if (groups[b].historyPriority !== groups[a].historyPriority) {
                return groups[b].historyPriority - groups[a].historyPriority;
            }
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
                    historyPriority: 0,
                    totalCount: 0  // Conteo independiente del almacenamiento
                };
            }
            groups[notif.appName].notifications.push(notif);
            groups[notif.appName].totalCount++;
            // Always set to the latest time in the group
            groups[notif.appName].time = latestTimeForApp[notif.appName] || notif.time;
            groups[notif.appName].historyPriority = Math.max(groups[notif.appName].historyPriority || 0, notif.historyPriority || 0);
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
    property int internalIdCounter: 1
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

    function notifyInternal(options) {
        if (!options || (!options.summary && !options.body)) {
            return null;
        }

        if (options.replaceKey) {
            const existingIds = root.list.filter(notif => notif && notif.replaceKey === options.replaceKey).map(notif => notif.id);
            if (existingIds.length > 0) {
                root.discardNotifications(existingIds);
            }
        }

        const notificationId = -1000000 - root.internalIdCounter++;
        const newNotifObject = notifComponent.createObject(root, {
            "id": notificationId,
            "actions": options.actions || [],
            "appIcon": options.appIcon || "",
            "appName": options.appName || "Ambxst",
            "body": options.body || "",
            "image": options.image || "",
            "summary": options.summary || "",
            "time": options.time || Date.now(),
            "urgency": options.urgency || NotificationUrgency.Normal,
            "historyPriority": options.historyPriority || 0,
            "replaceKey": options.replaceKey || "",
            "localActionHandlers": options.actionHandlers || {},
            "popup": !root.popupInhibited && options.popup !== false,
            "isCached": false
        });

        if (newNotifObject.popup) {
            newNotifObject.timer = notifTimerComponent.createObject(root, {
                "id": newNotifObject.id,
                "interval": options.expireTimeout || 5000
            });
        }

        root.list = [...root.list, newNotifObject];
        saveNotifications();
        root.notify(newNotifObject);
        return newNotifObject;
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
        if (!ids || ids.length === 0)
            return;

        var idsMap = {};
        ids.forEach(id => {
            idsMap[id] = true;
        });

        const newList = root.list.filter(notif => !idsMap[notif.id]);
        const removedCount = root.list.length - newList.length;

        if (removedCount > 0) {
            root.list = newList;
            triggerListChange();
            saveNotifications();
        }

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

    Timer {
        id: timeoutAnimationTimer
        interval: 350
        running: false
        repeat: false
        property int notificationId: -1
        onTriggered: {
            const index = root.list.findIndex(notif => notif.id === notificationId);
            if (index !== -1 && root.list[index] != null)
                root.list[index].popup = false;
            root.timeout(notificationId);
        }
    }

    function timeoutNotification(id) {
        root.timeoutWithAnimation(id);
        timeoutAnimationTimer.notificationId = id;
        timeoutAnimationTimer.restart();
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
        const notifIndex = root.list.findIndex(notif => notif.id === id);
        if (notifIndex !== -1) {
            const localHandlers = root.list[notifIndex].localActionHandlers || {};
            const localHandler = localHandlers[notifIdentifier];
            if (typeof localHandler === "function") {
                localHandler(id);
            }
        }

        const notifServerIndex = notifServer.trackedNotifications.values.findIndex(notif => notif.id + root.idOffset === id);
        if (notifServerIndex !== -1) {
            const notifServerNotif = notifServer.trackedNotifications.values[notifServerIndex];
            const action = notifServerNotif.actions.find(action => action.identifier === notifIdentifier);
            if (action) {
                action.invoke();
            }
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

    // cacheImage materializes a notification image into the daemon's
    // hash-keyed disk cache and returns a stable file path that survives
    // shell reloads. Falls back to the original source on any failure.
    //
    // Sources come in three flavors:
    //   - data: URIs        → passed straight to the daemon
    //   - image:// URLs     → Quickshell's in-process image provider
    //     (raw image_data D-Bus hints land here). The daemon can't
    //     resolve these, so we render + grab to a temp file and let the
    //     daemon persist it as a blob.
    //   - http(s) / file:// / local paths → sent to the daemon as-is
    function cacheImage(imageUrl, callback) {
        if (!imageUrl || imageUrl.startsWith("data:")) {
            callback(imageUrl);
            return;
        }

        if (imageUrl.startsWith("image://")) {
            cacheProviderImage(imageUrl, function (tmpPath) {
                if (!tmpPath) {
                    console.warn("Notifications: provider image cache job failed:", imageUrl);
                    callback(imageUrl);
                    return;
                }
                BackendService.call("notify.cacheImage", {url: tmpPath}, function (result, error) {
                    if (!result?.path) {
                        console.warn("Notifications: daemon cacheImage failed:", error ?? "no path");
                        callback(imageUrl);
                        return;
                    }
                    const path = result.path.startsWith("/") ? "file://" + result.path : result.path;
                    callback(path);
                });
            });
            return;
        }

        const isRemote = imageUrl.startsWith("http://") || imageUrl.startsWith("https://");
        const isLocal = imageUrl.startsWith("file://") || imageUrl.startsWith("/");
        if (!isRemote && !isLocal) {
            callback(imageUrl);
            return;
        }

        BackendService.call("notify.cacheImage", {url: imageUrl}, function (result, error) {
            if (!result?.path) {
                callback(imageUrl);
                return;
            }
            const path = result.path.startsWith("/") ? "file://" + result.path : result.path;
            callback(path);
        });
    }

    // Caching runs at most twice per notification (icon + image); debounce
    // the resulting disk writes instead of saving on every callback.
    Timer {
        id: cacheSaveTimer
        interval: 1000
        onTriggered: root.saveNotifications()
    }

    function scheduleCacheSave() {
        cacheSaveTimer.restart();
    }

    // ---- Image cache plumbing -------------------------------------------
    // Provider-backed images (image://, produced from raw D-Bus image_data
    // hints) can only be resolved by rendering them inside a scene, and
    // this singleton has none. A small transparent layer surface hosts the
    // render jobs; it reserves no exclusive zone and accepts no input.
    //
    // The scene only produces frames while the frame-pump animation runs,
    // which is required for grabToImage to capture actual pixels. Canvas
    // drawImage is not an alternative: it rasterizes provider images blank.

    property var cacheWindow: null
    property int activeCacheJobs: 0
    property int cacheJobCounter: 0

    Component {
        id: cacheWindowComponent

        PanelWindow {
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            visible: true
            implicitWidth: 512
            implicitHeight: 512
            mask: Region {
                item: null
            }
            anchors {
                top: true
                left: true
            }
            WlrLayershell.namespace: "ambxst:notification-cache"

            Rectangle {
                width: 1
                height: 1
                color: "transparent"
                visible: root.activeCacheJobs > 0
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    NumberAnimation {
                        to: 0
                        duration: 16
                    }
                    NumberAnimation {
                        to: 1
                        duration: 16
                    }
                    running: root.activeCacheJobs > 0
                }
            }
        }
    }

    Component {
        id: imageCacheJob

        Item {
            id: job

            required property string imageUrl
            required property var callback
            readonly property int maxSize: 512
            property bool done: false

            width: 1
            height: 1

            Component.onCompleted: root.activeCacheJobs++
            Component.onDestruction: root.activeCacheJobs--

            Image {
                id: img
                anchors.fill: parent
                source: job.imageUrl
                asynchronous: true
                cache: false

                onStatusChanged: {
                    if (status === Image.Ready)
                        job.setup();
                    else if (status === Image.Error)
                        job.finish(null);
                }
            }

            Timer {
                id: settleTimer
                interval: 150
                onTriggered: job.grab()
            }

            function setup() {
                const iw = img.implicitWidth;
                const ih = img.implicitHeight;
                if (iw <= 0 || ih <= 0) {
                    finish(null);
                    return;
                }
                const scale = Math.min(1, maxSize / Math.max(iw, ih));
                width = Math.max(1, Math.round(iw * scale));
                height = Math.max(1, Math.round(ih * scale));
                img.width = width;
                img.height = height;
                // Let the scene render the image texture before grabbing.
                settleTimer.restart();
            }

            function grab() {
                if (done)
                    return;
                done = true;
                const tmpPath = root.cacheTmpPath();
                grabToImage(result => {
                    if (!result || !result.image || !result.saveToFile(tmpPath)) {
                        console.warn("Notifications: grabToImage failed for", job.imageUrl);
                        finish(null);
                        return;
                    }
                    finish(tmpPath);
                });
            }

            function finish(result) {
                const cb = callback;
                destroy();
                if (cb)
                    cb(result);
            }
        }
    }

    function cacheTmpPath() {
        return "/tmp/ambxst-notif-cache-" + root.cacheJobCounter++ + ".png";
    }

    function cacheProviderImage(imageUrl, callback) {
        if (!root.cacheWindow)
            root.cacheWindow = cacheWindowComponent.createObject(root);
        imageCacheJob.createObject(root.cacheWindow.contentItem, {
            "imageUrl": imageUrl,
            "callback": callback
        });
    }

    Component.onCompleted: {
        // Defer notification history reload to not block boot.
        // The DBus notification server is registered above and live notifications work.
        notifDeferTimer.start();

        // Subscribe to the notify IPC service so external CLI commands
        // (colorpicker, screen, …) can route their notifications through
        // this singleton instead of shelling out to notify-send. Without
        // this they bypass Ambxst's notification lifecycle and leak into
        // the system daemon — see cmds_colorpicker.go for the originating
        // bug. We register the subscription even if BackendService isn't
        // connected yet; the callback simply won't fire until the socket
        // is up.
        root.notifyIpcHandle = BackendService.addSubscription(
            ["notify"],
            (service, data) => root.handleNotifyRequest(data)
        );

        root.initDone();
    }

    property int notifyIpcHandle: -1

    // handleNotifyRequest converts a CLI-driven notify.send event into a
    // tracked notification. Actions whose source object carries a
    // `clipboard` field get a synthetic handler that copies the value
    // through the daemon (the selection owner) when the user clicks
    // them, so cross-process flows (colorpicker formats) keep working
    // without the CLI blocking on stdin.
    function handleNotifyRequest(data) {
        if (!data) return;
        const rawActions = data.actions || [];
        const actionHandlers = {};
        const actions = [];
        for (let i = 0; i < rawActions.length; i++) {
            const a = rawActions[i];
            if (!a || !a.identifier) continue;
            actions.push({
                identifier: a.identifier,
                text: a.text || a.identifier
            });
            if (a.clipboard !== undefined && a.clipboard !== null) {
                const value = a.clipboard;
                actionHandlers[a.identifier] = function (_id) {
                    BackendService.call("clipboard.copyText", {text: value});
                };
            }
        }

        const opts = {
            summary: data.summary || "",
            body: data.body || "",
            appName: data.appName || "Ambxst",
            appIcon: data.appIcon || "",
            image: data.image || "",
            urgency: data.urgency || "normal",
            expireTimeout: data.expireTimeout || 5000,
            replaceKey: data.replaceKey || "",
            actions: actions,
            actionHandlers: actionHandlers,
            popup: true
        };
        root.notifyInternal(opts);
    }

    Timer {
        id: notifDeferTimer
        interval: 2000
        running: false
        repeat: false
        onTriggered: notifFileView.reload()
    }
}
