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
    // Bumped after every successful load. t() reads it so every binding which
    // calls t() re-evaluates after a language change.
    property int revision: 0

    function humanize(key) {
        const segment = key.substring(key.lastIndexOf(".") + 1).replace(/_/g, " ");
        return segment.charAt(0).toUpperCase() + segment.slice(1);
    }

    function t(key) {
        const currentRevision = root.revision;
        let str = root.strings[key] ?? root.fallback[key] ?? root.humanize(key);
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

    FileView {
        id: languagesLoader
        path: Qt.resolvedUrl("../../translations/languages.json")
        blockLoading: true
    }

    FileView {
        id: fallbackLoader
        path: Qt.resolvedUrl("../../translations/en.json")
        blockLoading: true
    }

    FileView {
        id: langLoader
        path: root.resolvedLanguage !== "en"
              ? Qt.resolvedUrl("../../translations/" + root.resolvedLanguage + ".json")
              : ""
        blockLoading: true
    }

    // blockLoading takes effect on an explicit text() call. Read the files
    // here so translations exist before the first UI binding evaluates.
    function loadAll() {
        try {
            root.availableLanguages = JSON.parse(languagesLoader.text());
        } catch (e) {
            console.warn("I18n: failed to parse languages.json:", e);
            root.availableLanguages = { "en": "English" };
        }

        try {
            root.fallback = JSON.parse(fallbackLoader.text());
        } catch (e) {
            console.warn("I18n: failed to parse en.json:", e);
            root.fallback = ({});
        }

        root.resolvedLanguage = root.resolveLanguage();

        if (root.resolvedLanguage === "en") {
            root.strings = root.fallback;
        } else {
            try {
                root.strings = JSON.parse(langLoader.text());
            } catch (e) {
                console.warn("I18n: failed to parse " + root.resolvedLanguage + ".json:", e);
                root.strings = root.fallback;
            }
        }

        root.ready = Object.keys(root.fallback).length > 0;
        root.revision++;
    }

    Component.onCompleted: root.loadAll()
    onConfigLanguageChanged: root.loadAll()
}
