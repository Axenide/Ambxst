pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    readonly property string configLanguage: Config.system?.language ?? "auto"
    property string resolvedLanguage: "en"
    property var strings: ({})
    property var fallback: ({})
    property var availableLanguages: ({})
    property bool ready: false

    function t(key) {
        let str = root.strings[key] ?? root.fallback[key] ?? key;
        for (let i = 1; i < arguments.length; i++)
            str = str.replace("%" + i, arguments[i]);
        return str;
    }

    function detectSystemLanguage() {
        const sources = [
            Qt.locale().name,
            Quickshell.env("LC_MESSAGES"),
            Quickshell.env("LC_ALL"),
            Quickshell.env("LANG")
        ];
        for (const src of sources) {
            if (src && src.length >= 2) {
                const code = src.substring(0, 2).toLowerCase();
                if (code !== "c" && code !== "po")
                    return code;
            }
        }
        return "en";
    }

    function resolveLanguage() {
        const lang = root.configLanguage === "auto"
            ? detectSystemLanguage()
            : root.configLanguage;

        if (root.availableLanguages[lang])
            return lang;
        return "en";
    }

    onConfigLanguageChanged: {
        root.resolvedLanguage = resolveLanguage();
    }

FileView {
        id: languagesLoader
        path: Qt.resolvedUrl("../../translations/languages.json")
        preload: true
        onLoaded: {
            try {
                root.availableLanguages = JSON.parse(text());
                root.resolvedLanguage = root.resolveLanguage();
            } catch (e) {
                console.warn("I18n: failed to parse languages.json:", e);
                root.availableLanguages = { "en": "English" };
            }
        }
    }

    FileView {
        id: fallbackLoader
        path: Qt.resolvedUrl("../../translations/en.json")
        preload: true
        onLoaded: {
            try {
                root.fallback = JSON.parse(text());
                if (root.resolvedLanguage === "en") {
                    root.strings = root.fallback;
                    root.ready = true;
                }
            } catch (e) {
                console.warn("I18n: failed to parse en.json:", e);
            }
        }
    }

    FileView {
        id: langLoader
        path: root.resolvedLanguage !== "en"
              ? Qt.resolvedUrl("../../translations/" + root.resolvedLanguage + ".json")
              : ""
        onLoaded: {
            if (root.resolvedLanguage === "en") return;
            try {
                root.strings = JSON.parse(text());
                root.ready = true;
            } catch (e) {
                console.warn("I18n: failed to parse " + root.resolvedLanguage + ".json:", e);
                root.strings = root.fallback;
                root.ready = true;
            }
        }
    }

    onResolvedLanguageChanged: {
        if (resolvedLanguage === "en") {
            root.strings = root.fallback;
            root.ready = Object.keys(root.fallback).length > 0;
        } else {
            langLoader.reload();
        }
    }
}
