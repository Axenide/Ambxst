pragma Singleton

import QtQuick
import Quickshell

/**
 * Centralized error handling service
 * Provides graceful fallbacks for service failures and runtime errors
 */
Singleton {
    id: root

    // Error state tracking
    property var errors: ([])
    property bool hasCriticalError: false
    
    // Service availability flags
    property bool axctlAvailable: false
    property bool networkAvailable: false
    property bool audioAvailable: false
    property bool bluetoothAvailable: false

    // Error severity levels
    readonly property int SeverityInfo: 0
    readonly property int SeverityWarning: 1
    readonly property int SeverityError: 2
    readonly property int SeverityCritical: 3

    // Log an error
    function log(severity, source, message, details) {
        var error = {
            timestamp: Date.now(),
            severity: severity,
            source: source,
            message: message,
            details: details || null
        };
        
        errors.push(error);
        
        // Keep only last 100 errors
        if (errors.length > 100) {
            errors.shift();
        }
        
        // Log to console based on severity
        var prefix = severity === SeverityInfo ? "INFO" : 
                     severity === SeverityWarning ? "WARN" : 
                     severity === SeverityError ? "ERROR" : "CRITICAL";
        
        console.log("[ErrorHandler:" + source + "] " + prefix + ": " + message);
        
        if (details) {
            console.log("  Details:", JSON.stringify(details));
        }
        
        // Emit signal for UI updates
        errorLogged(error);
        
        // Mark critical errors
        if (severity >= SeverityCritical) {
            hasCriticalError = true;
        }
    }

    function info(source, message, details) {
        log(SeverityInfo, source, message, details);
    }

    function warn(source, message, details) {
        log(SeverityWarning, source, message, details);
    }

    function error(source, message, details) {
        log(SeverityError, source, message, details);
    }

    function critical(source, message, details) {
        log(SeverityCritical, source, message, details);
    }

    signal errorLogged(var error)

    // Service availability check with fallback
    function checkService(name, isAvailable) {
        var wasAvailable = root[name + "Available"];
        root[name + "Available"] = isAvailable;
        
        if (!wasAvailable && !isAvailable) {
            warn("ErrorHandler", "Service unavailable: " + name);
        } else if (wasAvailable && isAvailable) {
            info("ErrorHandler", "Service recovered: " + name);
        }
    }

    // Graceful fallback value provider
    function getFallback(propertyType) {
        switch (propertyType) {
            case "bool": return false;
            case "int": return 0;
            case "real": return 0.0;
            case "string": return "";
            case "color": return "#000000";
            case "array": return [];
            case "object": return null;
            default: return null;
        }
    }

    // Safe property access with fallback
    function safeGet(obj, path, fallback) {
        if (!obj) return fallback;
        
        var parts = path.split(".");
        var current = obj;
        
        for (var i = 0; i < parts.length; i++) {
            if (current === null || current === undefined) {
                return fallback;
            }
            current = current[parts[i]];
        }
        
        return current !== undefined ? current : fallback;
    }

    // JSON parse with error handling
    function safeJsonParse(jsonString, fallback) {
        try {
            return JSON.parse(jsonString);
        } catch (e) {
            error("ErrorHandler", "JSON parse failed", { error: e.message });
            return fallback;
        }
    }

    // Retry wrapper for async operations
    function retry(fn, maxAttempts, delayMs, onSuccess, onFailure) {
        var attempts = 0;
        
        function attempt() {
            attempts++;
            var result = fn();
            
            if (result.success) {
                if (onSuccess) onSuccess(result.data);
            } else if (attempts < maxAttempts) {
                warn("ErrorHandler", "Retry attempt " + attempts + " failed, retrying...", 
                     { attempt: attempts, max: maxAttempts });
                Qt.callLater(attempt);
            } else {
                error("ErrorHandler", "All retry attempts exhausted", 
                      { attempts: attempts, max: maxAttempts });
                if (onFailure) onFailure(result.error);
            }
        }
        
        if (delayMs > 0) {
            Qt.callLater(attempt);
        } else {
            attempt();
        }
    }

    // Component loading error handler
    function handleComponentError(component, errorString) {
        error("ComponentLoader", "Failed to load component", { 
            error: errorString,
            component: component ? component.source : "unknown"
        });
    }

    // Process error handler
    function handleProcessError(process, command) {
        if (process.exitCode !== 0) {
            error("Process", "Process exited with error", {
                command: command,
                exitCode: process.exitCode
            });
        }
    }

    // Clear errors (e.g., after recovery)
    function clearErrors() {
        errors = [];
        hasCriticalError = false;
    }
}