pragma Singleton

import QtQuick
import Quickshell
import qs.config
import qs.modules.theme

/**
 * GradientCache - Singleton that caches gradient textures for StyledRect.
 *
 * Instead of each StyledRect creating its own Canvas and ShaderEffectSource,
 * this singleton maintains a shared cache of gradient textures keyed by
 * configuration hash. This reduces GPU memory usage from O(n) to O(variants).
 *
 * Usage: GradientCache.getTexture(gradientStops) returns a ShaderEffectSource
 */
Singleton {
    id: root

    // Internal cache storage - maps hash keys to texture objects
    property var _cache: ({})

    // Container for dynamically created Canvas/ShaderEffectSource pairs
    Item {
        id: textureContainer
        visible: false
    }

    /**
     * Generate a stable hash key from gradient stops array.
     * Format: "color1@pos1,color2@pos2,..."
     */
    function _hashGradient(stops) {
        if (!stops || stops.length === 0)
            return "";

        const parts = [];
        for (let i = 0; i < stops.length; i++) {
            const s = stops[i];
            // Resolve color to ensure consistent keys
            const resolvedColor = Config.resolveColor(s[0]);
            parts.push(resolvedColor + "@" + s[1]);
        }
        return parts.join(",");
    }

    /**
     * Get or create a gradient texture for the given stops.
     * Returns a ShaderEffectSource ready to be used as a texture sampler.
     */
    function getTexture(gradientStops) {
        const key = _hashGradient(gradientStops);

        // Return cached texture if exists
        if (key && root._cache[key]) {
            return root._cache[key].source;
        }

        // Empty gradient - return null
        if (!key || !gradientStops || gradientStops.length === 0) {
            return null;
        }

        // Create new Canvas + ShaderEffectSource pair
        const entry = _createTextureEntry(gradientStops, key);
        root._cache[key] = entry;

        return entry.source;
    }

    /**
     * Create a Canvas and ShaderEffectSource pair for the gradient.
     */
    function _createTextureEntry(stops, key) {
        // Create Canvas
        const canvasComponent = Qt.createComponent("GradientCanvas.qml");
        if (canvasComponent.status !== Component.Ready) {
            console.error("GradientCache: Failed to create GradientCanvas:", canvasComponent.errorString());
            return { source: null, canvas: null, key: key };
        }

        const canvas = canvasComponent.createObject(textureContainer, {
            gradientStops: stops
        });

        // Create ShaderEffectSource
        const sourceComponent = Qt.createQmlObject(`
            import QtQuick
            ShaderEffectSource {
                sourceItem: null
                hideSource: true
                smooth: true
                live: false
                wrapMode: ShaderEffectSource.ClampToEdge
                visible: false
            }
        `, textureContainer, "GradientCacheSource");

        sourceComponent.sourceItem = canvas;

        // Schedule update after canvas paints
        canvas.painted.connect(() => {
            sourceComponent.scheduleUpdate();
        });

        return {
            source: sourceComponent,
            canvas: canvas,
            key: key
        };
    }

    /**
     * Invalidate all cached textures and rebuild them.
     * Called when theme colors change.
     */
    function invalidateAll() {
        // Repaint all cached canvases
        for (const key in root._cache) {
            const entry = root._cache[key];
            if (entry.canvas) {
                entry.canvas.requestPaint();
            }
        }
    }

    // Listen for color theme changes
    Connections {
        target: Colors
        function onLoaded() {
            root.invalidateAll();
        }
    }
}
