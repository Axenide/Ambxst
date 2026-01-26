pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

QtObject {
    id: root

    readonly property string envLanguageRaw: Quickshell.env("LANG") || ""
    readonly property string envLanguage: normalizeLanguage(envLanguageRaw)

    property string language: normalizeLanguage(Config.system?.language || envLanguage || "en")
    readonly property string languageBase: language.split("-")[0]
    readonly property bool isRtl: false

    readonly property string assetsLocalePath: {
        const rel = "../../assets/locales/" + language + ".json";
        return Qt.resolvedUrl(rel).toString().replace("file://", "");
    }

    readonly property string userLocalePath: Config.configDir + "/locales/" + language + ".json"
    readonly property string fallbackLocalePath: Qt.resolvedUrl("../../assets/locales/en.json").toString().replace("file://", "")

    property var fallbackStrings: ({})
    property var baseStrings: ({})
    property var userStrings: ({})
    property var strings: ({})

    function normalizeLanguage(lang) {
        if (!lang)
            return "en";
        let cleaned = lang.toString();
        cleaned = cleaned.replace(".UTF-8", "").replace(".utf8", "");
        cleaned = cleaned.replace("_", "-");
        return cleaned;
    }

    function parseJson(text) {
        try {
            const value = JSON.parse(text);
            return value && typeof value === "object" ? value : {};
        } catch (e) {
            return {};
        }
    }

    function mergeStrings() {
        strings = Object.assign({}, fallbackStrings, baseStrings, userStrings);
    }

    function t(key, fallback, args) {
        let value = strings[key];
        if (value === undefined || value === null || value === "") {
            value = fallback !== undefined ? fallback : key;
        }
        if (args && Array.isArray(args)) {
            value = value.toString().replace(/\{(\d+)\}/g, function (match, index) {
                const idx = parseInt(index, 10);
                return args[idx] !== undefined ? args[idx] : match;
            });
        }
        return value;
    }

    property var fallbackLoader: FileView {
        path: root.fallbackLocalePath
        onLoaded: {
            root.fallbackStrings = root.parseJson(fallbackLoader.text());
            root.mergeStrings();
        }
        onFileChanged: {
            root.fallbackStrings = root.parseJson(fallbackLoader.text());
            root.mergeStrings();
        }
    }

    property var baseLoader: FileView {
        path: root.assetsLocalePath
        onLoaded: {
            root.baseStrings = root.parseJson(baseLoader.text());
            root.mergeStrings();
        }
        onFileChanged: {
            root.baseStrings = root.parseJson(baseLoader.text());
            root.mergeStrings();
        }
        onPathChanged: reload()
    }

    property var userLoader: FileView {
        path: root.userLocalePath
        onLoaded: {
            root.userStrings = root.parseJson(userLoader.text());
            root.mergeStrings();
        }
        onFileChanged: {
            root.userStrings = root.parseJson(userLoader.text());
            root.mergeStrings();
        }
        onPathChanged: reload()
    }
}
