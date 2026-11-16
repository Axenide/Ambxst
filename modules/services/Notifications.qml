pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.config
import qs.modules.services

Singleton {
    id: root

    component Notif: QtObject {
        required property int id
        property var notification: null
        property var actions: []
        property bool popup: false
        property string appIcon: ""
        property string appName: ""
        property string body: ""
        property string image: ""
        property string summary: ""
        property double time: 0
        property var urgency: NotificationUrgency.Normal
        property int historyPriority: 0
        property string replaceKey: ""
        property string ownerToken: ""
        property var localActionHandlers: ({})
        property var timer: null
        property var animationTimer: null
        property string cachedAppIcon: ""
        property string cachedImage: ""
        property bool isCached: false
    }

    component NotifTimer: QtObject {
        required property int id

        function pause() {
            root.call("Notification.Pause", {id: id});
        }

        function resume() {
            root.call("Notification.Resume", {id: id});
        }

        function stop() {
            root.call("Notification.Dismiss", {id: id});
        }
    }

    component TimeoutAnimationTimer: Timer {
        required property int notificationId
        interval: Config.animDuration
        repeat: false

        onTriggered: {
            root.finishTimeout(notificationId);
            destroy();
        }
    }

    property bool initialized: false
    property bool silent: false
    property list<Notif> list: []
    readonly property var notifications: list
    readonly property var popupList: list.filter(notification => notification.popup)
    readonly property var popupNotifications: popupList
    readonly property bool popupInhibited: silent
    property var latestTimeForApp: ({})
    property var totalCounts: ({})
    property var pendingActionHandlers: ({})
    property int ownerTokenCounter: 1

    signal initDone
    signal notify(notification: var)
    signal discard(id: var)
    signal discardAll
    signal timeout(id: var)
    signal timeoutWithAnimation(id: var)

    readonly property var groupsByAppName: groupsForList(list)
    readonly property var popupGroupsByAppName: groupsForList(popupList)
    readonly property var appNameList: appNameListForGroups(groupsByAppName)
    readonly property var popupAppNameList: appNameListForGroups(popupGroupsByAppName)

    Component {
        id: notifComponent
        Notif {}
    }

    Component {
        id: notifTimerComponent
        NotifTimer {}
    }

    Component {
        id: timeoutAnimationComponent
        TimeoutAnimationTimer {}
    }

    onSilentChanged: {
        if (initialized)
            root.call("Notification.SetDND", {enabled: silent});
    }

    onListChanged: {
        const latest = {};
        const counts = {};
        for (let i = 0; i < list.length; i++) {
            const notification = list[i];
            if (!notification || !notification.appName) continue;
            latest[notification.appName] = Math.max(latest[notification.appName] || 0, notification.time || 0);
            counts[notification.appName] = (counts[notification.appName] || 0) + 1;
        }
        latestTimeForApp = latest;
        totalCounts = counts;
    }

    Connections {
        target: AxctlBackend

        function onEventReceived(service, data) {
            if (service === "notifications.received") root.handleEvent(data);
            else if (service === "notifications.action") root.handleEvent(data);
            else if (service === "notifications.closed") root.handleEvent(data);
            else if (service === "notifications.deleted") root.handleEvent(data);
            else if (service === "notifications.cleared") root.loadHistory();
            else if (service === "notifications.dnd") root.loadDND();
        }
    }

    function call(method, params, callback) {
        AxctlBackend.call(method, params || {}, callback);
    }

    function urgencyValue(value) {
        if (value === "critical" || value === NotificationUrgency.Critical || value === 2) return NotificationUrgency.Critical;
        if (value === "low" || value === 0) return 0;
        return NotificationUrgency.Normal;
    }

    function appIconPath(icon, callback) {
        if (!icon || icon.startsWith("/") || icon.startsWith("file://") || icon.startsWith("image://") || icon.startsWith("data:")) {
            if (callback) callback(AxctlBackend.imageUrl(icon || ""));
            return;
        }
        AxctlBackend.resolveIcon(icon, 64, path => callback && callback(path || icon));
    }

    function mapNotification(raw, popupOverride, isCached = false) {
        const existing = list.find(notification => notification.id === Number(raw.id));
        const icon = raw.appIcon || "";
        const notification = existing || notifComponent.createObject(root, {id: Number(raw.id)});
        notification.notification = raw;
        notification.actions = raw.actions || [];
        notification.appName = raw.appName || "Unknown";
        notification.body = raw.body || "";
        notification.image = raw.image || "";
        notification.summary = raw.summary || "";
        notification.time = Number(raw.time) || Date.now();
        notification.urgency = urgencyValue(raw.urgency);
        notification.historyPriority = Number(raw.historyPriority) || 0;
        notification.replaceKey = raw.replaceKey || "";
        notification.ownerToken = raw.ownerToken || "";
        notification.localActionHandlers = root.pendingActionHandlers[notification.ownerToken] || notification.localActionHandlers || {};
        notification.popup = popupOverride === undefined ? !!raw.popup : popupOverride;
        if (!notification.timer && notification.popup)
            notification.timer = notifTimerComponent.createObject(root, {id: notification.id});
        if (!notification.popup && notification.timer) {
            notification.timer.destroy();
            notification.timer = null;
        }
        notification.appIcon = icon;
        notification.cachedAppIcon = icon;
        notification.cachedImage = notification.image;
        notification.isCached = isCached;
        root.appIconPath(icon, path => {
            if (notification && notification.id === Number(raw.id)) {
                notification.appIcon = path;
                notification.cachedAppIcon = path;
            }
        });
        return notification;
    }

    function upsert(raw, popupOverride) {
        if (!raw || !raw.id || (!raw.summary && !raw.body)) return null;
        const notification = mapNotification(raw, popupOverride);
        const next = list.slice();
        const index = next.findIndex(item => item.id === notification.id);
        if (index === -1) next.push(notification);
        else next[index] = notification;
        list = next;
        notify(notification);
        return notification;
    }

    function removeFromList(id) {
        const removed = list.find(notification => notification.id === id);
        list = list.filter(notification => notification.id !== id);
        if (removed && removed.ownerToken)
            delete pendingActionHandlers[removed.ownerToken];
        if (removed) Qt.callLater(() => root.destroyNotification(removed));
        discard(id);
    }

    function destroyNotification(notification) {
        if (!notification) return;
        if (notification.timer) notification.timer.destroy();
        if (notification.animationTimer) notification.animationTimer.destroy();
        notification.destroy();
    }

    function handleEvent(event) {
        if (!event) return;
        const notification = event.notification || {};
        const id = Number(notification.id);
        if (event.type === "received") {
            upsert(notification);
            return;
        }
        if (event.type === "action-invoked") {
            const current = list.find(item => item.id === id);
            const handler = current?.localActionHandlers?.[event.actionId];
            if (typeof handler === "function") handler(id);
            return;
        }
        if (event.type === "closed") {
            const current = list.find(item => item.id === id);
            if (current) {
                if (current.timer) current.timer.destroy();
                current.timer = null;
                if (event.reason === 1) {
                    if (current.animationTimer) current.animationTimer.destroy();
                    current.animationTimer = timeoutAnimationComponent.createObject(root, {notificationId: id});
                    current.animationTimer.start();
                } else {
                    current.popup = false;
                    list = list.slice();
                }
            }
            if (event.reason === 1) {
                timeoutWithAnimation(id);
                if (!current) timeout(id);
            } else if (event.reason === 3) {
                call("Notification.Delete", {id: id});
            }
            return;
        }
        if (event.type === "deleted") removeFromList(id);
    }

    function loadHistory() {
        call("Notification.History", {}, (history, error) => {
            if (error) {
                console.warn("Notifications: failed to load axctl history:", error);
                return;
            }
            const next = [];
            for (let i = 0; i < (history || []).length; i++) {
                const raw = history[i];
                const activePopup = list.find(item => item.id === Number(raw.id) && item.popup);
                const notification = activePopup || mapNotification(raw, false, true);
                if (!next.some(item => item.id === notification.id)) next.push(notification);
            }
            const previous = list;
            list = next;
            previous.filter(notification => !next.includes(notification)).forEach(notification => Qt.callLater(() => root.destroyNotification(notification)));
            initDone();
        });
    }

    function loadDND() {
        call("Notification.DND", {}, (result, error) => {
            if (!error) silent = !!result?.enabled;
        });
    }

    function notifyInternal(options) {
        if (!options || (!options.summary && !options.body)) return null;
        const ownerToken = "ambxst-" + Date.now() + "-" + ownerTokenCounter++;
        const handlers = options.actionHandlers || {};
        pendingActionHandlers[ownerToken] = handlers;
        pendingActionHandlers = Object.assign({}, pendingActionHandlers);
        const actions = (options.actions || []).map(action => ({
            identifier: action.identifier || action.id || "",
            text: action.text || action.label || action.identifier || action.id || ""
        })).filter(action => action.identifier);
        const urgency = urgencyValue(options.urgency);
        const request = {
            appName: options.appName || "Ambxst",
            appIcon: options.appIcon || "",
            summary: options.summary || "",
            body: options.body || "",
            image: options.image || "",
            urgency: urgency === NotificationUrgency.Critical ? "critical" : urgency === 0 ? "low" : "normal",
            expireTimeout: Number(options.expireTimeout) > 0 ? Number(options.expireTimeout) : 5000,
            historyPriority: Number(options.historyPriority) || 0,
            replaceKey: options.replaceKey || "",
            ownerToken: ownerToken,
            popup: options.popup !== false,
            actions: actions
        };
        call("Notification.Send", request, (_result, error) => {
            if (error) {
                delete pendingActionHandlers[ownerToken];
                pendingActionHandlers = Object.assign({}, pendingActionHandlers);
                console.warn("Notifications: failed to send notification through axctl:", error);
            }
        });
        return {ownerToken: ownerToken};
    }

    function discardNotification(id) {
		call("Notification.Delete", {id: Number(id)});
    }

    function discardNotifications(ids) {
        for (let i = 0; i < (ids || []).length; i++)
            call("Notification.Delete", {id: Number(ids[i])});
    }

    function discardAllNotifications() {
        const previous = list;
        call("Notification.Clear");
        list = [];
        previous.forEach(notification => Qt.callLater(() => root.destroyNotification(notification)));
        discardAll();
    }

    function attemptInvokeAction(id, identifier, autoDiscard = true) {
        const notification = list.find(item => item.id === Number(id));
        if (!notification) return;
        const handler = notification.localActionHandlers?.[identifier];
        if (typeof handler === "function") {
            handler(Number(id));
            if (autoDiscard) call("Notification.Delete", {id: Number(id)});
            return;
        }
        call("Notification.Action", {id: Number(id), actionId: identifier});
        if (autoDiscard) call("Notification.Delete", {id: Number(id)});
        if (autoDiscard) notification.popup = false;
    }

    function pauseGroupTimers(appName) {
        popupList.filter(notification => notification.appName === appName && notification.timer).forEach(notification => notification.timer.pause());
    }

    function resumeGroupTimers(appName) {
        popupList.filter(notification => notification.appName === appName && notification.timer).forEach(notification => notification.timer.resume());
    }

    function pauseAllTimers() {
        popupList.forEach(notification => notification.timer?.pause());
    }

    function resumeAllTimers() {
        popupList.forEach(notification => notification.timer?.resume());
    }

    function hideAllPopups() {
        const ids = popupList.map(notification => notification.id);
        for (let i = 0; i < ids.length; i++)
            call("Notification.Dismiss", {id: ids[i]});
    }

    function triggerListChange() {
        list = list.slice();
    }

    function timeoutNotification(id) {
        timeoutWithAnimation(id);
        const notification = list.find(item => item.id === Number(id));
        if (!notification) return;
        if (notification.animationTimer) notification.animationTimer.destroy();
        notification.animationTimer = timeoutAnimationComponent.createObject(root, {notificationId: Number(id)});
        notification.animationTimer.start();
    }

    function finishTimeout(id) {
        const notification = list.find(item => item.id === Number(id));
        if (notification) {
            notification.animationTimer = null;
            notification.popup = false;
            list = list.slice();
        }
        timeout(id);
        call("Notification.Dismiss", {id: Number(id)});
    }

    function timeoutAll() {
        popupList.forEach(notification => timeout(notification.id));
        hideAllPopups();
    }

    function appNameListForGroups(groups) {
        return Object.keys(groups).sort((a, b) => {
            if (groups[b].historyPriority !== groups[a].historyPriority)
                return groups[b].historyPriority - groups[a].historyPriority;
            return groups[b].time - groups[a].time;
        });
    }

    function groupsForList(notifications) {
        const groups = {};
        for (let i = 0; i < notifications.length; i++) {
            const notification = notifications[i];
            if (!notification || !notification.appName || (!notification.summary && !notification.body)) continue;
            if (!groups[notification.appName]) {
                groups[notification.appName] = {
                    appName: notification.appName,
                    appIcon: notification.appIcon,
                    notifications: [],
                    time: 0,
                    historyPriority: 0,
                    totalCount: 0
                };
            }
            const group = groups[notification.appName];
            group.notifications.push(notification);
            group.time = Math.max(group.time, notification.time || 0);
            group.historyPriority = Math.max(group.historyPriority, notification.historyPriority || 0);
            group.totalCount++;
        }
        return groups;
    }

    function handleNotifyRequest(data) {
        if (!data) return;
        const actionHandlers = {};
        const actions = [];
        for (let i = 0; i < (data.actions || []).length; i++) {
            const action = data.actions[i];
            if (!action || !action.identifier) continue;
            actions.push({identifier: action.identifier, text: action.text || action.identifier});
            if (action.clipboard !== undefined && action.clipboard !== null) {
                const value = action.clipboard;
                actionHandlers[action.identifier] = function () {
                    BackendService.call("clipboard.copyText", {text: value});
                };
            }
        }
        notifyInternal({
            appName: data.appName || "Ambxst",
            appIcon: data.appIcon || "",
            summary: data.summary || "",
            body: data.body || "",
            image: data.image || "",
            urgency: data.urgency || "normal",
            expireTimeout: Number(data.expireTimeout) > 0 ? Number(data.expireTimeout) : 5000,
            replaceKey: data.replaceKey || "",
            actions: actions,
            actionHandlers: actionHandlers
        });
    }

    property int notifyIpcHandle: -1

    Component.onCompleted: {
        notifyIpcHandle = BackendService.addSubscription(["notify"], (service, data) => {
            if (service === "notify.request") root.handleNotifyRequest(data);
            else if (service === "notify.send") root.handleNotifyRequest(data);
        });
        root.loadHistory();
        root.loadDND();
        root.initialized = true;
    }

    Component.onDestruction: {
        if (notifyIpcHandle >= 0) BackendService.removeSubscription(notifyIpcHandle);
    }
}
