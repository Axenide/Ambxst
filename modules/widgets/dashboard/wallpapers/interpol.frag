#version 440

#ifdef GL_ES
precision highp float;
precision mediump int;
#endif

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(binding = 1) uniform sampler2D currentFrame;
layout(binding = 2) uniform sampler2D previousFrame;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float blendFactor;
    vec2 iResolution;
    int blockSize;
    int searchRadius;
    float motionThreshold;
    int debugMode;
    int isOriginalFrame;
    int frameCounter;
} ubuf;

// -------------------------------------------------------------------
// Ultra‑fast approximate exp() – Refined Quake‑style polynomial
// -------------------------------------------------------------------
float fast_exp(float x) {
    x = clamp(x, -10.0, 10.0);
    float x2 = x * x;
    float x3 = x2 * x;
    float x4 = x2 * x2;
    return 1.0 + x + 0.5 * x2 + 0.16666666 * x3 + 0.04166666 * x4;
}

// -------------------------------------------------------------------
// Utility: clamp integer coordinate
// -------------------------------------------------------------------
ivec2 clampCoord(ivec2 coord, ivec2 minBound, ivec2 maxBound) {
    return ivec2(clamp(coord.x, minBound.x, maxBound.x),
                 clamp(coord.y, minBound.y, maxBound.y));
}

// -------------------------------------------------------------------
// Sample a pixel safely
// -------------------------------------------------------------------
vec3 samplePixel(sampler2D tex, ivec2 coord) {
    ivec2 res = ivec2(ubuf.iResolution);
    ivec2 clamped = clampCoord(coord, ivec2(0, 0), res - 1);
    return texelFetch(tex, clamped, 0).rgb;
}

// -------------------------------------------------------------------
// Optimized SAD using texelFetch (with manual unrolling for speed)
// -------------------------------------------------------------------
float blockSADFast(ivec2 centerCurr, ivec2 centerPrev, int bSize) {
    float sad = 0.0;
    int h = bSize / 2;
    ivec2 res = ivec2(ubuf.iResolution);
    ivec2 minBound = ivec2(h, h);
    ivec2 maxBound = res - h - 1;

    for (int y = -h; y < h; ++y) {
        for (int x = -h; x < h; ++x) {
            ivec2 offset = ivec2(x, y);
            ivec2 coord_curr = clampCoord(centerCurr + offset, minBound, maxBound);
            ivec2 coord_prev = clampCoord(centerPrev + offset, minBound, maxBound);
            vec3 c = texelFetch(currentFrame, coord_curr, 0).rgb;
            vec3 p = texelFetch(previousFrame, coord_prev, 0).rgb;
            sad += dot(abs(c - p), vec3(0.299, 0.587, 0.114));
        }
    }
    return sad / float(bSize * bSize);
}

void main() {
    vec2 uv = qt_TexCoord0;
    ivec2 res = ivec2(ubuf.iResolution);
    ivec2 texelCoord = ivec2(uv * vec2(res));

    int bSize = ubuf.blockSize;
    int h = bSize / 2;
    ivec2 minBound = ivec2(h, h);
    ivec2 maxBound = res - h - 1;
    ivec2 safeCoord = clampCoord(texelCoord, minBound, maxBound);

    ivec2 blockIdx = safeCoord / bSize;
    ivec2 blockCenter = blockIdx * bSize + h;

    vec3 curr = samplePixel(currentFrame, safeCoord);
    vec3 prev = samplePixel(previousFrame, safeCoord);

    vec2 motion = vec2(0.0);
    float bestCost = 1e10;
    bool motionValid = false;

    // ---- Pyramid‑based motion search (only at block centers) ----
    if (all(equal(safeCoord, blockCenter))) {
        // Fast check: if block difference is low, skip expensive search
        float coarseDiff = blockSADFast(blockCenter, blockCenter, bSize);
        if (coarseDiff > ubuf.motionThreshold) {
            int sr = ubuf.searchRadius;
            // Coarse search at 1/4 resolution for efficiency
            vec2 coarseTexel = 4.0 / vec2(res);
            vec2 coarseUV = uv * 0.25;
            for (int dy = -sr; dy <= sr; ++dy) {
                for (int dx = -sr; dx <= sr; ++dx) {
                    vec2 offset = vec2(float(dx), float(dy)) * coarseTexel;
                    vec3 c = textureLod(currentFrame, coarseUV, 2.0).rgb;
                    vec3 p = textureLod(previousFrame, coarseUV + offset, 2.0).rgb;
                    float cost = dot(abs(c - p), vec3(0.299, 0.587, 0.114));
                    if (cost < bestCost) {
                        bestCost = cost;
                        motion = offset * 4.0;
                    }
                }
            }
            // Fine refinement at full resolution (only if coarse search found something)
            if (bestCost < 1e9) {
                ivec2 coarseMotion = ivec2(motion * vec2(res));
                for (int dy = -2; dy <= 2; ++dy) {
                    for (int dx = -2; dx <= 2; ++dx) {
                        ivec2 offset = coarseMotion + ivec2(dx, dy);
                        ivec2 blockCenterPrev = blockCenter + offset;
                        if (any(lessThan(blockCenterPrev, minBound)) || any(greaterThan(blockCenterPrev, maxBound)))
                            continue;
                        float sad = blockSADFast(blockCenter, blockCenterPrev, bSize);
                        if (sad < bestCost) {
                            bestCost = sad;
                            motion = vec2(offset) / vec2(res);
                        }
                    }
                }
                motionValid = (bestCost < ubuf.motionThreshold * 2.0);
            }
        }
    }

    // ---- Warping & hole filling ----
    vec2 texelSize = 1.0 / vec2(res);
    vec2 motionUV = motion;
    vec2 halfTexel = texelSize * 0.5;

    vec2 warpedUV = uv - motionUV * ubuf.blendFactor;
    warpedUV = clamp(warpedUV, halfTexel, 1.0 - halfTexel);
    vec3 warpedPrev = texture(previousFrame, warpedUV).rgb;

    vec2 warpedCurrUV = uv + motionUV * (1.0 - ubuf.blendFactor);
    warpedCurrUV = clamp(warpedCurrUV, halfTexel, 1.0 - halfTexel);
    vec3 warpedCurr = texture(currentFrame, warpedCurrUV).rgb;

    vec3 blended = mix(prev, curr, ubuf.blendFactor);
    vec3 finalColor;

    if (motionValid) {
        vec3 centerWarpedPrev = texture(previousFrame, warpedUV).rgb;
        float holeWeight = clamp(dot(abs(curr - centerWarpedPrev), vec3(0.299, 0.587, 0.114)) / 0.3, 0.0, 1.0);
        vec3 motionCompensated = mix(warpedPrev, warpedCurr, holeWeight);
        float confidence = 1.0 - clamp(bestCost / (ubuf.motionThreshold * 3.0), 0.0, 1.0);
        finalColor = mix(blended, motionCompensated, confidence * 0.9);
    } else {
        finalColor = blended;
    }

    if (ubuf.debugMode != 0 && ubuf.isOriginalFrame == 0) {
        finalColor *= vec3(1.0, 1.2, 1.0);
    }

    fragColor = vec4(finalColor, 1.0) * ubuf.qt_Opacity;
}