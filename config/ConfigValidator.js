.pragma library

var CONFIG_VERSION = 1;

function clone(obj) {
    return JSON.parse(JSON.stringify(obj));
}

function migrate(oldConfig, oldVersion) {
    if (oldVersion === undefined || oldVersion === null) {
        // Pre-version configs: workspaceSpacing was 4, now 8
        if (oldConfig.overview && oldConfig.overview.workspaceSpacing === 4) {
            oldConfig.overview.workspaceSpacing = 8;
        }
    }
    return oldConfig;
}

function validateWithMigration(userConfig, defaults) {
    if (userConfig === undefined || userConfig === null) {
        return clone(defaults);
    }

    // Run migrations
    var version = userConfig.version || 0;
    if (version < CONFIG_VERSION) {
        userConfig = migrate(userConfig, version);
        userConfig.version = CONFIG_VERSION;
    }

    return validate(userConfig, defaults);
}

var enumValidators = {
    "position": ["top", "bottom", "left", "right"],
    "pillStyle": ["default", "squished"],
    "gradientType": ["linear", "radial", "halftone"],
    "noMediaDisplay": ["userHost", "compositor", "custom"],
    "theme": ["default", "integrated", "island"],
    "sidebarPosition": ["left", "right"],
    "sidebarWidth": null,
    "lightMode": null,
    "oledMode": null
};

var rangeValidators = {
    "roundness": { min: 0, max: 100 },
    "fontSize": { min: 8, max: 72 },
    "monoFontSize": { min: 8, max: 72 },
    "animDuration": { min: 0, max: 2000 },
    "shadowOpacity": { min: 0, max: 1 },
    "shadowBlur": { min: 0, max: 20 },
    "shadowXOffset": { min: -100, max: 100 },
    "shadowYOffset": { min: -100, max: 100 },
    "scale": { min: 0, max: 1 },
    "rows": { min: 1, max: 20 },
    "columns": { min: 1, max: 20 },
    "workspaceSpacing": { min: 0, max: 200 },
    "launcherIconSize": { min: 0, max: 128 },
    "frameThickness": { min: 0, max: 100 },
    "hoverRegionHeight": { min: 0, max: 200 },
    "iconSize": { min: 0, max: 128 },
    "spacing": { min: 0, max: 100 },
    "margin": { min: 0, max: 100 },
    "sidebarWidth": { min: 100, max: 2000 },
    "halftoneDotMin": { min: 0, max: 10 },
    "halftoneDotMax": { min: 0, max: 10 },
    "halftoneStart": { min: 0, max: 1 },
    "halftoneEnd": { min: 0, max: 1 },
    "opacity": { min: 0, max: 1 },
    "border": { min: 0, max: 100 }
};

function validate(current, defaults, keyName) {
    if (current === undefined || current === null) {
        return clone(defaults);
    }

    if (Array.isArray(defaults)) {
        if (!Array.isArray(current)) {
            return clone(defaults);
        }
        return current;
    }

    if (typeof defaults === 'object') {
        if (typeof current !== 'object' || Array.isArray(current)) {
            return clone(defaults);
        }

        var result = {};
        for (var key in defaults) {
            result[key] = validate(current[key], defaults[key], key);
        }
        // Preserve keys present in the user's file but absent from the blueprint
        // (forward-compatible / dynamically-added keys such as customEndpoint).
        // Without this, valid user settings are silently wiped on every load.
        for (var ckey in current) {
            if (!(ckey in result)) {
                result[ckey] = current[ckey];
            }
        }
        return result;
    }

    if (typeof current !== typeof defaults) {
        return defaults;
    }

    // Enum validation
    if (keyName in enumValidators && enumValidators[keyName] !== null) {
        if (enumValidators[keyName].indexOf(current) === -1) {
            return defaults;
        }
    }

    // Range validation for numbers
    if (keyName in rangeValidators && typeof current === 'number') {
        var range = rangeValidators[keyName];
        if (current < range.min || current > range.max) {
            return defaults;
        }
    }

    // Special case: border is an array [colorName, width]
    if (keyName === "border" && Array.isArray(current)) {
        if (current.length !== 2 || typeof current[0] !== 'string' || typeof current[1] !== 'number') {
            return defaults;
        }
        if (current[1] < 0 || current[1] > 100) {
            return defaults;
        }
    }

    return current;
}
