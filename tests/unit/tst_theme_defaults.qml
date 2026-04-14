import QtQuick 2.15
import QtTest 1.15

import "../../config/defaults/theme.js" as ThemeDefaults

TestCase {
    name: "ThemeDefaults"

    function test_themeDefaultsHasRequiredKeys() {
        var data = ThemeDefaults.data;
        
        verify(data.hasOwnProperty("colors"), "Theme defaults must have 'colors'");
        verify(data.hasOwnProperty("background"), "Theme defaults must have 'background'");
        verify(data.hasOwnProperty("accent"), "Theme defaults must have 'accent'");
    }

    function test_colorsHasValidStructure() {
        var colors = ThemeDefaults.data.colors;
        
        verify(colors.hasOwnProperty("dark"), "Colors must have 'dark' object");
        verify(colors.hasOwnProperty("light"), "Colors must have 'light' object");
        
        var requiredColorKeys = ["bg", "fg", "fgSecondary", "accent", "error", "warning", "success"];
        for (var i = 0; i < requiredColorKeys.length; i++) {
            var key = requiredColorKeys[i];
            verify(colors.dark.hasOwnProperty(key), "Dark colors must have '" + key + "'");
            verify(colors.light.hasOwnProperty(key), "Light colors must have '" + key + "'");
        }
    }

    function test_backgroundHasValidGradientType() {
        var bg = ThemeDefaults.data.background;
        var validTypes = ["linear", "radial", "halftone", "solid"];
        
        verify(validTypes.indexOf(bg.gradientType) !== -1, 
            "gradientType must be one of: " + validTypes.join(", "));
    }
}