#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float radius;       // Normalized radius (0.0-0.5)
    float startAngle;   // Radians
    float progressAngle;// Radians span
    float amplitude;    // Normalized
    float frequency;
    float phase;
    float thickness;    // Normalized
    float pixelSize;    // 1.0 / canvasSize (to help with AA)
    vec4 color;
} ubuf;

#define PI 3.14159265359

// Calculate the target radius for a given angle
float targetRadiusAt(float angle) {
    float relAngle = angle - ubuf.startAngle;
    return ubuf.radius + ubuf.amplitude * sin(ubuf.frequency * relAngle + ubuf.phase);
}

// Convert Polar to Cartesian
vec2 polarToCartesian(float r, float theta) {
    return vec2(r * cos(theta), r * sin(theta));
}

// Robust Distance Field search in Polar Coordinates
float distanceToWave(float r, float theta) {
    // 1. Define search window in Angular space
    // 0.1 radians is usually enough for high frequency waves at typical radii.
    float searchWindow = 0.15; 
    
    float minStart = theta - searchWindow;
    float minEnd = theta + searchWindow;
    
    const int numSteps = 24; 
    
    float minDistanceSq = 1.0e+20;
    
    for (int i = 0; i <= numSteps; ++i) {
        float t = float(i) / float(numSteps);
        float sampleTheta = mix(minStart, minEnd, t);
        
        float sampleR = targetRadiusAt(sampleTheta);
        
        // Calculate Cartesian distance squared
        float dX = r * cos(theta) - sampleR * cos(sampleTheta);
        float dY = r * sin(theta) - sampleR * sin(sampleTheta);
        float distSq = dX*dX + dY*dY;
        
        minDistanceSq = min(minDistanceSq, distSq);
    }
    
    return sqrt(minDistanceSq);
}

void main() {
    // UV centered at 0,0 (Range -0.5 to 0.5)
    vec2 uv = qt_TexCoord0 - 0.5;
    
    float r = length(uv);
    float theta = atan(uv.y, uv.x); // [-PI, PI]
    if (theta < 0.0) theta += 2.0 * PI;
    
    // --- Determine if inside Angular Mask ---
    float relAngle = theta - ubuf.startAngle;
    relAngle = mod(relAngle, 2.0 * PI);
    if (relAngle < 0.0) relAngle += 2.0 * PI;
    
    bool insideMask = (relAngle <= ubuf.progressAngle);
    
    // --- Distance to Curve ---
    float d_curve = 1.0; // Assume infinite if calculation skipped
    
    // Optimization: Only compute precise distance if reasonably close to the ring
    float margin = ubuf.amplitude + ubuf.thickness;
    if (abs(r - ubuf.radius) <= margin) {
        d_curve = distanceToWave(r, theta);
    }
    
    // If outside mask, d_curve is irrelevant (infinite)
    if (!insideMask) d_curve = 1.0;
    
    // --- Distance to Caps ---
    // Start Cap
    float startTheta = ubuf.startAngle;
    float startR = targetRadiusAt(startTheta);
    vec2 startPos = polarToCartesian(startR, startTheta);
    float d_start = distance(uv, startPos);
    
    // End Cap
    // Note: Use startAngle + progressAngle.
    // Ensure we account for wrapping if needed, but simple addition works for trig.
    float endTheta = ubuf.startAngle + ubuf.progressAngle;
    float endR = targetRadiusAt(endTheta);
    vec2 endPos = polarToCartesian(endR, endTheta);
    float d_end = distance(uv, endPos);
    
    // --- Combine Distances ---
    // We render the union of the masked curve and the two caps
    float d_caps = min(d_start, d_end);
    float d_final = min(d_curve, d_caps);
    
    // --- Rendering ---
    float halfThick = ubuf.thickness * 0.5;
    
    // Use fixed AA width based on pixel size to avoid artifacts from fwidth() 
    // at discontinuities (mask boundaries, optimization margins).
    // ubuf.pixelSize is (1.0 / canvasWidth). We use 1.5 pixels for smooth edges.
    float aa = ubuf.pixelSize * 1.5;
    
    float alpha = 1.0 - smoothstep(halfThick - aa, halfThick + aa, d_final);
    
    if (alpha <= 0.0) discard;
    
    fragColor = ubuf.color * alpha * ubuf.qt_Opacity;
}
