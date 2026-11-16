pragma Singleton

import QtQuick
import Quickshell
import qs.modules.services

Singleton {
    id: root

    readonly property var list: AxctlBackend.applications
    property var iconCache: ({})
    property var allAppsCache: null

    property var substitutions: ({
        "code-url-handler": "visual-studio-code",
        "Code": "visual-studio-code",
        "gnome-tweaks": "org.gnome.tweaks",
        "pavucontrol-qt": "pavucontrol",
        "wps": "wps-office2019-kprometheus",
        "wpsoffice": "wps-office2019-kprometheus",
        "footclient": "foot",
        "zen": "zen-browser"
    })

    property list<var> regexSubstitutions: [
        {regex: /^steam_app_(\d+)$/, replace: "steam_icon_$1"},
        {regex: /Minecraft.*/, replace: "minecraft"},
        {regex: /.*polkit.*/, replace: "system-lock-screen"},
        {regex: /gcr.prompter/, replace: "system-lock-screen"}
    ]

    onListChanged: allAppsCache = null

    function invalidateCache() {
        allAppsCache = null;
    }

    function getApplication(identity) {
        if (!identity) return null;
        const value = String(identity).toLowerCase().replace(/\.desktop$/, "");
        for (let i = 0; i < list.length; i++) {
            const app = list[i];
            if (String(app.id || "").toLowerCase().replace(/\.desktop$/, "") === value
                    || String(app.startupWMClass || "").toLowerCase() === value
                    || String(app.name || "").toLowerCase() === value
                    || (app.command?.length > 0 && String(app.command[0]).split("/").pop().toLowerCase() === value)) {
                return app;
            }
        }
        return null;
    }

    function getCachedIcon(name) {
        return guessIcon(name);
    }

    function getIconFromDesktopEntry(identity) {
        const app = getApplication(identity);
        return app ? (app.iconPath || "") : "";
    }

    function iconExists(name) {
        return !!(name && AxctlBackend.iconPaths[name]);
    }

    function validateIcon(name) {
        if (!name) return "image://icon/application-x-executable";
        if (iconExists(name)) return AxctlBackend.iconPaths[name];
        AxctlBackend.resolveIcon(name, 48);
        return "image://icon/application-x-executable";
    }

    function guessIcon(identity) {
        if (!identity) return "image://icon/application-x-executable";
        const value = String(identity);
        const appIcon = getIconFromDesktopEntry(value);
        if (appIcon) return appIcon;

        let candidate = substitutions[value] || value;
        for (let i = 0; i < regexSubstitutions.length; i++) {
            const substitution = regexSubstitutions[i];
            const replaced = candidate.replace(substitution.regex, substitution.replace);
            if (replaced !== candidate) {
                candidate = replaced;
                break;
            }
        }

        if (AxctlBackend.iconPaths[candidate]) return AxctlBackend.iconPaths[candidate];
        const lowerCandidate = candidate.toLowerCase();
        if (AxctlBackend.iconPaths[lowerCandidate]) return AxctlBackend.iconPaths[lowerCandidate];

        const extension = value.split(".").pop().toLowerCase();
        if (AxctlBackend.iconPaths[extension]) return AxctlBackend.iconPaths[extension];
        const dashed = value.toLowerCase().replace(/\s+/g, "-");
        if (AxctlBackend.iconPaths[dashed]) return AxctlBackend.iconPaths[dashed];

        AxctlBackend.resolveIcon(candidate, 48);
        if (extension) AxctlBackend.resolveIcon(extension, 48);
        if (dashed !== candidate) AxctlBackend.resolveIcon(dashed, 48);
        iconCache[value] = candidate;
        return "image://icon/application-x-executable";
    }

    function getAllApps(callback) {
        if (allAppsCache) {
            if (callback) callback(allAppsCache);
            return allAppsCache;
        }
        if (!AxctlBackend.applicationsReady) {
            AxctlBackend.loadApplications(apps => {
                allAppsCache = apps;
                if (callback) callback(apps);
            });
            return [];
        }
        allAppsCache = list.slice();
        if (callback) callback(allAppsCache);
        return allAppsCache;
    }

    function fuzzyQuery(search, callback) {
        if (!search) {
            getAllApps(callback);
            return [];
        }
        AxctlBackend.searchApplications(search, (apps, error) => {
            if (callback) callback(apps);
        });
        return [];
    }

    function launchApp(app, actionId, uris) {
        if (!app) return;
        const id = typeof app === "string" ? app : (app.id || app.desktopId || app.appId || "");
        if (!id) {
            console.warn("AppSearch: application has no desktop ID");
            return;
        }
        AxctlBackend.launchApplication(id, actionId, uris);
    }
}
