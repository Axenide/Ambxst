import QtQuick 2.15
import QtTest 1.15

import "../../config/ConfigValidator.js" as ConfigValidator

TestCase {
    name: "ConfigValidator"

    function test_cloneReturnsDeepCopy() {
        var original = { a: { b: 1 } };
        var cloned = ConfigValidator.clone(original);
        
        cloned.a.b = 2;
        
        compare(original.a.b, 1, "Clone should be a deep copy");
    }

    function test_validateReturnsDefaultForUndefined() {
        var result = ConfigValidator.validate(undefined, { foo: "bar" });
        compare(result.foo, "bar");
    }

    function test_validateReturnsDefaultForNull() {
        var result = ConfigValidator.validate(null, { foo: "bar" });
        compare(result.foo, "bar");
    }

    function test_validateReturnsDefaultForWrongType() {
        var result = ConfigValidator.validate("not an object", { foo: "bar" });
        compare(result.foo, "bar");
    }

    function test_validateReturnsCurrentForValidObject() {
        var defaults = { foo: "default", bar: 123 };
        var current = { foo: "custom", bar: 456 };
        
        var result = ConfigValidator.validate(current, defaults);
        
        compare(result.foo, "custom");
        compare(result.bar, 456);
    }

    function test_validateHandlesNestedObjects() {
        var defaults = { outer: { inner: "default" } };
        var current = { outer: { inner: "custom" } };
        
        var result = ConfigValidator.validate(current, defaults);
        
        compare(result.outer.inner, "custom");
    }

    function test_validateFillsMissingNestedKeys() {
        var defaults = { outer: { a: 1, b: 2 } };
        var current = { outer: { a: 100 } };
        
        var result = ConfigValidator.validate(current, defaults);
        
        compare(result.outer.a, 100, "Preserved user value");
        compare(result.outer.b, 2, "Filled missing with default");
    }

    function test_validateTypeConstraintGradientType() {
        var defaults = { gradientType: "linear" };
        
        // Valid values should pass
        compare(ConfigValidator.validate("linear", defaults, "gradientType"), "linear");
        compare(ConfigValidator.validate("radial", defaults, "gradientType"), "radial");
        compare(ConfigValidator.validate("halftone", defaults, "gradientType"), "halftone");
        
        // Invalid values should fallback
        compare(ConfigValidator.validate("invalid", defaults, "gradientType"), "linear");
    }

    function test_validateTypeConstraintNoMediaDisplay() {
        var defaults = { noMediaDisplay: "userHost" };
        
        // Valid values should pass
        compare(ConfigValidator.validate("userHost", defaults, "noMediaDisplay"), "userHost");
        compare(ConfigValidator.validate("compositor", defaults, "noMediaDisplay"), "compositor");
        compare(ConfigValidator.validate("custom", defaults, "noMediaDisplay"), "custom");
        
        // Invalid value should fallback
        compare(ConfigValidator.validate("invalid", defaults, "noMediaDisplay"), "userHost");
    }

    function test_validateHandlesArrays() {
        var defaults = [1, 2, 3];
        var current = [10, 20];
        
        var result = ConfigValidator.validate(current, defaults);
        
        verify(Array.isArray(result), "Result should be an array");
        compare(result.length, 2);
    }

    function test_validateReturnsDefaultForArrayWhenCurrentIsObject() {
        var defaults = [1, 2, 3];
        var current = { not: "array" };
        
        var result = ConfigValidator.validate(current, defaults);
        
        verify(Array.isArray(result), "Should return array defaults");
        compare(result.length, 3);
    }
}