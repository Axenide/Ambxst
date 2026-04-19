#version 440

// Inputs from vertex shader
layout(location = 0) in vec2 qt_TexCoord0;     // Original texture coordinate (0..1)
layout(location = 1) in vec4 qt_UVAdjustment;  // UV transform (offset.xy, scale.zw) from vertex shader

// Output color
layout(location = 0) out vec4 fragColor;

// Textures
layout(binding = 1) uniform sampler2D source;         // Input image
layout(binding = 2) uniform sampler2D paletteTexture; // 1D texture containing the palette colors

// Uniform block (same as vertex, but we only need a subset here)
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float paletteSize;    // number of colors in palette (1..MAX_PALETTE_COLORS)
    float texWidth;       // source image width in pixels (for dithering)
    float texHeight;      // source image height in pixels
} ubuf;

// -------------------------------------------------------------------
// Configurable constants
// -------------------------------------------------------------------
const int MAX_PALETTE_COLORS = 128;   // Maximum palette size we support
const float EPSILON = 1e-6;           // Small value to avoid division by zero

// Feature toggles
#define USE_LINEAR_SPACE 1            // Work in linear light (recommended for better blending)
#define HIGH_QUALITY_LOCAL_CONTRAST 0 // Use 8 neighbors instead of 4 for local contrast (costlier)

// Tunable parameters for the palette mapping effect
const float BASE_SHARPNESS = 20.0;               // Base sharpness of the soft cluster assignment
const float ADAPTIVE_SHARPNESS_STRENGTH = 14.0;  // How much local contrast increases sharpness
const float HYBRID_NEAREST_BIAS = 0.22;          // Bias toward nearest neighbor in high contrast areas
const float LOCAL_CONTRAST_STRENGTH = 0.35;      // How much to boost local contrast after mapping
const float DITHER_STRENGTH = 0.85;              // Maximum dither amplitude (in 0..1 range before /255)

// -------------------------------------------------------------------
// Color space conversion utilities
// -------------------------------------------------------------------

// Convert sRGB to linear space (approximate, but good enough)
vec3 srgbToLinear(vec3 c) {
    vec3 low  = c / 12.92;
    vec3 high = pow(max((c + 0.055) / 1.055, vec3(0.0)), vec3(2.4));
    bvec3 cutoff = lessThanEqual(c, vec3(0.04045));
    return mix(high, low, cutoff);
}

