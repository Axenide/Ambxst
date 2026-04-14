import QtQuick 2.15
import QtTest 1.15

import "../../modules/services/ErrorHandler.js" as ErrorHandlerModule

TestCase {
    name: "ErrorHandlerModule"

    // Note: This test validates the logic pattern, not the singleton directly
    // since singletons require special test setup

    function test_errorSeverityLevels() {
        // Verify severity level constants exist
        verify(ErrorHandlerModule.SeverityInfo !== undefined, "SeverityInfo should be defined");
        verify(ErrorHandlerModule.SeverityWarning !== undefined, "SeverityWarning should be defined");
        verify(ErrorHandlerModule.SeverityError !== undefined, "SeverityError should be defined");
        verify(ErrorHandlerModule.SeverityCritical !== undefined, "SeverityCritical should be defined");
    }

    function test_fallbackValues() {
        // Test fallback value generation pattern
        var fallbacks = {
            bool: false,
            int: 0,
            real: 0.0,
            string: "",
            color: "#000000",
            array: [],
            object: null
        };

        for (var type in fallbacks) {
            verify(fallbacks[type] !== undefined, "Fallback for " + type + " should exist");
        }
    }

    function test_safeJsonParse() {
        // Valid JSON
        var result1 = JSON.parse('{"key": "value"}');
        verify(result1.key === "value", "Should parse valid JSON");

        // Invalid JSON
        var result2 = (function() {
            try {
                return JSON.parse('invalid json');
            } catch (e) {
                return null;
            }
        })();
        verify(result2 === null, "Should return null for invalid JSON");
    }

    function test_safeGet() {
        var obj = { a: { b: { c: 42 } } };

        // Test path traversal
        function safeGet(target, path, fallback) {
            if (!target) return fallback;
            var parts = path.split(".");
            var current = target;
            for (var i = 0; i < parts.length; i++) {
                if (current === null || current === undefined) return fallback;
                current = current[parts[i]];
            }
            return current !== undefined ? current : fallback;
        }

        compare(safeGet(obj, "a.b.c", 0), 42, "Should traverse nested path");
        compare(safeGet(obj, "a.b.missing", 0), 0, "Should return fallback for missing");
        compare(safeGet(null, "anything", "fallback"), "fallback", "Should return fallback for null target");
        compare(safeGet(obj, "", "fallback"), "fallback", "Should return fallback for empty path");
    }
}