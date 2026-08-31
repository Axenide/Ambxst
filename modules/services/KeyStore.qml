pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    // Cache of loaded keys: { "openai": { api_key: "...", endpoint: "", custom_curl: "" }, ... }
    property var keyCache: ({})
    property bool initialized: false

    signal keysChanged

    Component.onCompleted: {
        refreshKeys();
    }

    function refreshKeys() {
        BackendService.call("keystore.list", {}, (result, error) => {
            if (error || !result || !Array.isArray(result)) return;
            let cache = {};
            for (let i = 0; i < result.length; i++) {
                const k = result[i];
                cache[k.provider] = {
                    api_key: k.api_key || "",
                    endpoint: k.endpoint || "",
                    custom_curl: k.custom_curl || ""
                };
            }
            root.keyCache = cache;
            root.initialized = true;
            root.keysChanged();
        });
    }

    function getKey(provider) {
        if (!provider) return "";
        let entry = keyCache[provider];
        return entry ? entry.api_key : "";
    }

    function getEndpoint(provider) {
        if (!provider) return "";
        let entry = keyCache[provider];
        return entry ? entry.endpoint : "";
    }

    function getCustomCurl(provider) {
        if (!provider) return "";
        let entry = keyCache[provider];
        return entry ? entry.custom_curl : "";
    }

    function hasKey(provider) {
        return keyCache[provider] !== undefined && keyCache[provider].api_key !== "";
    }

    function setKey(provider, apiKey, endpoint, customCurl) {
        BackendService.call("keystore.set", {
            provider: provider,
            api_key: apiKey,
            endpoint: endpoint || "",
            custom_curl: customCurl || ""
        }, (result, error) => {
            if (error || !result || result.error) {
                console.warn("KeyStore: Failed to set key:", error || result?.error);
                return;
            }
            root.refreshKeys();
        });
    }

    function deleteKey(provider) {
        BackendService.call("keystore.delete", {provider: provider}, (result, error) => {
            if (error || !result || result.error) {
                console.warn("KeyStore: Failed to delete key:", error || result?.error);
                return;
            }
            root.refreshKeys();
        });
    }
}
