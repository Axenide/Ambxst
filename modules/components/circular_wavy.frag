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

// SDF de primer orden en coordenadas polares — evita completamente el bucle de 24 pasos
// usando la derivada analítica del radio y la inversesqrt acelerada por hardware.
float distanceToWave(float r, float theta) {
    float relAngle = theta - ubuf.startAngle;
    float f_theta = ubuf.radius + ubuf.amplitude * sin(ubuf.frequency * relAngle + ubuf.phase);
    float df_theta = ubuf.amplitude * ubuf.frequency * cos(ubuf.frequency * relAngle + ubuf.phase);
    
    // First-order SDF for polar curve: |r - f(θ)| / sqrt(1 + (f'(θ)/r)²)
    // inversesqrt es la raíz cuadrada inversa acelerada por hardware de la GPU
    float diff = r - f_theta;
    float invDenom = inversesqrt(1.0 + (df_theta * df_theta) / (r * r));
    return abs(diff) * invDenom;
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