// Convert linear back to sRGB
vec3 linearToSrgb(vec3 c) {
    vec3 low  = c * 12.92;
    vec3 high = 1.055 * pow(max(c, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055;
    bvec3 cutoff = lessThanEqual(c, vec3(0.0031308));
    return clamp(mix(high, low, cutoff), 0.0, 1.0);
}

// Compute luminance (perceptual brightness) from linear RGB
float luma(vec3 c) {
    return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

// -------------------------------------------------------------------
// Noise functions for dithering
// -------------------------------------------------------------------

// 2D hash returning a float in [0,1]
float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// 2D hash returning a vec3 of three independent values
vec3 hash33(vec2 p) {
    return vec3(
        hash12(p + vec2(0.0, 0.0)),
        hash12(p + vec2(17.0, 31.0)),
        hash12(p + vec2(47.0, 73.0))
    );
}

// -------------------------------------------------------------------
// Texture fetching helpers
// -------------------------------------------------------------------

// Fetch source pixel and optionally convert to linear space
vec3 fetchSourceLinear(vec2 uv) {
    vec3 c = texture(source, uv).rgb;
#if USE_LINEAR_SPACE
    c = srgbToLinear(c);
#endif
    return c;
}

// Fetch a color from the 1D palette texture at a given index (0..size-1)
// The palette texture is assumed to be a horizontal strip of colors.
vec3 fetchPaletteLinear(float index, float invPaletteSize) {
    // Center the sample within the texel to avoid interpolation issues
    float u = (index + 0.5) * invPaletteSize;
    vec3 c = texture(paletteTexture, vec2(u, 0.5)).rgb;
#if USE_LINEAR_SPACE
    c = srgbToLinear(c);
#endif
    return c;
}

// -------------------------------------------------------------------
// Local statistics for adaptive sharpness and contrast preservation
// -------------------------------------------------------------------
void computeLocalStats(vec2 uv, vec3 centerColor, out vec3 localMean, out float localContrast) {
    // Size of one pixel in UV space
    vec2 texel = 1.0 / max(vec2(ubuf.texWidth, ubuf.texHeight), vec2(1.0));
    // Clamp UV so we don't sample outside the texture borders
    vec2 safeUV = clamp(uv, texel, vec2(1.0) - texel);

#if HIGH_QUALITY_LOCAL_CONTRAST
    // Sample all 8 neighbors (9-tap)
    vec3 c1 = fetchSourceLinear(safeUV + vec2(-texel.x,  0.0));
    vec3 c2 = fetchSourceLinear(safeUV + vec2( texel.x,  0.0));
    vec3 c3 = fetchSourceLinear(safeUV + vec2( 0.0, -texel.y));
    vec3 c4 = fetchSourceLinear(safeUV + vec2( 0.0,  texel.y));
    vec3 c5 = fetchSourceLinear(safeUV + vec2(-texel.x, -texel.y));
    vec3 c6 = fetchSourceLinear(safeUV + vec2( texel.x, -texel.y));
    vec3 c7 = fetchSourceLinear(safeUV + vec2(-texel.x,  texel.y));
    vec3 c8 = fetchSourceLinear(safeUV + vec2( texel.x,  texel.y));

    // Compute average of the 3x3 block
    localMean = (centerColor + c1 + c2 + c3 + c4 + c5 + c6 + c7 + c8) / 9.0;

    // Compute min/max luminance in the 3x3 block
    float l0 = luma(centerColor);
    float l1 = luma(c1);
    float l2 = luma(c2);
    float l3 = luma(c3);
    float l4 = luma(c4);
    float l5 = luma(c5);
    float l6 = luma(c6);
    float l7 = luma(c7);
    float l8 = luma(c8);

    float lumMin = min(min(min(min(l0, l1), min(l2, l3)), min(min(l4, l5), min(l6, l7))), l8);
    float lumMax = max(max(max(max(l0, l1), max(l2, l3)), max(max(l4, l5), max(l6, l7))), l8);
    // Scale contrast to a 0..1 range (1.6 is an empirical factor)
    localContrast = clamp((lumMax - lumMin) * 1.6, 0.0, 1.0);
#else
    // Lower quality but faster: only 4 orthogonal neighbors
    vec3 left   = fetchSourceLinear(safeUV + vec2(-texel.x, 0.0));
    vec3 right  = fetchSourceLinear(safeUV + vec2( texel.x, 0.0));
    vec3 up     = fetchSourceLinear(safeUV + vec2(0.0, -texel.y));
    vec3 down   = fetchSourceLinear(safeUV + vec2(0.0,  texel.y));

    localMean = (centerColor + left + right + up + down) * 0.2;

    float l0 = luma(centerColor);
    float l1 = luma(left);
    float l2 = luma(right);
    float l3 = luma(up);
    float l4 = luma(down);

    float lumMin = min(min(min(l0, l1), l2), min(l3, l4));
    float lumMax = max(max(max(l0, l1), l2), max(l3, l4));
    // Contrast factor adjusted for fewer samples
    localContrast = clamp((lumMax - lumMin) * 2.0, 0.0, 1.0);
#endif
}

// -------------------------------------------------------------------
// Palette matching (soft clustering)
// -------------------------------------------------------------------
struct PaletteMatchResult {
    vec3 averageColor;   // Weighted average of all palette colors (soft blend)
    vec3 nearestColor;   // Closest palette color (hard assignment)
    float totalWeight;   // Sum of weights for normalization
    float bestWeight;    // Weight of the best match (used for confidence)
    float bestDistSq;    // Squared distance to the best match
};

// Perform a soft assignment of the input color to the palette colors.
// The sharpness parameter controls how quickly weights fall off with distance.
PaletteMatchResult matchPalette(vec3 color, int size, float sharpness) {
    PaletteMatchResult r;
    r.averageColor = vec3(0.0);
    r.nearestColor = color;
    r.totalWeight = 0.0;
    r.bestWeight = 0.0;
    r.bestDistSq = 1e20; // large initial value

    float invPaletteSize = 1.0 / max(float(size), 1.0);
    const float LOG2_E = 1.4426950408889634; // 1/ln(2) for exp2 optimization

    for (int i = 0; i < MAX_PALETTE_COLORS; ++i) {
        if (i >= size) break; // stop if we processed all colors

        vec3 pColor = fetchPaletteLinear(float(i), invPaletteSize);
        vec3 diff = color - pColor;
        float distSq = dot(diff, diff); // squared Euclidean distance in linear space

        // Weight using a Gaussian-like falloff: exp2(-distSq * sharpness)
        // Using exp2 is faster on many GPUs.
        float weight = exp2(-distSq * sharpness * LOG2_E);

        // Accumulate for soft blending
        r.averageColor += pColor * weight;
        r.totalWeight += weight;

        // Track the closest match
        if (distSq < r.bestDistSq) {
            r.bestDistSq = distSq;
            r.nearestColor = pColor;
            r.bestWeight = weight;
        }
    }

    return r;
}

// -------------------------------------------------------------------
// Main shader entry point
// -------------------------------------------------------------------
void main() {
    // Apply the UV adjustment computed in the vertex shader.
    // This implements the "PreserveAspectCrop" effect by scaling and offsetting
    // the texture coordinates so the image fills the viewport without distortion.
    vec2 adjustedUV = qt_UVAdjustment.xy + qt_TexCoord0 * qt_UVAdjustment.zw;
    vec4 src = texture(source, adjustedUV);
    vec3 sourceColor = src.rgb;

    // Convert to linear light if enabled (this improves blending and distance calculations)
#if USE_LINEAR_SPACE
    sourceColor = srgbToLinear(sourceColor);
#endif

    // Clamp palette size to the supported range and cast to integer
    int size = int(clamp(ubuf.paletteSize, 0.0, float(MAX_PALETTE_COLORS)));

    // If no palette is provided, just output the source color (with opacity handling)
    if (size <= 0) {
#if USE_LINEAR_SPACE
        vec3 outColor = linearToSrgb(sourceColor);
#else
        vec3 outColor = sourceColor;
#endif
        fragColor = vec4(outColor * src.a, src.a) * ubuf.qt_Opacity;
        return;
    }

    // Analyze local neighborhood for adaptive behavior
    vec3 localMean;
    float localContrast;
    computeLocalStats(adjustedUV, sourceColor, localMean, localContrast);

    // Increase sharpness in high-contrast areas to preserve edges better
    float adaptiveSharpness = BASE_SHARPNESS * (1.0 + localContrast * ADAPTIVE_SHARPNESS_STRENGTH);
    adaptiveSharpness = max(adaptiveSharpness, 0.001);

    // Perform the soft clustering against the palette
    PaletteMatchResult pm = matchPalette(sourceColor, size, adaptiveSharpness);

    // Normalize the weighted average
    vec3 averageColor = pm.averageColor / max(pm.totalWeight, EPSILON);

    // Confidence measures how dominant the nearest color is.
    // If one color is overwhelmingly close, we trust the hard match more.
    float confidence = clamp(pm.bestWeight / max(pm.totalWeight, EPSILON), 0.0, 1.0);

    // Mix between soft average and hard nearest based on confidence and local contrast.
    // In high-contrast regions we bias toward the nearest color to preserve details.
    float nearestMix = smoothstep(0.15, 0.85, confidence);
    nearestMix = clamp(nearestMix + localContrast * HYBRID_NEAREST_BIAS, 0.0, 1.0);

    vec3 hybridColor = mix(averageColor, pm.nearestColor, nearestMix);

    // Boost local contrast to counteract the flattening effect of palette reduction.
    // This is a form of unsharp masking that brings back texture.
    float contrastBoost = 1.0 + localContrast * LOCAL_CONTRAST_STRENGTH;
    vec3 contrastedColor = localMean + (hybridColor - localMean) * contrastBoost;

    // -------------------------------------------------------------------
    // Dithering
    // -------------------------------------------------------------------
    // Dither strength depends on palette size (smaller palettes benefit more)
    // and on local smoothness (we avoid dithering edges to prevent artifacts).
    float paletteRisk = 1.0 - smoothstep(8.0, 64.0, float(size));
    float smoothArea = 1.0 - localContrast;
    float ditherAmount = (DITHER_STRENGTH / 255.0) * paletteRisk * smoothArea;

    // Generate pixel-based deterministic noise using integer pixel coordinates.
    vec2 pixel = floor(adjustedUV * vec2(max(ubuf.texWidth, 1.0), max(ubuf.texHeight, 1.0)));
    // Subtract two hashes to get a value roughly in [-1, 1] range with zero mean.
    vec3 dither = hash33(pixel) - hash33(pixel + vec2(13.37, 91.17));
    contrastedColor += dither * ditherAmount;

    // Ensure we stay within valid color range
    contrastedColor = clamp(contrastedColor, 0.0, 1.0);

    // Convert back to sRGB if we were working in linear space
#if USE_LINEAR_SPACE
    vec3 finalColor = linearToSrgb(contrastedColor);
#else
    vec3 finalColor = contrastedColor;
#endif

    // Combine with source alpha and apply global opacity
    fragColor = vec4(finalColor * src.a, src.a) * ubuf.qt_Opacity;
}