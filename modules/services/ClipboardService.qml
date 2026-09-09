pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

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

    // All persistence lives in the Go daemon (two encrypted SQLite
    // stores: pinned + unpinned). The watcher (wl-paste --watch) is also
    // owned by the daemon and emits a "clipboard.refresh" event on every
    // clipboard change; we just re-list.
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

    // External trigger to start watching + load history.
    function start() {
        root.list();
    }

    signal fullContentRetrieved(string itemId, string content)
    signal linkPreviewFetched(string url, var metadata, string itemId)

    // Function to decode URL-encoded strings
    function decodeUriString(str) {
        try {
            return decodeURIComponent(str);
        } catch (e) {
            // If decoding fails, return original string
            return str;
        }
    }

    function fetchLinkPreview(url, itemId) {
        // Check cache first
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

                // For files, extract the filename from the URI for preview
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
            // Clear the live clipboard if it matches the deleted item
            var deletedHash = result.hash || "";
            if (deletedHash.length > 0) {
                clearClipboardIfMatches.deletedHash = deletedHash;
                clearClipboardIfMatches.running = true;
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

    // Reorder item by moving it to a new index
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

    // Move item up (decrease index)
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

        // Optimistic update: swap in local array
        var temp = items[currentIdx];
        items[currentIdx] = items[currentIdx - 1];
        items[currentIdx - 1] = temp;
        listCompleted();

        swapItems(itemId, prevItem.id);
    }

    // Move item down (increase index)
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

    // Swap display indices between two items
    function swapItems(itemId1, itemId2) {
        BackendService.call("clipboard.swap", {id1: itemId1, id2: itemId2}, (result, error) => {
            if (error) {
                console.warn("ClipboardService: swap failed:", error);
                return;
            }
            Qt.callLater(root.list);
        });
    }

    // Copy an item back to the clipboard (text, file URI or image blob).
    function copyItem(id, mime) {
        BackendService.call("clipboard.copy", {id: id, mime: mime || ""}, (result, error) => {
            if (error) {
                console.warn("ClipboardService: copy failed:", error);
                return;
            }
            Qt.callLater(root.checkClipboard);
        });
    }

    function checkClipboard() {
        BackendService.call("clipboard.check", {}, () => {
            Qt.callLater(root.list);
        });
    }

    // Load image data as data URL (images live as encrypted blobs now)
    function decodeToDataUrl(id, mime) {
        if (imageDataById[id]) {
            return;
        }
        BackendService.call("clipboard.dataUrl", {id: id, mime: mime || ""}, (result, error) => {
            if (error || !result || !result.data_url) {
                return;
            }
            root.imageDataById[id] = result.data_url;
            root.revision++;
        });
    }

    function getImageData(id) {
        return imageDataById[id] || "";
    }

    // Materialize an image blob to a tmpfs path (drag-and-drop / open).
    function requestImagePath(id) {
        if (imagePathById[id]) {
            return;
        }
        BackendService.call("clipboard.imagePath", {id: id}, (result, error) => {
            if (error || !result || !result.path) {
                return;
            }
            root.imagePathById[id] = result.path;
            root.revision++;
        });
    }

    function getImagePath(id) {
        return imagePathById[id] || "";
    }

    // Copy and paste emoji via Ctrl+V (handled by the daemon)
    function copyAndTypeEmoji(emojiText) {
        BackendService.call("clipboard.emojiType", {emoji: emojiText}, (result, error) => {
            if (error) {
                console.warn("ClipboardService: emojiType failed:", error);
            }
        });
    }

    // Clear system clipboard if it matches deleted item
    property Process clearClipboardIfMatches: Process {
        property string deletedHash: ""
        running: false

        command: ["sh", "-c",
            "# Get current clipboard hash for different types\n" +
            "CURRENT_HASH=''; " +
            "if CONTENT=$(wl-paste --type text/uri-list 2>/dev/null); then " +
            "  CURRENT_HASH=$(echo -n \"$CONTENT\" | tr -d '\\r' | md5sum | cut -d' ' -f1); " +
            "elif CONTENT=$(wl-paste --type text/plain 2>/dev/null); then " +
            "  CURRENT_HASH=$(echo -n \"$CONTENT\" | md5sum | cut -d' ' -f1); " +
            "elif IMAGE_MIME=$(wl-paste --list-types 2>/dev/null | grep '^image/' | head -1); then " +
            "  [ -n \"$IMAGE_MIME\" ] && CURRENT_HASH=$(wl-paste --type \"$IMAGE_MIME\" 2>/dev/null | md5sum | cut -d' ' -f1); " +
            "fi; " +
            "# Clear clipboard if hashes match\n" +
            "if [ \"$CURRENT_HASH\" = '" + deletedHash + "' ]; then " +
            "  wl-copy --clear 2>/dev/null || true; " +
            "fi"
        ]

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.length > 0 && !text.includes("No selection")) {
                    console.warn("ClipboardService: clearClipboardIfMatches stderr:", text);
                }
            }
        }
    }

    Component.onCompleted: {
        // Bind clipboard watcher at boot (cheap - just adds IPC subscription)
        bindWatcher();
    }
}
