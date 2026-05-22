pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string dbPath: Quickshell.dataPath("keys.db")
    property string scriptPath: Qt.resolvedUrl("../../scripts/keystore.py").toString().replace("file://", "")

    // Cache of loaded keys: { "openai": { api_key: "...", endpoint: "", custom_curl: "" }, ... }
    property var keyCache: ({})
    property bool initialized: false

    signal keysChanged

    Component.onCompleted: {
        refreshKeys();
    }

    function refreshKeys() {
        listProcess.command = ["python3", scriptPath, dbPath, "list"];
        listProcess.running = true;
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
        let args = ["python3", scriptPath, dbPath, "set", provider, apiKey];
        if (endpoint) args.push(endpoint);
        if (customCurl) args.push(customCurl);
        setProcess.command = args;
        setProcess.running = true;
    }

    function deleteKey(provider) {
        deleteProcess.command = ["python3", scriptPath, dbPath, "delete", provider];
        deleteProcess.running = true;
    }

    // List all keys
    Process {
        id: listProcess
        stdout: StdioCollector {
            id: listStdout
        }
        onExited: exitCode => {
            if (exitCode === 0) {
                try {
                    let data = JSON.parse(listStdout.text);
                    if (Array.isArray(data)) {
                        let cache = {};
                        for (let i = 0; i < data.length; i++) {
                            cache[data[i].provider] = {
                                api_key: data[i].api_key,
                                endpoint: data[i].endpoint || "",
                                custom_curl: data[i].custom_curl || ""
                            };
                        }
                        root.keyCache = cache;
                        root.initialized = true;
                        root.keysChanged();
                    }
                } catch (e) {
                    console.warn("KeyStore: Failed to parse keys list:", e);
                }
            }
        }
    }

    // Set key
    Process {
        id: setProcess
        stdout: StdioCollector {
            id: setStdout
        }
        onExited: exitCode => {
            if (exitCode === 0) {
                root.refreshKeys();
            } else {
                console.warn("KeyStore: Failed to set key:", setStdout.text);
            }
        }
    }

    // Delete key
    Process {
        id: deleteProcess
        stdout: StdioCollector {
            id: deleteStdout
        }
        onExited: exitCode => {
            if (exitCode === 0) {
                root.refreshKeys();
            } else {
                console.warn("KeyStore: Failed to delete key:", deleteStdout.text);
            }
        }
    }
}
