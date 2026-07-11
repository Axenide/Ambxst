.pragma library

function clone(obj) {
    return JSON.parse(JSON.stringify(obj));
}

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

    if (keyName === "gradientType") {
        var validTypes = ["linear", "radial", "halftone"];
        if (validTypes.indexOf(current) === -1) {
            return defaults;
        }
    }

    if (keyName === "noMediaDisplay") {
        var validMediaOptions = ["userHost", "compositor", "custom"];
        if (validMediaOptions.indexOf(current) === -1) {
            return defaults;
        }
    }

    return current;
}
