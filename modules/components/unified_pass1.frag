#version 440
precision mediump float;

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float radius;
    vec2 texelSize;
} ubuf;

layout(binding = 1) uniform sampler2D source;

void main() {
    float alpha = 0.0;
    float r = clamp(ubuf.radius, 1.0, 16.0); // Restored range
    float totalWeight = 0.0;
    
    // Restored full loop range for correctness, optimization via early exit
    for (int i = -16; i <= 16; i++) {
        float fi = float(i);
        if (fi < -r || fi > r) continue;
        
        float weight = exp(-0.5 * pow(fi * 3.0 / r, 2.0)); // Restored curve
        alpha += texture(source, qt_TexCoord0 + vec2(fi * ubuf.texelSize.x, 0.0)).a * weight;
        totalWeight += weight;
    }
    
    fragColor = vec4(0.0, 0.0, 0.0, alpha / totalWeight) * ubuf.qt_Opacity;
}
