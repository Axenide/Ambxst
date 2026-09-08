.pragma library

function isValidPosition(value, allowedPositions) {
    return typeof value === "string" && allowedPositions.indexOf(value) !== -1;
}

function positionForScreen(config, screenName, fallbackPosition, allowedPositions) {
    var globalPosition = fallbackPosition;

    if (config && isValidPosition(config.position, allowedPositions)) {
        globalPosition = config.position;
    }

    if (!config || !screenName || !config.screenPositions || typeof config.screenPositions !== "object" || Array.isArray(config.screenPositions)) {
        return globalPosition;
    }

    var screenPosition = config.screenPositions[screenName];
    return isValidPosition(screenPosition, allowedPositions) ? screenPosition : globalPosition;
}
