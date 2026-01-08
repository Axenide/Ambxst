pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.services

Singleton {
    id: root

    property var iconCache: ({})
    
    function getCachedIcon(str) {
        if (!str) return "image-missing";
        if (iconCache[str]) return iconCache[str];
        
        const result = guessIcon(str);
        iconCache[str] = result;
        return result;
    }

    function iconExists(iconName) {
        return (Quickshell.iconPath(iconName, true).length > 0) 
            && !iconName.includes("image-missing");
    }

    // Validate icon and return fallback if needed
    function validateIcon(iconName) {
        if (!iconName || iconName.length === 0) {
            return "image-missing";
        }
        
        // If it's an absolute path, check if file exists
        if (iconName.startsWith("/")) {
            // Use Quickshell.iconPath to check if the path is valid
            const resolvedPath = Quickshell.iconPath(iconName, true);
            if (resolvedPath.length === 0) {
                return "image-missing";
            }
            return iconName;
        }
        
        // For icon names (not paths), check if they exist in the theme
        if (iconExists(iconName)) {
            return iconName;
        }
        
        return "image-missing";
    }

    function getIconFromDesktopEntry(className) {
        if (!className || className.length === 0) return null;

        const normalizedClassName = className.toLowerCase();

        for (let i = 0; i < list.length; i++) {
            const app = list[i];
            if (app.command && app.command.length > 0) {
                const executableLower = app.command[0].toLowerCase();
                if (executableLower === normalizedClassName) {
                    return app.icon || "application-x-executable";
                }
            }
            if (app.name && app.name.toLowerCase() === normalizedClassName) {
                return app.icon || "application-x-executable";
            }
            if (app.keywords && app.keywords.length > 0) {
                for (let j = 0; j < app.keywords.length; j++) {
                    if (app.keywords[j].toLowerCase() === normalizedClassName) {
                        return app.icon || "application-x-executable";
                    }
                }
            }
        }
        return null;
    }

    function guessIcon(str) {
        if (!str || str.length == 0) return "image-missing";

        const desktopIcon = getIconFromDesktopEntry(str);
        if (desktopIcon) return desktopIcon;

        if (substitutions[str])
            return substitutions[str];

        for (let i = 0; i < regexSubstitutions.length; i++) {
            const substitution = regexSubstitutions[i];
            const replacedName = str.replace(
                substitution.regex,
                substitution.replace,
            );
            if (replacedName != str) return replacedName;
        }

        if (iconExists(str)) return str;

        const extensionGuess = str.split('.').pop().toLowerCase();
        if (iconExists(extensionGuess)) return extensionGuess;

        const dashedGuess = str.toLowerCase().replace(/\s+/g, "-");
        if (iconExists(dashedGuess)) return dashedGuess;

        return str;
    }

    property var substitutions: ({
        "code-url-handler": "visual-studio-code",
        "Code": "visual-studio-code",
        "gnome-tweaks": "org.gnome.tweaks",
        "pavucontrol-qt": "pavucontrol",
        "wps": "wps-office2019-kprometheus",
        "wpsoffice": "wps-office2019-kprometheus",
        "footclient": "foot",
        "zen": "zen-browser",
    })
    property list<var> regexSubstitutions: [
        {
            "regex": /^steam_app_(\d+)$/,
            "replace": "steam_icon_$1"
        },
        {
            "regex": /Minecraft.*/,
            "replace": "minecraft"
        },
        {
            "regex": /.*polkit.*/,
            "replace": "system-lock-screen"
        },
        {
            "regex": /gcr.prompter/,
            "replace": "system-lock-screen"
        }
    ]




    
    readonly property list<DesktopEntry> list: Array.from(DesktopEntries.applications.values)
        .sort((a, b) => a.name.localeCompare(b.name))
    
    // Index structure: [{ name: "lower", command: "lower", keywords: ["lower"], original: appObject }, ...]
    property var searchIndex: []
    
    function buildIndex() {
        const newIndex = [];
        for (let i = 0; i < list.length; i++) {
            const app = list[i];
            newIndex.push({
                name: app.name.toLowerCase(),
                command: (app.command && app.command.length > 0) ? app.command.join(' ').toLowerCase() : "",
                executable: (app.command && app.command.length > 0) ? app.command[0].toLowerCase() : "",
                comment: (app.comment || "").toLowerCase(),
                genericName: (app.genericName || "").toLowerCase(),
                keywords: (app.keywords || []).map(k => k.toLowerCase()),
                original: app
            });
        }
        searchIndex = newIndex;
    }
    
    Component.onCompleted: buildIndex()
    
    function getAllApps() {
        const results = [];
        
        for (let i = 0; i < list.length; i++) {
            const app = list[i];
            const usageScore = UsageTracker.getUsageScore(app.id);
            const validIcon = validateIcon(app.icon || "application-x-executable");
            results.push({
                name: app.name,
                icon: validIcon,
                id: app.id,
                execString: app.execString,
                comment: app.comment || "",
                categories: app.categories || [],
                runInTerminal: app.runInTerminal || false,
                usageScore: usageScore,
                execute: () => {
                    app.execute();
                }
            });
        }
        
        // Sort by usage score (most used/recent first), then alphabetically
        results.sort((a, b) => {
            if (a.usageScore !== b.usageScore) {
                return b.usageScore - a.usageScore;
            }
            return a.name.localeCompare(b.name);
        });
        
        return results; // Show all apps
    }
    
    function fuzzyQuery(search) {
        if (!search || search.length === 0) return [];
        
        const searchLower = search.toLowerCase();
        const results = [];
        
        // Ensure index exists
        if (searchIndex.length === 0 && list.length > 0) buildIndex();
        
        for (let i = 0; i < searchIndex.length; i++) {
            const entry = searchIndex[i];
            let score = 0;
            let matchFound = false;
            
            // Search in name (highest priority)
            if (entry.name === searchLower) {
                score += 100; // Exact name match
                matchFound = true;
            } else if (entry.name.startsWith(searchLower)) {
                score += 80; // Name starts with search
                matchFound = true;
            } else if (entry.name.includes(searchLower)) {
                score += 60; // Name contains search
                matchFound = true;
            }
            
            // Search in command (high priority)
            if (entry.command) {
                if (entry.command.includes(searchLower)) {
                    score += 40; // Command contains search
                    matchFound = true;
                }
                if (entry.executable.includes(searchLower)) {
                    score += 50; // Executable name contains search
                    matchFound = true;
                }
            }
            
            // Search in comment/description (medium priority)
            if (entry.comment && entry.comment.includes(searchLower)) {
                score += 30; // Comment contains search
                matchFound = true;
            }
            
            // Search in genericName (medium priority)
            if (entry.genericName && entry.genericName.includes(searchLower)) {
                score += 25; // Generic name contains search
                matchFound = true;
            }
            
            // Search in keywords (medium priority)
            if (entry.keywords.length > 0) {
                for (let j = 0; j < entry.keywords.length; j++) {
                    if (entry.keywords[j].includes(searchLower)) {
                        score += 20; // Keyword contains search
                        matchFound = true;
                        break;
                    }
                }
            }
            
            if (matchFound) {
                const app = entry.original;
                const usageScore = UsageTracker.getUsageScore(app.id);
                const validIcon = validateIcon(app.icon || "application-x-executable");
                results.push({
                    name: app.name,
                    icon: validIcon,
                    score: score,
                    id: app.id,
                    execString: app.execString,
                    comment: app.comment || "",
                    categories: app.categories || [],
                    runInTerminal: app.runInTerminal || false,
                    usageScore: usageScore,
                    execute: () => {
                        app.execute();
                    }
                });
            }
        }
        
        // Sort by combined score (search match + usage), then by name
        results.sort((a, b) => {
            // Combine search score with usage score (usage score is already 0-200+)
            const totalScoreA = a.score + a.usageScore;
            const totalScoreB = b.score + b.usageScore;
            
            if (totalScoreA !== totalScoreB) {
                return totalScoreB - totalScoreA;
            }
            return (a.name || "").localeCompare(b.name || "");
        });
        
        return results.slice(0, 10); // Limit results
    }
}
