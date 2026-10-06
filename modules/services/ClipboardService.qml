pragma Singleton
import QtQuick
import Quickshell

QtObject {
    id: root

    property bool active: true
    property var items: []
    property var imageDataById: ({})
    property var imagePathById: ({})
    property var linkPreviewCache: ({})
    property int revision: 0

    property bool _initialized: false
    signal listCompleted()

    // Persistence + watcher live in the Go daemon; we just re-list on
    // its "clipboard.refresh" events.
    property int clipboardWatchHandle: -1
    property bool _watchBound: false

    property var _suspendWatch: Connections {
        target: SuspendManager
        function onPreparingForSleep() {
            if (root.clipboardWatchHandle >= 0) BackendService.setSubscriptionActive(root.clipboardWatchHandle, false);
        }
        function onWakingUp() {
            Qt.callLater(() => {
                if (!SuspendManager.isSuspending && root.clipboardWatchHandle >= 0) {
                    BackendService.setSubscriptionActive(root.clipboardWatchHandle, true);
                }
            });
        }
    }

    function bindWatcher() {
        if (root._watchBound) return;
        root._watchBound = true;
        root.clipboardWatchHandle = BackendService.addSubscription(["clipboard"], (service, data) => {
            if (service === "clipboard.refresh") {
                Qt.callLater(root.list);
            }
        });
        BackendService.setSubscriptionActive(root.clipboardWatchHandle, true);
    }

        function start() {
        root.list();
    }

    signal fullContentRetrieved(string itemId, string content)
    signal linkPreviewFetched(string url, var metadata, string itemId)

        function decodeUriString(str) {
        try {
            return decodeURIComponent(str);
        } catch (e) {
            return str;
        }
    }

    function fetchLinkPreview(url, itemId) {
        if (linkPreviewCache[url]) {
            Qt.callLater(function() {
                root.linkPreviewFetched(url, linkPreviewCache[url], itemId);
            });
            return;
        }

        BackendService.call("linkpreview.fetch", {url: url, timeout: 5}, (metadata, error) => {
            if (error || !metadata) {
                root.linkPreviewFetched(url, {'error': 'Failed to fetch preview'}, itemId);
                return;
            }
            const responseUrl = metadata.request_url || metadata.url || url;
            if (!metadata.error && responseUrl) {
                root.linkPreviewCache[responseUrl] = metadata;
            }
            root.linkPreviewFetched(responseUrl, metadata, itemId);
        });
    }

    function list() {
        BackendService.call("clipboard.list", {}, (result, error) => {
            if (error || !result) {
                console.warn("ClipboardService: list failed:", error || "no data");
                return;
            }
            var clipboardItems = [];
            for (var i = 0; i < result.length; i++) {
                var item = result[i];
                var isFile = item.mime_type === "text/uri-list";

                var preview = item.preview;
                if (item.is_image === 1) {
                    preview = "[Image]";
                }

                clipboardItems.push({
                    id: item.id,
                    preview: preview,
                    fullContent: item.preview,
                    mime: item.mime_type,
                    isImage: item.is_image === 1,
                    isFile: isFile,
                    binaryPath: "",
                    hash: item.content_hash || "",
                    size: item.size || 0,
                    createdAt: item.created_at || 0,
                    pinned: item.pinned === 1,
                    alias: item.alias || "",
                    displayIndex: item.display_index !== null && item.display_index !== undefined ? item.display_index : -1
                });
            }
            root.items = clipboardItems;
            root.pruneImageCaches();
            root.listCompleted();
        });
    }

    function getFullContent(id) {
        BackendService.call("clipboard.getContent", {id: id}, (result, error) => {
            if (error || !result) {
                root.fullContentRetrieved(id, "");
                return;
            }
            root.fullContentRetrieved(id, result.content || "");
        });
    }

    function deleteItem(id) {
        BackendService.call("clipboard.delete", {id: id}, (result, error) => {
            if (error || !result) {
                console.warn("ClipboardService: delete failed:", error || "no data");
                return;
            }
            Qt.callLater(root.list);
        });
    }

    function clear() {
        BackendService.call("clipboard.clear", {}, (result, error) => {
            if (error) {
                console.warn("ClipboardService: clear failed:", error);
                return;
            }
            Qt.callLater(root.list);
        });
    }

    function togglePin(id) {
        BackendService.call("clipboard.togglePin", {id: id}, (result, error) => {
            if (error) {
                console.warn("ClipboardService: togglePin failed:", error);
                return;
            }
            Qt.callLater(root.list);
        });
    }

    function setAlias(id, alias) {
        BackendService.call("clipboard.setAlias", {id: id, alias: alias}, (result, error) => {
            if (error) {
                console.warn("ClipboardService: setAlias failed:", error);
                return;
            }
            Qt.callLater(root.list);
        });
    }

        function reorderItem(itemId, newIndex) {
        if (newIndex < 0) newIndex = 0;
        BackendService.call("clipboard.reorder", {id: itemId, new_index: newIndex}, (result, error) => {
            if (error) {
                console.warn("ClipboardService: reorder failed:", error);
                return;
            }
            Qt.callLater(root.list);
        });
    }

        function moveItemUp(itemId) {
        var currentIdx = -1;
        for (var i = 0; i < items.length; i++) {
            if (items[i].id === itemId) {
                currentIdx = i;
                break;
            }
        }
        if (currentIdx <= 0) return;

        var item = items[currentIdx];
        var prevItem = items[currentIdx - 1];
        if (prevItem.pinned !== item.pinned) return;

        var temp = items[currentIdx];
        items[currentIdx] = items[currentIdx - 1];
        items[currentIdx - 1] = temp;
        listCompleted();

        swapItems(itemId, prevItem.id);
    }

        function moveItemDown(itemId) {
        var currentIdx = -1;
        for (var i = 0; i < items.length; i++) {
            if (items[i].id === itemId) {
                currentIdx = i;
                break;
            }
        }
        if (currentIdx < 0 || currentIdx >= items.length - 1) return;

        var item = items[currentIdx];
        var nextItem = items[currentIdx + 1];
        if (nextItem.pinned !== item.pinned) return;

        // Optimistic update: swap in local array
        var temp = items[currentIdx];
        items[currentIdx] = items[currentIdx + 1];
        items[currentIdx + 1] = temp;
        listCompleted();

        swapItems(itemId, nextItem.id);
    }

        function swapItems(itemId1, itemId2) {
        BackendService.call("clipboard.swap", {id1: itemId1, id2: itemId2}, (result, error) => {
            if (error) {
                console.warn("ClipboardService: swap failed:", error);
                return;
            }
            Qt.callLater(root.list);
        });
    }

// Copy an item back to the clipboard (the daemon records the copy).
    function copyItem(id, mime) {
        BackendService.call("clipboard.copy", {id: id, mime: mime || ""}, (result, error) => {
            if (error) {
                console.warn("ClipboardService: copy failed:", error);
            }
        });
    }

    // Caches keyed by "id|hash": a recycled rowid can never serve a
    // previous item's image.
    function decodeToDataUrl(id, mime, hash) {
        var key = cacheKey(id, hash);
        if (imageDataById[key]) {
            return;
        }
        BackendService.call("clipboard.dataUrl", {id: id, mime: mime || ""}, (result, error) => {
            if (error || !result || !result.data_url) {
                return;
            }
            root.imageDataById[key] = result.data_url;
            root.revision++;
        });
    }

    function getImageData(id, hash) {
        return imageDataById[cacheKey(id, hash)] || "";
    }

        function requestImagePath(id, hash) {
        var key = cacheKey(id, hash);
        if (imagePathById[key]) {
            return;
        }
        BackendService.call("clipboard.imagePath", {id: id}, (result, error) => {
            if (error || !result || !result.path) {
                return;
            }
            root.imagePathById[key] = result.path;
            root.revision++;
        });
    }

    function getImagePath(id, hash) {
        return imagePathById[cacheKey(id, hash)] || "";
    }

    function cacheKey(id, hash) {
        return id + "|" + (hash || "");
    }

        function pruneImageCaches() {
        var live = {};
        for (var i = 0; i < items.length; i++) {
            live[cacheKey(items[i].id, items[i].hash)] = true;
        }
        var changed = false;
        for (var k in imageDataById) {
            if (!live[k]) {
                delete imageDataById[k];
                changed = true;
            }
        }
        for (var k2 in imagePathById) {
            if (!live[k2]) {
                delete imagePathById[k2];
                changed = true;
            }
        }
        if (changed) {
            root.revision++;
        }
    }

// Copy and paste emoji via Ctrl+V (daemon waits for selection ownership).
    function copyAndTypeEmoji(emojiText) {
        BackendService.call("clipboard.emojiType", {emoji: emojiText}, (result, error) => {
            if (error) {
                console.warn("ClipboardService: emojiType failed:", error);
            }
        });
    }

    Component.onCompleted: {
        bindWatcher();
    }
}
