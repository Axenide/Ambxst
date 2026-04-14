// Test utilities and assertions for QML tests
// Provides common test helpers for the Ambxst test suite

pragma Singleton

import QtQuick 2.15
import QtTest 1.15

Singleton {
    id: TestUtils

    // Waits for a condition with timeout
    function waitForCondition(conditionFn, timeoutMs) {
        var startTime = Date.now();
        while (!conditionFn()) {
            if (Date.now() - startTime > timeoutMs) {
                return false;
            }
            qtTestWait(10);
        }
        return true;
    }

    // Waits for signal with timeout
    function waitForSignal(target, signalName, timeoutMs) {
        var spy = Qt.createQmlObject(
            "import QtTest 1.15; SignalSpy { target: " + target + "; signalName: '" + signalName + "' }",
            target
        );
        if (!spy) return false;
        
        var result = waitForCondition(function() { return spy.count > 0; }, timeoutMs);
        spy.destroy();
        return result;
    }

    // Deep compare two objects
    function deepCompare(actual, expected, path) {
        path = path || "";
        
        if (actual === expected) return true;
        
        if (typeof actual !== typeof expected) {
            console.log("Type mismatch at " + path + ": " + typeof actual + " !== " + typeof expected);
            return false;
        }
        
        if (typeof actual === "object" && actual !== null) {
            if (Array.isArray(actual) !== Array.isArray(expected)) {
                console.log("Array mismatch at " + path);
                return false;
            }
            
            var actualKeys = Object.keys(actual);
            var expectedKeys = Object.keys(expected);
            
            if (actualKeys.length !== expectedKeys.length) {
                console.log("Key count mismatch at " + path + ": " + actualKeys.length + " !== " + expectedKeys.length);
                return false;
            }
            
            for (var i = 0; i < actualKeys.length; i++) {
                var key = actualKeys[i];
                if (!deepCompare(actual[key], expected[key], path + "." + key)) {
                    return false;
                }
            }
            return true;
        }
        
        console.log("Value mismatch at " + path + ": " + actual + " !== " + expected);
        return false;
    }

    // Creates a temporary directory for tests
    function createTempDir(prefix) {
        return "/tmp/ambxst_test_" + (prefix || "temp") + "_" + Date.now();
    }

    // Clean up test files
    function cleanupFile(path) {
        // Would use Process to rm -f, but keeping simple for now
    }
}