// Error handling utilities for QML
// Provides reusable error handling patterns

.pragma library

// Log with source and message
function logError(source, message) {
    console.error("[ERROR:" + source + "] " + message);
}

function logWarning(source, message) {
    console.warn("[WARN:" + source + "] " + message);
}

function logInfo(source, message) {
    console.log("[INFO:" + source + "] " + message);
}

// Safe JSON parse with fallback
function safeJsonParse(jsonString, fallback) {
    try {
        return JSON.parse(jsonString);
    } catch (e) {
        logError("SafeJson", "Parse failed: " + e.message);
        return fallback;
    }
}

// Safe property access
function safeGet(obj, path, fallback) {
    if (!obj) return fallback;
    var parts = path.split(".");
    var current = obj;
    for (var i = 0; i < parts.length; i++) {
        if (current === null || current === undefined) return fallback;
        current = current[parts[i]];
    }
    return current !== undefined ? current : fallback;
}

// Default fallback values by type
function getFallback(type) {
    var fallbacks = {
        "bool": false,
        "int": 0,
        "real": 0.0,
        "string": "",
        "color": "#000000",
        "array": [],
        "object": null
    };
    return fallbacks[type] !== undefined ? fallbacks[type] : null;
}

// Validate required process exit code
function validateProcessExit(process, command, expectedCode) {
    expectedCode = expectedCode || 0;
    if (process.exitCode !== expectedCode) {
        logError("Process", "Process failed: " + command + " (exit code: " + process.exitCode + ")");
        return false;
    }
    return true;
}

// Component status checker
function checkComponentStatus(component) {
    if (!component) return { valid: false, error: "Component is null" };
    
    var status = component.status || component.loadStatus || 0;
    var statusNames = ["Null", "Loading", "Ready", "Error"];
    var statusName = statusNames[status] || "Unknown";
    
    if (status === 3) { // Error
        return { 
            valid: false, 
            error: component.errorString || "Unknown error",
            statusName: statusName 
        };
    }
    
    return { valid: true, statusName: statusName };
}