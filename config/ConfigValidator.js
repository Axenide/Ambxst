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
